unit mysqlstoragestring;
{$DEFINE FORCE_TRIMMED_STRINGS} //Unidac Bug
interface

uses
  variants, stringx, systemx, sysutils;

function GetStorageString(vT: integer; v: variant): string;
function gss(vT: integer; v: variant): string;inline;
function GetVariantStorage(v: variant): string;
function gvs(v: variant): string;inline;
function GetStorageStringClickHouse(vT: integer; v: variant): string;
function gvsCH(v: variant): string;
function chUniCode(s: string): string;
function chRegEx(v: variant): string;




implementation



function chUniCode(s: string): string;
begin
  result := '';
  for var t:=low(s) to high(s) do begin
    if ord(s[t]) < 256 then
      result := result + s[t]
    else
      result := result + '\x{'+inttohex(ord(s[t]),4)+'}';
  end;
end;


function gss(vT: integer; v: variant): string;inline;
begin
  result := GetStorageString(vT, v);
end;

function GetStorageString(vT: integer; v: variant): string;
begin

  if VarIsNull(v) then begin
    result := 'NULL';
  end else
  if (vt=varSTring) or (vt=varUString) or (vt=varOleStr) then begin
    var s := vartostr(v);
    {$IFDEF FORCE_TRIMMED_STRINGS}
    s := trim(s);
    {$ENDIF}

    result := Quote(SQLEscape(s),'''');
  end else
  if vt = varDate then begin
    result := Quote(datetoMYSQLDate(v),'''');
  end else
  if vt = varDouble then begin
    result := floatprecision(double(v),8);
  end else
  if vt = varBoolean then begin
    result := BooltoStrEx(v,'1','0');
  end else
  if vt = varSingle then begin
    result := floatprecision(single(v),8);
  end else
  begin

    result := VarToStr(v);
    IF result = 'INF' then
      result := '0.0';
    if result = 'NAN' then
      result := '0.0';
  end;

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

function chRegEx(v: variant): string;
begin
  result := gvs(chUnicode(v));
{  var res := result;
  result := '';
  for var t:=low(res) to high(res) do begin
    if res[t] = '\' then
      result := result + res[t]+res[t]
    else
      result := result + res[t];

  end;}
end;



function GetStorageStringClickHouse(vT: integer; v: variant): string;
begin
  //clickhouse unicode characters seem to require AMP encoding going IN but come out as expected
  if (vt=varSTring) or (vt=varUString) or (vt=varOleStr) then begin
    var s := vartostr(v);
    {$IFDEF FORCE_TRIMMED_STRINGS}
    s := trim(s);
    {$ENDIF}
    result := Quote(SQLEscape(s),'''');
  end else begin
    result := GetStorageString(vT,v);
  end;

end;

function gssCH(vT: integer; v: variant): string;
begin
  result := GetStorageStringClickHouse(vT,v);
end;



function gvsCH(v: variant): string;
begin
  result := GetStorageStringClickhouse(VarType(v),v);
end;





end.
