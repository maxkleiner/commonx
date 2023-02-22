unit SimpleAutoConnection;

interface

uses
  debug,simpleabstractconnection, systemx, typex, https, betterobject, tickcount, sysutils, helpers_stream, classes, numbers, simplesockproxconnection, simpletcpconnection, proxydefault, stringx;

type
  TSimpleAutoConnection = class(TSimpleAbstractConnection)
  protected
    FProxyURLs: IHolder<TStringList>;
    FProxyURL: string;
    FStackConnected: boolean;
    connection_tries: ni;
    underconnection: TSimpleAbstractConnection;
    function DoCheckForData: Boolean; override;
    function DoWaitForData(timeout: Cardinal): Boolean; override;
    procedure AssertUnderConnection;
  protected
    function DoReadData(buffer: PByte; length: Integer): Integer; override;
    function DoSendData(buffer: PByte; length: Integer): Integer; override;
    function DoConnect: Boolean; override;
    procedure DoDisconnect; override;
    function GetConnected: Boolean; override;
    procedure Cleanup;
    function CreateUnderClass(bProxy: boolean): TSimpleAbstractConnection;
    procedure SelectProxy;
  public
    procedure Detach; override;
    constructor Create; override;
    function GetUniqueID: Int64; override;
    property ProxyURL: string read FProxyURL write FProxyURL;

  end;


var
  G_DirectConnectionTested: boolean = false;
  G_PreferProxy: boolean = false;
  G_preferred_proxy_idx: nativeint = 0;


implementation

{ TSimpleAutoConnection }

uses
  commandline;




procedure TSimpleAutoConnection.AssertUnderConnection;
begin
  if underconnection = nil then
    raise ECritical.Create('underconnection is nil, it is possible that you forgot to call connect()');
end;

procedure TSimpleAutoConnection.Cleanup;
begin
  if underconnection<>nil then begin
    underconnection.Free;
    underconnection := nil;
  end;

end;

constructor TSimpleAutoConnection.Create;
begin
  inherited;
  FProxyURLs := stringtostringlisth(GetDefaultProxy.o.text);
  if FProxyURls.o.count > 0 then
    FProxyURL := FProxyURLS.o[0];
end;

function TSimpleAutoConnection.CreateUnderClass(
  bProxy: boolean): TSimpleAbstractConnection;
begin
  Cleanup;
      if bProxy then begin
        underconnection := TSimpleSockProxConnection.create;
        (underconnection as TSimpleSockProxConnection).ProxyURL := self.ProxyURL;

      end else begin
        underconnection := TSimpleTCPConnection.create;
      end;

      underconnection.HostName := self.HostName;
      underconnection.EndPoint := self.EndPoint;
      underconnection.send_eol_cr := send_eol_cr;
      underconnection.send_eol_lf := send_eol_lf;
      underconnection.readln_eol := readln_eol;
      underconnection.readln_ignore := readln_ignore;

  underconnection.maxconnectiontries := 0;
  result := underconnection;

end;

procedure TSimpleAutoConnection.Detach;
begin
  if detached then exit;

  Cleanup;
  inherited;

end;

function TSimpleAutoConnection.DoCheckForData: Boolean;
begin
  AssertUnderConnection;
  result := underconnection.checkfordata;
end;

function TSimpleAutoConnection.DoConnect: Boolean;
begin
  FStackConnected := false;
  try
    try
      Cleanup;
    except
      Debug.Log('Warning: an exception occurred when trying to cleanup underconnection in '+classname);
    end;
    //if we've already affirmed direct connection is possible, just keep using it
    if G_DirectConnectionTested and (G_PreferProxy=false) then begin
      underconnection := CreateUnderClass(G_PreferProxy);
      FStackConnected := underconnection.connect;
    end else begin
      if not G_DirectConnectionTested then
      try
        Debug.Log(classname+': Trying direct connection to '+HostName+':'+endpoint);

        underconnection := CreateUnderClass(false);
        FStackConnected := false;
        FStackConnected := underconnection.Connect;
        if FStackConnected then begin
          G_PreferProxy := false;
          G_DirectConnectionTested := true;
        end;
      except
        FStackConnected := false;
      end;

      var cx := FProxyURLs.o.count * 2;
      while not FStackConnected do begin
        try
          SelectProxy;
          Cleanup;
          underconnection := CreateUnderClass(true);
          Debug.Log(classname+': Trying connection to '+HostName+':'+endpoint+' via proxy: @'+FProxyURL);

          FStackConnected := false;
          FStackConnected := underconnection.Connect;

          if FStackConnected then begin
            Debug.Log(classname+': Connected to '+HostName+':'+endpoint+' via proxy: @'+FProxyURL);
            G_PreferProxy := true;
            G_DirectConnectionTested := true;
          end else begin
            Debug.Log('Stack failed to connected via proxy: '+FProxyURL);
            inc(G_preferred_proxy_idx);//threadsafe because of how it is RANGE CHECKED on READ
            dec(cx);
          end;
        except
          inc(G_preferred_proxy_idx);//threadsafe because of how it is RANGE CHECKED on READ
          FStackConnected := false;
          dec(cx);
        end;
        if cx <=0 then
          break;
      end;
    end;

  finally
    result := FstackConnected;
  end;




end;

procedure TSimpleAutoConnection.DoDisconnect;
begin
  inherited;
  if underconnection = nil then
    exit;
  underconnection.disconnect;

end;

function TSimpleAutoConnection.DoReadData(buffer: PByte;
  length: Integer): Integer;
begin
  if underconnection = nil then
    exit(0);
  result := underconnection.readdata(buffer, length);

end;

function TSimpleAutoConnection.DoSendData(buffer: PByte;
  length: Integer): Integer;
begin
  AssertUnderConnection;
  result := underconnection.senddata(buffer,length);

end;

function TSimpleAutoConnection.DoWaitForData(timeout: Cardinal): Boolean;
begin
  result := underconnection.waitfordata(timeout);
end;

function TSimpleAutoConnection.GetConnected: Boolean;
begin
  if underconnection = nil then
    exit(false);

  result := underconnection.connected;
end;

function TSimpleAutoConnection.GetUniqueID: Int64;
begin
  result := underconnection.getuniqueid;
end;

procedure TSimpleAutoConnection.SelectProxy;
begin
  if FProxyURLs.o.Count >0 then begin
    var idx := G_preferred_proxy_idx mod FProxyUrls.o.count;
    FProxyURL := FProxyUrls.o[idx];
    Debug.Log('Selected proxy: '+FProxyURL);
  end;
end;

procedure CheckCommandLineFlags;
var
  cl: TcommandLIne;
begin
  cl.ParseCommandLine();
  if cl.HasFlag('--force-proxy') then begin
    G_DirectConnectionTested := true;
    G_PreferProxy := true;
  end;


end;

initialization


CheckCommandLineFlags;



end.

