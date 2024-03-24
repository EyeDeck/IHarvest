{
  Collects all arrows and projectiles in a given load order such that
  they can easily be fed into IHarvest to modify its behavior

  Usage:
  - Save this script as "Collect Gatherable Projectiles for IHarvest.pas",
    to the "Edit Scripts" folder in your xEdit directory
  - Load xEdit with your full load order
  - Right click in the left pane -> Apply Script
  - Select "Collect Gatherable Projectiles for IHarvest"
  - Press OK
  - Close xEdit
  - Make sure the "Console Commands Extender" SKSE plugin is installed
  - Launch the game, load a save
  - Open the console and run this command: bat IHArrows
}
unit IHarvestArrows;

interface
implementation
//uses xEditAPI, Classes, SysUtils, StrUtils;

var
  sl: TStringList;

function ProcessRecord(e: IInterface): integer;
var
  sig: string;
begin
  // skip irrelevant records
  sig := Signature(e);
  if (sig <> 'PROJ') and (sig <> 'AMMO') then
    Exit;

  // skip anything except conflict winners
  if not IsWinningOverride(e) then
    Exit;

  // skip anything not normally interactable
  if ( ((sig = 'AMMO') and (GetEditValue(ElementByPath(e,
    'DATA\Flags\Non-Playable')) = '1'))
    or ((sig = 'PROJ') and (GetEditValue(ElementByPath(e,
    'DATA\Flags\Can Be Picked Up')) <> '1')) ) then
    Exit;

  sl.Add('AddFormToFormList IH_LearnedTypes ' + GetElementEditValues(e, 'EDID'));
end;

function ProcessGroup(e: IInterface): integer;
var
  i: Integer;
begin
  for i := 0 to ElementCount(e) - 1 do begin
    ProcessRecord(ElementByIndex(e, i));
  end;
end;

function Initialize: integer;
var
  iFileIndex: Integer;

begin
  sl := TStringList.Create;
  for iFileIndex := 0 to FileCount - 1 do begin
    ProcessGroup(GroupBySignature(FileByIndex(iFileIndex), 'PROJ'));
    ProcessGroup(GroupBySignature(FileByIndex(iFileIndex), 'AMMO'));
  end;
end;

function Finalize: integer;
var
  fname: string;
begin
  fname := DataPath + '..\IHArrows.txt';
  AddMessage('Saving script to ' + fname);
  sl.SaveToFile(fname);
  sl.Free;
end;

end.
