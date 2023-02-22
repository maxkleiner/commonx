unit FileLauncher;

interface

uses
{$IFDEF MSWINDOWS}
Winapi.ShellAPI, Winapi.Windows;
{$ENDIF MSWINDOWS}
{$IFDEF MACOS}
 macapi.appkit, macapi.foundation, Posix.Stdlib;
{$ENDIF MACOS}

type
TFileLauncher = class
  class procedure Open(const FilePath: string);
end;

implementation

class procedure TFileLauncher.Open(const FilePath: string);
begin
{$IFDEF MSWINDOWS}
ShellExecute(0, 'OPEN', PChar(FilePath), '', '', SW_SHOWNORMAL);
{$ENDIF MSWINDOWS}

{$IFDEF MACOS}
  begin
    var Workspace: NSWorkspace; // interface, no need for explicit destruction
    Workspace := TNSWorkspace.Create;
    Workspace.openFile(NSSTR(FilePath));
  end;
//_system(PAnsiChar('open '+'"'+AnsiString(FilePath)+'"'));
{$ENDIF MACOS}
end;

end.
