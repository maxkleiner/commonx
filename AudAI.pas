unit AudAI;

interface


uses
  ffmpeg_types,globalmultiqueue, simplequeue,  stringx, typex, numbers, sysutils, SoundTools, ffmpeg_tools, soundinterfaces, soundstream, commandprocessor, betterobject, dir, dirfile, generics.collections;

type
  TAudAnalCross = record
    total_windows_checked: int64;
    divergence: double;
    
    procedure init;
  end;
  TAudAnal = record
    channelguess: string;
    activity: double;
    crosscheck: array of TaudAnalCross;
    leastdivergent: integer;
    divergenceFromPair: double;
    procedure FindLeastDivergentChannel(myidx: integer; notin: array of integer);

    procedure Init;
  end;
  TAudAI = class(Tcommand)
  private
    streams: array of TSoundStream;
  public
    probe:TFFProbe;
    fileprefix: string;
    output_anal: array of TaudAnal;
    output_map: array of integer;
    output_names: array of string;
    function GetFFMpegChannelMap: string;
    procedure DoExecute;override;
    function DebugOutput: string;
  end;

function StartAudAI(probe: TFFProbe; fileprefix: string): IHolder<TAudAI>;

implementation

{ TAudAI }
function StartAudAI(probe: TFFProbe; fileprefix: string): IHolder<TAudAI>;
begin
  result := THolder<TAudAI>.create;
  result.o := TAudAI.Create;
  result.o.fileprefix := fileprefix;
  result.o.probe := probe;
  result.o.Start;
end;

function TAudAI.DebugOutput: string;
begin
  result := '';
  for var t := 0 to high(streams) do begin
    var act := output_anal[t].activity;
    result := result + 'Channel '+t.ToString+' activity: '+floatprecision(act, 2)+CRLF;
    for var u := 0 to high(streams) do begin
      var diver := output_anal[t].crosscheck[u].divergence;
      result := result + ' vs. '+inttostr(u)+' divergence: '+floatprecision(diver,8)+CRLF;
    end;
  end;
         
  result := result + CRLF+CRLF;
  for var t := 0 to high(streams) do begin
    result := result + 'Channel '+t.ToString+' is '+output_anal[t].channelguess+CRLF;
  end;

  result := result + 'ffmpeg channel map: '+GetFFMpegChannelMap;
end;

procedure TAudAI.DoExecute;
var
  qis : array of TQueueitem;
  peaks: array of NativeFloat;
  nin: array of integer;
begin
  inherited;

  
  setlength(streams, probe.AudioChannels);
  setlength(output_map, length(streams));
  setlength(output_anal, length(streams));
  setlength(peaks, length(streams));

  for var t := 0 to high(streams) do begin
    setlength(output_anal[t].crosscheck, length(streams));
  end;

  for var t := 0 to high(streams) do begin
    output_anal[t].init;
    for var u := 0 to high(streams) do begin
      output_anal[t].crosscheck[u].init;
    end;
  end;


  var dir := Tdirectory.CreateH(extractfilepath(fileprefix), extractfilename(fileprefix)+'*.wav', 0,0);
  if length(streams) <> dir.o.Filecount then
    raise Exception.create('expected to find '+length(streams).tostring+' files but found '+dir.o.filecount.tostring+' files named '+fileprefix);

  var totalsamples: int64 := 0;
  status := 'opening streams...';
  stepcount := dir.o.Filecount;

  var worked := false;
  repeat
    try
      for var idx := 0 to dir.o.filecount-1 do begin
       streams[idx] := TSoundStream.Create(dir.o.files[idx].FullName, fmOpenRead+fmShareDenyWrite);
      end;
      worked := true;
    except
      on E: exception do begin
        for var idx := 0 to dir.o.filecount-1 do begin
         streams[idx].Free;
         streams[idx] := nil;
        end;
        Log('waiting 10 seconds  '+e.message);
        sleep(10000);
      end;
    end;
  until worked;


  for var t := 0 to high(streams) do begin
    if t = 0 then
      totalsamples := streams[t].samplecount
    else
      totalsamples := lesserof(streams[t].samplecount, totalsamples);
  end;


  status := 'working...';

  totalsamples := lesserof(totalsamples, 44100*60*15);

  const SAMPLE_WINDOW : int64 = 4096;
  var startsample := 0;
  stepcount := totalsamples;
  setlength(qis, length(streams));
  while startsample < totalsamples do begin
    step := startsample;
    for var t:= 0 to high(streams) do begin
      qis[t] := InlineIteratorProcQI(t, procedure (idx: int64) begin

        var strm := streams[idx];
        peaks[idx] := strm.GetSamplePeak(startsample, startsample+SAMPLE_WINDOW, 1);

      end);
    end;
    for var t:= 0 to high(streams) do begin
      qis[t].waitfor;
      qis[t].free;
      qis[t] := nil;
    end;
    for var t:= 0 to high(streams) do begin
      var peak_source := peaks[t];
      output_anal[t].activity := output_anal[t].activity + peak_source;

      for var u := 0 to high(streams) do begin
        var peak_target := peaks[u];
        output_anal[t].crosscheck[u].divergence := output_anal[t].crosscheck[u].divergence + abs(peak_target-peak_source);
        inc(output_anal[t].crosscheck[u].total_windows_checked);
      end;
    end;
    inc(startsample, SAMPLE_WINDOW);
  end;

  setlength(nin, 2);
  //guess which channels are which
  //--channel 0 is always left
  output_anal[0].channelguess := 'L';
  output_map[0] := 0;
  nin[0] := 0;
  var best := 0.0;
  var bestIdx := 1;
  for var t:= 1 to high(streams) do begin
    //--right channel is whichever channel diverges the least from channel 0

    var divThis := output_anal[0].crosscheck[t].divergence;
    if (t = 1) or (divthis < best) then begin
      best := divThis;
      bestidx := t;
    end;
  end;
  output_anal[bestIdx].channelguess := 'R';
  nin[1] := bestIdx;
  output_map[1] := bestidx;


  if probe.AudioChannels > 4 then begin
    //SL and SR are the two most converged of the remaining channels
    bestidx := -1;
    best := 0.0;
    for var t := 0 to high(streams) do begin
      output_anal[t].FindLeastDivergentChannel(t, nin);
    end;                                   //v side channels will be after back channels in positions 6 and 7
    for var t := 0 to lesserof(high(streams),5) do begin
      for var u := 0 to high(nin) do begin //^ side channels will be after back channels in positions 6 and 7
        if nin[u] = t then
          continue;
      end;
      if output_anal[t].channelguess <> '' then continue;
      if (bestidx = -1)
      or (output_anal[t].divergenceFromPair < best) then begin
        best := output_anal[t].divergenceFromPair;
        bestidx := t;
      end;
    end;

    //make sure L is before R
    if bestidx > output_anal[bestidx].leastdivergent then
      bestidx := output_anal[bestidx].leastdivergent; 
    output_anal[bestidx].channelguess := 'BL';
    output_map[4] := bestidx;

    output_anal[output_anal[bestidx].leastdivergent].channelguess := 'BR';
    output_map[5] := output_anal[bestidx].leastdivergent;
    setlength(nin, length(nin)+2);
    nin[high(nin)-1] := bestidx;
    nin[high(nin)] := output_anal[bestidx].leastdivergent;
  end;

  //of the remaining channels the least active is LFE
  bestidx := -1;
  best := 0.0;  
  for var t := 0 to high(streams) do begin
    if output_anal[t].channelguess <> '' then continue;
    if (bestidx = -1)
    or (output_anal[t].activity < best) then begin
      best := output_anal[t].activity;
      bestidx := t;
    end;
  end;

  if probe.AudioChannels > 6 then begin
    //SL and SR are the two most converged of the remaining channels
    bestidx := -1;
    best := 0.0;
    for var t := 0 to high(streams) do begin
      output_anal[t].FindLeastDivergentChannel(t, nin);
    end;
    for var t := 0 to high(streams) do begin
      for var u := 0 to high(nin) do begin
        if nin[u] = t then
          continue;
      end;
      if output_anal[t].channelguess <> '' then continue;
      if (bestidx = -1)
      or (output_anal[t].divergenceFromPair < best) then begin
        best := output_anal[t].divergenceFromPair;
        bestidx := t;      
      end;
    end;

    //make sure L is before R
    if bestidx > output_anal[bestidx].leastdivergent then
      bestidx := output_anal[bestidx].leastdivergent; 
    output_anal[bestidx].channelguess := 'SL';
    output_map[6] := bestidx;

    output_anal[output_anal[bestidx].leastdivergent].channelguess := 'SR';
    output_map[7] := output_anal[bestidx].leastdivergent;
    setlength(nin, length(nin)+2);
    nin[high(nin)-1] := bestidx;
    nin[high(nin)] := output_anal[bestidx].leastdivergent;
  end;

  //of the remaining channels the least active is LFE
  bestidx := -1;
  best := 0.0;  
  for var t := 0 to high(streams) do begin
    if output_anal[t].channelguess <> '' then continue;
    if (bestidx = -1)
    or (output_anal[t].activity < best) then begin
      best := output_anal[t].activity;
      bestidx := t;
    end;
  end;

  if bestidx >=0 then begin
    output_anal[bestidx].channelguess := 'LFE';
    output_map[3] := bestidx;
  end;

  //of the remaining channels the MOST  active is CENTER
  bestidx := -1;
  best := 0.0;  
  for var t := 0 to high(streams) do begin
    if output_anal[t].channelguess <> '' then continue;
    if (bestidx = -1)
    or (output_anal[t].activity > best) then begin
      best := output_anal[t].activity;
      bestidx := t;
    end;
  end;

  if bestidx >=0 then begin
    output_anal[bestidx].channelguess := 'C';
    output_map[2] := bestidx;
  end;
    
    




end;

function TAudAI.GetFFMpegChannelMap: string;
begin
{$IFDEF ALT_FF}
  result := '';
  for var t := 0 to high(output_map) do begin
    result := result + ' -map 0.a.'+output_map[t].ToString;
  end;
{$ELSE}
  result := ' -af "channelmap=';
  for var t := 0 to high(output_map) do begin
    result := result + output_map[t].tostring;
    if t < high(output_map) then
      result := result + '|'
    else
      result := result + ':';

  end;
  

  case probe.AudioChannels of 
    3: result := result + '2.1" ';
    4: result := result + '3.1" ';
    6: result := result + '5.1" ';
    8: result := result + '7.1" ';
  else
    result := '';
  end;
  
{$ENDIF}
end;

{ TAudAnal }

procedure TAudAnal.init;
begin
  activity := 0.0;
end;

{ TAudAnalCross }

procedure TAudAnalCross.init;
begin

  total_windows_checked := 0;
  divergence := 0;

end;

procedure TAudAnal.FindLeastDivergentChannel(myidx: integer; notin: array of integer);
begin
  leastdivergent := -1;
  var best := 0.0;
  for var t:= 0 to High(crosscheck) do begin
    var bIgnore := false;   
    if t = myidx then
      continue;
    for var u := 0 to high(notin) do begin
      if notin[u] = t then bignore := true;
    end;
    if bignore then continue;

    var thisone := crosscheck[t].divergence;
    if (leastdivergent = -1) or (thisone < best) then begin
      best := thisone;
      leastdivergent := t;
    end;
  end;
  divergenceFromPair := best;
end;


end.
