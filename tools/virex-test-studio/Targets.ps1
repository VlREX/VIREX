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
function Test-DepthResult([string]$output, [string]$errors) {
    # --exact selects one named test; nocapture output can split its name and ok.
    return ($output -match 'test result: ok\. 1 passed; 0 failed; 0 ignored') -and
        ($output -match 'pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws') -and
        (($output+"`n"+$errors) -notmatch '(?im)no host depth bounds support; skipped|no PC dxc\.exe; skipped')
}
function Add-WorkspaceCargoSteps([string]$cargo, [string]$directory) {
    $lock = if (Test-Path -LiteralPath (Join-Path $directory 'Cargo.lock') -PathType Leaf) { ' --locked' } else { '' }
    Add-Step 'Cargo version' $cargo '--version'
    if ($script:machine.AgilityRequested) {
        if (!(Test-AgilitySource $directory)) { throw 'A kiválasztott revízióban nincs támogatott Agility SDK integráció. Használd a Belobug #360 PR-t vagy kapcsold ki az Agility opciót.' }
        Add-Step 'Prepare D3D12 Agility SDK' $cargo 'xtask agility' 'agility'
    }
    if ($ckCheck.Checked) { Add-Step 'Workspace check' $cargo "check --workspace$lock" }
    if ($ckTest.Checked) {
        for ($pass=1; $pass -le $script:machine.Repeat; $pass++) {
            Add-Step "Workspace tests ($pass/$($script:machine.Repeat))" $cargo "test --workspace$lock -- --nocapture" 'tests'
        }
    }
    if ($script:machine.DepthRequested) {
        for ($pass=1; $pass -le $script:machine.Repeat; $pass++) {
            Add-Step "D3D12 depth bounds ($pass/$($script:machine.Repeat))" $cargo "test -p victory-gpu --lib$lock pipeline::host::tests::depth_bounds_pipeline_loads_and_filters_draws -- --exact --nocapture" 'depthtest'
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
