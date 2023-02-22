unit ut_https;

interface

uses
  https, debug, httptypes;




procedure RunAllTests;

implementation


procedure Test1;
var
  textresponse: string;
begin
  Debug.Log('HTTPS Test 1');
  if https.QuickHTTPSGet('https://cloud.comparatio.com/monitoratio/deploy.txt', textresponse) then begin
    debug.Log('success: '+textresponse);
  end else begin
    debug.Log('fail');
  end;
end;


procedure Test2;
var
  textresponse: string;
begin
  Debug.Log('HTTPS Test 2');
  var c := Tcmd_HTTPS.create;
  c.Request.method := mGet;
  c.Request.url := 'https://cloud.comparatio.com/monitoratio/deploy.txt';
  c.Start;
  c.WaitFor;
  if c.Results.Success then begin
    textREsponse := c.Results.Body;
    debug.Log('success: '+textresponse);
  end else begin
    debug.Log('fail');
  end;
end;


procedure RunAllTests;
begin
//  Test1;
//  Test2;

end;



end.
