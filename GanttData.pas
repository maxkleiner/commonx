unit GanttData;

interface


uses
  simplequeue,graphics, classes, types,tickcount, typex, stringx, systemx, sysutils, dxtypes, debug, anoncommand, commandprocessor, numbers, globalmultiqueue, storageenginetypes, consolelock;

const
  OVERLAP_CHECK_WIDTH = 4000;
  INCIDENT_THRESHOLD = 3.0;
type


//  70.166.249.130 - - [13/Feb/2020:06:25:08 +0000]
// "GET /fastcrib2/notificationMessage/ajaxGetNotifications?YII_CSRF_TOKEN=b2b4742f58c3dcc2473c62379b006d36f58448bc&user_id=2274&company_id=44&firstRunOnPage=false&_=1581566878285 HTTP/1.1"
// 200
// 3307
// "https://fastcrib.com/fastcrib2/customerPartCribMap/index?CustomerPartCribMap%5Bid%5D=&CustomerPartCribMap%5Bcu2_location_search%5D=&CustomerPartCribMap%5Bcu3_crib_search%5D=&CustomerPartCribMap%5Bbi1_id_default%5D=&CustomerPartCribMap%5Btotal_bins_search%5D=&CustomerPartCribMap%5Bpa3_customer_part_number_search%5D=&CustomerPartCribMap%5Bpa3_manufacturer_item_number_search%5D=&CustomerPartCribMap%5Bpreferred_supplier_search%5D=&CustomerPartCribMap%5Bpa3_customer_part_description_search%5D=&CustomerPartCribMap%5Bpa4_total_available_quantity_search%5D=&CustomerPartCribMap%5Bpa4_total_available_quantity_search_status%5D=&CustomerPartCribMap%5Bpa4_total_on_hand_quantity_search%5D=&CustomerPartCribMap%5Bpa3_package_quantity_search%5D=&CustomerPartCribMap%5Bcurrency_converted_price%5D=&CustomerPartCribMap%5Bcr1_id_location%5D=&CustomerPartCribMap%5Bpa3_unit_search%5D=&CustomerPartCribMap%5Bpa4_total_min_quantity_search%5D=&CustomerPartCribMap%5Bpa4_total_max_quantity_search%5D=&CustomerPartCribMap%5Bor2_total_order_quantity_search%5D=&CustomerPartCribMap%5Bimage_link_search%5D=&CustomerPartCribMap%5Bcu5_active%5D=&CustomerPartCribMap%5Bpa3_is_kit_template_search%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_1%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_2%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_3%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_4%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_5%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_6%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_7%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_8%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_9%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_10%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_11%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_12%5D=&CustomerPartCribMap%5Bpa3_custom_attribute_13%5D=&CustomerPartCribMap%5Bcu5_consignment%5D=&CustomerPartCribMap_page=1&yt4="
// "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36"
//  IP
//date
//0=url/command
//1=code
//2=time
//3=referer
//4=UserAgent
  TIncidentSummary = record
    minute: integer;
    duration: integer;
  end;
  TganttRecord = record
    ip: string;
    dateutc: string;
    urlandparams: string;
    url: string;
    params: string;
    httpver: string;
    method: string;
    resultcode: string;
    runtime: double;
    referer: string;
    date: TDateTime;
    runtimef: TDateTime;
    useragent: string;
    track: ni;
    sz: int64;
    valid: boolean;
    color: TColor;
    procedure FromLogLine(sLine: string);
    procedure FromRow(rs: TSERowset; iRow: ni);
    procedure Decode;
    function endtime: TDateTime;
  private
    function GetHead: string;
    procedure SetHead(const Value: string);
  public
    function ToString: string;
    property head: string read GetHead write SetHead;
  end;

  PGanttRecord = ^TGanttRecord;

  TMinuteSummary = record
    hits: int64;
    threads: int64;
    threadtimesSecs: single;
    timeInMS: int64;
    startedRequests: int64;
    finishedRequests: int64;
    startedUnfinishedRequests: int64;
    MaxTrack: integer;
    firstRecIndex,lastRecIndex: int64;
    finishedPriorRequests: int64;
    continuingRequests: int64;//requests started before and finished after this minute
    function activeRequests: int64;
    function UnfinishedRequests: int64;
    function Avg: single;
    function AvgInSeconds: single;
    function LowerChartvalue: single;
    function laggedThreads: single;
    procedure init;
    procedure initOpen(high: int64);
  end;
  PMinuteSummary = ^TMinuteSummary;

  TMinuteSummaries = record
  strict private
    FMaxAvg: single;
    foundmax: boolean;
    FMaxAvgMinute: fi;
    FMaxUnfinished: single;
    FMaxUnfinishedMinute: fi;
    FMaxThreadTimeSecs: single;
    FMaxThreadTimeMinute: int64;
    FMaxLaggedThreads: single;
    FMaxLaggedThreadsMinute: int64;
  public
    minutes: array of TMinuteSummary;
    MaxTrack: integer;
    procedure CalcMax;
    function maxavg: single;
    function maxavgminute: fi;
    function maxunfinished: single;
    function maxUnfinishedMinute: fi;
    function maxthreadtimesecs: single;
    function maxthreadtimeminute: int64;
    function maxLowerChart: single;
    function maxLowerChartMinute: int64;
    function maxLaggedThreads: single;
    function maxLaggedThreadsMinute: int64;
    function GetIncidentMinuteCount: int64;
    function GetIncidentMinutes: Tarray<int64>;
    function GetIncidentMinuteSummary: Tarray<TIncidentSummary>;
    procedure Init;


  end;

  TGanttData = record
  strict private
    procedure Analyze_GenerateMinuteSummaries();
  private
    function Analyze_CountTracksMinute(m: int64; maxTrackKnown: integer): int64;


  public
    minuteSummaries: TMinuteSummaries;
    minx,maxx: TDateTime;
    startday: TDateTime;
    maxtrack: ni;
    recs: TArray<TGanttRecord>;
    selected: PGanttRecord;
    loadedFrom: string;
    progproc: TProc<TProgress>;
    function GetMinuteSummaryForMinute(dt:TDateTime): TMinuteSummary;
    function GetMaxAvgMinuteValue: single;
    function GetMaxAvgMinute: int64;
    function GetMaxUnfinishedMinuteSummary: single;
    function GetMaxUnfinishedMinute: int64;
    function GetMaxThreadTimeSecs: single;
    function GetMaxThreadTimeMinute: int64;
    function GetLowerChartMax: single;
    function GetLowerChartMaxMinute: int64;



    Procedure LoadFromfile(sfile: string; bNoAnalyze: boolean = false);
    Procedure LoadFromRowset(rs: TSERowset; bNoAnalyze: boolean);
    procedure SaveToDayLogs;
    function Loaded: boolean;
    procedure Analyze();
    procedure CheckOverlap(idx: ni;width: ni;bReset: boolean; multiplytime: ni);
    procedure CalcMaxTrack;
    procedure SearchPoint(x,y: double);
    procedure ApplyColors(url: string; color: TColor);overload;
    procedure ApplyColors(urls: TArray<string>; colors: Tarray<Tcolor>);overload;
    procedure ApplyColorsUA(UA: string; color: TColor);
    procedure ResetColors;
  end;

  PGanttData = ^TGanttData;


var
  datalock: TCLXCriticalSection;


implementation

{ TganttRecord }

procedure TganttRecord.Decode;
begin
  var l,r,day,month,year,h,m,s,ms: string;
  var monthint: ni;

  if zcopy(dateutc,0,1) = '[' then begin
  //13/Feb/2020:06:25:08 +0000
    var start := zcopy(dateutc,1,length(dateutc)-2);
    SplitString(start,'/',day,month);
    SplitString(month,'/',month, year);
    Splitstring(year,':',year,h);
    SplitString(h,':',h,m);
    SplitString(m,':',m,s);
    SplitString(s,' ',s, ms);
    ms := '0';
    monthint := MonthToInt(month,true);



  end else begin

    SplitString(dateutc, '-', year, month);
    SplitString(month, '-', month, day);
    SplitString(day, ' ', day, h);
    SplitString(h, ':', h,m);
    SplitString(m, ':', m,s);
    SplitString(s, '.', s,ms);
    SplitString(ms, ' ', ms,r);
    ms := zcopy(ms, 0,4);
    monthint := monthtoint(month,true);
  end;



  //EncodeDate(strtoint(year),strtoint(month), strtoint(day));

  if monthint =0 then begin
    self.date := 0.0;
    self.valid := false;
  end else begin
    var time: TDateTime := (strtoint(h)/24)+(strtoint(m)/(24*60))+(strtoint(s)/(24*60*60)+(strtoint(ms)/(24*60*60*1000)));
    var date: TdateTime := EncodeDate(strtoint(year), monthint, strtoint(day));
    self.date := date+time-(6/24);
  end;

  runtimef := ((runtime / 1000)/(24*60*60));
//  if runtimef = 7514.10 then
//    Debug.Log('here');


end;

function TganttRecord.endtime: TDateTime;
begin
  result := date + runtimef;
end;

procedure TganttRecord.FromLogLine(sLine: string);
const
  OFFSET = 2;
begin
  color := clGray;
  var l,r: string;
  sLine := stringreplace(sLine, '\"','',[rfReplaceAll]);
//  sLine := StringReplace(sLine, ' - - ', ' ', []);
//  sLine := StringReplace(sLine, ' - root ', ' ', []);
  var slh := ParseStringNotInH(sLine,' ', '"');
  if slh.o.count <5 then begin
    valid := false;
  end else
  if (slh.o.count <9) and (slh.o.count >7) then begin
    try
    ip := slh.o[0];
    dateutc := slh.o[1]+' '+slh.o[2];
    head:= unquote(slh.o[3]);
    resultcode := slh.o[4];
    runtime := 250;//we don't know the runtime, assume typical 1/4 second
    var s := slh.o[5];
    if IsInteger(s) then
      sz := strtoint64(s)
    else
      sz := 0;
    if slh.o.count > 6 then begin
      referer := slh.o[6];
      useragent := slh.o[7];
    end else begin
      referer := '';
      useragent :='';
    end;
    decode;
    except
    valid := false;
    end;
  end else begin
    try
    if slh.o.count >= 11 then begin
        if zpos(':',slh.o[1]) < 0 then begin
          head:= unquote(slh.o[3+OFFSET]);
  //        if zpos('c1e5', head) >=0 then
  //          Debug.log('here');
          ip := slh.o[0];
          dateutc := slh.o[1+OFFSET]+' '+slh.o[2+OFFSET];

          resultcode := slh.o[4+OFFSET];
          sz := strtoint64(slh.o[6+OFFSET]);//strtoint64(slh.o[6+OFFSET]);
          var rt := slh.o[5+OFFSET];
          if zpos('.', rt) >=0 then
            runtime := strtofloat(rt)*1000
          else
            runtime := strtoint64(rt);

          referer := slh.o[7+OFFSET];
          useragent := slh.o[8+OFFSET];
          decode;
          valid := true;
        end else
          //2022/08 format
        begin
          const OFFSET_2022 = 0;
          head:= unquote(slh.o[3+OFFSET]);
  //        if zpos('c1e5', head) >=0 then
  //          Debug.log('here');
          ip := slh.o[0];
          if zpos('-',ip)>=0 then
            ip := slh.o[2];
          dateutc := slh.o[0]+' '+slh.o[1];

          resultcode := slh.o[4+OFFSET];
          sz := strtoint64(slh.o[5+OFFSET]);//strtoint64(slh.o[6+OFFSET]);
          var rt := slh.o[8+OFFSET];
          if zpos('.', rt) >=0 then
            runtime := strtofloat(rt)*1000
          else begin
            try
              runtime := strtoint64(rt);
            except
              on E: exception do begin
                e.message := e.message + ' processing line:' +sLine;
                raise;
              end;
            end;
          end;

          referer := slh.o[6+OFFSET];
          useragent := slh.o[7+OFFSET];
          decode;
          valid := true;
        end;

    end;
    except
    end;
  end;
end;

procedure TganttRecord.FromRow(rs: TSERowset; iRow: ni);
{
              '  `chdate` DATE, '+
              '  `shard` UInt64, '+
              '  `ip` varchar(23), '+
              '  `rqid` bigint(20), '+
              '  `file` varchar(16), '+
              '  `ts` datetime, '+
              '  `tsf` double, '+
              '  `runtime` bigint(20), '+
              '  `page` text, '+
              '  `url` text, '+
              '  `referer` text, '+
              '  `projcode` varchar(12) ';

}
begin
  self.track := 0;
  color := clGray;
  self.ip := rs.ValuesN['ip',iRow];
  self.date := rs.ValuesN['tsf', iRow];
  self.dateutc := FormatDateTime('YYYY-MM-DD hh:mm:ss', rs.valuesn['ts',iRow]);
  self.runtime := rs.valuesn['runtime',iRow];

  var junk: string := '';
  var sl: string := rs.valuesn['url',iRow];
  self.head := sl;//get /some/url/ http/1.1 ... split by record functions
  self.sz := rs.valuesn['size',iRow];
  self.useragent := rs.valuesn['useragent',iRow];
//  self.page := rs.valuesn['url',iRow];
  self.referer := rs.valuesn['referer', iRow];
  runtimef := ((runtime / 1000)/(24*60*60));
  valid := true;
//  Decode;




end;

function TganttRecord.GetHead: string;
begin
  result := method+' '+urlAndParams+' '+httpver;
end;

procedure TganttRecord.SetHead(const Value: string);
var
  l,r: string;
begin
  SplitString(value, ' ', l,r);
  method := l;
  SplitString(r, ' ', urlandparams,httpver);
  SplitString(urlandparams, '?', l,r);
  url := l;
  params := r;

end;

function TGanttRecord.ToString: string;
begin
  result := ip+' - - '+dateutc+' '+quote(head)+' '+resultcode+' '+floattostr(runtime)+' '+inttostr(sz)+' '+referer+' '+useragent;

end;


{ TGanttData }

procedure TGanttData.Analyze();
begin
  if length(recs) = 0 then
    exit;

  for var t:=0 to high(recs) do begin
    minx := recs[t].date;
    if minx <> 0.0 then
      break;
  end;

  startday := trunc(minx);
  maxx := (recs[high(recs)].date)+recs[high(recs)].runtimef;

{x$DEFINE NO_CHECK_OVERLAP}
{$IFNDEF NO_CHECK_OVERLAP}
{x$DEFINE NOMTOVERLAP}
{$IFDEF NOMTOVERLAP}
  for var t:= 0 to high(recs) do begin
    if t and $FFF = 0 then
      Debug.Log('Checking overlaps '+t.ToString);
    CheckOverlap(t,OVERLAP_CHECK_WIDTH);
  end;
{$ELSE}
  //ITERATION 1
  begin
    var cx := length(recs);
    var idx: ni := 0;

    var pg: PGanttData := @self;
    var cl := TCommandList<TCommand>.create;
    try
      while cx > 0 do begin
        var group := (length(recs) div GetEnabledCPUCount)+1;
        var ac := InlineIteratorGroupProc(idx, lesserof(group,cx),
          procedure (idx: int64) begin
            pg.CheckOverlap(idx,OVERLAP_CHECK_WIDTH, true, 1);
          end
        );

        cl.Add(ac);
        inc(idx, group);
        dec(cx, group);
      end;

      cl.WaitForAll_DestroyWhileWaiting;

    finally
      cl.free;
    end;
  end;
  //ITERATION 2
  begin
    var cx := length(recs);
    var idx: ni := 0;

    var pg: PGanttData := @self;
    var cl := TCommandList<TCommand>.create;
    try
      while cx > 0 do begin
        var group := (length(recs) div GetEnabledCPUCount)+1;
        var ac := InlineIteratorGroupProc(idx, lesserof(group,cx),
          procedure (idx: int64) begin
            pg.CheckOverlap(idx,OVERLAP_CHECK_WIDTH, false, 1);
          end
        );
        cl.Add(ac);
        inc(idx, group);
        dec(cx, group);
      end;

      cl.WaitForAll_DestroyWhileWaiting;

    finally
      cl.free;
    end;
  end;
{$ENDIF}
{$ENDIF}
  CalcMaxTrack;
  Analyze_GenerateMinuteSummaries();

end;

procedure TGanttData.ApplyColors(url: string; color: TColor);
begin
  var idx : nativeint := 0;
  var r := recs;
  ForX_QI(0, high(recs), 10000, procedure (idx: int64) begin
    if CompareText(r[idx].url, url)=0 then
      r[idx].color := color;
  end,[fxEndinclusive]);
end;

procedure TGanttData.ApplyColorsUA(UA: string; color: TColor);
begin
  var idx : nativeint := 0;
  var r := recs;
  var plat := UserAgentToPlatform(ua);
  ForX_QI(0, high(recs), 10000, procedure (idx: int64) begin
    if CompareText(UserAgentToPlatform(r[idx].useragent), plat)=0 then
      r[idx].color := color;
  end,[fxEndinclusive]);


(*
  while idx < length(recs) do begin
//    InlineIteratorGroupProc(idx, 100000, procedure (iidx: nativeint) begin
      var iidx := idx;
      for var t := iidx to lesserof(high(r),(iidx + 999)) do begin
        if CompareText(r[t].url, url)=0 then
          r[t].color := color;
      end;
//    end);
    inc(idx, 1000);
  end;
*)
end;

function TGanttData.Analyze_CountTracksMinute(m: int64; maxTrackKnown: integer): int64;
var
  r: TganttRecord;
  aHas: array of boolean;
begin
  setlength(aHas, maxTrackKnown+1);
  for var t:= 0 to high(aHas) do aHas[t] := false;

  var s := greaterof(0,minuteSummaries.minutes[m].firstRecIndex);
  var e := lesserof(high(recs), minuteSummaries.minutes[m].lastRecIndex);

  for var t := s to e do begin
    r := recs[t];
    if r.track > high(aHAs) then
      setlength(ahas, r.track+1);
    if aHas[r.track] then
      continue;

    var minute:= (r.date-Self.startday)*(60*24);
    var minInt : int64 := trunc(minute);
    var minuteend := minute+(r.runtime/60000);
    var minuteEndint := trunc(minuteend);

    if minInt>m then
      break;
    if minuteEndInt < m then
      continue;

    aHas[r.track] := true;
  end;
  result := 0;
  for var t:= 0 to high(aHas) do
    if aHas[t] then inc(result);

end;

procedure TGanttData.Analyze_GenerateMinuteSummaries();
begin
  ecs(datalock);
  try
    setlength(minuteSummaries.minutes,60*24);
  finally
    lcs(datalock);
  end;
  for var t := 0 to high(minuteSummaries.minutes) do begin
    minuteSummaries.minutes[t].init;
  end;

  maxtrack :=0;



  for var t := 0 to high(recs) do begin
    var minute:= (recs[t].date-Self.startday)*(60*24);
    var minInt : int64 := trunc(minute);
    var minuteend := minute+(recs[t].runtime/60000);
    var minuteEndint := trunc(minuteend);

    //if this rec is BEFORE the lowest index known then set it
    for var mm := minInt to minuteEndInt do begin
      if mm > high(minutesummaries.minutes) then
        continue;
      if mm < 0 then
        continue;
      if t < minutesummaries.minutes[mm].firstRecIndex then
        minutesummaries.minutes[mm].firstRecIndex := t;
      if t > minutesummaries.minutes[mm].lastRecIndex then
        minutesummaries.minutes[mm].lastRecIndex := t;
    end;


    if minute >= 64*24 then
      continue;
    if minute < 0 then
      continue;

    var minny : PMinuteSummary := @minuteSummaries.minutes[minInt];

    for var u := minInt to minuteEndInt do begin
      var trk := recs[t].track;
      if trk > minuteSummaries.minutes[u].MaxTrack then
        minuteSummaries.minutes[u].MaxTrack := trk;
      if maxtrack < trk then
        maxtrack := trk;

      var timeInMinuteSecs := 0.0;
      if minInt = minuteEndint then begin
        timeInMinuteSecs := recs[t].runtime / 1000;
      end else
      if (minInt < u) and (minuteEndInt > u) then begin
        timeInMinuteSecs := 60.0;
      end else
      if (minInt = u) and (minuteEndInt > u) then begin
        timeInMinuteSecs := 60.0-(60.0*(minute-minInt));
      end else
      if (minInt < u) and (minuteEndInt = u) then begin
        timeInMinuteSecs := 60.0*(minuteEnd - minuteEndint);
      end;
      minny^.threadtimesSecs := minny^.threadtimesSecs + timeInMinuteSecs;


      minny^.hits := minny^.hits + 1;

      if u = minInt then begin
        minny^.startedRequests := minny^.startedRequests + 1;
      end;

      if u = minuteEndInt then begin
        minny^.finishedRequests := minny^.finishedRequests+1;
      end;

//      if u = minuteend then
//        minny^.finishedRequests := minny^.finishedRequests+1;


      if (u = minInt) and (u < minuteEndInt) then begin
        minny^.startedUnfinishedRequests :=  minny^.startedUnfinishedRequests+1;
      end;

      if (u > minint) and (u = minuteEndInt) then begin
        minny^.finishedPriorRequests :=  minny^.finishedPriorRequests+1;
      end;

      if (u > minint) and (u < minuteEndInt) then begin
        minny^.continuingRequests :=  minny^.continuingRequests+1;
      end;

      minny^.timeInMS := minny^.timeInMS + round(recs[t].runtime);
    end;
  end;

  minutesummaries.calcmax;

//  for var t := 0 to high(minuteSummaries.minutes) do begin
//    Debug.Log('Minute Index ranges: '+t.tostring+' : '+    commaize(minuteSummaries.minutes[t].firstRecIndex)+' - '+    commaize(minuteSummaries.minutes[t].lastrecindex));
//  end;




//  for var t := 0 to high(minuteSummaries.minutes) do begin
  var dat : PGanttData:= @self;
  ForX(0,high(minuteSummaries.minutes),100,procedure (t: int64) begin
    var cnt := dat^.Analyze_CountTracksMinute(t,dat^.minuteSummaries.minutes[t].MaxTrack);
    dat^.minuteSummaries.minutes[t].MaxTrack := cnt;

  end,[fxEndInclusive], progproc);
//  end;

  minutesummaries.calcmax;//must do again

end;

procedure TGanttData.ApplyColors(urls: TArray<string>; colors: Tarray<Tcolor>);
begin
  var r := recs;
  var aa := urls;
  setlength(aa,length(aa));
  var cc := colors;
  setlength(cc,length(cc));

{$DEFINE COLOR_MT}
{$IFDEF COLOR_MT}
  ForX_QI_NoWait(0, high(recs), 10000, procedure (idx: int64) begin
{$ELSE}
  for var idx := 0 to high(recs) do begin
{$ENDIF}
    for var u := 0 to high(urls) do begin
      if CompareText(r[idx].url, aa[u])=0 then
        r[idx].color := cc[u];
    end;
{$IFDEF COLOR_MT}
  end,[fxEndinclusive]);
{$ELSE}
  end;
{$ENDIF}


end;

procedure TGanttData.CalcMaxTrack;
begin
  maxtrack :=0;
  for var t := 0 to high(recs) do begin
    maxtrack := greaterof(maxtrack,recs[t].track);
  end;
end;

procedure TGanttData.CheckOverlap(idx: ni;width: ni;bReset: boolean; multiplytime: ni);
var
  myrec : PganttRecord;
begin
  myrec := @recs[idx];
  var usewidth := round((myrec.runtime*multiplytime)+width);

  var track:ni := 0;
  if not bReset then
    track := myrec.track;
  var bFoundTrack := false;
  while not bFoundTrack do begin
    bFoundTrack := true;
    //make sure that nothing overlaps us on this track..
    //if collision is found, increment track and start over

    for var t := greaterof(0,idx - usewidth) to lesserof(high(recs), idx+usewidth) do begin

      if t = idx then continue;

      var check: PGanttRecord := @recs[t];

      if check.date = 0.0 then
        continue;

      if check.track <> track then
        continue;

      if check.date > myrec.endtime then
        continue;

      if check.endtime < myrec.Date then
        continue;

      bFoundTrack := false;
//      if myrec.runtimef < check.runtimef then
        inc(track);
//      else
//        inc(check.track);
      break;
    end;
  end;

  myrec.track := track;


end;

function TGanttData.GetLowerChartMax: single;
begin
  result := minuteSummaries.maxLaggedThreads;
end;

function TGanttData.GetLowerChartMaxMinute: int64;
begin
  result := minuteSummaries.maxLaggedThreadsMinute;

end;

function TGanttData.GetMaxAvgMinute: int64;
begin
  result := MinuteSummaries.maxAVgminute;
end;

function TGanttData.GetMaxAvgMinuteValue: single;
begin
  result := Minutesummaries.maxavg;
end;

function TGanttData.GetMaxThreadTimeMinute: int64;
begin
  result := MinuteSummaries.maxthreadtimeminute;

end;

function TGanttData.GetMaxThreadTimeSecs: single;
begin
  result := MinuteSummaries.maxthreadtimesecs;

end;

function TGanttData.GetMaxUnfinishedMinute: int64;
begin
  result := MinuteSummaries.maxUnfinishedMinute;
end;

function TGanttData.GetMaxUnfinishedMinuteSummary: single;
begin
  result := MinuteSummaries.maxUnfinished;
end;

function TGanttData.GetMinuteSummaryForMinute(dt: TDateTime): TMinuteSummary;
begin
  result.init;
  if dt > 10000.0 then
    dt := dt - self.startday;


  //determine minute that DT represends;
  var minute := round(dt * (60*24));

  if minute < 0 then
    exit;
  if minute > high(minutesummaries.minutes) then
    exit;

  result := minutesummaries.minutes[minute];





end;

function TGanttData.Loaded: boolean;
begin
  result := length(recs)> 0;
end;

procedure TGanttData.LoadFromfile(sfile: string; bNoAnalyze: boolean = false);
begin
  minuteSummaries.Init;
  loadedfrom := sfile;
  selected := nil;
  var recs := self.recs;
  var sl: TStringList := nil;
  try
    try
      var tm := GetTicker;
      Debug.Log('loading '+sFile);
{$IFDEF QUICKLOAD}
      var s := LoadStringFromFile(sfile);
      sl := stringToStringList(s);
//      sl.LoadFromFile(sfile);

{$ELSE}
      sl := TStringlist.create;
      sl.loadfromfile(sFile);

      //if the linecount is super-low, line ends might not be right...
      if sl.count < 1000 then
        sl.text := sl.text;
{$ENDIF}

      Debug.Log('loaded '+sl.count.tostring+' recs in '+commaize(gettimesince(tm))+'ms.');
    except
      on E: exception do begin
        Debug.Log(e.message);
      end;
    end;
    if sl.count > 0 then
      sl.delete(0);
    ecs(datalock);
    try
      setlength(recs, sl.count);
    finally
      lcs(datalock);
    end;
    var tmStart := GetTicker;

{$DEFINE SIMPLE_ITERATE}
{$IFDEF SIMPLE_ITERATE}
    begin
      var tm := GetTicker;
      for var t := 0 to sl.count-1 do begin
        recs[t].FromLogLine(sl[t]);
      end;
      debug.log('Simple Iterate:  '+commaize(gettimesince(tm)));
    end;
{$ELSE}
    begin
      var tm := GetTicker;
      ForX(0, sl.count-1, 5000,
        procedure (idx: int64) begin
          recs[idx].FromLogLine(sl[idx]);
        end
      ,[fxEndInclusive]);
      debug.log('ForX_QI Iterate:  '+commaize(gettimesince(tm)));
    end;
{$ENDIF}
//      dEBUG.lOG('Log ends: '+datetimetostr(recs[high(recs)].date));

    self.recs := recs;
    if not bNoAnalyze then
      Analyze;
    Debug.Log('Loaded and parsed in '+commaize(gettimesince(tmStart)));


  finally
    sl.free;
  end;

end;




procedure TGanttData.LoadFromRowset(rs: TSERowset; bNoAnalyze: boolean);
var
  rr_dont_use_in_threaded_version: TganttRecord;
begin
  minuteSummaries.Init;
  var tmStart := Getticker;
  loadedfrom := 'db';
  selected := nil;
  ecs(datalock);
  try
    setlength(recs, rs.rowcount);
  finally
    lcs(datalock)
  end;

  for var t := 0 to high(minuteSummaries.minutes) do begin
    minuteSummaries.minutes[t].initOpen(rs.rowcount-1);
  end;


{x$DEFINE SIMPLE_ITERATE_RS}
{$IFDEF SIMPLE_ITERATE_RS}
    begin
      var tm := GetTicker;
      for var t := 0 to rs.rowcount-1 do begin
        rr_dont_use_in_threaded_version.FromRow(rs,t);
        self.recs[t] := rr_dont_use_in_threaded_version;
      end;
      debug.log('Simple Iterate:  '+commaize(gettimesince(tm)));
    end;
{$ELSE}
  var recs := self.recs;
    begin
      var tm := GetTicker;
      ForX_QI(0, rs.rowcount-1, 256,512,
        procedure (idx: int64) begin
          recs[idx].FromRow(rs,idx);
        end
      ,[]);
      debug.log('MT Load from rowset took:  '+floatprecision(gettimesince(tm)/1000,1)+' seconds');
    end;
    self.recs := recs;
{$ENDIF}
//      dEBUG.lOG('Log ends: '+datetimetostr(recs[high(recs)].date));



    if not bNoAnalyze then
      Analyze;
    Debug.Log('Loaded and parsed in '+commaize(gettimesince(tmStart)));

end;
procedure TGanttData.ResetColors;
begin
  var idx : int64 := 0;
  var r  := recs;

{$DEFINE USE_FORX}
{$IFDEF USE_FORX}
  ForX_QI(0, high(recs), 10000, procedure (idx: int64) begin
    r[idx].color := clGray;
  end,[fxEndInclusive]);
{$ELSE}


  while idx < length(recs) do begin
    InlineIteratorGroupProc(idx, 1000, procedure (iidx: int64) begin
      //var iidx := idx;
      for var t := iidx to lesserof(high(r),(iidx + 999)) do begin
        r[t].color := clGray;
      end;
    end);
    inc(idx, 1000);
  end;

{$ENDIF}
end;

procedure TGanttData.SaveToDayLogs;
var
  path: string;
  lastdate: TDateTime;
  slOut: TStringlist;
    procedure CommitStrings;
    begin
      if slOut <> nil then begin
        var s: string := slash(extractfilepath(loadedFrom))+formatdatetime('YYYYMMDD', lastdate)+'.txt';
        Debug.Log('saving '+s);
        slOut.SaveToFile(s);
        slOut.free;
        slOut := nil;
      end;
    end;
begin
  lastdate := 0.0;
  slOut := nil;
  path := ExtractFilePath(loadedfrom);
  for var t := 0 to high(self.recs) do begin
    if (trunc(lastdate) <> trunc(recs[t].date)) or (slOut=nil) then begin
      //NEW LOG FILE... SETUP
      CommitStrings;
      slOut := TStringlist.create;
    end;

    //write the record
    slOut.Add(recs[t].ToString);
    lastdate := trunc(recs[t].date);
  end;

  CommitStrings;


end;

procedure TGanttData.SearchPoint(x,y: double);
begin
  for var t := 0 to high(recs) do begin
    var prec : PGanttRecord := @recs[t];
    if (prec.date < X)
    and (prec.endtime > x)
    and (prec.track = trunc(y)) then begin
      selected := prec;
      exit;
    end;
  end;

end;

{ TMinuteSummaries }

procedure TMinuteSummaries.CalcMax;
begin
  fMaxAvgMinute := 0;
  FMaxUnfinishedMinute := 0;
  FMaxAvg := 0;
  FMaxUnfinished := 0;
  FMaxThreadTimeSecs := 0;
  FMaxThreadTimeMinute := 0;
  FMaxLaggedThreads := 0;
  FMaxLaggedThreadsMinute := 0;

  for var t := 0 to high(minutes) do begin
    if minutes[t].AvgInSeconds > FMaxAvg then begin
      FMaxAvg := minutes[t].AvgInSeconds;
      FMaxAvgMinute := t;
    end;
    if minutes[t].UnfinishedRequests > FMaxUnfinished then begin
      FMaxUnfinished := minutes[t].UnfinishedRequests;
      FMaxUnfinishedMinute := t;
    end;
    if minutes[t].threadtimesSecs > FMaxThreadTimeSecs then begin
      FMaxThreadTimeSecs := minutes[t].threadtimesSecs;
      FMaxThreadTimeMinute := t;
    end;

    if minutes[t].laggedThreads > FMaxLaggedThreads then begin
      FMaxLaggedThreads := minutes[t].laggedThreads;
      FMaxLaggedThreadsMinute := t;
    end;


  end;

  foundmax := true;

end;

function TMinuteSummaries.GetIncidentMinuteCount: int64;
begin
  result := 0;
  for var t:= 0 to high(minutes) do begin
    if minutes[t].LowerChartvalue > INCIDENT_THRESHOLD  then begin
      inc(result);
    end;
  end;

end;

function TMinuteSummaries.GetIncidentMinutes: Tarray<int64>;
begin
  setlength(result,0);
  for var t:= 0 to high(minutes) do begin
    if minutes[t].LowerChartvalue > INCIDENT_THRESHOLD then begin
      setlength(result,length(result)+1);
      result[high(result)] := t;
    end;
  end;
end;

function TMinuteSummaries.GetIncidentMinuteSummary: Tarray<TIncidentSummary>;
var
  lastmin: integer;
begin
  lastmin := -2;
  var a := GetIncidentMinutes;
  for var t := 0 to high(a) do begin
    if (length(result) = 0)
    or ((lastmin < (a[t]-1)))
    then begin
      setlength(result,length(result)+1);
      result[high(result)].minute := a[t];
      result[high(result)].duration := 1;
      lastmin := a[t];

    end else begin
      inc(result[high(result)].duration);// := 1;
      lastmin := a[t];
    end;


  end;
end;

procedure TMinuteSummaries.Init;
begin
  foundmax := false;
  for var t:= 0 to high(minutes) do
    minutes[t].init;
end;

function TMinuteSummaries.maxavgminute: fi;
begin
  if not foundmax then
    CalcMax;//forces calulation

  result := FMaxAvgMinute;


end;

function TMinuteSummaries.maxLaggedThreads: single;
begin
   if not foundmax then
    CalcMax;

  result := FMaxLaggedThreads;

end;

function TMinuteSummaries.maxLaggedThreadsMinute: int64;
begin
   if not foundmax then
    CalcMax;

  result := FMaxLaggedThreadsMinute;


end;

function TMinuteSummaries.maxLowerChart: single;
begin
  result := maxLaggedThreads;
end;

function TMinuteSummaries.maxLowerChartMinute: int64;
begin
  result := maxLaggedThreadsMinute;

end;

function TMinuteSummaries.maxthreadtimeminute: int64;
begin
  if not foundmax then
    CalcMax;

  result := FMaxThreadTimeMinute;

end;

function TMinuteSummaries.maxthreadtimesecs: single;
begin
   if not foundmax then
    CalcMax;

  result := FMaxThreadTimeSecs;

end;

function TMinuteSummaries.maxunfinished: single;
begin
  if not foundmax then
    CalcMax;

  result := FMaxUnfinished;

end;

function TMinuteSummaries.maxUnfinishedMinute: fi;
begin
  if not foundmax then
    CalcMax;

  result := FMaxUnfinishedMinute;
end;

function TMinuteSummaries.maxAvg: single;
begin
  if not foundmax then
    CalcMax;

  result := FMaxAvg;

end;

{ TMinuteSummary }

function TMinuteSummary.activeRequests: int64;
begin
  result := startedRequests+finishedRequests+continuingRequests;
end;

function TMinuteSummary.Avg: single;
begin
  if hits = 0 then
    exit(0.0);

  result := timeInMS/hits;
end;

function TMinuteSummary.AvgInSeconds: single;
begin
  result := avg / 1000;
end;

procedure TMinuteSummary.init;
begin
  FillMem(@self, sizeof(self),0);
  lastRecIndex := -1;
//  firstrecindex := 0;
  firstRecIndex := 4200000000;
//  hits := 0.0;

end;

procedure TMinuteSummary.initOpen(high: int64);
begin
  Init;
  firstRecIndex := 0;
  lastRecIndex := high;
end;

function TMinuteSummary.laggedThreads: single;
begin
  if finishedRequests = 0 then
    exit((threadtimesSecs/60));
  result := (threadtimesSecs/60)/finishedRequests;
  result := result * maxTrack;
end;

function TMinuteSummary.LowerChartvalue: single;
begin
  result := laggedThreads;
end;

function TMinuteSummary.UnfinishedRequests: int64;
begin
  result := (startedRequests - (finishedRequests+finishedPriorRequests))+startedUnfinishedRequests+continuingRequests;
//    startedRequests: int64;
//    finishedRequests: int64;
//    startedUnfinishedRequests: int64;
//    finishedPriorRequests: int64;
//    continuingRequests: int64;//requests started before and finished after this minute


end;

initialization
  ics(datalock);

finalization
  dcs(datalock);

end.
