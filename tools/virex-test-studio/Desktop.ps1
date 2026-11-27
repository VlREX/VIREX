# Native controls and keyboard navigation for the main window.
function New-Stack($parent, [string]$direction, [bool]$wrap) {
    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.FlowDirection = $direction
    $flow.WrapContents = $wrap
    $flow.Margin = [Windows.Forms.Padding]::Empty
    $parent.Controls.Add($flow)
    return $flow
}
function New-Caption($parent, [string]$text, [int]$size, $color, [bool]$bold=$false) {
    $label = New-Object Windows.Forms.Label
    $label.AutoSize = $true
    $label.Text = $text
    $label.Font = Font $size 'Segoe UI' $bold
    $label.ForeColor = $color
    $label.Margin = New-Object Windows.Forms.Padding(0,5,0,4)
    $parent.Controls.Add($label)
    return $label
}
function New-Action($parent, [string]$text, [string]$fill, [int]$width, [int]$height=34) {
    $button = Button $parent $text 0 0 $width $height $fill
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.UseVisualStyleBackColor = $false
    $button.Margin = New-Object Windows.Forms.Padding(0,3,6,3)
    return $button
}
function New-Option($parent, [string]$text, [bool]$selected) {
    $option = Check $parent $text 0 0 225 $selected
    $option.ForeColor = $ink
    $option.Margin = [Windows.Forms.Padding]::Empty
    $option.Height = 25
    return $option
}

function Set-StudioTabStyle($control) {
    $control.DrawMode='OwnerDrawFixed'
    $control.SizeMode='Fixed'
    $control.ItemSize=New-Object Drawing.Size(104,36)
    $control.Add_DrawItem({
        param($owner,$event)
        if ($event.Index -lt 0) { return }
        $selected=$owner.SelectedIndex -eq $event.Index
        $back=if ($selected) { $panel } else { $bg }
        $brush=New-Object Drawing.SolidBrush($back)
        try { $event.Graphics.FillRectangle($brush,$event.Bounds) } finally { $brush.Dispose() }
        $textColor=if ($selected) { $cyan } else { $fg }
        [Windows.Forms.TextRenderer]::DrawText($event.Graphics,$owner.TabPages[$event.Index].Text,$owner.Font,$event.Bounds,$textColor,'HorizontalCenter, VerticalCenter, SingleLine')
        if ($selected) {
            $pen=New-Object Drawing.Pen($cyan,3)
            try { $event.Graphics.DrawLine($pen,$event.Bounds.Left+5,$event.Bounds.Bottom-2,$event.Bounds.Right-5,$event.Bounds.Bottom-2) } finally { $pen.Dispose() }
        }
        if ($owner.Focused) { $event.DrawFocusRectangle() }
    })
}

function New-OverviewCard($row, [string]$heading, [int]$column) {
    $card=New-Object Windows.Forms.Panel
    $card.BackColor=Color '#19243B'
    $card.Dock='Fill'
    $card.Margin=New-Object Windows.Forms.Padding(0,0,10,0)
    $row.Controls.Add($card,$column,0)
    $title=Label $card $heading 12 10 120 23 9
    $title.ForeColor=$muted
    $value=Label $card '—' 12 35 110 39 13 $true
    $value.AutoSize=$true
    return $value
}

function Add-StartPanel($page) {
    $surface=New-Object Windows.Forms.TableLayoutPanel
    $surface.Dock='Fill'
    $surface.Padding=New-Object Windows.Forms.Padding(18,14,10,10)
    $surface.BackColor=Color '#10182A'
    $surface.AutoScroll=$true
    $surface.ColumnCount=1
    $surface.RowCount=7
    foreach($height in @(49,72,94,54,48,30)){
        $null=$surface.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',$height)))
    }
    $page.Controls.Add($surface)
    $title=New-Caption $surface 'Futtatási áttekintés' 23 $fg $true
    $surface.SetCellPosition($title,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,0)))
    $target=New-Stack $surface 'TopDown' $false
    $target.Dock='Fill'
    $surface.SetCellPosition($target,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,1)))
    $script:welcomeName=New-Caption $target '' 13 $fg $true
    $script:welcomeDetail=New-Caption $target '' 9 $cyan
    $cards=New-Object Windows.Forms.TableLayoutPanel
    $cards.ColumnCount=3
    $cards.RowCount=1
    $cards.Dock='Fill'
    foreach($width in @(37,27,36)){
        $null=$cards.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',$width)))
    }
    $surface.Controls.Add($cards,0,2)
    $script:overviewStatus=New-OverviewCard $cards 'Futás állapota' 0
    $script:overviewSteps=New-OverviewCard $cards 'Befejezett lépés' 1
    $script:overviewGpu=New-OverviewCard $cards 'D3D12-validáció' 2
    $script:overviewDetail=Label $surface '' 0 0 200 42 10
    $script:overviewDetail.Dock='Fill'
    $script:overviewDetail.AutoEllipsis=$true
    $script:overviewDetail.ForeColor=$muted
    $surface.SetCellPosition($script:overviewDetail,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,3)))
    $actions=New-Stack $surface 'LeftToRight' $true
    $actions.Dock='Fill'
    $surface.SetCellPosition($actions,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,4)))
    $localLink=New-Action $actions 'Helyi projekt…' '#30425F' 131
    $localLink.Add_Click({ $combo.SelectedIndex=1; $openSource.PerformClick() })
    $helpLink=New-Action $actions 'Útmutató · F1' '#263550' 126
    $helpLink.Add_Click({ Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'README.md')+'"') })
    $heading=New-Caption $surface 'Legutóbbi lépések' 12 $fg $true
    $surface.SetCellPosition($heading,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,5)))
    $script:overviewHistory=New-Object Windows.Forms.ListBox
    $overviewHistory.AccessibleName='Legutóbbi futtatási lépések'
    $overviewHistory.Dock='Fill'
    $overviewHistory.MinimumSize=New-Object Drawing.Size(0,90)
    $overviewHistory.BorderStyle='None'
    $overviewHistory.BackColor=Color '#19243B'
    $overviewHistory.ForeColor=$fg
    $overviewHistory.Font=Font 10
    $overviewHistory.HorizontalScrollbar=$true
    $surface.Controls.Add($overviewHistory,0,6)
    $null=$surface.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
}

function Update-StudioOverview {
    $overviewStatus.Text = if ($runState -eq 'IDLE') { 'Készen áll' } else { $status.Text }
    $overviewStatus.ForeColor = $status.ForeColor
    $overviewSteps.Text = if ($runState -eq 'IDLE') { '—' } else { "$($progress.Value) / $($progress.Maximum)" }
    $gpuSteps = @($steps | Where-Object { $_.Kind -eq 'depthtest' -and $_.GpuExecution })
    $overviewGpu.Text = if (!$gpuSteps.Count) { '—' } else { Get-CompletedValidationStatus $gpuSteps }
    if ($overviewGpu.Text -eq 'PASS') { $overviewGpu.Text = 'VERIFIED' }
    $completed = @($steps | Where-Object { $_.Status -ne 'RUNNING' })
    $passed = @($completed | Where-Object { $_.Status -eq 'PASS' -and ($_.Kind -ne 'depthtest' -or $_.GpuExecution -eq 'VERIFIED') }).Count
    $issues = @($completed | Where-Object { $_.Status -in @('FAIL','RUNNER_ERROR') }).Count
    $skipped = @($completed | Where-Object { $_.Status -eq 'SKIPPED' }).Count
    $overviewDetail.Text = if ($active) { "Most fut: $($active.Name)" }
        elseif ($completed.Count) { "$passed sikeres  ·  $issues hibás  ·  $skipped kihagyva" }
        else { 'Válassz tesztcélt és ellenőrzéseket a futtatáshoz.' }
    $overviewHistory.BeginUpdate()
    try {
        $overviewHistory.Items.Clear()
        foreach($entry in ($steps | Select-Object -Last 6)){
            $result = if ($entry.Status -eq 'PASS' -and $entry.Kind -eq 'depthtest') {
                $entry.GpuExecution
            } else { $entry.Status }
            $null=$overviewHistory.Items.Add(('{0}  ·  {1}' -f $result,$entry.Name))
        }
    } finally { $overviewHistory.EndUpdate() }
}

$ink = Color '#E5EDF7'
$inkMuted = Color '#A5B5CA'
$form = New-Object Windows.Forms.Form
$form.Text = if ($script:isPreview) { "VIREX Test Studio  $studioVersion · Előnézet" } else { "VIREX Test Studio  $studioVersion" }
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96,96)
$form.ClientSize = New-Object Drawing.Size(1260,800)
$form.MinimumSize = New-Object Drawing.Size(740,525)
$form.BackColor = $bg
$form.ForeColor = $fg
$form.Font = Font 10
$form.Icon = New-Object Drawing.Icon((Join-Path $appDir 'assets\studio.ico'))
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 1
$layout.RowCount = 3
foreach ($height in @(76,-1,50)) {
    $style = New-Object Windows.Forms.RowStyle
    if ($height -lt 0) { $style.SizeType='Percent'; $style.Height=100 } else { $style.SizeType='Absolute'; $style.Height=$height }
    $null = $layout.RowStyles.Add($style)
}
$form.Controls.Add($layout)
$header = New-Object Windows.Forms.Panel
$header.Margin = [Windows.Forms.Padding]::Empty
$header.Dock = 'Fill'
$header.BackColor = Color '#19233A'
$layout.Controls.Add($header,0,0)
$mark = New-Object Windows.Forms.PictureBox
$mark.Image = [Drawing.Image]::FromFile((Join-Path $appDir 'assets\studio.png'))
$mark.SizeMode = 'Zoom'
$mark.SetBounds(19,17,42,42)
$header.Controls.Add($mark)
$brand = Label $header 'VIREX Test Studio' 74 9 320 36 21 $true
$captionText = if ($script:isPreview) { "Előnézet   /   v$studioVersion" } else { "Helyi Rust tesztlabor   /   v$studioVersion" }
$caption = Label $header $captionText 77 48 340 19 9
$caption.ForeColor = $cyan
$updateLabel = '&Frissítések'
$updateButton = New-Action $header $updateLabel '#295263' 145 36
$updateButton.Dock = 'Right'
$header.Padding = New-Object Windows.Forms.Padding(0,18,20,18)

$body = New-Object Windows.Forms.TableLayoutPanel
$body.Dock='Fill'
$body.Margin=[Windows.Forms.Padding]::Empty
$body.ColumnCount=2
$null=$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute',288)))
$null=$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
$layout.Controls.Add($body,0,1)
$sidePanel = New-Object Windows.Forms.Panel
$sidePanel.Dock='Fill'
$sidePanel.AutoScroll=$true
$sidePanel.BackColor=Color '#151F33'
$sidePanel.Margin=[Windows.Forms.Padding]::Empty
$body.Controls.Add($sidePanel,0,0)
$sidebar = New-Stack $sidePanel 'TopDown' $false
$sidebar.AutoSize=$true
$sidebar.AutoSizeMode='GrowAndShrink'
$sidebar.Padding=New-Object Windows.Forms.Padding(16,10,12,14)
$null=New-Caption $sidebar 'Tesztcél' 15 $ink $true
$combo=New-Object Windows.Forms.ComboBox
$combo.AccessibleName='Tesztcél'
$combo.DropDownStyle='DropDownList'
$combo.Width=244
$combo.DropDownWidth=450
$combo.DisplayMember = 'Label'
function Add-TargetChoice([string]$label, [string]$mode, $preset=$null) {
    $null = $combo.Items.Add([pscustomobject]@{Label=$label; Mode=$mode; Preset=$preset})
}
Add-TargetChoice 'Belobug · VIctory AMD' 'belobug'
Add-TargetChoice 'Saját Cargo-projekt…' 'local'
Add-TargetChoice 'Másik GitHub-repó…' 'github'
foreach ($p in $presets) { Add-TargetChoice $p.Name 'pinned' $p }
Add-TargetChoice 'PR Manager · konkrét revízió' 'revision'
$sidebar.Controls.Add($combo)
$revision=New-Caption $sidebar '' 9 $inkMuted
$revision.AutoSize=$false
$revision.Size=New-Object Drawing.Size(245,44)
$revision.AutoEllipsis=$true
$openSource=New-Action $sidebar 'Forrás megnyitása' '#355764' 194 30
$rule=New-Object Windows.Forms.Panel
$rule.Size=New-Object Drawing.Size(242,1)
$rule.Margin=New-Object Windows.Forms.Padding(0,12,0,8)
$rule.BackColor=Color '#395563'
$sidebar.Controls.Add($rule)
$null=New-Caption $sidebar 'Futtatási mód' 13 $ink $true
$modeSwitch=New-Object Windows.Forms.CheckBox
$modeSwitch.Appearance='Button';$modeSwitch.FlatStyle='Flat';$modeSwitch.FlatAppearance.BorderSize=0
$modeSwitch.UseVisualStyleBackColor=$false;$modeSwitch.TextAlign='MiddleCenter'
$modeSwitch.Font=Font 11 'Segoe UI' $true;$modeSwitch.ForeColor=$fg
$modeSwitch.BackColor=Color '#355764';$modeSwitch.Size=New-Object Drawing.Size(240,40)
$modeSwitch.Text='MANUAL  |  AUTO';$modeSwitch.Cursor=[Windows.Forms.Cursors]::Hand
$sidebar.Controls.Add($modeSwitch)
$null=New-Caption $sidebar 'Ellenőrzések' 14 $ink $true
$ckCheck=New-Option $sidebar 'Fordításellenőrzés' $true
$ckTest=New-Option $sidebar 'Célzott tesztek' $true
$ckClippy=New-Option $sidebar 'Clippy  ·  szigorú mód' $true
$ckBench=New-Option $sidebar 'Benchmark  ·  release' $true
$ckFull=New-Option $sidebar 'Teljes crate-teszt' $false
$ckWarp=New-Option $sidebar 'WARP szoftveres GPU' $false
$ckRepeat=New-Option $sidebar 'Tesztek háromszor' $true
$ckAgility=New-Option $sidebar 'Agility SDK előkészítés' $false
$ckDepth=New-Option $sidebar 'D3D12 depth bounds teszt' $false
$script:windowsBuild=0
try { $script:windowsBuild=[int](Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber) } catch {}
$osHint=if ($windowsBuild -ge 10240 -and $windowsBuild -lt 22000) {'Windows 10: Agility SDK ajánlott, ha a revízió támogatja.'} elseif ($windowsBuild -ge 22000) {'Windows 11: Agility SDK opcionális.'} else {'Windows build nem azonosítható.'}
$runtimeHint=New-Caption $sidebar $osHint 8 $inkMuted
$runtimeHint.MaximumSize=New-Object Drawing.Size(240,0)
$actions=New-Stack $sidebar 'LeftToRight' $false
$actions.AutoSize=$true
$actions.Margin=New-Object Windows.Forms.Padding(0,12,0,0)
$runButton=New-Action $actions '&Futtatás' '#087B71' 141 38
$stopButton=New-Action $actions '&Leállítás' '#653C4B' 95 38
$stopButton.Enabled=$false

$workArea=New-Object Windows.Forms.TableLayoutPanel
$workArea.Dock='Fill'
$workArea.Margin=[Windows.Forms.Padding]::Empty
$workArea.Padding=New-Object Windows.Forms.Padding(12,8,12,8)
$workArea.RowCount=3
$null=$workArea.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',43)))
$null=$workArea.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
$null=$workArea.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',46)))
$body.Controls.Add($workArea,1,0)
$runStatus=New-Object Windows.Forms.Panel
$runStatus.Dock='Fill'
$workArea.Controls.Add($runStatus,0,0)
$status=Label $runStatus 'Indításra kész' 0 2 210 30 15 $true
$status.ForeColor=$cyan
$progressText=Label $runStatus '' 0 0 78 36 9
$progressText.Dock='Right'
$progressText.TextAlign='MiddleCenter'
$progress=New-Object Windows.Forms.ProgressBar
$progress.Dock='Right'
$progress.Width=80
$strip=New-Object Windows.Forms.Panel
$strip.Width=86
$strip.Dock='Right'
$strip.Padding=New-Object Windows.Forms.Padding(0,15,0,12)
$progress.Dock='Fill'
$strip.Controls.Add($progress)
$runStatus.Controls.Add($strip)
$tabs=New-Object Windows.Forms.TabControl
$tabs.AccessibleName='Munkaterület'
$tabs.Dock='Fill'
$tabs.Font=Font 10
$tabs.Padding=New-Object Drawing.Point(9,6)
$tabs.Multiline=$true
$workArea.Controls.Add($tabs,0,1)
$bottom=New-Stack $workArea 'LeftToRight' $false
$bottom.Dock='Fill'
$bottom.AutoScroll=$true
$workArea.SetCellPosition($bottom,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,2)))
$copyButton=New-Action $bottom 'Riport másolása' '#245B58' 133
$copyFullButton=New-Action $bottom 'Napló másolása' '#29414E' 129
$folderButton=New-Action $bottom 'Riportmappa' '#29414E' 105
$copyButton.Enabled=$false
$copyFullButton.Enabled=$false
$foot=New-Object Windows.Forms.Label
$foot.Dock='Fill'
$foot.Margin=[Windows.Forms.Padding]::Empty
$foot.Padding=New-Object Windows.Forms.Padding(18,0,12,0)
$foot.TextAlign='MiddleLeft'
$foot.BackColor=Color '#19233A'
$foot.ForeColor=$fg
$foot.Font=Font 9
$foot.Text='Válassz tesztcélt és ellenőrzéseket, majd indítsd a futtatást.'
$layout.Controls.Add($foot,0,2)
$form.KeyPreview=$true
$form.Add_KeyDown({
    param($sender,$event)
    if ($event.KeyCode -eq 'F1') {
        Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'README.md')+'"')
        $event.Handled=$true
    }
})
$tip=New-Object Windows.Forms.ToolTip
$updateHint = if ($script:isPreview) { 'Előnézeti kiadás keresése a VlREX/VIREX repóban' } else { 'Stabil Windows-kiadás keresése a VlREX/VIREX repóban' }
$tip.SetToolTip($updateButton,$updateHint)
$tip.SetToolTip($ckClippy,'A Clippy figyelmeztetései is hibának számítanak.')
$tip.SetToolTip($ckRepeat,'A kiválasztott Rust-teszteket ismétli meg. A benchmark egyszer fut.')
$tip.SetToolTip($ckAgility,'Külön Cargo-cache, a kiválasztott repó saját cargo xtask agility parancsa. Hálózati letöltés lehetséges.')
$tip.SetToolTip($ckDepth,'A victory-gpu depth_bounds_pipeline_loads_and_filters_draws tesztet futtatja.')
