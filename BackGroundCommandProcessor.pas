unit BackGroundCommandProcessor;

interface
{$IFDEF NO_DONT_USE_MOVED_TO_COMMANDPROCESSOR}
uses
  orderlyinit, ManagedThread, BackGroundThreads, CommandProcessor,
{$IFNDEF IOS}
  windows,
{$ENDIF}
  sysutils;

var
  BGCmd: TCommandProcessor = nil;
  ForXCmds: TCommandProcessor = nil;
  KillFlag: boolean = false;

{$ENDIF}
implementation
{$IFDEF NO_DONT_USE_MOVED_TO_COMMANDPROCESSOR}
procedure oinit;
begin
  KillFlag := false;
  BGCmd := TCommandProcessor.create(BackgroundThreadMan, 'BackGroundCommandProcessor.BGCmd');
  ForXCmd := TCommandProcessor.create(BackgroundThreadMan, 'BackGroundCommandProcessor.ForXCmd');
end;

procedure ofinal;
begin
  KillFlag := true;
  if assigned(ForXCmd) then
    ForXCmd.cancelall;
  if assigned(BGCmd) then
    BGCmd.CancelAll;
  if assigned(ForXCmd) then
    ForXCmd.WaitForAll;
  if assigned(BGCmd) then
    BGCmd.WaitforAll;
  if assigned(ForXCmd) then
    ForXCmd.Detach;
  if assigned(BGCmd) then
    BGCmd.Detach;
  //sleep(100);


  if assigned(ForXCmd) then
    ForXCmd.Free;
  if assigned(BGCmd) then
    BGCmd.free;

end;
{$ENDIF}

initialization

{$IFDEF NOPE}
init.RegisterProcs('BackGroundCommandProcessor', oinit, ofinal,'CommandProcessor,ManagedThread');
{$ENDIF}

finalization


end.
