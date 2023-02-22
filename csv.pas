unit csv;

interface

uses mysqlstoragestring, stringx, systemx,storageenginetypes, classes, sysutils;


procedure RowSetToCSV(rs: TSERowSet; sFile: string);


implementation

procedure RowSetToCSV(rs: TSERowSet; sFile: string);
begin

  var slh := NewStringListH;
  var sl := slh.o;
  var slTemp := NewStringListH;
  for var ff := 0 to rs.fieldcount-1 do begin
    slTemp.o.Add(gvs(rs.fielddefs[ff].sName));
  end;
  sl.add(unparsestring(slTemp.o));
  rs.Iterate(procedure begin
    slTemp := NewstringListH;
    for var ff := 0 to rs.fieldcount-1 do begin
      slTemp.o.Add(gvs(rs.fielddefs[ff].sName));
    end;
  end);

  sl.SavetoFile(sFile);

end;


end.
