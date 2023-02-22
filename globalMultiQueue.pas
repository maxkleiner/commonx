unit globalMultiQueue;

interface

uses
  System.SysUtils, System.Classes, orderlyinit, simplequeue, typex, systemx, numbers;

type
  TAnonymousIteratorQI = class(TQueueItem)
  protected
    procedure DoExecute;override;
  public
    additional_iterations: int64;
    iteration: int64;
    StopPtr: PByte;
    proc: TProc<int64>;
  end;

  TAnonymousIteratorQIV = class(TQueueItem)
  protected
    procedure DoExecute;override;
  public
    visor: int64;
    additional_iterations: int64;
    iteration: int64;
    proc: TProc<int64,int64,int64>;
  end;


  TAnonymousQI = class(TQueueItem)
  protected
    procedure DoExecute;override;
  public
    proc: TProc;
  end;


function InlineProcQI(proc: TProc): TAnonymousQI;
function InlineIteratorProcQI(idx: ni; proc: TProc<int64>): TAnonymousIteratorQI;
procedure ForX_QI(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions; stopP: PByte = nil; mq: TMultiQueue = nil);overload;
procedure ForX_QI(iStart, iEnd, iMinBatchSize, iMaxBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions; stopP: PByte = nil; mq: TMultiQueue = nil);overload;
procedure ForV_QI(visors, iStart, iEnd: int64; doproc: TProc<int64,int64,int64>; opts: TForXoptions);
procedure ForX_QI_NoWait(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions);
procedure GUISync(p: TProc);



var
  gmq: TMultiQueue = nil;

procedure QueueBehind(q: TAbstractSimpleQueue; qi: TQueueItem);


implementation

procedure GUISync(p: TProc);
begin
  TThread.Synchronize(nil,procedure begin
    p()
  end);
end;

procedure QueueBehind(q: TAbstractSimpleQueue; qi: TQueueItem);
begin
  var qii := TqiAddQueueItem.Create;
  qii.qi := qi;
  qii.q := q;
  qii.autodestroy := true;
  GMQ.additem(qii);
end;


procedure oinit;
begin
  gmq := TmultiQueue.create;

end;

function InlineIteratorProcQI(idx: ni; proc: TProc<int64>): TAnonymousIteratorQI;
begin
  result := TAnonymousIteratorQI.create;
  result.iteration := idx;
  result.proc := proc;
//  result.CPUExpense := 1.0;
  GMQ.AddItem(result);

end;

function InlineProcQI(proc: TProc): TAnonymousQI;
begin
  result := TAnonymousQI.create;
  result.proc := proc;
  GMQ.AddItem(result);
end;




procedure ofinal;
begin
  gmq.free;
  gmq := nil;
end;

{ TAnonymousIteratorCommand }

procedure TAnonymousIteratorQI.DoExecute;
begin
  inherited;
  if additional_iterations =0 then
    proc(iteration)
  else
  //use a tighter loop if not StopPtr (optimizing as much as possible
  if stopptr = nil then
  for var t := iteration to iteration+additional_iterations do begin
    proc(t);
    if StopPtr <> nil then
      if stopPtr^<>0 then exit;
  end else
  //slightly less optimal loop supports checking the stopPtr
  for var t := iteration to iteration+additional_iterations do begin
    proc(t);
    if StopPtr <> nil then
      if stopPtr^<>0 then exit;
  end;
end;

{ TAnonymousQI }

procedure TAnonymousQI.DoExecute;
begin
  inherited;
  proc();
end;


procedure ForX_QI(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions; stopP: PByte = nil; mq: TMultiQueue = nil);
begin
  ForX_QI(iStart, iend, iMinBatchSize, 0, doProc, opts, stopp, mq);
end;

procedure ForX_QI(iStart, iEnd, iMinBatchSize, iMaxBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions; stopP: PByte = nil; mq: TMultiQueue = nil);
var
  a: array of TAnonymousIteratorQI;
begin
  if iMaxBatchSize = 0 then
    iMaxBatchSize := SIMPLE_BATCH_SIZE;

  if mq = nil then
    mq := GMQ;
  try
    var cpus := GetEnabledCPUCount;
    var t := iStart;
    var firstqi: TAnonymousIteratorQI := nil;
    var prevqi:TAnonymousIteratorQI := nil;
    var totalsz := (iEnd-iStart);
    if fxEndinclusive in opts then
      inc(totalsz);

    var batches := (cpus);
    if (totalsz div batches) < (iminBatchSize) then
      batches := greaterof(1,totalsz div iMinBatchSize);

    var batchsz := totalsz div batches;
    if totalsz mod batches > 0 then
      batchsz := batchsz + 1;

    setlength(a, (totalsz div greaterof(1,lesserof(batchsz,imaxbatchsize)))+1);
    if (iEnd >= iStart) then begin

      var aidx:nativeint := 0;
      var cx := totalsz;
      while cx > 0 do begin
        var thissz := lesserof(cx, batchsz);
        if aidx = high(a) then
          thissz := cx;//double check ... if this is the high index... always use all... there's a calc error in here somewhere
        if thissz > iMaxBatchSize then
          thissz := iMaxBatchSize;
        var c := TAnonymousIteratorQI.Create;
        c.iteration := t;
        c.additional_iterations := thissz-1;
        c.proc := doProc;
        a[aidx] := c;
        inc(aidx);
        c.AutoDestroy := false;
        c.StopPtr := stopp;
        mq.AddItem(c);
        dec(cx, thissz);
        inc(t, thissz);
        if firstqi = nil then
            firstqi := c;

        if prevqi <> nil then
          prevqi.next := c;

        prevqi := c;


      end;
    end else begin
      exit;
//      raise ECritical.create('not implemented when end < start');
    end;


    for var tt := 0 to high(a) do begin
      if a[tt] <> nil then begin
        a[tt].WAitFor;
        a[tt].Free;
        a[tt] := nil;
      end;
    end;



  finally

  end;
end;

procedure ForX_QI_NoWait(iStart, iEnd, iMinBatchSize: int64; doproc: TProc<int64>; opts: TForXoptions);
begin
  try
    var cpus := GetEnabledCPUCount;
    var t := iStart;
    if (iEnd >= iStart) then begin
      var totalsz := iEnd-iStart;
      if fxEndInclusive in opts then
        inc(totalsz);

      var cx := totalsz;
      while cx > 0 do begin
        var thissz := lesserof(cx, greaterof(iMinBatchSize, (totalsz div cpus)));
        var c := TAnonymousIteratorQI.Create;
        c.iteration := t;
        c.additional_iterations := thissz-1;
        c.proc := doProc;
        GMQ.AddItem(c);
        dec(cx, thissz);
        inc(t, thissz);


      end;
    end else begin
      raise ECritical.create('not implemented when end < start');
    end;

  finally

  end;
end;

procedure ForV_QI(visors, iStart, iEnd: int64; doproc: TProc<int64,int64,int64>; opts: TForXoptions);
var
  a: array of TAnonymousIteratorQIV;
begin

  try
    var v := 0;
    var cpus := GetEnabledCPUCount;
    var t := iStart;
    var firstqi: TAnonymousIteratorQIV := nil;
    var prevqi:TAnonymousIteratorQIV := nil;
    var totalsz := (iEnd-iStart);
    if fxEndInclusive in opts then
      inc(totalsz);

    var batchsz := totalsz div visors;
    if totalsz mod visors > 0 then
      batchsz := batchsz + 1;

    setlength(a, totalsz);
    if (iEnd >= iStart) then begin

      var aidx:nativeint := 0;
      var cx := totalsz;
      while cx > 0 do begin
        var thissz := lesserof(cx, batchsz);
        var c := TAnonymousIteratorQIV.Create;
        c.visor := v; inc(v);
        c.iteration := t;
        c.additional_iterations := thissz-1;
        c.proc := doProc;
        a[aidx] := c;
        inc(aidx);
        GMQ.AddItem(c);
        dec(cx, thissz);
        inc(t, thissz);
        if firstqi = nil then
            firstqi := c;

        if prevqi <> nil then
          prevqi.next := c;

        prevqi := c;


      end;
    end else begin
      raise ECritical.create('not implemented when end < start');
    end;


    for var tt := 0 to high(a) do begin
      if a[tt] <> nil then begin
        a[tt].WAitFor;
        a[tt].Free;
        a[tt] := nil;
      end;
    end;



  finally

  end;
end;

{ TAnonymousIteratorQIV }

procedure TAnonymousIteratorQIV.DoExecute;
begin
  inherited;
  proc(visor,iteration,1+additional_iterations);

end;

initialization

gmq := nil;
init.RegisterProcs('globalMultiQueue', oinit, ofinal,'managedthread');

finalization





end.
