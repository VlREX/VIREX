# Run from Windows PowerShell 5.1 -STA in a fresh process.
[CmdletBinding()]
param([switch]$WithCargo, [string]$PreviewPath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$projectPath=Split-Path -Parent $PSScriptRoot
$tempBase=[IO.Path]::GetTempPath()
$fixture=Join-Path $tempBase ('virex-desktop-'+[guid]::NewGuid().ToString('N'))
$oldAppData=$env:LOCALAPPDATA
$oldOffline=$env:CARGO_NET_OFFLINE
$env:LOCALAPPDATA=$fixture
$env:CARGO_NET_OFFLINE='true'
$sample=Join-Path $fixture 'Árvíz Cargo projekt'
$null=[IO.Directory]::CreateDirectory((Join-Path $sample 'src'))
[IO.File]::WriteAllText((Join-Path $sample 'Cargo.toml'),"[package]$([Environment]::NewLine)name = 'studio_fixture'$([Environment]::NewLine)version = '0.1.0'$([Environment]::NewLine)edition = '2021'")
[IO.File]::WriteAllText((Join-Path $sample 'src\lib.rs'),'#[test] fn studio_smoke() { assert_eq!(2 + 2, 4); }')
$script:phase=0
$script:passed=$false
$script:failure=''
$deadline=[DateTime]::UtcNow.AddSeconds(300)
$driver=New-Object Windows.Forms.Timer
$driver.Interval=150
$driver.Add_Tick({
    try {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Desktop test timeout.' }
        if ($script:phase -eq 0) {
            if (!$form.Visible) { return }
            if ($combo.Items.Count -ne 20 -or $tabs.TabPages.Count -ne 4) { throw 'Missing target or workspace tab.' }
            if (!$updateButton.Enabled -or $ckBench.Enabled -or $combo.SelectedItem.Mode -ne 'belobug') { throw 'Startup controls unavailable.' }
            if ($PreviewPath) {
                $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
                try { $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
            }
            $form.Size=New-Object Drawing.Size(800,590)
            $tabs.SelectedIndex=3
            if ($reviewPages.TabPages.Count -ne 2) { throw 'AI Review panels missing.' }
            $prompt=New-ReviewPrompt 'fixture evidence'
            if ($prompt -notmatch 'fixture evidence' -or $prompt -match 'BEGIN PEER REVIEW|Claude') { throw 'GPT-only review prompt invalid.' }
            $script:reviewEvidence.Text='fixture evidence'
            $gptCopy.PerformClick()
            if ($reviewPages.SelectedIndex -ne 1) { throw 'GPT review did not open without a peer response.' }
            if ([Windows.Forms.Clipboard]::GetText() -ne $prompt) { throw 'GPT prompt clipboard mismatch.' }
            $script:reviewEvidence.Clear()

            $combo.SelectedIndex=1
            Set-LocalProject $sample
            if ($ckBench.Enabled -or $ckFull.Enabled -or $ckWarp.Enabled -or !$ckTest.Enabled) { throw 'Invalid local mode controls.' }
            $combo.SelectedIndex=3
            if (!$ckBench.Enabled -or !$ckFull.Enabled) { throw 'Failed to restore pinned mode.' }
            $combo.SelectedIndex=1
            if (!$WithCargo) { $script:passed=$true; $driver.Stop(); $form.Close(); return }
            $target=ConvertTo-RepositoryTarget 'https://github.com/Belobug/VIctory-Belobug-AMD.git'
            if ($target.Name -ne 'Belobug/VIctory-Belobug-AMD' -or $target.CacheId -ne $belobugTarget.CacheId) { throw 'GitHub URL normalization failed.' }
            foreach ($invalid in @('file:///local','a/..','-x/name','https://example.com/a/b','user/repo --flag')) {
                $rejected=$false
                try { ConvertTo-RepositoryTarget $invalid | Out-Null } catch { $rejected=$true }
                if (!$rejected) { throw "Unexpected repository input: $invalid" }
            }
            $ckRepeat.Checked=$false
            $ckClippy.Checked=$false
            # Consent applies exclusively to the temporary, locally generated Rust fixture.
            function script:Confirm-StudioRun([string]$message) { return ($workDir -eq $sample) }
            $script:phase=1
            $runButton.PerformClick()
            if ($script:runState -ne 'RUNNING') { throw 'UI did not start the fixture.' }
        } elseif ($script:phase -eq 1 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if ($runState -ne 'PASS' -or $report -notmatch '1 passed' -or $report -notmatch 'Local workspace:' -or $report -match 'Pinned commit:') { throw $report }
            if (!$updateButton.Enabled -or !$copyButton.Enabled) { throw 'Post-run controls unavailable.' }
            # Redirect only clone/fetch transport to a local fixture. All Git commands and validation gates are real.
            [IO.File]::WriteAllText((Join-Path $sample '.gitignore'),"/target/")
            & git -C $sample init --quiet -b a-publier
            if ($LASTEXITCODE) { throw 'Git fixture initialization failed.' }
            & git -C $sample add -- Cargo.toml Cargo.lock src/lib.rs .gitignore
            if ($LASTEXITCODE) { throw 'Git fixture staging failed.' }
            & git -C $sample -c user.name=Studio -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm fixture
            if ($LASTEXITCODE) { throw 'Git fixture commit failed.' }
            $script:testSha=(& git -C $sample rev-parse HEAD).Trim()
            $script:queueStep=Get-Item Function:Add-Step | Select-Object -ExpandProperty ScriptBlock
            function script:Add-Step([string]$name,[string]$exe,[string]$arguments,[string]$kind='normal') {
                if ([IO.Path]::GetFileName($exe) -eq 'git.exe' -and $arguments -match '^(clone|fetch) ') {
                    $uri=([uri]$sample).AbsoluteUri
                    $arguments='-c "url.'+$uri+'.insteadOf='+$belobugTarget.Origin+'" '+$arguments
                }
                & $script:queueStep $name $exe $arguments $kind
            }
            function script:Confirm-StudioRun([string]$message) {
                return $workDir -eq (Join-Path $fixture ('VIREX Test Studio\repositories\'+$belobugTarget.CacheId))
            }
            $combo.SelectedIndex=0
            $script:phase=2
            $runButton.PerformClick()
            if ($runState -ne 'RUNNING') { throw 'Belobug mode did not start.' }
        } elseif ($script:phase -eq 2 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if ($runState -ne 'PASS' -or !$report.Contains($testSha) -or !$report.Contains($belobugTarget.Origin) -or !$report.Contains('--locked')) { throw $report }
            [IO.File]::WriteAllText((Join-Path $workDir 'local-change.txt'),'preserve this file')
            $script:phase=3
            $runButton.PerformClick()
        } elseif ($script:phase -eq 3 -and $script:runState -ne 'RUNNING') {
            if ($runState -ne 'FAIL' -or $steps[$steps.Count-1].Kind -ne 'clean' -or !(Test-Path -LiteralPath (Join-Path $workDir 'local-change.txt'))) {
                throw 'Dirty checkout was not protected.'
            }
            # Run the real background lookup through a fixed release response, with no network.
            $module=[IO.File]::ReadAllText((Join-Path $appDir 'StudioUpdate.ps1'))
            $stub="function Invoke-RestMethod { return @{ tag_name='studio-stable'; draft=0; prerelease=0; assets=@(@{ name='VIREX-Test-Studio-$studioVersion-Setup.exe'; state='uploaded' }) } }"
            [IO.File]::WriteAllText((Join-Path $fixture 'StudioUpdate.ps1'),$module+[Environment]::NewLine+$stub,[Text.Encoding]::UTF8)
            $script:appDir=$fixture
            $script:phase=4
            $updateButton.PerformClick()
            if ($runButton.Enabled) { throw 'A run could start during the update check.' }
        } elseif ($script:phase -eq 4 -and !$script:updateWorker) {
            if ($foot.Text -notlike 'Naprakész*' -or !$updateButton.Enabled -or !$runButton.Enabled) { throw "Update button result: $($foot.Text)" }
            $script:passed=$true
            $driver.Stop()
            $form.Close()
        }
    } catch {
        $script:failure=$_.Exception.Message
        $driver.Stop()
        if ($script:runState -eq 'RUNNING') { $script:closeAfterStop=$true; Stop-Run }
        else { $form.Close() }
    }
})
try {
    $driver.Start()
    . (Join-Path $projectPath 'VIREX-Test-Studio.ps1')
    if (!$passed) { throw "Desktop test failed. $failure" }
    Write-Output "PASS: native desktop, presets, AI Review, local mode and resize. Cargo run: $WithCargo"
} finally {
    $driver.Dispose()
    $env:LOCALAPPDATA=$oldAppData
    $env:CARGO_NET_OFFLINE=$oldOffline
    $actual=[IO.Path]::GetFullPath($fixture)
    if ([IO.Path]::GetDirectoryName($actual) -eq $tempBase.TrimEnd('\') -and [IO.Path]::GetFileName($actual) -match '^virex-desktop-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $actual -Recurse -Force
    }
}
