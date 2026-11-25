//! Merge GPU writes into the current title bytes without losing CPU writes.
//! The caller has already read title memory and identified a changed piece.
//! Keep the original bytewise precedence, including when both sides wrote.

/// Returns whether title bytes changed, and synchronizes the host copy.
pub(super) fn merge(title: &mut [u8], host: &mut [u8], old: &[u8]) -> bool {
    assert_eq!(title.len(), host.len());
    assert_eq!(title.len(), old.len());
    // Select the merged byte before recording a change, allowing vectorization.
    let mut changed = false;
    for ((t, h), o) in title.iter_mut().zip(host.iter_mut()).zip(old) {
        let merged = if *h == *o { *t } else { *h };
        changed |= merged != *t;
        *t = merged;
        *h = merged;
    }
    changed
}

#[cfg(test)]
fn scalar(title: &mut [u8], host: &mut [u8], old: &[u8]) -> bool {
    let mut changed = false;
    for ((t, h), o) in title.iter_mut().zip(host.iter_mut()).zip(old) {
        if *h != *o && *t != *h {
            *t = *h;
            changed = true;
        }
        *h = *t;
    }
    changed
}

#[cfg(test)]
mod tests {
    use super::*;

    fn next(seed: &mut u32) -> u8 {
        *seed ^= *seed << 13;
        *seed ^= *seed >> 17;
        *seed ^= *seed << 5;
        *seed as u8
    }

    #[test]
    fn merge_preserves_cpu_bytes_and_gpu_write_precedence() {
        let mut title = [7, 8, 9, 10, 11, 12];
        let mut host = [1, 2, 9, 4, 99, 12];
        let old = [1, 3, 3, 4, 5, 6];
        assert!(merge(&mut title, &mut host, &old));
        assert_eq!(title, [7, 2, 9, 10, 99, 12]);
        assert_eq!(host, title);
    }

    #[test]
    fn merge_reports_no_title_change_when_gpu_matches_title() {
        let mut title = [5; 65];
        let mut host = [5; 65];
        assert!(!merge(&mut title, &mut host, &[0; 65]));
        let mut host = [1; 65];
        assert!(!merge(&mut title, &mut host, &[1; 65]));
        assert_eq!(host, title);
    }

    #[test]
    fn one_changed_byte_at_each_vector_boundary() {
        for at in [0, 30, 31, 32, 33, 63, 64] {
            let old = [0u8; 65];
            let mut title = [0x55u8; 65];
            let mut host = old;
            host[at] = 0x80;
            let mut expected = title;
            expected[at] = 0x80;
            assert!(merge(&mut title, &mut host, &old));
            assert_eq!(title, expected);
            assert_eq!(host, expected);
        }
    }

    #[test]
    fn merge_matches_scalar_with_unaligned_vectors_and_tails() {
        let mut seed = 0x1234_abcd;
        for len in (0..=129).chain([255, 256, 257, 4095, 4096, 4097, 65535, 65536]) {
            for offset in 0..32 {
                let mut title = vec![0x5a; len + 64];
                let mut host = vec![0xa5; len + 64];
                let mut old = vec![0; len + 64];
                for i in 0..len {
                    let at = offset + i;
                    old[at] = next(&mut seed);
                    title[at] = next(&mut seed);
                    host[at] = match i % 4 {
                        0 => old[at],
                        1 => title[at],
                        _ => next(&mut seed),
                    };
                }
                let mut expected_title = title.clone();
                let mut expected_host = host.clone();
                let range = offset..offset + len;
                let changed = scalar(
                    &mut expected_title[range.clone()],
                    &mut expected_host[range.clone()],
                    &old[range.clone()],
                );
                assert_eq!(
                    merge(&mut title[range.clone()], &mut host[range.clone()], &old[range]),
                    changed
                );
                // Also checks that bytes outside the view remain untouched.
                assert_eq!(title, expected_title);
                assert_eq!(host, expected_host);
            }
        }
    }
}
