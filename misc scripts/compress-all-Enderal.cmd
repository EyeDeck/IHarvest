REM Batch script for automatically shoving all of my assets into archive files using Bethesda's Archive2 utility.
REM As usual, if you aren't me, you may have to adjust the directories yourself.

set _moddir="C:\Bethesda Softworks\Mod Organizer EnderalSE\mods\IHarvest EnderalSE"
REM E:C:\Bethesda Softworks\Mod Organizer EnderalSE\mods\IHarvest EnderalSE
cd %_moddir%
"C:\Bethesda Softworks\BSArch\bsarch.exe" pack %_moddir% "packingEnderal\IHarvest-EnderalSE.bsa" -sse
copy %_moddir%\IHarvest-EnderalSE.esp packingEnderal\IHarvest-EnderalSE.esp

pause