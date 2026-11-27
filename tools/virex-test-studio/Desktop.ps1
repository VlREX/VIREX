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
    $hint=New-Caption $stack 'AUTO módban a Test Lab vezeti végig a tesztszinteket. MANUAL módban pipákkal vagy GPT-profillal állíthatod be a futtatást.' 10 $muted
    $hint.MaximumSize=New-Object Drawing.Size(320,0)
    $localLink=New-Action $stack 'Helyi projekt megnyitása…' '#285360' 207
    $localLink.Margin=New-Object Windows.Forms.Padding(0,15,0,4)
    $localLink.Add_Click({ $combo.SelectedIndex=1; $openSource.PerformClick() })
    $helpLink=New-Action $stack 'Útmutató megnyitása  ·  F1' '#223D49' 207
    $helpLink.Add_Click({ Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'README.md')+'"') })
    return $surface
}

$ink = Color '#E5EDF7'
$inkMuted = Color '#A5B5CA'
$form = New-Object Windows.Forms.Form
$form.Text = "VIREX Test Studio  $studioVersion"
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96,96)
$form.ClientSize = New-Object Drawing.Size(1440,880)
$form.MinimumSize = New-Object Drawing.Size(800,590)
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
$header.BackColor = Color '#0D1823'
$layout.Controls.Add($header,0,0)
$mark = New-Object Windows.Forms.PictureBox
$mark.Image = [Drawing.Image]::FromFile((Join-Path $appDir 'assets\studio.png'))
$mark.SizeMode = 'Zoom'
$mark.SetBounds(19,17,42,42)
$header.Controls.Add($mark)
$brand = Label $header 'VIREX TEST STUDIO' 74 9 460 36 22 $true
$caption = Label $header "$studioVersion · UI előnézet" 77 48 340 19 9
$caption.ForeColor = $cyan
$updateButton = New-Action $header '&Frissítés' '#16434C' 145 36
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
$sidePanel.BackColor=Color '#14222F'
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
$combo.FlatStyle='Flat';$combo.BackColor=$panel;$combo.ForeColor=$fg
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
$openSource=New-Action $sidebar 'Forrás megnyitása' '#223545' 194 30
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
$modeSwitch.BackColor=Color '#223545';$modeSwitch.Size=New-Object Drawing.Size(240,40)
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
$actions=New-Stack $sidebar 'TopDown' $false
$actions.AutoSize=$true
$actions.Margin=New-Object Windows.Forms.Padding(0,12,0,0)
$runButton=New-Action $actions '&Futtatás' '#00DAC6' 240 48
$runButton.ForeColor=Color '#09222A';$runButton.Font=Font 13 'Segoe UI' $true
$stopButton=New-Action $actions '&Leállítás' '#223545' 240 43
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
$foot.BackColor=Color '#101C28'
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


# Native, double-buffered dashboard. All data comes from the existing runner.
Add-Type -ReferencedAssemblies @('System.dll','System.Drawing.dll','System.Windows.Forms.dll') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public sealed class VirexDashboard : Control {
    readonly Color bg = Color.FromArgb(13,24,35), card = Color.FromArgb(19,34,47), edge = Color.FromArgb(48,68,84);
    readonly Color ink = Color.FromArgb(236,243,249), muted = Color.FromArgb(165,183,199), teal = Color.FromArgb(0,218,198);
    readonly Color green = Color.FromArgb(98,231,152), amber = Color.FromArgb(251,191,76), red = Color.FromArgb(255,121,130), blue = Color.FromArgb(62,164,249);
    readonly Font normal = new Font("Segoe UI",15,GraphicsUnit.Pixel), bold = new Font("Segoe UI Semibold",18,GraphicsUnit.Pixel);
    readonly Font large = new Font("Segoe UI Semibold",29,GraphicsUnit.Pixel), headline = new Font("Segoe UI Semibold",27,GraphicsUnit.Pixel);
    readonly Queue<double>[] history = {new Queue<double>(),new Queue<double>(),new Queue<double>()};
    readonly double[] latest = {-1,-1,-1};
    double free=-1,total=-1,vram=-1;
    string state="IDLE",active="";
    int completed,count;
    string[] names=new string[0],states=new string[0];
    DateTime sampled=DateTime.MinValue;
    float displayed;
    public int Completed { get { return completed; } }
    public int Planned { get { return count; } }
    public string RunState { get { return state; } }
    public string GpuEvidence { get { return "NOT VERIFIED"; } }
    public VirexDashboard() {
        SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);
        AccessibleName="Futtatási áttekintés"; AccessibleRole=AccessibleRole.Pane; BackColor=bg;
    }
    public void SetRun(string s,string a,int done,int planned,string[] n,string[] st) {
        if(state!=s && s=="RUNNING")displayed=0;
        state=s??"IDLE"; active=a??""; completed=Math.Max(0,done); count=Math.Max(0,planned);
        names=n??new string[0]; states=st??new string[0];
        float target=count>0?Math.Min(1f,(float)completed/count):0;
        displayed=state=="RUNNING"?displayed+(target-displayed)*.65f:target;
        AccessibleDescription=state+", "+completed+"/"+count+", "+active+", GPU NOT VERIFIED";Invalidate();
    }
    public void Sample(double cpu,double ram,double load,double video) {
        double[] values={cpu,ram,load};
        for(int i=0;i<3;i++){latest[i]=values[i]>=0&&values[i]<=100?values[i]:-1;history[i].Enqueue(latest[i]);while(history[i].Count>48)history[i].Dequeue();}
        vram=video>=0?video:-1;sampled=DateTime.Now;Invalidate();
    }
    public void SetStorage(double f,double t){free=f;total=t;Invalidate();}
    GraphicsPath Rounded(RectangleF r,float radius) {
        float d=Math.Min(radius*2,Math.Min(r.Width,r.Height));var p=new GraphicsPath();
        if(d<=0){p.AddRectangle(r);return p;}
        p.AddArc(r.X,r.Y,d,d,180,90);p.AddArc(r.Right-d,r.Y,d,d,270,90);p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.X,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;
    }
    void Fill(Graphics g,RectangleF r,Color c,float radius){if(r.Width<=0||r.Height<=0)return;using(var p=Rounded(r,radius))using(var b=new SolidBrush(c))g.FillPath(b,p);}
    void Card(Graphics g,RectangleF r,Color c,Color stroke){using(var p=Rounded(r,9))using(var b=new SolidBrush(c))using(var pen=new Pen(stroke,1)){g.FillPath(b,p);g.DrawPath(pen,p);}}
    void Txt(Graphics g,string value,Font font,Color c,RectangleF r){
        using(var b=new SolidBrush(c))using(var fmt=new StringFormat{Trimming=StringTrimming.EllipsisCharacter,FormatFlags=StringFormatFlags.NoWrap,LineAlignment=StringAlignment.Center})g.DrawString(value??"",font,b,r,fmt);
    }
    Color StateColor(string s){return s=="PASS"?green:s=="RUNNING"?teal:s=="FAIL"||s=="RUNNER_ERROR"?red:s=="IDLE"?muted:amber;}
    void Icon(Graphics g,float x,float y,string s,Color c){
        using(var p=new Pen(c,2.5f))using(var b=new SolidBrush(c)){
            if(s=="PASS"){g.FillEllipse(b,x,y,22,22);using(var q=new Pen(bg,2.6f))g.DrawLines(q,new[]{new PointF(x+5,y+11),new PointF(x+9,y+15),new PointF(x+17,y+7)});}
            else if(s=="RUNNING")g.DrawPolygon(p,new[]{new PointF(x+4,y+2),new PointF(x+20,y+11),new PointF(x+4,y+20)});
            else if(s=="FAIL"||s=="RUNNER_ERROR"){g.DrawEllipse(p,x,y,22,22);g.DrawLine(p,x+6,y+6,x+16,y+16);g.DrawLine(p,x+16,y+6,x+6,y+16);}
            else{g.DrawEllipse(p,x+2,y+2,18,18);g.DrawLine(p,x+11,y+6,x+11,y+12);g.FillEllipse(b,x+10,y+15,2,2);}
        }
    }
    void Spark(Graphics g,RectangleF r,int i,Color c,string label) {
        Card(g,r,card,edge);bool stale=sampled==DateTime.MinValue||(DateTime.Now-sampled).TotalSeconds>15;
        string value=stale||latest[i]<0?"N/A":latest[i].ToString("0")+"%";
        Txt(g,label,bold,ink,new RectangleF(r.X+14,r.Y+5,r.Width-85,26));
        Txt(g,value,bold,c,new RectangleF(r.Right-66,r.Y+5,60,26));
        var plot=new RectangleF(r.X+14,r.Y+36,r.Width-28,r.Height-46);
        if(plot.Height<5)return;
        double[] data=history[i].ToArray();
        using(var pen=new Pen(edge,1))g.DrawLine(pen,plot.Left,plot.Bottom,plot.Right,plot.Bottom);
        if(stale||data.Length<2){Txt(g,stale?"Nincs friss minta":"Mérés folyamatban",normal,muted,plot);return;}
        var segment=new List<PointF>();
        for(int j=0;j<=data.Length;j++){
            if(j<data.Length&&data[j]>=0){segment.Add(new PointF(plot.Left+plot.Width*j/Math.Max(1,data.Length-1),plot.Bottom-plot.Height*(float)data[j]/100));continue;}
            if(segment.Count>=2)using(var area=new GraphicsPath())using(var fill=new LinearGradientBrush(plot,Color.FromArgb(100,c),Color.FromArgb(7,c),90f))using(var pen=new Pen(c,2.1f)){
                area.AddLines(segment.ToArray());area.AddLine(segment[segment.Count-1],new PointF(segment[segment.Count-1].X,plot.Bottom));area.AddLine(new PointF(segment[segment.Count-1].X,plot.Bottom),new PointF(segment[0].X,plot.Bottom));area.CloseFigure();g.FillPath(fill,area);g.DrawLines(pen,segment.ToArray());
            }else if(segment.Count==1)using(var b=new SolidBrush(c))g.FillEllipse(b,segment[0].X-2,segment[0].Y-2,4,4);
            segment.Clear();
        }
    }
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);var g=e.Graphics;g.Clear(bg);g.SmoothingMode=SmoothingMode.AntiAlias;g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        if(ClientSize.Width<10||ClientSize.Height<10)return;
        float scale=Math.Min(ClientSize.Width/850f,ClientSize.Height/570f);g.ScaleTransform(scale,scale);
        float w=ClientSize.Width/scale,h=ClientSize.Height/scale,p=18,gap=13,cw=(w-2*p-2*gap)/3;
        Txt(g,"Futtatási áttekintés",headline,ink,new RectangleF(p,8,w-2*p,39));
        var a=new RectangleF(p,60,cw,94);var b=new RectangleF(p+cw+gap,60,cw,94);var c=new RectangleF(p+2*(cw+gap),60,cw,94);
        Color sc=StateColor(state);
        Card(g,a,Color.FromArgb(17,49,54),Color.FromArgb(27,105,109));Card(g,b,card,edge);Card(g,c,Color.FromArgb(45,38,29),Color.FromArgb(100,78,40));
        Icon(g,a.X+15,a.Y+18,state,sc);Txt(g,"Állapot",normal,muted,new RectangleF(a.X+48,a.Y+9,a.Width-60,25));
        Txt(g,state=="RUNNING"?"Fut":state=="IDLE"?"Készen áll":state,large,sc,new RectangleF(a.X+15,a.Y+39,a.Width-25,45));
        Txt(g,"Lépések",normal,muted,new RectangleF(b.X+16,b.Y+9,b.Width-28,25));Txt(g,completed+" / "+count,large,ink,new RectangleF(b.X+16,b.Y+39,b.Width-28,45));
        Txt(g,"GPU-validáció",normal,amber,new RectangleF(c.X+16,c.Y+9,c.Width-28,25));Txt(g,GpuEvidence,bold,amber,new RectangleF(c.X+16,c.Y+39,c.Width-28,45));
        Txt(g,"Aktív lépés:  "+(String.IsNullOrEmpty(active)?"—":active),bold,ink,new RectangleF(p,168,w-2*p,27));
        var track=new RectangleF(p,203,w-2*p,15);Fill(g,track,edge,7);
        if(displayed>0){var bar=new RectangleF(track.X,track.Y,track.Width*displayed,track.Height);using(var path=Rounded(bar,7))using(var brush=new LinearGradientBrush(bar,teal,Color.FromArgb(114,250,229),0f))g.FillPath(brush,path);}
        float left=(w-2*p-gap)*.57f,right=w-2*p-gap-left,y=240,bottom=h-20,rx=p+left+gap;
        var list=new RectangleF(p,y,left,bottom-y);Card(g,list,card,edge);
        Txt(g,"Legutóbbi lépések ("+names.Length+")",bold,ink,new RectangleF(p+15,y+10,left-30,30));
        float rowH=Math.Min(54,(list.Height-57)/5);
        if(names.Length==0)Txt(g,"Válassz tesztcélt, majd indítsd a futtatást.",normal,muted,new RectangleF(p+15,y+65,left-30,36));
        for(int i=0;i<names.Length&&i<states.Length;i++){
            float yy=y+48+i*rowH;Color col=StateColor(states[i]);
            if(states[i]=="RUNNING")Fill(g,new RectangleF(p+8,yy,left-16,rowH-3),Color.FromArgb(13,66,69),7);
            else using(var pen=new Pen(edge,1))g.DrawLine(pen,p+14,yy,p+left-14,yy);
            Icon(g,p+17,yy+(rowH-22)/2,states[i],col);
            Txt(g,names[i],normal,ink,new RectangleF(p+50,yy,left-174,rowH-3));Txt(g,states[i],normal,col,new RectangleF(p+left-116,yy,110,rowH-3));
        }
        float sh=(bottom-y-3*gap)/4;
        Spark(g,new RectangleF(rx,y,right,sh),0,teal,"CPU");
        Spark(g,new RectangleF(rx,y+sh+gap,right,sh),1,blue,"RAM");
        bool fresh=sampled!=DateTime.MinValue&&(DateTime.Now-sampled).TotalSeconds<=15;
        Spark(g,new RectangleF(rx,y+2*(sh+gap),right,sh),2,green,"GPU · "+(fresh&&vram>=0?vram.ToString("0.00")+" GiB":"VRAM N/A"));
        var disk=new RectangleF(rx,y+3*(sh+gap),right,sh);Card(g,disk,card,edge);
        Txt(g,"Tárhely · cache meghajtó",bold,ink,new RectangleF(rx+14,disk.Y+4,right-28,25));
        Txt(g,free>=0?free.ToString("0.0")+" GiB szabad":"N/A",normal,muted,new RectangleF(rx+14,disk.Y+29,right-28,20));
        var dt=new RectangleF(rx+14,disk.Bottom-13,right-28,6);Fill(g,dt,edge,3);
        if(total>0&&free>=0)Fill(g,new RectangleF(dt.X,dt.Y,dt.Width*(float)Math.Max(0,Math.Min(1,free/total)),dt.Height),teal,3);
    }
    protected override void Dispose(bool disposing){if(disposing){normal.Dispose();bold.Dispose();large.Dispose();headline.Dispose();}base.Dispose(disposing);}
}
'@
