unit ConsoleGlobal;

interface


uses
{$IFDEF MSWINDOWS}
  windows,
{$ENDIF}
  ConsoleX;


var
  con: TConsole = nil;


implementation




{$IFDEF MSWINDOWS}
procedure ctrlhandler;stdcall;
begin
  con.closeapp := true;
{$IFDEF MSWINDOWS}
  Windows.SetConsoleCtrlHandler(nil, false);
{$ENDIF}


end;
{$ENDIF}



initialization
  con := TConsole.create;
{$IFDEF MSWINDOWS}
  Windows.SetConsoleCtrlHandler(@ctrlhandler, true);
{$ENDIF}


finalization
{$IFDEF MSWINDOWS}
  Windows.SetConsoleCtrlHandler(nil, false);
{$ENDIF}

  if assigned(con) then
    con.free;
  con := nil;



end.
