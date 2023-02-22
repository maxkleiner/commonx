unit WebDispatchMain;
{$DEFINE NO_HIT}
interface
uses
  debug, systemx, tickcount, RequestInfo, variants, MTDTInterface, webresource, Dataobjectservices, Dataobject, webconfig, sysutils, templates, quickqueries, multibuffermemoryfilestream, classes, speech, node;

type
  EUserError = class(Exception);

function DispatchMainServerRequest(rqInfo: TrequestInfo): boolean;

procedure WRQ_DBTest(rqInfo: TRequestInfo);
procedure WRQ_Logout(rqInfo: TRequestInfo);
procedure GET_Home(rqInfo: TRequestInfo);
procedure WRQ_GET_UserManagement(rqINfo: TRequestInfo);
procedure WRQ_Get_AddUser(rqInfo: TRequestInfo);



function QuickSessionX(rqInfo: TrequestInfo): TDataObject;
procedure LoadStandardTemplate(rqInfo: TRequestInfo);



implementation

uses
  WebFunctions, CommonRequests, stringx, stringx.ansi,
  ServerInterface, ErrorHandler, Roles,
  Exceptions, SimpleMail,
  SystemQueries, RequestDispatcher, WebString, Rights, AsyncClasses,
  DataObjectDefinitions;

function DispatchMainServerRequest(rqInfo: TrequestInfo): boolean;
var
  sHost: ansistring;
  sDoc: ansistring;
  sTemp, sLeft, sRight: ansistring;
  rqf: TRequestDispatchFunction;
  arqf: TAsyncwebProcedure;
  iHit: integer;
begin
{$IFDEF ENABLE_NODE}
  CheckNodeBuild;
{$ENDIF}
  rqInfo.DTID := 0;
  rqInfo.DoTransactions := true;
  result := false;
  rqInfo.Request.AddDirectoriesAsParameters;
  while splitstring(rqInfo.request.Document, '/_', sLeft, sright) do begin
    SplitString(sRight, '/', sTemp, sright);
    rqInfo.request.Document := sLeft+'/'+sRight;
  end;

  sDoc := lowercase(rqInfo.request.document);
  sDoc := stringreplace(sDoc, #10, '', [rfReplaceAll]);

  iHit := {$IFDEF NO_HIT}123456;{$ELSE}xxrqInfo.Server.GetNextID(CKEY_NEW_HIT, 0);{$ENDIF}
  rqInfo.request.AddParam('hit', inttostr(iHit), pcheader);
  rqInfo.LoadVars;
  //------------------------------------------------

  try
    //find a function that handles the page
    rqf := RQD.GetHandler(sDoc, rqInfo.Request.Command);
    arqf := RQD.GetAsyncHandler(sDoc, rqInfo.Request.Command);
    //if found a function execute it
    if assigned(rqf) then begin
      result := true;
      if rQInfo.request.hasparam('async') then
        AsyncAdapt(rqInfo, rqf)
      else
        rqf(rqInfo);
    end else
    if assigned(arqf) then begin
      result := true;
      StartAsync(rqInfo, arqf);
    end;

    //lazy dispatch
    if not result then begin
      if lowercase(ExtractFileExt(rqInfo.request.document)) = '.ms' then begin
        sTemp := changefileext(copy(rqInfo.request.document, 2, length(rqInfo.request.document)), '.html');
        if FileExists(webserverconfig.ExternalResourcePath+sTemp) then begin
          rqInfo.Request.Document := changefileext(rqInfo.Request.Document, '.html');
          result := true;
          WRQ_LazyDispatch(rqInfo);

        end;
      end;

    end;


    if rqInfo.request.HasParam('AutoGoto') then begin
      rqINfo.response.location := rqInfo.request['autogoto'];
    end;

  finally
(*    on E:Exception do begin
      rqInfo.Response.content.text := E.Message;
      rqInfo.response.contentlength := length(rqInfo.response.content.text);
      rqInfo.response.content.add('<!--'+rqInfo.response.DebugLog.text+'//-->');

      result := true;
    end;*)
  end;

//  rqInfo.Response.





end;






procedure GET_Home(rqInfo: TRequestInfo);
var
  doSession: TDataObject;
begin
  doSession := QuickSession(rqInfo);
(*  if doSession.assoc['user']['roleid'].AsVariant < 3 then begin
    rqInfo.response.location := 'my_school.ms?sessionid='+rqInfo.SessionHash;
    exit;
  end;*)


  LoadWebResourceAndMergeWithBestTemplate(rqInfo,'home.html','');


  rqInfo.response.ObjectPool['session'] := doSession;
  rqInfo.response.ObjectPool['user'] := RecordQuery(rqInfo, 'SELECT * FROM USER WHERE USERID='+doSession['UserID'].AsString);
end;




function QuickSessionX(rqInfo: TrequestInfo): TDataObject;
begin
  result := RecordQuery(rqInfo, 'SELECT * FROM SESSION WHERE SESSIONID='+inttostr(rqInfo.sessionid));
end;

procedure WRQ_GET_UserManagement(rqINfo: TRequestInfo);
begin
  LoadWebResourceAndMergeWithBestTEmplate(rqInfo,'user_management.html','');

  rqInfo.response.objectpool['users'] := QueryX(rqInfo, 'SELECT u.*, r.Name as RoleNAme from USER u LEFT JOIN Role r ON (u.roleid=r.roleid) ORDER BY LastName, FirstName');

end;

procedure WRQ_Get_AddUser(rqInfo: TRequestInfo);
begin
  LoadWebResourceAndMergeWithBestTEmplate(rqInfo,'edit_user.html','');
  rqInfo.response.objectpool['user'] := New(rqInfo, 'TdoUser', 0);
  rQINfo.request['userid'] := rqInfo.response.objectpool['user'].token.params[0];
  rQINfo.response.varpool['userid'] := rqInfo.response.objectpool['user'].token.params[0];

  rqInfo.Response.ObjectPool['roles'] := QueryX(rqInfo, 'SELECt * from Role', true);
  rqInfo.Response.ObjectPool['distributors'] := QueryX(rqInfo, 'SELECT * from distributor', true);
end;




procedure WRQ_DeleteUser(rqInfo: TrequestINfo);
begin
  UpdateQuery(rqInfo, 'DELETE FROM user WHERE userid='+rqInfo.request['userid']);
  GotoBookMark(rQInfo);

end;

procedure WRQ_Get_Clients(rqInfo: TrequestInfo);
begin
  rqInfo.response.objectpool['clients'] := QueryX(rqInfo, 'SELECT * from CLIENTS');
  LoadStandardTemplate(rqInfo);

end;

procedure WRQ_Client_Add(rqInfo: TRequestInfo);
begin
  LoadWebResourceAndMergeWithBestTemplate(rqInfo,'client_edit.html');
  rqInfo.response.objectpool['client'] := New(rqInfo, 'TdoClient', 0);
  rQINfo.response.varpool['clientid'] := rqInfo.response.objectpool['client'].token.params[0];
end;




procedure LoadStandardTemplate(rqInfo: TRequestInfo);
var
  sTemp: ansistring;
begin
  sTemp := changefileext(copy(rqInfo.request.document, 2, length(rqInfo.request.document)), '.html');
  if FileExists(webserverconfig.ExternalResourcePath+sTemp) then begin
    LoadWebResourceAndMergeWithBestTemplate(rqInfo, sTemp);
  end;
end;

procedure WRQ_POST_Client(rqInfo: TRequestInfo);
var
  doClient: TDataObject;
begin
  doClient := Ghost(rQInfo, 'TdoClient', strtoint(rqInfo.Request['clientid']));
  rqINfo.response.objectpool['client'] := doClient;
  WebObjectFill(rqInfo, 'client');


  SaveQuery(rqInfo, doClient, 'CLIENTS', ['clientid']);

  rqInfo.response.location := 'clients.ms?sessionid='+rQInfo.sessionhash;

end;

procedure WRQ_Client_Delete(rqInfo: TrequestINfo);
begin
  UpdateQuery(rqInfo, 'DELETE FROM clients WHERE clientid='+rqInfo.request['clientid']);
  rqINfo.response.location := 'clients.ms?sessionid='+rqInfo.sessionhash;

end;




procedure WRQ_Conference_Delete(rqInfo: TrequestINfo);
begin
  UpdateQuery(rqInfo, 'DELETE FROM conf WHERE confid='+rqInfo.request['confid']);
  rqINfo.response.location := 'confs.ms?sessionid='+rqInfo.sessionhash;

end;

procedure WRQ_POST_Conference(rqInfo: TRequestInfo);
var
  doConf: TDataObject;
begin
  doconf := Ghost(rQInfo, 'TdoConference', strtoint(rqInfo.Request['confid']));
  rqINfo.response.objectpool['conf'] := doConf;
  WebObjectFill(rqInfo, 'conf');


  SaveQuery(rqInfo, doConf, 'conf', ['confid']);

  rqInfo.response.location := 'confs.ms?sessionid='+rQInfo.sessionhash;

end;

//------------------------------------------------------------------------------
function BuildWhereClause(rqInfo: TrequestInfo; bExtended: boolean = false): ansistring;
var
  t,u: integer;
  sLeft, sRight: ansistring;
  sValue: ansistring;
begin
  result := '';
  u := 0;
  for t:=0 to rqInfo.request.paramPatternCount['where.']-1 do begin
    if result = '' then
      SplitString(rqInfo.request.paramNamesByPatternMatch['where.', t], '.', sLeft, sRight);
      sValue := rqInfo.request.ParamsByPatternMatch['where.', t];
      if sValue <> '' then begin
        if u>0 then
          result := result + 'AND'
        else
          result := ' WHERE ';

        result := result+sRight+'="'+sValue+'" ';

        inc(u);
      end;
  end;

  for t:=0 to rqInfo.request.paramPatternCount['likewhere.']-1 do begin
    if result = '' then
      SplitString(rqInfo.request.paramNamesByPatternMatch['likewhere.', t], '.', sLeft, sRight);
      sValue := rqInfo.request.ParamsByPatternMatch['likewhere.', t];
      if sValue <> '' then begin
        if u>0 then
          result := result + 'AND'
        else
          result := ' WHERE ';

        result := result+sRight+' like "%'+sValue+'%" ';

        inc(u);
      end;
  end;
end;



procedure WRQ_DBTest(rqInfo: TRequestInfo);
var
  obj: TDataObject;
  t: cardinal;
begin
  rqInfo.DoTransactions := true;
  t := getticker;


  UpdateQuery(rqInfo, 'DELETE from TypeTest');
  for t:= 0 to 200 do begin
    obj := Ghost(rqInfo, 'TdoTypeTest', t);
    obj['Date'].Asvariant := date;
    SaveQuery(rqInfo, obj, 'TypeTest', ['ID']);
  end;

  rqInfo.Server.QueryMap(rqInfo.Response.DOCache, obj, 'SELECT * from TypeTest ORDER BY ID', rqInfo.SessionID, 300000, true, 0, 'TdoTestList', 0, nil, 'TdoTypeTest', 1);
  rqInfo.response.objectpool['obj'] := obj;

  rQInfo.Commit;
  for t:= 0 to obj.objectcount-1 do begin
    obj.obj[t]['Date'].Asvariant := now;
    SaveQuery(rqInfo, obj.obj[t], 'TypeTest', ['ID']);
  end;

  LoadwebResource(rqInfo, 'dbtest.html');

end;

procedure WRQ_Logout(rqInfo: TRequestInfo);
begin
  UpdateQuery(rqInfo, 'DELETE from Session where SessionID='+inttostr(rqInfo.sessionid), false);
  rqInfo.response.location := 'login.ms';

end;


procedure WRQ_Forward(rqInfo: TRequestInfo);
var
  sGO: ansistring;
begin
  sGo := rqInfo.request['go'];
  sGo := sGo + '?'+rqInfo.Request.RebuildInlineParameters;
  SendJavaRedirect(rqInfo, sGo, 'Running your report...',false, true);


end;

procedure WRQ_Default(rqInfo: TRequestInfo);
begin
//  rQInfo.response.location := '/default.ms';
//  rqInfo.response.resultcode := 301;

//  rqINfo.request.document := '/default.ms';


//  rqinfo.response.NeedsProcessing := false;


end;

procedure WRQ_Test(rqInfo: TRequestInfo);
(*var
  i: int64;*)
begin
(*  //test keybot
  rqInfo.response.nodebug := true;
  rqInfo.response.contenttype := 'text/plain';

  try
    i := rqInfo.Server.GetNextID(9999,0);
    rqInfo.response.Content.Add('ID=OK');
  except
    rqInfo.response.Content.Add('ID=FAIL');
  end;

  try
    Query(rqInfo, 'SELECT * from user limit 10');
    rqInfo.response.Content.Add('DATA=OK');
  except
    rqInfo.response.Content.Add('DATA=FAIL');
  end;

*)
end;


procedure WRQ_GET_Movie(rqInfo: TRequestInfo);
var
  sFile: string;
  rangeStart, rangeEnd: string;
begin
  sFile := rqInfo.request.params['movie'];
  sFile := WebServerConfig.ExternalResourcePath+'LocalMovies\'+sFile;
  if fileexists(sFile) then begin
    rqINfo.response.contenttype := 'video/mp4';

    if rqInfo.Request.HasParam('range') then begin
      Debug.Log(rqInfo.request.RawText);
      rqInfo.response.ResultCode := 206;
      rangeStart := rqInfo.request.params['range'];

      splitstring(rangestart,'bytes=', rangeend, rangeStart);
      splitstring(rangestart,'-', rangestart, rangeend);
      rangestart := trim(rangestart);
      //yNAtural(rangeStart);
      rangeend := trim(rangeEnd);
      if rangeStart = '' then
        rangeStart := '0';
      if rangeEnd = '' then
        rangeEnd := inttostr(strtoint64(rangeStart)+65536);

      rqInfo.Response.contentstream := TMultiBufferMemoryFileStream.Create(sFile, fmOpenREad+fmShareDenyNone);;
      rqInfo.response.contentStream.Seek(strtoint64(rangestart), soBeginning);
      rqInfo.Response.RangeStart := strtoint64(trim(rangestart));
      rqInfo.Response.RangeEnd := strtoint64(trim(rangeEnd));
      rqInfo.response.contentLength := rqInfo.Response.RangeEnd-rqInfo.Response.RangeStart;


    end else begin
      rqInfo.response.contentstream := TMultiBufferMemoryFileStream.Create(sFile, fmOpenREad+fmShareDenyNone);
//      rqInfo.Response.RangeStart := 0;
//      rqInfo.response.RangeEnd := 256000;
    end;
  end;
end;


initialization

RQD.AddRequest('/forward.ms', 'get', WRQ_Forward);
//RQD.AddRequest('/default.ms', 'get', WRQ_Default);
//RQD.AddRequest('/', 'get', WRQ_Default);
RQD.AddRequest('/test', 'get', WRQ_Test);
RQD.AddRequest('/test', '', WRQ_Test);
RQD.AddRequest('/home.ms', 'get', GET_Home);
RQD.AddRequest('/user_management.ms', 'get', WRQ_GET_UserManagement);
RQD.AddRequest('/get_movie.mp4', 'get', WRQ_GET_MOVIE);



end.

