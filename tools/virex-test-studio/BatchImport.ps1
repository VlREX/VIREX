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
