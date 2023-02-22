unit SimpleSockProxConnection;

interface

uses
  debug, simpleabstractconnection, systemx, typex, https, betterobject, tickcount, sysutils, helpers_stream, classes, numbers, httptypes;

type
  TSimpleSockProxConnection = class(TSimpleAbstractConnection)
  strict protected
    FProxyURL: string;
    FProxConnected: boolean;
    FConnected: boolean;
    connectionid: string;
    function DoCheckForData: Boolean; override;
    function DoWaitForData(timeout: Cardinal): Boolean; override;
  protected
    function DoReadData(buffer: PByte; length: Integer): Integer; override;
    function DoSendData(buffer: PByte; length: Integer): Integer; override;
    function DoConnect: Boolean; override;
    procedure DoDisconnect; override;
    function GetConnected: Boolean; override;
    function GetNonce: string;
    function LocalHTTPSGet(sURL: string): THTTPResults;
    function LocalHTTPSPost(sURL: string; postdata: TDynByteArray): THTTPResults;

  public
    function GetUniqueID: Int64; override;

    property ProxyURL: string read FProxyURL write FProxyURL;
  end;


implementation

{ TSimpleSockProxConnection }

function TSimpleSockProxConnection.DoCheckForData: Boolean;
begin
//this is used for polling operations... not sure it is needed
  result := false;
end;

function TSimpleSockProxConnection.DoConnect: Boolean;
var
  r: THTTPResults;
begin
  inherited;
  try
    var url := ProxyURL+'connect.ms?host='+Self.HostName+'&endpoint='+self.EndPoint;
    r := LocalHTTPSGet(url);
    result := r.ResultCode = 200;

    if not result then begin
      Debug.Log('Got '+r.resultcode.tostring+' from '+url);
      exit(false);
    end else
      connectionid := trim(r.Body);

    if connectionid= '' then begin
      Debug.Log('connection returned 200 but no connectionid!');
      result := false;
    end;

    Fconnected := result;
  except
    FConnected := false;
    result := false;
  end;



end;

procedure TSimpleSockProxConnection.DoDisconnect;
var
  r: THTTPResults;
begin
  inherited;
  if connectionid = '' then begin
    FConnected := false;
    exit;
  end;

  var url := ProxyURL+'disconnect.ms?id='+connectionid;
  r := LocalHTTPSGet(url);

    FConnected := false;


end;

function TSimpleSockProxConnection.DoReadData(buffer: PByte;
  length: Integer): Integer;
var
  r: THTTPResults;
begin
  if connectionid = '' then begin
    FConnected := false;
    exit;
  end;

  var url := ProxyURL+'receive.ms?len='+length.tostring+'&id='+connectionid;
  r := LocalHTTPSGet(url);
  if r.resultcode = 302 then
    exit(0)
  else begin
    var bsi := r.bodystream;
    if bsi <> nil then begin
      var bs := bsi.o;
      bs.Seek(0, soBeginning);
      result := lesserof(bs.Size, length);
      Stream_GuaranteeRead(bs, buffer, result);
    end else
      exit(0);
  end;

  if result > length then
    raise ECritical.Create(classname+' cannot return more data than is requested. Requested '+length.ToString+' returning '+result.tostring);

end;

function TSimpleSockProxConnection.DoSendData(buffer: PByte;
  length: Integer): Integer;
var
  ba: TDynByteArray;
  r: THTTPResults;
begin
  if connectionid = '' then begin
    FConnected := false;
    raise ECritical.create('cannot call send on a connection with blank connectionid');
  end;
  setlength(ba, length);
  MoveMem32(@ba[low(ba)], buffer, length);

  var url := ProxyURL+'send.ms?id='+connectionid;
  r := LocalHTTPSPost(url, ba);
  result := length;


end;

function TSimpleSockProxConnection.DoWaitForData(timeout: Cardinal): Boolean;
begin
  if connectionid = '' then begin
    FConnected := false;
    exit(true);

  end;

  var url := ProxyURL+'waitfordata.ms?id='+connectionid+'&tm='+inttostr(timeout);
  var r := LocalHTTPSGet(url);


  result := r.ResultCode = 200;

end;

function TSimpleSockProxConnection.GetConnected: Boolean;
begin
  result:= FConnected;
end;

function TSimpleSockProxConnection.GetNonce: string;
begin
  result := 'nonce='+inttohex(getticker,1)+inttohex(random(65535),1);
end;

function TSimpleSockProxConnection.GetUniqueID: Int64;
begin
  result := strtoint64(connectionid);
end;

function TSimpleSockProxConnection.LocalHTTPSPost(sURL: string;
  postdata: TDynByteArray): THTTPResults;
begin
  result := HTTPSPost(sURL+'&'+getNonce, postdata,'binary/binary');
end;

function TSimpleSockProxConnection.LocalHTTPSGet(sURL: string): THTTPResults;
begin
  result := HTTPSGet(sURL+'&'+getNonce);
end;

end.
