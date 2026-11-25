//! Synthetic benchmark of the actual readback overlap index.
#[path = "../crates/victory-gpu/src/memory/precise_ranges.rs"]
mod candidate;

use candidate::PreciseRanges;
use std::{hint::black_box, time::Instant};

const PAGE: u64 = 65536;

fn next(state: &mut u64) -> u64 {
    *state ^= *state << 13;
    *state ^= *state >> 7;
    *state ^= *state << 17;
    *state
}

fn linear(ranges: &[(u64, u64)], queries: &[u64]) -> Vec<bool> {
    queries.iter().map(|&from| {
        ranges.iter().any(|&(start, len)| start < from + PAGE && from < start + len)
    }).collect()
}

fn indexed(ranges: &[(u64, u64)], queries: &[u64]) -> Vec<bool> {
    let index = PreciseRanges::new(ranges);
    queries.iter().map(|&from| index.overlaps(from, from + PAGE)).collect()
}

fn main() {
    let mut rng = 0x5a1d_c9e7u64;
    for density in [1u64, 16] {
        for n in [0, 1, 4, 16, 64, 256, 1024] {
            let ranges: Vec<_> = (0..n).map(|_| {
                let start = next(&mut rng) % (65536 * PAGE / density);
                (start, next(&mut rng) % (4 * PAGE))
            }).collect();
            for q in [1, 16, 256, 4096] {
                let queries: Vec<_> = (0..q)
                    .map(|_| next(&mut rng) % 65536 * PAGE)
                    .collect();
                let expected = linear(&ranges, &queries);
                assert_eq!(indexed(&ranges, &queries), expected);
                let hits = expected.iter().filter(|&&x| x).count();
                let repeats = (32768 / q).max(8);
                let mut samples = [[0.0f64; 7]; 2];
                type Runner = fn(&[(u64, u64)], &[u64]) -> Vec<bool>;
                let runners: [Runner; 2] = [linear, indexed];
                for rep in 0..7 {
                    for k in [rep % 2, 1 - rep % 2] {
                        let start = Instant::now();
                        for _ in 0..repeats {
                            black_box(runners[k](black_box(&ranges), black_box(&queries)));
                        }
                        samples[k][rep] = start.elapsed().as_secs_f64() * 1e6 / repeats as f64;
                    }
                }
                for series in &mut samples {
                    series.sort_by(f64::total_cmp);
                }
                println!(
                    "density={density} ranges={n} queries={q} hits={hits} linear_us={:.4} indexed_us={:.4}",
                    samples[0][3], samples[1][3]
                );
            }
        }
    }
    println!("PASS: all 56 configurations matched the original; index construction included");
}
