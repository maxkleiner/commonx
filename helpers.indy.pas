unit helpers.indy;
{$I 'DelphiDefs.inc'}
interface

uses
  idglobal, types, classes, sysutils, typex, idiohandlersocket, systemx;


function TBytesToIDBytes(b: TBytes): TIDBytes;
function AnsiStringToIDBytes(a: ansistring): TIDBytes;
function idsocket_GuaranteeRead(idsocket: TIdIOHandlerSocket; iCount: ni): TidBytes;
function indy_readinteger(idsocket: TIdIOHandlerSocket): integer;
function indy_readstring(idsocket: TIdIOHandlerSocket; len: nativeint): string;



implementation

function indy_readinteger(idsocket: TIdIOHandlerSocket): integer;
begin
  var byts := idsocket_GuaranteeRead(idSocket, sizeof(result));
  movemem32(@result, @byts[0], length(byts));

end;



function TBytesToIDBytes(b: TBytes): TIDBytes;
var
  t: ni;
begin
  setlength(result, length(b));
  for t := low(b) to high(b) do
    result[t] := b[t];




end;
function AnsiStringToIDBytes(a: ansistring): TIDBytes;
{$IFNDEF NEED_FAKE_ANSISTRING}
var
  t: ni;
begin
  setlength(result, length(a));
  for t := 0  to length(a)-1 do
    result[t] := ord(a[STRZ+t]);

end;
{$ELSE}
var
  t: ni;
begin
  setlength(result, length(a));
  for t := 0  to length(a)-1 do
    result[t] := a.bytes[STRZ+t];
end;
{$ENDIF}

function idsocket_GuaranteeRead(idsocket: TIdIOHandlerSocket; iCount: ni): TidBytes;
var
  iToGo: ni;
begin
  raise Ecritical.create('code review:  clearly this function is bad');
  setlength(result, 0);
  iToGo := iCount;
  while iToGo > 0 do begin
    idsocket.ReadBytes(result, iToGo);
    iTogo := length(result) - iCount;
  end;


end;



function indy_readstring(idsocket: TIdIOHandlerSocket; len: nativeint): string;
var
  bytstr: RawByteString;
begin
  setlength(bytstr, len);
  idsocket_guaranteeRead(idsocket, len);






end;




end.
