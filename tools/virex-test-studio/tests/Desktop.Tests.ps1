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
$deadline=[DateTime]::UtcNow.AddSeconds(480)
$driver=New-Object Windows.Forms.Timer
$driver.Interval=150
$driver.Add_Tick({
    try {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Desktop test timeout.' }
        if ($script:phase -eq 0) {
            if (!$form.Visible) { return }
            if ($combo.Items.Count -ne 21 -or $tabs.TabPages.Count -ne 7) { throw 'Missing target or workspace tab.' }
            if (!$updateButton.Enabled -or $ckBench.Enabled -or $combo.SelectedItem.Mode -ne 'belobug') { throw 'Startup controls unavailable.' }
            if (!$storageChoose.Enabled -or !$storageClean.Enabled -or !$storageMeasure.Enabled) { throw 'Storage controls missing.' }
            $rejected=$false; try { Assert-StorageSpace 4GB 2GB 2GB 2GB } catch { $rejected=$true }; if(!$rejected){throw 'Low disk guard failed.'}
            Assert-StorageSpace 30GB 2GB 2GB 2GB
            $script:alternate=Select-CacheRoot $fixture
            Set-CacheRoot $alternate
            if (!(Test-CacheRoot $alternate) -or (Get-StudioTargetDirectory $false $true $belobugTarget $true) -ne (Join-Path $alternate ('cache\'+$belobugTarget.CacheId+'-agility'))) {throw 'Alternate cache routing failed.'}
            if ((Get-StudioTargetDirectory $true $true $belobugTarget $false) -ne $inheritedTargetDir) {throw 'Local target changed.'}
            if (!$ckAgility.Enabled -or !$ckDepth.Enabled -or $ckAgility.Checked -or $ckDepth.Checked) { throw 'Agility and depth options must be opt-in.' }
            $profileJson='{"v":1,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/pull/7","check":true,"workspace":false,"clippy":false,"repeat":3,"agility":true,"depth":true}'
            Apply-StudioProfile $profileJson
            if($combo.SelectedItem.Mode -ne 'revision' -or !$ckCheck.Checked -or $ckTest.Checked -or !$ckDepth.Checked -or !$ckRepeat.Checked -or !$ckAgility.Checked -or $runState -ne 'IDLE'){throw 'Manual profile application failed.'}
            foreach($invalid in @($profileJson.Replace('"repeat":3','"repeat":2'),$profileJson.Replace('"check":true','"check":"true"'),$profileJson.Replace('"v":1','"v":1,"command":"cmd.exe"'))){
                $rejected=$false;try{ConvertFrom-StudioProfile $invalid|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'Invalid profile accepted.'}
            }
            $modeSwitch.Checked=$true
            if($ckCheck.Enabled -or $profileLoad.Enabled -or !$modeSwitch.Checked){throw 'AUTO did not lock manual inputs.'}
            $modeSwitch.Checked=$false
            if(!$ckCheck.Enabled -or !$profileLoad.Enabled){throw 'MANUAL controls not restored.'}
            $combo.SelectedIndex=0
            $ckTest.Checked=$true;$ckClippy.Checked=$true;$ckAgility.Checked=$false;$ckDepth.Checked=$false
            $depthOutput="test pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws ... ok`r`ntest result: ok. 1 passed; 0 failed; 0 ignored"
            if (!(Test-DepthResult $depthOutput '') -or (Test-DepthResult $depthOutput 'no PC dxc.exe; skipped') -or (Test-DepthResult $depthOutput 'no host depth bounds support; skipped') -or (Test-DepthResult 'test result: ok. 0 passed; 0 failed; 0 ignored' '')) { throw 'Depth result gate regression.' }
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

            $tabs.SelectedTab=$prTab
            $prAddress.Text='https://github.com/Belobug/VIctory-Belobug-AMD/pull/7'
            $prSelect.PerformClick()
            if ($combo.SelectedItem.Mode -ne 'revision' -or $revisionTarget.Branch -cne 'refs/pull/7/head') { throw 'PR selection failed.' }
            $branchTarget=ConvertTo-RevisionTarget 'https://github.com/Belobug/VIctory-Belobug-AMD/tree/fix/example'
            if ($branchTarget.Branch -cne 'refs/heads/fix/example') { throw 'Branch selection failed.' }
            $known='0123456789abcdef0123456789abcdef01234567'
            $commitTarget=ConvertTo-RevisionTarget "https://github.com/Belobug/VIctory-Belobug-AMD/commit/$known"
            if ($commitTarget.ExpectedSha -cne $known) { throw 'Commit pin failed.' }
            foreach ($bad in @('https://example.org/a/b/pull/1','https://github.com/a/b/pull/0','https://github.com/a/b/tree/../x','https://github.com/a/b/tree/x --force','https://github.com/a/b/tree/x:refs/heads/main','https://github.com/a/b/commit/abcd','https://github.com/a/b/pull/1/files')) {
                $rejected=$false
                try { ConvertTo-RevisionTarget $bad | Out-Null } catch { $rejected=$true }
                if (!$rejected) { throw "Accepted invalid revision URL: $bad" }
            }
            $combo.SelectedIndex=1
            Set-LocalProject $sample
            if ($ckBench.Enabled -or $ckFull.Enabled -or $ckWarp.Enabled -or $ckAgility.Enabled -or $ckDepth.Enabled -or !$ckTest.Enabled) { throw 'Invalid local mode controls.' }
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
            # The PR fixture uses a real tiny Cargo workspace. Its xtask stages
            # INERT text files, not Microsoft DLLs; this tests orchestration, not D3D12.
            foreach ($dir in @('.cargo','xtask/src','crates/victory-gpu/src')) {
                $null=[IO.Directory]::CreateDirectory((Join-Path $sample $dir))
            }
            [IO.File]::WriteAllText((Join-Path $sample 'Cargo.toml'),@'
[package]
name = "victory-gpu"
version = "0.1.0"
edition = "2021"
[workspace]
members = ["xtask"]
resolver = "2"
'@)
            [IO.File]::WriteAllText((Join-Path $sample 'src/lib.rs'),'#[cfg(test)] mod pipeline { pub mod host { pub mod tests { #[test] fn depth_bounds_pipeline_loads_and_filters_draws() { assert_eq!(2+2,4); } } } }')
            [IO.File]::WriteAllText((Join-Path $sample '.cargo/config.toml'),'[alias]' + [Environment]::NewLine + 'xtask = "run --quiet --package xtask --"')
            [IO.File]::WriteAllText((Join-Path $sample 'xtask/Cargo.toml'),@'
[package]
name = "xtask"
version = "0.1.0"
edition = "2021"
'@)
            [IO.File]::WriteAllText((Join-Path $sample 'xtask/src/main.rs'),@'
fn main() {
    assert_eq!(std::env::args().nth(1).as_deref(), Some("agility"));
    let target = std::path::PathBuf::from(std::env::var_os("CARGO_TARGET_DIR").unwrap());
    let dir = target.join("debug").join("D3D12");
    std::fs::create_dir_all(&dir).unwrap();
    for name in ["D3D12Core.dll", "d3d12SDKLayers.dll"] {
        std::fs::write(dir.join(name), b"inert test fixture").unwrap();
    }
}
'@)
            foreach ($file in @('xtask/src/agility.rs','crates/victory-gpu/src/agility.rs','crates/victory-gpu/build.rs')) {
                [IO.File]::WriteAllText((Join-Path $sample $file),'// inert fixture')
            }
            & cargo generate-lockfile --offline --manifest-path (Join-Path $sample 'Cargo.toml')
            if ($LASTEXITCODE) { throw 'Fixture lock generation failed.' }
            & git -C $sample add -- Cargo.toml Cargo.lock src/lib.rs .cargo xtask crates
            if ($LASTEXITCODE) { throw 'PR fixture staging failed.' }
            & git -C $sample -c user.name=Studio -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm pr-fixture
            if ($LASTEXITCODE) { throw 'PR fixture commit failed.' }
            $script:prSha=(& git -C $sample rev-parse HEAD).Trim()
            & git -C $sample update-ref refs/pull/7/head $prSha
            if ($LASTEXITCODE) { throw 'PR ref creation failed.' }
            & git -C $sample reset --hard $testSha
            if ($LASTEXITCODE) { throw 'Fixture baseline reset failed.' }
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
            Remove-Item -LiteralPath (Join-Path $workDir 'local-change.txt')
            $tabs.SelectedTab=$prTab
            $prAddress.Text='https://github.com/Belobug/VIctory-Belobug-AMD/pull/7'
            $prSelect.PerformClick()
            $script:phase=31
            $runButton.PerformClick()
            if ($runState -ne 'RUNNING') { throw 'PR run did not start.' }
        } elseif ($script:phase -eq 31 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if ($runState -ne 'PASS' -or !$report.Contains($prSha) -or !$report.Contains('refs/pull/7/head') -or !$report.Contains('Source URL: https://github.com/Belobug/VIctory-Belobug-AMD/pull/7')) { throw $report }
            if (Test-AgilitySource $sample) { throw 'Baseline fixture unexpectedly supports agility.' }
            $ckCheck.Checked=$false; $ckTest.Checked=$false; $ckClippy.Checked=$false
            $ckDepth.Checked=$true; $ckAgility.Checked=$true; $ckRepeat.Checked=$true
            $script:phase=32
            $runButton.PerformClick()
            if ($runState -ne 'RUNNING') { throw 'Agility test did not start.' }
        } elseif ($script:phase -eq 32 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if ($runState -ne 'PASS' -or !$machine.AgilityStaged -or !$env:CARGO_TARGET_DIR.EndsWith('-agility') -or @($steps | Where-Object { $_.Kind -eq 'depthtest' -and $_.Status -eq 'PASS' }).Count -ne 3 -or !$report.Contains('Agility SDK staged (files present): True')) { throw $report }
            if (!$env:CARGO_TARGET_DIR.StartsWith($alternate,[StringComparison]::OrdinalIgnoreCase)) {throw 'Actual build did not use alternate cache.'}
            if (Test-StagedAgility ($env:CARGO_TARGET_DIR.Substring(0,$env:CARGO_TARGET_DIR.Length-8))) { throw 'Agility polluted the baseline cache.' }
            $modeSwitch.Checked=$true
            $autoProfile.SelectedIndex=1
            $script:phase=34
            $runButton.PerformClick()
            if($runState -ne 'RUNNING'){throw 'AUTO D3D12 did not start.'}
        } elseif ($script:phase -eq 34 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if($runState -ne 'PASS' -or $report -notmatch 'Execution mode: AUTO' -or @($steps|Where-Object {$_.Kind -eq 'depthtest'}).Count -ne 3 -or @($steps|Where-Object {$_.Name -eq 'L3 | Workspace tests'}).Count -ne 1){throw $report}
            foreach($level in 0..4){if($levelResults["$level"] -ne 'PASS' -or !(Test-Path -LiteralPath (Join-Path $runDir "LEVEL-$level.txt") -PathType Leaf)){throw "Missing AUTO checkpoint $level"}}
            $names=@($steps|ForEach-Object {$_.Name});$depthLast=[array]::IndexOf($names,'L2 | D3D12 depth bounds (3/3)');$workspaceIndex=[array]::IndexOf($names,'L3 | Workspace tests')
            if($depthLast -lt 0 -or $workspaceIndex -le $depthLast){throw 'Wrong stage order.'}
            $modeSwitch.Checked=$false
            $combo.SelectedIndex=1
            Set-LocalProject $sample
            [IO.File]::WriteAllText((Join-Path $sample 'src/lib.rs'),'#[test] fn studio_smoke() { panic!("intentional test failure"); }')
            function script:Confirm-StudioRun([string]$message) { return ($workDir -eq $sample) }
            $modeSwitch.Checked=$true
            $script:phase=35
            $runButton.PerformClick()
            if($runState -ne 'RUNNING'){throw 'AUTO failure fixture did not start.'}
        } elseif ($script:phase -eq 35 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if($runState -ne 'FAIL' -or $levelResults['3'] -ne 'FAIL' -or $report -notmatch 'L4 \| Strict Clippy \| NOT RUN' -or @($steps|Where-Object {$_.Name -match '^L4'}).Count){throw $report}
            $modeSwitch.Checked=$false
            $script:phase=33
            Start-CacheOperation $false
            if(!$cacheWorker -or $runButton.Enabled -or $updateButton.Enabled){throw 'Cache worker gating failed.'}
        } elseif ($script:phase -eq 33 -and !$script:cacheWorker) {
            if($storageResult.Text -notlike 'Cache mérete:*' -or !$runButton.Enabled -or !$updateButton.Enabled){throw "Cache measurement failed: $($storageResult.Text)"}
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
