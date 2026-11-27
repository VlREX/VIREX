# Bounded opt-in prototype. No arbitrary commands, no automatic merge.
$script:autoSession=$null
$script:autoJob=$null
$script:autoFetch=$null
$null=New-Caption $labLayout 'AUTONOMOUS · CHAT START' 13 $cyan $true
$autoRepo=New-Object Windows.Forms.TextBox
$autoRepo.Width=400;$autoRepo.Text='VlREX/VIctory-Belobug-AMD';$labLayout.Controls.Add($autoRepo)
$autoArm=New-Action $labLayout 'Munkamenet élesítése (2 óra)' '#245B58' 280
$autoStop=New-Action $labLayout 'Autonomous STOP' '#493A46' 220
$autoStop.Enabled=$false
$autoStatus=New-Caption $labLayout 'OFF · egyszeri helyi engedély szükséges.' 9 $muted
$autoStatus.MaximumSize=New-Object Drawing.Size(400,0)
function ConvertFrom-AutonomousPlan([string]$json,$session){
    if(!$session -or !$json -or $json.Length -gt 60000){throw 'Invalid session or plan size.'}
    $plan=ConvertFrom-Json -InputObject $json -ErrorAction Stop
    $keys=@($plan.PSObject.Properties.Name)
    if($keys.Count -ne 4 -or @($keys|Where-Object{$_ -cnotin @('virex_batch','session','round','profiles')}).Count){throw 'Invalid autonomous envelope.'}
    if($plan.virex_batch -isnot [int] -or $plan.virex_batch -ne 1 -or $plan.session -cne $session.Id -or $plan.round -isnot [int] -or $plan.round -ne $session.Round -or $plan.round -notin (1..4)){throw 'Wrong session or round.'}
    if($plan.profiles -isnot [array]){throw 'Profiles must be an array.'}
    $items=@(ConvertFrom-StudioBatch (ConvertTo-Json -InputObject @($plan.profiles) -Depth 8 -Compress))
    foreach($item in $items){
        if($item.Target.Origin -ine $session.Origin){throw 'Repository outside approved scope.'}
        if($item.Target.ExpectedSha -cne $items[0].Target.ExpectedSha){throw 'One exact commit per round required.'}
    }
    if($session.LastSha -and $items[0].Target.ExpectedSha -ceq $session.LastSha){throw 'Repeated commit rejected.'}
    return $items
}
function Get-AutonomousMailboxUrl($session){
    if($session.Id -cnotmatch '^[0-9a-f]{32}$' -or $session.Round -notin (1..4)){throw 'Invalid mailbox session.'}
    return ('https://raw.githubusercontent.com/VlREX/VIREX/studio-handoff/handoff/'+$session.Id+'/r'+$session.Round+'.json')
}
function Stop-AutonomousFetch {
    if($script:autoFetch){
        $fetch=$script:autoFetch;$script:autoFetch=$null
        $fetch.Client.Dispose()
    }
}
function Start-AutonomousFetch($session){
    Add-Type -AssemblyName System.Net.Http
    $handler=New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect=$false
    $client=New-Object System.Net.Http.HttpClient -ArgumentList $handler
    try{
        $client.Timeout=[TimeSpan]::FromSeconds(15)
        $client.MaxResponseContentBufferSize=65536
        $url=(Get-AutonomousMailboxUrl $session)+'?poll='+[DateTime]::UtcNow.Ticks
        $client.DefaultRequestHeaders.CacheControl=New-Object System.Net.Http.Headers.CacheControlHeaderValue
        $client.DefaultRequestHeaders.CacheControl.NoCache=$true
        $task=$client.GetAsync($url)
        $script:autoFetch=@{Client=$client;Task=$task;Session=$session.Id;Round=$session.Round}
    }catch{$client.Dispose();throw}
}
function Stop-AutonomousSession([string]$reason){
    Stop-AutonomousFetch
    $script:autoSession=$null
    $script:autoJob=$null
    $autoArm.Enabled=$true;$autoRepo.Enabled=$true;$autoStop.Enabled=$false
    $autoStatus.Text=$reason
}
function Start-AutonomousJob([string]$kind,[string]$reportPath=''){
    $s=$script:autoSession
    if(!$s -or $script:autoJob -or $kind -cne 'REPORT'){throw 'No available autonomous report session.'}
    $id=[guid]::NewGuid().ToString('N')
    $name='virex-auto-'+$id+'.csv'
    $payload=@{kind=$kind;session=$s.Id;round=$s.Round;origin=$s.Origin}
    if($kind -eq 'REPORT'){
        $bytes=[IO.File]::ReadAllBytes($reportPath)
        if($bytes.Length -gt 1000000){throw 'Report too large for prototype; local TXT retained.'}
        $payload.file='VIREX_'+$s.Id+'_R'+$s.Round+'.txt'
        $payload.base64=[Convert]::ToBase64String($bytes)
    }
    $json=ConvertTo-Json -InputObject $payload -Depth 4 -Compress
    $csv='"'+$json.Replace('"','""')+'"'+[Environment]::NewLine
    $path=Join-Path $s.Config.data $name
    $ack=Join-Path $s.Config.data ('virex-auto-'+$id+'-ack.csv')
    $url=([uri]$s.Config.html).AbsoluteUri+'?direct=1&closeRPA=0&closeBrowser=0&storage=xfile&macro=VIREX_Autonomous.js&cmd_var1='+[uri]::EscapeDataString($name)+'&cmd_var2='+[uri]::EscapeDataString($s.Config.url)+'&cmd_var3='+$id
    [IO.File]::WriteAllText($path,$csv,(New-Object Text.UTF8Encoding($false)))
    try{Start-Process -FilePath $s.Chrome -ArgumentList ('"'+$url+'"') -ErrorAction Stop}
    catch{Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue;throw}
    $script:autoJob=@{Id=$id;Kind=$kind;Path=$path;Ack=$ack;Deadline=[DateTime]::UtcNow.AddMinutes(2)}
}
function Complete-AutonomousBatch([string]$state){
    if(!$script:autoSession){return}
    if($state -in @('CANCELLED','REPORT_ERROR') -or $script:closeAfterStop){Stop-AutonomousSession ('STOP · '+$state);return}
    try{
        $script:autoSession.State=$state
        $script:autoSession.Phase='REPORT'
        Start-AutonomousJob 'REPORT' $script:batchReport
        $autoStatus.Text='TXT · átadás folyamatban.'
    }catch{Stop-AutonomousSession ('REPORT ERROR · '+$_.Exception.Message)}
}
$autoArm.Add_Click({
    if($script:autoSession -or $script:batchActive -or $script:bridgePending -or $script:importPending -or (Test-StorageBusy)){return}
    try{
        if(!$script:bridgeConfig){throw 'Mentsd az AutoBridge konfigurációját.'}
        $cfg=Get-BridgeConfig $bridgeTarget.Text.Trim() $bridgeHtml.Text.Trim() $bridgeData.Text.Trim() $false
        if($cfg.url -cne $script:bridgeConfig.url -or $cfg.html -cne $script:bridgeConfig.html -or $cfg.data -cne $script:bridgeConfig.data){throw 'Mentsd a módosított beállításokat.'}
        $repo=$autoRepo.Text.Trim()
        if($repo -inotmatch '^(VlREX|Csomaika)/[A-Za-z0-9_.-]{1,100}$'){throw 'Csak a saját VIREX/Csomaika repók engedélyezettek.'}
        $target=ConvertTo-RepositoryTarget $repo
        $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        $chrome=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","$pf86\Google\Chrome\Application\chrome.exe","$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
        if(!$chrome){throw 'Chrome nem található.'}
        if(!(Confirm-StudioRun ('2 órára engedélyezed a megadott saját repo commitjainak automatikus Cargo-futtatását (max. 4 kör, körönként 12 profil) a VlREX/VIREX studio-handoff ágában tárolt teszttervek alapján, és a riportok elküldését a mentett chatbe? A teszttervek nyilvánosak; a riportok nem kerülnek GitHubra. A repo kódja a Windows-fiókod teljes jogosultságával fut; ez NEM sandbox. Csak megbízható saját kódhoz. STOP megszakítja a munkamenetet.'+[Environment]::NewLine+$target.Origin+[Environment]::NewLine+$cfg.url))){return}
        $macroDir=Join-Path (Split-Path -Parent ($cfg.data.TrimEnd('\'))) 'macros'
        if(!(Test-Path -LiteralPath $macroDir -PathType Container)){throw 'Ui.Vision macros mappa nem található.'}
        $source=Join-Path $appDir 'VIREX_Autonomous.js'
        $dest=Join-Path $macroDir 'VIREX_Autonomous.js'
        if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw 'A csomagból hiányzik a riport makró.'}
        if([IO.Path]::GetFullPath($source) -ine [IO.Path]::GetFullPath($dest)){
            if(Test-Path -LiteralPath $dest -PathType Leaf){
                Copy-Item -LiteralPath $dest -Destination ($dest+'.bak') -Force -ErrorAction Stop
            }
            Copy-Item -LiteralPath $source -Destination $dest -Force -ErrorAction Stop
        }
        $id=[guid]::NewGuid().ToString('N')
        $script:autoSession=@{Id=$id;Round=1;Origin=$target.Origin;Config=$cfg;Chrome=$chrome;Deadline=[DateTime]::UtcNow.AddHours(2);Next=[DateTime]::UtcNow;Phase='WAIT';LastSha='';State=''}
        $autoArm.Enabled=$false;$autoRepo.Enabled=$false;$autoStop.Enabled=$true
        $autoStatus.Text='ARMED · GitHub mailbox · SESSION '+$id+' · másold ezt a session azonosítót a chatbe egyszer.'
        [Windows.Forms.Clipboard]::SetText('VIREX SESSION '+$id+' REPO '+$repo)
    }catch{Stop-AutonomousSession $_.Exception.Message}
})
$autoStop.Add_Click({
    Stop-AutonomousSession 'STOP · munkamenet lezárva.'
    if($script:batchActive){$script:batchStop=$true;if($script:runState -eq 'RUNNING'){Stop-Run}else{Finish-StudioBatch 'CANCELLED'}}
})
$autonomousTimer=New-Object Windows.Forms.Timer
$autonomousTimer.Interval=1000
$autonomousTimer.Add_Tick({
    $s=$script:autoSession
    if(!$s){return}
    if([DateTime]::UtcNow -gt $s.Deadline){
        Stop-AutonomousSession 'EXPIRED · munkamenet lezárva.'
        if($script:batchActive){$script:batchStop=$true;if($script:runState -eq 'RUNNING'){Stop-Run}else{Finish-StudioBatch 'CANCELLED'}}
        return
    }
    try{
        if($script:autoJob){
            $job=$script:autoJob
            if(!(Test-Path -LiteralPath $job.Ack -PathType Leaf)){
                if([DateTime]::UtcNow -gt $job.Deadline){throw 'Makró timeout; nincs automatikus újraküldés.'}
                return
            }
            $row=@(Import-Csv -LiteralPath $job.Ack -Header 'id','result','payload' -Encoding UTF8)
            if($row.Count -ne 1 -or $row[0].id -cne $job.Id){throw 'Invalid acknowledgement.'}
            Remove-Item -LiteralPath $job.Path,$job.Ack -Force -ErrorAction SilentlyContinue
            $script:autoJob=$null
            if($job.Kind -eq 'REPORT'){
                if($row[0].result -cne 'SENT'){throw ('TXT nem igazolt: '+$row[0].payload)}
                if($s.State -eq 'PASS' -or $s.Round -ge 4){Stop-AutonomousSession ('DONE · '+$s.State+' · TXT elküldve.');return}
                $s.Round++;$s.Phase='WAIT';$s.Next=[DateTime]::UtcNow.AddSeconds(30)
                $autoStatus.Text='WAIT · hotfix kör '+$s.Round
            }else{throw 'Unexpected legacy poll acknowledgement.'}
        }elseif($script:autoFetch){
            $fetch=$script:autoFetch
            if(!$fetch.Task.IsCompleted){return}
            $response=$null;$json=$null;$retry=$false
            try{
                if($fetch.Session -cne $s.Id -or $fetch.Round -ne $s.Round){throw 'Stale mailbox fetch.'}
                $response=$fetch.Task.GetAwaiter().GetResult()
                $status=[int]$response.StatusCode
                if($status -eq 404){$retry=$true;$autoStatus.Text='WAIT · GitHub tesztterv, kör '+$s.Round}
                elseif($status -eq 429 -or $status -ge 500){$retry=$true;$autoStatus.Text='WAIT · GitHub HTTP '+$status}
                elseif($status -ne 200){throw ('Mailbox HTTP '+$status)}
                else{$json=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()}
            }finally{
                if($response){$response.Dispose()}
                Stop-AutonomousFetch
            }
            if($retry){$s.Next=[DateTime]::UtcNow.AddSeconds(15);return}
            $items=@(ConvertFrom-AutonomousPlan $json $s)
            if(Test-StorageBusy -or $script:batchActive -or $script:bridgePending -or $script:importPending){
                $s.Next=[DateTime]::UtcNow.AddSeconds(15);$autoStatus.Text='WAIT · runner busy';return
            }
            $s.LastSha=$items[0].Target.ExpectedSha
            $s.Phase='RUNNING'
            Start-ApprovedBatch $items
            $autoStatus.Text='RUNNING · GitHub mailbox · kör '+$s.Round+' / 4'
        }elseif($s.Phase -eq 'WAIT' -and [DateTime]::UtcNow -ge $s.Next -and !(Test-StorageBusy) -and !$script:bridgePending -and !$script:importPending){
            Start-AutonomousFetch $s
            $autoStatus.Text='WAIT · GitHub tesztterv, kör '+$s.Round
        }
    }catch{Stop-AutonomousSession ('STOP · '+$_.Exception.Message)}
})
$autonomousTimer.Start()
