# Explicit import from the configured conversation. Never executes imported text.
$script:importPending=$null
$batchImport=New-Action $labLayout 'ChatGPT tesztterv importálása' '#355764' 270
$batchImportMacro=New-Action $labLayout 'Import makró megnyitása' '#355764' 245
$batchImportStatus=New-Caption $labLayout 'IMPORT · várakozik' 9 $muted
$batchImportStatus.MaximumSize=New-Object Drawing.Size(400,0)
function New-BatchImportJob($cfg,[string]$id){
    if($id -cnotmatch '^[0-9a-f]{32}$'){throw 'Invalid import id.'}
    $name='virex-import-'+$id+'.csv'
    $url=([uri]$cfg.html).AbsoluteUri+'?direct=1&closeRPA=0&closeBrowser=0&storage=xfile&macro=VIREX_BatchImport.js&cmd_var1='+[uri]::EscapeDataString($name)+'&cmd_var2='+[uri]::EscapeDataString($cfg.url)+'&cmd_var3='+$id
    return @{Path=(Join-Path $cfg.data $name);Url=$url;Id=$id}
}
$batchImportMacro.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'VIREX_BatchImport.js')+'"')})
$batchImport.Add_Click({
    if($script:batchActive -or $script:importPending -or $script:bridgePending -or (Test-StorageBusy)){return}
    try{
        if(!$script:bridgeConfig){throw 'Előbb mentsd az AutoBridge konfigurációt.'}
        $cfg=Get-BridgeConfig $bridgeTarget.Text.Trim() $bridgeHtml.Text.Trim() $bridgeData.Text.Trim() $false
        if($cfg.url -cne $script:bridgeConfig.url -or $cfg.html -cne $script:bridgeConfig.html -or $cfg.data -cne $script:bridgeConfig.data){throw 'Mentsd a módosított beállításokat.'}
        if($batchBox.Text -and [Windows.Forms.MessageBox]::Show($form,'Felülírod a jelenlegi teszttervet, ha az import sikeres?','Import','YesNo','Question') -ne 'Yes'){return}
        $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        $chrome=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","$pf86\Google\Chrome\Application\chrome.exe","$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
        if(!$chrome){throw 'Chrome nem található.'}
        $job=New-BatchImportJob $cfg ([guid]::NewGuid().ToString('N'))
        Start-Process -FilePath $chrome -ArgumentList ('"'+$job.Url+'"') -ErrorAction Stop
        $script:importPending=@{Job=$job;Deadline=[DateTime]::UtcNow.AddMinutes(2);Original=$batchBox.Text}
        $batchImport.Enabled=$false;$batchStart.Enabled=$false
        $batchImportStatus.Text='IMPORT · várja a makrót.'
    }catch{$batchImportStatus.Text=$_.Exception.Message}
})
$importTimer=New-Object Windows.Forms.Timer
$importTimer.Interval=750
$importTimer.Add_Tick({
    if(!$script:importPending){return}
    $pending=$script:importPending;$job=$pending.Job
    if(Test-Path -LiteralPath $job.Path -PathType Leaf){
        try{
            if((Get-Item -LiteralPath $job.Path).Length -gt 500000){throw 'Import file too large.'}
            $row=@(Import-Csv -LiteralPath $job.Path -Header 'id','result','payload' -Encoding UTF8)
            if($row.Count -ne 1 -or $row[0].id -cne $job.Id){throw 'Invalid import response.'}
            if($row[0].result -ne 'OK'){throw 'Makróhiba: '+$row[0].payload}
            $items=@(ConvertFrom-StudioBatch $row[0].payload)
            if($batchBox.Text -cne $pending.Original -or $script:batchActive){throw 'A helyi terv időközben megváltozott.'}
            $batchBox.Text=$row[0].payload
            $batchImportStatus.Text='IMPORT PASS · '+$items.Count+' profil. Ellenőrizd, majd START.'
        }catch{$batchImportStatus.Text='IMPORT FAIL · '+$_.Exception.Message}
        Remove-Item -LiteralPath $job.Path -Force -ErrorAction SilentlyContinue
        $script:importPending=$null;$batchImport.Enabled=$true;$batchStart.Enabled=!$script:batchActive
    }elseif([DateTime]::UtcNow -gt $pending.Deadline){
        $script:importPending=$null;$batchImport.Enabled=$true;$batchStart.Enabled=!$script:batchActive
        $batchImportStatus.Text='IMPORT TIMEOUT · ellenőrizd a Ui.Vision naplót.'
    }
})
$importTimer.Start()

# PR request has its own macro and explicit consent; never merges or runs tests.
$null=New-Caption $labLayout 'PR INDÍTÁSA · DEVELOPMENT REQUEST' 13 $cyan $true
$null=New-Caption $labLayout 'GitHub fork (owner/repository)' 9 $muted
$prRequestRepo=New-Object Windows.Forms.TextBox
$prRequestRepo.Width=400;$prRequestRepo.MaxLength=141;$prRequestRepo.Text='VlREX/VIctory-Belobug-AMD';$labLayout.Controls.Add($prRequestRepo)
$null=New-Caption $labLayout 'Javítás célja / fejlesztési feladat' 9 $muted
$prRequestTask=New-Object Windows.Forms.TextBox
$prRequestTask.Width=400;$prRequestTask.Height=75;$prRequestTask.Multiline=$true;$prRequestTask.MaxLength=2000;$labLayout.Controls.Add($prRequestTask)
$prRequestStart=New-Action $labLayout 'PR indítása · START' '#245B58' 220
$prRequestMacro=New-Action $labLayout 'PR makró megnyitása' '#355764' 220
$prRequestStatus=New-Caption $labLayout 'IDLE · add meg a fejlesztési feladatot.' 9 $muted
$prRequestStatus.MaximumSize=New-Object Drawing.Size(400,0)
function New-OrchestratorRequest([string]$repo,[string]$task){
    if($repo -cnotmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,100}$' -or $repo.Split('/')[1] -in @('.','..')){throw 'Érvénytelen GitHub fork.'}
    if([string]::IsNullOrWhiteSpace($task) -or $task.Length -gt 2000){throw 'Add meg a fejlesztési célt (max. 2000 karakter).'}
    $lines=@(
        'VIREX ORCHESTRATOR | PR REQUEST',
        ('Repository: '+$repo),
        ('Feladat: '+$task),
        'Vizsgáld át a forráskódot, készíts célzott javítást, ellenőrizd és hozz létre Draft PR-t a megadott forkban. Ne merge-eld és ne publikáld a kész verziót automatikusan.',
        'A válaszban adj pontosan egy JSON kódblokkot ezzel a sémával: {"virex_batch":1,"profiles":[...]} . A profiles tömb 1-12 szigorú, v3 Studio profilt tartalmazzon, teljes commit SHA-val. Csak az engedélyezett profilmezőket használd, ne shell parancsokat.',
        'A teszttervet a Studio a felhasználó jóváhagyása után futtatja. Tüntesd fel, mit ellenőriztél és mi maradt teszteletlen.'
    )
    return $lines -join [Environment]::NewLine
}
$prRequestMacro.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'VIREX_PRRequest.js')+'"')})
$prRequestStart.Add_Click({
    if($script:batchActive -or $script:importPending -or $script:bridgePending -or (Test-StorageBusy)){return}
    try{
        if(!$script:bridgeConfig){throw 'Előbb mentsd az AutoBridge konfigurációját.'}
        $cfg=Get-BridgeConfig $bridgeTarget.Text.Trim() $bridgeHtml.Text.Trim() $bridgeData.Text.Trim() $false
        if($cfg.url -cne $script:bridgeConfig.url -or $cfg.html -cne $script:bridgeConfig.html -or $cfg.data -cne $script:bridgeConfig.data){throw 'Mentsd a módosított beállításokat.'}
        $request=New-OrchestratorRequest $prRequestRepo.Text.Trim() $prRequestTask.Text.Trim()
        if(!(Confirm-StudioRun ('A következő fejlesztési kérést elküldöd a mentett ChatGPT-beszélgetésbe?'+[Environment]::NewLine+$request))){return}
        Start-BridgeTransfer $cfg $request 'VIREX_PRRequest.js'
        $prRequestStatus.Text='Kérés átadva a makrónak. Az eredmény az AutoBridge állapotnál látszik.'
    }catch{$prRequestStatus.Text=$_.Exception.Message}
})
