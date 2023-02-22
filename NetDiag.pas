unit NetDiag;

interface

uses
  commandprocessor, betterobject, idglobal, IdTCPClient, SimpleTCPConnection, sysutils, HTTPClient_2020, HTTPTypes;

type
  TNetdiagCommand = class(TCommand)
  public
    error: string;
  end;

  Tcmd_CheckConnect = class(TNetDiagCommand)
  public
    host: string;
    port: nativeint;
    procedure DoExecute;override;
  end;

  Tcmd_CheckHTTPS = class(TNetDiagCommand)
  public
    url: string;
    procedure DoExecute;override;
  end;

implementation

{ Tcmd_CheckConnect }

procedure Tcmd_CheckConnect.DoExecute;
begin
  inherited;
  var cli := TSimpleTCPConnection.Create;
  try
    cli.HostName := host;
    cli.EndPoint := port.tostring;
    try
      if not cli.Connect then begin
        error := 'General Connection Failure to '+host+':'+port.tostring;
      end;
    except
      on e: exception do begin
        error := e.message;
      end;
    end;
  finally
    cli.Free;
  end;
end;

{ Tcmd_CheckHTTPS }

procedure Tcmd_CheckHTTPS.DoExecute;
var
  res: THTTPResults;
begin
  inherited;
  try
    res := HTTPClient_2020.HTTPSGet(url, nil, self);
    if res.ResultCode <> 200 then begin
     error := 'HTTPs Error '+res.ResultCode.ToString;
    end;
  except
    on E:Exception do begin
      error := e.message;
    end;
  end;

end;


end.
