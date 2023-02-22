unit https;
{$IFDEF MSWINDOWS}
{$DEFINE USE_IXMLHTTP}
{$ENDIF}
interface
{$I DelphiDefs.inc}

uses
{$IFDEF USE_IXMLHTTP}
  MSXML2_TLB_Legacy,
{$ELSE}
  System.Net.HttpClient,
  SYstem.Net.URLClient,
{$ENDIF}
  sysutils, variants, typex, commandprocessor, classes, debug, IdSSLOpenSSL, systemx, IdSSLOpenSSLHeaders, betterobject, helpers_stream, stringx, httptypes;


const
  DEFAULT_CONTENT_TYPE = 'application/x-www-form-urlencoded';
type
  Tcmd_HTTPS = class(TCommand)
  private

  public
    Request: THTTPSRequest;
    Results: THTTPResults;
    procedure DoExecute; override;
    procedure Init; override;
  end;

  Tcmd_HTTPsToFile = class(Tcmd_HTTPS)
  public
    UrL: string;
    IgnoreIftargetExists: boolean;
    LocalFile: String;
    procedure DoExecute; override;
  end;

//function QuickHTTPSGet(sURL: ansistring): ansistring;
function QuickHTTPSGet(sURL: ansistring; out sOutREsponse: string; addHead: string =''; addHeadValue: string = ''): boolean;overload;
function QuickHTTPSGet(sURL: ansistring; out sOutREsponse: string; addHeaders: TArray<TExtraHeader>): boolean;overload;
function QuickHTTPSPost(sURL: ansistring; sPostBody: ansistring; out sOutREsponse: string; contentType: string = DEFAULT_CONTENT_TYPE; addHead: string =''; addHeadValue: string = ''; method: string = 'POST'): boolean;
{$IFDEF USE_IXMLHTTP}
function QuickHTTPSPostOld(sURL: ansistring; PostData: ansistring; ContentType: ansistring = 'application/x-www-form-urlencoded'): ansistring;
{$ENDIF}

function HTTPSGet(sURL: string; referer: string = ''; AddHead: string = ''; AddHeadValue: string = ''): THTTPResults;
function HTTPSPost(sURL: string; PostData: string; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;overload;
function HTTPSPost(sURL: string; PostData: TDynByteArray; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;overload;

{$IFDEF USE_IXMLHTTP}
procedure https_SetHeaderIfSet(htp: IXMLHttpRequest; sheader: string; sValue: string);
{$ELSE}
{$ENDIF}


implementation


function QuickHTTPSPost(sURL: ansistring; sPostBody: ansistring; out sOutREsponse: string; contentType: string = DEFAULT_CONTENT_TYPE; addHead: string =''; addHeadValue: string = ''; method: string = 'POST'): boolean;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := ComsXMLHTTP30.create();
  try
    htp.open(method, string(sURL), false, null, null);
    htp.setRequestHeader('Content-Type', ContentType);
    if addHead <> '' then
      htp.setRequestHeader(addHead, addHeadValue);
    htp.send(sPostBody);

    result := htp.status = 200;
    if result then
      sOutREsponse := htp.responsetext
    else begin
      soutResponse := htp.responsetext;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;
end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

    //xxxx htp.setRequestHeader('Content-Type', ContentType);
    nvp.Name := 'Content-Type';
    nvp.Value := ContentType;
{$IFDEF USE_IXMLHTTP}
      htp.CustHeaders.Add(nvp);
{$ELSE}

      htp.CustomHeaders[nvp.Name] := nvp.Value;
{$ENDIF}

    if addHead <> '' then begin
      //xxx htp.setRequestHeader(addHead, addHeadValue);
      nvp.Name := addHEad;
      nvp.Value := addheadValue;

{$IFDEF USE_IXMLHTTP}
      htp.CustHeaders.Add(nvp);
{$ELSE}
      htp.CustomHeaders[nvp.Name] := nvp.Value;
{$ENDIF}
    end;
    var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
    stream_dont_use_resp_stream.o := TMemoryStream.Create;
    var resp := htp.Post(sURL, StringToStringListh(sPostBody).o, stream_dont_use_resp_stream.o, nil, addheads);

    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result := resp.StatusCode = 200;

    if result then
      sOutREsponse := resp.ContentAsString
    else begin
      soutResponse := resp.ContentAsString;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;
end;
{$ENDIF}


function QuickHTTPSGet(sURL: ansistring; out sOutREsponse: string; addHeaders: TArray<TExtraHeader>): boolean;
{$IFDEF USE_IXMLHTTP}
var
  t: ni;
  htp: IXMLhttprequest;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := ComsXMLHTTP30.create();
  try
    htp.open('GET', string(sURL), false, null, null);
    for t := 0 to high(addHeaders) do begin
      htp.setRequestHeader(addHeaders[t].name, addHeaders[t].value);
    end;
    htp.send('');
    result := htp.status = 200;
    if result then
      sOutREsponse := htp.responsetext
    else begin
      soutResponse := htp.responsetext;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;

end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

    for var t:= 0 to high(addHeaders) do begin
      //xxx htp.setRequestHeader(addHead, addHeadValue);
      nvp.Name := addHeaders[t].name;
      nvp.Value := addHeaders[t].value;

{$IFDEF USE_IXMLHTTP}
      htp.CustHeaders.Add(nvp);
{$ELSE}
      htp.CustomHeaders[nvp.Name] := nvp.Value;
{$ENDIF}

    end;
    var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
    stream_dont_use_resp_stream.o := TMemoryStream.Create;
    var resp := htp.Get(sURL, nil, addheads);

    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result := resp.StatusCode = 200;

    if result then
      sOutREsponse := resp.ContentAsString
    else begin
      soutResponse := resp.ContentAsString;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;
end;
{$ENDIF}

function QuickHTTPSGet(sURL: ansistring; out sOutREsponse: string; addHead: string =''; addHeadValue: string = ''): boolean;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := ComsXMLHTTP30.create();
  try
    htp.open('GET', string(sURL), false, null, null);
    if addHead <> '' then
      htp.setRequestHeader(addHead, addHeadValue);
    htp.send('');
    result := htp.status = 200;
    if result then
      sOutREsponse := htp.responsetext
    else begin
      soutResponse := htp.responsetext;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;

end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

    if addHead <> '' then begin
      //xxx htp.setRequestHeader(addHead, addHeadValue);
      nvp.Name := addHead;
      nvp.Value := addHeadValue;
{$IFDEF USE_IXMLHTTP}
      htp.CustHeaders.Add(nvp);
{$ELSE}
      htp.CustomHeaders[nvp.Name] := nvp.Value;
{$ENDIF}
    end;
    var msh: IHolder<TStream> := Tholder<TStream>.create;
    msh.o := TMemoryStream.Create;
    var resp := htp.Get(sURL, nil, addheads);

    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result := resp.StatusCode = 200;

    if result then
      sOutREsponse := resp.ContentAsString
    else begin
      soutResponse := resp.ContentAsString;
    end;
  except
    on e: Exception do begin
      result := false;
      sOutResponse := 'error '+e.message;
    end;
  end;
end;
{$ENDIF}

{$IFDEF USE_IXMLHTTP}
function QuickHTTPSPostOld(sURL: ansistring; PostData: ansistring; ContentType: ansistring = 'application/x-www-form-urlencoded'): ansistring;
var
  htp: IXMLhttprequest;
begin
//  raise Exception.create('carry forward');
  htp := ComsXMLHTTP30.create();
  try
    htp.open('POST', string(sURL), false,null,null);
    htp.setRequestHeader('Accept-Language', 'en');
    //htp.setRequestHeader('Connection:', 'Keep-Alive');
    htp.setRequestHeader('Content-Type', string(ContentType));
    htp.setRequestHeader('Content-Length', inttostr(length(PostData)));
    htp.send(PostData);
    result := ansistring(htp.responsetext);
  finally
//    htp.free;
  end;
end;
{$ENDIF}

function HTTPSGet(sURL: string; referer: string = ''; AddHead: string = ''; AddHeadValue: string = ''): THTTPResults;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
begin
//  raise Exception.create('carry forward');
  result.error := '';
  htp := ComsXMLHTTP30.create();
  try
    try
      htp.open('GET', sURL, false, null, null);
      htp.setRequestHeader('Referer', referer);
      htp.send('');
      result.contentType := htp.getResponseHeader('Content-type');
      result.ResultCode := htp.status;
      if result.resultcode <> 200 then begin
        result.success := false;
        exit;
      end;
      try
        if zpos('text', result.contentType) >=0 then
          result.Body := htp.responseText;
        if zpos('json', result.contentType) >=0 then
          result.Body := htp.responseText;

      except
        result.body := '';
      end;

      result.Success := true;
      result.bodystream := THolder<TStream>.create;
      Result.bodystream.o := olevarianttomemoryStream(htp.responsebody);
    except
      on e: Exception do begin
        result.success := false;
        result.error := e.message;
      end;
    end;
  finally
//    htp.free;
  end;
end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

    if addHead <> '' then begin
      //xxx htp.setRequestHeader(addHead, addHeadValue);
      nvp.Name := addHead;
      nvp.Value := addHeadValue;
{$IFDEF USE_IXMLHTTP}
      htp.CustHeaders.Add(nvp);
{$ELSE}
      htp.CustomHeaders[nvp.Name] := nvp.Value;
{$ENDIF}
    end;
    var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
    stream_dont_use_resp_stream.o := TMemoryStream.Create;
    var resp := htp.Get(sURL,  stream_dont_use_resp_stream.o, addheads);
    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result.Success := resp.StatusCode = 200;
    result.ResultCode := resp.StatusCode;
    result.error := resp.StatusText;
    result.contentType := resp.MimeType;
    result.contentRange := resp.HeaderValue['Content-Range'];
    if result.contentTypeIsText then
      result.Body := resp.ContentAsString;
    result.bodystream := stream_dont_use_resp_stream;

  except
    on e: Exception do begin
      result.error := 'Local error: '+e.Message;
      result.ResultCode := 0;
    end;
  end;
end;
{$ENDIF}
function HTTPSPost(sURL: string; PostData: string; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
begin
//  raise Exception.create('carry forward');
  result.error := '';
  htp := ComsXMLHTTP30.create();
  try
    htp.open('POST', sURL, false,null,null);
    htp.setRequestHeader('Accept-Language', 'en');
    htp.setRequestHeader('Connection:', 'Keep-Alive');
    htp.setRequestHeader('Content-Type', ContentType);
    htp.setRequestHeader('Content-Length', inttostr(length(PostData)));
    htp.send(PostData);
    result.ResultCode := htp.status;
    result.Body := htp.responsetext;

  finally
//    htp.free;
  end;
end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

//    if addHead <> '' then begin
//      nvp.Name := addHead;
//      nvp.Value := addHeadValue;
//      htp.CustHeaders.Add(nvp);
//    end;
    var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
    stream_dont_use_resp_stream.o := TMemoryStream.Create;
    var resp := htp.Post(sURL, POstData, stream_dont_use_resp_stream.o, addheads);
    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result.Success := resp.StatusCode = 200;
    result.ResultCode := resp.StatusCode;
    result.error := resp.StatusText;
    result.contentType := resp.MimeType;
    result.contentRange := resp.HeaderValue['Content-Range'];
    if result.contentTypeIsText then
      result.Body := resp.ContentAsString;
    result.bodystream := stream_dont_use_resp_stream;

  except
    on e: Exception do begin
      result.error := 'Local error: '+e.Message;
      result.ResultCode := 0;
    end;
  end;
end;
{$ENDIF}

function HTTPSPost(sURL: string; PostData: TDynByteArray; ContentType: string = 'application/x-www-form-urlencoded'): THTTPResults;overload;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
begin
//  raise Exception.create('carry forward');
  result.error := '';
  htp := ComsXMLHTTP30.create();
  try
    htp.open('POST', sURL, false,null,null);
    htp.setRequestHeader('Accept-Language', 'en');
    htp.setRequestHeader('Connection:', 'Keep-Alive');
    htp.setRequestHeader('Content-Type', ContentType);
    htp.setRequestHeader('Content-Length', inttostr(length(PostData)));
    htp.send(PostData);
    result.ResultCode := htp.status;
    result.Body := htp.responsetext;

  finally
//    htp.free;
  end;

end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  nvp: System.Net.URLclient.TNameValuePair;
  addheads: TArray<System.Net.URLclient.TNameValuePair>;
begin
{$IFDEF LOG_HTTP}
  Debug.Log(sURL);
{$ENDIF}

  htp := System.Net.HttpClient.THTTPClient.create();
  try
    //xxxx htp.open(method, sURL, false, null, null);

//    if addHead <> '' then begin
//      nvp.Name := addHead;
//      nvp.Value := addHeadValue;
//      htp.CustHeaders.Add(nvp);
//    end;
    var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
    stream_dont_use_resp_stream.o := TMemoryStream.Create;
    var sendStream : IHolder<TStream> := THolder<TStream>.create;
    sendStream.o := TMemoryStream.Create;
    Stream_GuaranteeWrite(sendstream.o, @postdata[low(postdata)], length(postdata));
    var resp := htp.Post(sURL, sendStream.o, stream_dont_use_resp_stream.o, addheads);
    //xxx htp.send(sPostBody);
    //xxxx result := htp.status = 200;
    result.Success := resp.StatusCode = 200;
    result.ResultCode := resp.StatusCode;
    result.error := resp.StatusText;
    result.contentType := resp.MimeType;
    result.contentRange := resp.HeaderValue['Content-Range'];
    if result.contentTypeIsText then
      result.Body := resp.ContentAsString;
    result.bodystream := stream_dont_use_resp_stream;

  except
    on e: Exception do begin
      result.error := 'Local error: '+e.Message;
      result.ResultCode := 0;
    end;
  end;
end;
{$ENDIF}


{ Tcmd_HTTPS }

procedure Tcmd_HTTPS.DoExecute;
{$IFDEF USE_IXMLHTTP}
var
  htp: IXMLhttprequest;
  sMeth: string;
begin
  inherited;
  if request.method = mGet then begin
    try
    {$IFDEF LOG_HTTP}
      Debug.Log(sURL);
    {$ENDIF}
      htp := ComsXMLHTTP30.create();
      try
        if self.request.method = THttpsMethod.mPost then
          sMeth := 'POST'
        else
          sMeth := 'GET';


        htp.open(sMeth, self.request.url, false, null, null);

        https_setheaderifset(htp, 'Content-Length', inttostr(request.contentlength));
        https_setheaderifset(htp, 'Content-Type', request.contenttype);
        https_setheaderifset(htp, 'Accept-Ranges', request.acceptranges);
        https_setheaderifset(htp, 'Range', request.range);
        https_setheaderifset(htp, 'Referer', request.referer);
        https_setheaderifset(htp, 'Cookie', request.Cookie);
        https_setheaderifset(htp, 'CookieEx', request.Cookie);
        https_setheaderifset(htp, request.addHead, request.addHeadValue);

        if self.request.method = mGet then
          htp.send('')
        else
          htp.send(request.postBody);

        results.ResultCode := htp.status;
        results.contentRange := htp.getResponseHeader('Content-Range');
        results.contentType := htp.getResponseHeader('Content-Type');
        var s := htp.getResponseHeader('Set-Cookie');
        if s <> '' then  begin
          results.AddCookieHeader(s);
        end;
        results.bodystream := THolder<TStream>.create;
        self.Results.bodystream.o := olevarianttomemoryStream(htp.responsebody);

//        results.Body := htp.responsetext;
      except
        on e: Exception do begin
          ErrorMessage := e.message;
          results.Body := 'error '+e.message;
        end;
      end;
    finally
    end;
  end else
  if request.method = mPost then begin
    results := HTTPSPost(request.url, request.PostData, request.contenttype);
  end;

end;
{$ELSE}
var
  htp: System.Net.HttpClient.THTTPClient;
  sMeth: string;
  nvp: System.net.urlclient.TNAmeValuePair;
  addHEads: TArray<System.Net.URLClient.TNameValuePair>;
  procedure AddHead(sName, sValue: string);
  begin
    if sValue = '' then exit;
//    if sValue = '0' then exit;
    setlength(addHeads, length(addHEads)+1);
    addHEads[high(addHeads)].Name := sname;
    addHEads[high(addHeads)].value := svalue;
  end;
  function GetCustomheader(resp: IHTTPResponse; sName: string): string;
  begin
    if resp.ContainsHeader(sName) then
      result := resp.HeaderValue[sName];
  end;
begin
  inherited;
  if request.method = mGet then begin
    try
    {$IFDEF LOG_HTTP}
      Debug.Log(sURL);
    {$ENDIF}
      htp := System.Net.HttpClient.THTTPClient.create();
      try
        var stream_dont_use_resp_stream: IHolder<TStream> := Tholder<TStream>.create;
        stream_dont_use_resp_stream.o := TMemoryStream.Create;


        AddHead('Content-Length',inttostr(request.contentlength));
        AddHead('Content-Type', request.contenttype);
        AddHead('Accept-Ranges', request.acceptranges);
        AddHead('Range', request.range);
        AddHead('Referer', request.referer);
        AddHead('Cookie', request.Cookie);
        AddHead('CookieEx', request.Cookie);
        AddHead(request.addHead, request.addHeadValue);

        var resp := htp.Get(self.request.url, stream_dont_use_resp_stream.o, addHEads);

        results.success := resp.statuscode = 200;
        results.ResultCode := resp.StatusCode;
        results.contentRange := GetCustomHeader(resp, 'Content-Range');
        results.contentType := GetCustomHeader(resp,'Content-Type');
        var s := GetCustomHeader(resp,'Set-Cookie');
        if s <> '' then  begin
          results.AddCookieHeader(s);
        end;
        self.Results.bodystream := stream_dont_use_resp_stream;
        if self.Results.ContentTypeIsText then
          results.Body := resp.ContentAsString;


//        results.Body := htp.responsetext;
      except
        on e: Exception do begin
          ErrorMessage := e.message;
          results.Body := 'error '+e.message;
        end;
      end;
    finally
    end;
  end else
  if request.method = mPost then begin
    results := HTTPSPost(request.url, request.PostData, request.contenttype);
  end;
end;
{$ENDIF}

procedure Tcmd_HTTPS.Init;
begin
  inherited;
  request.ContentType := 'application/x-www-form-urlencoded';

end;

{$IFDEF USE_IXMLHTTP}
procedure https_SetHeaderIfSet(htp: IXMLHttpRequest; sheader: string; sValue: string);
begin
  if sValue = '' then
    exit;
  htp.setRequestHeader(sHeader, sValue);
end;
{$ENDIF}


{ Tcmd_HTTPsToFile }

procedure Tcmd_HTTPsToFile.DoExecute;
begin
  //inherited;
  request.url := URL;
  if (not IgnoreIftargetExists) or (not FileExists(LocalFile)) then begin
    inherited;
    var fs := TfileStream.create(LocalFile, fmCreate);
    try
      Stream_GuaranteeCopy(self.Results.bodystream.o, fs);
    finally
      fs.free;
    end;

  end;
end;

initialization

{$IFDEF MSWINDOWS}
if fileexists(dllpath+'ssleay32.dll') then begin
  IdOpenSSLSetLibPath(DLLPath);
  IdSSLOpenSSL.LoadOpenSSLLibrary;
end;
{$ENDIF}

end.
