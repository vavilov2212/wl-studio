; Worklog Studio - Inno Setup installer script
;
; Compile with:
;   iscc /DAppVersion=1.0.12 /DSourceDir=C:\path\to\Release /Ooutput_dir worklog_studio.iss
;
; AppVersion and SourceDir MUST be provided as CLI defines.

#define AppName      "Worklog Studio"
#define AppPublisher "vavilov2212"
#define AppExeName   "worklog_studio.exe"
; This GUID identifies the app to Windows for upgrade detection.
; Never change it after the first public release.
#define AppId        "{{A3F8D201-7C4B-4E9A-BD6F-2E1C5A7F8D30}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppUpdatesURL=https://github.com/vavilov2212/wl-studio/releases
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install: no UAC elevation required.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputBaseFilename=worklog_studio_setup_{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Prompt user to close the running app before upgrading (needed to replace the .exe).
CloseApplications=yes
CloseApplicationsFilter=*worklog_studio.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copies the entire Flutter release output recursively.
; WinSparkle.dll is already in SourceDir because CMakeLists.txt copies it there at build time.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[UninstallRun]
; Force-terminate the app before uninstall so the uninstaller can delete
; locked files. WM_CLOSE alone won't work because the window is intercepted
; (minimize-to-tray). /F force-kills; SQLite journals ensure data safety.
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM {#AppExeName}"; \
  Flags: runhidden; RunOnceId: "KillApp"

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent
