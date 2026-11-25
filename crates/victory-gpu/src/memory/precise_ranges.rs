//! Readback overlap index for root-UAV ranges. This does not change the
//! page-level policy: a page touching a precise range is left to that
//! range's existing byte-for-byte copy-back.

pub(super) struct PreciseRanges {
    // Sorted starts with the maximum end among this entry and all earlier
    // entries. Nested ranges and repeated starts require the prefix max,
    // not just the end of the last range preceding a query.
    prefix: Vec<(u64, u64)>,
}

impl PreciseRanges {
    pub(super) fn new(ranges: &[(u64, u64)]) -> Self {
        let mut prefix: Vec<_> = ranges
            .iter()
            .map(|&(start, len)| (start, start.saturating_add(len)))
            .collect();
        prefix.sort_unstable_by_key(|&(start, _)| start);
        let mut max_end = 0;
        for (_, end) in &mut prefix {
            max_end = max_end.max(*end);
            *end = max_end;
        }
        Self { prefix }
    }

    /// For a nonempty page [from, to), the original test was
    /// start < to && from < start + len. In particular, preserve its
    /// treatment of zero-length declarations strictly inside a page.
    pub(super) fn overlaps(&self, from: u64, to: u64) -> bool {
        if from >= to {
            return false;
        }
        let count = self.prefix.partition_point(|&(start, _)| start < to);
        count != 0 && self.prefix[count - 1].1 > from
    }
}

/// Avoid sorting/allocating for small or lightly queried range lists.
/// The measured crossover depends on query count and hit position. Start
/// linearly and build the index only after the equivalent of 32 full scans.
pub(super) struct AdaptiveRanges<'a> {
    ranges: &'a [(u64, u64)],
    comparisons: usize,
    index: Option<PreciseRanges>,
}

impl<'a> AdaptiveRanges<'a> {
    pub(super) fn new(ranges: &'a [(u64, u64)]) -> Self {
        Self { ranges, comparisons: 0, index: None }
    }

    pub(super) fn overlaps(&mut self, from: u64, to: u64) -> bool {
        if from >= to {
            return false;
        }
        if let Some(index) = &self.index {
            return index.overlaps(from, to);
        }
        let n = self.ranges.len();
        if n >= 8 && self.comparisons >= n.saturating_mul(32) {
            let index = self.index.insert(PreciseRanges::new(self.ranges));
            return index.overlaps(from, to);
        }
        let hit = self.ranges.iter().position(|&(a, len)| {
            a < to && from < a.saturating_add(len)
        });
        if n >= 8 {
            self.comparisons = self.comparisons.saturating_add(hit.map_or(n, |i| i + 1));
        }
        hit.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn reference(ranges: &[(u64, u64)], from: u64, to: u64) -> bool {
        ranges.iter().any(|&(a, n)| a < to && from < a.saturating_add(n))
    }


    #[test]
    fn adaptive_index_waits_for_work_and_keeps_small_inputs_linear() {
        let ranges = vec![(0, 1); 64];
        let mut lookup = AdaptiveRanges::new(&ranges);
        assert!(lookup.index.is_none());
        // Hits at the first range should not pay for an index.
        for _ in 0..1024 {
            assert!(lookup.overlaps(0, 1));
        }
        assert!(lookup.index.is_none());

        // Repeated misses pay for the index; no result changes.
        for _ in 0..64 {
            assert!(!lookup.overlaps(2, 3));
        }
        assert!(lookup.index.is_some());
        assert!(lookup.overlaps(0, 1));

        let mut small = AdaptiveRanges::new(&ranges[..4]);
        for _ in 0..4096 {
            assert!(!small.overlaps(2, 3));
        }
        assert!(small.index.is_none());
    }

    #[test]
    fn adaptive_lookup_matches_reference_before_and_after_indexing() {
        let ranges: Vec<_> = (0..128u64)
            .rev()
            .map(|i| (i * 65536 + 7, i % 3 * 65536))
            .chain([(u64::MAX - 2, 8), (1, 65536 * 20)])
            .collect();
        let mut lookup = AdaptiveRanges::new(&ranges);
        assert!(!lookup.overlaps(1, 1));
        assert!(!lookup.overlaps(2, 1));
        for i in 0..4096u64 {
            let from = (i * 37 % 257) * 65536;
            assert_eq!(
                lookup.overlaps(from, from + 65536),
                reference(&ranges, from, from + 65536)
            );
        }
        assert!(lookup.index.is_some());
        assert!(lookup.overlaps(u64::MAX - 1, u64::MAX));
    }

    #[test]
    fn nested_ranges_keep_the_earlier_long_end() {
        let index = PreciseRanges::new(&[(0, 200), (10, 1), (20, 1), (20, 2)]);
        assert!(index.overlaps(100, 101));
        assert!(!index.overlaps(200, 201));
    }

    #[test]
    fn boundaries_and_zero_length_match_the_old_predicate() {
        let ranges = [(64, 64), (200, 0), (300, 8)];
        let index = PreciseRanges::new(&ranges);
        for (from, to) in [(0, 64), (64, 128), (128, 192), (192, 256), (200, 201), (199, 200), (308, 309)] {
            assert_eq!(index.overlaps(from, to), reference(&ranges, from, to));
        }
        assert!(!PreciseRanges::new(&[]).overlaps(0, 65536));
        assert!(PreciseRanges::new(&[(u64::MAX - 2, 8)]).overlaps(u64::MAX - 1, u64::MAX));
    }

    #[test]
    fn empty_or_reversed_queries_never_overlap() {
        let index = PreciseRanges::new(&[(0, 100), (50, 0)]);
        assert!(!index.overlaps(25, 25));
        assert!(!index.overlaps(60, 40));
        assert!(index.overlaps(25, 26));
    }

    #[test]
    fn exhaustive_small_ranges_and_queries() {
        let ranges: Vec<_> = (0..8u64)
            .flat_map(|a| (0..=8 - a).map(move |n| (a, n)))
            .collect();
        for &a in &ranges {
            for &b in &ranges {
                let input = [a, b];
                let index = PreciseRanges::new(&input);
                for from in 0..8 {
                    for to in from + 1..=8 {
                        assert_eq!(index.overlaps(from, to), reference(&input, from, to));
                    }
                }
            }
        }
    }

    #[test]
    fn many_unsorted_declarations_across_page_boundaries() {
        let mut seed = 0x1234_abcd_u64;
        let mut next = || {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            seed
        };
        for size in [0, 1, 2, 8, 32, 128, 512, 2048] {
            let ranges: Vec<_> = (0..size)
                .map(|_| (next() % (1 << 32), next() % (1 << 18)))
                .collect();
            let index = PreciseRanges::new(&ranges);
            for _ in 0..4096 {
                let from = (next() % (1 << 16)) << 16;
                assert_eq!(index.overlaps(from, from + 65536), reference(&ranges, from, from + 65536));
            }
        }
    }
}
