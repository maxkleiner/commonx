unit HelpersDB_MySQL;

interface

uses
  abstractdb, mysqlstoragestring;


function RowToValues_DBC_NoParens(cur: TAbstractDBCursor): string;

implementation


function RowToValues_DBC_NoParens(cur: TAbstractDBCursor): string;
var
  x: integer;
  v: variant;
  sRow: string;
begin
  result := '';
//  for y:= 0 to ds.RowCount-1 do begin
    sRow := '';
    for x:= 0 to cur.FieldCount-1 do begin
      if x > 0 then
        sRow := sRow+','+mysqlstoragestring.gvs(cur.FieldsByIndex[x])
      else begin
//        if bIncludeSEFields then
//          sRow := '0,'+mysqlstoragestring.gvs(cur.FieldsByIndex[x])
//        else
          sRow := ''+mysqlstoragestring.gvs(cur.FieldsByIndex[x])
      end;
    end;

  result := sRow;
end;


end.
