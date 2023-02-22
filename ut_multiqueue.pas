unit ut_multiqueue;

interface

uses
  debug, globalmultiqueue, ConsoleGlobal, stringx, sysutils;



procedure TestIteration(iter: int64; count: int64);
procedure Test;


implementation

procedure TestIteration(iter: int64; count: int64);
begin
  con.writeEx('Iteration '+inttostr(iter)+' '+commaize(count)+' items.       ');
  ForX_QI(0,count,64, random(10000000), procedure (idx: int64) begin
    //do nothing
  end,[]);
end;

procedure Test;
begin
  var iter: int64 := 0;
  while true do begin
    TestIteration(iter,random(10000));
    inc(iter);
  end;

end;

end.
