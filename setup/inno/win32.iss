#include "Z:\tmp\pawpaw\version.iss"

[Setup]
AppName=PawPaw
AppVersion={#VERSION}
DefaultDirName={commonpf32}\PawPaw
DisableDirPage=yes
OutputBaseFilename=PawPaw-win32-v{#VERSION}
OutputDir=.
UsePreviousAppDir=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#include "Z:\tmp\pawpaw\components.iss"

[Files]
#include "Z:\tmp\pawpaw\lv2bundles.iss"
