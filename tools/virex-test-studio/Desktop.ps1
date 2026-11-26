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
    $control.ItemSize=New-Object Drawing.Size(83,35)
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

function Add-StartPanel($page) {
    $surface=New-Object Windows.Forms.Panel
    $surface.Dock='Fill'
    $surface.AutoScroll=$true
    $surface.BackColor=Color '#142C38'
    $page.Controls.Add($surface)
    $surface.BringToFront()
    $stack=New-Stack $surface 'TopDown' $false
    $stack.AutoSize=$true
    $stack.AutoSizeMode='GrowAndShrink'
    $stack.Padding=New-Object Windows.Forms.Padding(22,18,10,12)
    $script:welcomeName=New-Caption $stack '' 20 $fg $true
    $script:welcomeDetail=New-Caption $stack '' 10 $cyan
    $script:welcomeDetail.MaximumSize=New-Object Drawing.Size(310,0)
    $line=New-Object Windows.Forms.Panel
    $line.Size=New-Object Drawing.Size(225,1)
    $line.BackColor=Color '#38606A'
    $line.Margin=New-Object Windows.Forms.Padding(0,13,0,10)
    $stack.Controls.Add($line)
    $null=New-Caption $stack 'Első futtatás' 13 $fg $true
    $hint=New-Caption $stack 'A bal oldalon válaszd ki az ellenőrzéseket, majd kattints a Futtatás gombra. A parancsok kimenete itt jelenik meg.' 10 $muted
    $hint.MaximumSize=New-Object Drawing.Size(320,0)
    $localLink=New-Action $stack 'Helyi projekt megnyitása…' '#285360' 207
    $localLink.Margin=New-Object Windows.Forms.Padding(0,15,0,4)
    $localLink.Add_Click({ $combo.SelectedIndex=1; $openSource.PerformClick() })
    $helpLink=New-Action $stack 'Útmutató megnyitása  ·  F1' '#223D49' 207
    $helpLink.Add_Click({ Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'README.md')+'"') })
    return $surface
}

$ink = Color '#172B38'
$inkMuted = Color '#425B63'
$form = New-Object Windows.Forms.Form
$form.Text = "VIREX Test Studio  $studioVersion"
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96,96)
$form.ClientSize = New-Object Drawing.Size(1136,730)
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
$header.BackColor = Color '#102B37'
$layout.Controls.Add($header,0,0)
$mark = New-Object Windows.Forms.PictureBox
$mark.Image = [Drawing.Image]::FromFile((Join-Path $appDir 'assets\studio.png'))
$mark.SizeMode = 'Zoom'
$mark.SetBounds(19,17,42,42)
$header.Controls.Add($mark)
$brand = Label $header 'VIREX Test Studio' 74 9 320 36 21 $true
$caption = Label $header "Helyi Rust tesztlabor   /   v$studioVersion" 77 48 340 19 9
$caption.ForeColor = $cyan
$updateButton = New-Action $header '&Frissítés' '#295263' 145 36
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
$sidePanel.BackColor=Color '#EDF3F2'
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
$rule.BackColor=Color '#CAD9D8'
$sidebar.Controls.Add($rule)
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
$runButton=New-Action $actions '&Futtatás' '#087669' 141 38
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
$foot.BackColor=Color '#142C37'
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
$tip.SetToolTip($updateButton,'Stabil Windows-kiadás keresése a VlREX/VIREX repóban')
$tip.SetToolTip($ckClippy,'A Clippy figyelmeztetései is hibának számítanak.')
$tip.SetToolTip($ckRepeat,'A kiválasztott Rust-teszteket ismétli meg. A benchmark egyszer fut.')
$tip.SetToolTip($ckAgility,'Külön Cargo-cache, a kiválasztott repó saját cargo xtask agility parancsa. Hálózati letöltés lehetséges.')
$tip.SetToolTip($ckDepth,'A victory-gpu depth_bounds_pipeline_loads_and_filters_draws tesztet futtatja.')
