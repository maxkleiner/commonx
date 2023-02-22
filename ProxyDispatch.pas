unit ProxyDispatch;


interface

uses RequestInfo, WebConfig, HTTPCLient, sysutils, webstring, stringx, stringx.ansi, webfunctions, dialogs, ExceptionsX, filecache, ExtendedProxyDispatch;

function DispatchProxyRequest(rqInfo: TRequestInfo): boolean;


implementation

function DispatchProxyRequest(rqInfo: TRequestInfo): boolean;
var
  sDoc: ansistring;
begin
  result := ExtendedProxyDispatch.dispatchProxyRequest(rqInfo);

  sDoc := lowercase(rqInfo.request.document);
  rqINfo.request.default('template', '');

  rqInfo.SetupDefaultVarPool;
end;





end.
