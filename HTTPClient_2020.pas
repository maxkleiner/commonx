unit HTTPClient_2020;
{$INCLUDE DelphiDefs.inc}



interface

uses
  betterobject,consolex, sysutils, debug, httptypes, systemx, typex, classes, System.Net.HttpClient, stringx, System.Net.URLClient, helpers_stream, commandprocessor;

const
  DEFAULT_USER_AGENT = 'googlebot';



function HTTPSGet(sURL: string; altstream: IHolder<TStream>; cmd: TCommand  = nil; protocols: THTTPSecureProtocols = []): THTTPResults;

function HTTPSPost(sURL: string; PostData: string; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;


function preferred_protocols(con: Tconsole = nil):THTTPSecureProtocols;


type
  TNameAndValue = record
    name: string;
    value: string;
    class function New(name, value: string): TNameAndValue;static;
    class function toQueryString(a: Tarray<TNameAndValue>; prefix: string = '?'): string;static;
  end;
  TStatefulBrowser = class(TBetterObject)
  //TStatefulBrowser is a simple/cross-platform HTTP Client that remembers
  //things like cookies from request to request.
  private

  protected
    client: IHolder<THTTPClient>;
  public
    forceEncoding: TEncoding;
    function Get(sURL: string; extraheaders: TArray<TNameAndValue>;altstream: IHolder<TStream> =nil; cmd: TCommand  = nil; protocols: THTTPSecureProtocols = []): THTTPResults;overload;
    function Get(sURL: string; altstream: IHolder<TStream> = nil; cmd: TCommand  = nil; protocols: THTTPSecureProtocols = []): THTTPResults;overload;
    function Post(sURL: string; PostData: string; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;overload;
    function Post(sURL: string; PostData: TArray<TNameAndValue>; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;overload;
    function Patch(sURL: string; PostData: string; ContentType: string = 'application/json'): THTTPResults;overload;

    constructor Create; override;
    class function CreateH: IHolder<TStatefulBrowser>;

  end;


implementation



var
  prots_found: boolean = false;
  best_prots: THTTPSecureProtocols;

function preferred_protocols(con: Tconsole = nil):THTTPSecureProtocols;
var
  res: THTTPResults;
begin
  if prots_found then
    exit(best_prots);

  result := [];

  var url := 'https://cloud.comparatio.com/monitoratio/deploy.txt';

{$IFDEF SUPPORT_TLS13}
  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: TLS13 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.TLS13]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.TLS13];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.Message);
      if con <> nil then con.WriteOk(false);
    end;
  end;
{$ENDIF}

  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: TLS12 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.TLS12]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.TLS12];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.message);
      if con <> nil then con.writeok(false);
    end;
  end;

  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: TLS11 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.TLS11]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.TLS11];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.message);
      if con <> nil then con.writeok(false);
    end;
  end;

  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: TLS1 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.TLS1]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.TLS1];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.message);
      if con <> nil then con.writeok(false);
    end;
  end;


  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: SSL3 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.SSL3]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.SSL3];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.message);
      if con <> nil then con.writeok(false);
    end;
  end;

  try
    if con <> nil then con.WriteEx('Checking TLS support Levels: SSL2 ');
    res := HTTPSGet(url, nil, nil, [THTTPSecureProtocol.SSL2]);
    if res.Success then begin
      result := result + [THTTPSecureProtocol.SSL2];
    end;
    if con <> nil then con.WriteOk(res.success);
  except
    on E:Exception do begin
      if con <> nil then con.WriteEx(e.message);
      if con <> nil then con.writeok(false);
    end;
  end;

  best_prots := result;
  prots_found := true;


end;

type
  THTTPSReceptor = class(TObject)
    cmd: Tcommand;
    procedure recv (const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var Abort: Boolean);
  end;

function HTTPSGet(sURL: string; altstream: IHolder<TStream>; cmd: TCommand  = nil; protocols: THTTPSecureProtocols = []): THTTPResults;
var
  heads: TArray<System.Net.URLClient.TNameValuePair>;
begin
//  if cmd <> nil then
//    debug.log(cmd.classname);
//  raise Exception.create('carry forward');
  result.error := '';
  var htp := System.Net.HttpClient.THTTPClient.Create;
  htp.UserAgent := DEFAULT_USER_AGENT;
  try
    if protocols = [] then
      protocols := preferred_protocols;
    htp.SecureProtocols :=  protocols;
    var msh : IHolder<TSTream>;
    if altstream = nil then begin
      msh := THolder<TStream>.create;
      msh.o := TmemoryStream.Create;
    end else begin
      msh := altstream;
    end;


    setlength(heads, 0);//extra headers
                  //Get(const AURL: string; const AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
{$IF CompilerVersion >33.0}
    htp.ConnectionTimeout := 8000;
    htp.SendTimeout := 8000;
    htp.ResponseTimeout := 30000;
{$ELSE}
    Debug.Log('Warning! Use of THTTPClient does not support Timeouts in 10.3 and earlier');
{$ENDIF}
    var rec := THTTPSReceptor.create;
    try
      if cmd <> nil then begin
        rec.cmd := cmd;
        htp.OnReceiveData := rec.recv;
      end;
      var resp := htp.Get(sURL, msh.o, heads);

      result.bodystream := msh;
      result.native := resp;
      result.ResultCode := resp.StatusCode;
      result.Success := resp.StatusCode < 400;
      result.error := resp.StatusText;
      if zpos('text', lowercase(resp.MimeType)) >=0 then
        result.Body := resp.ContentAsString;

      result.bodystream := msh;
      result.contentType := resp.MimeType;
    finally
      htp.onreceivedata := nil;
      rec.Free;
    end;


  finally
    htp.free;
  end;

end;

function HTTPSPost(sURL: string; PostData: string; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;
var
  heads: TArray<System.Net.URLClient.TNameValuePair>;
begin

//  raise Exception.create('carry forward');
  result.error := '';
  var htp := System.Net.HttpClient.THTTPClient.Create;
  htp.UserAgent :=DEFAULT_USER_AGENT;
  try
    var slh := stringToStringListH(PostData);
    var msh : IHolder<TSTream> := THolder<TStream>.create;
    msh.o := TmemoryStream.Create;

    setlength(heads, 0);//extra headers
    htp.ContentType := ContentType;
    var resp := htp.Post(sURL, slh.o, msh.o, nil, heads);
    result.ResultCode := resp.StatusCode;
    result.error := resp.StatusText;
    result.Success := resp.StatusCode < 400;
    result.Body := resp.ContentAsString;
    result.bodystream := msh;
    result.contentType := resp.MimeType;

  finally
    htp.free;
  end;

end;

{ THTTPSReceptor }

procedure THTTPSReceptor.recv(const Sender: TObject; AContentLength,
  AReadCount: Int64; var Abort: Boolean);
begin


//  cmd.Status :=aReadcount.tostring+'/'+acontentlength.tostring;
  cmd.step:= AReadCount;
  cmd.stepcount := AContentLength;
end;

{ TStatefulBrowser }

constructor TStatefulBrowser.Create;
begin
  inherited;
  var cli := THTTPClient.Create;
  client := Tholder<THTTPClient>.create(cli);
  client.o.UserAgent :=DEFAULT_USER_AGENT;
  forceEncoding := nil;
end;

function TStatefulBrowser.Get(sURL: string; extraheaders: TArray<TNameAndValue>; altstream: IHolder<TStream>;
  cmd: TCommand; protocols: THTTPSecureProtocols): THTTPResults;
var
  heads: TArray<System.Net.URLClient.TNameValuePair>;
begin
//  if cmd <> nil then
//    debug.log(cmd.classname);
//  raise Exception.create('carry forward');
  result.error := '';
  var htp := client.o;
  try
    if protocols = [] then
      protocols := preferred_protocols;
    htp.SecureProtocols :=  protocols;
    var msh : IHolder<TSTream>;
    if altstream = nil then begin
      msh := THolder<TStream>.create;
      msh.o := TmemoryStream.Create;
    end else begin
      msh := altstream;
    end;


    setlength(heads, length(extraheaders));//extra headers
                  //Get(const AURL: string; const AResponseContent: TStream; const AHeaders: TNetHeaders): IHTTPResponse;
    for var i := 0 to high(heads) do begin
      heads[i].Name := extraheaders[i].Name;
      heads[i].Value := extraheaders[i].Value;
    end;


{$IF CompilerVersion >33.0}
    htp.ConnectionTimeout := 8000;
    htp.SendTimeout := 8000;
    htp.ResponseTimeout := 30000;
{$ELSE}
    Debug.Log('Warning! Use of THTTPClient does not support Timeouts in 10.3 and earlier');
{$ENDIF}
    var rec := THTTPSReceptor.create;
    try
      if cmd <> nil then begin
        rec.cmd := cmd;
        htp.OnReceiveData := rec.recv;
      end;
      var resp := htp.Get(sURL, msh.o, heads);

      result.bodystream := msh;
      result.ResultCode := resp.StatusCode;
      result.Success := resp.StatusCode < 400;
      result.error := resp.StatusText;
      if (zpos('text', lowercase(resp.MimeType)) >=0)
      or (zpos('application/xml', lowercase(resp.MimeType)) >=0)
      or (zpos('application/json', lowercase(resp.MimeType)) >=0)
      then begin
        try
          result.Body := resp.ContentAsString(forceencoding);
        except
          result.Body := resp.ContentAsString(TEncoding.ANSI);
        end;
      end;
      setlength(result.cookie_headers, resp.Cookies.count);
      for var t:= 0 to resp.Cookies.Count-1 do
        result.cookie_headers[t] := resp.Cookies[t].Name+'='+resp.Cookies[t].value;

      result.bodystream := msh;
      result.contentType := resp.MimeType;
    finally
      htp.onreceivedata := nil;
      rec.Free;
    end;


  finally
  end;

end;

class function TStatefulBrowser.CreateH: IHolder<TStatefulBrowser>;
begin
  result := THolder<TStatefulbrowser>.create(TStatefulbrowser.create);
end;

function TStatefulBrowser.Get(sURL: string; altstream: IHolder<TStream>;
  cmd: TCommand; protocols: THTTPSecureProtocols): THTTPResults;
begin
  result := Get(sURL, [], altstream, cmd, protocols);
end;

function TStatefulBrowser.Patch(sURL, PostData,
  ContentType: string): THTTPResults;
var
  heads: TArray<System.Net.URLClient.TNameValuePair>;
begin

//  raise Exception.create('carry forward');
  result.error := '';
  var htp := client.o;
  try
    var slh := parsestringh(PostData,'&');
    var msh : IHolder<TSTream> := THolder<TStream>.create;
    msh.o := TmemoryStream.Create;
    var ss: IHolder<TStringStream> := THolder<TStringStream>.create(TStringStream.Create);
    ss.o.WriteString(slh.o.Text);

    setlength(heads, 0);//extra headers
    htp.ContentType := ContentType;
    var resp := htp.Patch(sURL, ss.o, msh.o, heads);
    result.ResultCode := resp.StatusCode;
    result.Success := resp.StatusCode < 400;
    result.error := resp.StatusText;
    try
      result.Body := resp.ContentAsString(forceencoding);
    except
      result.Body := resp.ContentAsString(TEncoding.ANSI);
    end;
    result.bodystream := msh;
    result.contentType := resp.MimeType;

  finally
  end;

end;

function TStatefulBrowser.Post(sURL: string; PostData: TArray<TNameAndValue>;
  ContentType: string): THTTPResults;
begin
  var datastring := '';
  for var t := 0 to high(PostData) do begin
    if datastring = '' then
      datastring := datastring + postdata[t].name+'='+postdata[t].value
    else
      datastring := datastring + '&'+ postdata[t].name+'='+postdata[t].value;



  end;

  result := Post(sURL,datastring, contenttype);


end;

function TStatefulBrowser.Post(sURL, PostData,
  ContentType: string): THTTPResults;
var
  heads: TArray<System.Net.URLClient.TNameValuePair>;
  resp : IHTTPResponse;
begin

//  raise Exception.create('carry forward');
  result.error := '';
  var htp := client.o;
  try
    var msh : IHolder<TSTream> := THolder<TStream>.create;
    msh.o := TmemoryStream.Create;
    htp.ContentType := ContentType;
    setlength(heads, 0);//extra headers
    var slh := NewStringListH();
    if contenttype='application/x-www-form-urlencoded' then begin
      slh := parsestringh(PostData,'&');
      resp := htp.Post(sURL, slh.o, msh.o, nil, heads);
    end else begin
      slh.o.Text := PostData;
      var ssh : IHolder<TStringStream> := Tholder<TStringStream>.create(TStringStream.create);
      ssh.o.WriteString(PostData);
      ssh.o.seek(0,soBeginning);
      resp := htp.Post(sURL, ssh.o, msh.o, heads);
    end;

    result.ResultCode := resp.StatusCode;
    result.Success := resp.StatusCode < 400;
    result.error := resp.StatusText;
    try
      result.Body := resp.ContentAsString(forceencoding);
    except
      result.Body := resp.ContentAsString(TEncoding.ANSI);
    end;
    result.bodystream := msh;
    result.contentType := resp.MimeType;

  finally
  end;

end;


{ TNameAndValue }

class function TNameAndValue.New(name, value: string): TNameAndValue;
begin
  result.name := name;
  result.value := value;
end;

class function TNameAndValue.toQueryString(a: Tarray<TNameAndValue>; prefix: string = '?'): string;
begin
  result := '';
  for var t := 0 to high(a) do begin
    if result = '' then
      result := prefix + urlencode(a[t].name)+'='+urlencode(a[t].value)
    else
      result := result+'&'+urlencode(a[t].name)+'='+urlencode(a[t].value);
  end;

end;

end.

