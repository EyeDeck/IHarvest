REM Batch script for automatically shoving all of my assets into archive files using Bethesda's Archive2 utility.
REM As usual, if you aren't me, you may have to adjust the directories yourself.

set _moddir="C:\Bethesda Softworks\MO2 SSE Mods\IHarvest"
REM E:
cd %_moddir%
"C:\Bethesda Softworks\BSArch\bsarch.exe" pack %_moddir% "packing\IHarvest.bsa" -sse
copy %_moddir%\IHarvest.esl packing\IHarvest.esl
copy %_moddir%\IHarvest.esp packing\IHarvest.esp

pause