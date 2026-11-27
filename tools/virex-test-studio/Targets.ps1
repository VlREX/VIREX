$belobugTarget=ConvertTo-RepositoryTarget 'Belobug/VIctory-Belobug-AMD'
$belobugTarget.Branch='a-publier'
$script:customTarget=$null
$script:revisionTarget=$null
function Test-LocalTarget { return $combo.SelectedItem.Mode -eq 'local' }
function Test-WorkspaceTarget { return $combo.SelectedItem.Mode -ne 'pinned' }
function Get-SelectedRepository {
    if ($combo.SelectedItem.Mode -eq 'belobug') { return $belobugTarget }
    if ($combo.SelectedItem.Mode -eq 'revision') { return $script:revisionTarget }
    return $script:customTarget
}

function Update-TargetControls {
    $local = Test-LocalTarget
    $workspace = Test-WorkspaceTarget
    $ckFull.Enabled = !$workspace
    $ckWarp.Enabled = !$workspace
    $ckAgility.Enabled = $workspace -and !$local
    $ckDepth.Enabled = $workspace -and !$local
    if ($workspace) {
        $ckTest.Text = 'Munkaterület-tesztek'
        $ckBench.Enabled = $false
        $ckBench.Checked = $false
        if ($local) {
            $openSource.Text = 'Projektmappa tallózása…'
            $revision.Text = if ($script:localProject) { $script:localProject } else { 'Válaszd ki a Cargo.toml fájlt tartalmazó mappát.' }
        } else {
            $target=Get-SelectedRepository
            $openSource.Text = if ($combo.SelectedItem.Mode -eq 'belobug') { 'Repó megnyitása' } elseif ($combo.SelectedItem.Mode -eq 'revision') { 'PR Manager megnyitása' } else { 'GitHub-cím megadása…' }
            $revision.Text = if ($target) { "$($target.Name)$([Environment]::NewLine)Ág: $($target.Branch)" } else { 'Add meg a tesztelendő GitHub-címet.' }
        }
    } else {
        $p = $combo.SelectedItem.Preset
        $ckTest.Text = 'Célzott tesztek'
        $ckBench.Enabled = [bool]$p.Bench
        $ckBench.Checked = [bool]$p.Bench
        $openSource.Text = 'Commit megnyitása'
        $revision.Text = "$($p.Branch)$([Environment]::NewLine)$($p.Sha.Substring(0,12))"
    }
    $tip.SetToolTip($revision,$(if ($workspace) { $revision.Text } else { $p.Sha }))
    $welcomeName.Text=if ($workspace -and !$local -and $target) { $target.Name.Split('/')[-1] } elseif ($local -and $localProject) { Split-Path -Leaf $localProject } elseif (!$workspace) { $p.Crate } else { 'Projekt kiválasztása' }
    $welcomeDetail.Text=$revision.Text
    if (Get-Command Update-ExecutionMode -ErrorAction SilentlyContinue) { Update-ExecutionMode }
}

function Set-LocalProject([string]$directory) {
    $manifest = Join-Path $directory 'Cargo.toml'
    if (!(Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'A kiválasztott mappából hiányzik a Cargo.toml.' }
    $script:localProject = (Get-Item -LiteralPath $directory).FullName
    Update-TargetControls
}

function Test-AgilitySource([string]$directory) {
    foreach ($file in @('xtask/src/agility.rs','crates/victory-gpu/src/agility.rs','crates/victory-gpu/build.rs','.cargo/config.toml')) {
        if (!(Test-Path -LiteralPath (Join-Path $directory $file) -PathType Leaf)) { return $false }
    }
    return $true
}
function Test-StagedAgility([string]$targetDirectory) {
    if ([string]::IsNullOrWhiteSpace($targetDirectory)) { return $false }
    foreach ($name in @('D3D12Core.dll','d3d12SDKLayers.dll')) {
        $path=Join-Path $targetDirectory ('debug\D3D12\'+$name)
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -le 0) { return $false }
    }
    return $true
}
$script:depthTestName = 'pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws'

function Get-DepthValidation([string]$output, [string]$errors) {
    $result = @{ Completed = $false; GpuExecution = 'NOT VERIFIED'; Evidence = ''; SkipReason = '' }
    $testName = [regex]::Escape($script:depthTestName)
    $testLine = "(?m)^test $testName \.\.\. "
    if ($output -notmatch $testLine) { return $result }

    if ($output -match ($testLine + 'ignored(?:[,\r\n]|$)') -and
        $output -match '(?m)^test result: ok\. 0 passed; 0 failed; 1 ignored(?:;|\r?$)') {
        $result.Completed = $true
        $result.GpuExecution = 'SKIPPED'
        $result.SkipReason = 'Rust marked the targeted depth bounds test as ignored.'
        return $result
    }
    if ($output -notmatch '(?m)^test result: ok\. 1 passed; 0 failed; 0 ignored(?:;|\r?$)') { return $result }
    $result.Completed = $true

    $log = $output + [Environment]::NewLine + $errors
    if ($log -match '(?i)no host depth bounds support; skipped|no PC dxc\.exe; skipped|no host D3D12 device; command lists will not run') {
        $result.GpuExecution = 'SKIPPED'
        $result.SkipReason = $Matches[0]
        return $result
    }

    # The instrumented test emits this line after checking all depth readbacks
    # and resolving the D3D12 device to a non-software DXGI adapter.
    $marker = "(?m)^(?:test $testName \.\.\. )?(?<evidence>NATIVE DEPTH READBACK PASSED: (?<adapter>[^\r\n]+?) PCI (?<id>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}))[ \t]*\r?$"
    $evidence = [regex]::Matches($log, $marker)
    if ($evidence.Count -eq 1 -and $evidence[0].Groups['id'].Value -ne '1414:008c' -and
        $evidence[0].Groups['adapter'].Value -notmatch '(?i)\bWARP\b|Basic Render Driver|software adapter') {
        $result.GpuExecution = 'VERIFIED'
        $result.Evidence = $evidence[0].Groups['evidence'].Value
    }
    return $result
}

function Get-CompletedValidationStatus($entries) {
    $hasSkip = $false
    foreach ($entry in $entries) {
        if ($entry.Kind -ne 'depthtest') { continue }
        if ($entry.GpuExecution -eq 'SKIPPED') { $hasSkip = $true }
        elseif ($entry.GpuExecution -ne 'VERIFIED') { return 'NOT VERIFIED' }
    }
    if ($hasSkip) { return 'SKIPPED' }
    return 'PASS'
}

function Add-WorkspaceCargoSteps([string]$cargo, [string]$directory) {
    $lock = if (Test-Path -LiteralPath (Join-Path $directory 'Cargo.lock') -PathType Leaf) { ' --locked' } else { '' }
    Add-Step 'Cargo version' $cargo '--version'
    if ($script:machine.AutoMode) {
        if ($script:machine.AgilityRequested) {
            if (!(Test-AgilitySource $directory)) { throw 'Az AUTO D3D12 profilhoz Agility SDK integráció szükséges. Válassz megfelelő revíziót vagy általános profilt.' }
            Add-Step 'L1 | Prepare D3D12 Agility SDK' $cargo 'xtask agility' 'agility'
        }
        Add-Step 'L1 | Workspace check' $cargo "check --workspace$lock"
        if ($script:machine.DepthRequested) {
            for($pass=1;$pass -le 3;$pass++){ Add-Step "L2 | D3D12 depth bounds ($pass/3)" $cargo "test -p victory-gpu --lib$lock $script:depthTestName -- --exact --nocapture" 'depthtest' }
        }
        Add-Step 'L3 | Workspace tests' $cargo "test --workspace$lock -- --nocapture" 'tests'
        Add-Step 'L4 | Clippy / warnings denied' $cargo "clippy --workspace --all-targets$lock -- -D warnings"
        return
    }
    if ($script:machine.AgilityRequested) {
        if (!(Test-AgilitySource $directory)) { throw 'A kiválasztott revízióban nincs támogatott Agility SDK integráció. Használd a Belobug #360 PR-t vagy kapcsold ki az Agility opciót.' }
        Add-Step 'Prepare D3D12 Agility SDK' $cargo 'xtask agility' 'agility'
    }
    if ($ckCheck.Checked) { Add-Step 'Workspace check' $cargo "check --workspace$lock" }
    if ($ckTest.Checked) {
        if($script:machine.ManualCrate){
            $manualArgs=Get-ManualTestArgs $script:machine.ManualCrate $script:machine.ManualTest $script:machine.ManualSerial $lock $script:machine.ManualRelease $script:machine.ManualIgnored
            $kind = if ($script:machine.ManualDepth) { 'depthtest' } else { 'tests' }
            for($pass=1;$pass -le $script:machine.Repeat;$pass++){Add-Step "Targeted crate tests ($pass/$($script:machine.Repeat))" $cargo $manualArgs $kind}
        }else{
        for ($pass=1; $pass -le $script:machine.Repeat; $pass++) {
            Add-Step "Workspace tests ($pass/$($script:machine.Repeat))" $cargo "test --workspace$lock -- --nocapture" 'tests'
        }
        }
    }
    if ($script:machine.DepthRequested) {
        for ($pass=1; $pass -le $script:machine.Repeat; $pass++) {
            Add-Step "D3D12 depth bounds ($pass/$($script:machine.Repeat))" $cargo "test -p victory-gpu --lib$lock $script:depthTestName -- --exact --nocapture" 'depthtest'
        }
    }
    if ($ckClippy.Checked) { Add-Step 'Clippy / warnings denied' $cargo "clippy --workspace --all-targets$lock -- -D warnings" }
}

function Confirm-StudioRun([string]$message) {
    return [Windows.Forms.MessageBox]::Show($form,$message,'Helyi futtatás jóváhagyása','YesNo','Question') -eq 'Yes'
}

$combo.Add_SelectedIndexChanged({ Update-TargetControls })
$combo.SelectedIndex = 0
$openSource.Add_Click({
    try {
        if (Test-LocalTarget) {
            $dialog = New-Object Windows.Forms.FolderBrowserDialog
            try {
                $dialog.Description = 'Válaszd ki a Cargo.toml fájlt tartalmazó mappát.'
                $dialog.ShowNewFolderButton = $false
                if ($localProject) { $dialog.SelectedPath=$localProject }
                if ($dialog.ShowDialog($form) -eq 'OK') { Set-LocalProject $dialog.SelectedPath }
            } finally { $dialog.Dispose() }
        } elseif ($combo.SelectedItem.Mode -eq 'revision') {
            $tabs.SelectedTab=$prTab
        } elseif ($combo.SelectedItem.Mode -eq 'github') {
            Add-Type -AssemblyName Microsoft.VisualBasic
            $address=[Microsoft.VisualBasic.Interaction]::InputBox('GitHub HTTPS-cím vagy tulajdonos/repó','Tesztelendő repó',$(if ($customTarget) {$customTarget.Origin} else {''}))
            if ($address.Trim()) { $script:customTarget=ConvertTo-RepositoryTarget $address; Update-TargetControls }
        } elseif ($combo.SelectedItem.Mode -eq 'belobug') {
            Start-Process 'https://github.com/Belobug/VIctory-Belobug-AMD'
        } else {
            Start-Process "https://github.com/VlREX/VIREX/commit/$($combo.SelectedItem.Preset.Sha)"
        }
    } catch { [Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Tesztcél') | Out-Null }
})

# PR Manager never starts a build or uploads anything on its own.
$prTab=New-ReviewPage $tabs 'PR Manager'
$prPanel=New-Object Windows.Forms.Panel
$prPanel.Dock='Fill'; $prPanel.AutoScroll=$true
$prTab.Controls.Add($prPanel)
$prLayout=New-Stack $prPanel 'TopDown' $false
$prLayout.AutoSize=$true; $prLayout.AutoSizeMode='GrowAndShrink'
$prLayout.Padding=New-Object Windows.Forms.Padding(16,12,10,12)
$null=New-Caption $prLayout 'PR / fejlesztői ág / commit tesztelése' 13 $fg $true
$prHint=New-Caption $prLayout 'Illeszd be a GitHub-linket. A Studio lekéri a kiválasztott revíziót, és rögzíti a tényleges SHA-t. A PR headet teszteli, nem a merge eredményét.' 9 $muted
$prHint.MaximumSize=New-Object Drawing.Size(360,0)
$prAddress=New-Object Windows.Forms.TextBox
$prAddress.Width=360; $prAddress.MaxLength=400; $prLayout.Controls.Add($prAddress)
$prSelect=New-Action $prLayout 'Tesztcél betöltése' '#245B58' 190
$prLink=New-Action $prLayout 'Belobug PR-lista' '#29414E' 190
$prStatus=New-Caption $prLayout 'Nincs kiválasztott revízió.' 9 $cyan
$prStatus.MaximumSize=New-Object Drawing.Size(360,0)
$prLink.Add_Click({ Start-Process 'https://github.com/Belobug/VIctory-Belobug-AMD/pulls' })
$prSelect.Add_Click({
    if ($script:runState -eq 'RUNNING' -or $script:updateWorker -or $script:unsafeState) { return }
    try {
        $target=ConvertTo-RevisionTarget $prAddress.Text
        $script:revisionTarget=$target
        $choice=@($combo.Items | Where-Object { $_.Mode -eq 'revision' })[0]
        $combo.SelectedItem=$choice
        Update-TargetControls
        $prStatus.Text="Betöltve: $($target.Name) - $($target.Branch)"
        $foot.Text='A kiválasztott revízió teszteléséhez kattints a Futtatás gombra.'
    } catch { $prStatus.Text=$_.Exception.Message }
})


# Storage is isolated from source checkouts, reports, and updater files.
$script:defaultCacheRoot=$root
$script:cacheRoot=$root
$script:cacheSetting=Join-Path $root 'cache-location.txt'
$script:cacheWorker=$null
$script:monitorWorker=$null
$script:monitorJob=$null
$script:monitorSamples=0
$script:monitorPeak=@{}
function Test-PlainDirectory([string]$path) {
    $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
    while ($item) {
        # DirectoryInfo.Parent is a .NET object, not a provider item; PSIsContainer
        # is not guaranteed on it. Use the actual filesystem attributes.
        if (!(($item.Attributes -band [IO.FileAttributes]::Directory)) -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
        $item=$item.Parent
    }
    return $true
}
function Test-CacheRoot([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path) -or $path -notmatch '^[A-Za-z]:\\') { return $false }
    try {
        $full=[IO.Path]::GetFullPath($path)
        if (!(Test-PlainDirectory $full)) { return $false }
        $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
        if (!$drive.IsReady -or $drive.DriveType -ne 'Fixed') { return $false }
        if ($full -ieq $defaultCacheRoot) { return $true }
        if ([IO.Path]::GetFileName($full) -cne 'VIREX-Studio-Cache') { return $false }
        $marker=Join-Path $full '.virex-cache-owner'
        $file=Get-Item -LiteralPath $marker -Force -ErrorAction Stop
        return !$file.PSIsContainer -and !(($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) -and ([IO.File]::ReadAllText($marker) -ceq 'VIREX Studio managed cache v1')
    } catch { return $false }
}
function Select-CacheRoot([string]$parent) {
    if (!(Test-PlainDirectory $parent)) { throw 'Nem választható átirányított mappa.' }
    $path=Join-Path $parent 'VIREX-Studio-Cache'
    if (!(Test-Path -LiteralPath $path)) {
        $null=[IO.Directory]::CreateDirectory($path)
        [IO.File]::WriteAllText((Join-Path $path '.virex-cache-owner'),'VIREX Studio managed cache v1')
    }
    if (!(Test-CacheRoot $path)) { throw 'A mappa nem saját VIREX cache vagy nem helyi, fix meghajtó.' }
    return $path
}
function Set-CacheRoot([string]$path) {
    if (!(Test-CacheRoot $path)) { throw 'Érvénytelen cache-mappa.' }
    [IO.File]::WriteAllText($cacheSetting,$path)
    $script:cacheRoot=$path
}
if (Test-Path -LiteralPath $cacheSetting -PathType Leaf) {
    try {
        $saved=[IO.File]::ReadAllText($cacheSetting).Trim()
        if (Test-CacheRoot $saved) { $script:cacheRoot=$saved }
    } catch {}
}
function Get-FreeBytes([string]$path) {
    $full=[IO.Path]::GetFullPath($path)
    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
    if (!$drive.IsReady) { throw 'A meghajtó nem elérhető.' }
    return [long]$drive.AvailableFreeSpace
}
function Get-StudioTargetDirectory([bool]$local,[bool]$workspace,$target,[bool]$agility) {
    if ($local) { return $script:inheritedTargetDir }
    if (!(Test-CacheRoot $cacheRoot)) { throw 'A cache-mappa nem elérhető vagy nem biztonságos.' }
    $path=if($workspace){$suffix=if($agility){'-agility'}else{''};Join-Path $cacheRoot ('cache\'+$target.CacheId+$suffix)}else{Join-Path $cacheRoot 'target'}
    $ancestor=$path
    while (!(Test-Path -LiteralPath $ancestor)) { $ancestor=Split-Path -Parent $ancestor }
    if (!(Test-PlainDirectory $ancestor)) { throw 'Átirányított cache nem használható.' }
    return $path
}
function Assert-StorageSpace([long]$cacheFree,[long]$systemFree,[long]$tempFree,[long]$cargoFree) {
    if ($systemFree -lt 1GB -or $tempFree -lt 1GB -or $cargoFree -lt 1GB) { throw 'Kevés hely a riport, TEMP vagy Cargo home meghajtóján (minimum 1 GiB). Szabadíts fel helyet.' }
    if ($cacheFree -lt 5GB) { throw 'A fordítási cache meghajtóján 5 GiB-nál kevesebb a szabad hely. Válassz másik meghajtót vagy takarítsd a cache-t.' }
}
function Get-StorageInfo([string]$targetPath) {
    $cargoHome=if($env:CARGO_HOME){$env:CARGO_HOME}else{Join-Path $env:USERPROFILE '.cargo'}
    $targetFree=Get-FreeBytes $targetPath
    $reportFree=Get-FreeBytes $root
    $tempFree=Get-FreeBytes ([IO.Path]::GetTempPath())
    $cargoFree=Get-FreeBytes $cargoHome
    Assert-StorageSpace $targetFree $reportFree $tempFree $cargoFree
    return @{Cache=$targetFree;Reports=$reportFree;Temp=$tempFree;Cargo=$cargoFree}
}
$storageTab=New-ReviewPage $tabs 'Tárhely / hardver'
$storagePanel=New-Object Windows.Forms.Panel
$storagePanel.Dock='Fill'; $storagePanel.AutoScroll=$true
$storageTab.Controls.Add($storagePanel)
$storageLayout=New-Stack $storagePanel 'TopDown' $false
$storageLayout.AutoSize=$true; $storageLayout.AutoSizeMode='GrowAndShrink'
$storageLayout.Padding=New-Object Windows.Forms.Padding(16,12,10,12)
$null=New-Caption $storageLayout 'Fordítási cache' 14 $fg $true
$storagePath=New-Caption $storageLayout '' 10 $cyan
$storagePath.MaximumSize=New-Object Drawing.Size(390,0)
$storageFree=New-Caption $storageLayout '' 10 $fg
$storageFree.MaximumSize=New-Object Drawing.Size(390,0)
$storageChoose=New-Action $storageLayout 'Másik meghajtó / mappa…' '#245B58' 240
$storageDefault=New-Action $storageLayout 'Alapértelmezett cache' '#29414E' 240
$storageMeasure=New-Action $storageLayout 'Cache méretének mérése' '#29414E' 240
$storageClean=New-Action $storageLayout 'Kiválasztott cache törlése' '#653C4B' 240
$storageResult=New-Caption $storageLayout 'A források és riportok nem kerülnek törlésre.' 9 $muted
$storageResult.MaximumSize=New-Object Drawing.Size(390,0)
$null=New-Caption $storageLayout 'Élő hardverterhelés (rendszerszintű)' 13 $fg $true
$monitorText=New-Caption $storageLayout 'Mérés indítása a fül megnyitásakor.' 10 $cyan
$monitorText.MaximumSize=New-Object Drawing.Size(390,0)
$null=New-Caption $storageLayout 'GPU: legterheltebb motor; VRAM: dedikált memória összesen. Nem folyamatonkénti mérés.' 9 $muted
function Test-StorageBusy { return ($script:runState -eq 'RUNNING' -or $script:unsafeState -or $script:updateWorker -or $script:cacheWorker) }
function Update-StorageDisplay {
    $storagePath.Text=$cacheRoot
    try { $storageFree.Text=('Cache: {0:N1} GiB szabad | Riport: {1:N1} GiB szabad' -f ((Get-FreeBytes $cacheRoot)/1GB),((Get-FreeBytes $root)/1GB)) }
    catch { $storageFree.Text='A cache meghajtó nem elérhető.' }
    foreach($control in @($storageChoose,$storageDefault,$storageMeasure,$storageClean)) { $control.Enabled=!(Test-StorageBusy) }
}
$storageChoose.Add_Click({
    if (Test-StorageBusy) { return }
    $dialog=New-Object Windows.Forms.FolderBrowserDialog
    try {
        $dialog.Description='Válassz egy mappát a helyi SSD-n. A Studio saját VIREX-Studio-Cache almappát készít.'
        if ($dialog.ShowDialog($form) -eq 'OK') {
            Set-CacheRoot (Select-CacheRoot $dialog.SelectedPath)
            $storageResult.Text='Új cache aktív. A korábbi cache nem lett áthelyezve vagy törölve.'
        }
    } catch { $storageResult.Text=$_.Exception.Message } finally { $dialog.Dispose(); Update-StorageDisplay }
})
$storageDefault.Add_Click({
    if (Test-StorageBusy) { return }
    try { Set-CacheRoot $defaultCacheRoot; $storageResult.Text='Alapértelmezett cache aktív.' } catch { $storageResult.Text=$_.Exception.Message }
    Update-StorageDisplay
})
function Start-CacheOperation([bool]$delete) {
    if (Test-StorageBusy) { return }
    if (!(Test-CacheRoot $cacheRoot)) { throw 'Nem biztonságos cache-mappa.' }
    if ($delete -and [Windows.Forms.MessageBox]::Show($form,"Végleg törlöd a cache és target almappákat innen?"+[Environment]::NewLine+$cacheRoot,'Cache törlése','YesNo','Warning') -ne 'Yes') { return }
    $operation={
        param($base,$delete)
        $ErrorActionPreference='Stop'
        # Explicit traversal; refuse any reparse point before deleting anything.
        $dirs=New-Object 'System.Collections.Generic.List[string]'
        $files=New-Object 'System.Collections.Generic.List[string]'
        $bytes=0L
        foreach ($name in @('cache','target')) {
            $path=Join-Path $base $name
            if (!(Test-Path -LiteralPath $path)) { continue }
            $stack=New-Object 'System.Collections.Generic.Stack[string]'
            $stack.Push($path)
            while ($stack.Count) {
                $dir=$stack.Pop()
                $item=Get-Item -LiteralPath $dir -Force
                if (!$item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Átirányított cache: $dir" }
                $dirs.Add($dir)
                foreach($child in Get-ChildItem -LiteralPath $dir -Force) {
                    if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Átirányított cache-elem: $($child.FullName)" }
                    if ($child.PSIsContainer) { $stack.Push($child.FullName) }
                    else { $files.Add($child.FullName); $bytes+=$child.Length }
                }
            }
        }
        if ($delete) {
            foreach($file in $files) { Remove-Item -LiteralPath $file -Force }
            for($i=$dirs.Count-1;$i -ge 0;$i--) { [IO.Directory]::Delete($dirs[$i],$false) }
        }
        return @{Bytes=$bytes;Deleted=$delete}
    }
    $script:cacheWorker=[PowerShell]::Create()
    try {
        $null=$cacheWorker.AddScript($operation.ToString()).AddArgument($cacheRoot).AddArgument($delete)
        $script:cacheJob=$cacheWorker.BeginInvoke()
        $runButton.Enabled=$false; $updateButton.Enabled=$false
        $storageResult.Text=if($delete){'Takarítás folyamatban…'}else{'Méret számítása…'}
        Update-StorageDisplay
    } catch { $cacheWorker.Dispose(); $script:cacheWorker=$null; throw }
}
$storageMeasure.Add_Click({try{Start-CacheOperation $false}catch{$storageResult.Text=$_.Exception.Message}})
$storageClean.Add_Click({try{Start-CacheOperation $true}catch{$storageResult.Text=$_.Exception.Message}})
$script:storageTimer=New-Object Windows.Forms.Timer
$storageTimer.Interval=3000
$storageTimer.Add_Tick({
    if ($cacheWorker -and $cacheJob.IsCompleted) {
        try {
            $r=@($cacheWorker.EndInvoke($cacheJob))[0]
            if ($cacheWorker.HadErrors -or !$r) { throw 'A cache művelet nem fejeződött be.' }
            $storageResult.Text=if($r.Deleted){'Törölve: {0:N2} GiB' -f ($r.Bytes/1GB)}else{'Cache mérete: {0:N2} GiB' -f ($r.Bytes/1GB)}
        } catch { $storageResult.Text=$_.Exception.GetBaseException().Message }
        finally {
            $cacheWorker.Dispose(); $script:cacheWorker=$null
            $runButton.Enabled=!$unsafeState; $updateButton.Enabled=!$unsafeState
        }
    }
    Update-StorageDisplay
    if ($monitorWorker -and $monitorJob.IsCompleted) {
        try {
            $r=@($monitorWorker.EndInvoke($monitorJob))[0]
            if ($r) {
                $monitorText.Text=('CPU: {0} % | RAM: {1} %'+[Environment]::NewLine+'GPU: {2} % | VRAM: {3} GiB') -f $(if($null -eq $r.CPU){'N/A'}else{$r.CPU}),$(if($null -eq $r.RAM){'N/A'}else{$r.RAM}),$(if($null -eq $r.GPU){'N/A'}else{$r.GPU}),$(if($null -eq $r.VRAM){'N/A'}else{$r.VRAM})
                if($runState -eq 'RUNNING'){
                    $script:monitorSamples++
                    foreach($key in @('CPU','RAM','GPU','VRAM')) { if($null -ne $r[$key] -and (!$monitorPeak.ContainsKey($key) -or $r[$key] -gt $monitorPeak[$key])){$monitorPeak[$key]=$r[$key]} }
                }
            }
        } catch { $monitorText.Text='Hardvermérés nem elérhető.' }
        finally { $monitorWorker.Dispose(); $script:monitorWorker=$null }
    }
    if (!$monitorWorker -and ($runState -eq 'RUNNING' -or $tabs.SelectedTab -eq $storageTab)) {
        $sample={
            $r=@{CPU=$null;RAM=$null;GPU=$null;VRAM=$null}
            try {$r.CPU=[math]::Round((Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime,0)}catch{}
            try {$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; if($os.TotalVisibleMemorySize -gt 0){$r.RAM=[math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize),0)}}catch{}
            try {
                $engines=@(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop)
                if($engines.Count){
                    $max=($engines | Group-Object { $_.Name -replace '^pid_\d+_','' } | ForEach-Object { ($_.Group | Measure-Object UtilizationPercentage -Sum).Sum } | Measure-Object -Maximum).Maximum
                    $r.GPU=[math]::Round([math]::Min(100,$max),0)
                }
            }catch{}
            try {$a=@(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop); if($a.Count){$r.VRAM=[math]::Round(($a | Measure-Object DedicatedUsage -Sum).Sum/1GB,2)}}catch{}
            return $r
        }
        $script:monitorWorker=[PowerShell]::Create()
        try {$null=$monitorWorker.AddScript($sample.ToString()); $script:monitorJob=$monitorWorker.BeginInvoke()} catch {$monitorWorker.Dispose();$script:monitorWorker=$null}
    }
})
Update-StorageDisplay
$storageTimer.Start()


# Strict declarative profiles: no shell commands or arbitrary arguments.
function ConvertFrom-StudioProfile([string]$json) {
    if ([string]::IsNullOrWhiteSpace($json) -or $json.Length -gt 4096) { throw 'Üres vagy túl hosszú tesztprofil.' }
    $data=ConvertFrom-Json -InputObject $json -ErrorAction Stop
    if ($data -isnot [pscustomobject]) { throw 'A tesztprofil egy JSON objektum.' }
    $keys=@('v','target','check','workspace','clippy','repeat','agility','depth')
    if($data.v -in @(2,3)){$keys+=@('crate','test','threads')}
    if($data.v -eq 3){$keys+=@('release','ignored')}
    $actual=@($data.PSObject.Properties.Name)
    if ($actual.Count -ne $keys.Count -or @($actual | Where-Object { $_ -cnotin $keys }).Count) { throw 'Ismeretlen vagy hiányzó profilmező.' }
    if ($data.v -isnot [int] -or $data.v -notin @(1,2,3)) { throw 'Nem támogatott profilverzió.' }
    if ($data.target -isnot [string] -or $data.target.Length -gt 400) { throw 'Érvénytelen tesztcél.' }
    foreach ($key in @('check','workspace','clippy','agility','depth')) {
        if ($data.$key -isnot [bool]) { throw "A $key mező csak true vagy false lehet." }
    }
    if ($data.repeat -isnot [int] -or $data.repeat -notin @(1,3)) { throw 'Az ismétlés csak 1 vagy 3 lehet.' }
    if (!$data.check -and !$data.workspace -and !$data.clippy -and !$data.depth) { throw 'Legalább egy teszt szükséges.' }
    if($data.v -eq 3 -and ($data.release -isnot [bool] -or $data.ignored -isnot [bool])) {
        throw 'A release és ignored mező csak true vagy false lehet.'
    }
    if($data.v -in @(2,3)){
        if($data.crate -isnot [string] -or $data.test -isnot [string] -or $data.threads -isnot [int] -or $data.threads -notin @(0,1)){throw 'Érvénytelen crate / test / threads mező.'}
        if(!$data.workspace){throw 'A célzott crate teszthez workspace:true szükséges.'}
        $null=Get-ManualTestArgs $data.crate $data.test ($data.threads -eq 1) '' ([bool]$data.release) ([bool]$data.ignored)
    }
    $target=ConvertTo-RevisionTarget $data.target
    if($data.v -eq 3 -and !$target.ExpectedSha){throw 'A v3 profil teljes commit SHA-t tartalmazó GitHub URL-t igényel.'}
    return @{Target=$target;Options=$data}
}
function Apply-StudioProfile([string]$json) {
    if ($modeSwitch.Checked -or (Test-StorageBusy)) { throw 'Profil csak nyugalmi MANUAL módban tölthető be.' }
    $profile=ConvertFrom-StudioProfile $json
    $d=$profile.Options
    $script:revisionTarget=$profile.Target
    $prAddress.Text=$profile.Target.SourceUrl
    $combo.SelectedItem=@($combo.Items | Where-Object {$_.Mode -eq 'revision'})[0]
    Update-TargetControls
    $prStatus.Text="Betöltve: $($profile.Target.Name)"
    $ckCheck.Checked=$d.check; $ckTest.Checked=$d.workspace; $ckClippy.Checked=$d.clippy
    $ckRepeat.Checked=($d.repeat -eq 3); $ckAgility.Checked=$d.agility; $ckDepth.Checked=$d.depth
    $ckFull.Checked=$false; $ckBench.Checked=$false; $ckWarp.Checked=$false
    $manualCrate.Text=if($d.v -in @(2,3)){$d.crate}else{''};$manualTest.Text=if($d.v -in @(2,3)){$d.test}else{''};$manualSerial.Checked=($d.v -in @(2,3) -and $d.threads -eq 1)
    $manualRelease.Checked=($d.v -eq 3 -and $d.release); $manualIgnored.Checked=($d.v -eq 3 -and $d.ignored)
    $profileStatus.Text='Profil betöltve. Ellenőrizd a pipákat, majd Futtatás. Semmi nem indult el.'
}
function Get-AutoPlan([bool]$d3d) {
    $plan=@('L0 | Runner / Git / revision','L1 | Build validation')
    if($d3d){$plan+=@('L2 | D3D12 depth bounds x3')}
    $plan+=@('L3 | Workspace tests x1','L4 | Strict Clippy')
    return $plan
}
function Get-StepLevel($step) {
    if($step.Name -match '^L([1-4]) \|'){return [int]$Matches[1]}
    return 0
}
$labTab=New-ReviewPage $tabs 'Test Lab'
$labPanel=New-Object Windows.Forms.Panel
$labPanel.Dock='Fill';$labPanel.AutoScroll=$true;$labTab.Controls.Add($labPanel)
$labLayout=New-Stack $labPanel 'TopDown' $false
$labLayout.AutoSize=$true;$labLayout.AutoSizeMode='GrowAndShrink';$labLayout.Padding=New-Object Windows.Forms.Padding(18,12,10,12)
$null=New-Caption $labLayout 'VALIDATION PIPELINE' 18 $cyan $true
$labHint=New-Caption $labLayout 'AUTO: egy commit, egy cache, egymásra épülő ellenőrzések. MANUAL: saját pipák vagy GPT-profil.' 10 $fg
$labHint.MaximumSize=New-Object Drawing.Size(520,0)
$autoProfile=New-Object Windows.Forms.ComboBox
$autoProfile.Width=300;$autoProfile.DropDownStyle='DropDownList'
$null=$autoProfile.Items.Add('General Rust workspace')
$null=$autoProfile.Items.Add('D3D12 / Agility validation')
$autoProfile.SelectedIndex=0
$labLayout.Controls.Add($autoProfile)
$labPlan=New-Object Windows.Forms.ListBox
$labPlan.Width=400;$labPlan.Height=125;$labPlan.BackColor=$panel;$labPlan.ForeColor=$fg;$labPlan.Font=Font 11
$labLayout.Controls.Add($labPlan)
$labState=New-Caption $labLayout 'MANUAL · ready' 11 $cyan $true
$null=New-Caption $labLayout 'GPT test profile · MANUAL' 12 $fg $true
$profileBox=New-Object Windows.Forms.TextBox
$profileBox.Multiline=$true;$profileBox.ScrollBars='Vertical';$profileBox.Width=400;$profileBox.Height=115;$profileBox.MaxLength=4096
$profileBox.Font=Font 9 'Consolas';$labLayout.Controls.Add($profileBox)
$profileLoad=New-Action $labLayout 'Profil betöltése' '#245B58' 185
$profileStatus=New-Caption $labLayout 'JSON v1/v2/v3 · csak ismert mezők · nem futtat parancsot.' 9 $muted
$profileStatus.MaximumSize=New-Object Drawing.Size(400,0)
$null=New-Caption $labLayout 'MANUAL · célzott lib teszt (opcionális)' 12 $fg $true
$manualCrate=New-Object Windows.Forms.TextBox;$manualCrate.Width=400;$manualCrate.MaxLength=100
$labLayout.Controls.Add($manualCrate)
$null=New-Caption $labLayout 'Crate neve (pl. victory-shader); üres = workspace' 9 $muted
$manualTest=New-Object Windows.Forms.TextBox;$manualTest.Width=400;$manualTest.MaxLength=300
$labLayout.Controls.Add($manualTest)
$null=New-Caption $labLayout 'Pontos tesztnév; üres = teljes crate lib' 9 $muted
$manualRelease=Check $labLayout 'Release build (optimalizált)' 0 0 300 $false
$manualIgnored=Check $labLayout 'Csak az ignored jelölésű pontos teszt' 0 0 330 $false
$manualSerial=Check $labLayout 'Soros futtatás (1 tesztszál)' 0 0 300 $false
$profileLoad.Add_Click({try{Apply-StudioProfile $profileBox.Text}catch{$profileStatus.Text=$_.Exception.Message}})
function Update-LabProgress([int]$runningLevel=-1) {
    $labPlan.BeginUpdate()
    try {
        $labPlan.Items.Clear()
        foreach($line in (Get-AutoPlan ($autoProfile.SelectedIndex -eq 1))){
            $id=$line.Substring(1,1)
            $result=if($levelResults.ContainsKey($id)){$levelResults[$id]}elseif([int]$id -eq $runningLevel){'RUNNING'}else{'PENDING'}
            $null=$labPlan.Items.Add("$line  [$result]")
        }
    } finally {$labPlan.EndUpdate()}
}
function Update-ExecutionMode {
    $busy=$script:runState -eq 'RUNNING' -or $script:unsafeState
    $auto=$modeSwitch.Checked
    if ($auto -and !(Test-WorkspaceTarget)) { $modeSwitch.Checked=$false; return }
    $modeSwitch.Text=if($auto){'AUTO  |  MANUAL'}else{'MANUAL  |  AUTO'}
    $modeSwitch.BackColor=if($auto){Color '#087669'}else{Color '#355764'}
    $modeSwitch.Enabled=!$busy -and (Test-WorkspaceTarget)
    $autoProfile.Enabled=$auto -and !$busy -and !(Test-LocalTarget)
    if(Test-LocalTarget){$autoProfile.SelectedIndex=0}
    $profileBox.Enabled=!$auto -and !$busy
    $profileLoad.Enabled=$profileBox.Enabled
    foreach($c in @($manualCrate,$manualTest,$manualSerial,$manualRelease,$manualIgnored)){$c.Enabled=!$auto -and !$busy -and (Test-WorkspaceTarget)}
    if($auto){foreach($c in @($ckCheck,$ckTest,$ckClippy,$ckRepeat,$ckAgility,$ckDepth,$ckFull,$ckWarp,$ckBench)){$c.Enabled=$false}}
    $labPlan.Items.Clear()
    if($auto){Update-LabProgress}
    else{$null=$labPlan.Items.Add('MANUAL · kiválasztott ellenőrzések')}
    if(!$busy){$labState.Text=if($auto){'AUTO · ready'}else{'MANUAL · ready'}}
}
$modeSwitch.Add_CheckedChanged({
    if($modeSwitch.Checked){
        $script:levelResults=@{}
        $target=Get-SelectedRepository
        if($target -and $target.Origin -ieq $belobugTarget.Origin -and ($target.Branch -eq 'refs/pull/360/head' -or $target.ExpectedSha -eq '2083466bb80691d99b917d09cd9d55084338c55a')){$autoProfile.SelectedIndex=1}
        $tabs.SelectedTab=$labTab
    }else{
        foreach($c in @($ckCheck,$ckTest,$ckClippy,$ckRepeat)){$c.Enabled=$true}
        Update-TargetControls
    }
    Update-ExecutionMode
})
$autoProfile.Add_SelectedIndexChanged({if($script:runState -ne 'RUNNING'){$script:levelResults=@{}};Update-ExecutionMode})
function Write-AutoCheckpoint([int]$level,[string]$state) {
    if (!$script:machine.AutoMode -or !$runDir) { return }
    $entries = @($steps | Where-Object { (Get-StepLevel $_) -eq $level })
    if ($state -eq 'PASS') { $state = Get-CompletedValidationStatus $entries }
    $lines=@("VIREX $studioVersion | AUTO LEVEL $level | $state","Target: $($runPreset.Name)","Commit: $($runPreset.Sha)","Agility staged: $($machine.AgilityStaged)")
    foreach($entry in $entries){
        $lines+=@("[$($entry.Status)] $($entry.Name) | exit=$($entry.Exit) | $($entry.Seconds)s",$entry.Command)
        if($entry.GpuExecution){$lines+=('GPU execution: '+$entry.GpuExecution)}
        if($entry.GpuEvidence){$lines+=$entry.GpuEvidence}
        if($entry.Error){$lines+=$entry.Error}
        $lines+=@(((Read-Shared $entry.Out)+[Environment]::NewLine+(Read-Shared $entry.Err)) -split '\r?\n' | Where-Object {$_ -match 'test result:|error:|FAILED|skipped|Finished'} | Select-Object -Last 40)
    }
    [IO.File]::WriteAllText((Join-Path $runDir ("LEVEL-$level.txt")),(Redact ($lines -join [Environment]::NewLine)),[Text.Encoding]::UTF8)
    $script:levelResults["$level"]=$state
    $labState.Text="L$level | $state"
    Update-LabProgress
}
Update-ExecutionMode


function Get-ManualTestArgs([string]$crate,[string]$test,[bool]$serial,[string]$lock,[bool]$release=$false,[bool]$ignored=$false) {
    if($crate -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$'){throw 'Érvénytelen crate név.'}
    if($test -and $test -cnotmatch '^[A-Za-z0-9_]+(?:::[A-Za-z0-9_]+)*$'){throw 'Érvénytelen pontos tesztnév.'}
    if($test.Length -gt 300){throw 'Túl hosszú tesztnév.'}
    if($ignored -and !$test){throw 'Az ignored futtatáshoz pontos tesztnév kell.'}
    $buildProfile=if($release){' --release'}else{''}
    $arg="test$buildProfile -p $crate --lib$lock"
    if($test){$arg+=" $test -- --exact --nocapture"}else{$arg+=' -- --nocapture'}
    if($ignored){$arg+=' --ignored'}
    if($serial){$arg+=' --test-threads=1'}
    return $arg
}
function Get-CrashPackage([string]$output,[string]$errors,$exitCode) {
    $combined=$output+[Environment]::NewLine+$errors
    if($exitCode -ne -1073741819 -and $combined -notmatch '(?i)0xc0000005|STATUS_ACCESS_VIOLATION'){return $null}
    # Cargo omits -p for a default/single-package library. Accept only one
    # unambiguous rerun hint; never execute text taken from a log.
    $hints=@([regex]::Matches($combined,'(?m)^error: test failed, to rerun pass [\x60]([^\r\n\x60]+)[\x60][ \t\r]*$') | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique)
    if($hints.Count -ne 1){return $null}
    if($hints[0] -ceq '--lib'){return '<default-lib>'}
    if($hints[0] -cmatch '^-p ([A-Za-z0-9][A-Za-z0-9_-]{0,99}) --lib$'){return $Matches[1]}
    return $null
}
function Get-CrashTestArgs([string]$package,[string]$test,[string]$lock) {
    if($package -ne '<default-lib>'){return Get-ManualTestArgs $package $test $true $lock}
    if($test -and ($test.Length -gt 300 -or $test -cnotmatch '^[A-Za-z0-9_]+(?:::[A-Za-z0-9_]+)*$')){throw 'Invalid exact diagnostic test.'}
    if($test){return "test --lib$lock $test -- --exact --nocapture --test-threads=1"}
    return "test --lib$lock -- --nocapture --test-threads=1"
}
function Get-CrashExecutable([string]$errors) {
    $found=[regex]::Matches($errors,"(?im)process didn't exit successfully:[^\r\n]*[\\/]([A-Za-z0-9_-]+-[a-f0-9]{8,64}\.exe)(?=\s)")
    $names=@($found | ForEach-Object {$_.Groups[1].Value} | Select-Object -Unique)
    if($names.Count -eq 1){return $names[0]}
    return ''
}
function Get-SerialCrashCandidate([string]$output) {
    $found=[regex]::Matches($output,'(?m)^test ([A-Za-z0-9_]+(?:::[A-Za-z0-9_]+)*) \.\.\. ')
    if(!$found.Count){return $null}
    $last=$found[$found.Count-1]
    $tail=$output.Substring($last.Index+$last.Length)
    # A completion can be on a separate line with nocapture. Never infer a culprit from an already completed test.
    if($tail -match '(?m)(?:^|\s)(?:ok|FAILED|ignored)(?:,.*)?\s*$'){return $null}
    $name=$last.Groups[1].Value
    if($name.Length -gt 300){return $null}
    return $name
}
function Start-CrashDiagnostics($step,[string]$out,[string]$err) {
    if(!$script:machine.AutoMode -or $script:diagnosticActive -or $step.Kind -ne 'tests' -or (Get-StepLevel $step) -ne 3){return $false}
    $package=Get-CrashPackage $out $err $step.Exit
    if(!$package){return $false}
    # Preserve evidence and original FAIL before any retry.
    Write-AutoCheckpoint 3 'FAIL'
    $script:machine.CrashPackage=$package
    $script:machine.CrashExecutable=Get-CrashExecutable $err
    $script:machine.CrashOriginalExit=$step.Exit
    $script:machine.CrashResult='PENDING'
    $script:diagnosticActive=$true
    $script:queue.Clear()
    try{
        $script:runState='FAIL'
        Save-Report
        Copy-Item -LiteralPath (Join-Path $runDir 'REPORT.txt') -Destination (Join-Path $runDir 'ORIGINAL-FAIL.txt')
    }finally{$script:runState='RUNNING'}
    $lock=if(Test-Path -LiteralPath (Join-Path $workDir 'Cargo.lock') -PathType Leaf){' --locked'}else{''}
    Add-Step "D1 | Serial crash isolation: $package" $workspaceCargo (Get-CrashTestArgs $package '' $lock) 'diagserial'
    $progress.Maximum=$steps.Count+$queue.Count
    Add-Log ("Original FAIL preserved; diagnostic retry of "+$package+[Environment]::NewLine) $cyan
    return $true
}
function Add-CrashEventStep {
    # Fixed local read-only Windows event query; no registry changes or dumps.
    $exeName=if($script:machine.CrashExecutable){[regex]::Escape($script:machine.CrashExecutable)}elseif($script:machine.CrashPackage -ne '<default-lib>'){[regex]::Escape($script:machine.CrashPackage.Replace('-','_'))+'-[a-f0-9]+\.exe'}else{'(?!)'}
    $since=$script:started.ToUniversalTime().ToString('o')
    $command='$ErrorActionPreference="Stop"; try { $events=@(Get-WinEvent -FilterHashtable @{LogName="Application";Id=1000;StartTime=[datetime]::Parse("'+$since+'").ToLocalTime()} -MaxEvents 50 -ErrorAction Stop | Where-Object {$_.ProviderName -eq "Application Error" -and $_.Message -match "(?i)'+$exeName+'"}); if(!$events.Count){"No matching crash event found."}else{foreach($event in $events){$event.TimeCreated.ToString("o"); $event.Message}} } catch {"Crash event unavailable: "+$_.Exception.Message}'
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Add-Step 'D3 | Windows Application Error evidence' (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') "-NoProfile -NonInteractive -EncodedCommand $encoded" 'diagevent'
}
function Complete-CrashStep($step,[string]$out,[string]$err,[bool]$valid) {
    if($step.Kind -eq 'diagserial'){
        $script:machine.CrashResult=if($valid){'NOT REPRODUCED IN SERIAL RUN'}else{'SERIAL RUN FAILED'}
        if(!$valid -and ($step.Exit -eq -1073741819 -or ($out+$err) -match '(?i)0xc0000005|STATUS_ACCESS_VIOLATION')){
            $candidate=Get-SerialCrashCandidate $out
            if($candidate){
                $script:machine.CrashCandidate=$candidate
                $lock=if(Test-Path -LiteralPath (Join-Path $workDir 'Cargo.lock') -PathType Leaf){' --locked'}else{''}
                Add-Step "D2 | Exact candidate: $candidate" $workspaceCargo (Get-CrashTestArgs $script:machine.CrashPackage $candidate $lock) 'diagexact'
            }
        }
        Add-CrashEventStep
    }elseif($step.Kind -eq 'diagexact'){
        $script:machine.CrashResult=if($valid){'EXACT CANDIDATE PASSED; ORIGINAL CRASH REMAINS'}else{'EXACT CANDIDATE FAILED; INSPECT EXIT AND LOG'}
    }
    $progress.Maximum=$steps.Count+$queue.Count
}
