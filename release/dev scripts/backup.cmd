set /p num=Archive suffix: 

set _backup_moddir=IHarvest
set _backup_espname=IHarvest
set _backup_namespace=IH_
set _backup_filename=IHarvest-backup-%num%.7z
set _backup_modsdir=E:\libraries\Documents\Mods\Skyrim
set _backup_datadir="E:\Bethesda Softworks\MO2 SSE Mods\IHarvest"

start /D %_backup_datadir% /wait 7z a "%_backup_modsdir%\%_backup_moddir%\%_backup_filename%" -r Scripts\*%_backup_namespace%* Source\Scripts\*%_backup_namespace%* *%_backup_espname%*  meshes\idek\%_backup_namespace%\* meshes\idek\GetterCritter "%_backup_modsdir%\%_backup_moddir%\backup.cmd" "%_backup_modsdir%\%_backup_moddir%\compile-all.py"