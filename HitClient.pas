unit HitClient;

interface

uses
  tickcount, sysutils, betterobject, orderlyinit, rdtpdb,  mysqlstoragestring, stringx, systemx;



procedure RecordHit(method: string; ip: string; ts: TDateTime; runtime: int64; page: string; url: string; useragent: string; size: UInt64; referer: string);


var
  HitGiver: TGiverOf<TRDTPDB>;
  PROJCODE: string = '';

implementation

procedure ConfigureCHDBConnection(db: TRDTPDB);
begin
  db.DBHost := '192.168.101.180';
  db.clusternode := 0;
  db.MWHost := '192.168.101.149';
  db.MWEndPoint := '235';
  db.DBuser := 'default';
  db.DBpassword := '';
  db.database := 'logdb';
end;

function NeedDB: IHolder<TRDTPDB>;
begin
  result := HitGiver.need;
  if result.o.context = '' then
    ConfigureCHDBConnection(result.o);

end;

procedure RecordHit(method: string; ip: string; ts: TDateTime; runtime: int64; page: string; url: string; useragent: string; size: UInt64; referer: string);
begin
  var db := NeedDB;

{
   `chdate` Date,
    `shard` UInt64,
    `filelineidx` UInt64,
    `ip` String,
    `rqid` Int64,
    `file` String,
    `ts` DateTime,
    `tsf` Float64,
    `runtime` Int64,
    `page` String,
    `url` String,
    `useragent` String,
    `size` UInt64,
    `referer` String,
    `projcode` String
}

  var id: int64 := trunc(now()*24*60*60*1000)+getticker;
  var q := 'insert into requests values ('+
    'now(),'+gvs(id)+',0,'+gvs(ip)+','+gvs(id)+','''','+gss(varDate, ts)+','+
    gss(varDouble,ts)+','+gvs(runtime)+','+gvs(page)+','+gvs(method+' /'+url)+','+
    gvs(useragent)+','+gvs(size)+','+gvs(referer)+','+gvs(projcode)+
  ')';
  //SaveStringAsFile(dllpath+'temp.txt', q);
  db.o.WriteQuery(q);
  



end;

procedure oinit;
begin
  HitGiver := TGiverOf<TRDTPDB>.create;
  HitGiver.limit := 8;
end;

procedure ofinal;
begin
  //
end;
  
initialization
  orderlyinit.init.RegisterProcs('HitClient',oinit, ofinal, '');


end.
