//! Compare backwards dataflow with a path-to-first-use oracle.
use super::*;

const REGISTERS: [Reg; 16] = [
    Reg::S(0),
    Reg::S(1),
    Reg::S(63),
    Reg::S(64),
    Reg::S(105),
    Reg::S(106),
    Reg::S(126),
    Reg::S(127),
    Reg::Scc,
    Reg::V(0),
    Reg::V(1),
    Reg::V(62),
    Reg::V(63),
    Reg::V(126),
    Reg::V(127),
    Reg::V(255),
];

fn mask(bits: u64) -> RegSet {
    let mut set = [0; REGS.div_ceil(64)];
    for (i, &reg) in REGISTERS.iter().enumerate() {
        if bits & (1 << i) != 0 {
            insert(&mut set, reg);
        }
    }
    set
}

// Independently follow paths until the register is read or overwritten.
fn reaches_use(blocks: &[Block], uses: &[RegSet], defs: &[RegSet], start: usize, reg: Reg) -> bool {
    let mut seen = vec![false; blocks.len()];
    let mut work = vec![start];
    while let Some(b) = work.pop() {
        if seen[b] {
            continue;
        }
        seen[b] = true;
        if contains(&uses[b], reg) {
            return true;
        }
        if !contains(&defs[b], reg) {
            work.extend(blocks[b].exit.successors());
        }
    }
    false
}

fn check(exits: Vec<Exit>, uses: Vec<RegSet>, defs: Vec<RegSet>) {
    let mut blocks: Vec<_> = exits
        .into_iter()
        .enumerate()
        .map(|(offset, exit)| Block {
            offset,
            preds: Vec::new(),
            phis: Vec::new(),
            insts: Vec::new(),
            exit,
        })
        .collect();
    link(&mut blocks);
    let order = reverse_postorder(&blocks);
    let (actual_in, actual_out) = solve_liveness(&blocks, &order, &uses, &defs);
    let empty = [0; REGS.div_ceil(64)];
    let mut expected_in = vec![empty; blocks.len()];
    let mut expected_out = vec![empty; blocks.len()];
    for &b in &order {
        for reg in REGISTERS {
            if reaches_use(&blocks, &uses, &defs, b, reg) {
                insert(&mut expected_in[b], reg);
            }
            if blocks[b]
                .exit
                .successors()
                .iter()
                .any(|&s| reaches_use(&blocks, &uses, &defs, s, reg))
            {
                insert(&mut expected_out[b], reg);
            }
        }
    }
    assert_eq!(actual_in, expected_in);
    assert_eq!(actual_out, expected_out);
}

#[test]
fn duplicate_edges_and_unreachable_predecessors() {
    check(
        vec![
            Exit::Branch { taken: 1, not_taken: 1 },
            Exit::Branch { taken: 1, not_taken: 2 },
            Exit::End,
            Exit::Jump(1),
            Exit::Jump(4),
        ],
        vec![mask(0), mask(1), mask(1 << 15), mask(2), mask(4)],
        vec![mask(1), mask(0), mask(0), mask(0), mask(0)],
    );
}

#[test]
fn generated_control_flow_matches_path_oracle() {
    for seed in 1..=192u64 {
        let mut state = seed;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        let n = 4 + (seed as usize % 29);
        let mut exits = Vec::with_capacity(n);
        let mut uses = Vec::with_capacity(n);
        let mut defs = Vec::with_capacity(n);
        for b in 0..n {
            let random = (next() % n as u64) as usize;
            let forward = (b + 1).min(n - 1);
            let exit = match seed % 6 {
                0 if b + 1 < n => Exit::Jump(forward),
                1 if b + 1 < n => Exit::Branch { taken: forward, not_taken: random },
                2 if b + 1 < n => Exit::Branch { taken: forward, not_taken: forward },
                3 => Exit::Jump(random),
                _ => match next() % 4 {
                    0 => Exit::End,
                    1 => Exit::Jump(random),
                    _ => Exit::Branch { taken: random, not_taken: (next() % n as u64) as usize },
                },
            };
            exits.push(exit);
            uses.push(mask(next() & next()));
            defs.push(mask(next() & next()));
        }
        check(exits, uses, defs);
    }
}


// Original fixed-point sweep from baseline 13f91ca, after use/def construction.
fn reference_sweep(
    blocks: &[Block],
    order: &[usize],
    uses: &[RegSet],
    defs: &[RegSet],
) -> (Vec<RegSet>, Vec<RegSet>) {
    let empty = [0; REGS.div_ceil(64)];
    let mut live_in = vec![empty; blocks.len()];
    let mut live_out = vec![empty; blocks.len()];
    let mut changed = true;
    while changed {
        changed = false;
        for &b in order.iter().rev() {
            let mut out = empty;
            for s in blocks[b].exit.successors() {
                for (o, i) in out.iter_mut().zip(&live_in[s]) {
                    *o |= i;
                }
            }
            let mut inn = empty;
            for w in 0..inn.len() {
                inn[w] = uses[b][w] | out[w] & !defs[b][w];
            }
            if inn != live_in[b] || out != live_out[b] {
                (live_in[b], live_out[b]) = (inn, out);
                changed = true;
            }
        }
    }
    (live_in, live_out)
}

#[test]
#[ignore = "release-only synthetic liveness benchmark"]
fn bench_liveness_worklist() {
    use std::hint::black_box;
    use std::time::Instant;

    for n in [32usize, 128, 512, 2048] {
        for kind in ["straight", "local_loops", "long_loop"] {
            let mut blocks: Vec<_> = (0..n)
                .map(|b| {
                    let exit = if b + 1 == n {
                        Exit::End
                    } else if kind == "long_loop" && b + 2 == n {
                        Exit::Branch { taken: 0, not_taken: b + 1 }
                    } else if kind == "local_loops" && b % 16 == 15 {
                        Exit::Branch { taken: b - 7, not_taken: b + 1 }
                    } else {
                        Exit::Jump(b + 1)
                    };
                    Block {
                        offset: b,
                        preds: Vec::new(),
                        phis: Vec::new(),
                        insts: Vec::new(),
                        exit,
                    }
                })
                .collect();
            link(&mut blocks);
            let order = reverse_postorder(&blocks);
            assert_eq!(order.len(), n);
            let uses: Vec<_> = (0..n)
                .map(|b| mask(if b % 17 == 0 { 1 << ((b / 17) % 16) } else { 0 }))
                .collect();
            let defs: Vec<_> = (0..n)
                .map(|b| mask(if b % 29 == 0 { 1 << ((b / 29 + 3) % 16) } else { 0 }))
                .collect();
            let expected = reference_sweep(&blocks, &order, &uses, &defs);
            assert_eq!(solve_liveness(&blocks, &order, &uses, &defs), expected);
            let repeats = (32768 / n).max(8);
            let measure = |reference: bool| {
                let start = Instant::now();
                for _ in 0..repeats {
                    let b = black_box(blocks.as_slice());
                    let o = black_box(order.as_slice());
                    let u = black_box(uses.as_slice());
                    let d = black_box(defs.as_slice());
                    let _ = black_box(if reference {
                        reference_sweep(b, o, u, d)
                    } else {
                        solve_liveness(b, o, u, d)
                    });
                }
                start.elapsed().as_secs_f64() * 1e6 / repeats as f64
            };
            let mut old = Vec::new();
            let mut new = Vec::new();
            for round in 0..7 {
                if round % 2 == 0 {
                    old.push(measure(true));
                    new.push(measure(false));
                } else {
                    new.push(measure(false));
                    old.push(measure(true));
                }
            }
            old.sort_by(f64::total_cmp);
            new.sort_by(f64::total_cmp);
            println!(
                "kind={kind} blocks={n} sweep_us={:.3} worklist_us={:.3} speedup={:.3}",
                old[3], new[3], old[3] / new[3]
            );
        }
    }
    println!("PASS: all 12 synthetic liveness configurations matched the reference");
}
