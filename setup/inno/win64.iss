#include "Z:\tmp\pawpaw\version.iss"

[Setup]
ArchitecturesInstallIn64BitMode=x64
AppName=PawPaw
AppPublisher=DISTRHO
AppPublisherURL=https://github.com/DISTRHO/PawPaw/
AppSupportURL=https://github.com/DISTRHO/PawPaw/issues/
AppUpdatesURL=https://github.com/DISTRHO/PawPaw/releases/
AppVersion={#VERSION}
DefaultDirName={commonpf64}\PawPaw
DisableDirPage=yes
OutputBaseFilename=PawPaw-win64-v{#VERSION}
OutputDir=.
UninstallDisplayName=PawPaw LV2 plugins
UsePreviousAppDir=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#include "Z:\tmp\pawpaw\components.iss"

[Files]
#include "Z:\tmp\pawpaw\lv2bundles.iss"
