# VIREX Test Studio - local, explicit execution only. Windows PowerShell 5.1.
# No server, no API key, no telemetry. All source tests run as the current user.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
# Keep the native process handle and drain redirected streams before reading its exit code.
# PowerShell 5.1 Start-Process -PassThru can return a Process with no cached exit code.
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Threading;

public sealed class VirexChild : IDisposable {
    private Process process;
    private StreamWriter stdout, stderr;
    private readonly object gate = new object();
    private string captureError;
    private bool disposed;
    private volatile bool outDone, errDone;
    private IntPtr job;
    private bool assigned;
    private int stopRequested;
    private string stopError;
    public bool OutputComplete { get { return outDone && errDone; } }
    public string StopError { get { lock (gate) { return stopError; } } }
    public bool TreeExited {
        get {
            if (!process.HasExited) return false;
            if (!assigned) return OutputComplete;
            Accounting a;
            if (!QueryInformationJobObject(job, 1, out a, (uint)Marshal.SizeOf(typeof(Accounting)), IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return a.ActiveProcesses == 0;
        }
    }
    [StructLayout(LayoutKind.Sequential)] private struct BasicLimit {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass, SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] private struct IoCounters {
        public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount,
            ReadTransferCount, WriteTransferCount, OtherTransferCount;
    }
    [StructLayout(LayoutKind.Sequential)] private struct ExtendedLimit {
        public BasicLimit BasicLimitInformation;
        public IoCounters IoInfo;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Accounting {
        public long TotalUserTime, TotalKernelTime, ThisPeriodTotalUserTime, ThisPeriodTotalKernelTime;
        public uint TotalPageFaultCount, TotalProcesses, ActiveProcesses, TotalTerminatedProcesses;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimit data, uint size);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool QueryInformationJobObject(IntPtr job, int kind, out Accounting data, uint size, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool TerminateJobObject(IntPtr job, uint exitCode);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool CloseHandle(IntPtr handle);
    private void CreateJob() {
        job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        ExtendedLimit limit = new ExtendedLimit();
        limit.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if (!SetInformationJobObject(job, 9, ref limit, (uint)Marshal.SizeOf(typeof(ExtendedLimit))))
            throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public string CaptureError { get { lock (gate) { return captureError; } } }
    public bool HasExited { get { return process.HasExited; } }
    public int Id { get { return process.Id; } }
    public int ExitCode { get { return process.ExitCode; } }

    private VirexChild() {}
    public static VirexChild Start(string file, string args, string cwd, string outPath, string errPath) {
        VirexChild child = new VirexChild();
        try {
            child.stdout = new StreamWriter(new FileStream(outPath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite), new UTF8Encoding(false));
            child.stderr = new StreamWriter(new FileStream(errPath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite), new UTF8Encoding(false));
            child.stdout.AutoFlush = true;
            child.stderr.AutoFlush = true;
            child.CreateJob();
            child.process = new Process();
            child.process.StartInfo = new ProcessStartInfo(file, args ?? "") {
                WorkingDirectory = cwd, UseShellExecute = false, CreateNoWindow = true,
                RedirectStandardOutput = true, RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
            };
            child.process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data == null) child.outDone = true; else child.Write(child.stdout, e.Data); };
            child.process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data == null) child.errDone = true; else child.Write(child.stderr, e.Data); };
            if (!child.process.Start()) throw new InvalidOperationException("Native process did not start.");
            // Start() retains the handle; accessing it explicitly also ensures it is available.
            IntPtr handle = child.process.Handle;
            child.assigned = AssignProcessToJobObject(child.job, handle);
            if (!child.assigned && !child.process.HasExited)
                throw new InvalidOperationException("Could not attach child to a Windows Job Object; refusing untracked execution.");
            child.process.BeginOutputReadLine();
            child.process.BeginErrorReadLine();
            return child;
        } catch {
            try { if (child.process != null && !child.process.HasExited) child.process.Kill(); } catch {}
            child.Dispose();
            throw;
        }
    }
    private void Write(StreamWriter writer, string line) {
        if (line == null) return;
        lock (gate) {
            if (disposed) return;
            try { writer.WriteLine(line); }
            catch (Exception ex) { if (captureError == null) captureError = ex.ToString(); }
        }
    }
    public void RequestStop() {
        if (Interlocked.Exchange(ref stopRequested, 1) != 0) return;
        // No WaitForExit on the UI thread. The timer checks termination and EOF.
        ThreadPool.QueueUserWorkItem(delegate(object unused) {
            try {
                lock (gate) {
                    if (disposed) return;
                    if (assigned) {
                        if (!TerminateJobObject(job, 1223))
                            throw new Win32Exception(Marshal.GetLastWin32Error());
                    } else if (!process.HasExited) process.Kill();
                }
            } catch (Exception ex) { lock (gate) { stopError = ex.Message; } }
        });
    }
    public void Dispose() {
        lock (gate) {
            if (disposed) return;
            disposed = true;
            if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
            if (stdout != null) stdout.Dispose();
            if (stderr != null) stderr.Dispose();
        }
        if (process != null) process.Dispose();
    }
}
'@

$script:root = Join-Path $env:LOCALAPPDATA 'VIREX Test Studio'
$script:repo = Join-Path $script:root 'repo'
$script:reports = Join-Path $script:root 'reports'
$script:origin = 'https://github.com/VlREX/VIREX.git'
$script:appDir = $PSScriptRoot
$script:studioVersion = [IO.File]::ReadAllText((Join-Path $appDir 'VERSION')).Trim()
$script:isPreview = Test-Path -LiteralPath (Join-Path $appDir 'PREVIEW') -PathType Leaf
$script:localProject = $null
$script:workDir = $repo
$script:inheritedTargetDir = $env:CARGO_TARGET_DIR
$null = New-Item -ItemType Directory -Force -Path $script:repo,$script:reports
$script:presets = @(
    @{Name='#1869 | Adaptive memory range index'; Branch='perf/indexed-copyback-ranges'; Sha='163c39fffb76a0c14db047a12e972d9bdb26ce7b'; Crate='victory-gpu'; Filter='precise_ranges'; Features=$true; Bench='adaptive'},
    @{Name='#2718 | Keyboard hold ordering'; Branch='fix/duplicate-scripted-keys'; Sha='ee868cd01b7be2518309458013bbdc743f984bcd'; Crate='victory-hle'; Filter='gameinput::'; Features=$true; Bench=''},
    @{Name='#2747 | Windows 10 texture fallback'; Branch='fix/texture-test-device10-fallback'; Sha='3892a538176eeee8c443f36551e3c52fb6745b66'; Crate='victory-gpu'; Filter='a_texture_written_in_one_format_reads_in_another_through_a_placed_view'; Features=$true; Bench=''},
    @{Name='#2747 FIX CANDIDATE | Alias flags fallback'; Branch='fix/texture-alias-inherited-flags-2747'; Sha='838efa0843036ef80808eef7061276b5b5d139f4'; Crate='victory-gpu'; Filter='a_texture_written_in_one_format_reads_in_another_through_a_placed_view'; Features=$true; Bench=''},
    @{Name='#1840 | Shader loop discovery'; Branch='perf/shader-scc-loop-discovery'; Sha='f8132358098d08f8fe58df32732d14b8e1c388fd'; Crate='victory-shader'; Filter='ir::tests::scc_'; Features=$false; Bench=''},
    @{Name='#1840 BASELINE | Shader reference (full suite optional)'; Branch='perf/shader-scc-loop-discovery'; Sha='70564ae08c82d43df5fad97b08d34628b07b1d9d'; Crate='victory-shader'; Filter='ir::tests::'; Features=$false; Bench=''},
    @{Name='#1846 | Shader liveness worklist'; Branch='perf/worklist-liveness-corpus'; Sha='fc589dbde847ea5bb6b587d9bfcb0dd78d481532'; Crate='victory-shader'; Filter='liveness'; Features=$false; Bench=''},
    @{Name='#1862 | Bindless slot index'; Branch='perf/bindless-slot-index-corpus'; Sha='3ff4bc053cd9aed53f125b4f6caf001e06347dd4'; Crate='victory-gpu'; Filter='slot_tests'; Features=$true; Bench=''},
    @{Name='#2479 | Frame interval synchronization'; Branch='fix/frame-interval-clock-lock'; Sha='30a5f1d7459a342e44ae81f977eec599b772600e'; Crate='victory-gpu'; Filter='frame::tests::'; Features=$true; Bench=''},
    @{Name='#1840 BENCH | SCC loop discovery'; Branch='bench/shader-scc-loop-discovery'; Sha='b561b22e518de41d54be01dd470c2c042d2b8a5c'; Crate='victory-shader'; Filter='ir::tests::scc_'; Features=$false; Bench='cargo'; BenchFilter='bench_scc_loop_discovery'; BenchCount=12},
    @{Name='#1846 BENCH | Liveness worklist'; Branch='bench/shader-liveness-worklist'; Sha='1627eaa3bba86d6cbce0f8ba8234ef9fdb02c542'; Crate='victory-shader'; Filter='liveness'; Features=$false; Bench='cargo'; BenchFilter='bench_liveness_worklist'; BenchCount=12},
    @{Name='#1862 BENCH | Bindless slot index'; Branch='bench/bindless-slot-index'; Sha='b62629774da0bc36df5e462f7b5d7fd9c145d033'; Crate='victory-gpu'; Filter='slot_tests'; Features=$true; Bench='cargo'; BenchFilter='bench_slot_index'; BenchCount=27},
    @{Name='#1867 | Safe shadow merge'; Branch='perf/avx2-shadow-merge'; Sha='ea57fd91c0fb76bdf4b6017ba5d8bf16be2d526c'; Crate='victory-gpu'; Filter='shadow'; Features=$true; Bench=''},
    @{Name='#1884 | Memory guard batching'; Branch='perf/memory-guard-batching'; Sha='c14ab1d8144ac2a681eb7a56e34d432af5c8412d'; Crate='victory-gpu'; Filter='page_batch'; Features=$true; Bench=''},
    @{Name='Benchmark #12 | Original range index'; Branch='bench/precise-copyback-ranges'; Sha='7be00b2bea1fb34be397b2aefda76b090c1a0be0'; Crate='victory-gpu'; Filter='precise_ranges'; Features=$true; Bench='precise'},
    @{Name='Benchmark #8 | Shadow merge (historical)'; Branch='bench/shadow-merge-rust'; Sha='44ebb1d8d558e4f2018aa8a47bd1dc7942410b83'; Crate='victory-gpu'; Filter='shadow'; Features=$true; Bench='shadow'},
    @{Name='Benchmark #11 | Windows page protection'; Branch='bench/page-guard-protect'; Sha='ea4b59c142e325c0d467b37c42ad43dedb3e7b0a'; Crate='victory-gpu'; Filter='page_batch'; Features=$true; Bench='page'}
)
$script:queue = New-Object 'System.Collections.Generic.Queue[object]'
$script:steps = New-Object 'System.Collections.Generic.List[object]'
$script:proc = $null
$script:active = $null
$script:runDir = $null
$script:runPreset = $null
$script:runState = 'IDLE'
$script:cancelled = $false
$script:stopAt = $null
$script:exitSeenAt = $null
$script:closeAfterStop = $false
$script:unsafeState = $false
$script:started = $null
$script:machine = @{}
$script:levelResults=@{}
$script:diagnosticActive=$false
$script:mutex = New-Object System.Threading.Mutex($false, 'Local\VIREX-Test-Studio-v1')
try { $ownsMutex=$script:mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $ownsMutex=$true }
if (-not $ownsMutex) { [System.Windows.Forms.MessageBox]::Show('Test Studio is already running.') | Out-Null; exit }

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$bg=Color '#0A1822'; $panel=Color '#0F212D'; $fg=Color '#ECF4F8'; $muted=Color '#A5BCCB'; $cyan=Color '#00DECE'; $green=Color '#51D88A'; $red=Color '#FF8181'
$amber = Color '#FFD18C'
function Get-ValidationStatusColor([string]$state) {
    switch ($state) {
        'PASS' { return $green }
        'CANCELLED' { return $muted }
        'NOT VERIFIED' { return $amber }
        'SKIPPED' { return $amber }
        default { return $red }
    }
}
function Font([float]$size,[string]$family='Segoe UI',[bool]$bold=$false) {
    $style = [System.Drawing.FontStyle]::Regular; if ($bold) {$style=[System.Drawing.FontStyle]::Bold}
    New-Object System.Drawing.Font($family,$size,$style)
}
function Label($parent,[string]$value,[int]$x,[int]$y,[int]$w,[int]$h,[float]$size=10,[bool]$bold=$false) {
    $c=New-Object System.Windows.Forms.Label; $c.Text=$value; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,$h); $c.Font=Font $size 'Segoe UI' $bold; $c.ForeColor=$fg; $parent.Controls.Add($c); return $c
}
function Button($parent,[string]$value,[int]$x,[int]$y,[int]$w,[int]$h,[string]$fill='#263B53') {
    $c=New-Object System.Windows.Forms.Button; $c.Text=$value; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,$h); $c.BackColor=Color $fill; $c.ForeColor=$fg; $c.FlatStyle='Flat'; $c.FlatAppearance.BorderSize=0; $c.Font=Font 10 'Segoe UI' $true; $parent.Controls.Add($c); return $c
}
function Check($parent,[string]$value,[int]$x,[int]$y,[int]$w,[bool]$checked) {
    $c=New-Object System.Windows.Forms.CheckBox; $c.Text=$value; $c.Location=New-Object System.Drawing.Point($x,$y); $c.Size=New-Object System.Drawing.Size($w,27); $c.ForeColor=$fg; $c.Checked=$checked; $parent.Controls.Add($c); return $c
}
. (Join-Path $appDir 'Desktop.ps1')
. (Join-Path $appDir 'Benchmark.ps1')
$overviewTab=New-Object Windows.Forms.TabPage
$overviewTab.Text='Áttekintés'
$tabs.TabPages.Add($overviewTab)
Add-StartPanel $overviewTab
$motionToggle.Checked=$commandCenter.MotionEnabled
$logTab=New-Object System.Windows.Forms.TabPage; $logTab.Text='Napló'; $logTab.BackColor=$bg; $tabs.TabPages.Add($logTab)
$script:terminal=New-Object System.Windows.Forms.RichTextBox; $terminal.Dock='Fill'; $terminal.ReadOnly=$true; $terminal.BackColor=Color '#0B1220'; $terminal.ForeColor=$fg; $terminal.Font=Font 10 'Consolas'; $terminal.WordWrap=$false; $terminal.DetectUrls=$false; $logTab.Controls.Add($terminal)
$benchTab=New-Object System.Windows.Forms.TabPage; $benchTab.Text='Mérések'; $benchTab.BackColor=$bg; $tabs.TabPages.Add($benchTab)
$script:grid=New-Object System.Windows.Forms.DataGridView; $grid.Dock='Fill'; $grid.ReadOnly=$true; $grid.AllowUserToAddRows=$false; $grid.AllowUserToDeleteRows=$false; $grid.RowHeadersVisible=$false; $grid.AutoSizeColumnsMode='Fill'; $grid.BackgroundColor=$bg; $grid.BorderStyle='None'; $grid.DefaultCellStyle.BackColor=$panel; $grid.DefaultCellStyle.ForeColor=$fg; $grid.AlternatingRowsDefaultCellStyle.BackColor=Color '#202E43'; $grid.ColumnHeadersDefaultCellStyle.BackColor=Color '#23334A'; $grid.ColumnHeadersDefaultCellStyle.ForeColor=$fg; $grid.EnableHeadersVisualStyles=$false
foreach($col in @('Scenario','Linear / original','Indexed / select','Adaptive / AVX2','Best speedup','Unit')){$null=$grid.Columns.Add($col,$col)}; $benchTab.Controls.Add($grid)
$script:chart=New-Object System.Windows.Forms.Panel; $chart.Dock='Bottom'; $chart.Height=132; $chart.BackColor=$panel; $benchTab.Controls.Add($chart); $grid.BringToFront()
$script:chartTitle=Label $chart 'Az összehasonlításhoz válassz egy mérési sort.' 15 8 1000 22 10 $true
$script:chartBars=@(); $script:chartLabels=@(); $script:chartValues=@()
for($i=0;$i -lt 3;$i++){
    $y=36+29*$i
    $name=@('Original','Indexed / select','Adaptive / AVX2')[$i]; $script:chartLabels+=@(Label $chart $name 15 $y 145 22 9)
    $bar=New-Object System.Windows.Forms.Panel; $bar.Location=New-Object System.Drawing.Point(165,($y+3)); $bar.Size=New-Object System.Drawing.Size(0,16); $bar.BackColor=@($muted,$cyan,$green)[$i]; $chart.Controls.Add($bar); $script:chartBars+=@($bar)
    $script:chartValues+=@(Label $chart '-' 730 $y 260 23 9)
}
function Update-Chart {
    $track = [math]::Max(20,$chart.ClientSize.Width - 265)
    for ($i=0; $i -lt 3; $i++) { $chartValues[$i].Left = 165 + $track + 6 }
    if(!$grid.CurrentRow){return}
    $row=$grid.CurrentRow; $chartTitle.Text=[string]$row.Cells[0].Value+' | lower is better'
    $values=@(0.0,0.0,0.0); $available=@($false,$false,$false)
    for($i=0;$i -lt 3;$i++){ $v=0.0; $available[$i]=[double]::TryParse([string]$row.Cells[$i+1].Value,[System.Globalization.NumberStyles]::Float,[cultureinfo]::InvariantCulture,[ref]$v); $values[$i]=$v }
    $max=($values | Measure-Object -Maximum).Maximum; if($max -le 0){$max=1}
    for($i=0;$i -lt 3;$i++){ $chartBars[$i].Width=[int][math]::Round($track*$values[$i]/$max); $chartValues[$i].Text=if($available[$i]){$values[$i].ToString('F4',[cultureinfo]::InvariantCulture)+' '+$row.Cells[5].Value}else{'not measured'} }
}
$grid.Add_SelectionChanged({Update-Chart})
$chart.Add_Resize({Update-Chart})
$summaryTab=New-Object System.Windows.Forms.TabPage; $summaryTab.Text='Riport'; $summaryTab.BackColor=$bg; $tabs.TabPages.Add($summaryTab)
$script:reportBox=New-Object System.Windows.Forms.TextBox; $reportBox.Multiline=$true; $reportBox.ReadOnly=$true; $reportBox.ScrollBars='Both'; $reportBox.WordWrap=$false; $reportBox.Dock='Fill'; $reportBox.BackColor=$bg; $reportBox.ForeColor=$fg; $reportBox.Font=Font 10 'Consolas'; $summaryTab.Controls.Add($reportBox)
. (Join-Path $script:appDir 'AI-Review.ps1')
Set-StudioTabStyle $tabs
Update-StudioOverview
. (Join-Path $appDir 'DesktopUpdate.ps1')

function Add-Log([string]$text,[System.Drawing.Color]$color=$fg) {
    if ([string]::IsNullOrEmpty($text)) {return}
    if ($terminal.TextLength -gt 240000) { $terminal.Select(0,80000); $terminal.SelectedText='' }
    $terminal.SelectionStart=$terminal.TextLength; $terminal.SelectionColor=$color; $terminal.AppendText($text); if($tabs.SelectedTab -eq $logTab){$terminal.ScrollToCaret()}
}
function Read-Shared([string]$path) {
    if (!(Test-Path -LiteralPath $path)) {return ''}
    $stream=$null; $reader=$null
    try { $stream=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite); $reader=New-Object System.IO.StreamReader($stream,[System.Text.Encoding]::UTF8,$true); return $reader.ReadToEnd() }
    catch {return ''} finally {if($reader){$reader.Dispose()}elseif($stream){$stream.Dispose()}}
}
function Add-Step([string]$name,[string]$exe,[string]$arguments,[string]$kind='normal') {
    $script:queue.Enqueue(@{Name=$name;Exe=$exe;Args=$arguments;Kind=$kind})
}
function Tool-Path([string]$name) {
    $c=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$c) {throw "Missing executable: $name. Restart Studio after installing Rust/Git."}; return $c.Source
}
function Redact([string]$s) {
    if ($env:USERPROFILE) {$s=[regex]::Replace($s,[regex]::Escape($env:USERPROFILE),'%USERPROFILE%','IgnoreCase')}; return $s
}
function Add-BenchmarkRows($rows) {
    $culture = [cultureinfo]::InvariantCulture
    foreach ($row in $rows) {
        $adaptive = if ($null -eq $row.adaptive) { '-' } else { $row.adaptive.ToString('F4', $culture) }
        $index = $grid.Rows.Add($row.scenario, $row.original.ToString('F4', $culture),
            $row.indexed.ToString('F4', $culture), $adaptive, ($row.speedup.ToString('F2', $culture) + 'x'), $row.unit)
        $grid.Rows[$index].Cells[4].Style.ForeColor = if ($row.speedup -gt 1) { $green } else { $red }
    }
}
function Update-Tail {
    if(!$script:active){return}
    foreach($stream in @('Out','Err')){
        $path=$script:active[$stream]; $key=$stream+'Bytes'; $offset=[long]$script:active[$key]
        if(!(Test-Path -LiteralPath $path)){continue}
        $f=$null
        try {
            $f=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
            if($f.Length -le $offset){continue}
            $start=[math]::Max($offset,$f.Length-16384)
            $null=$f.Seek($start,[System.IO.SeekOrigin]::Begin)
            $buf=New-Object byte[] ([int]($f.Length-$start));$n=$f.Read($buf,0,$buf.Length)
            $script:active[$key]=$start+$n
            $col=$fg;if($stream -eq 'Err'){$col=$muted}
            if($start -gt $offset){Add-Log "`r`n[Live preview shortened; full log saved.]`r`n" $muted}
            Add-Log ([System.Text.Encoding]::UTF8.GetString($buf,0,$n)) $col
        } catch {} finally {if($f){$f.Dispose()}}
    }
}
function Save-Report {
    if(!$script:runDir){return}
    $brief=New-Object System.Text.StringBuilder; $full=New-Object System.Text.StringBuilder
    $depthRequested = $script:machine.DepthRequested -or $script:machine.ManualDepth
    $header=@(
        "VIREX TEST STUDIO $studioVersion | LOCAL VERIFICATION"
        ('Status: '+$script:runState)
        $(if($script:runState -eq 'RUNNER_ERROR'){'Runner verification incomplete; Rust output is provisional, not a confirmed PASS or FAIL.'})
        ('Target: '+$script:runPreset.Name)
        $(if ($script:runPreset.Directory) {
            'Local workspace: ' + $script:runPreset.Directory
        } else {
            if ($script:runPreset.Origin) { 'Repository: ' + $script:runPreset.Origin }
            if ($script:runPreset.Sha) { 'Pinned commit: ' + $script:runPreset.Sha } else { 'Commit: not verified' }
            'Branch: ' + $script:runPreset.Branch
            if ($script:runPreset.SourceUrl) { 'Source URL: ' + $script:runPreset.SourceUrl }
        })
        ('Started: '+$script:started.ToString('o'))
        ('CPU: '+$script:machine.CPU)
        ('GPU / driver: '+$script:machine.GPU)
        ('OS: '+$script:machine.OS)
        ('WARP requested: '+$script:machine.Warp)
        ('Windows build detected: '+$script:machine.WindowsBuild)
        ('Agility SDK requested: '+$script:machine.AgilityRequested)
        ('Agility SDK staged (files present): '+$script:machine.AgilityStaged)
        ('D3D12 depth bounds requested: '+$depthRequested)
        $(if($depthRequested){'D3D12 hardware verification requires a native adapter and successful depth readbacks recorded by the test.'})
        ('Cargo target directory: '+$script:machine.TargetDirectory)
        ('Free space at start (GiB): '+$script:machine.Storage)
        ('System-wide hardware samples: '+$script:monitorSamples)
        $(foreach($key in @('CPU','RAM','GPU','VRAM')) { if($monitorPeak.ContainsKey($key)){ 'Sampled peak '+$key+': '+$monitorPeak[$key]+$(if($key -eq 'VRAM'){' GiB'}else{' %'})} })
        ('Execution mode: '+$(if($script:machine.AutoMode){'AUTO'}else{'MANUAL'}))
        $(if($script:machine.AutoMode){'Auto profile: '+$script:machine.AutoProfile; foreach($stage in (Get-AutoPlan $script:machine.DepthRequested)){ $number=[string]$stage.Substring(1,1); $stage+' | '+$(if($levelResults.ContainsKey($number)){$levelResults[$number]}else{'NOT RUN'}) }})
        $(if($script:machine.ManualCrate){'Manual crate: '+$script:machine.ManualCrate;'Exact test: '+$script:machine.ManualTest;'Serial: '+$script:machine.ManualSerial;'Release build: '+$script:machine.ManualRelease;'Ignored only: '+$script:machine.ManualIgnored})
        $(if($script:machine.CrashPackage){'Crash package: '+$script:machine.CrashPackage;'Original crash exit: '+$script:machine.CrashOriginalExit;'Crash diagnostic: '+$script:machine.CrashResult; if($script:machine.CrashCandidate){'Suspected serial test: '+$script:machine.CrashCandidate};'Original failure remains FAIL even if a retry passes.'})
        ('Rust test repetitions requested: '+$script:machine.Repeat)
        'Synthetic benchmarks are not game FPS. Validation runner does not upload reports.'
        ''
    ) -join "`r`n"
    $null=$brief.AppendLine($header); $null=$full.AppendLine($header)
    foreach($step in $script:steps){
        $exitText=if($null -eq $step.Exit){'UNAVAILABLE'}else{[string]$step.Exit}; $head="[$($step.Status)] $($step.Name) | exit=$exitText | $($step.Seconds)s`r`n$($step.Command)"; if($step.Error){$head+="`r`nRunner detail: $($step.Error)"}
        if ($step.GpuExecution) { $head += [Environment]::NewLine + 'GPU execution: ' + $step.GpuExecution }
        if ($step.GpuEvidence) { $head += [Environment]::NewLine + $step.GpuEvidence }
        $null = $brief.AppendLine($head)
        $null = $full.AppendLine($head)
        $out=Read-Shared $step.Out; $err=Read-Shared $step.Err
        $null=$full.AppendLine("--- stdout ---`r`n$out`r`n--- stderr ---`r`n$err")
        $lines=@(($out+"`n"+$err) -split '\r?\n' | Where-Object {$_ -match 'test result:|\bPASS:|^density=|^changed=|^case=|^kind=|^mode=|error\[|error:|warning:|panicked at|FAILED|Finished|^rustc |^cargo |^git version|^[a-f0-9]{40}$|^AVX2 supported|D3D12 Agility SDK|depth_bounds_pipeline_loads_and_filters_draws|no host depth bounds support|no PC dxc.exe'})
        if($step.Kind -like 'diag*'){$lines+=@(($out+[Environment]::NewLine+$err) -split '\r?\n' | Select-Object -Last 60)}
        if($step.Status -ne 'PASS'){$lines+=@(($out+"`n"+$err) -split '\r?\n' | Select-Object -Last 35)}
        foreach($line in $lines){$null=$brief.AppendLine($line)}; $null=$brief.AppendLine('')
    }
    $benchmarkRows = @(foreach ($step in $script:steps) { if ($step.Benchmarks) { $step.Benchmarks } })
    $benchmarkSummaries = @(Get-BenchmarkSummaries $script:steps)
    $benchmarkTable = @(Format-BenchmarkSummaryTable $benchmarkSummaries) + @(Format-BenchmarkTable $benchmarkRows)
    if ($benchmarkTable.Count) {
        $table = Redact ($benchmarkTable -join [Environment]::NewLine)
        $null = $brief.AppendLine($table)
        $null = $full.AppendLine($table)
    }
    $short=Redact $brief.ToString(); $all=Redact $full.ToString()
    $reportBox.Text=if($short.Length -gt 200000){$short.Substring(0,200000)+"`r`n[Preview shortened; full report saved.]"}else{$short}
    [System.IO.File]::WriteAllText((Join-Path $runDir 'REPORT.txt'),$short,[System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText((Join-Path $runDir 'FULL-LOG.txt'),$all,[System.Text.Encoding]::UTF8)
    $meta=@{state=$script:runState;preset=$script:runPreset;started=$script:started.ToString('o');hardware=$script:machine;steps=@($script:steps.ToArray())}
    $meta | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $runDir 'run.json') -Encoding UTF8
    if ($benchmarkRows.Count -gt 0) {
        $benchmarkRows | Export-Csv -LiteralPath (Join-Path $runDir 'benchmark.csv') -NoTypeInformation -Encoding UTF8
        ConvertTo-Json -InputObject $benchmarkRows -Depth 4 | Set-Content -LiteralPath (Join-Path $runDir 'benchmark.json') -Encoding UTF8
        $table | Set-Content -LiteralPath (Join-Path $runDir 'benchmark.md') -Encoding UTF8
        if ($benchmarkSummaries.Count) {
            foreach ($summary in $benchmarkSummaries) { $summary.command = Redact $summary.command }
            ConvertTo-Json -InputObject $benchmarkSummaries -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'benchmark-summary.json') -Encoding UTF8
        }
    }
}
function Set-Idle([string]$state) {
    if($script:diagnosticActive){
        if($state -eq 'CANCELLED'){$script:machine.CrashResult+=' | DIAGNOSTICS CANCELLED'}
        elseif($state -eq 'RUNNER_ERROR'){$script:machine.CrashResult+=' | DIAGNOSTICS INCOMPLETE'}
        $state='FAIL'
    }
    $progress.Style='Continuous'
    $script:runState=$state; $status.Text=$state; $status.ForeColor=Get-ValidationStatusColor $state; $script:queue.Clear(); $script:proc=$null; $script:active=$null; $runButton.Enabled=(-not $script:unsafeState); $stopButton.Enabled=$false; $combo.Enabled=$true; $updateButton.Enabled=!$script:unsafeState; $openSource.Enabled=$true
    foreach($c in @($ckCheck,$ckTest,$ckClippy,$ckFull,$ckWarp,$ckRepeat)){$c.Enabled=$true}; if (Test-WorkspaceTarget) {
        $ckFull.Enabled=$false; $ckWarp.Enabled=$false; $ckBench.Enabled=$false
    } else { $ckBench.Enabled=[bool]$combo.SelectedItem.Preset.Bench }
    $ckAgility.Enabled=(Test-WorkspaceTarget) -and !(Test-LocalTarget); $ckDepth.Enabled=$ckAgility.Enabled
    if($script:machine.AutoMode -and !$script:diagnosticActive -and $steps.Count -gt 0 -and $state -in @('FAIL','RUNNER_ERROR','CANCELLED')){
        $level=Get-StepLevel $steps[$steps.Count-1]
        try{Write-AutoCheckpoint $level $state}catch{Add-Log ('Checkpoint save failed: '+$_.Exception.Message) $red}
    }
    Update-ExecutionMode
    Update-StudioOverview
    $labState.Text="$($script:machine.AutoProfile) | $state"
    if($script:machine.AutoMode -and !$script:closeAfterStop){$tabs.SelectedTab=$summaryTab}
    $copyButton.Enabled=$false; $copyFullButton.Enabled=$false
    try {Save-Report; $copyButton.Enabled=$true; $copyFullButton.Enabled=$true} catch {Add-Log ("`r`nREPORT ERROR: "+$_.Exception.Message+"`r`n") $red; if($reportBox.Text){$copyButton.Enabled=$true} }; Update-StorageDisplay
    $script:diagnosticActive=$false
    Add-Log "`r`n=== $state ===`r`n" $status.ForeColor
    if($script:closeAfterStop -and !$script:unsafeState){$script:closeAfterStop=$false;$form.Close()}
}
function Start-Next {
    if($script:cancelled){Set-Idle 'CANCELLED';return}
    if ($script:queue.Count -eq 0) {
        if ($script:diagnosticActive) { Set-Idle 'FAIL' }
        else { Set-Idle (Get-CompletedValidationStatus $script:steps) }
        return
    }
    $script:exitSeenAt=$null; $script:stopAt=$null
    $s=$script:queue.Dequeue(); $num=$script:steps.Count+1; $s.Out=Join-Path $runDir ('{0:D2}-stdout.log' -f $num); $s.Err=Join-Path $runDir ('{0:D2}-stderr.log' -f $num); $s.OutBytes=0; $s.ErrBytes=0; $s.Start=[DateTime]::UtcNow; $s.Command=$s.Exe+' '+$s.Args; $s.Status='RUNNING'; $s.Exit=$null; $s.Error=''; $s.Seconds=0; $script:active=$s; $script:steps.Add($s); $progressText.Text="$num / $($progress.Maximum)"; Add-Log "`r`n[$num] $($s.Name)`r`n> $($s.Command)`r`n" $cyan
    if($script:diagnosticActive){$labState.Text=$s.Name; $status.Text='DIAGNOSTICS'}elseif($script:machine.AutoMode){$labState.Text='L'+(Get-StepLevel $s)+' | '+$s.Name; $status.Text='AUTO L'+(Get-StepLevel $s); Update-LabProgress (Get-StepLevel $s)}
    $progress.Style='Marquee'
    Update-StudioOverview
    try {
        if($script:machine.AutoMode){$null=Get-StorageInfo $script:machine.TargetDirectory}
        # Child processes inherit only this process's selected WARP setting.
        $script:proc=[VirexChild]::Start($s.Exe,$s.Args,$workDir,$s.Out,$s.Err)
    } catch { $s.Status='RUNNER_ERROR'; $s.Exit=$null; $s.Error=$_.Exception.Message; $s.Seconds=0; Add-Log ($s.Error+"`r`n") $red; Set-Idle 'RUNNER_ERROR' }
}
$script:timer=New-Object System.Windows.Forms.Timer; $timer.Interval=400
$timer.Add_Tick({
    if(!$script:proc){return}
    try {
        Update-Tail
        $now=[DateTime]::UtcNow
        $s=$script:active
        if($s.Kind -eq 'runnerstop' -and !$script:stopAt -and ($now-$s.Start).TotalSeconds -ge 1){
            $script:stopAt=$now; $script:proc.RequestStop()
        }
        if($script:diagnosticActive -and !$script:stopAt -and !$script:proc.HasExited -and ($now-$s.Start).TotalSeconds -gt $(if($s.Kind -eq 'diagevent'){30}else{300})){
            $s.DiagnosticTimeout=$true; $script:stopAt=$now; $script:proc.RequestStop()
            Add-Log ("Diagnostic time limit reached; stopping only the active process tree."+[Environment]::NewLine) $red
        }
        if($script:proc.StopError){throw ('Stop failed: '+$script:proc.StopError)}
        if($script:proc.HasExited -and !$script:exitSeenAt){$script:exitSeenAt=$now}
        if(!$script:proc.TreeExited -or !$script:proc.OutputComplete){
            # Cargo can leave an MSVC symbol server alive after its own exit. Clean up only this step's job.
            if (!$script:stopAt -and $script:exitSeenAt -and ($now-$script:exitSeenAt).TotalSeconds -ge 2 -and
                [IO.Path]::GetFileName($s.Exe) -eq 'cargo.exe' -and !$script:proc.TreeExited) {
                $script:stopAt=$now
                $script:proc.RequestStop()
                Add-Log "A Cargo kilépett. A hozzá tartozó háttérfolyamatok lezárása.$([Environment]::NewLine)" $muted
            }
            if($script:stopAt -and ($now-$script:stopAt).TotalSeconds -ge 12){throw 'Termination or output drain not confirmed in 12 seconds.'}
            if(!$script:stopAt -and $script:exitSeenAt -and ($now-$script:exitSeenAt).TotalSeconds -ge 8){throw 'Root process exited but descendants or redirected streams did not finish.'}
            return
        }
        Update-Tail; $s.Exit=$script:proc.ExitCode; $s.Seconds=[math]::Round(([DateTime]::UtcNow-$s.Start).TotalSeconds,2); $out=Read-Shared $s.Out; $err=Read-Shared $s.Err
        if($null -eq $s.Exit){throw 'Native process exit code unavailable; result cannot be verified.'}
        if($script:proc.CaptureError){throw ('Log capture failed: '+$script:proc.CaptureError)}
        $valid=($s.Exit -eq 0 -and !$s.DiagnosticTimeout)
        if($s.Kind -eq 'runner0' -or $s.Kind -eq 'runner7'){
            $expected=if($s.Kind -eq 'runner0'){0}else{7}
            $valid=($s.Exit -eq $expected -and $out -match 'VIREX_STDOUT' -and $err -match 'VIREX_STDERR')
            if(!$valid){$s.Error="Runner self-test expected exit $expected and both output markers."}
        }
        if($s.Kind -eq 'runnerstop'){ $valid=($null -ne $script:stopAt -and $s.Exit -ne 0 -and $out -match 'VIREX_STOP_READY'); if(!$valid){$s.Error='Cancellation self-test did not confirm a stopped process.'} }
        if($valid -and $s.Kind -eq 'remote'){$valid=($out.Trim() -eq $script:expectedOrigin)}
        if($valid -and $s.Kind -eq 'clean'){$valid=([string]::IsNullOrWhiteSpace($out))}
        if($valid -and $s.Kind -eq 'head'){$valid=($out.Trim() -eq $script:runPreset.Sha)}
        if ($valid -and $s.Kind -eq 'workspacehead') {
            $valid=($out.Trim() -cmatch '^[0-9a-f]{40}$') -and (Test-Path -LiteralPath (Join-Path $workDir 'Cargo.toml') -PathType Leaf)
            if ($script:runPreset.ExpectedSha -and $out.Trim() -cne $script:runPreset.ExpectedSha) { $valid=$false; $s.Error='A tényleges commit eltér a kért SHA-tól.' }
            if ($valid) {
                $script:runPreset.Sha=$out.Trim()
                $revision.Text="$($runPreset.Name)$([Environment]::NewLine)$($runPreset.Sha.Substring(0,12))"
                $tip.SetToolTip($revision,$runPreset.Sha)
                try { Add-WorkspaceCargoSteps $script:workspaceCargo $workDir; $progress.Maximum=$script:steps.Count+$script:queue.Count } catch { $valid=$false; $s.Error=$_.Exception.Message }
            } elseif (!$s.Error) { $s.Error='Hiányzik a gyökérből a Cargo.toml, vagy érvénytelen a commit.' }
        }
        if($valid -and $s.Kind -eq 'agility') {
            $valid=Test-StagedAgility $env:CARGO_TARGET_DIR
            $script:machine.AgilityStaged=$valid
            if(!$valid){$s.Error='Agility parancs sikeres, de a szükséges debug/D3D12 DLL-ek hiányoznak.'}
        }
        if ($s.Kind -eq 'depthtest') {
            $s.GpuExecution = 'NOT VERIFIED'
            if ($valid -and !$script:cancelled) {
                $depthResult = Get-DepthValidation $out $err
                $valid = $depthResult.Completed
                $s.GpuExecution = $depthResult.GpuExecution
                $s.GpuEvidence = $depthResult.Evidence
                if (!$valid) { $s.Error = 'A kiválasztott D3D12-teszt futása nem igazolható.' }
                elseif ($depthResult.SkipReason) { $s.Error = $depthResult.SkipReason }
            }
        }
        if ($s.Kind -in @('bench','cargo_bench','tests','depthtest')) {
            $s.Benchmarks = @(Get-BenchmarkStepRows $out $err)
            Add-BenchmarkRows $s.Benchmarks
            $hasPassMarker = $out -match 'PASS:' -or $err -match 'PASS:'
            if ($valid -and $s.Kind -eq 'bench') {
                $valid = $hasPassMarker -and ($s.Benchmarks.Count -gt 0)
            }
            if ($valid -and $s.Kind -eq 'cargo_bench') {
                $valid = $hasPassMarker -and ($out -match 'test result: ok\. 1 passed; 0 failed') -and
                    ($s.Benchmarks.Count -eq $script:runPreset.BenchCount)
            }
        }
        $storageFailure=(!$valid -and (($out+"`n"+$err) -match '(?i)no space (left )?on device|not enough space on (the )?disk|disk full|Nincs elég hely a lemezen'))
        if($storageFailure){$s.Error='Tárhelyhiba: a fordítási eredmény nem értékelhető. Szabadíts fel helyet a Tárhely / hardver fülön.'}
        $s.Status = if ($script:cancelled) { 'CANCELLED' }
            elseif ($storageFailure) { 'RUNNER_ERROR' }
            elseif (!$valid) { 'FAIL' }
            elseif ($s.GpuExecution -eq 'SKIPPED') { 'SKIPPED' }
            else { 'PASS' }
        if(!$valid -and $s.Exit -eq 0 -and !$s.Error){$s.Error="Validation gate failed ($($s.Kind))"; Add-Log "`r`nValidation gate failed ($($s.Kind)): inspect stdout before continuing.`r`n" $red}
        $script:proc.Dispose();$script:proc=$null;$script:active=$null; $progress.Value=[math]::Min($script:steps.Count,$progress.Maximum)
        Update-StudioOverview
        $stepResult = if ($s.Status -eq 'PASS') { Get-CompletedValidationStatus @($s) } else { $s.Status }
        $col = Get-ValidationStatusColor $stepResult
        Add-Log "`r`n$stepResult | exit $($s.Exit) | $($s.Seconds)s`r`n" $col
        if($script:cancelled){Set-Idle 'CANCELLED'}
        elseif($storageFailure){Set-Idle 'RUNNER_ERROR'}
        elseif($script:diagnosticActive){if($s.DiagnosticTimeout){$s.Error='Diagnostic time limit reached.';$script:machine.CrashResult+=' | DIAGNOSTIC TIMEOUT';Set-Idle 'FAIL'}else{Complete-CrashStep $s $out $err $valid; Start-Next}}
        elseif(!$valid){if(Start-CrashDiagnostics $s $out $err){Start-Next}else{Set-Idle 'FAIL'}}
        else{if($script:machine.AutoMode -and ($script:queue.Count -eq 0 -or (Get-StepLevel $script:queue.Peek()) -ne (Get-StepLevel $s))){Write-AutoCheckpoint (Get-StepLevel $s) 'PASS'};Start-Next}
    } catch {
        $message=$_.Exception.Message
        Add-Log ("`r`nRunner error: "+$message+"`r`n") $red
        if($script:active){$script:active.Status='RUNNER_ERROR';$script:active.Error=$message;$script:active.Seconds=[math]::Round(([DateTime]::UtcNow-$script:active.Start).TotalSeconds,2)}
        if($script:proc){
            # Closing the job requests termination; do not report cancellation as verified.
            $script:unsafeState=$true
            try{$script:proc.RequestStop();$script:proc.Dispose()}catch{}
            Add-Log "`r`nProcess completion unconfirmed. Check Task Manager and restart Studio before another run.`r`n" $red
        }
        Set-Idle 'RUNNER_ERROR'
    }
})
function Stop-Run {
    $script:cancelled=$true; $script:queue.Clear(); $stopButton.Enabled=$false
    $status.Text='STOPPING';$status.ForeColor=$muted
    if(!$script:stopAt){$script:stopAt=[DateTime]::UtcNow}
    Add-Log "`r`nSTOP requested; waiting for process tree and both log streams.`r`n" $cyan
    if($script:proc){$script:proc.RequestStop()}else{Set-Idle 'CANCELLED'}
}
. (Join-Path $appDir 'Repository.ps1')
. (Join-Path $appDir 'Targets.ps1')
Initialize-StudioNavigation
$folderButton.Add_Click({$dir=$reports;if($script:runDir){$dir=$script:runDir}; Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')})
$copyButton.Add_Click({try{$reportPath=Join-Path $runDir 'REPORT.txt'; $content=if(Test-Path -LiteralPath $reportPath -PathType Leaf){$saved=[IO.File]::ReadAllText($reportPath);if($saved){$saved}else{$reportBox.Text}}else{$reportBox.Text};[System.Windows.Forms.Clipboard]::SetText($content); $foot.Text='A riport a vágólapra került.'}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message)|Out-Null}})
$copyFullButton.Add_Click({try{[System.Windows.Forms.Clipboard]::SetText([System.IO.File]::ReadAllText((Join-Path $runDir 'FULL-LOG.txt')));$foot.Text='A teljes napló a vágólapra került.'}catch{[System.Windows.Forms.MessageBox]::Show($_.Exception.Message)|Out-Null}})
$stopButton.Add_Click({Stop-Run})
function Start-StudioRun {
    if (Test-StorageBusy) { return }
    try {
        $isLocal = Test-LocalTarget
        $isWorkspace = Test-WorkspaceTarget
        $auto=$modeSwitch.Checked -and $isWorkspace
        $d3d=$auto -and !$isLocal -and ($autoProfile.SelectedIndex -eq 1)
        $agility=if($auto){$d3d}else{$ckAgility.Enabled -and $ckAgility.Checked}
        $depth=if($auto){$d3d}else{$ckDepth.Enabled -and $ckDepth.Checked}
        $manualPackage='';$manualName='';$manualOne=$false;$release=$false;$ignored=$false;$manualArgs=''
        if(!$auto -and $isWorkspace){
            $manualPackage=$manualCrate.Text.Trim();$manualName=$manualTest.Text.Trim();$manualOne=$manualSerial.Checked
            $release=$manualRelease.Checked;$ignored=$manualIgnored.Checked
            if($manualPackage){if(!$ckTest.Checked){throw 'A célzott crate futtatásához jelöld be a teszteket.'};$manualArgs=Get-ManualTestArgs $manualPackage $manualName $manualOne '' $release $ignored}
            elseif($manualName -or $manualOne -or $release -or $ignored){throw 'A pontos teszthez / soros módhoz crate név szükséges.'}
        }
        $script:expectedOrigin=$origin
        if (!$auto -and !$ckCheck.Checked -and !$ckTest.Checked -and !$ckClippy.Checked -and !($ckFull.Enabled -and $ckFull.Checked) -and !($ckBench.Checked -and $ckBench.Enabled) -and !($ckDepth.Checked -and $ckDepth.Enabled)) { throw 'Válassz legalább egy ellenőrzést.' }
        if ($isLocal) {
            if (!$localProject -or !(Test-Path -LiteralPath (Join-Path $localProject 'Cargo.toml') -PathType Leaf)) { throw 'Válassz érvényes Cargo-projektmappát.' }
            $p = @{Name=(Split-Path -Leaf $localProject); Directory=$localProject}
            $runLabel = 'local'
            $detail = "Mappa: $localProject"
            $script:workDir = $localProject
        } elseif ($isWorkspace) {
            $target=Get-SelectedRepository
            if (!$target) { throw 'Először add meg a GitHub-repó címét.' }
            $p=$target.Clone()
            $runLabel='github'
            $detail="$($p.Origin)   [$($p.Branch)]"
            $script:expectedOrigin=$p.Origin
            $script:workDir=Join-Path $root ('repositories\'+$p.CacheId)
        } else {
            $p = $combo.SelectedItem.Preset
            $runLabel = $p.Sha.Substring(0,8)
            $detail = "Commit: $($p.Sha)"
            $script:workDir = $repo
        }
        $confirm = "Futtatod a kiválasztott ellenőrzéseket? A projekt és a függőségei tetszőleges kódot futtathatnak a Windows-fiókod jogosultságaival. A Studio nem biztonsági sandbox. Csak megbízható forrást futtass.$([Environment]::NewLine)$([Environment]::NewLine)$($p.Name)$([Environment]::NewLine)$detail"
        if($auto){$confirm += [Environment]::NewLine+[Environment]::NewLine+'AUTO: '+((Get-AutoPlan $d3d) -join '; ')+' | Access violation esetén automatikus, korlátozott diagnosztikai újrateszt; az eredeti FAIL megmarad.'}
        if($manualPackage){$confirm += [Environment]::NewLine+'MANUAL: '+$manualArgs}
        if ($agility) { $confirm += "`r`n`r`nAgility SDK: a kiválasztott revízió saját cargo xtask agility parancsa fut, hálózati letöltés lehetséges. Elkülönített buildcache." }
        $plannedTarget=Get-StudioTargetDirectory $isLocal $isWorkspace $p $agility
        $spacePath=if($plannedTarget){if([IO.Path]::IsPathRooted($plannedTarget)){$plannedTarget}else{Join-Path $workDir $plannedTarget}}else{Join-Path $workDir 'target'}
        $space=Get-StorageInfo $spacePath
        $confirm += "`r`n`r`nCargo cache: $spacePath`r`nSzabad hely: $([math]::Round($space.Cache/1GB,1)) GiB."
        if($space.Cache -lt 20GB){$confirm += "`r`nFigyelem: 20 GiB alatt a nagy Rust-build elfogyaszthatja a tárhelyet. Ez csak előzetes ellenőrzés."}
        if (!(Confirm-StudioRun $confirm)) { return }
        $cargo=Tool-Path 'cargo.exe'
        if (!$isLocal) { $git=Tool-Path 'git.exe' }
        if (!$isWorkspace) { $rust=Tool-Path 'rustc.exe' }
        $script:workspaceCargo=$cargo
        $script:runPreset=$p; $script:started=Get-Date
        $script:runDir=Join-Path $reports ($script:started.ToString('yyyyMMdd-HHmmss-fff')+'-'+$runLabel)
        $null=New-Item -ItemType Directory -Path $runDir
        $script:machine=@{CPU='unknown';GPU='unknown';OS='unknown';Warp=($ckWarp.Checked -and !$isWorkspace);Repeat=1;WindowsBuild=$windowsBuild;AgilityRequested=$agility;AgilityStaged=$false;DepthRequested=$depth;AutoMode=$auto;AutoProfile=$(if($auto){[string]$autoProfile.SelectedItem}else{'MANUAL'})};if($d3d -or (!$auto -and $ckRepeat.Checked)){$script:machine.Repeat=3}; try{$script:machine.CPU=((Get-CimInstance Win32_Processor | ForEach-Object {$_.Name}) -join '; ');$script:machine.GPU=((Get-CimInstance Win32_VideoController | ForEach-Object {"$($_.Name) ($($_.DriverVersion))"}) -join '; ');$os=Get-CimInstance Win32_OperatingSystem;$script:machine.OS="$($os.Caption) $($os.Version) build $($os.BuildNumber)"}catch{}
        $script:machine.ManualDepth = $manualPackage -ceq 'victory-gpu' -and $manualName -ceq $script:depthTestName
        $script:machine.ManualCrate=$manualPackage;$script:machine.ManualTest=$manualName;$script:machine.ManualSerial=$manualOne;$script:machine.ManualRelease=$release;$script:machine.ManualIgnored=$ignored;$script:diagnosticActive=$false
        $script:machine.TargetDirectory=$spacePath; $script:machine.Storage=('cache={0:N1}; reports={1:N1}; temp={2:N1}; cargo={3:N1}' -f ($space.Cache/1GB),($space.Reports/1GB),($space.Temp/1GB),($space.Cargo/1GB)); $script:monitorSamples=0; $script:monitorPeak=@{}; $script:levelResults=@{}
        $script:queue.Clear(); $script:steps.Clear(); $terminal.Clear(); $reportBox.Clear(); $grid.Rows.Clear(); $chartTitle.Text='Az összehasonlításhoz válassz egy mérési sort.'; foreach($bar in $chartBars){$bar.Width=0}; foreach($v in $chartValues){$v.Text='-'}; $script:cancelled=$false
        $env:CARGO_TERM_COLOR='never';$env:RUST_BACKTRACE='1';$env:GIT_TERMINAL_PROMPT='0';$env:CARGO_TARGET_DIR=$plannedTarget
        if($ckWarp.Checked -and !$isWorkspace){$env:VICTORY_D3D12_WARP='1';$env:VICTORY_WARP='1'}else{Remove-Item Env:VICTORY_D3D12_WARP,Env:VICTORY_WARP -ErrorAction SilentlyContinue}
        $cmd=Join-Path $env:SystemRoot 'System32\cmd.exe'
        Add-Step 'Runner self-test (expected exit 0)' $cmd '/d /c "echo VIREX_STDOUT & echo VIREX_STDERR 1>&2 & exit /b 0"' 'runner0'
        Add-Step 'Runner self-test (expected exit 7)' $cmd '/d /c "echo VIREX_STDOUT & echo VIREX_STDERR 1>&2 & exit /b 7"' 'runner7'
        Add-Step 'Runner self-test (stop child tree)' $cmd '/d /c "echo VIREX_STOP_READY & ping -n 30 127.0.0.1 >nul"' 'runnerstop'
        if ($isLocal) {
            Add-WorkspaceCargoSteps $cargo $workDir
        } elseif ($isWorkspace) {
            Add-RepositorySteps $p $git
        } else {
            if(!(Test-Path -LiteralPath (Join-Path $repo '.git'))){if(@(Get-ChildItem -LiteralPath $repo -Force).Count -ne 0){throw "Test clone directory is not empty: $repo"};Add-Step 'Clone dedicated test repository' $git "clone -- $origin ."}
            Add-Step 'Verify repository origin' $git 'remote get-url origin' 'remote'
            Add-Step 'Check repository is clean' $git 'status --porcelain --untracked-files=normal' 'clean'
            Add-Step 'Fetch selected branch' $git "fetch --no-tags origin $($p.Branch)"
            Add-Step 'Checkout pinned revision' $git "switch --detach $($p.Sha)"
            Add-Step 'Verify exact revision' $git 'rev-parse HEAD' 'head'
            Add-Step 'Rust version' $rust '--version'; Add-Step 'Cargo version' $cargo '--version'; Add-Step 'Git version' $git '--version'
            $features='';if($p.Features){$features=' --features diagnostics'}
            if($ckCheck.Checked){Add-Step 'Workspace check' $cargo 'check --workspace --locked'}
            if($ckTest.Checked){$filter='';if($p.Filter){$filter=' '+$p.Filter};for($pass=1;$pass -le $script:machine.Repeat;$pass++){Add-Step "Targeted Rust tests ($pass/$($script:machine.Repeat))" $cargo "test -p $($p.Crate) --locked$features$filter -- --nocapture" 'tests'}}
            if($ckClippy.Checked){Add-Step 'Clippy / warnings denied' $cargo "clippy -p $($p.Crate) --locked --all-targets$features -- -D warnings"}
            if($ckFull.Checked){for($pass=1;$pass -le $script:machine.Repeat;$pass++){Add-Step "Full crate tests ($pass/$($script:machine.Repeat))" $cargo "test -p $($p.Crate) --locked$features" 'tests'}}
            if($ckBench.Checked -and $ckBench.Enabled){
                if($p.Bench -eq 'cargo'){
                    Add-Step 'Execute release benchmark' $cargo "test --release -p $($p.Crate) --locked$features $($p.BenchFilter) -- --ignored --nocapture" 'cargo_bench'
                }else{
                $exe=Join-Path $runDir 'benchmark.exe'; $src=''
                switch($p.Bench){
                    'adaptive' {$src=Join-Path $runDir 'adaptive_ranges.rs'; $source=[System.IO.File]::ReadAllText((Join-Path $appDir 'adaptive_ranges.rs.template')); $module=(Join-Path $repo 'crates\victory-gpu\src\memory\precise_ranges.rs').Replace('\','/'); [System.IO.File]::WriteAllText($src,$source.Replace('__PRECISE_RANGES_PATH__',$module),(New-Object System.Text.UTF8Encoding($false)))}
                    'precise' {$src=Join-Path $repo 'benchmarks\precise_ranges.rs'}
                    'shadow' {$src=Join-Path $repo 'benchmarks\shadow_merge.rs'}
                    'page' {$src=Join-Path $repo 'benchmarks\page_guard.rs'}
                }
                if(!$src){throw 'Unsupported benchmark preset'}
                Add-Step 'Compile optimized benchmark' $rust ('--edition=2024 -O "'+$src+'" -o "'+$exe+'"')
                Add-Step 'Execute synthetic benchmark' $exe '' 'bench'
                }
            }
        }
        $updateButton.Enabled=$false;$openSource.Enabled=$false;$script:runState='RUNNING';$status.Text='Futtatás…';$status.ForeColor=$cyan;$progress.Maximum=$script:queue.Count;$progress.Value=0;$combo.Enabled=$false;$runButton.Enabled=$false;$stopButton.Enabled=$true;$copyButton.Enabled=$false;$copyFullButton.Enabled=$false
        foreach($c in @($ckCheck,$ckTest,$ckClippy,$ckFull,$ckWarp,$ckBench,$ckRepeat,$ckAgility,$ckDepth)){$c.Enabled=$false};Update-StorageDisplay;Update-ExecutionMode;$tabs.SelectedTab=$overviewTab;Add-Log "VIREX local validation | $($p.Name)`r`n$detail`r`n" $cyan;Start-Next
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Unable to start')|Out-Null; if($script:runState -eq 'RUNNING'){Set-Idle 'FAIL'} }
}
$runButton.Add_Click({Start-StudioRun})
$form.Add_FormClosing({param($sender,$e)
    if($script:cacheWorker){$e.Cancel=$true; $foot.Text='A cache művelet még fut.'; return}
    if($script:runState -eq 'RUNNING'){
        $e.Cancel=$true
        if($script:closeAfterStop){return}
        if([System.Windows.Forms.MessageBox]::Show('Stop current test and close?','VIREX','YesNo','Warning') -ne 'Yes'){return}
        $script:closeAfterStop=$true;Stop-Run
    }
})
$form.Add_Shown({
    $tabs.SelectedTab=$overviewTab
    Update-StudioOverview
    Add-Log "VIREX Test Studio  $studioVersion$([Environment]::NewLine)" $cyan
    Add-Log "A futtatás után itt követheted a parancsokat és a kimenetüket.$([Environment]::NewLine)" $muted
    $combo.Select()
})
$timer.Start()
try{[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();$storageTimer.Stop();$storageTimer.Dispose();if($monitorWorker){$null=$monitorWorker.BeginStop($null,$null)};$updateTimer.Stop();$updateTimer.Dispose();if ($updateWorker) { $null=$updateWorker.BeginStop($null,$null) };if($script:proc){try{$script:proc.Dispose()}catch{}};$script:mutex.ReleaseMutex();$script:mutex.Dispose();$form.Dispose()}

if ($script:pendingSetup) {
    try { Start-VerifiedSetup $script:pendingSetup $script:updateOffer.Hash }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Telepítési hiba') | Out-Null }
}
