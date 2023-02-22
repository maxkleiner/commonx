unit WebLogin;

interface

uses RequestInfo, WebConfig, mysqlstoragestring,
  webresource, dataobject, stringx,
  dataobjectservices, sysutils, errorhandler,
  webstring, MTDTInterface, systemx,
  variants, requestdispatcher;

procedure POST_Login(rqInfo: TRequestInfo);
procedure Get_Logout(rqInfo: TRequestInfo);



implementation

uses SimpleMail;

procedure Get_Logout(rqInfo: TRequestInfo);
begin
  try
    MTDTInterface.QuickSession(rqinfo);
    MTDTInterface.UpdateQuery(rqInfo, 'delete from session where sessionid='+gvs(rqInfo.SessionID));
  except
  end;

  rqInfo.Response.AddCookie('sessionid','');
  rqInfo.response.location := 'k_book_search.ms';


end;

procedure POST_Login(rqInfo: TRequestInfo);
var
  doSession: TDataOBject;
  sEmail: string;
  sPhone: string;
  sPin: string;
  sPassword: string;
begin
  try
    if (rqInfo.request['loginname'] = '') or (rqInfo.request['password'] = '') then
      raise Exception.create('no login information submitted');

    var p := MTDTInterface.QueryfnV(rqInfo,'select password from user where (email='+gvs(rqInfo.request['loginname'])+') or (nickname='+gvs(rqInfo.request['loginname'])+')');
    var u := MTDTInterface.QueryfnV(rqInfo,'select userid from user where (email='+gvs(rqInfo.request['loginname'])+') or (nickname='+gvs(rqInfo.request['loginname'])+')');
    if varisnull(p) or varisNull(u) then
      rqInfo.response.content.Add('wrong username or password')
    else begin
      rqInfo.sessionid := rqInfo.server(0).getNextID('session');
      MTDTInterface.UpdateQuery(rqinfo, 'insert into session values ('+gvs(rqInfo.sessionid)+','+gvs(u)+',now(),0)');
      rqinfo.response.addcookie('sessionid',rqInfo.sessionhash);
      rqInfo.response.Location := rqInfo.request['goto'];
    end;

  except
    on E: Exception do begin
      if pos('keybot', lowercase(e.message))>0 then begin
        rqInfo.response.content.clear;
        rqInfo.response.location := 'login.ms?message='+encodeWebString('The system is temporarily unable to allow logins pending maintenance.  We apologise for the inconvenience.  The webmaster has been paged with this information.')+'&details='+encodewebstring(e.Message);
      end else begin
        rqInfo.response.content.clear;
        rqInfo.response.location := 'login.ms?message='+encodeWebString('Could not log you in.  Please check your information and try again')+'&details='+encodewebstring(e.Message);
      end;
    end;
  end;
end;


initialization

RQD.AddRequest('/post_login.ms', 'post', POST_Login);
RQD.AddRequest('/logout.ms', 'get', get_Logout);

end.
