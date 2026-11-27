function Get-BenchmarkRows([string]$s) {
    foreach($line in ($s -split '\r?\n')) {
        $a=$null; $b=$null; $c=$null; $unit='us'; $scenario=''
        $line = $line -replace '^test .+? \.\.\. ', ''
        if ($line -match '\b(?<family>UPLOAD_PLAN_BENCH|CARD_LEVEL_BENCH|SNAPSHOT_SWEEP_BENCH)\s+(?<case>[^:\r\n]+):\s*(?:(?<size>\d+ ranges),\s*)?old(?: median)?\s+(?<old>[0-9]+(?:\.[0-9]+)?)\s+(?<oldUnit>us|ms),\s*new(?: median)?\s+(?<new>[0-9]+(?:\.[0-9]+)?)\s+(?<newUnit>us|ms),\s*(?:old/new\s+)?[0-9]+(?:\.[0-9]+)?x(?:;\s*profile=(?<profile>\w+))?\s*$') {
            $scenario = (@($Matches.family, $Matches.case, $Matches.size, $Matches.profile) | Where-Object { $_ }) -join ' / '
            $a = [double]::Parse($Matches.old, [cultureinfo]::InvariantCulture)
            $b = [double]::Parse($Matches.new, [cultureinfo]::InvariantCulture)
            if ($Matches.oldUnit -eq 'ms') { $a *= 1000 }
            if ($Matches.newUnit -eq 'ms') { $b *= 1000 }
        } elseif ($line -match '^density=(\d+) ranges=(\d+) queries=(\d+) hits=(\d+) linear_us=([0-9]+(?:\.[0-9]+)?) indexed_us=([0-9]+(?:\.[0-9]+)?)(?: adaptive_us=([0-9]+(?:\.[0-9]+)?))?\s*$') {
            $scenario="D$($Matches[1]) / $($Matches[2]) ranges / $($Matches[3]) queries / $($Matches[4]) hits"; $a=[double]::Parse($Matches[5],[cultureinfo]::InvariantCulture); $b=[double]::Parse($Matches[6],[cultureinfo]::InvariantCulture); if($Matches[7]){$c=[double]::Parse($Matches[7],[cultureinfo]::InvariantCulture)}
        } elseif ($line -match '^changed=(\d+)% chunk=(\d+) original_ms=([0-9]+(?:\.[0-9]+)?) select_ms=([0-9]+(?:\.[0-9]+)?) candidate_ms=([0-9]+(?:\.[0-9]+)?)\s*$') {
            $scenario="$($Matches[1])% changed / $($Matches[2]) B"; $unit='ms'; $a=[double]::Parse($Matches[3],[cultureinfo]::InvariantCulture); $b=[double]::Parse($Matches[4],[cultureinfo]::InvariantCulture); $c=[double]::Parse($Matches[5],[cultureinfo]::InvariantCulture)
        } elseif ($line -match '^case=(\S+) writers=(\d+) pages=(\d+) original_calls=(\d+) candidate_calls=(\d+) original_us=([0-9]+(?:\.[0-9]+)?) candidate_us=([0-9]+(?:\.[0-9]+)?)\s*$') {
            $scenario="$($Matches[1]) / $($Matches[2]) writers / $($Matches[3]) pages / calls $($Matches[4])->$($Matches[5])"; $a=[double]::Parse($Matches[6],[cultureinfo]::InvariantCulture); $b=[double]::Parse($Matches[7],[cultureinfo]::InvariantCulture)
        } elseif ($line -match '^kind=(\S+) blocks=(\d+) (?:reference|sweep)_us=([0-9]+(?:\.[0-9]+)?) (?:scc|worklist)_us=([0-9]+(?:\.[0-9]+)?) speedup=[0-9]+(?:\.[0-9]+)?$') {
            $scenario="$($Matches[1]) / $($Matches[2]) blocks"; $a=[double]::Parse($Matches[3],[cultureinfo]::InvariantCulture); $b=[double]::Parse($Matches[4],[cultureinfo]::InvariantCulture)
        } elseif ($line -match '^mode=(\S+) slots=(\d+) fanout=(\d+) scan_us=([0-9]+(?:\.[0-9]+)?) index_us=([0-9]+(?:\.[0-9]+)?) speedup=[0-9]+(?:\.[0-9]+)?$') {
            $scenario="$($Matches[1]) / $($Matches[2]) slots / fanout $($Matches[3])"; $a=[double]::Parse($Matches[4],[cultureinfo]::InvariantCulture); $b=[double]::Parse($Matches[5],[cultureinfo]::InvariantCulture)
        }
        if ($a -le 0 -or $b -le 0 -or [double]::IsInfinity($a) -or [double]::IsInfinity($b)) { continue }
        if ($null -ne $c -and ($c -le 0 -or [double]::IsInfinity($c))) { continue }
        $best = if ($null -ne $c) { [math]::Min($b, $c) } else { $b }
        [pscustomobject]@{
            scenario = $scenario
            original = $a
            indexed = $b
            adaptive = $c
            speedup = $a / $best
            unit = $unit
            timeReductionPercent = (1 - $best / $a) * 100
            timeSaved = $a - $best
        }
    }
}

function Get-BenchmarkStepRows([string]$stdout, [string]$stderr) {
    $stdoutCounts = @{}
    foreach ($row in (Get-BenchmarkRows $stdout)) {
        $key = ConvertTo-Json -InputObject $row -Compress
        $stdoutCounts[$key]++
        $row
    }
    foreach ($row in (Get-BenchmarkRows $stderr)) {
        $key = ConvertTo-Json -InputObject $row -Compress
        if ($stdoutCounts[$key] -gt 0) { $stdoutCounts[$key]-- }
        else { $row }
    }
}

function Format-BenchmarkTable($rows) {
    if (!$rows.Count) { return }
    ''
    '### Benchmark measurements'
    '| Scenario | Original | Optimized | Speedup | Time saved | Reduction |'
    '| --- | ---: | ---: | ---: | ---: | ---: |'
    foreach ($row in $rows) {
        $scenario = $row.scenario.Replace('|', '\|')
        $optimized = if ($null -eq $row.adaptive) { $row.indexed } else { [math]::Min($row.indexed, $row.adaptive) }
        [string]::Format([cultureinfo]::InvariantCulture,
            '| {0} | {1:F3} {2} | {3:F3} {2} | {4:F2}x | {5:F3} {2} | {6:F2}% |',
            $scenario, $row.original, $row.unit, $optimized, $row.speedup, $row.timeSaved, $row.timeReductionPercent)
    }
}


function Get-BenchmarkPercentile([double[]]$sorted, [double]$fraction) {
    $position = ($sorted.Count - 1) * $fraction
    $lower = [int][math]::Floor($position)
    $upper = [int][math]::Ceiling($position)
    $sorted[$lower] + ($sorted[$upper] - $sorted[$lower]) * ($position - $lower)
}

function Get-BenchmarkStatistics([double[]]$values) {
    [array]::Sort($values)
    $mean = ($values | Measure-Object -Average).Average
    $sumSquares = 0.0
    foreach ($value in $values) { $sumSquares += [math]::Pow($value - $mean, 2) }
    [pscustomobject]@{
        median = Get-BenchmarkPercentile $values 0.5
        minimum = $values[0]
        maximum = $values[-1]
        sampleStandardDeviation = $(if ($values.Count -gt 1) { [math]::Sqrt($sumSquares / ($values.Count - 1)) })
        interquartileRange = (Get-BenchmarkPercentile $values 0.75) - (Get-BenchmarkPercentile $values 0.25)
    }
}

function Get-BenchmarkSummaries($steps) {
    $successfulRows = foreach ($step in $steps) {
        if ($step.Status -ne 'PASS') { continue }
        foreach ($row in $step.Benchmarks) {
            [pscustomobject]@{
                command = $step.Command
                scenario = $row.scenario
                unit = $row.unit
                hasAdaptive = $null -ne $row.adaptive
                row = $row
            }
        }
    }
    foreach ($group in ($successfulRows | Group-Object -Property command, scenario, unit, hasAdaptive -CaseSensitive)) {
        if ($group.Count -lt 2) { continue }
        $first = $group.Group[0]
        $rows = $group.Group.row
        $original = Get-BenchmarkStatistics $rows.original
        $indexed = Get-BenchmarkStatistics $rows.indexed
        $adaptive = $null
        $optimized = $indexed
        $variant = 'indexed'
        if ($first.hasAdaptive) {
            $adaptive = Get-BenchmarkStatistics $rows.adaptive
            if ($adaptive.median -lt $indexed.median) {
                $optimized = $adaptive
                $variant = 'adaptive'
            }
        }
        [pscustomobject]@{
            command = $first.command
            scenario = $first.scenario
            unit = $first.unit
            sampleCount = $group.Count
            original = $original
            indexed = $indexed
            adaptive = $adaptive
            optimizedVariant = $variant
            speedup = $original.median / $optimized.median
            timeSaved = $original.median - $optimized.median
            timeReductionPercent = (1 - $optimized.median / $original.median) * 100
        }
    }
}

function Format-BenchmarkSummaryTable($summaries) {
    if (!$summaries.Count) { return }
    ''
    '### Repeated benchmark measurements'
    'Statistics describe the reported measurements of successful steps. Some benchmarks emit a median of internal trials per measurement.'
    '| Scenario | Samples | Original median | Optimized median | Speedup | Time saved | Reduction |'
    '| --- | ---: | ---: | ---: | ---: | ---: | ---: |'
    foreach ($summary in $summaries) {
        $scenario = $summary.scenario.Replace('|', '\|')
        $optimized = $summary.($summary.optimizedVariant)
        [string]::Format([cultureinfo]::InvariantCulture,
            '| {0} | {1} | {2:F3} {3} | {4:F3} {3} | {5:F2}x | {6:F3} {3} | {7:F2}% |',
            $scenario, $summary.sampleCount, $summary.original.median, $summary.unit, $optimized.median,
            $summary.speedup, $summary.timeSaved, $summary.timeReductionPercent)
    }
}
