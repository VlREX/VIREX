# Native, double-buffered drawing; no new runtime dependencies.
Add-Type -ReferencedAssemblies @('System.dll','System.Drawing.dll','System.Windows.Forms.dll') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public static class VirexVisual {
    public static readonly Color Bg=Color.FromArgb(10,24,34), Surface=Color.FromArgb(15,33,45), Border=Color.FromArgb(45,73,88);
    public static readonly Color Ink=Color.FromArgb(236,244,248), Muted=Color.FromArgb(165,188,203), Teal=Color.FromArgb(0,222,206);
    public static readonly Color Green=Color.FromArgb(105,232,140), Amber=Color.FromArgb(250,193,88), Red=Color.FromArgb(255,119,131);
    public static GraphicsPath Path(RectangleF r,float radius) {
        var p=new GraphicsPath();float d=Math.Min(radius*2,Math.Min(r.Width,r.Height));
        if(d<=0){p.AddRectangle(r);return p;}
        p.AddArc(r.X,r.Y,d,d,180,90);p.AddArc(r.Right-d,r.Y,d,d,270,90);
        p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.X,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;
    }
    public static void Fill(Graphics g,RectangleF r,Color c,float radius) {
        if(r.Width<=0||r.Height<=0)return;using(var p=Path(r,radius))using(var b=new SolidBrush(c))g.FillPath(b,p);
    }
    public static void Card(Graphics g,RectangleF r,Color c,Color edge,float radius) {
        if(r.Width<=0||r.Height<=0)return;using(var p=Path(r,radius))using(var b=new SolidBrush(c))using(var pen=new Pen(edge,1)){g.FillPath(b,p);g.DrawPath(pen,p);}
    }
    public static Color Blend(Color a,Color b,float t){return Color.FromArgb((int)(a.R+(b.R-a.R)*t),(int)(a.G+(b.G-a.G)*t),(int)(a.B+(b.B-a.B)*t));}
    public static void Text(Graphics g,string s,Font f,Color c,RectangleF r,bool right=false) {
        if(r.Width<=0||r.Height<=0)return;
        using(var b=new SolidBrush(c))using(var fmt=new StringFormat{Trimming=StringTrimming.EllipsisCharacter,FormatFlags=StringFormatFlags.NoWrap,LineAlignment=StringAlignment.Center,Alignment=right?StringAlignment.Far:StringAlignment.Near})g.DrawString(s??"",f,b,r,fmt);
    }
}
public sealed class VirexAction : Button {
    bool hover,pressed;
    public VirexAction(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);FlatStyle=FlatStyle.Flat;}
    protected override void OnMouseEnter(EventArgs e){base.OnMouseEnter(e);hover=true;Invalidate();}
    protected override void OnMouseLeave(EventArgs e){base.OnMouseLeave(e);hover=false;pressed=false;Invalidate();}
    protected override void OnMouseDown(MouseEventArgs e){base.OnMouseDown(e);pressed=true;Invalidate();}
    protected override void OnMouseUp(MouseEventArgs e){base.OnMouseUp(e);pressed=false;Invalidate();}
    protected override void OnEnabledChanged(EventArgs e){base.OnEnabledChanged(e);Invalidate();}
    protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
    protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();}
    protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;g.Clear(Parent==null?VirexVisual.Bg:Parent.BackColor);g.SmoothingMode=SmoothingMode.AntiAlias;
        Color fill=Enabled?VirexVisual.Blend(BackColor,pressed?Color.Black:Color.White,pressed?.13f:hover?.09f:0):Color.FromArgb(42,57,68);
        var r=new RectangleF(1,1,Width-3,Height-3);
        VirexVisual.Card(g,r,fill,Focused?VirexVisual.Teal:VirexVisual.Border,7);
        TextRenderer.DrawText(g,Text,Font,Rectangle.Round(r),Enabled?ForeColor:Color.FromArgb(158,174,186),TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.SingleLine);
    }
}
public sealed class VirexMode : CheckBox {
    public VirexMode(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);Appearance=Appearance.Button;}
    protected override void OnCheckedChanged(EventArgs e){base.OnCheckedChanged(e);Invalidate();}
    protected override void OnEnabledChanged(EventArgs e){base.OnEnabledChanged(e);Invalidate();}
    protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
    protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();}
    protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;g.Clear(Parent==null?VirexVisual.Bg:Parent.BackColor);g.SmoothingMode=SmoothingMode.AntiAlias;
        var r=new RectangleF(1,1,Width-3,Height-3);VirexVisual.Card(g,r,VirexVisual.Surface,Focused?VirexVisual.Teal:VirexVisual.Border,7);
        var a=new RectangleF(3,3,(Width-6)/2f,Height-7);var b=new RectangleF(a.Right,3,a.Width,a.Height);
        VirexVisual.Fill(g,Checked?b:a,Enabled?VirexVisual.Teal:Color.FromArgb(64,85,96),5);
        var flags=TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.SingleLine;
        TextRenderer.DrawText(g,"MANUAL",Font,Rectangle.Round(a),!Checked&&Enabled?VirexVisual.Bg:VirexVisual.Ink,flags);
        TextRenderer.DrawText(g,"AUTO",Font,Rectangle.Round(b),Checked&&Enabled?VirexVisual.Bg:VirexVisual.Ink,flags);
    }
}
public sealed class VirexCommandCenter : Control {
    readonly Font normal=new Font("Segoe UI",15,GraphicsUnit.Pixel), small=new Font("Segoe UI",13,GraphicsUnit.Pixel);
    readonly Font bold=new Font("Segoe UI Semibold",19,GraphicsUnit.Pixel), title=new Font("Segoe UI Semibold",29,GraphicsUnit.Pixel), large=new Font("Segoe UI Semibold",32,GraphicsUnit.Pixel);
    readonly Queue<double>[] history={new Queue<double>(),new Queue<double>(),new Queue<double>()};
    readonly double[] values={-1,-1,-1};
    readonly Timer animation=new Timer();
    string state="IDLE",display="Készen áll",gpu="—",detail="",target="",active="",diskName="Cache";
    string[] names=new string[0],states=new string[0],times=new string[0];
    int done,planned; double free=-1,total=-1,vram=-1,ramUsed=-1,ramTotal=-1;
    DateTime sampled=DateTime.MinValue;
    float shown,phase; bool motion=SystemInformation.UIEffectsEnabled;
    public int Completed {get{return done;}} public int Planned {get{return planned;}}
    public string GpuStatus {get{return gpu;}} public string RunState {get{return state;}}
    public int SampleCount {get{return history[0].Count;}}
    public bool MotionEnabled {get{return motion;}set{motion=value;UpdateAnimation();Invalidate();}}
    public VirexCommandCenter(){
        SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);
        BackColor=VirexVisual.Bg;AccessibleName="Futtatási áttekintés";AccessibleRole=AccessibleRole.Pane;
        animation.Interval=60;animation.Tick+=delegate{phase=(phase+3)%48;shown+=(Fraction-shown)*.22f;Invalidate();};
    }
    float Fraction{get{return planned>0?Math.Max(0,Math.Min(1,(float)done/planned)):0;}}
    void UpdateAnimation(){if(motion&&state=="RUNNING"&&Visible)animation.Start();else{animation.Stop();shown=Fraction;}}
    protected override void OnVisibleChanged(EventArgs e){base.OnVisibleChanged(e);UpdateAnimation();}
    public void SetRun(string s,string shownState,string gpuState,string info,string name,string current,int completed,int expected,string[] n,string[] st,string[] t){
        if(state!="RUNNING"&&s=="RUNNING")shown=0;
        state=s;display=shownState;gpu=gpuState;detail=info;target=name;active=current;done=completed;planned=expected;
        names=n??new string[0];states=st??new string[0];times=t??new string[0];
        if(shown>Fraction)shown=Fraction;
        UpdateAnimation();AccessibleDescription=display+"; "+done+"/"+planned+"; GPU "+gpu+"; "+detail;Invalidate();
    }
    public void Sample(double cpu,double ram,double gpuLoad,double video,double used,double installed){
        if(sampled!=DateTime.MinValue&&(DateTime.UtcNow-sampled).TotalSeconds>15)foreach(var h in history)h.Clear();
        double[] v={cpu,ram,gpuLoad};
        for(int i=0;i<3;i++){values[i]=v[i]>=0&&v[i]<=100?v[i]:-1;history[i].Enqueue(values[i]);while(history[i].Count>45)history[i].Dequeue();}
        vram=video;ramUsed=used;ramTotal=installed;sampled=DateTime.UtcNow;Invalidate();
    }
    public void SetStorage(string drive,double available,double size){if(diskName==drive&&free==available&&total==size)return;diskName=drive;free=available;total=size;Invalidate();}
    Color Status(string s){return s=="PASS"||s=="VERIFIED"?VirexVisual.Green:s=="RUNNING"?VirexVisual.Teal:s=="FAIL"||s=="RUNNER_ERROR"?VirexVisual.Red:s=="IDLE"||s=="—"?VirexVisual.Muted:VirexVisual.Amber;}
    void Icon(Graphics g,string s,float x,float y,Color c){
        using(var pen=new Pen(c,2.3f))using(var brush=new SolidBrush(c)){
            if(s=="PASS"||s=="VERIFIED"){g.FillEllipse(brush,x,y,22,22);using(var p=new Pen(VirexVisual.Bg,2.5f))g.DrawLines(p,new[]{new PointF(x+5,y+11),new PointF(x+9,y+15),new PointF(x+17,y+7)});}
            else if(s=="RUNNING"){g.DrawArc(pen,x+1,y+1,20,20,phase*7,260);g.DrawLine(pen,x+9,y+6,x+15,y+11);g.DrawLine(pen,x+15,y+11,x+9,y+16);}
            else{g.DrawEllipse(pen,x+1,y+1,20,20);g.DrawLine(pen,x+11,y+5,x+11,y+12);g.FillEllipse(brush,x+10,y+15,2,2);}
        }
    }
    void Metric(Graphics g,RectangleF r,string label,string value,Color c,bool highlighted,bool compact){
        VirexVisual.Card(g,r,highlighted?Color.FromArgb(9,49,53):VirexVisual.Surface,highlighted?Color.FromArgb(17,113,112):VirexVisual.Border,9);
        VirexVisual.Text(g,label,normal,VirexVisual.Ink,new RectangleF(r.X+14,r.Y+10,r.Width-28,25));
        VirexVisual.Text(g,value,compact?bold:large,c,new RectangleF(r.X+14,r.Y+39,r.Width-28,r.Height-45));
    }
    bool Fresh{get{return sampled!=DateTime.MinValue&&(DateTime.UtcNow-sampled).TotalSeconds<=15;}}
    void Spark(Graphics g,RectangleF r,int index,string label,Color c,string sub){
        VirexVisual.Card(g,r,VirexVisual.Surface,VirexVisual.Border,9);
        VirexVisual.Text(g,label,bold,VirexVisual.Ink,new RectangleF(r.X+14,r.Y+7,r.Width-78,27));
        VirexVisual.Text(g,Fresh&&values[index]>=0?values[index].ToString("0")+"%":"N/A",bold,c,new RectangleF(r.Right-70,r.Y+7,56,27),true);
        var plot=new RectangleF(r.X+14,r.Y+40,r.Width-28,r.Height-67);
        if(plot.Height>6){
            using(var pen=new Pen(VirexVisual.Border,1))g.DrawLine(pen,plot.Left,plot.Bottom,plot.Right,plot.Bottom);
            double[] data=history[index].ToArray();var segment=new List<PointF>();
            if(Fresh&&values[index]>=0&&data.Length>=2){
                for(int j=0;j<=data.Length;j++){
                    if(j<data.Length&&data[j]>=0){segment.Add(new PointF(plot.Left+plot.Width*j/Math.Max(1,data.Length-1),plot.Bottom-plot.Height*(float)data[j]/100));continue;}
                    if(segment.Count>=2)using(var path=new GraphicsPath())using(var fill=new LinearGradientBrush(plot,Color.FromArgb(100,c),Color.FromArgb(5,c),90f))using(var pen=new Pen(c,2)){
                        path.AddLines(segment.ToArray());path.AddLine(segment[segment.Count-1],new PointF(segment[segment.Count-1].X,plot.Bottom));path.AddLine(new PointF(segment[segment.Count-1].X,plot.Bottom),new PointF(segment[0].X,plot.Bottom));path.CloseFigure();g.FillPath(fill,path);g.DrawLines(pen,segment.ToArray());
                    }else if(segment.Count==1)using(var brush=new SolidBrush(c))g.FillEllipse(brush,segment[0].X-2,segment[0].Y-2,4,4);
                    segment.Clear();
                }
            }else VirexVisual.Text(g,"Nincs elegendő friss adat",small,VirexVisual.Muted,plot);
        }
        VirexVisual.Text(g,sub,small,VirexVisual.Muted,new RectangleF(r.X+14,r.Bottom-24,r.Width-28,20));
    }
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);var g=e.Graphics;g.Clear(VirexVisual.Bg);g.SmoothingMode=SmoothingMode.AntiAlias;g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        if(ClientSize.Width<10||ClientSize.Height<10)return;
        float scale=Math.Min(ClientSize.Width/880f,ClientSize.Height/535f);g.ScaleTransform(scale,scale);
        float w=ClientSize.Width/scale,h=ClientSize.Height/scale,p=12,gap=12,side=Math.Max(235,w*.30f),main=w-side-2*p-gap,rx=p+main+gap;
        VirexVisual.Text(g,"Futtatási áttekintés",title,VirexVisual.Ink,new RectangleF(p,5,main,43));
        VirexVisual.Text(g,target,small,VirexVisual.Muted,new RectangleF(p,47,main,20));
        float cw=(main-2*gap)/3;
        Metric(g,new RectangleF(p,77,cw,98),"Állapot",state=="RUNNING"?"Fut":display,Status(state),true,display.Length>10&&state!="RUNNING");
        Metric(g,new RectangleF(p+cw+gap,77,cw,98),"Lépések",planned==0?"—":done+" / "+planned,VirexVisual.Ink,false,false);
        Metric(g,new RectangleF(p+2*(cw+gap),77,cw,98),"GPU-validáció",gpu=="—"?"NOT VERIFIED":gpu,Status(gpu=="—"?"NOT VERIFIED":gpu),false,true);
        var prog=new RectangleF(p,188,main,102);VirexVisual.Card(g,prog,VirexVisual.Surface,VirexVisual.Border,9);
        VirexVisual.Text(g,String.IsNullOrEmpty(active)?detail:"Aktív lépés:  "+active,bold,VirexVisual.Ink,new RectangleF(p+15,prog.Y+9,main-30,31));
        var track=new RectangleF(p+15,prog.Y+52,main-86,17);VirexVisual.Fill(g,track,Color.FromArgb(37,65,78),7);
        if(shown>0){
            var bar=new RectangleF(track.X,track.Y,track.Width*Math.Min(shown,Fraction),track.Height);
            if(bar.Width>0){using(var path=VirexVisual.Path(bar,7))using(var brush=new LinearGradientBrush(bar,VirexVisual.Teal,Color.FromArgb(102,249,222),0f)){
                g.FillPath(brush,path);
                if(motion&&state=="RUNNING"){var saved=g.Save();g.SetClip(path);using(var pen=new Pen(Color.FromArgb(55,255,255,255),7))for(float x=bar.X-24+phase;x<bar.Right+24;x+=24)g.DrawLine(pen,x,bar.Bottom,x+18,bar.Top);g.Restore(saved);}
            }}
        }
        VirexVisual.Text(g,planned>0?(Fraction*100).ToString("0")+"%":"—",bold,VirexVisual.Ink,new RectangleF(track.Right+7,track.Y-5,53,26),true);
        VirexVisual.Text(g,"Befejezett lépések aránya · a terv futás közben bővülhet",small,VirexVisual.Muted,new RectangleF(p+15,prog.Bottom-25,main-30,20));
        var list=new RectangleF(p,303,main,h-315);VirexVisual.Card(g,list,VirexVisual.Surface,VirexVisual.Border,9);
        VirexVisual.Text(g,"Legutóbbi tesztlépések ("+names.Length+")",bold,VirexVisual.Ink,new RectangleF(p+15,list.Y+8,main-30,31));
        float rh=Math.Min(49,(list.Height-48)/5);
        if(names.Length==0)VirexVisual.Text(g,"Még nincs futtatási eredmény.",normal,VirexVisual.Muted,new RectangleF(p+15,list.Y+54,main-30,30));
        for(int i=0;i<names.Length&&i<states.Length;i++){
            float yy=list.Y+43+i*rh;Color c=Status(states[i]);
            if(states[i]=="RUNNING")VirexVisual.Fill(g,new RectangleF(p+8,yy,main-16,rh-2),Color.FromArgb(11,61,65),6);
            else using(var pen=new Pen(VirexVisual.Border,1))g.DrawLine(pen,p+12,yy,p+main-12,yy);
            Icon(g,states[i],p+15,yy+(rh-22)/2,c);
            VirexVisual.Text(g,states[i]=="RUNNING"?"FUT":states[i],small,c,new RectangleF(p+44,yy,105,rh-2));
            VirexVisual.Text(g,names[i],normal,VirexVisual.Ink,new RectangleF(p+153,yy,main-232,rh-2));
            VirexVisual.Text(g,i<times.Length?times[i]:"",small,VirexVisual.Muted,new RectangleF(p+main-75,yy,61,rh-2),true);
        }
        float sy=12,sh=(h-24-3*gap)/4;
        Spark(g,new RectangleF(rx,sy,side,sh),0,"CPU",VirexVisual.Teal,"Rendszerszintű kihasználtság");
        Spark(g,new RectangleF(rx,sy+sh+gap,side,sh),1,"RAM",Color.FromArgb(64,169,245),Fresh&&ramUsed>=0&&ramTotal>0?ramUsed.ToString("0.0")+" / "+ramTotal.ToString("0.0")+" GiB":"Fizikai memória");
        Spark(g,new RectangleF(rx,sy+2*(sh+gap),side,sh),2,"GPU",VirexVisual.Teal,Fresh&&vram>=0?"VRAM: "+vram.ToString("0.00")+" GiB · dedikált":"VRAM: N/A");
        var disk=new RectangleF(rx,sy+3*(sh+gap),side,sh);VirexVisual.Card(g,disk,VirexVisual.Surface,VirexVisual.Border,9);
        VirexVisual.Text(g,"Tárhely · "+diskName,bold,VirexVisual.Ink,new RectangleF(rx+14,disk.Y+7,side-28,28));
        VirexVisual.Text(g,free>=0?free.ToString("0.0")+" GiB szabad":"N/A",normal,VirexVisual.Muted,new RectangleF(rx+14,disk.Y+36,side-28,23));
        var dt=new RectangleF(rx+14,disk.Y+65,side-28,9);VirexVisual.Fill(g,dt,VirexVisual.Border,4);
        if(free>=0&&total>0)VirexVisual.Fill(g,new RectangleF(dt.X,dt.Y,dt.Width*(float)Math.Max(0,Math.Min(1,free/total)),dt.Height),VirexVisual.Teal,4);
        VirexVisual.Text(g,total>0?"Összesen: "+total.ToString("0.0")+" GiB":"Kapacitás: N/A",small,VirexVisual.Muted,new RectangleF(rx+14,disk.Bottom-24,side-28,20));
    }
    protected override void Dispose(bool disposing){if(disposing){animation.Stop();animation.Dispose();normal.Dispose();small.Dispose();bold.Dispose();title.Dispose();large.Dispose();}base.Dispose(disposing);}
}
'@

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
    $button=New-Object VirexAction
    $button.Text=$text;$button.Size=New-Object Drawing.Size($width,$height)
    $button.BackColor=Color $fill;$button.ForeColor=$fg;$button.Font=Font 10 'Segoe UI' $true
    $parent.Controls.Add($button)
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
    $option.FlatStyle='Flat';$option.FlatAppearance.CheckedBackColor=$cyan
    return $option
}

function Set-StudioTabStyle($control) {
    $control.DrawMode='OwnerDrawFixed'
    $control.SizeMode='Fixed'
    $control.ItemSize=New-Object Drawing.Size(106,26)
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
    $page.BackColor=$bg
    # Model fields retain the original overview binding contract.
    $script:welcomeName=[pscustomobject]@{Text=''}
    $script:welcomeDetail=[pscustomobject]@{Text=''}
    $script:overviewStatus=[pscustomobject]@{Text='';ForeColor=$cyan}
    $script:overviewSteps=[pscustomobject]@{Text='—'}
    $script:overviewGpu=[pscustomobject]@{Text='—'}
    $script:overviewDetail=[pscustomobject]@{Text=''}
    $script:commandCenter=New-Object VirexCommandCenter
    $commandCenter.Dock='Fill'
    $page.Controls.Add($commandCenter)
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
        else { 'Válassz tesztcélt és ellenőrzéseket.' }
    $recent=@($steps | Select-Object -Last 5)
    $names=[string[]]@($recent | ForEach-Object {$_.Name})
    $states=[string[]]@($recent | ForEach-Object {if($_.Status -eq 'PASS' -and $_.Kind -eq 'depthtest'){$_.GpuExecution}else{$_.Status}})
    $times=[string[]]@($recent | ForEach-Object {if($_.Status -eq 'RUNNING'){'…'}else{('{0:0.00}s' -f $_.Seconds)}})
    $planned=if($runState -eq 'IDLE'){0}else{$progress.Maximum}
    $current=if($active){[string]$active.Name}else{''}
    $commandCenter.SetRun($runState,$overviewStatus.Text,$overviewGpu.Text,$overviewDetail.Text,([string]$welcomeName.Text+'  ·  '+([string]$welcomeDetail.Text -replace '[\r\n]+',' ')),$current,$completed.Count,$planned,$names,$states,$times)
}

function Update-StudioNavigation {
    foreach($button in $script:navButtons){
        $selected=$button.Tag -eq $tabs.SelectedTab
        $button.BackColor=if($selected){Color '#0C444A'}else{$bg}
        $button.ForeColor=if($selected){$cyan}else{$fg}
        $button.Invalidate()
    }
}
function Initialize-StudioNavigation {
    $script:navButtons=@()
    foreach($page in $tabs.TabPages){
        $name=if($page.Text -eq 'Tárhely / hardver'){'Tárhely'}else{$page.Text}
        $button=New-Action $navigation $name '#0A1822' 112 38
        $button.Tag=$page
        $button.AccessibleName=$page.Text
        $button.Add_Click({param($sender,$event) $tabs.SelectedTab=$sender.Tag})
        $script:navButtons+=@($button)
    }
    $tabs.Add_SelectedIndexChanged({Update-StudioNavigation})
    Update-StudioNavigation
}
$ink = Color '#E5EDF7'
$inkMuted = Color '#A5B5CA'
$form = New-Object Windows.Forms.Form
$form.Text = if ($script:isPreview) { "VIREX Test Studio  $studioVersion · Előnézet" } else { "VIREX Test Studio  $studioVersion" }
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96,96)
$form.ClientSize = New-Object Drawing.Size(1400,850)
$form.MinimumSize = New-Object Drawing.Size(800,590)
$form.BackColor = $bg
$form.ForeColor = $fg
$form.Font = Font 10
$form.Icon = New-Object Drawing.Icon((Join-Path $appDir 'assets\studio.ico'))
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 1
$layout.RowCount = 4
foreach ($height in @(76,51,-1,38)) {
    $style = New-Object Windows.Forms.RowStyle
    if ($height -lt 0) { $style.SizeType='Percent'; $style.Height=100 } else { $style.SizeType='Absolute'; $style.Height=$height }
    $null = $layout.RowStyles.Add($style)
}
$form.Controls.Add($layout)
$header = New-Object Windows.Forms.Panel
$header.Margin = [Windows.Forms.Padding]::Empty
$header.Dock = 'Fill'
$header.BackColor = Color '#0A1822'
$layout.Controls.Add($header,0,0)
$mark = New-Object Windows.Forms.PictureBox
$mark.Image = [Drawing.Image]::FromFile((Join-Path $appDir 'assets\studio.png'))
$mark.SizeMode = 'Zoom'
$mark.SetBounds(19,17,42,42)
$header.Controls.Add($mark)
$brand = Label $header 'VIREX TEST STUDIO' 74 9 440 36 22 $true
$captionText = if ($script:isPreview) { "Előnézet   /   v$studioVersion" } else { "Helyi Rust tesztlabor   /   v$studioVersion" }
$caption = Label $header $captionText 77 48 340 19 9
$caption.ForeColor = $cyan
$updateLabel = '&Frissítések'
$updateButton = New-Action $header $updateLabel '#12434B' 145 36
$updateButton.Dock = 'Right'
$header.Padding = New-Object Windows.Forms.Padding(0,18,20,18)

$navigation=New-Stack $layout 'LeftToRight' $false
$navigation.Dock='Fill';$navigation.AutoScroll=$true;$navigation.BackColor=$bg
$navigation.Padding=New-Object Windows.Forms.Padding(12,3,0,0)
$layout.SetCellPosition($navigation,(New-Object Windows.Forms.TableLayoutPanelCellPosition(0,1)))
$body = New-Object Windows.Forms.TableLayoutPanel
$body.Dock='Fill'
$body.Margin=[Windows.Forms.Padding]::Empty
$body.ColumnCount=2
$null=$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute',288)))
$null=$body.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
$layout.Controls.Add($body,0,2)
$sidePanel = New-Object Windows.Forms.Panel
$sidePanel.Dock='Fill'
$sidePanel.AutoScroll=$true
$sidePanel.BackColor=Color '#102430'
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
$openSource=New-Action $sidebar 'Forrás megnyitása' '#1E3948' 194 30
$rule=New-Object Windows.Forms.Panel
$rule.Size=New-Object Drawing.Size(242,1)
$rule.Margin=New-Object Windows.Forms.Padding(0,12,0,8)
$rule.BackColor=Color '#2D4958'
$sidebar.Controls.Add($rule)
$null=New-Caption $sidebar 'Futtatási mód' 13 $ink $true
$modeSwitch=New-Object VirexMode
$modeSwitch.Appearance='Button';$modeSwitch.FlatStyle='Flat';$modeSwitch.FlatAppearance.BorderSize=0
$modeSwitch.UseVisualStyleBackColor=$false;$modeSwitch.TextAlign='MiddleCenter'
$modeSwitch.Font=Font 11 'Segoe UI' $true;$modeSwitch.ForeColor=$fg
$modeSwitch.BackColor=Color '#1E3948';$modeSwitch.Size=New-Object Drawing.Size(240,40)
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
$runButton=New-Action $actions '&Futtatás' '#00DECE' 240 43
$runButton.ForeColor=$bg;$runButton.Font=Font 12 'Segoe UI' $true
$stopButton=New-Action $actions '&Leállítás' '#263D4B' 240 38
$stopButton.Enabled=$false

$workArea=New-Object Windows.Forms.TableLayoutPanel
$workArea.Dock='Fill'
$workArea.Margin=[Windows.Forms.Padding]::Empty
$workArea.Padding=New-Object Windows.Forms.Padding(4,3,5,3)
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
$localLink=New-Action $bottom 'Helyi projekt…' '#263D4B' 120
$localLink.Add_Click({if($openSource.Enabled){$combo.SelectedIndex=1;$openSource.PerformClick()}})
$helpLink=New-Action $bottom 'Útmutató · F1' '#263D4B' 110
$helpLink.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $appDir 'README.md')+'"')})
$motionToggle=New-Option $bottom 'Animáció' $true
$motionToggle.Width=90
$motionToggle.Add_CheckedChanged({$commandCenter.MotionEnabled=$motionToggle.Checked})
$foot=New-Object Windows.Forms.Label
$foot.Dock='Fill'
$foot.Margin=[Windows.Forms.Padding]::Empty
$foot.Padding=New-Object Windows.Forms.Padding(18,0,12,0)
$foot.TextAlign='MiddleLeft'
$foot.BackColor=Color '#0A1822'
$foot.ForeColor=$fg
$foot.Font=Font 9
$foot.Text='Válassz tesztcélt és ellenőrzéseket, majd indítsd a futtatást.'
$layout.Controls.Add($foot,0,3)
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
