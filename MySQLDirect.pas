unit MySQLDirect;

interface

uses
    MySQLUniProvider, uni, betterobject, sysutils;

type
  Tdbinfo = record
    remotehost: string;
    port: nativeint;
    username: string;
    password: string;
    database: string;
    procedure Init;
  end;

function NewConnection(dbinfo: TDbInfo): IHolder<TUniConnection>;
function NewQuery(conn: TUniConnection): IHolder<TUniQuery>;
procedure WriteQuery(conn: TUniConnection; q: string);


implementation


function NewQuery(conn: TUniConnection): IHolder<TUniQuery>;
begin
  result := THolder<TUniQuery>.create(TUniQuery.Create(nil));
  result.o.Connection := conn;
end;

function NewConnection(dbinfo: TDbInfo): IHolder<TUniConnection>;
begin
  result := THolder<TUniConnection>.create(TUniConnection.Create(nil));
  result.o.ConnectString := 'Provider Name=MySQL;Database='+dbinfo.database+';port='+dbinfo.port.tostring+';Data Source='+dbinfo.remotehost+';User ID='+dbinfo.username+';password='+dbinfo.password;
  result.o.SpecificOptions.Values['Charset'] := 'utf8mb4';
  result.o.SpecificOptions.Values['UseUnicode'] := 'True';
end;

procedure WriteQuery(conn: TUniConnection; q: string);
begin
  conn.ExecSQL(q);

end;



procedure Tdbinfo.Init;
begin
  remotehost := 'localhost';
  port := 3306;
  username := 'root';
  password := '';


end;


end.
