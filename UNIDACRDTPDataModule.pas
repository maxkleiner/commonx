unit UNIDACRDTPDataModule;

{$IFNDEF VER160}{$INLINE AUTO}{$ENDIF}
{$DEFINE STD_DRV}
{x$DEFINE ALT_DRV}
{x$DEFINE SAVE_MEMORY}
interface
//TODO 1:Should not export TCustomDADataset

uses
  MySQLUniProvider, uni, SQLServerUniProvider,
  SysUtils, Classes, DBAccess, variants,
  DB, better_Sockets, typex,inifiles, replaylog, ExceptionsX,
  sharedobject, abstractrdtpdatamodule, storageenginetypes,
  managedthread, rdtpprocessor, beeper, inifile, systemx,
  namevaluepair, consolelock, betterobject, tickcount;

type
  TUniDACRDTPDataModule = class(TAbstractRDTPDataModule)
  private
    { Private declarations }
    FContextVerified: boolean;
    FHost: string;
    FID: string;

    procedure DataModuleCreate(Sender: TObject);
    procedure Execute(sQuery:string; connection: TUNIConnection; out ds: TCustomDADataset);
    function ExecuteDirect(sQuery: string; connection: TUNIConnection): integer;
    procedure SetContext(const Value: string);

  protected
    function TryGetNextID(iKey: integer; out res: int64): boolean;
    function TrySetNextID(iKey: integer; value: int64): boolean;
    procedure ConfigureFromContext;override;
    procedure ConfigureFromContext_SE;
    procedure ConfigureFromContext_Simple;
    procedure ConnectRead;override;
    procedure ConnectWrite;override;
    procedure ConnectSystem;override;
    function GetChannelObject(ch: TSQLChannel): TUniConnection;


  public

    writes: TUniConnection;
    sessiondb: TUniConnection;
    reads: TUniConnection;
    keybot_link: TBetterTcpClient;
    dbtype: string;

    constructor create;override;
    destructor destroy;override;



    { Public declarations }

    function GetNextID(sKey: string): int64;override;
    function GetNextIDEx(sKey: string; sTable, sField: string; count: int64): int64;override;
    function SetNextID(sKey: string; iValue: int64): int64;override;

    procedure IncWrite;
    procedure ChangeUniConnectionParam(conn: TUniConnection; sParamName: string; sVAlue: string);

    function ExecuteSystem_Platform(sQuery: string; out dataset: TCustomDADataset): integer;
    procedure ExecuteRead_Platform(sQuery: string; out dataset: TCustomDADataset);
    procedure ExecuteWrite_Platform(sQuery: string; out dataset: TCustomDADataset);

    function ExecuteSystem(sQuery: string): integer;override;
    function ExecuteWriteRaw(sQuery: string): integer;override;
    function ExecuteSystem(sQuery: string; out dataset: TSERowSet): integer;override;
    function ExecuteWrite(sQuery: string; out dataset: TSERowSet): integer;override;
    procedure ExecuteRead(sQuery: string; out dataset: TSERowSet);override;

    function ContextVerified: boolean;inline;
    procedure VerifyContext;
    function TableExists(sTable: string): boolean;
    function CopyTable(sSource, sTarget: string): IHolder<TStringList>;

    procedure BeginTransactionOn(ch: TSQLChannel); override;
    procedure CommitOn(ch: TSQLChannel); override;
    procedure RollbackOn(ch: TSQLChannel); override;
    procedure WriteOn(ch: TSQLChannel; sQuery: string); override;
    function ReadOn(ch: TSQLChannel; sQuery: string): TSERowSet; override;
    function IsMYSQL: boolean;
    procedure ResetForPool;override;
  end;

procedure UniSetToRowSet(var rs: TSERowset; ds: TCustomDADataset; bAppend: boolean = false);



implementation

uses AppLock, debug,  stringx;

procedure UniSetToRowSet(var rs: TSERowset; ds: TCustomDaDataset; bAppend: boolean = false);
var
  t, i,u: integer;
  s: string;
  u8: utf8string;
  c: array of char;
begin
  if rs = nil then
    rs := TSERowSet.Create;

  ds.first;
  i := 0;
  if not bAppend then begin
    rs.SetFieldCount(ds.fieldcount);
    for t:= 0 to ds.fieldcount-1 do begin
      rs.FieldDefs[t].sName := ds.FieldDefs[t].Name;
      rs.FieldDefs[t].vType := ds.FieldDefs[t].DataType;
    end;
  end else begin
    if rs.FieldCount <> ds.FieldCount then
      raise exception.create('appended dataset contains incorrect number of fields');
  end;

  ds.first;
  while not ds.eof do begin
    rs.SetRowCount(i+1);
    for t:= 0 to ds.FieldCount-1 do begin
      if ds.Fields[t].IsBlob then begin
        if ds.FieldDefs[t].DataType in [ftMemo, ftWideMemo] then begin
          rs.Values[t,i] := ds.fields[t].Value;
        end else begin
          SetLength(s, ds.Fields[t].DataSize);
          SEtLength(c, ds.Fields[t].DAtaSize);

          {$IFDEF MSWINDOWS}
            ds.Fields[t].GetData(@c[0]);
          {$ELSE}
            raise ECritical.create('ds.Fields[t].GetData(@c[0]); is not implemented on this platform.');
          {$ENDIF}
          for u := low(c) to high(c) do begin
            s[u+1] := c[u];
          end;
          rs.Values[t,i] := s;
        end;

      end else
      if (vartype(ds.fields[t].Value) = varString)
      or (vartype(ds.fields[t].Value) = varOleStr)
      then begin
        rs.Values[t,i] := ds.fields[t].Text;
      end else
      begin
        if ds.FieldDefs[t].DataType in [ftDateTime,ftTimeStamp] then begin
          if vartype(ds.Fields[t].AsVariant) = varNull then
            rs.values[t,i] := NULL
          else
            rs.Values[t,i] := strtodatetime(ds.Fields[t].AsVariant);
        end
        else
          rs.Values[t,i] := ds.Fields[t].AsVariant;
      end;
    end;
    inc(i);
    ds.Next;
  end;
end;

procedure TUniDACRDTPDataModule.BeginTransactionOn(ch: TSQLChannel);
var
  conn: TUniConnection;
  stats: PSQlChannelStats;
begin
  conn := GetChannelObject(ch);
  conn.Connect;
  stats := GetChannelStats(ch);
  if not stats.InTransaction then begin
    stats.Init;
    stats.InTransaction := true;
    conn.StartTransaction;
    Debug.Log(self,'Transaction Started');
  end else
    Debug.Log(self,'Already in Transaction');

end;

procedure TUniDACRDTPDataModule.ChangeUniConnectionParam(conn: TUniConnection;
  sParamName, sVAlue: string);
begin
  raise ECritical.create('not implemented');
//  RemovePrefixFromStringList(sPAramName,conn.Params);
//  conn.params.Add(sParamName+'='+sValue);
end;

procedure TUniDACRDTPDataModule.CommitOn(ch: TSQLChannel);
var
  conn: TUniConnection;
  stats: PSQlChannelStats;
begin
  conn := GetChannelObject(ch);
  conn.Connect;
  stats := GetChannelStats(ch);



  if conn.connected and (stats.InTransaction) then begin
    if stats.WriteQueries > 0 then begin
      Debug.Log('commit');
      try
        conn.Commit;
      except
        on e: exception do begin
          Debug.Log(self,'Commit exception: '+e.message);
        end;
      end;
      stats.init;
      Debug.Log(self,'Transaction Committed');
    end else begin
      Debug.Log(self,'No writes to commit');
      try
        conn.Commit;
      except
        on e: exception do begin
          Debug.Log(self,'Commit exception: '+e.message);
        end;
      end;

    end;
  end;

end;

procedure TUniDACRDTPDataModule.ConfigureFromContext_SE;
begin
  raise ECritical.create('not implemented');

end;

procedure TUniDACRDTPDataModule.ConfigureFromContext;
begin
  inherited;
  if lowercase(zcopy(context, 0, length('simple;'))) = 'simple;' then begin
    ConfigureFromContext_Simple;
  end else begin
    ConfigureFromContext_SE;
  end;
end;

procedure TUniDACRDTPDataModule.ConfigureFromContext_Simple;
//sample simple context:
//simple;db=crimphd;port=3307;host=192.168.101.81;user=root;pass=something';
var
  h: IHolder<TSTringlist>;
  nvp: TNameValuePairList;
  s: string;
  sWrites, sReads, ssessiondb: string;
begin
  sWrites := ''; sReads := ''; sSessiondb := '';
  var applyAll := procedure (name,val: string)
                  begin
                    sWrites := AOR(sWrites, ';', name+'='+val);
                    sReads := AOR(sReads, ';', name+'='+val);
                    sSessionDB := AOR(sSessionDB, ';', name+'='+val);
                  end;
  h := ParseStringH(context,';');
  h.o.delete(0);
  nvp := TNameValuePairList.create;
  try
    writes.ConnectString :='';
    reads.ConnectString :='';
    sessiondb.ConnectString :='';

    nvp.loadFromString(h.o.Text);
    var prov := nvp.GetItemEx('Provider','MySQL');
    dbtype := prov;
    applyAll('Provider Name', prov);
    if comparetext(prov, 'mysql') = 0 then begin
      applyAll('Database', nvp.GetItemEx('db',''));
      applyAll('port', nvp.GetItemEx('port','3306'));
    end
    else
    begin
      applyAll('Database', nvp.GetItemEx('db',''));
      applyAll('Initial Catalog', nvp.GetItemEx('db',''));
      var port := nvp.GetItemEx('port','1433');
      if port <> '1433' then
       applyAll('port', port );
    end;
    applyAll('Data Source', nvp.GetItemEx('host',''));
    applyAll('User ID', nvp.GetItemEx('user',''));
    applyAll('password', nvp.GetItemEx('pass',''));
    var bUseSSL := nvp.GetItemEx('ssl', false);
    if bUseSSL then begin
      writes.SpecificOptions.Values['MySQL.Protocol'] := 'mpSSL';
      reads.SpecificOptions.Values['MySQL.Protocol'] := 'mpSSL';
      sessiondb.SpecificOptions.Values['MySQL.Protocol'] := 'mpSSL';
    end;

//    reads.SpecificOptions.Values['Charset'] := 'utf8mb4';
//    reads.SpecificOptions.Values['UseUnicode'] := 'True';
//    writes.SpecificOptions.Values['Charset'] := 'utf8mb4';
//    writes.SpecificOptions.Values['UseUnicode'] := 'True';
//    sessiondb.SpecificOptions.Values['Charset'] := 'utf8mb4';
//    sessiondb.SpecificOptions.Values['UseUnicode'] := 'True';



    //commit string

    writes.ConnectString := sWrites;
    Debug.Log(writes.ConnectString);
    if zpos('provider name=mysql',lowercase(sWrites))>=0 then begin //todo 1:make this omre robust
      writes.SpecificOptions.Values['Charset'] := 'utf8mb4';
      writes.SpecificOptions.Values['UseUnicode'] := 'True';
    end;


    reads.ConnectString := sReads;
    if zpos('provider name=mysql',lowercase(sReads))>=0 then begin //todo 1:make this omre robust
      reads.SpecificOptions.Values['Charset'] := 'utf8mb4';
      reads.SpecificOptions.Values['UseUnicode'] := 'True';
    end;

    sessiondb.ConnectString := sSessiondb;
    if zpos('provider name=mysql',lowercase(sSessiondb))>=0 then begin //todo 1:make this omre robust
      sessiondb.SpecificOptions.Values['Charset'] := 'utf8mb4';
      sessiondb.SpecificOptions.Values['UseUnicode'] := 'True';
    end;


  finally
    nvp.free;
  end;

end;

procedure TUniDACRDTPDataModule.ConnectRead;
var
  bRetry: boolean;
begin
  if gettimesince(lastused) > 300000 then begin
    reads.Connected := false;
  end;
  repeat
    bRetry := false;
    try
      if not reads.connected then begin
        reads.connected := true;
      end;
    except
      on E: Exception do begin
        Debug.Log(self,'EXCEPTION on connection: '+e.message );
        if pos('failed to connect', lowercase(e.message))> 0 then begin
          Debug.Log(self,'auto-retry on EXCEPTION');
          reads.connected := false;

          bRetry := true;
          sleep(random(700));
        end
        else begin
          beeper.beep(700,300);
          Debug.Log(self,'auto-retry on EXCEPTION');
          raise;

        end;
      end;
    end;
  until bRetry = false;


//  writes.connected := true;
//  sessiondb.connected := true;
end;





function TUniDACRDTPDataModule.GetChannelObject(
  ch: TSQLChannel): TUniConnection;
begin
  case ch of
    sqlRead: exit(reads);
    sqlWrite: exit(writes);
    sqlSystem: exit(sessiondb);
  end;
end;




function TUniDACRDTPDataModule.GetNextID(sKey: string): int64;
var
  rs: TSERowSet;
begin
  result := -1;

    BeginTransactionOn(sqlSYstem);
    try
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          '	create table if not exists nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from sysobjects where name=''nextid'' and xtype=''U'') '+CRLF+
          '	create table nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'+CRLF
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' insert ignore into nextid values ("'+sKey+'",1)'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from nextid where keyname='''+sKey+''') '+CRLF+
          'begin '+CRLF+
          '	insert into nextid values('''+sKey+''', 1); '+CRLF+
          'end; '
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = id + 1 where keyname = "'+sKey+'"'
        );
      end else begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = id + 1 where keyname = '''+sKey+''''
        );
      end;
      rs := nil;
      try
        if IsMySQL then begin
          rs := self.ReadOn(
            sqlSystem,
            ' select * from nextid where keyname = "'+sKey+'"'
          );
        end else begin
          rs := self.ReadOn(
            sqlSystem,
            ' select * from nextid where keyname = '''+sKey+''''
          );
        end;

        result := rs['id'];
      finally
        rs.free;
      end;

      try
        CommitOn(sqlSYstem);
      except
      end;
    except
      RollbackOn(sqlSystem);
    end;



end;

function TUniDACRDTPDataModule.GetNextIDEx(sKey, sTable, sField: string; count: int64): int64;
var
  rs: TSERowSet;
begin
  result := -1;

    BeginTransactionOn(sqlSYstem);
    try
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          '	create table if not exists nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from sysobjects where name=''nextid'' and xtype=''U'') '+CRLF+
          '	create table nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'+CRLF
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' insert ignore into nextid values ("'+sKey+'",1)'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from nextid where keyname='''+sKey+''') '+CRLF+
          'begin '+CRLF+
          '	insert into nextid values('''+sKey+''', 1); '+CRLF+
          'end; '
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = id + '+count.tostring+' where keyname = "'+sKey+'"'
        );
      end else begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = id + '+count.tostring+' where keyname = '''+sKey+''''
        );
      end;
      rs := nil;
      try
        if IsMySQL then begin
          rs := self.ReadOn(
            sqlSystem,
            ' select * from nextid where keyname = "'+sKey+'"'
          );
        end else begin
          rs := self.ReadOn(
            sqlSystem,
            ' select * from nextid where keyname = '''+sKey+''''
          );
        end;

        result := rs['id'];
      finally
        rs.free;
      end;

      try
        CommitOn(sqlSYstem);
      except
      end;
    except
      RollbackOn(sqlSystem);
    end;
end;

procedure TUniDACRDTPDataModule.SetContext(const Value: string);
begin
  FContext := value;
  ConfigureFromContext;

end;




function TUniDACRDTPDataModule.SetNextID(sKey: string; iValue: int64): int64;
var
  rs: TSERowSet;
begin
  result := ivalue;
    BeginTransactionOn(sqlSYstem);
    try
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          '	create table if not exists nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from sysobjects where name=''nextid'' and xtype=''U'') '+CRLF+
          '	create table nextid '+CRLF+
          '	(keyname char(50) PRIMARY KEY, '+CRLF+
          '	ID bigint);'+CRLF
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' insert ignore into nextid values ("'+sKey+'",1)'
        );
      end else begin
        self.WriteOn(sqlSystem,
          'if not exists (select * from nextid where keyname='''+sKey+''') '+CRLF+
          'begin '+CRLF+
          '	insert into nextid values('''+sKey+''', 1); '+CRLF+
          'end; '
        );
      end;
      if IsMySQL then begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = '+ivalue.tostring+'where keyname = "'+sKey+'"'
        );
      end else begin
        self.WriteOn(sqlSystem,
          ' update nextid set id = '+ivalue.tostring+' where keyname = '''+sKey+''''
        );
      end;
      CommitOn(sqlSYstem);
    except
      RollbackOn(sqlSystem);
    end;
end;

function TUniDACRDTPDataModule.ReadOn(ch: TSQLChannel;
  sQuery: string): TSERowSet;
var
  conn: TUniConnection;
  stats: PSQlChannelStats;
  dataset: TCustomDADataset;
begin
  result := nil;
  conn := GetChannelObject(ch);
  conn.Connect;
  stats := GetChannelStats(ch);
  inc(stats.ReadQueries);
  WaitForCommands;

  dataset := nil;

  try
    Execute(sQuery, conn, dataset);
    UniSetToRowSet(result, dataset, false);
    lastused := getticker;
  finally
    dataset.free;
  end;

end;

procedure TUniDACRDTPDataModule.ResetForPool;
begin
  inherited;
  RollbackOn(TSqlChannel.sqlRead);
  RollbackOn(TSqlChannel.sqlWrite);
  RollbackOn(TSqlChannel.sqlSystem);

end;

procedure TUniDACRDTPDataModule.RollbackOn(ch: TSQLChannel);
var
  conn: TUniConnection;
  stats: PSQlChannelStats;
begin
  conn := GetChannelObject(ch);
  conn.Connect;
  stats := GetChannelStats(ch);

  if conn.connected and (stats.InTransaction) then begin
    if stats.WriteQueries > 0 then begin
      Debug.Log(self,'Transaction Rollback after '+stats.writequeries.tostring+' queries');
      try
        conn.Rollback;
      except
        on e: exception do begin
          Debug.Log(self,'Rolback exception: '+e.message);
        end;
      end;
      stats.init;

    end else begin
      Debug.Log(self,'Transaction Rollback after 0 queries');
      try
        conn.Rollback;
      except
        on e: exception do begin
          Debug.Log(self,'Rolback exception: '+e.message);
        end;
      end;
      stats.init;


//      Debug.Log(self,'No writes to rollback');
    end;
  end;



end;




procedure TUniDACRDTPDataModule.DataModuleCreate(Sender: TObject);
begin
  inherited;
  //NOP
//TODO -cunimplemented: unimplemented block
end;

procedure TUniDACRDTPDataModule.ConnectWrite;
var
  bRetry: boolean;
begin
  if gettimesince(lastused) > 300000 then begin
    writes.Connected := false;
  end;
  repeat
    bRetry := false;
    try
      if not writes.connected then begin
        GetChannelStats(sqlWrite).Init;
        writes.connected := true;
        Debug.Log(self,'write connection opened');
        //self.BeginTransaction;

      end;
    except
      on E: Exception do begin
        if (pos('failed to connect', lowercase(e.message))> 0) or (pos('lost connection', lowercase(e.message))> 0) then begin
          bRetry := true;
          reads.connected := false;
        end
        else begin
//          beeper.beep(700,300);
          Debug.Log(self,'auto-retry on EXCEPTION '+e.message);
          raise;
        end;
      end;
    end;
  until bRetry = false;

  //self.writes.ExecuteDirect('ROLLBACK;');

//  if not writes.connected then begin
//    FWriteQueries := 0;
//    writes.connected := true;
//    Debug.Log('write connection opened');
//    self.BeginTransaction;
//  end;

end;

function TUniDACRDTPDataModule.ContextVerified: boolean;
begin
  result := FContextVErified;
end;

function TUniDACRDTPDataModule.CopyTable(sSource, sTarget: string): IHolder<TStringLIst>;
var
  sQuery: string;
begin
  result := THolder<TStringList>.create;
  result.o := TStringlist.create;

  var rs : IHolder<TSERowSet> := ReadQuery('show create table '+sSource);
  if rs.o.rowcount = 0 then
    raise ECritical.create('Trying to copy '+sSource+' table, which does not exist');
  var ct : string := rs.o.values[1,0];

  ct := stringreplace(ct, '''0000-00-00 00:00:00''', 'now()', [rfIgnoreCase, rfReplaceAll]);
  ct := stringreplace(ct, '''0000-00-00''', 'now()', [rfIgnoreCase, rfReplaceAll]);
  ct := stringreplace(ct, 'current_timestamp()', 'now()', [rfIgnoreCase, rfReplaceAll]);
  ct := stringreplace(ct, 'create table', 'create table if not exists', [rfIgnoreCase]);
  ct := stringreplace(ct, sSource, sTarget, [rfIgnoreCase]);

//  sQuery := 'create table '+sTarget+' like '+sSource;
  sQuery := ct;
  ExecuteWrite(sQuery);
  result.o.add(sQuery);

  sQuery := 'insert into '+sTarget+' select * from '+sSource;
  ExecuteWrite(sQuery);
  result.o.add(sQuery);



end;

procedure TUniDACRDTPDataModule.connectsystem;
var
  bRetry: boolean;
begin
  if gettimesince(lastused) > 300000 then begin
    sessiondb.Connected := false;
  end;
  repeat
    bRetry := false;
    try
      if not sessiondb.connected then begin
//        Debug.Log(GetCurrentDir);
        sessiondb.connected := true;
        VerifyContext;
        Debug.Log(self,'session connection opened');
      end;

    except
      on E: Exception do begin
        if (pos('failed to connect', lowercase(e.message))> 0) or (pos('lost connection', lowercase(e.message))> 0) then begin
          bRetry := true;
          reads.connected := false;
        end
        else begin
          beeper.beep(700,300);
          Debug.Log(self,'auto-retry on EXCEPTION');
          raise;
        end;

      end;
    end;
  until bRetry = false;



end;

procedure TUniDACRDTPDataModule.IncWrite;
begin
  inc(GetChannelStats(sqlWrite).WriteQueries);

end;

function TUniDACRDTPDataModule.IsMYSQL: boolean;
begin
  result := comparetext(dbtype,'MySQL')=0;
end;

destructor TUniDACRDTPDataModule.destroy;
begin
  writes.free;
  sessiondb.free;
  reads.free;
  keybot_link.free;

  inherited;
end;

constructor TUniDACRDTPDataModule.create;
begin
  inherited;
  writes := TUniConnection.create(nil);
  sessiondb := TUniConnection.create(nil);
  reads := TUniConnection.create(nil);

  keybot_link := TBetterTcpClient.create(nil);

  DataModuleCreate(nil);
//  ConfigureFromContext;

end;

procedure TUniDACRDTPDataModule.Execute(sQuery: string; connection: TUniConnection;
  out ds: TCustomDADataset);
var
  bREtry: boolean;
  rc: integer;
begin
//  Al.Lock;
//  try

  ds := nil;
  rc := 0;
  repeat
    ds := nil;
    bREtry := false;
    try
      Debug.Log(self,'Execute:'+sQuery);
//      squery := StringReplace(sQuery, '''', '\''', [rfReplaceAll]);
//      squery := StringReplace(sQuery, '"', '''', [rfReplaceAll])
      //ds := connection.CreateDataSet(nil);
      var qq := TUniQuery.create(nil);
      qq.Connection := connection;
      ds := qq;
      try
        //qq.Options.TrimFixedChar :=false;
//        qq.Options.TrimVarChar :=false;
        qq.SQL.text := sQuery;

        var retry := 0;
        repeat
          try
            ds.Active := true;
            break;
          except
            on E: Exception do begin
              inc(retry);
              Debug.Log('DB Exception :'+e.message+' ... will retry ... #'+retry.tostring);
              if retry >= 4 then
                raise;
              sleep(1000*retry);
            end;
          end;
        until false;



      except
        ds.free;
        ds := nil;
        raise;
      end;

    except
      on E: Exception do begin
        if zpos('gone away', lowercase(e.message))>= 0 then begin
          Connection.Connected := false;
          Connection.Connected := true;
          inc(rc);
          bRetry := rc < 30;
          Debug.Log(self,'RETRYING after '+e.Message+' #'+inttostr(rc));

        end else
        if zpos('can''t connect to ', lowercase(e.message))>= 0 then begin
          inc(rc);
          bRetry := rc < 30;
          Debug.Log(self,'RETRYING after '+e.Message+' #'+inttostr(rc));

        end

        else begin
          Debug.Log(self,'RETRYING after '+e.Message+' #'+inttostr(rc));
          raise;
        end;
      end;
    end;
  until bretry = false;
//  finally
//    Al.Unlock;
//  end;

end;

function TUniDACRDTPDataModule.ExecuteDirect(sQuery: string; connection: TUniConnection): integer;
var
  bREtry: boolean;
  rc: integer;
begin
//  Al.Lock;
//  try
  result := 0;
  rc := 0;
  repeat
    bREtry := false;
    try
      sQuery := Trimstr(sQuery);
      if sQuery='' then
        exit;
      Debug.Log(self,'Execute Direct:'+sQuery);
      var v := connection.ExecSQL(sQuery);
      if VarIsNull(v) then
        result := 0
      else
        result := v;
      inc(rc);
    except
      on E: Exception do begin
        if pos('failed to connect', lowercase(e.message))> 0 then
          bRetry := rc < 15
        else
          raise;

      end;
    end;
  until bretry = false;
//  finally
//    Al.Unlock;
//  end;
end;


procedure TUniDACRDTPDataModule.ExecuteRead(sQuery: string;
  out dataset: TSERowSet);
var
  ds: TCustomDADataSet;
begin
  dataset := nil;

  ExecuteRead_Platform(sQuery, ds);
  try
    dataset := TSERowset.create;
    UniSetToRowSet(dataset, ds, false);
    lastused := getticker;
  finally
    ds.free;
  end;


end;

procedure TUniDACRDTPDataModule.ExecuteRead_Platform(sQuery: string; out dataset: TCustomDADataset);
begin

  WaitForCommands;
  ConnectRead;
{$IFDEF SAVE_MEMORY}
  LockConsole;
{$ENDIF}
  try
    dataset := nil;
    try
      Execute(sQuery, reads, dataset);

    finally
//      dataset.free;
//      dataset := nil;
    end;


  finally
{$IFDEF SAVE_MEMORY}
    UnlockConsole;
{$ENDIF}
  end;
end;



function TUniDACRDTPDataModule.ExecuteSystem(sQuery: string): integer;
var
  sLeft, sRight: string;
begin
  WaitForCommands;
  ConnectSystem;
  sRight := sQuery;
  while SplitString(sRight, '--execute--', sLeft, sRight) do begin
    ExecuteDirect(sLeft, sessiondb);
    lastused := getticker;
  end;
  result := ExecuteDirect(sLeft, sessiondb);
  lastused := getticker;
end;


function TUniDACRDTPDataModule.ExecuteSystem(sQuery: string;
  out dataset: TSERowSet): integer;
begin

  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

function TUniDACRDTPDataModule.ExecuteSystem_Platform(sQuery: string;
  out dataset: TCustomDADataset): integer;
begin
  result := 1;
  WaitForCommands;
  ConnectSystem;
{$IFDEF SAVE_MEMORY}
  LockConsole;
{$ENDIF}
  try
    dataset := nil;
    try
      Execute(sQuery, sessiondb, dataset);

    finally
//      dataset.free;
//      dataset := nil;
    end;


  finally
{$IFDEF SAVE_MEMORY}
    UnlockConsole;
{$ENDIF}
  end;
end;


function TUniDACRDTPDataModule.TableExists(sTable: string): boolean;
var
  t: ni;
  rs: TSERowSet;
begin
  rs := nil;
  try
    result := false;
    ExecuteRead('show tables', rs);
    if rs.RowCount = 0 then
      exit;

    for t:= 0 to rs.RowCount-1 do begin
      if comparetext(rs.Values[0,t], sTable) = 0 then begin
        exit(true);
      end;
    end;

  finally
    rs.Free;
    rs := nil;
  end;

end;

function TUniDACRDTPDataModule.TryGetNextID(iKey: integer; out res: int64): boolean;
var
  i64, iChecksum: int64;
  cmd: byte;
begin
  result := true;
  try
    try
      keybot_link.Connect;
      cmd := 1;
      keybot_link.SendBuf(cmd, 1);
      keybot_link.SendBuf(iKey, 4);
      keybot_link.WaitForData(8000);
      if keybot_link.ReceiveBuf(i64, 8, 0)=0 then begin
        result := false;
        exit;
      end;

      if keybot_link.ReceiveBuf(iChecksum, 8, 0)=0 then begin
        result := false;
        exit;
      end;


      //checksum
      if (not iCheckSum) <> i64 then begin
         result := false;
         exit;
      end;




    finally
      keybot_link.Disconnect;
    end;
    res := i64;
  except
    result := false;
  end;
end;

function TUniDACRDTPDataModule.TrySetNextID(iKey: integer; value: int64): boolean;
var
  i64, iCheckSum: int64;
  cmd: byte;
begin
  result := false;
  try
    try

      keybot_link.Connect;
      cmd := 2;
      keybot_link.SendBuf(cmd, 1);
      keybot_link.SendBuf(iKey, 4);
      keybot_link.SendBuf(value, 8);
      if keybot_link.WaitForData(8000) then begin
        if keybot_link.ReceiveBuf(i64, 8, 0)=0 then begin
          result := false;
          exit;
        end;

        if keybot_link.ReceiveBuf(iCheckSum, 8, 0)=0 then begin
          result := false;
          exit;
        end;

        //checksum
        if (not iCheckSum) <> i64 then begin
           result := false;
           exit;
        end;

        result := true;

      end;
    finally
      keybot_link.Disconnect;
    end;
  except
    result := false;
  end;
end;

procedure TUniDACRDTPDataModule.VerifyContext;
var
  ds: TSERowSet;
  sContext: string;
begin
  exit;

  if ContextVerified then
    exit;

  ds := nil;
  try
    //query the hosts
    ExecuteSystem('select * from se_host where ID="'+self.FID+'"', ds);
    if ds.RowCount = 0 then
      raise EClassException.create('Host Record not found in database for ID:'+FID);
    //TODO 3: Auto add hosts?

    sContext := ds.CurRecordFields['Context'];
    if sContext <> FContext then begin
      ExecuteSystem('update se_host set context="'+StringToHex(FContext)+'" where ID="'+self.FID+'"');

    end else begin
      FContextVerified := true;
    end;



  finally
    ds.free;
  end;

end;

procedure TUniDACRDTPDataModule.WriteOn(ch: TSQLChannel; sQuery: string);
var
  conn: TUniConnection;
  stats: PSQlChannelStats;
  dataset: TCustomDADataset;
begin
  conn := GetChannelObject(ch);
  conn.Connect;
  stats := GetChannelStats(ch);
  inc(stats.WriteQueries);

  WaitForCommands;

  dataset := nil;

  ExecuteDirect(sQuery, conn{, dataset});

end;

{ TDataPool }





function TUniDACRDTPDataModule.ExecuteWrite(sQuery: string;
  out dataset: TSERowSet): integer;
var
  ds: TCustomDADataSet;
begin
  result := 1;
  dataset := nil;

  ExecuteWrite_Platform(sQuery, ds);

  try
    dataset := TSERowset.create;
    UniSetToRowSet(dataset, ds, false);
    lastused := getticker;
  finally
    ds.free;
  end;

end;

function TUniDACRDTPDataModule.ExecuteWriteRaw(sQuery: string): integer;
var
  sLeft, sRight: string;
  ds: TCustomDADataset;
//  slParsed: TStringlist;
  t: ni;
begin
  result := 0;//todo 1: who uses this? what is it for?
  ds := nil;
  try
    ConnectWrite;
    sRight := sQuery;
    sQuery := '';//<-- do this to conserve memory
//    slParsed := ParseString(sRight, '--execute--');
    while SplitString(sRight, '--execute--', sLeft, sRight) do begin
      ExecuteDirect(sLeft,writes);
      IncWrite;
    end;
    ExecuteDirect(sLeft, writes);
    IncWrite;
    lastused := getticker;

//    ConnectWrite;
//    for t:= 0 to slParsed.count-1 do begin
//      ExecuteDirect(slParsed[t], writes);
//    end;

//    slParsed.free;

  finally
    ds.free;
  end;

end;

procedure TUniDACRDTPDataModule.ExecuteWrite_Platform(sQuery: string;
  out dataset: TCustomDADataset);
begin

  WaitForCommands;
  ConnectWrite;
{$IFDEF SAVE_MEMORY}
  LockConsole;
{$ENDIF}
  try
    dataset := nil;
    try
      Execute(sQuery, writes, dataset);
      IncWrite;

    finally
//      dataset.free;
//      dataset := nil;
    end;


  finally
{$IFDEF SAVE_MEMORY}
    UnlockConsole;
{$ENDIF}
  end;
end;





initialization
//TDBXConnectionFActory.GetConnectionFactory.GetDriverNames(itms);
  EnableUniSQL := false;


end.



implementation

end.
