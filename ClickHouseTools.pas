unit ClickHouseTools;


interface

uses
  types, typex,tickcount, sysutils, storageenginetypes, rdtpdb, classes, stringx, betterobject;

function GetDistributedCreateQueries(basetablename: string; cluster: string; fields, storageengine, distributedengine: string):TArray<string>;

function GetReplicatedCreateQuery(basetablename: string; cluster: string; fields: string; orderbyEtc: string): string;
function GetDistributedAndReplicatedCreateQueries(basetablename: string; cluster: string; fields, orderbyEtc: string; sAs: string = ''):TArray<string>;
procedure TouchRowSetTimeStamps(rs: TSERowSet);
procedure PushRowsetToTable(db: IHolder<TRDTPDB>; sTable: string;rs :TSERowset);overload;
procedure PushRowsetToTable(db: TRDTPDB; sTable: string; rs: TSERowSet);overload;


implementation

function GetReplicatedCreateQuery(basetablename: string; cluster: string; fields: string; orderbyEtc: string): string;
begin
  result := 'create table if not exists '+basetablename+'_n on cluster '+cluster+
            fields+
            ' ENGINE = ReplicatedReplacingMergeTree(''/clickhouse/'+cluster+'/tables/{shard}/'+basetablename+'_'+inttostr(getticker)+'_n'',''{replica}'',dtf)'+
            ' '+orderbyetc;


end;

procedure TouchRowSetTimeStamps(rs: TSERowSet);
begin
  rs.IterateMTQI(SIMPLE_BATCH_SIZE,SIMPLE_BATCH_SIZE,procedure (y: int64) begin
    rs.values[0,y] := now();
    rs.values[1,y] := double(now());
  end,[]);
end;

function GetDistributedAndReplicatedCreateQueries(basetablename: string; cluster: string; fields, orderbyEtc: string; sAs: string):TArray<string>;
begin
  var q1 := GetReplicatedCreateQuery(basetablename, cluster, '('+fields+')', orderbyETC);
  var q2 := 'create table if not exists '+basetablename+' on cluster '+cluster+
            '('+fields+') ENGINE = Distributed('''+cluster+''', ''roke'', '''+basetablename+'_n'', shard)'+sAs;

  setlength(result,2);
  result[0] := q1;
  result[1] := q2;

end;

function GetDistributedCreateQueries(basetablename: string; cluster: string; fields, storageengine, distributedengine: string):TArray<string>;
begin
  var t1 := 'create table if not exists '+basetablename+'_n on cluster '+cluster;
  var t2 := 'create table if not exists '+basetablename+' on cluster '+cluster;
  var q1 := t1+' ('+fields+') '+storageengine;
  var q2 := t2+' ('+fields+') '+distributedengine;
  setlength(result,2);
  result[0] := q1;
  result[1] := q2;
end;


procedure PushRowsetToTable(db: IHolder<TRDTPDB>; sTable: string;rs :TSERowset);
begin
  pushrowsettotable(db.o,sTable, rs);
end;
procedure PushRowsetToTable(db: TRDTPDB; sTable: string;rs :TSERowset);
begin

  rs.iterateAC(procedure (sl: TStringList) begin
    sl.add('('+RowToValues_NoParens(rs,rs.cursor,false,true)+')');
  end, procedure (sl: TStringList) begin
    db.WriteQuery('insert into '+sTable+' values '+unparsestring(sl));
  end);

end;




end.
