$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Benchmark.ps1')

$upload = 'UPLOAD_PLAN_BENCH short-heavy: 80000 ranges, old median 5123.850 us, new median 1358.175 us, old/new 3.773x; profile=debug'
$sweep = 'SNAPSHOT_SWEEP_BENCH ranges=80000 fragmented=true: old 2.000 ms, new 500.000 us, 4.000x'
$legacy = 'kind=loop blocks=50 reference_us=25.000 scc_us=5.000 speedup=5.000'
$before = [threading.thread]::CurrentThread.CurrentCulture
try {
    [threading.thread]::CurrentThread.CurrentCulture = [cultureinfo]'hu-HU'
    $nl = [Environment]::NewLine
    $card = 'CARD_LEVEL_BENCH steps=512 copies=true overlap=false: old 10.000 us, new 4.000 us, 2.500x'
    $cardRows = @(Get-BenchmarkStepRows '' "test host::card_steps::tests::bench ... $card")
    if ($cardRows.Count -ne 1 -or $cardRows[0].scenario -notlike '*steps=512 copies=true overlap=false' -or $cardRows[0].speedup -ne 2.5) {
        throw 'Card level benchmark was not captured from Rust stderr.'
    }
    $steps = @(
        @{ Status = 'PASS'; Command = 'cargo test --release -- card'; Benchmarks = $cardRows }
        @{ Status = 'PASS'; Command = 'cargo test --release -- card'; Benchmarks = @(Get-BenchmarkRows ($card.Replace('new 4.000', 'new 6.000').Replace('old 10.000', 'old 14.000'))) }
        @{ Status = 'PASS'; Command = 'cargo test --release -- card'; Benchmarks = @(Get-BenchmarkRows ($card.Replace('10.000', '18.000').Replace('4.000', '8.000'))) }
        @{ Status = 'FAIL'; Command = 'cargo test --release -- card'; Benchmarks = $cardRows }
        @{ Status = 'PASS'; Command = 'cargo test -- card'; Benchmarks = $cardRows }
    )
    $summaries = @(Get-BenchmarkSummaries $steps)
    if ($summaries.Count -ne 1) { throw 'Incompatible commands were grouped or the repeated measurement was lost.' }
    $summary = $summaries[0]
    if ($summary.sampleCount -ne 3 -or $summary.original.median -ne 14 -or $summary.original.minimum -ne 10 -or
        $summary.original.maximum -ne 18 -or $summary.original.sampleStandardDeviation -ne 4 -or
        $summary.original.interquartileRange -ne 4 -or $summary.timeSaved -ne 8) {
        throw 'Repeated measurements or statistics are incorrect.'
    }
    if (((Format-BenchmarkSummaryTable $summaries) -join $nl) -notmatch '14\.000 us.*6\.000 us.*2\.33x') {
        throw 'Benchmark summary is missing or uses localized numbers.'
    }
    $even = Get-BenchmarkStatistics @(8, 4)
    if ($even.median -ne 6 -or $even.interquartileRange -ne 2) { throw 'Even-sample percentile interpolation failed.' }
    $rows = @(Get-BenchmarkStepRows ("test gpu::upload ... $upload" + $nl + $legacy) ($upload + $nl + $sweep))
    if ($rows.Count -ne 3) { throw 'Expected three rows and one mirrored measurement.' }
    if ($rows[0].original -ne 5123.850 -or $rows[0].indexed -ne 1358.175 -or $rows[0].scenario -notlike '*/ debug') {
        throw 'Upload parser lost the measured times or profile.'
    }
    if ($rows[1].speedup -ne 5 -or $rows[2].original -ne 2000 -or $rows[2].speedup -ne 4 -or
        $rows[2].timeSaved -ne 1500 -or $rows[2].timeReductionPercent -ne 75) {
        throw 'Legacy parsing or normalized comparison math failed.'
    }
    $repeats = @(Get-BenchmarkStepRows ($upload + $nl + $upload) $upload)
    if ($repeats.Count -ne 2) { throw 'Identical repetitions within a stream must be retained.' }
    foreach ($invalid in @('0.000', '5..2', '5,2')) {
        if (@(Get-BenchmarkRows ($upload.Replace('5123.850', $invalid))).Count) { throw "Invalid time accepted: $invalid" }
    }
    if (((Format-BenchmarkTable $rows) -join $nl) -notmatch '2000\.000 us.*4\.00x.*75\.00%') {
        throw 'Report formatting depends on the Windows locale or omitted results.'
    }
} finally {
    [threading.thread]::CurrentThread.CurrentCulture = $before
}
'Benchmark checks passed.'
