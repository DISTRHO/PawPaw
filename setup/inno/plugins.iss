[Setup]
ArchitecturesInstallIn64BitMode=x64
AppName=PawPaw
AppVersion=0.0.0
DefaultDirName={autopf}\PawPaw
DisableDirPage=yes
OutputBaseFilename=PawPaw-0.0.0
OutputDir=.
UsePreviousAppDir=no

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#include "Z:\tmp\pawpaw\components.txt"

[Files]
#include "Z:\tmp\pawpaw\lv2bundles.txt"
