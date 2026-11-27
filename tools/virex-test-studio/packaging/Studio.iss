#ifndef StudioVersion
  #error Supply StudioVersion with packaging\Build.ps1
#endif

[Setup]
#ifdef StudioPreview
AppId={{C648126E-595A-4762-A5B8-647224507D86}
AppName=VIREX Test Studio Preview
DefaultDirName={%LOCALAPPDATA|{localappdata}}\Programs\VIREX Test Studio Preview
DefaultGroupName=VIREX Test Studio Preview
OutputBaseFilename=VIREX-Test-Studio-{#StudioVersion}-Preview-Setup
Uninstallable=not IsPortablePreview
#else
AppId={{E5BEB288-90E3-4F5E-A706-16B5EF731077}
AppName=VIREX Test Studio
DefaultDirName={localappdata}\Programs\VIREX Test Studio
DefaultGroupName=VIREX Test Studio
OutputBaseFilename=VIREX-Test-Studio-{#StudioVersion}-Setup
#endif
AppVersion={#StudioVersion}
VersionInfoVersion={#StudioVersion}.0
AppPublisher=VIREX
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\assets\studio.ico
UninstallDisplayIcon={app}\VIREX-Test-Studio.exe
OutputDir=..\artifacts\installer
Compression=lzma2
SolidCompression=yes
AppMutex=Local\VIREX-Test-Studio-v1
CloseApplications=no

[Languages]
Name: "hu"; MessagesFile: "compiler:Languages\Hungarian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
#ifdef StudioPreview
Source: "..\packaging\PREVIEW"; DestDir: "{app}"; Flags: ignoreversion
#endif
Source: "..\artifacts\launcher\VIREX-Test-Studio.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\VIREX-Test-Studio.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Desktop.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Benchmark.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Repository.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\studio.png"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\Targets.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\AutoBridge.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\BatchQueue.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\BatchImport.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\VIREX_BatchImport.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\VIREX_AutoBridge.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\StudioUpdate.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\DesktopUpdate.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\AI-Review.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\ai_review.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\START-AI-REVIEW.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\adaptive_ranges.rs.template"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\studio.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
#ifdef StudioPreview
Name: "{group}\VIREX Test Studio Preview"; Filename: "{app}\VIREX-Test-Studio.exe"; Check: not IsPortablePreview
Name: "{userdesktop}\VIREX Test Studio Preview"; Filename: "{app}\VIREX-Test-Studio.exe"; Tasks: desktopicon; Check: not IsPortablePreview
#else
Name: "{group}\VIREX Test Studio"; Filename: "{app}\VIREX-Test-Studio.exe"
Name: "{userdesktop}\VIREX Test Studio"; Filename: "{app}\VIREX-Test-Studio.exe"; Tasks: desktopicon
#endif

[Run]
Filename: "{app}\VIREX-Test-Studio.exe"; Description: "{cm:LaunchProgram,VIREX Test Studio}"; Flags: nowait postinstall skipifsilent

#ifdef StudioPreview
[Code]
function IsPortablePreview: Boolean;
begin
  Result := ExpandConstant('{param:PORTABLE|0}') = '1';
end;
#endif
