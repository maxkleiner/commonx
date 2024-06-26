unit MSSQLStorageString;

interface

uses
  variants, stringx, systemx, sysutils;

function GetStorageString(vT: integer; v: variant): string;
function gss(vT: integer; v: variant): string;inline;
function GetVariantStorage(v: variant): string;
function gvs(v: variant): string;inline;




implementation

function MSSQLEscape(s: string): string;
begin
  result := s;
  result := stringreplace(result, '''', '''''', [rfReplaceAll]);
  result := stringreplace(result, '\', '\\', [rfReplaceAll]);
  result := stringreplace(result, '"', '\"', [rfReplaceAll]);
//NOT OK  result := stringreplace(result, '''', '\''', [rfReplaceAll]);
  result := stringreplace(result, #13#10, '''+CHAR(13)+CHAR(10)+''', [rfReplaceAll]);
  result := stringreplace(result, #13, '''+CHAR(13)+''', [rfReplaceAll]);
  result := stringreplace(result, #10, '''+CHAR(10)+''', [rfReplaceAll]);

end;


function gss(vT: integer; v: variant): string;inline;
begin
  result := GetStorageString(vT, v);
end;

function GetStorageString(vT: integer; v: variant): string;
begin
  if vt=varBoolean then begin
    result := BoolToStrEx(v,'1','0');
  end else
  if vt=varInteger then begin
    result := inttostr(int64(v));
  end else
  if vt=varInt64 then begin
    result := inttostr(int64(v));
  end else
  if VarIsNull(v) then begin
    result := 'NULL';
  end else
  if (vt=varSTring) or (vt=varUString) or (vt=varOleStr) then begin
    result := Quote(MSSQLEscape(vartostr(v)),'''');
  end else
  if vt = varDate then begin
    result := Quote(datetoMYSQLDate(v),'''');
  end else
  if (vT = varDouble) or (vt=varSingle) then
  begin
    result := VarToStr(double(v));
    IF result = 'INF' then
      result := '0.0';
    if result = 'NAN' then
      result := '0.0';
  end else begin
    result := VarToStr(v);
  end;
//  result := stringReplace(result, '\', '\\', [rfReplaceAll]);

//  end else begin
//    raise exception.create('vartype not handled in mysqlstoragestring.getstoragestring');
//  end;



end;
function GetVariantStorage(v: variant): string;
begin
  result := GetStorageString(vartype(v),v);
end;
function gvs(v: variant): string;inline;
begin
  result := GetVariantStorage(v);
end;



end.
