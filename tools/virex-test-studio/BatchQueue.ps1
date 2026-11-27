# Sequential batch prototype; only existing validated pinned profiles.
$script:batchActive=$false
$script:batchItems=@()
$script:batchIndex=0
$script:batchReport=$null
$script:batchWaiting=$false
$script:batchCurrent=$false
$script:batchStop=$false
function ConvertFrom-StudioBatch([string]$json){
    if([string]::IsNullOrWhiteSpace($json) -or $json.Length -gt 60000 -or !$json.TrimStart().StartsWith('[')){throw 'JSON array required (1-12 profiles).'}
    $items=@(ConvertFrom-Json -InputObject $json -ErrorAction Stop)
    if($items.Count -lt 1 -or $items.Count -gt 12){throw '1-12 profiles required.'}
    $validated=@()
    $origin=$null
    foreach($item in $items){
        $source=ConvertTo-Json -InputObject $item -Depth 5 -Compress
        $parsed=ConvertFrom-StudioProfile $source
        if($parsed.Options.v -ne 3 -or !$parsed.Target.ExpectedSha){throw 'Each batch profile requires v3 and an exact commit.'}
        if($origin -and $origin -cne $parsed.Target.Origin){throw 'A batch must target one repository.'}
        $origin=$parsed.Target.Origin
        $validated+=@{Json=$source;Target=$parsed.Target;Options=$parsed.Options}
    }
    return $validated
}
$null=New-Caption $labLayout 'DEVELOPMENT ORCHESTRATOR · BATCH QUEUE' 13 $cyan $true
$null=New-Caption $labLayout 'JSON v3 profiles in one array. Stop on first non-PASS.' 9 $muted
$batchBox=New-Object Windows.Forms.TextBox
$batchBox.Multiline=$true;$batchBox.ScrollBars='Vertical';$batchBox.Width=400;$batchBox.Height=130;$batchBox.MaxLength=60000
$batchBox.Font=Font 9 'Consolas';$labLayout.Controls.Add($batchBox)
$batchActions=New-Stack $labLayout 'LeftToRight' $false
$batchActions.AutoSize=$true;$batchActions.AutoSizeMode='GrowAndShrink'
$batchStart=New-Action $batchActions 'Teszt indítása · START' '#245B58' 185
$batchCancel=New-Action $batchActions 'STOP' '#493A46' 85
$batchCancel.Enabled=$false
$batchFolder=New-Action $labLayout 'Összesített riport mappája' '#355764' 245
$batchFolder.Enabled=$false
$batchStatus=New-Caption $labLayout 'IDLE' 10 $cyan
$batchStatus.MaximumSize=New-Object Drawing.Size(400,0)
function Add-BatchReport([string]$text){
    [IO.File]::AppendAllText($script:batchReport,$text+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
}
function Finish-StudioBatch([string]$state){
    if(!$script:batchActive){return}
    try{
        for($i=$script:batchIndex;$i -lt $script:batchItems.Count;$i++){
            Add-BatchReport ('['+($i+1)+'] NOT RUN | '+$script:batchItems[$i].Target.SourceUrl)
        }
        Add-BatchReport ('BATCH STATUS: '+$state)
        $batchStatus.Text=$state+' | '+$script:batchReport
    }catch{$batchStatus.Text='REPORT ERROR: '+$_.Exception.Message}
    finally{
        $script:batchActive=$false;$script:batchWaiting=$false;$script:batchCurrent=$false
        $batchStart.Enabled=$true;$batchCancel.Enabled=$false;$batchBox.Enabled=$true
        $batchFolder.Enabled=[bool]$script:batchReport
    }
}
function Complete-BatchRun([string]$state,[bool]$saved){
    if(!$script:batchActive -or !$script:batchCurrent){return}
    $script:batchCurrent=$false
    try{
        Add-BatchReport ('===== PROFILE '+($script:batchIndex+1)+' | '+$state+' =====')
        Add-BatchReport $script:batchItems[$script:batchIndex].Json
        if(!$saved){throw 'Individual report could not be saved.'}
        Add-BatchReport ([IO.File]::ReadAllText((Join-Path $runDir 'REPORT.txt')))
        $script:batchIndex++
        if($state -ne 'PASS' -or $script:batchStop -or $script:closeAfterStop){
            Finish-StudioBatch $(if($state -ne 'PASS'){$state}else{'CANCELLED'})
        }elseif($script:batchIndex -ge $script:batchItems.Count){
            Finish-StudioBatch 'PASS'
        }else{$script:batchWaiting=$true}
    }catch{Finish-StudioBatch 'REPORT_ERROR'}
}
$batchStart.Add_Click({
    if($script:batchActive -or (Test-StorageBusy)){return}
    try{
        $items=@(ConvertFrom-StudioBatch $batchBox.Text)
        $summary=($items|ForEach-Object {$_.Json}) -join ([Environment]::NewLine+[Environment]::NewLine)
        if(!(Confirm-StudioRun ('Approve all pinned profiles below? Cargo and repository code run with your Windows account permissions. The batch stops at the first non-PASS.'+[Environment]::NewLine+$summary))){return}
        $directory=Join-Path $reports ('batch-'+[guid]::NewGuid().ToString('N'))
        $null=[IO.Directory]::CreateDirectory($directory)
        $script:batchReport=Join-Path $directory 'BATCH-REPORT.txt'
        [IO.File]::WriteAllText($script:batchReport,('VIREX BATCH VALIDATION | '+[DateTime]::Now.ToString('o')+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
        $script:batchItems=$items;$script:batchIndex=0;$script:batchStop=$false;$script:batchCurrent=$false
        $script:batchActive=$true;$script:batchWaiting=$true
        $batchStart.Enabled=$false;$batchCancel.Enabled=$true;$batchBox.Enabled=$false;$batchFolder.Enabled=$true
        $batchStatus.Text='QUEUED | '+$items.Count+' profiles'
    }catch{$batchStatus.Text=$_.Exception.Message}
})
$batchCancel.Add_Click({
    if(!$script:batchActive){return}
    $script:batchStop=$true
    if($script:batchCurrent -and $script:runState -eq 'RUNNING'){Stop-Run}
    else{Finish-StudioBatch 'CANCELLED'}
})
$batchFolder.Add_Click({
    if($script:batchReport){Start-Process explorer.exe -ArgumentList ('"'+(Split-Path -Parent $script:batchReport)+'"')}
})
$batchTimer=New-Object Windows.Forms.Timer
$batchTimer.Interval=500
$batchTimer.Add_Tick({
    if(!$script:batchActive -or !$script:batchWaiting -or (Test-StorageBusy)){return}
    $script:batchWaiting=$false
    if($script:batchStop){Finish-StudioBatch 'CANCELLED';return}
    try{
        $modeSwitch.Checked=$false
        Clear-StudioProfile 'Batch profile selected.'
        Apply-StudioProfile $script:batchItems[$script:batchIndex].Json
        $batchStatus.Text='RUNNING '+($script:batchIndex+1)+' / '+$script:batchItems.Count
        $script:batchCurrent=$true
        Start-StudioRun -BatchApproved
        if($script:batchActive -and $script:batchCurrent -and $script:runState -ne 'RUNNING'){
            $script:batchCurrent=$false;Finish-StudioBatch 'START_ERROR'
        }
    }catch{$script:batchCurrent=$false;Finish-StudioBatch 'START_ERROR'}
})
$batchTimer.Start()
