unit AccessDB;

interface

uses
  betterobject, sysutils, systemx, UniProvider, ODBCUniProvider,
  AccessUniProvider, Data.DB, DBAccess, Uni;

type
  TAccessDBinfo = record
    filename: string;
    username: string;
    password: string;
    database: string;
    procedure Init;
  end;

type
  TConnQueryPair = record
    conn: IHolder<TUniConnection>;
    query: IHolder<TUniQuery>;
  end;

function NewConnection(sFileName: string): IHolder<TUniConnection>;overload;
function NewConnection(dbinfo: TAccessDBinfo): IHolder<TUniConnection>;overload;
function NewQuery(conn: TUniConnection): IHolder<TUniQuery>;
procedure WriteQuery(conn: TUniConnection; q: string);
function EasyQuery(sFilename: string; sQuery: string): TConnQueryPair;


implementation

function EasyQuery(sFilename: string; sQuery: string): TConnQueryPair;
begin
  var cc := NewConnection(sfilename);
  var qq := NewQuery(cc.o);
  var q := qq.o;
  q.SQL.text := sQuery;
  q.active := true;
  result.conn := cc;
  result.query := qq;

end;


function NewQuery(conn: TUniConnection): IHolder<TUniQuery>;
begin
  result := THolder<TUniQuery>.create(TUniQuery.Create(nil));
  result.o.Connection := conn;
end;

function NewConnection(sFileName: string): IHolder<TUniConnection>;overload;
var
  dbi: TAccessDBInfo;
begin
  dbi.init;
  dbi.filename := sFileName;
  result := NewConnection(dbi);

end;
function NewConnection(dbinfo: TAccessDBinfo): IHolder<TUniConnection>;
begin
  result := THolder<TUniConnection>.create(TUniConnection.Create(nil));

  result.o.ProviderName := 'Access';
  result.o.Database := dbinfo.filename;
  result.o.Username := 'Admin';
  result.o.LoginPrompt := False;
//  result.o.ConnectString :='Provider Name=Access;User ID=Admin;Database=c:\source\pascal\64\khero\book_imports\mikevegas.mdb;Login Prompt=False';
//  result.o.ProviderName := 'Access'
//  result.o.Server := dbinfo.FileName;
//  result.o.Database := dbinfo.FileName;
//  result.o.DriverVersion := dvAuto;
//  result.o.ConnectString := result.o.ConnectString + 'ColumnWideBinding=false;ConnectionTimeout=15;ExclusiveLock=False;ExtendedAnsiSQL=False;ForceCreateDatabase=False;SystemDatabase=;UseUnicode=true';
//  result.o.SpecificOptions.Values['User ID'] := 'Admin';
//  result.o.datasourceprovider := 'Access';

//  result.o.SpecificOptions.Values['Charset'] := 'utf8mb4';
  //result.o.SpecificOptions.Values['UseUnicode'] := 'True';
  result.o.Connect;
end;

procedure WriteQuery(conn: TUniConnection; q: string);
begin
  conn.ExecSQL(q);

end;



procedure TAccessDBinfo.Init;
begin
  username := '';
  password := '';


end;


end.
