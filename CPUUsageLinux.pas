unit CPUUsageLinux;

interface

uses
  stringx, betterobject, classes, sysutils, SysUsageTypes;

function GetCPUUsages(old: TArray<TCPUUsage>): TArray<TCPUUsage>;

function OldSkoolReadProcStat: IHolder<TStringlist>;

implementation
var
  didone: boolean = false;

function GetCPUUsages(old: TArray<TCPUUsage>): TArray<TCPUUsage>;
begin
  var slh := OldSkoolReadProcStat;
  var sl := slh.o;

  setlength(result, sl.count);

  if length(old) <> slh.o.count then
    exit;

  for var t:= 0 to high(result) do begin
    Writeln(sl[t]);
    var parsed := ParseStringH(sl[t],' ');
    var sum: int64 := 0;
    for var u := parsed.o.count-1 downto 0 do begin
      if parsed.o[u] = '' then
        parsed.o.delete(u);
    end;

    for var u := 1 to parsed.o.count-1 do begin
//      WriteLn(parsed.o[u]);
      sum := sum + strtoint64(parsed.o[u]);
    end;
    var idle: int64 := strtoint64(parsed.o[4]);
    result[t].liIdleTime.QuadPart := idle;
    result[t].liActiveTime.QuadPart := sum-idle;
    result[t].liSystemTime.QuadPart := sum;
    var activeDelta := result[t].liActiveTime.QuadPart - old[t].liActiveTime.QuadPart;
    if didone then begin
      result[t].deltaIdleTime := idle-old[t].liIdletime.quadpart;
      result[t].deltaSystemTime := sum-old[t].liSystemTime.quadpart;
      result[t].max := 1.0;
      result[t].usage := (result[t].deltaSystemTime-result[t].deltaIdleTime)/result[t].deltaSystemTime;
    end else begin
      result[t].deltaIdleTime := 0;
      result[t].deltaSystemTime := 0;
      result[t].max := 1.0;
      result[t].usage := 0.0;
      didone := true;
    end;
//    Writeln((result[t].deltaSystemTime-result[t].deltaIdleTime).tostring+'/'+result[t].deltaSystemTime.tostring);


  end;

end;

function OldSkoolReadProcStat: IHolder<TStringlist>;
begin
  result := NewStringListH();
  var f: textfile;
  assignfile(f, '/proc/stat');
  try
    FileMode := fmOpenRead;
    reset(f);
    while not eof(f) do begin
      var s: string;
      readln(f,s);
      if zcopy(s,0,3)='cpu' then begin
        if not (zcopy(s,0,4)='cpu ') then begin
          result.o.add(s);
        end;
      end;
    end;
  finally
    closefile(f);
  end;
end;

end.
