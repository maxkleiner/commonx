unit MotherShipSocketProxy;

interface
uses
  debug, systemx, tickcount, RequestInfo, helpers.sockets, numbers, helpers_stream,
  variants, MTDTInterface, webresource, Dataobjectservices, Dataobject,
  webconfig, sysutils, templates, quickqueries, multibuffermemoryfilestream,
  classes, speech, node, simpleabstractconnection, SimpleWinSock, socketproxy, typex;

implementation

uses
  stringx, stringx.ansi,
  ServerInterface,
  Exceptions,
  RequestDispatcher, WebString;



procedure WRQ_Connect(rqInfo: TRequestInfo);
begin
  rqinfo.Response.ContentType := 'text/plain';
  try
    var c := SkPx.Connect(rqInfo.Request['host'],rqInfo.Request['endpoint']);

    if c = nil then
      rqInfo.Response.Content.add('')
    else
      rqInfo.Response.Content.Add(inttostr(c.o.GetUniqueID));

  except
    on e: Exception do begin
      rqInfo.response.ResultCode := 500;
      rqInfo.Response.Content.Text := e.message;
    end;
  end;



end;

procedure WRQ_WAitForData(rqInfo: TRequestInfo);
begin
  rqinfo.Response.ContentType := 'text/plain';
  try
    var id: int64 := strtoint64(rqInfo.Request['id']);
    var timeout: int64 := strtoint64(rqInfo.Request['tm']);

    var c := SkPx.FindSocket(strtoint64(rqInfo.Request['id']));
    if c = nil then begin
      rqInfo.Response.Content.Add('1');//return true if connection doesn't exist
    end else begin
      rqInfo.Response.Content.Add(booltostrex(c.o.WaitForData(timeout),'1','0'));
    end;
  except
    on e: Exception do begin
      rqInfo.response.ResultCode := 500;
      rqInfo.Response.Content.Text := e.message;
    end;
  end;

end;

procedure WRQ_Send(rqInfo: TRequestInfo);
var
  mem: TDynByteArray;

begin
  rqInfo.Response.ContentType := 'text/plain';
  Debug.Log('Mothership SEND');
  rqinfo.Response.ContentType := 'socket/data';
  try
    if not rqInfo.Request.HasParam('id') then begin
      raise ECritical.Create('something very wrong with '+rqInfo.request.FullURL);
    end;
    var sid: string := rqInfo.Request['id'];
    if sid = '' then
      raise ECritical.Create('something very wrong with '+rqInfo.request.FullURL);
    var id: int64 := strtoint64(sid);

    var c := SkPx.FindSocket(id);
    if c = nil then begin
      rqInfo.Response.Content.Add('Connection does not exist');//return true if connection doesn't exist
      rqInfo.Response.ResultCode := 500;
    end else begin
      var str:= rqInfo.Request.ContentStream.o;
      str.seek(0,soBeginning);
      setlength(mem, str.Size);
      Stream_GuaranteeRead(str, @mem[0], str.Size);
      c.o.GuaranteeeSendata(@mem[low(mem)], length(mem),16000);
      rqInfo.Response.Content.Text := inttostr(length(mem));
    end;
  except
    on e: Exception do begin
      rqInfo.response.ResultCode := 500;
      rqInfo.Response.Content.Text := e.message;
    end;
  end;
end;


procedure WRQ_Receive(rqInfo: TRequestInfo);
begin
  rqinfo.Response.ContentType := 'socket/data';
  try
    var id: int64 := strtoint64(rqInfo.Request['id']);
    var len: int64 := strtoint64(rqInfo.Request['len']);
    len := lesserof(len, 1000000);

    var c := SkPx.FindSocket(id);
    if c = nil then
      rqInfo.response.resultcode := 302
    else begin
      var tempstr : rawbytestring := '';
      setlength(tempstr, len);
      var iRead := c.o.ReadData(@tempstr[low(tempstr)], len);
      if iRead > len then
        raise ECritical.Create('cannot read more than buffer size!');
      rqInfo.Response.ContentLength := iRead;
      rqInfo.Response.ContentStream := TMemoryStream.Create;
      rqInfo.Response.ContentLength := iRead;
      rqInfo.response.contenttype := 'application/octet-stream';
      stream_guaranteeWrite(rqInfo.response.contentstream, @tempstr[low(tempstr)], iRead);
      rqInfo.Response.ContentStream.Seek(0, soBeginning);
      Debug.Log('Mothership Receive '+inttostr(iRead)+' from '+id.tostring);
    end;

  except
    on e: Exception do begin
      rqInfo.response.ResultCode := 500;
      rqInfo.Response.Content.Text := e.message;
    end;
  end;

end;


procedure WRQ_Disconnect(rqInfo: TRequestInfo);
begin
  rqinfo.Response.ContentType := 'text/plain';
  try
    var id: int64 := strtoint64(rqInfo.Request['id']);
    SkPx.Disconnect(id);
  except
    on e: Exception do begin
      rqInfo.response.ResultCode := 500;
      rqInfo.Response.Content.Text := e.message;
    end;
  end;

end;





initialization

RQD.AddRequest('/connect.ms', 'get', WRQ_connect);
RQD.AddRequest('/waitfordata.ms', 'get', WRQ_WaitForData);
RQD.AddRequest('/send.ms', 'post', WRQ_Send);
RQD.AddRequest('/receive.ms', 'get', WRQ_Receive);
RQD.AddRequest('/disconnect.ms', 'get', WRQ_Disconnect);



end.

