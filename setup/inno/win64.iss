#include "Z:\tmp\pawpaw\version.iss"

[Setup]
ArchitecturesInstallIn64BitMode=x64
AppName=PawPaw
AppVersion={#VERSION}
DefaultDirName={commonpf64}\PawPaw
DisableDirPage=yes
OutputBaseFilename=PawPaw-win64-v{#VERSION}
OutputDir=.
UsePreviousAppDir=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#include "Z:\tmp\pawpaw\components.iss"

[Files]
#include "Z:\tmp\pawpaw\lv2bundles.iss"
