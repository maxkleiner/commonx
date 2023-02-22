unit RestDB;

interface

uses
  sysutils, httptypes,AbstractDB, systemx, typex, stringx, httpclient_2020,storageenginetypes, data.db;

type
  TRestDB = class(TAbstractDB)
  private
    function GetURL: string;
  public
    httpcli: TStatefulBrowser;
    function ReadQuery(sQuery: string): TSERowSet;overload;override;
    function FunctionQuery(sQuery: string; sDefault: int64): int64;overload;override;
    function FunctionQuery(sQuery: string; rDefault: double): double;overload;override;
    function FunctionQuery(sQuery: string; sDefault: string): string;overload;override;
    function GetNextID(sType: string; iCount:int64 = 1): Int64; override;
    function SetNextID(sType: string; id: int64): boolean;override;
    function Connected: boolean;override;
    procedure Connect;override;
    destructor Destroy; override;
    property URL: string read GetURL;
    function ClickhouseTypeToVariant(sType: string; sVal: string): variant;
    function ClickhouseTypeToFieldType(sType: string): TFieldType;
    function HTTPBodyToRowset(s: string): TSERowSet;



  end;

implementation

{ TRestDB }

function TRestDB.ClickhouseTypeToFieldType(sType: string): TFieldType;
begin
  stype := lowercase(sType);
  var junk: string;
  SplitString(sType,'(',sType, junk);
  if sType = 'date' then exit(ftDate);
  if sType = 'datetime' then exit(ftDateTime);
  if sType = 'uint64' then exit(ftLargeint);
  if sType = 'uint32' then exit(ftLargeint);
  if sType = 'uint16' then exit(ftLargeint);
  if sType = 'uint8' then exit(ftLargeint);
  if sType = 'int64' then exit(ftLargeint);
  if sType = 'int32' then exit(ftLargeint);
  if sType = 'int16' then exit(ftLargeint);
  if sType = 'int8' then exit(ftLargeint);
  if sType = 'single' then exit(ftSingle);
  if sType = 'double' then exit(ftExtended);
  if sType = 'float' then exit(ftExtended);
  if sType = 'fixedstring' then exit(ftString);
  if sType = 'string' then exit(ftString);




end;

function TRestDB.ClickhouseTypeToVariant(sType, sVal: string): variant;
begin
  result := sVal;
end;

procedure TRestDB.Connect;
begin
  inherited;
  httpcli := TStatefulBrowser.create;

end;

function TRestDB.Connected: boolean;
begin
  if httpcli <> nil then
    exit(true);

  exit(false);

end;

destructor TRestDB.Destroy;
begin
  httpcli.free;
  httpcli := nil;
  inherited;
end;

function TRestDB.FunctionQuery(sQuery: string; rDefault: double): double;
begin
  var rs := readQueryh(sQuery);
  result := rs.o.values[0,0];

end;

function TRestDB.FunctionQuery(sQuery: string; sDefault: int64): int64;
begin
  var rs := readQueryh(sQuery);
  result := rs.o.values[0,0];

end;

function TRestDB.FunctionQuery(sQuery, sDefault: string): string;
begin
  var rs := readQueryh(sQuery);
  result := rs.o.values[0,0];
end;

function TRestDB.GetNextID(sType: string; iCount: int64): Int64;
begin

end;

function TRestDB.GetURL: string;
begin
  result := 'http://'+DBHost+':'+DBPort+'/?database='+database+'&query=';
end;

function TRestDB.HTTPBodyToRowset(s: string): TSERowSet;
begin
  result := TSERowSet.create;
  var doc := stringToStringListH(s);
  var flds := parsestringh(doc.o[0],#9);
  var types := parsestringh(doc.o[1],#9);
  for var f := 0 to flds.o.count-1 do begin
    var pf : PSeRowSetFieldDef := result.AddField;
    pf^.sName := flds.o[f];
    pf^.vType := ClickhouseTypeToFieldType(types.o[f]);
  end;

  for var t := 2 to doc.o.count-1 do begin
    result.AddRow;
    for var ff := 0 to flds.o.count-1 do begin
      var line := ParseStringH(doc.o[t],#9);
      result.CurRecordFieldsByIdx[ff] := ClickhouseTypeToVariant(types.o[ff],line.o[ff]);
    end;

  end;


end;

function TRestDB.ReadQuery(sQuery: string): TSERowSet;
var
  res: THTTPResults;
begin
  var urlurl := URL+urlencode(sQuery+' FORMAT TabSeparatedWithNamesAndTypes');
  res := httpcli.Get(urlurl,nil);
  if not res.success then
    raise ECritical.create('REST query failed '+inttostr(res.resultcode)+' '+res.error+' '+urlurl+#13#10+res.body);
  result := HTTPBodyToRowset(res.Body);




end;

function TRestDB.SetNextID(sType: string; id: int64): boolean;
begin

end;

end.
