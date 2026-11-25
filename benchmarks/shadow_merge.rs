//! Standalone synthetic benchmark for the shadow copy-back merge.
//! No GPU, game assets, external dependencies, or runtime changes.
#[path = "../crates/victory-gpu/src/shadow/merge.rs"]
mod candidate;

use std::hint::black_box;
use std::time::Instant;

type Merge = fn(&mut [u8], &mut [u8], &[u8]) -> bool;

#[inline(never)]
fn original(title: &mut [u8], host: &mut [u8], old: &[u8]) -> bool {
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

#[inline(never)]
fn select(title: &mut [u8], host: &mut [u8], old: &[u8]) -> bool {
    let mut changed = false;
    for ((t, h), o) in title.iter_mut().zip(host.iter_mut()).zip(old) {
        let merged = if *h == *o { *t } else { *h };
        changed |= merged != *t;
        *t = merged;
        *h = merged;
    }
    changed
}

#[inline(never)]
fn avx2(title: &mut [u8], host: &mut [u8], old: &[u8]) -> bool {
    candidate::merge(title, host, old)
}

fn next(state: &mut u32) -> u32 {
    *state ^= *state << 13;
    *state ^= *state >> 17;
    *state ^= *state << 5;
    *state
}

fn check(title: &[u8], host: &[u8], old: &[u8], start: usize, len: usize) {
    let range = start..start + len;
    let mut expected_title = title.to_vec();
    let mut expected_host = host.to_vec();
    let expected = original(
        &mut expected_title[range.clone()],
        &mut expected_host[range.clone()],
        &old[range.clone()],
    );
    for implementation in [select as Merge, avx2] {
        let mut actual_title = title.to_vec();
        let mut actual_host = host.to_vec();
        let changed = implementation(
            &mut actual_title[range.clone()],
            &mut actual_host[range.clone()],
            &old[range.clone()],
        );
        assert_eq!(changed, expected);
        assert!(actual_title == expected_title);
        assert!(actual_host == expected_host);
    }
}

fn verify() {
    let count = 1usize << 24;
    let title: Vec<_> = (0..count).map(|i| i as u8).collect();
    let host: Vec<_> = (0..count).map(|i| (i >> 8) as u8).collect();
    let old: Vec<_> = (0..count).map(|i| (i >> 16) as u8).collect();
    check(&title, &host, &old, 0, count);
    let mut state = 0x09c4_f123;
    let mut cases = 0;
    for len in 0..=256 {
        for offset in 0..32 {
            let size = len + 64;
            let title: Vec<_> = (0..size).map(|_| next(&mut state) as u8).collect();
            let host: Vec<_> = (0..size).map(|_| next(&mut state) as u8).collect();
            let old: Vec<_> = host.iter().enumerate().map(|(i, &h)| {
                if i % 3 == 0 { next(&mut state) as u8 } else { h }
            }).collect();
            check(&title, &host, &old, offset, len);
            cases += 1;
        }
    }
    println!("PASS: {count} byte triples and {cases} length/alignment cases");
}

fn main() {
    verify();
    #[cfg(target_arch = "x86_64")]
    println!("AVX2 supported: {}", std::arch::is_x86_feature_detected!("avx2"));
    let size = 4usize << 20;
    let implementations: [Merge; 3] = [original, select, avx2];
    let mut state = 0x09c4_f123;
    for changed_percent in [1, 50, 100] {
        let old: Vec<_> = (0..size).map(|_| next(&mut state) as u8).collect();
        let title: Vec<_> = (0..size).map(|_| next(&mut state) as u8).collect();
        let host: Vec<_> = old.iter().map(|&o| {
            if next(&mut state) % 100 < changed_percent {
                o.wrapping_add(1 + (next(&mut state) % 255) as u8)
            } else {
                o
            }
        }).collect();
        let mut a = title.clone();
        let mut b = host.clone();
        for chunk in [256, 4096, 65536, 1048576] {
            let mut samples = [[0.0f64; 7]; 3];
            for rep in 0..7 {
                for order in 0..3 {
                    let k = (rep + order) % 3;
                    a.copy_from_slice(&title);
                    b.copy_from_slice(&host);
                    let start = Instant::now();
                    for ((t, h), o) in a.chunks_exact_mut(chunk)
                        .zip(b.chunks_exact_mut(chunk))
                        .zip(old.chunks_exact(chunk))
                    {
                        black_box(implementations[k](black_box(t), black_box(h), black_box(o)));
                    }
                    samples[k][rep] = start.elapsed().as_secs_f64() * 1000.0;
                    black_box((&a, &b));
                }
            }
            for series in &mut samples {
                series.sort_by(f64::total_cmp);
            }
            println!(
                "changed={changed_percent}% chunk={chunk} original_ms={:.6} select_ms={:.6} candidate_ms={:.6}",
                samples[0][3], samples[1][3], samples[2][3],
            );
        }
    }
}
