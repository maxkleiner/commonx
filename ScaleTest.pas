unit ScaleTest;

interface

uses
  stringx,commandprocessor, systemx, typex, AnonCommand, SimpleQueue, tickcount, consoleglobal, globalmultiqueue;

const
  NUM_ELEMS = 1000000000;

var
  dyndata: array of int64;
  //staticdata: array[0..NUM_ELEMS] of int64;

procedure SetupData;

function CheckBatchSize(sz: nativeint): double;
function CheckSimpleIteration: double;

procedure GoTest;


implementation


procedure GoTest;
begin
  SetupData;
  CheckSimpleIteration;
  CheckBatchSize(65536);
  CheckBatchSize(32768);
  CheckBatchSize(16384);
  CheckBatchSize(8192);
  CheckBatchSize(4096);
  CheckBatchSize(2048);
  CheckBatchSize(1024);
  CheckBatchSize(512);
  CheckBatchSize(256);
  CheckBatchSize(128);
  CheckBatchSize(64);
  CheckBatchSize(32);
  CheckBatchSize(16);
  CheckBatchSize(8);
  CheckBatchSize(4);
  CheckBatchSize(2);
  CheckBatchSize(1);
  sleep(300000);
end;

procedure SetupData;
begin
  setlength(dyndata,NUM_ELEMS);
  for var t:= 0 to high(dyndata) do
    dyndata[t] := random(65336)+1;
end;

function CheckBatchSize(sz: nativeint): double;
begin
  var tmStart := GetTicker;
  con.writeln('check sz '+commaize(sz));
  ForX_QI(low(dyndata),length(dyndata),sz,sz,procedure (t: int64) begin
    dyndata[t] := round(sqrt(dyndata[t]*dyndata[t]));

  end,[]);
  con.Writeln('    sz '+commaize(sz)+' in '+commaize(gettimesince(tmStart)));
  result := 0.0;

end;

function CheckSimpleIteration: double;
begin
  var tmStart := GetTicker;
  for var t:= low(dyndata) to high(dyndata) do begin
    dyndata[t] := round(sqrt(dyndata[t]*dyndata[t]));
  end;
  con.WriteLn('Simple Iteration in '+commaize(gettimesince(tmStart)));
  result := 0.0;
end;

end.
