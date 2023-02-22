unit BackgroundThreads;
//This unit holds a global variable for a singleton instance of TThreadManager
//called BackgroudnThreadMan.  Read BackgroundThreadMan to get the status of
//all BAckground threads running in the PWLN system.  This includes the
//"Janitor" cleanup thread, ERater-retry thread, Session Timeout thread, and
//1-n temporary threads that occasionally appear for fetching accounts from the data-tier(s).
//There are no classes defined here, and there is no significant code.


interface
uses
  Managedthread,
{$IFDEF WINDOWS}
  winapi.windows,
{$ENDIF}
  orderlyinit;

var
  GFBackgroundThreadMan : TThreadManager =nil;

function BackgroundThreadMan: TThreadManager;


implementation


function BackgroundThreadMan: TThreadManager;
begin
  if GFBackgroundThreadMan = nil then
    GFBackgroundThreadMan := TThreadManager.create;
  result := GFBackgroundThreadMan;

end;

procedure oinit;
begin
//  GFBackgroundThreadMan := TThreadManager.create;
  BackgroundThreadMan;
end;

procedure ofinal;
begin
  if assigned(GFBackgroundThreadMan) then
    GFBackgroundThreadMan.free;

end;

initialization
  init.RegisterProcs('BackgroundThreads', oinit, ofinal, 'ManagedThread');


finalization



end.

