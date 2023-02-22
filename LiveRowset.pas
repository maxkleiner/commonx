unit LiveRowset;

interface

uses
  betterobject, systemx, stringx, sysutils, managedthread, commandprocessor, variants,
  typex,numbers,mysqlstoragestring, storageenginetypes, rdtpdb, classes;


type
  TLiveRowset = class(TSharedObject)
  strict protected
    rsh: IHolder<TSERowSet>;
  private
    procedure Reset;
  public
    provideclient: TFunc<IHolder<TRDTPDB>>;
    rs: TSERowSet;

    table: string;
    alter_table: string;
    filter: string;
    keyfield: string;

    function Query: string; virtual;
    procedure Commit;virtual;
    procedure Refresh;virtual;
    function o: TSERowset;inline;

  end;



implementation

{ TLiveRowset }

procedure TLiveRowset.Commit;
begin



  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

function TLiveRowset.o: TSERowset;
begin
  result := rs;
end;

function TLiveRowset.Query: string;
begin
  result := 'select * from '+table;
  if filter <> '' then
    result := result + ' where '+filter;

end;

procedure TLiveRowset.Refresh;
begin
  var dbh := provideclient();
  rsh := dbh.o.ReadQueryH(query);
  rs := rsh.o;

  Reset;

end;

procedure TLiveRowset.Reset;
begin
  rs.reset(false);

end;

end.
