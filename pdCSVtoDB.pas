unit pdCSVtoDB;

interface


uses
  MySQLUniProvider, uni, mysqlstoragestring,
  SysUtils, Classes, DBAccess, variants,
  betterobject,
  commandline,
  systemx,
  mysqldirect,
  commandprocessor,
  dir,typex,stringx,
  consoleglobal,consolex,
  dirfile;



type

  TcmdImport = class(TCommand)
  protected
    procedure DoExecute; override;

 public
    con: Tconsole;
    fil: string;
    dbinfo: TdbInfo;
    procedure Log(s: string); override;
    procedure InitExpense; override;
  end;

  TpdCSVtoDB = class(TBetterobject)
  public
    con: Tconsole;
    dbInfo: TDbinfo;
    folder: string;
    procedure log(s: string);
    procedure Go;

  end;






implementation

{ TpdCSVtoDB }

procedure TpdCSVtoDB.Go;
var
  dir: TDirectory;
  fil: TFileInformation;
  cl: Tcommandlist<TcmdImport>;
begin
  cl := TCommandlist<TcmdImport>.create;
  try

    dir := Tdirectory.Create(Self.folder, 'data_*.csv',0,0);
    try
      while dir.GetNextFile(fil) do begin
        var c := TcmdImport.Create;
        c.fil := fil.FullName;
        c.start;
        c.dbinfo := self.dbInfo;
        c.con := self.con;
        c.Start;
        cl.Add(c);


      end;

    finally
      dir.Free;
    end;

    cl.WaitForAll_DestroyWhileWaiting;
  finally
    cl.Free;
  end;

end;

procedure TpdCSVtoDB.log(s: string);
begin
  if assigned(con) then
    con.WriteLnEx(s);
end;


{ TcmdImport }

procedure TcmdImport.DoExecute;
begin
  inherited;

  var conn := NewConnection(dbinfo);
  var tblsplit := ParseStringh(extractfilename(fil),'_');
  tblsplit.o.Delete(0);
  for var t := 1 to 6 do
    tblsplit.o.Delete(tblsplit.o.Count-1);

  var tbl := unParseString('_', tblsplit.o);

  try
  WriteQuery(conn.o, 'truncate table '+tbl);

  WriteQuery(conn.o,
              'LOAD DATA INFILE '+gvs(fil)+
              ' INTO TABLE '+tbl+
              ' FIELDS TERMINATED BY '','''+
              ' ENCLOSED BY ''"'''+
              ' LINES TERMINATED BY ''\n'''+
              ' IGNORE 1 ROWS;'
            );
  except
  end;


  log('file: '+fil);
end;

procedure TcmdImport.InitExpense;
begin
  inherited;
//  memoryexpense := 1.0;
end;

procedure TcmdImport.Log(s: string);
begin
  inherited;
  if assigned(con) then
    con.WriteLnEx(s);
end;

end.
