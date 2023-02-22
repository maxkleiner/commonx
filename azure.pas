unit azure;

interface

uses
  jsonhelpers, betterobject, typex, systemx,exe, sysutils;


type
  TAzureCLI = class(TSharedObject)
  private
    FSubscription: string;
    FLoggedIn: boolean;
    procedure SetSubScription(const Value: string);
  protected
    function azrun(sParams: string): string;
  public
    property Subscription: string read FSubscription write SetSubScription;
    procedure Login;
    function GetAccountList: string;
    function GetLogList(resourcegroup: string; servername: string): IHolder<TJSON>;
  end;


implementation

{ TAzureCLI }

function TAzureCLI.azrun(sParams: string): string;
var
  loc: string;
begin
  loc := 'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd';

  if not fileexists(loc) then
    raise ECritical.create('could not find Azure CLI instlaled at '+loc);

  var c := Tcmd_RunExe.create;
  try
    c.prog := loc;
    c.WorkingDir := dllpath;
    c.batchwrap := false;
    c.CaptureConsoleoutput := true;
    c.params := sParams;
    c.start;
    c.waitfor;
    result := c.ConsoleOutput;
  finally
    c.free;
  end;

end;

function TAzureCLI.GetAccountList: string;
begin
  result := azrun('account list');
end;

function TAzureCLI.GetLogList(resourcegroup,
  servername: string): IHolder<TJSON>;
begin
  var s := azrun('mysql server-logs list --resource-group '+resourcegroup+' --server-name '+servername);
  result := TJson.CreateFromString(s);

end;

procedure TAzureCLI.Login;
begin

  azrun('login');
  FLoggedIn := true;

end;

procedure TAzureCLI.SetSubScription(const Value: string);
begin
  if not FLoggedIn then
    raise Ecritical.create('log in before calling SetSubScription');
  FSubscription := Value;
  azrun('account set --subscription '+value);



end;

end.
