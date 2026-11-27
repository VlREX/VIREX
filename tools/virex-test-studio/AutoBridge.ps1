# Opt-in local report handoff. Never automatically sends messages.
function Test-BridgeTarget([string]$url) {
    return $url -cmatch '^https://chatgpt\.com/(?:c/|g/g-[A-Za-z0-9_-]+/c/)[0-9a-fA-F-]{36}$'
}
function Get-BridgeConfig([string]$url,[string]$html,[string]$data,[bool]$enabled) {
    if (!(Test-BridgeTarget $url)) { throw 'Pontos ChatGPT beszélgetés URL szükséges.' }
    if ($html -notmatch '^[A-Za-z]:\\' -or [IO.Path]::GetExtension($html) -ine '.html' -or !(Test-Path -LiteralPath $html -PathType Leaf)) { throw 'Válaszd ki a helyi Ui.Vision autorun HTML-t.' }
    if ($data -notmatch '^[A-Za-z]:\\' -or !(Test-Path -LiteralPath $data -PathType Container) -or (Split-Path -Leaf ($data.TrimEnd('\'))) -ine 'datasources') { throw 'Válaszd ki a Ui.Vision datasources mappáját.' }
    return [pscustomobject]@{url=$url;html=$html;data=$data;enabled=$enabled}
}
function New-BridgePayload($cfg,[string]$report,[string]$id,[string]$macro='VIREX_AutoBridge.js') {
    if($macro -cnotin @('VIREX_AutoBridge.js','VIREX_PRRequest.js')){throw 'Unknown bridge macro.'}
    if ($id -cnotmatch '^[0-9a-f]{32}$' -or !$report -or $report.Length -gt 100000) { throw 'Érvénytelen vagy túl hosszú riport (max. 100 000 karakter).' }
    $name='virex-'+$id+'.csv'
    $json=ConvertTo-Json -InputObject $report -Compress
    $csv='"'+$json.Replace('"','""')+'"'+[Environment]::NewLine
    $url=([uri]$cfg.html).AbsoluteUri+'?direct=1&closeRPA=0&closeBrowser=0&storage=xfile&macro='+[uri]::EscapeDataString($macro)+'&cmd_var1='+[uri]::EscapeDataString($name)+'&cmd_var2='+[uri]::EscapeDataString($cfg.url)+'&cmd_var3='+$id
    return @{Path=(Join-Path $cfg.data $name);Ack=(Join-Path $cfg.data ('virex-'+$id+'-ack.csv'));Csv=$csv;Url=$url;Id=$id}
}
$script:bridgeSettingsPath=Join-Path $root 'autobridge.json'
$script:bridgeConfig=$null
$script:bridgePending=$null
$null=New-Caption $labLayout 'AUTOBRIDGE · Ui.Vision' 13 $cyan $true
$bridgeEnabled=Check $labLayout 'Automatikus riportátadás (nem küld üzenetet)' 0 0 400 $false
$null=New-Caption $labLayout 'ChatGPT beszélgetés teljes URL-je' 9 $muted
$bridgeTarget=New-Object Windows.Forms.TextBox
$bridgeTarget.Width=400;$labLayout.Controls.Add($bridgeTarget)
$null=New-Caption $labLayout 'Ui.Vision autorun HTML' 9 $muted
$bridgeHtml=New-Object Windows.Forms.TextBox
$bridgeHtml.Width=400;$labLayout.Controls.Add($bridgeHtml)
$bridgePickHtml=New-Action $labLayout 'HTML tallózása' '#355764' 180
$null=New-Caption $labLayout 'Ui.Vision datasources mappa' 9 $muted
$bridgeData=New-Object Windows.Forms.TextBox
$bridgeData.Width=400;$labLayout.Controls.Add($bridgeData)
$bridgePickData=New-Action $labLayout 'Mappa tallózása' '#355764' 180
$bridgeActions=New-Stack $labLayout 'LeftToRight' $false
$bridgeActions.AutoSize=$true;$bridgeActions.AutoSizeMode='GrowAndShrink'
$bridgeSave=New-Action $bridgeActions 'Mentés' '#245B58' 105
$bridgeTest=New-Action $bridgeActions 'Kapcsolat tesztje' '#355764' 175
$bridgeMacro=New-Action $labLayout 'Makrófájl megnyitása' '#355764' 220
$bridgeStatus=New-Caption $labLayout 'OFF · nincs automatikus átadás.' 9 $muted
$bridgeStatus.MaximumSize=New-Object Drawing.Size(400,0)
if(Test-Path -LiteralPath $script:bridgeSettingsPath -PathType Leaf){
    try{
        $saved=Get-Content -LiteralPath $script:bridgeSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $bridgeTarget.Text=[string]$saved.url;$bridgeHtml.Text=[string]$saved.html;$bridgeData.Text=[string]$saved.data
        $script:bridgeConfig=Get-BridgeConfig $bridgeTarget.Text $bridgeHtml.Text $bridgeData.Text ($saved.enabled -eq $true)
        $bridgeEnabled.Checked=$script:bridgeConfig.enabled
        $bridgeStatus.Text=if($bridgeEnabled.Checked){'ON · mentett beállítás.'}else{'OFF · mentett beállítás.'}
    }catch{$bridgeEnabled.Checked=$false;$bridgeStatus.Text='OFF · ellenőrizd a mentett beállításokat.'}
}
$bridgePickHtml.Add_Click({
    $dlg=New-Object Windows.Forms.OpenFileDialog
    try{$dlg.Filter='HTML (*.html)|*.html';if($dlg.ShowDialog() -eq 'OK'){$bridgeHtml.Text=$dlg.FileName}}finally{$dlg.Dispose()}
})
$bridgePickData.Add_Click({
    $dlg=New-Object Windows.Forms.FolderBrowserDialog
    try{if($dlg.ShowDialog() -eq 'OK'){$bridgeData.Text=$dlg.SelectedPath}}finally{$dlg.Dispose()}
})
$bridgeSave.Add_Click({
    try{
        $cfg=Get-BridgeConfig $bridgeTarget.Text.Trim() $bridgeHtml.Text.Trim() $bridgeData.Text.Trim() $bridgeEnabled.Checked
        $cfg|ConvertTo-Json -Compress|Set-Content -LiteralPath $script:bridgeSettingsPath -Encoding UTF8 -ErrorAction Stop
        $script:bridgeConfig=$cfg
        $bridgeStatus.Text=if($cfg.enabled){'ON · mentve.'}else{'OFF · mentve.'}
    }catch{$bridgeStatus.Text=$_.Exception.Message}
})
$bridgeEnabled.Add_CheckedChanged({
    if(!$bridgeEnabled.Checked -and $script:bridgeConfig){
        $script:bridgeConfig.enabled=$false
        try{$script:bridgeConfig|ConvertTo-Json -Compress|Set-Content -LiteralPath $script:bridgeSettingsPath -Encoding UTF8 -ErrorAction Stop;$bridgeStatus.Text='OFF · kikapcsolva.'}catch{$bridgeStatus.Text='OFF · mentési hiba; ellenőrizd újraindítás után.'}
    }elseif($bridgeEnabled.Checked){$bridgeStatus.Text='Mentés szükséges az aktiváláshoz.'}
})
$bridgeMacro.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'VIREX_AutoBridge.js')+'"')})
function Start-BridgeTransfer($config,[string]$report,[string]$macro='VIREX_AutoBridge.js'){
    if($script:bridgePending){throw 'Már folyamatban van egy átadás.'}
    $cfg=Get-BridgeConfig $config.url $config.html $config.data $config.enabled
    $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $chrome=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","$pf86\Google\Chrome\Application\chrome.exe","$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
    if(!$chrome){throw 'Chrome nem található.'}
    $job=New-BridgePayload $cfg $report ([guid]::NewGuid().ToString('N')) $macro
    [IO.File]::WriteAllText($job.Path,$job.Csv,(New-Object Text.UTF8Encoding($false)))
    try{Start-Process -FilePath $chrome -ArgumentList ('"'+$job.Url+'"') -ErrorAction Stop}
    catch{Remove-Item -LiteralPath $job.Path -Force -ErrorAction SilentlyContinue;throw}
    $script:bridgePending=@{Job=$job;Macro=$macro;Deadline=[DateTime]::UtcNow.AddMinutes(3)}
    $bridgeStatus.Text='Átadás elindítva · visszajelzésre vár.'
}
$bridgeTest.Add_Click({
    if(Test-StorageBusy){return}
    try{$cfg=Get-BridgeConfig $bridgeTarget.Text.Trim() $bridgeHtml.Text.Trim() $bridgeData.Text.Trim() $false;Start-BridgeTransfer $cfg 'VIREX AutoBridge | CONNECTION TEST | SUCCESS'}
    catch{$bridgeStatus.Text=$_.Exception.Message}
})
function Publish-AutoBridgeReport([string]$path,[string]$state){
    if(!$script:bridgeConfig -or !$script:bridgeConfig.enabled -or !$bridgeEnabled.Checked -or $state -notin @('PASS','FAIL','NOT VERIFIED','RUNNER_ERROR')){return}
    try{
        if($bridgeTarget.Text.Trim() -cne $script:bridgeConfig.url -or $bridgeHtml.Text.Trim() -cne $script:bridgeConfig.html -or $bridgeData.Text.Trim() -cne $script:bridgeConfig.data){throw 'A módosított beállításokat előbb mentsd.'}
        Start-BridgeTransfer $script:bridgeConfig ([IO.File]::ReadAllText($path))
    }catch{$bridgeStatus.Text='AutoBridge: '+$_.Exception.Message;Add-Log ('AutoBridge: '+$_.Exception.Message) $muted}
}
$bridgeTimer=New-Object Windows.Forms.Timer
$bridgeTimer.Interval=750
$bridgeTimer.Add_Tick({
    if(!$script:bridgePending){return}
    $pending=$script:bridgePending;$job=$pending.Job
    if(Test-Path -LiteralPath $job.Ack -PathType Leaf){
        try{
            $ack=[IO.File]::ReadAllText($job.Ack).Trim().Trim('"')
            if($ack -in @(('OK:'+$job.Id),('FAIL:'+$job.Id))){
                $bridgeStatus.Text=if($ack -eq ('OK:'+$job.Id)){if($pending.Macro -eq 'VIREX_PRRequest.js'){'PASS · PR kérés elküldve.'}else{'PASS · beillesztve; ellenőrizd és küldd el.'}}else{'FAIL · makró megállt; a riport megmaradt.'}
                Remove-Item -LiteralPath $job.Path,$job.Ack -Force -ErrorAction SilentlyContinue
                $script:bridgePending=$null
            }
        }catch{}
    }
    if($script:bridgePending -and [DateTime]::UtcNow -gt $pending.Deadline){
        Remove-Item -LiteralPath $job.Path,$job.Ack -Force -ErrorAction SilentlyContinue
        $bridgeStatus.Text='TIMEOUT · nincs igazolt beillesztés. Ellenőrizd a Ui.Vision naplót.'
        $script:bridgePending=$null
    }
})
$bridgeTimer.Start()
