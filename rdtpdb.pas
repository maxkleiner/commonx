unit rdtpdb;
{$DEFINE NO_QUERY_LOGGING}
{$I DelphiDefs.inc}
{$DEFINE DO_WRITE_BEHIND}
{$DEFINE QUERY_LOGGIng}
{$IFDEF NO_QUERY_LOGGING}
{$UNDEF QUERY_LOGGING}
{$ENDIF}
{x$DEFINE SHORT_POOL}


interface

uses
  numbers, consolelock, abstractdb, sysutils, stringx, typex, systemx, tickcount, RDTPSQLconnectionClientEx, storageenginetypes, variants, debug, namevaluepair, rdtpkeybotclient, betterobject, commandprocessor, databasequeryengine, classes;
type
  Trdtpdb = class(TAbstractDB)
  private
  protected
    FIsMYSQL: boolean;
    FUseTCP: boolean;
    FUseTor: boolean;
    function Getcontext: string;override;
    procedure Setcontext(Value: string);override;

  public
    clusternode: ni;
    cli: TRDTPSQLConnectionClientEx;
    tmLAstReadyCheck: ticker;
    poolable: boolean;
    procedure Init;override;
    destructor Destroy;override;
    constructor CopyCreate(source: TRDTPDB);
    procedure Connect;override;
//    function ReadQuery(sQuery: string): TdbCursor;
    procedure WriteQuery(sQuery: string);override;
    function DeleteVerify(sTable, sCluster: string; sWhere: string; timeout: ticker = 0 ): boolean;
    procedure Writebehind(sQuery: string; bDontLog: boolean = false);override;
    procedure ReadQuery_Begin(sQuery: string);
    function ReadQuery_End: TSERowSet;
    function ReadQueryH_End: IHolder<TSERowSet>;

    function ReadQuery(sQuery: string): TSERowSet;override;
    function ReadQuerySLH(sQuery: string): IHolder<TStringList>;
    function ReadQueryMultiTable(sQueryDotDotDot: string; postOrder: string): IHolder<TSERowSet>;
    procedure WriteQueryMultiTable(sQueryDotDotDot: string);

    function ReadQueryDBC(sQuery: string): TAbstractDBCursor;override;
//    property conn: TSQLConnection read Fconn;
    function ArrayQuery(sQuery: string): TArray<string>;
    procedure FunctionQueryInt_Begin(sQuery: string);overload;
    procedure FunctionQueryDouble_Begin(sQuery: string);overload;
    procedure FunctionQueryString_Begin(sQuery: string);overload;
    function FunctionQuery_End(iDefault: int64): int64;overload;
    function FunctionQuery_End(rDefault: double): double;overload;
    function  FunctionQuery_End(sDefault: string): string;overload;

    function FunctionQuery(sQuery: string; iDefault: int64): int64;overload;override;
    function FunctionQuery(sQuery: string; rDefault: double): double;overload;override;
    function FunctionQuery(sQuery: string; sDefault: string): string;overload;override;
    procedure CleanupClient;
    function GetNextID(sType: string; iCount:int64 = 1): Int64; override;
    function SetNextID(sType: string; id: Int64): Boolean; override;
    function ShouldGive: Boolean; override;
    property UseTCP: boolean read FUseTCP write FuseTCP;
    property UseTor: boolean read FUseTor write FuseTor;
    function Connected: boolean;override;
    property Context: string read Getcontext write Setcontext;
    procedure CheckConnectedOrConnect;
    function IsMYSQL: boolean;

  end;


function CanRetryOnError(sMessage: string): boolean;



implementation

{ Trdtpdb }

function CanRetryOnError(sMessage: string): boolean;
begin
  result := zpos('TOO_MANY_PARTS',sMessage) >=0;  if result then exit;
  result := zpos('THREAD',sMessage) >=0;  if result then exit;



end;

function Trdtpdb.ArrayQuery(sQuery: string): TArray<string>;
var
  t: ni;
  rs: TSERowSet;
begin
  rs := TSERowSet.Create;
  try
    sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
    rs := ReadQuery(sQuery);
    setlength(result, rs.RowCount);
    for t:= 0 to rs.rowcount-1 do begin
      result[t] := rs.values[0,t];
    end;
  finally
    rs.free;
  end;


end;

procedure Trdtpdb.CheckConnectedOrConnect;
begin
  if Connected then
    exit;
  connect;

end;

procedure Trdtpdb.CleanupClient;
begin
  if assigned(cli) then
    cli.free;
  cli := nil;

end;

procedure Trdtpdb.Connect;
var
  sl,sr: string;
begin
  if connected then exit;

  cleanupclient;
  cli := TRDTPSQLConnectionClientEx.create(MWHost, MWEndpoint);
  cli.Host := self.MWHost;
  cli.endPoint := self.MWEndpoint;
  cli.UseTCP := self.UseTCP;
{$IFDEF ALLOW_TOR}
  //cli.UseTor := self.UseTor;
{$ENDIF}

  if context <> '' then begin
    splitstringnocase(context, ';db=', sl,sr);
    splitstringnocase(sr, ';', sl,sr);
    cli.context := context;
  end else begin
{$IFNDEF CONTEXT_ONLY}
    cli.Context :='simple;db='+Database+';host='+DBHost+';user='+DBUSER+';pass='+DBPassword+';port='+DBPort+';';
{$ENDIF}
  end;

  cli.timeout := 3000000;




end;

function Trdtpdb.Connected: boolean;
begin
  if self.cli = nil then
    exit(false);

  result := self.cli.Connected;
end;

constructor Trdtpdb.CopyCreate(source: TRDTPDB);
begin
  inherited Create;
  FMWHost := source.MWHost;
  FMWEndpoint := source.MWEndpoint;
  if source.Context <> '' then begin
    context := source.context;
    Connect;
  end else begin
    {$IFNDEF CONTEXT_ONLY}
    Connect(source.DBhost, source.database, source.DBuser, source.DBpassword, source.DBport);
    {$ENDIF}
  end;
end;

function Trdtpdb.DeleteVerify(sTable, sCluster, sWhere: string; timeout: ticker): boolean;
begin
  WriteQuery('alter table '+sTable+'_n on cluster '+sCluster+' delete where '+sWhere);
  var tmStart := getticker;
  while (timeout = 0) or (gettimesince(tmStart) < timeout )do begin
    if FunctionQuery('select count(*) from '+sTable+' where '+sWhere,0)=0 then
      exit(true);
    sleep(lesserof(1000,timeout));
  end;
  exit(false);
end;

destructor Trdtpdb.Destroy;
begin
  cleanupclient;
  inherited;
end;

function Trdtpdb.FunctionQuery(sQuery: string; iDefault: int64): int64;
begin
  while true do begin
    try
      FunctionQueryDouble_Begin(sQuery);
      result := FunctionQuery_End(iDefault);
      break;
    except
      on e:exception do begin
        poolable := false;
        if not CanRetryOnError(e.message) then begin
          poolable := false;
          raise;
        end;

      end;
    end;
  end;


end;



function Trdtpdb.FunctionQuery(sQuery, sDefault: string): string;
begin
  while true do begin
    try
      FunctionQueryDouble_Begin(sQuery);
      result := FunctionQuery_End(sDefault);
      break;
    except
      on e:exception do begin
        poolable := false;
        if not CanRetryOnError(e.message) then
          raise;
      end;
    end;
  end;

end;

procedure Trdtpdb.FunctionQueryDouble_Begin(sQuery: string);
begin
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  ReadQuery_Begin(sQuery);



end;

procedure Trdtpdb.FunctionQueryInt_Begin(sQuery: string);
begin
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  ReadQuery_Begin(sQuery);
end;

procedure Trdtpdb.FunctionQueryString_Begin(sQuery: string);
begin
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  ReadQuery_Begin(sQuery);
end;

function Trdtpdb.FunctionQuery_End(iDefault: int64): int64;
var
  rs: TSERowset;
begin
  rs := nil;
  try
  rs := Readquery_End;
  if rs = nil then begin
    result := iDefault;
    exit;
  end;

  if rs.RowCount = 0 then begin
    result := iDefault;
    exit;
  end;

  if rs.fieldcount = 0 then begin
    result := iDefault;
    exit;
  end;

  if vartype(rs.values[0,0]) = varNull then
    result := iDefault
  else
    result := rs.Values[0,0];
  finally
    rs.free;
    rs := nil;
  end;


end;

function Trdtpdb.FunctionQuery_End(rDefault: double): double;
var
  rs: TSERowset;
begin
  try
  rs := nil;
  try
  rs := Readquery_End;
  if rs = nil then begin
    result := rDefault;
    exit;
  end;

  if rs.RowCount = 0 then begin
    result := rDefault;
    exit;
  end;

  if rs.fieldcount = 0 then begin
    result := rDefault;
    exit;
  end;

  if vartype(rs.values[0,0]) = varNull then
    result := rDefault
  else
    result := rs.Values[0,0];

  finally
    rs.free;
    rs := nil;
  end;
  except
    poolable := false;
    raise;
  end;



end;


function Trdtpdb.FunctionQuery_End(sDefault: string): string;
var
  rs: TSERowset;
begin
  try
  rs := Readquery_End;
  try
    if rs = nil then begin
      result := sDefault;
      exit;
    end;

    if rs.RowCount = 0 then begin
      result := sDefault;
      exit;
    end;

    if rs.fieldcount = 0 then begin
      result := sDefault;
      exit;
    end;

    if vartype(rs.values[0,0]) = varNull then
      result := sDefault
    else
      result := rs.Values[0,0];
  finally
    rs.free;
  end;
  except
    poolable := false;
    raise;
  end;

end;

function Trdtpdb.Getcontext: string;
begin
  result := FContext;
end;

function Trdtpdb.GetNextID(sType: string; iCount:int64 = 1): Int64;
begin
  CheckConnectedOrConnect;
  Result := cli.GetNextIDEx(sType,'','', iCount);
end;

function Trdtpdb.FunctionQuery(sQuery: string; rDefault: double): double;
begin
  while true do begin
    try
      FunctionQueryDouble_Begin(sQuery);
      result := FunctionQuery_End(rDefault);
      break;
    except
      on e:exception do begin
        poolable := false;
        if not CanRetryOnError(e.message) then
          raise;
      end;
    end;
  end;

end;

procedure Trdtpdb.Init;
begin
  inherited;
  poolable := true;
  FMWHost := 'localhost';
  FMWEndpoint := '235';
  Created := getticker;
end;


function Trdtpdb.IsMYSQL: boolean;
begin
  result := FIsMYSQL;
end;

function Trdtpdb.ReadQuery(sQuery: string): TSERowSet;
var
  tm: ticker;
begin
  result := nil;
  try

  tm := GetTicker;
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  CheckConnectedOrConnect;
{$IFDEF QUERY_LOGGING}  Debug.Log('Read Query: '+sQuery);{$ENDIF}
  while true do begin
    try
      result := cli.ReadQuery(sQuery);
      break;
    except
      on e:exception do begin
        poolable := false;
        if not CanRetryOnError(e.message) then
          raise;
      end;
    end;
  end;
//  Debug.Log('Query Took: '+commaize(gettimesince(tm))+'ms.');
  except
    poolable := false;
    raise;
  end;

end;

function Trdtpdb.ReadQueryDBC(sQuery: string): TAbstractDBCursor;
begin
  try
    result := TSERowSetCursor.create;
    sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
    while true do begin
      try

        TSERowSetCursor(result).RS := ReadQuery(sQuery);
        break;
      except
        on e:exception do begin
          poolable := false;
          if not CanRetryOnError(e.message) then
            raise;
        end;
      end;
    end;

  except
    poolable := false;
    raise;
  end;


end;

function Trdtpdb.ReadQueryH_End: IHolder<TSERowSEt>;
begin
  result := THolder<TSERowSet>.create;
  result.o := ReadQuery_end;
end;

function Trdtpdb.ReadQueryMultiTable(sQueryDotDotDot: string; postOrder: string): IHolder<TSERowset>;
var
  rsTables: TSERowsEt;
  t: ni;
  s, sl, sTable, sTablePrefix, sTableSuffix, sr, sJunk, sQuery: string;
  unsorted: TSERowSet;
  e: IHolder<TSERowSet>;
begin

  sQueryDotDotDot := ApplyContextVariablesToQuery(self.FContext, sQueryDotDotDot);
  s := sQueryDotDotDot;
  if not SplitString(s, '...', sl, sr) then
    raise ECritical.create('no ... found');
  if not SplitString(sl, ' ', sl, sTablePRefix, true) then
    raise ECritical.create('could not find table prefix in '+sQueryDotDotDot);

  if (not SplitString(sr, ' ', sTableSuffix, sr)) and (sr <> '') then
    raise ECritical.create('could not find table suffix in '+sQueryDotDotDot);


  rsTables := ReadQuery('show tables');
  try
    for t:= 0 to rsTables.RowCount -1 do begin
      sTable := rstables.Values[0, t];
      if comparetext(Zcopy(sTable, 0, length(sTablePrefix)), sTablePrefix)=0 then begin
        if comparetext(Zcopy(sTable, length(sTable)-length(sTableSuffix), length(sTableSuffix)), sTableSuffix)=0 then begin
          sQuery := sl +' '+ sTable +' '+ sr;
          ReadQuery_Begin(sQuery);
        end;
      end;
    end;

    result := THolder<TSERowset>.create;
    result.o := TSERowSet.create;
    unsorted := TSERowset.create;
    try
      for t:= 0 to rsTables.RowCount -1 do begin
        sTable := rstables.Values[0, t];
        if comparetext(Zcopy(sTable, 0, length(sTablePrefix)), sTablePrefix)=0 then begin
          if comparetext(Zcopy(sTable, length(sTable)-length(sTableSuffix), length(sTableSuffix)), sTableSuffix)=0 then begin
            sQuery := sl +' '+ sTable +' '+ sr;
            e := ReadQueryH_End;
            unsorted.Append(e);//<<--- MERGES STUFF
          end;
        end;
      end;

      unsorted.BuildIndex('idxRes', postOrder);//<---- THIS ALSO SETS THE INDEX
      unsorted.CopyFieldDefsTo(result.o);
      for t:= 0 to unsorted.rowcount-1 do begin
        unsorted.cursor := t;
        result.o.AppendRowFrom(unsorted, t);
//        Debug.Log('Multi-Sort #'+inttostr(t)+': '+unsorted.RowToString);
      end;

    finally
      unsorted.free;
    end;
  finally
    rsTables.free;
  end;

end;


function Trdtpdb.ReadQuerySLH(sQuery: string): IHolder<TStringList>;
begin
  var rs := readqueryh(sQuery);
  var slh := NewStringListH;
  result := slh;
  rs.o.Iterate(procedure begin
    slh.o.add(rs.o.values[0,rs.o.cursor]);
  end);
end;

procedure Trdtpdb.ReadQuery_Begin(sQuery: string);
begin
{$IFDEF QUERY_LOGGING}  Debug.Log('BEGIN Read Query: '+sQuery);{$ENDIF}
  Connect;
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  cli.ReadQuery_Async(sQuery);
end;

function Trdtpdb.ReadQuery_End: TSERowSet;
//var
//  tm: ticker;
begin
//  tm := GetTicker;
  result := cli.ReadQuery_Response;
//  Debug.Log('END Read Query took '+commaize(gettimesince(tm))+'ms.');
end;

procedure Trdtpdb.Setcontext(Value: string);
begin
  inherited;
  if zpos('provider=mysql', lowercase(FContext)) >=0 then
    FIsMYSQL := true;//todo 2: make this better...
end;

function Trdtpdb.SetNextID(sType: string; id: Int64): Boolean;
begin
  cli.SetNextId(sType, id);
  result := true;
end;

function Trdtpdb.ShouldGive: Boolean;
begin
{$IFDEF SHORT_POOL}
  result := (gettimesince(created) < 1000) and poolable;
{$ELSE}
  result := (gettimesince(created) < 10000) and poolable;
{$ENDIF}
end;

procedure Trdtpdb.Writebehind(sQuery: string; bDontLog: boolean = false);
begin
  CheckConnectedOrConnect;
  inherited;
  sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
  if not bDontLog then
{$IFDEF QUERY_LOGGING}    Debug.Log('WriteBehind: '+sQuery);{$ENDIF}
{$IFDEF DO_WRITE_BEHIND}
  if gettimesince(tmLastReadyCheck) > 30000 then begin
    cli.ReadyToWriteBehind;
    tmLastReadyCheck := getticker;
  end;
  cli.WriteBehind(sQuery);
{$ELSE}
  cli.WriteQuery(sQuery);
{$ENDIF}

end;

procedure Trdtpdb.WriteQuery(sQuery: string);
begin
{$IFDEF QUERY_LOGGING}  Debug.Log('Write: '+sQuery);{$ENDIF}
  Connect;
  try
    sQuery := ApplyContextVariablesToQuery(self.FContext, sQuery);
    repeat
      try
        cli.WriteQuery(sQuery);
        break;
      except
        on E:Exception do begin
          poolable := false;
          if (zpos('TOO_MANY_PARTS',e.message) < 0)
          and (zpos('THREAD',e.message) < 0) then
            raise;
          sleep(random(4000));
        end;
      end;
    until false;
{$IFDEF DONT_POOL_ALTER}
    if 0=comparetext('alter', zcopy(trim(sQuery),0,length('alter'))) then begin
      poolable := false;
    end;
    if 0=comparetext('optimize', zcopy(trim(sQuery),0,length('optimize'))) then begin
      poolable := false;
    end;
{$ENDIF}
  except
    poolable := false;
    raise;
  end;

end;


procedure Trdtpdb.WriteQueryMultiTable(sQueryDotDotDot: string);
var
  rsTables: TSERowsEt;
  t: ni;
  s, sl, sTable, sTablePrefix, sTableSuffix, sr, sJunk, sQuery: string;
  unsorted: TSERowSet;
  e: IHolder<TSERowSet>;
begin

  sQueryDotDotDot := ApplyContextVariablesToQuery(self.FContext, sQueryDotDotDot);
  s := sQueryDotDotDot;
  if not SplitString(s, '...', sl, sr) then
    raise ECritical.create('no ... found');
  if not SplitString(sl, ' ', sl, sTablePRefix, true) then
    raise ECritical.create('could not find table prefix in '+sQueryDotDotDot);

  if not SplitString(sr, ' ', sTableSuffix, sr) then
    raise ECritical.create('could not find table suffix in '+sQueryDotDotDot);


  rsTables := ReadQuery('show tables');
  try
    for t:= 0 to rsTables.RowCount -1 do begin
      sTable := rstables.Values[0, t];
      if comparetext(Zcopy(sTable, 0, length(sTablePrefix)), sTablePrefix)=0 then begin
        if comparetext(Zcopy(sTable, length(sTable)-length(sTableSuffix), length(sTableSuffix)), sTableSuffix)=0 then begin
          sQuery := sl +' '+ sTable +' '+ sr;
          Writebehind(sQuery);
        end;
      end;
    end;
  finally
    rsTables.free;
  end;
end;

initialization


finalization


end.
