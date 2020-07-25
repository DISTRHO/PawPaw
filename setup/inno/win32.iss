[Setup]
AppName=PawPaw
AppVersion=0.0.0
DefaultDirName={commonpf32}\PawPaw
DisableDirPage=yes
OutputBaseFilename=PawPaw-win32-0.0.0
OutputDir=.
UsePreviousAppDir=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#include "Z:\tmp\pawpaw\components.txt"

[Files]
#include "Z:\tmp\pawpaw\lv2bundles.txt"