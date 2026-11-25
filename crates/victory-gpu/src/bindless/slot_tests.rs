//! Synthetic reverse-index regressions; no host device or title data.
use super::*;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Expected {
    Texture(usize),
    Left((usize, u64, u64)),
}

fn check(inner: &Inner, reference: &BTreeMap<u32, Expected>) {
    let actual: BTreeMap<_, _> = inner
        .slots
        .iter()
        .map(|(&slot, seen)| {
            let value = match seen {
                Seen::Texture(r) => Expected::Texture(*r),
                Seen::Left(v) => Expected::Left(*v),
                Seen::Buffer(..) => panic!("unexpected buffer"),
            };
            (slot, value)
        })
        .collect();
    assert_eq!(&actual, reference);
    let mut reverse = BTreeMap::<usize, BTreeSet<u32>>::new();
    for (&slot, &value) in reference {
        if let Expected::Texture(r) = value {
            reverse.entry(r).or_default().insert(slot);
        }
    }
    assert_eq!(inner.textures, reverse);
    assert!(inner.ranges.is_empty());
    assert!(inner.ends.is_empty());
    assert!(inner.hulls.is_empty());
}

#[test]
fn release_preserves_overwritten_and_unrelated_slots() {
    let mut inner = Inner::default();
    inner.replace(0, Some(Seen::Texture(1)));
    inner.replace(u32::MAX, Some(Seen::Texture(1)));
    inner.replace(2, Some(Seen::Texture(2)));
    inner.replace(0, Some(Seen::Left((2, 4096, 128))));
    inner.forget_texture(1);
    inner.forget_texture(1);
    check(
        &inner,
        &BTreeMap::from([
            (0, Expected::Left((2, 4096, 128))),
            (2, Expected::Texture(2)),
        ]),
    );
    inner.replace(u32::MAX, Some(Seen::Texture(1)));
    inner.replace(u32::MAX, Some(Seen::Texture(1)));
    inner.replace(u32::MAX, None);
    assert!(!inner.textures.contains_key(&1));
}

#[test]
fn seeded_slot_updates_match_full_scan() {
    for seed in 1..=200u64 {
        let mut random = seed;
        let mut next = || {
            random ^= random << 13;
            random ^= random >> 7;
            random ^= random << 17;
            random
        };
        let mut inner = Inner::default();
        let mut reference = BTreeMap::new();
        let span = [8, 32, 128, 1024][seed as usize % 4];
        let resources = [2, 8, 32, 128][(seed as usize / 4) % 4];
        for _ in 0..256 {
            let offset = (next() % span) as u32;
            let slot = if seed.is_multiple_of(2) {
                u32::MAX - offset
            } else {
                offset
            };
            let r = (next() % resources) as usize;
            match next() % 8 {
                0 => {
                    inner.forget_texture(r);
                    reference.retain(|_, seen| *seen != Expected::Texture(r));
                }
                1 => {
                    inner.replace(slot, None);
                    reference.remove(&slot);
                }
                2 => {
                    let left = (r % 4, next() % 4096, next() % 512);
                    inner.replace(slot, Some(Seen::Left(left)));
                    reference.insert(slot, Expected::Left(left));
                }
                _ => {
                    inner.replace(slot, Some(Seen::Texture(r)));
                    reference.insert(slot, Expected::Texture(r));
                }
            }
            check(&inner, &reference);
        }
    }
}


// Baseline texture/left-only subset of Inner at 13f91ca. The buffer
// bookkeeping is unchanged by the PR and deliberately not timed here.
#[derive(Default)]
struct ScanSlots {
    slots: HashMap<u32, Seen>,
    textures: BTreeMap<usize, u32>,
}

impl ScanSlots {
    fn count(&mut self, seen: &Seen, add: bool) {
        if let Seen::Texture(r) = seen {
            let n = self.textures.entry(*r).or_insert(0);
            *n = if add { *n + 1 } else { n.saturating_sub(1) };
            if *n == 0 {
                self.textures.remove(r);
            }
        }
    }

    fn replace(&mut self, index: u32, seen: Option<Seen>) {
        if let Some(old) = self.slots.remove(&index) {
            self.count(&old, false);
        }
        if let Some(seen) = seen {
            self.count(&seen, true);
            self.slots.insert(index, seen);
        }
    }

    fn forget_texture(&mut self, resource: usize) {
        if self.textures.remove(&resource).is_some() {
            self.slots.retain(|_, seen| !matches!(seen, Seen::Texture(r) if *r == resource));
        }
    }
}

#[test]
#[ignore = "release-only synthetic slot index benchmark"]
fn bench_slot_index() {
    use std::hint::black_box;
    use std::time::Instant;

    for n in [256u32, 4096, 32768] {
        for fanout in [1u32, 8, 64] {
            for mode in ["rewrite", "mixed", "release"] {
                let resources = n / fanout;
                let mut old = ScanSlots::default();
                let mut new = Inner::default();
                for slot in 0..n {
                    let r = (slot / fanout) as usize;
                    old.replace(slot, Some(Seen::Texture(r)));
                    new.replace(slot, Some(Seen::Texture(r)));
                }
                // A release followed by repopulation keeps the heap size
                // stable. Both algorithms pay the repopulation cost.
                let cycles = (resources as usize).min(128);
                let mut old_times = Vec::new();
                let mut new_times = Vec::new();
                let mut run = |reference: bool| {
                    let start = Instant::now();
                    for i in 0..cycles {
                        let r = black_box(i * 17 % resources as usize);
                        if mode != "release" {
                            for offset in 0..fanout {
                                let slot = r as u32 * fanout + offset;
                                if reference {
                                    old.replace(slot, Some(Seen::Left((0, 0, 0))));
                                    old.replace(slot, Some(Seen::Texture(r)));
                                } else {
                                    new.replace(slot, Some(Seen::Left((0, 0, 0))));
                                    new.replace(slot, Some(Seen::Texture(r)));
                                }
                            }
                        }
                        if mode != "rewrite" {
                            if reference {
                                old.forget_texture(r);
                            } else {
                                new.forget_texture(r);
                            }
                            for offset in 0..fanout {
                                let slot = r as u32 * fanout + offset;
                                if reference {
                                    old.replace(slot, Some(Seen::Texture(r)));
                                } else {
                                    new.replace(slot, Some(Seen::Texture(r)));
                                }
                            }
                        }
                    }
                    start.elapsed().as_secs_f64() * 1e6 / cycles as f64
                };
                for round in 0..7 {
                    if round % 2 == 0 {
                        old_times.push(run(true));
                        new_times.push(run(false));
                    } else {
                        new_times.push(run(false));
                        old_times.push(run(true));
                    }
                }
                // Also compare the intermediate released state: restoration
                // alone could conceal an erroneous no-op release.
                old.forget_texture(0);
                new.forget_texture(0);
                let reference: BTreeMap<_, _> = old.slots.iter().map(|(&slot, seen)| {
                    let value = match seen {
                        Seen::Texture(r) => Expected::Texture(*r),
                        Seen::Left(v) => Expected::Left(*v),
                        Seen::Buffer(..) => panic!("unexpected buffer"),
                    };
                    (slot, value)
                }).collect();
                assert_eq!(reference.len(), (n - fanout) as usize);
                check(&new, &reference);
                let counts: BTreeMap<_, _> = new.textures.iter()
                    .map(|(&r, slots)| (r, slots.len() as u32)).collect();
                assert_eq!(old.textures, counts);
                old_times.sort_by(f64::total_cmp);
                new_times.sort_by(f64::total_cmp);
                println!(
                    "mode={mode} slots={n} fanout={fanout} scan_us={:.3} index_us={:.3} speedup={:.3}",
                    old_times[3], new_times[3], old_times[3] / new_times[3]
                );
            }
        }
    }
    println!("PASS: all 27 synthetic slot configurations matched");
}
