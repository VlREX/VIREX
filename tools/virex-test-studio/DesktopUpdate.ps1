$updateTimer = New-Object Windows.Forms.Timer
$updateTimer.Interval = 180
$script:updateWorker = $null
$script:pendingSetup = $null
$script:updateOffer = $null

function Start-UpdateWorker([string]$action) {
    $script:updateAction = $action
    $script:updateWorker = [PowerShell]::Create()
    $operation = {
        param($module, $action, $installed, $offer, $directory)
        $ErrorActionPreference = 'Stop'
        . $module
        if ($action -eq 'check') { Get-StudioUpdate ([version]$installed) }
        else { Receive-StudioUpdate $offer $directory }
    }
    try {
        $null = $updateWorker.AddScript($operation.ToString()).AddArgument((Join-Path $appDir 'StudioUpdate.ps1')).AddArgument($action).AddArgument($studioVersion).AddArgument($updateOffer).AddArgument((Join-Path $root 'updates'))
        $script:updateJob = $updateWorker.BeginInvoke()
        $runButton.Enabled = $false
        $updateButton.Enabled = $false
        $foot.Text = if ($action -eq 'check') {'Stabil kiadás keresése a GitHubon…'} else {'Telepítő letöltése és SHA-256 ellenőrzése…'}
        $updateTimer.Start()
    } catch {
        $updateWorker.Dispose()
        $script:updateWorker = $null
        throw
    }
}

$updateButton.Add_Click({
    if ($script:updateWorker -or $script:runState -eq 'RUNNING' -or $script:unsafeState) { return }
    try { Start-UpdateWorker 'check' } catch { $foot.Text = $_.Exception.GetBaseException().Message }
})
$updateTimer.Add_Tick({
    if (!$script:updateWorker -or !$script:updateJob.IsCompleted) { return }
    $updateTimer.Stop()
    try {
        try { $result = @($updateWorker.EndInvoke($updateJob))[0] }
        finally { $updateWorker.Dispose(); $script:updateWorker = $null }
        if ($updateAction -eq 'check') {
            switch ($result.State) {
                'current' { $foot.Text = "Naprakész vagy. Telepített verzió: $studioVersion." }
                'unpublished' { $foot.Text = 'A Studio stabil kiadási csatornája még nem érhető el a repóban.' }
                'available' {
                    $script:updateOffer = $result
                    $foot.Text = "Elérhető verzió: $($result.Version)."
                    $message = "Telepített verzió: $studioVersion. Új verzió: $($result.Version). Letöltöd a telepítőt a VlREX/VIREX repóból?"
                    if ([Windows.Forms.MessageBox]::Show($form,$message,'Studio frissítése','YesNo','Question') -eq 'Yes') {
                        Start-UpdateWorker 'download'
                    }
                }
                default { throw 'Ismeretlen válasz a kiadási csatornától.' }
            }
        } else {
            $foot.Text = "Ellenőrzött telepítő: $result"
            $message = 'A telepítő letöltése és ellenőrzése sikerült. Bezárod a Studiót és elindítod a telepítőt? Ha van mentetlen AI-véleményed, előbb mentsd el.'
            if ([Windows.Forms.MessageBox]::Show($form,$message,'Frissítés telepítése','YesNo','Question') -eq 'Yes') {
                $script:pendingSetup = $result
                $form.Close()
            }
        }
    } catch {
        $foot.Text = 'Frissítési hiba. ' + $_.Exception.GetBaseException().Message
        $tip.SetToolTip($foot,$foot.Text)
    } finally {
        if (!$script:updateWorker) {
            $runButton.Enabled = !$script:unsafeState
            $updateButton.Enabled = !$script:unsafeState
        }
    }
})

function Start-VerifiedSetup([string]$path, [string]$expectedHash) {
    # Keep a read lock across the final verification and process creation.
    $stream = [IO.File]::Open($path, 'Open', 'Read', 'Read')
    try {
        if ((Get-FileHash -Algorithm SHA256 -InputStream $stream).Hash -ne $expectedHash) {
            throw 'A telepítő időközben módosult. Töltsd le újból.'
        }
        Start-Process -FilePath $path -ErrorAction Stop
    } finally { $stream.Dispose() }
}
