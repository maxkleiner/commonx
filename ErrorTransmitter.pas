unit ErrorTransmitter;

interface

uses
  typex,types,sysutils,systemx,debug,
  fileserviceclientex, AnonCommand, commands_system;

var
  G_Transmit_Errors_To: string = '';
procedure SendErrorReport(e: Exception);

implementation

procedure SendErrorReport(e: Exception);
var
  p: TPromise;
begin
  try
  if G_Transmit_Errors_To = '' then
    exit;

  debug.debuglog.lock;
  try
    var tmpfil := systemx.GetTempPath+'error_debug.txt';
    var remfil := 'error_reports\'+extractfilename(dllname)+'\error_debug_'+formatDateTime('YYYYMMDD_hhnnss',now())+'.txt';
    if e <> nil then
      Debug.log('TRANSMITTING ERROR:'+e.classname+' - '+e.message);
    debuglog.savelog(tmpfil, 1000000);

    var pp := InlineProc(procedure begin
      Debug.Log('promise started');
      var cli := TFileServiceclientex.create(G_Transmit_Errors_To,'420');
      try
        try
        cli.putfileex(tmpfil, remfil);
        except
        end;
      finally
        cli.free;
      end;
    end);

    GarbageCollect(pp);

    except
    end;
  finally
    debug.debuglog.unlock;
  end;





end;



end.
















