//! Synthetic Windows protection benchmark. No title memory or game data.
#[path = "../crates/victory-gpu/src/watch/page_batch.rs"]
mod candidate;

use std::collections::BTreeSet;
use std::ffi::c_void;
use std::hint::black_box;
use std::time::Instant;

const PAGE: usize = 64 << 10;
const COUNT: usize = 1024;
const MEM_COMMIT_RESERVE: u32 = 0x3000;
const MEM_RELEASE: u32 = 0x8000;
const PAGE_READONLY: u32 = 2;
const PAGE_READWRITE: u32 = 4;

#[link(name = "kernel32")]
unsafe extern "system" {
    fn VirtualAlloc(addr: *mut c_void, size: usize, kind: u32, protect: u32) -> *mut c_void;
    fn VirtualFree(addr: *mut c_void, size: usize, kind: u32) -> i32;
    fn VirtualProtect(addr: *mut c_void, size: usize, protect: u32, old: *mut u32) -> i32;
}

struct Pool(*mut c_void);
impl Pool {
    fn new() -> Self {
        // SAFETY: reserve and commit a private anonymous allocation.
        let ptr = unsafe { VirtualAlloc(std::ptr::null_mut(), COUNT * PAGE, MEM_COMMIT_RESERVE, PAGE_READWRITE) };
        assert!(!ptr.is_null());
        Self(ptr)
    }
    fn protect(&self, start: usize, end: usize, protection: u32) {
        assert!(start < end && end <= COUNT);
        let mut old = 0;
        // SAFETY: range stays inside this private allocation; old is valid.
        let ok = unsafe {
            VirtualProtect(self.0.cast::<u8>().add(start * PAGE).cast(), (end - start) * PAGE, protection, &mut old)
        };
        assert_ne!(ok, 0, "VirtualProtect failed: {}", std::io::Error::last_os_error());
    }
}
impl Drop for Pool {
    fn drop(&mut self) {
        // SAFETY: this is the original allocation base, owned by self.
        unsafe { VirtualFree(self.0, 0, MEM_RELEASE) };
    }
}

fn original(pages: &[usize], busy: &[(usize, usize)]) -> Vec<usize> {
    pages.iter().copied().filter(|p| !busy.iter().any(|&(a,b)| (a..b).contains(p))).collect()
}

fn apply(pool: &Pool, pages: &[usize]) -> (usize, BTreeSet<usize>) {
    // Mirrors watch::protect's grouping of consecutive, unprotected pages.
    // All memory is mapped and committed, so the fallback path is not tested.
    let mut protected = BTreeSet::new();
    let mut i = 0;
    let mut calls = 0;
    while i < pages.len() {
        if protected.contains(&pages[i]) {
            i += 1;
            continue;
        }
        let first = i;
        while i + 1 < pages.len() && pages[i + 1] == pages[i] + 1 && !protected.contains(&pages[i+1]) {
            i += 1;
        }
        let run = &pages[first..=i];
        pool.protect(run[0], run[run.len()-1] + 1, PAGE_READONLY);
        calls += 1;
        protected.extend(run);
        i += 1;
    }
    (calls, protected)
}

fn next(state: &mut u64) -> u64 {
    *state ^= *state << 13;
    *state ^= *state >> 7;
    *state ^= *state << 17;
    *state
}

fn main() {
    let pool = Pool::new();
    let mut state = 0x8765_1234_u64;
    let sorted: Vec<_> = (0..COUNT).collect();
    let mut shuffled = sorted.clone();
    for i in (1..shuffled.len()).rev() {
        shuffled.swap(i, (next(&mut state) % (i as u64 + 1)) as usize);
    }
    let mut aliases = shuffled.clone();
    aliases.extend_from_slice(&shuffled[..256]);
    for (name, pages) in [("sorted", &sorted), ("shuffled", &shuffled), ("aliases", &aliases)] {
        for writers in [0, 4, 32, 128] {
            let busy: Vec<_> = (0..writers).map(|_| {
                let start = next(&mut state) as usize % COUNT;
                (start, (start + 1 + next(&mut state) as usize % 4).min(COUNT))
            }).collect();
            let expected: BTreeSet<_> = original(pages, &busy).into_iter().collect();
            assert_eq!(candidate::eligible(pages, &busy).into_iter().collect::<BTreeSet<_>>(), expected);
            let planners: [fn(&[usize], &[(usize,usize)]) -> Vec<usize>;2] = [original, candidate::eligible];
            let mut times = [[0.0; 9];2];
            let mut calls = [0;2];
            for rep in 0..9 {
                for k in [rep % 2, 1-rep % 2] {
                    pool.protect(0, COUNT, PAGE_READWRITE);
                    let start = Instant::now();
                    let plan = planners[k](black_box(pages), black_box(&busy));
                    let (n, actual) = apply(&pool, &plan);
                    times[k][rep] = start.elapsed().as_secs_f64() * 1e6;
                    assert_eq!(actual, expected);
                    calls[k] = n;
                }
            }
            for t in &mut times {
                t.sort_by(f64::total_cmp);
            }
            println!("case={name} writers={writers} pages={} original_calls={} candidate_calls={} original_us={:.3} candidate_us={:.3}", expected.len(), calls[0], calls[1], times[0][4], times[1][4]);
        }
    }
    println!("PASS: all 12 cases preserved identical protected page sets across nine runs");
}
