# Run from Windows PowerShell 5.1 -STA in a fresh process.
[CmdletBinding()]
param([switch]$WithCargo, [string]$PreviewPath, [switch]$ExpectPreview)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$projectPath=Split-Path -Parent $PSScriptRoot
$tempBase=[IO.Path]::GetTempPath()
$fixture=Join-Path $tempBase ('virex-desktop-'+[guid]::NewGuid().ToString('N'))
$oldAppData=$env:LOCALAPPDATA
$oldOffline=$env:CARGO_NET_OFFLINE
$oldDepthSkip=$env:VIREX_STUDIO_FIXTURE_DEPTH_SKIP
$env:VIREX_STUDIO_FIXTURE_DEPTH_SKIP=$null
$env:LOCALAPPDATA=$fixture
$env:CARGO_NET_OFFLINE='true'
$sample=Join-Path $fixture 'Árvíz Cargo projekt'
$null=[IO.Directory]::CreateDirectory((Join-Path $sample 'src'))
[IO.File]::WriteAllText((Join-Path $sample 'Cargo.toml'),"[package]$([Environment]::NewLine)name = 'studio_fixture'$([Environment]::NewLine)version = '0.1.0'$([Environment]::NewLine)edition = '2021'")
[IO.File]::WriteAllText((Join-Path $sample 'src\lib.rs'),'#[test] fn studio_smoke() { assert_eq!(2 + 2, 4); } #[test] #[ignore] fn studio_release() { assert!(!cfg!(debug_assertions)); }')
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
            if ($isPreview -ne $ExpectPreview.IsPresent) { throw 'Unexpected package channel.' }
            if ($ExpectPreview -and ($form.Text -notlike '*Előnézet*' -or $updateButton.Text -ne '&Frissítések')) {
                throw 'Preview title or GitHub update button missing.'
            }
            if ($tabs.SelectedTab -ne $overviewTab -or $overviewStatus.Text -ne 'Készen áll' -or $overviewSteps.Text -ne '—') {
                throw 'Overview does not show idle state on startup.'
            }
            if ($combo.Items.Count -ne 21 -or $tabs.TabPages.Count -ne 8) { throw 'Missing target or workspace tab.' }
            if (!$updateButton.Enabled -or $ckBench.Enabled -or $combo.SelectedItem.Mode -ne 'belobug') { throw 'Startup controls unavailable.' }
            if (!$storageChoose.Enabled -or !$storageClean.Enabled -or !$storageMeasure.Enabled) { throw 'Storage controls missing.' }
            if($bridgeEnabled.Checked -or $script:bridgeConfig){throw 'AutoBridge must default OFF.'}
            $batchProfile='{"v":3,"target":"https://github.com/VlREX/VIREX/commit/0123456789abcdef0123456789abcdef01234567","check":true,"workspace":true,"clippy":false,"repeat":1,"agility":false,"depth":false,"crate":"victory-pipeline","test":"","threads":0,"release":false,"ignored":false}'
            $batchParsed=@(ConvertFrom-StudioBatch ('['+$batchProfile+','+$batchProfile+']'))
            if($batchParsed.Count -ne 2 -or $batchParsed[0].Target.ExpectedSha -ne '0123456789abcdef0123456789abcdef01234567'){throw 'Batch profile parsing failed.'}
            foreach($invalid in @('[]',$batchProfile,('['+$batchProfile.Replace('"check":true','"command":"cmd.exe"')+']'))){
                $rejected=$false;try{ConvertFrom-StudioBatch $invalid|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'Invalid batch accepted.'}
            }
            $bridgeFixture=Join-Path $fixture 'bridge'
            $bridgeFiles=Join-Path $bridgeFixture 'datasources'
            $null=New-Item -ItemType Directory -Path $bridgeFiles -Force
            $bridgeLauncher=Join-Path $bridgeFixture 'ui.vision.html'
            [IO.File]::WriteAllText($bridgeLauncher,'fixture')
            $bridgeUrl='https://chatgpt.com/g/g-abc/c/01234567-89ab-cdef-0123-456789abcdef'
            $cfg=Get-BridgeConfig $bridgeUrl $bridgeLauncher $bridgeFiles $false
            if(Test-BridgeTarget 'https://example.com/c/01234567-89ab-cdef-0123-456789abcdef'){throw 'Unsafe bridge target accepted.'}
            $message='hello, "quote"'+[Environment]::NewLine+'Árvíz'
            $job=New-BridgePayload $cfg $message '0123456789abcdef0123456789abcdef'
            if($job.Url -notlike 'file:*' -or $job.Url -notlike '*storage=xfile*' -or $job.Url.Contains('hello')){throw 'Invalid bridge launcher.'}
            $row=ConvertFrom-Csv -InputObject $job.Csv -Header 'payload'
            if((ConvertFrom-Json -InputObject $row.payload) -cne $message){throw 'Bridge report encoding failed.'}
            $rejected=$false; try { Assert-StorageSpace 4GB 2GB 2GB 2GB } catch { $rejected=$true }; if(!$rejected){throw 'Low disk guard failed.'}
            Assert-StorageSpace 30GB 2GB 2GB 2GB
            $script:alternate=Select-CacheRoot $fixture
            Set-CacheRoot $alternate
            if (!(Test-CacheRoot $alternate) -or (Get-StudioTargetDirectory $false $true $belobugTarget $true) -ne (Join-Path $alternate ('cache\'+$belobugTarget.CacheId+'-agility'))) {throw 'Alternate cache routing failed.'}
            if ((Get-StudioTargetDirectory $true $true $belobugTarget $false) -ne $inheritedTargetDir) {throw 'Local target changed.'}
            if (!$ckAgility.Enabled -or !$ckDepth.Enabled -or $ckAgility.Checked -or $ckDepth.Checked) { throw 'Agility and depth options must be opt-in.' }
            $profileJson='{"v":1,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/pull/7","check":true,"workspace":false,"clippy":false,"repeat":3,"agility":true,"depth":true}'
            $tabs.SelectedTab=$labTab
            $profileBox.Text=$profileJson
            $profileLoad.PerformClick()
            if($profileBox.Text -cne $profileJson){throw 'Loading prematurely cleared the profile.'}
            $profileClear.PerformClick()
            if($profileBox.Text -or $script:loadedProfileText){throw 'Clear profile did not empty the editor.'}
            $profileBox.Text='invalid JSON'
            $profileLoad.PerformClick()
            if($profileBox.Text -cne 'invalid JSON'){throw 'Invalid profile was lost.'}
            $profileClear.PerformClick()
            $tabs.SelectedTab=$overviewTab
            if($combo.SelectedItem.Mode -ne 'revision' -or !$ckCheck.Checked -or $ckTest.Checked -or !$ckDepth.Checked -or !$ckRepeat.Checked -or !$ckAgility.Checked -or $runState -ne 'IDLE'){throw 'Manual profile application failed.'}
            foreach($invalid in @($profileJson.Replace('"repeat":3','"repeat":2'),$profileJson.Replace('"check":true','"check":"true"'),$profileJson.Replace('"v":1','"v":1,"command":"cmd.exe"'))){
                $rejected=$false;try{ConvertFrom-StudioProfile $invalid|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'Invalid profile accepted.'}
            }
            $profileV2='{"v":2,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/pull/7","check":false,"workspace":true,"clippy":false,"repeat":1,"agility":true,"depth":false,"crate":"victory-gpu","test":"pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws","threads":1}'
            Apply-StudioProfile $profileV2
            if($manualCrate.Text -ne 'victory-gpu' -or !$manualSerial.Checked -or $manualTest.Text -notlike 'pipeline::*'){throw 'v2 profile failed.'}
            if((Get-ManualTestArgs 'victory-gpu' 'a::b' $true ' --locked') -ne 'test -p victory-gpu --lib --locked a::b -- --exact --nocapture --test-threads=1'){throw 'Targeted arguments incorrect.'}
            $badProfile=$profileV2.Replace('"crate":"victory-gpu"','"crate":"victory-gpu --workspace"')
            $rejected=$false;try{ConvertFrom-StudioProfile $badProfile|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'Unsafe crate accepted.'}
            $commitUrl='https://github.com/Belobug/VIctory-Belobug-AMD/commit/2083466bb80691d99b917d09cd9d55084338c55a'
            $profileV3=$profileV2.Replace('"v":2','"v":3,"release":true,"ignored":true').Replace('https://github.com/Belobug/VIctory-Belobug-AMD/pull/7',$commitUrl)
            Apply-StudioProfile $profileV3
            if (!$manualRelease.Checked -or !$manualIgnored.Checked -or $revisionTarget.ExpectedSha -ne $commitUrl.Split('/')[-1] -or $runState -ne 'IDLE') {
                throw 'Pinned v3 profile application failed.'
            }
            foreach ($invalid in @(
                $profileV3.Replace('"ignored":true','"ignored":"true"'),
                $profileV3.Replace($commitUrl,'https://github.com/Belobug/VIctory-Belobug-AMD/pull/7'),
                $profileV3.Replace('pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws','')
            )) {
                $rejected=$false
                try { $null=ConvertFrom-StudioProfile $invalid } catch { $rejected=$true }
                if (!$rejected) { throw 'Invalid v3 profile accepted.' }
            }
            Apply-StudioProfile $profileJson
            if($manualCrate.Text -or $manualTest.Text -or $manualSerial.Checked -or $manualRelease.Checked -or $manualIgnored.Checked){throw 'v1 did not clear targeting.'}
            $rejected=$false
            try { $null=Get-ManualTestArgs 'victory-gpu' '' $true '' $true $true } catch { $rejected=$true }
            if (!$rejected) { throw 'Ignored-only mode accepted a missing exact test.' }
            $crashLog='error: test failed, to rerun pass '+[char]96+'-p victory-shader --lib'+[char]96+[Environment]::NewLine+'exit code: 0xc0000005, STATUS_ACCESS_VIOLATION'
            if((Get-CrashPackage '' $crashLog 101) -ne 'victory-shader' -or (Get-CrashPackage '' 'error: failed' 101)){throw 'Crash parser failed.'}
            $defaultCrash=$crashLog.Replace('-p victory-shader --lib','--lib')
            if((Get-CrashPackage '' $defaultCrash -1073741819) -ne '<default-lib>' -or (Get-CrashTestArgs '<default-lib>' '' ' --locked') -ne 'test --lib --locked -- --nocapture --test-threads=1'){throw 'Default library crash parser failed.'}
            if(Get-CrashPackage '' ($crashLog+[Environment]::NewLine+$defaultCrash) -1073741819){throw 'Ambiguous crash hints accepted.'}
            $exeLog="process didn't exit successfully: "+[char]96+'C:\cache\debug\deps\studio_fixture-12345678abcdef90.exe --nocapture'+[char]96
            if((Get-CrashExecutable $exeLog) -ne 'studio_fixture-12345678abcdef90.exe'){throw 'Crash executable parser failed.'}
            if((Get-SerialCrashCandidate ('test a::ok ... ok'+[Environment]::NewLine+'test b::suspect ... ')) -ne 'b::suspect' -or (Get-SerialCrashCandidate 'test b::ok ... ok')){throw 'Serial candidate parser failed.'}
            $modeSwitch.Checked=$true
            if($ckCheck.Enabled -or $profileLoad.Enabled -or $profileClear.Enabled -or !$modeSwitch.Checked){throw 'AUTO did not lock manual inputs.'}
            $modeSwitch.Checked=$false
            if(!$ckCheck.Enabled -or !$profileLoad.Enabled -or !$profileClear.Enabled){throw 'MANUAL controls not restored.'}
            $combo.SelectedIndex=0
            $ckTest.Checked=$true;$ckClippy.Checked=$true;$ckAgility.Checked=$false;$ckDepth.Checked=$false
            $nl = [Environment]::NewLine
            $testLine = "test $script:depthTestName ..."
            $depthOutput = "$testLine ok" + $nl + 'test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured'
            $ignoredOutput = "$testLine ignored" + $nl + 'test result: ok. 0 passed; 0 failed; 1 ignored; 0 measured'
            $proof = 'NATIVE DEPTH READBACK PASSED: AMD Radeon RX 9070 GRE PCI 1002:7550'
            $cases = @(
                @{ Name='silent'; Output=$depthOutput; Log=''; Execution='NOT VERIFIED'; Completed=$true }
                @{ Name='unsupported'; Output=$depthOutput; Log='no host depth bounds support; skipped'; Execution='SKIPPED'; Completed=$true }
                @{ Name='missing shader compiler'; Output=$depthOutput; Log='no PC dxc.exe; skipped'; Execution='SKIPPED'; Completed=$true }
                @{ Name='missing host'; Output=$depthOutput; Log="WARN no host D3D12 device; command lists will not run"; Execution='SKIPPED'; Completed=$true }
                @{ Name='ignored'; Output=$ignoredOutput; Log=''; Execution='SKIPPED'; Completed=$true }
                @{ Name='missing test'; Output='test result: ok. 0 passed; 0 failed; 0 ignored'; Log=$proof; Execution='NOT VERIFIED'; Completed=$false }
                @{ Name='proof'; Output=$depthOutput; Log=$proof; Execution='VERIFIED'; Completed=$true }
                @{ Name='ambiguous proof'; Output=$depthOutput; Log=($proof+$nl+$proof); Execution='NOT VERIFIED'; Completed=$true }
                @{ Name='software'; Output=$depthOutput; Log='NATIVE DEPTH READBACK PASSED: Microsoft Basic Render Driver PCI 1414:008c'; Execution='NOT VERIFIED'; Completed=$true }
                @{ Name='skip overrides proof'; Output=$depthOutput; Log=($proof+$nl+'no PC dxc.exe; skipped'); Execution='SKIPPED'; Completed=$true }
                @{ Name='inline proof'; Output=$depthOutput.Replace("$testLine ok", "$testLine $proof" + $nl + 'ok'); Log=''; Execution='VERIFIED'; Completed=$true }
            )
            foreach ($case in $cases) {
                $result = Get-DepthValidation $case.Output $case.Log
                if ($result.Completed -ne $case.Completed -or $result.GpuExecution -ne $case.Execution) {
                    throw "Depth validation classification failed: $($case.Name)"
                }
            }
            $verifiedStep = @{ Kind='depthtest'; GpuExecution='VERIFIED' }
            $skippedStep = @{ Kind='depthtest'; GpuExecution='SKIPPED' }
            $unverifiedStep = @{ Kind='depthtest'; GpuExecution='NOT VERIFIED' }
            if ((Get-CompletedValidationStatus @($verifiedStep, @{Kind='tests'})) -ne 'PASS' -or
                (Get-CompletedValidationStatus @($verifiedStep, $skippedStep)) -ne 'SKIPPED' -or
                (Get-CompletedValidationStatus @($skippedStep, $unverifiedStep)) -ne 'NOT VERIFIED') {
                throw 'Mixed validation results must not hide skipped or unverified steps.'
            }
            $tabs.SelectedTab=$overviewTab
            if($navButtons.Count -ne 8 -or $commandCenter.RunState -ne 'IDLE'){throw 'Command Center navigation or initial state missing.'}
            $navButtons[2].PerformClick()
            if($tabs.SelectedTab -ne $benchTab){throw 'Command Center navigation failed.'}
            $navButtons[0].PerformClick()
            $commandCenter.MotionEnabled=$false
            $commandCenter.SetRun('RUNNING','Fut','NOT VERIFIED','Fixture UI only','MINTAADATOK · UI TESZT','Workspace tests',7,12,[string[]]@('Runner self-test','Fetch revision','Cargo check','Clippy','Workspace tests'),[string[]]@('PASS','PASS','PASS','PASS','RUNNING'),[string[]]@('0.2s','1.2s','8.5s','4.0s','…'))
            $beforeSamples=$commandCenter.SampleCount
            for($i=0;$i -lt 10;$i++){$commandCenter.Sample((20+($i*7)%45),(40+$i),(5+($i*3)%20),1.71,13.4,32)}
            $commandCenter.SetStorage('Fixture G:',82.1,120)
            if($commandCenter.Completed -ne 7 -or $commandCenter.Planned -ne 12 -or $commandCenter.GpuStatus -ne 'NOT VERIFIED' -or $commandCenter.SampleCount -lt [math]::Min(45,$beforeSamples+10)){throw 'Command Center display state failed.'}
            if ($PreviewPath) {
                $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
                try { $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
            }
            Update-StudioOverview
            $form.Size=New-Object Drawing.Size(800,590)
            $form.PerformLayout()
            $smallBitmap=New-Object Drawing.Bitmap($commandCenter.Width,$commandCenter.Height)
            try{$commandCenter.DrawToBitmap($smallBitmap,(New-Object Drawing.Rectangle(0,0,$commandCenter.Width,$commandCenter.Height)))}finally{$smallBitmap.Dispose()}
            $tabs.SelectedIndex=4
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
            $manualCrate.Text='studio_fixture'
            $manualTest.Text='studio_release'
            $manualRelease.Checked=$true
            $manualIgnored.Checked=$true
            $script:phase=1
            $runButton.PerformClick()
            if ($script:runState -ne 'RUNNING') { throw 'UI did not start the fixture.' }
        } elseif ($script:phase -eq 1 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if ($runState -ne 'PASS' -or $report -notmatch '1 passed' -or $report -notmatch 'Local workspace:' -or $report -match 'Pinned commit:') { throw $report }
            if ($report -notmatch 'test --release -p studio_fixture --lib studio_release -- --exact --nocapture --ignored' -or
                $report -notmatch 'Release build: True') { throw 'Release/ignored desktop arguments missing.' }
            $manualCrate.Clear()
            $manualTest.Clear()
            $manualRelease.Checked=$false
            $manualIgnored.Checked=$false
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
            [IO.File]::WriteAllText((Join-Path $sample 'src/lib.rs'),@'
#[cfg(test)]
mod pipeline {
    pub mod host {
        pub mod tests {
            #[test]
            fn depth_bounds_pipeline_loads_and_filters_draws() {
                if std::env::var_os("VIREX_STUDIO_FIXTURE_DEPTH_SKIP").is_some() {
                    eprintln!("no host depth bounds support; skipped");
                    return;
                }
                eprintln!("CARD_LEVEL_BENCH steps=512 copies=true overlap=false: old 10.000 us, new 4.000 us, 2.500x");
                assert_eq!(2 + 2, 4);
            }
        }
    }
}
'@)
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
            $tabs.SelectedTab=$labTab
            $profileBox.Text='{"v":1,"target":"https://github.com/Belobug/VIctory-Belobug-AMD/pull/7","check":true,"workspace":true,"clippy":false,"repeat":1,"agility":false,"depth":false}'
            $script:fixtureConfirm=Get-Item Function:Confirm-StudioRun | Select-Object -ExpandProperty ScriptBlock
            function script:Confirm-StudioRun([string]$message) { return $false }
            $runButton.PerformClick()
            if (!$profileBox.Text -or $runState -eq 'RUNNING') { throw 'Cancelled run lost its profile.' }
            Set-Item -Path Function:script:Confirm-StudioRun -Value $script:fixtureConfirm
            $script:phase=31
            $runButton.PerformClick()
            if ($runState -ne 'RUNNING' -or $profileBox.Text -or $profileClear.Enabled) { throw 'PR profile run did not start and clear correctly.' }
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
            if ($runState -ne 'NOT VERIFIED' -or $status.Text -ne 'NOT VERIFIED' -or $overviewGpu.Text -ne 'NOT VERIFIED' -or
                $status.ForeColor -ne $amber -or !$machine.AgilityStaged -or !$env:CARGO_TARGET_DIR.EndsWith('-agility') -or @($steps | Where-Object { $_.Kind -eq 'depthtest' -and $_.Status -eq 'PASS' }).Count -ne 3 -or !$report.Contains('Agility SDK staged (files present): True')) { throw $report }
            $bench = Get-Content -LiteralPath (Join-Path $runDir 'benchmark-summary.json') -Raw | ConvertFrom-Json
            $meta = Get-Content -LiteralPath (Join-Path $runDir 'run.json') -Raw | ConvertFrom-Json
            if ($report -notmatch 'Status: NOT VERIFIED' -or $report -notmatch 'GPU execution: NOT VERIFIED' -or
                $meta.state -ne 'NOT VERIFIED' -or
                @($steps | Where-Object { $_.Kind -eq 'depthtest' -and $_.GpuExecution -eq 'NOT VERIFIED' }).Count -ne 3) {
                throw 'Passing D3D12 test fixture was not marked as GPU-unverified.'
            }
            if ($bench[0].sampleCount -ne 3 -or $bench[0].speedup -ne 2.5 -or
                $report -notmatch 'Repeated benchmark measurements' -or
                @(Import-Csv -LiteralPath (Join-Path $runDir 'benchmark.csv')).Count -ne 3) {
                throw 'Desktop report or benchmark exports lost repeated measurements.'
            }
            if (!$env:CARGO_TARGET_DIR.StartsWith($alternate,[StringComparison]::OrdinalIgnoreCase)) {throw 'Actual build did not use alternate cache.'}
            if (Test-StagedAgility ($env:CARGO_TARGET_DIR.Substring(0,$env:CARGO_TARGET_DIR.Length-8))) { throw 'Agility polluted the baseline cache.' }
            $modeSwitch.Checked=$true
            $autoProfile.SelectedIndex=1
            $script:phase=34
            $runButton.PerformClick()
            if($runState -ne 'RUNNING'){throw 'AUTO D3D12 did not start.'}
        } elseif ($script:phase -eq 34 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if($runState -ne 'NOT VERIFIED' -or $report -notmatch 'Execution mode: AUTO' -or @($steps|Where-Object {$_.Kind -eq 'depthtest'}).Count -ne 3 -or @($steps|Where-Object {$_.Name -eq 'L3 | Workspace tests'}).Count -ne 1){throw $report}
            foreach ($level in 0..4) {
                $state = if ($level -eq 2) { 'NOT VERIFIED' } else { 'PASS' }
                $checkpoint = Get-Content -LiteralPath (Join-Path $runDir "LEVEL-$level.txt") -Raw
                if ($levelResults["$level"] -ne $state -or !$checkpoint.Contains("AUTO LEVEL $level | $state")) {
                    throw "Incorrect AUTO checkpoint $level"
                }
            }
            $names=@($steps|ForEach-Object {$_.Name});$depthLast=[array]::IndexOf($names,'L2 | D3D12 depth bounds (3/3)');$workspaceIndex=[array]::IndexOf($names,'L3 | Workspace tests')
            if($depthLast -lt 0 -or $workspaceIndex -le $depthLast){throw 'Wrong stage order.'}
            $modeSwitch.Checked=$false
            $ckCheck.Checked=$false; $ckTest.Checked=$true; $ckClippy.Checked=$false
            $ckDepth.Checked=$false; $ckAgility.Checked=$true; $ckRepeat.Checked=$false
            $manualCrate.Text='victory-gpu'
            $manualTest.Text=$script:depthTestName
            $env:VIREX_STUDIO_FIXTURE_DEPTH_SKIP='1'
            $script:phase=37
            $runButton.PerformClick()
            if ($runState -ne 'RUNNING') { throw 'Targeted depth skip fixture did not start.' }
        } elseif ($script:phase -eq 37 -and $script:runState -ne 'RUNNING') {
            $env:VIREX_STUDIO_FIXTURE_DEPTH_SKIP=$null
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            $skipped = @($steps | Where-Object { $_.Kind -eq 'depthtest' -and $_.Status -eq 'SKIPPED' })
            if ($runState -ne 'SKIPPED' -or $status.Text -ne 'SKIPPED' -or $status.ForeColor -ne $amber -or
                $skipped.Count -ne 1 -or $report -notmatch 'GPU execution: SKIPPED' -or
                $report -notmatch 'D3D12 depth bounds requested: True') {
                throw $report
            }
            $manualCrate.Clear()
            $manualTest.Clear()
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
            # Real child process returns NTSTATUS 0xC0000005; no unsafe memory access is needed.
            [IO.File]::WriteAllText((Join-Path $sample 'src/lib.rs'),'#[test] fn studio_crash() { std::process::exit(-1073741819); }')
            $modeSwitch.Checked=$true
            $script:phase=36
            $runButton.PerformClick()
            if($runState -ne 'RUNNING'){throw 'Crash fixture did not start.'}
        } elseif ($script:phase -eq 36 -and $script:runState -ne 'RUNNING') {
            $report=[IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt'))
            if($runState -ne 'FAIL' -or $levelResults['3'] -ne 'FAIL' -or $machine.CrashPackage -notin @('<default-lib>','studio_fixture','victory-gpu') -or @($steps|Where-Object {$_.Kind -eq 'diagserial'}).Count -ne 1 -or @($steps|Where-Object {$_.Kind -eq 'diagevent'}).Count -ne 1 -or !(Test-Path -LiteralPath (Join-Path $runDir 'ORIGINAL-FAIL.txt')) -or @($steps|Where-Object {$_.Name -match '^L4'}).Count){throw $report}
            if($machine.CrashCandidate -and @($steps|Where-Object {$_.Kind -eq 'diagexact'}).Count -ne 1){throw 'Exact candidate retry missing.'}
            $modeSwitch.Checked=$false
            $script:phase=33
            Start-CacheOperation $false
            if(!$cacheWorker -or $runButton.Enabled -or $updateButton.Enabled){throw 'Cache worker gating failed.'}
        } elseif ($script:phase -eq 33 -and !$script:cacheWorker) {
            if($storageResult.Text -notlike 'Cache mérete:*' -or !$runButton.Enabled -or !$updateButton.Enabled){throw 'Cache measurement failed before batch.'}
            $modeSwitch.Checked=$false
            $tabs.SelectedTab=$labTab
            $batchProfile=ConvertTo-Json -Compress -InputObject @{v=3;target=('https://github.com/Belobug/VIctory-Belobug-AMD/commit/'+$testSha);check=$false;workspace=$true;clippy=$false;repeat=1;agility=$false;depth=$false;crate='studio_fixture';test='studio_smoke';threads=0;release=$false;ignored=$false}
            $bad=$batchProfile.Replace('studio_fixture','missing_fixture_package')
            $batchBox.Text='['+$batchProfile+','+$batchProfile+','+$bad+','+$batchProfile+']'
            function script:Confirm-StudioRun([string]$message) { return $message.Contains($testSha) -and $message.Contains('missing_fixture_package') -and $message.Contains('Approve all pinned profiles') }
            $script:phase=38
            $batchStart.PerformClick()
            if(!$script:batchActive){throw 'Batch did not start.'}
        } elseif ($script:phase -eq 38 -and !$script:batchActive) {
            $batchLog=[IO.File]::ReadAllText($script:batchReport)
            if($batchLog -notmatch 'PROFILE 1 \| PASS' -or $batchLog -notmatch 'PROFILE 2 \| PASS' -or $batchLog -notmatch 'PROFILE 3 \| FAIL' -or $batchLog -notmatch '\[4\] NOT RUN' -or $batchLog -notmatch 'BATCH STATUS: FAIL' -or $script:batchIndex -ne 3){throw $batchLog}
            $script:phase=39
        } elseif ($script:phase -eq 39) {
            if($storageResult.Text -notlike 'Cache mérete:*' -or !$runButton.Enabled -or !$updateButton.Enabled){throw "Cache measurement failed: $($storageResult.Text)"}
            $module=[IO.File]::ReadAllText((Join-Path $appDir 'StudioUpdate.ps1'))
            $tag = if ($ExpectPreview) { 'studio-preview' } else { 'studio-stable' }
            $prerelease = if ($ExpectPreview) { 1 } else { 0 }
            $suffix = if ($ExpectPreview) { '-Preview' } else { '' }
            $stub = 'function Invoke-RestMethod {{ param($Uri) if ($Uri -notlike "*/{0}") {{ throw "Wrong update endpoint" }}; return @{{ tag_name="{0}"; draft=0; prerelease={1}; assets=@(@{{ name="VIREX-Test-Studio-{2}{3}-Setup.exe"; state="uploaded" }}) }} }}' -f $tag,$prerelease,$studioVersion,$suffix
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
    $env:VIREX_STUDIO_FIXTURE_DEPTH_SKIP=$oldDepthSkip
    $actual=[IO.Path]::GetFullPath($fixture)
    if ([IO.Path]::GetDirectoryName($actual) -eq $tempBase.TrimEnd('\') -and [IO.Path]::GetFileName($actual) -match '^virex-desktop-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $actual -Recurse -Force
    }
}
