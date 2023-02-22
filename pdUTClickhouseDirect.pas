unit pdUTClickhouseDirect;

interface


uses
  MySQLUniProvider, uni, mysqlstoragestring,
  SysUtils, Classes, DBAccess, variants, clickhousetools,
  betterobject,
  commandline,
  systemx,
  mysqldirect,
  commandprocessor,
  dir,typex,stringx,
  consoleglobal,consolex,
  dirfile;


const
  cluster = 'sar';
type

  TpdUTCH = class(TBetterobject)
  public
    con: Tconsole;
    dbInfo: TDbinfo;
    folder: string;
    procedure log(s: string);
    procedure Go;

  end;






implementation

{ TpdCSVtoDB }

procedure TpdUTCH.Go;
begin
  log('create database ch_ut');
  var conn := NewConnection(dbinfo);
  WriteQuery(conn.o, 'create database if not exists asdf  ');
  conn := NewConnection(dbinfo);
  dbinfo.remotehost := '192.168.101.181';
  WriteQuery(conn.o, 'create database if not exists asdf  ');
  dbinfo.remotehost := '192.168.101.180';
  conn := NewConnection(dbinfo);
//  WriteQuery(NewConnection(dbinfo).o,'drop table if exists correction on cluster '+cluster);
//  WriteQuery(NewConnection(dbinfo).o,'drop table if exists correction_n on cluster '+cluster);
//  sleep(4000);

  var qs := clickhousetools.GetDistributedCreateQueries(
    'correction',CLUSTER,
    'chdate Date, dtf Double, shard UInt64, name String ',
    'ENGINE = ReplacingMergeTree(dtf) ORDER BY (name)',
    'ENGINE = Distributed('''+CLUSTER+''', ''asdf'', ''correction_n'', shard)'
  );
  log(qs[0]);
  log(qs[1]);
  WriteQuery(NewConnection(dbinfo).o,qs[0]);
  WriteQuery(NewConnection(dbinfo).o,qs[1]);
  WriteQuery(NewConnection(dbinfo).o,'truncate table correction_n on cluster '+cluster);

  WriteQuery(NewConnection(dbinfo).o,'insert into correction values(now(),'+gvs(double(now))+',0,'+gvsch('Somebody‘s Been Sleeping')+')');




  log('finish');


end;

procedure TpdUTCH.log(s: string);
begin
  if assigned(con) then
    con.WriteLnEx(s);
end;


{ TcmdImport }


end.
