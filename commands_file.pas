unit commands_file;


interface


uses
{$IFDEF MSWINDOWS}
    {$DEFINE USE_COPY_FILE_EX}
  windows, exe,
{$ENDIF}
  unicodeart, sysutils, types, betterobject, dirfile, commandprocessor, typex,classes, systemx, tickcount, commandicons, ioutils, debug, numbers, orderlyinit, stringx, dir, managedthread;



{$IFDEF ALLOW_COMPRESSION}
const
  MAX_COMPRESS_SIZE = 100000000;
{$ENDIF}

type
  TfileOp = (foCopy, foMove);
  TMultiMode = (mmToBest, mmToAll);

  TFileCopyCommand = class(TCommand)
  private
    FSource: string;
    FDest: string;
    FSize: int64;
    FLatency: cardinal;
    FFileOp: TfileOp;
    FCompress: boolean;
    FLAstTime: cardinal;
    FStartTime: cardinal;
    FLastTransfer: nativefloat;
    FStatFrom: TResourceHealthData;
    FStatTo: TResourceHealthData;
    FWakingUp: boolean;
    FNoAutoExpense: boolean;
    FThrottleRate: int64;
    procedure RecalculateExpense;
    procedure SetDest(const Value: string);
    procedure SetSource(const Value: string);
    procedure SetSize(const Value: int64);
    procedure SetLatency(const Value: cardinal);
    procedure AssignStats;
    procedure ChooseFinalDestination;
    procedure SetFileOp(const Value: TfileOp);
  public
    constructor Create;override;
    property noAutoExpense: boolean read FNoAutoExpense write FNoAutoExpense;

    property ThrottleRate: int64 read FThrottleRate write FthrottleRate;

    property WakingUp: boolean read FWakingUp write FWakingUp;
    property Source: string read FSource write SetSource;
    property Destination: string read FDest write SetDest;
    property Size: int64 read FSize write SetSize;
    property Latency: cardinal read FLatency write SetLatency;
    property Compress: boolean read FCompress write FCompress;
    procedure DoExecute;override;
    property FileOp: TfileOp read FFileOp write SetFileOp;
    class function BeginCopyFile(sSource, sTarget: string): TfilecopyCommand;
    procedure UpdateProgress(TotalTransferred, TotalSize: int64);

  end;

  TfileMoveCommand = class(TFileCopycommand)
  public
    constructor Create;override;
    class function BeginMoveFile(sSource, sTarget: string): TfileMoveCommand;
    class function CreateMoveFile(sSource, sTarget: string): TfileMoveCommand;


  end;

  TFileDeleteCommand = class(TCommand)
  private
    FFile: string;
  public
    procedure InitExpense;override;
    procedure DoExecute;override;
    property FileToDelete: string read FFile write FFile;
  end;

  TDrainFolderThread = class(TManagedThread)
  private
    sources: IHolder<TStringList>;
  public
    dst: string;
    idx: ni;
    filespec: string;
    recurse: boolean;
    submount: boolean;
    ThrottleRate: int64;
    cleanDstFileSpec: string;
    cleanDstOlderThan: TDateTime;
    procDebug: TProc<string>;
    function ShouldPause: boolean;virtual;
    procedure AddSource(s: string);
    procedure DoExecute;override;
    procedure InitFromPool; override;

  end;



function CopyProgressRoutine(
    TotalFileSize, TotalBytesTransferred, StreamSize,StreamBytesTransferred: int64;
    dwStreamNumber: cardinal;
    dwCallbackReason: cardinal;
    hSourcefile, hDestinationFile: Thandle;
    lpData: pointer): DWORD;stdcall;


function UniquefileName(sFileName: string): string;
{$IFDEF MSWINDOWS}
procedure forcePermissions(sFileSpec: string; u: string= 'everyone'; p: string ='F');
function forcePermissions_begin(sFileSpec: string; u: string= 'everyone'; p: string ='F'): Tcmd_RunExe;
procedure forcePermissions_end(c: Tcmd_RunExe);
{$ENDIF}





var
  fileCommands: TCommandProcessor = nil;

implementation



function UniquefileName(sFileName: string): string;
var
  sSuffix: string;
  t: ni;
begin
  t := 0;
  result := sFileName;
  while FileExists(result) do begin
    inc(t);
    result := slash(extractfilepath(sFileName))+extractfilenamepart(sFileName)+inttostr(t)+extractfileext(sFilename);
  end;
end;

procedure TFileCopyCommand.AssignStats;
begin
      if assigned(self.Processor) then begin
        FStatFrom := Self.Processor.ResourceStats.GetStatForResource(ExtractNetworkRoot(Source));
        FStatTo := Self.Processor.ResourceStats.GetStatForResource(ExtractNetworkRoot(Destination));
      end;
end;

class function TFilecopycommand.BeginCopyFile(sSource,
  sTarget: string): TfilecopyCommand;
begin
  result := TfileCopycommand.create;
  result.Source := sSource;
  result.Destination := sTarget;
  result.start;



end;

class function TFileMovecommand.BeginMoveFile(sSource,
  sTarget: string): TfileMoveCommand;
begin
  result := CreateMoveFile(sSource,sTarget);
  result.start;


end;

procedure TFileCopyCommand.ChooseFinalDestination;
var
  sl: TStringlist;
  t: integer;
  r, rMin: nativefloat;
begin
  rMin := 9999999;
  sl := TStringlist.create;
  try
    sl.text := FDest;
    for t:= 0 to sl.count-1 do begin
      r := self.Processor.GetCurrentScheduledCustomResourceExpense(ExtractNetworkRoot(sl[t]));
      if r< rMin then begin
        rMin := r;
        FDest := sl[t];
      end;
    end;

  finally
    sl.free;
  end;

end;

constructor TFilecopycommand.Create;
begin
  inherited;
  CPUExpense := 0;
  FLatency := 0;
  FLAstTime := GetTicker;
  Icon := @CMD_ICON_FILE_COPY;

//  DiskExpenseByString[GetDrive(Source)] := 1;
//  DiskExpenseByString[GetDrive(Destination)] := 1;
//  NetworkExpense := 1;
end;

procedure TFilecopycommand.DoExecute;
var
  i: longbool;
  sExt: string;
  sPath: string;
begin
  inherited;
  try

    if Processor = nil then
      raise Exception.create('No processor set');

    if (zpos(#13, FDest) > -1) or (zpos(#10, FDest) > -1) then
      ChooseFinalDestination;

    self.Status := FSource+'->'+FDest;


    sPath := extractFilePath(FDest);
    if sPath <> '' then
      ForceDirectories(spath);


{$IFNDEF WINDOWS}
  {$Message Hint 'FileCopycommand on IOS/Andriod does not set Attributes'}
{$ELSE}
    if fileExists(FDest) then begin
      FileSetAttr(PChar(FDest), (FileGetAttr(PChar(FDest)) and not faReadOnly));
    end;
{$ENDIF}


    if FileOP = foCopy then begin
      Debug.Log(self,'Start copy of '+FSource, 'filecopy');

      {$IFDEF IOS}
        {$Message Hint 'FileCopycommand on IOS does not set Attributes'}
      {$ELSE}

        {$IFDEF ALLOW_COMPRESSION}
        if (TFileAttribute.faCompressed in TFile.GetAttributes(FSource)) then begin
          Resources.SetResourceUsage(ExtractNetworkRoot(FSource),1.0);
//        FStatFrom := Self.Processor.ResourceStats.GetStatForResource(ExtractNetworkRoot(FSource));


        //DiskExpenseByString[GEtDrive(FSource)] := 1.0;
          WaitForResources;
        end;
        {$ENDIF}
      {$ENDIF}
      FStartTime := GetTicker;
{$IFDEF USE_COPY_FILE_EX}
      i := CopyFileEx(PChar(Fsource), PChar(FDest), @CopyProgressRoutine, pointer(self), nil, 0);
{$ELSE}
      i := true;
      try
        TFile.Copy(Fsource,FDest, true);
      except
        i := false;
      end;
{$ENDIF}
      if (i) then
        Debug.Log(self,'Copy Finished '+FSource, 'filecopy')
      else begin
        Debug.Log(self,'Copy FAILED! '+FSource+'->'+FDest, 'error');
        self.CResult := false;
      end;
    end else begin
      Debug.Log(self,'Start move of '+FSource+' to '+FDest, 'filecopy');
      {$IFDEF ALLOW_COMPRESSION}
      if Compress and (TfileAttribute.faCompressed in TFile.GetAttributes(FSource)) then begin
        Resources.SetResourceUsage(ExtractNetworkRoot(FSource),1.0);
//        FStatFrom := Self.Processor.ResourceStats.GetStatForResource(ExtractNetworkRoot(FSource));
//        DiskExpenseByString[GEtDrive(FSource)] := 1.0;
        WaitForResources;
      end;
      {$ENDIF}
      FStartTime := GetTicker;
{$IFDEF USE_COPY_FILE_EX}
      i := MoveFileWithProgress(PChar(Fsource), PChar(FDest), @CopyProgressRoutine, pointer(self),MOVEFILE_COPY_ALLOWED+MOVEFILE_REPLACE_EXISTING);
{$ELSE}
      i := true;
      try
        TFile.Move(Fsource, FDest);
      except
        i := false;
      end;
{$ENDIF}
      if (i) then begin
        Debug.Log(self,'move Finished '+FSource, 'filecopy')
      end
      else
      begin
        Debug.Log(self,'move FAILED! '+FSource, 'filecopy');
        Self.CResult := false;
      end;
    end;

  //  if fileExists(FDest) then begin
  //    FileSetAttr(PChar(FDest), FILE_ATTRIBUTE_COMPRESSED or (FileGetAttr(PChar(FDest)) and not faReadOnly));
  //  end;


{$IFDEF ALLOW_COMPRESSION}
    if false and Compress then begin
      try

        Source := '';//recalculates expense while compressing on target
        sExt := lowercase(extractfileext(FDest));

        if (sExt <> '.jpg')
        and (sExt <> '.tar')
        and (sExt <> '.mov')
        and  (sExt <> '.zip')
        and  (sExt <> '.mpg')
        and  (sExt <> '.mp4')
        and  (sExt <> '.mp3')
        and  (sExt <> '.ogg')
        and  (sExt <> '.gif')
        and  (sExt <> '.rar')
        and  (sExt <> '.cab')
        and  (sExt <> '.wma')
        and  (pos(')', FDest)=0)
        and (Size > 0)
        and (Size < MAX_COMPRESS_SIZE)
        then begin
          RunProgramAndWait('compact', '/C "'+FDest+'"', '', true, true);
        end;
      except
      end;
    end;
{$ENDIF}
  except
  end;

  //CopyFile(Pchar(Fsource), Pchar(FDest), false);
end;


procedure TFilecopycommand.RecalculateExpense;
var
  r: real;
  r2: real;
begin
  if NoAutoExpense then
    exit;

  Lock;
  REsources.Lock;
  try
    Resources.Clear;

  //  if Source = '' then Source := ' ';
  //  if Destination = '' then exit;


    if Latency > 200 then
      FLatency := 200;

    r := (200-FLatency)/200;

    MemoryExpense := 1/64;
//    Debug.Log('Calc Expense for: '+source+'->'+destination);
//    Debug.Log('Latency: '+floattostr(Latency),'filecopy');
//    Debug.Log('Latency factor: '+floattostr(r),'filecopy');


    if r < (1/8) then
      r := (1/8);

    if FileOp = foMove then begin
      if lowercase(ExtractNetworkRoot(source)) = lowercase(ExtractNetworkRoot(destination)) then begin
        r := 0.0;
      end;
    end else begin

    end;


    try
      try

        r2 := Size;
//        if r2 < 32768 then r2 := 32768;

        if r2 > 0 then begin
          r2 := r2 / 2000000;
          if r2 > 1 then r2 := 1;

          if r = 0 then
            r := 0.0
          else
            r := r2*r;
          if r < 0 then r := 0;
        end else
          r := 0.0;


//        if (r < 1) and (r>0) then begin
//          r := r * r;
//        end;

      finally
      end;

//      r := r * 4000;
      const MIN_EXPENSE = 1/64;
      const MAX_EXPENSE = 63/64;
      if r > MAX_EXPENSE then r := MAX_EXPENSE;
      if r < (MIN_EXPENSE) then r := (MIN_EXPENSE);
//
//      Debug.Log('Source: '+GetDrive(Source),'filecopy');
//      Debug.Log('Destination: '+GetDrive(Destination),'filecopy');


      Resources.SetResourceUsage(ExtractNetworkroot(Source), Resources.GetResourceUsage(ExtractNetworkroot(Source)).Usage+(r));
      Resources.SetResourceUsage(ExtractNetworkroot(Destination), Resources.GetResourceUsage(ExtractNetworkroot(Destination)).Usage+(r));

      AssignStats;


//      Debug.Log('End Expense: '+floattostr(r),'filecopy');

    except

    end;
  finally
    Resources.Unlock;
    Unlock;
  end;


end;

procedure TFilecopycommand.SetDest(const Value: string);
begin
  FDest := Value;
  UniqueString(FDest);
  RecalculateExpense;
end;

procedure TFileCopyCommand.SetFileOp(const Value: TfileOp);
begin
  FFileOp := Value;
  if value = foMove then
    Icon := @CMD_ICON_FILE_MOVe
  else
    Icon := @CMD_ICON_FILE_COPY;

end;

procedure TFilecopycommand.SetLatency(const Value: cardinal);
begin
  FLatency := Value;
  RecalculateExpense;
end;

procedure TFilecopycommand.SetSize(const Value: int64);
begin
  FSize := Value;
  RecalculateExpense;
end;

procedure TFilecopycommand.SetSource(const Value: string);
begin
  FSource := value;
  UniqueString(FSource);
  Size := dirfile.GEtfileSize(value);
  RecalculateExpense;
end;

procedure TFileCopyCommand.UpdateProgress(TotalTransferred, TotalSize: int64);
var
  tm: Cardinal;
  tmDelta, tmTotal, TransferDelta: nativefloat;
  r1,r2: nativefloat;
begin
  if (TotalSize div 1000000) < 100 then begin
    StepCount := TotalSize div 10000;
    Step := TotalTransferred div 10000;
  end else begin
    StepCount := TotalSize div 1000000;
    Step := TotalTransferred div 1000000;
  end;

  tm := GetTicker;
  tmDelta := GetTimeSince(tm, FLastTime) / 1000;
  tmTotal := GetTimeSince(tm, FStartTime) / 1000;
  TransferDelta := TotalTransferred- FLastTransfer;
  FLastTransfer := TotalTransferred;
  FLastTime := tm;

  if ThrottleRate > 0 then begin
    if TotalTransferred > 0 then begin
      var since := gettimesince(FStartTime) /1000;
      if since > 0 then begin
        var actualrate := TotalTransferred / since;
        if actualrate > ThrottleRate then begin
          var targettime: int64 := round(since * ThrottleRate);
          var intofuture := gettimesince(targettime,getticker());
          if intofuture < 0 then
            intofuture := 0;
          sleep(lesserof(4000, intofuture));
        end;
      end;
    end;
  end;


  if tmDelta = 0 then exit;
  if self.WakingUp then begin
    self.WakingUp := false;
    exit;
  end;

  AssignStats;


  if TransferDelta > 0 then begin
    if assigned(FStatTo) then begin
      FStatTo.ApplyStat(tmTotal, TotalTransferred);
//      if TotalSize > LARGE_FILE_THRESHOLD then begin
//        self.Resources.SetResourceUsage(FStatTo.Resource,(TransferDelta/tmDelta) / FStatTo.MaxLarge);
//      end else begin
//        self.Resources.SetResourceUsage(FStatTo.Resource,(TransferDelta/tmDelta) / FStatTo.MaxSmall);
//      end;
    end;

    if assigned(FStatFrom) then begin
      FStatFrom.ApplyStat(tmTotal, TotalTransferred);
//      if TotalSize > LARGE_FILE_THRESHOLD then begin
//        self.Resources.SetResourceUsage(FStatFrom.Resource,(TransferDelta/tmDelta) / FStatFrom.MaxLarge);
//      end else begin
//        self.Resources.SetResourceUsage(FStatFrom.Resource,(TransferDelta/tmDelta) / FStatFrom.MaxSmall);
//      end;
    end;

    if assigned(FStatFrom) and assigned(FStatTo) then begin
      if TotalSize > LARGE_FILE_THRESHOLD then begin
        FSTatTo.MaxLarge  := greaterof(FStatTo.MaxLarge, 1);
        FSTatFrom.MaxLarge  := greaterof(FStatTo.MaxLarge, 1);
        r1 := (TransferDelta/tmDelta) / FStatTo.MaxLarge;
        r2 := (TransferDelta/tmDelta) / FStatFrom.MaxLarge;
      end
      else begin
        FSTatTo.MaxSmall  := greaterof(FStatTo.MaxSmall, 1);
        FSTatFrom.MaxSmall  := greaterof(FStatTo.MaxSmall, 1);
        r1 := (TransferDelta/tmDelta) / FStatTo.MAxSmall;
        r2 := (TransferDelta/tmDelta) / FStatFrom.MAxSmall;
      end;

      //ONE OF THE TWO must be above 50% usage or they will both be considered
      //maxed out
      if (self is TfileMoveCommand) and (comparetext(ExtractNetworkRoot(self.Source), ExtractNetworkRoot(self.Destination))=0) then begin
        self.Resources.SetResourceUsage(FStatFrom.Resource,lesserof(r2*5,0.05));
        self.Resources.SetResourceUsage(FStatTo.Resource,lesserof(r1*5,0.05));
      end else
      if (r1 > 0.4) or (r2 > 0.4) then begin
        self.Resources.SetResourceUsage(FStatFrom.Resource,lesserof(r2*1.5,1.0));
        self.Resources.SetResourceUsage(FStatTo.Resource,lesserof(r1*1.5,1.0));
      end else begin
          if (r1 < 0.1) and (r2 < 0.1) then begin
            self.Resources.SetResourceUsage(FStatFrom.Resource,lesserof(r2*5,1.0));
            self.Resources.SetResourceUsage(FStatTo.Resource,lesserof(r1*5,1.0));
//            self.WaitForResources(30000);
//            self.WakingUp := true;
          end;
          //FLAstTime := GetTicker;
      end;



    end;

  end;
end;


{ TfileMoveCommand }

constructor TfileMoveCommand.Create;
begin
  inherited;
  FileOp := foMove;
end;





class function TfileMoveCommand.CreateMoveFile(sSource,
  sTarget: string): TfileMoveCommand;
begin
  result := TfileMovecommand.create;
  result.Source := sSource;
  result.Destination := sTarget;
  result.FileOp := fomove;

end;

{ TFileCopyLookupTable }


function CopyProgressRoutine(
    TotalFileSize, TotalBytesTransferred, StreamSize,StreamBytesTransferred: int64;
    dwStreamNumber: cardinal;
    dwCallbackReason: cardinal;
    hSourcefile, hDestinationFile: Thandle;
    lpData: pointer): DWORD;stdcall;
var
  fc: TFileCopyCommand;
begin
  fc := TFileCopycommand(lpData);
  fc.UpdateProgress(TotalBytesTransferred, TotalFileSize);
  result := 0;

end;


procedure oinit;
begin
  filecommands := TCommandProcessor.create(nil,'File Commands');
end;

procedure ofinal;
begin
  if assigned(filecommands) then begin
    filecommands.free;
    filecommands := nil;
  end;

end;


{ TFileDeleteCommand }

procedure TFileDeleteCommand.DoExecute;
begin
  inherited;
  if FileExists(FileToDelete) then
    DeleteFile(FileToDelete);

end;

procedure TFileDeleteCommand.InitExpense;
begin
  inherited;
  CPUExpense := 0.0;
end;


function MoveFolderUntilEmpty(sSource,sDest: string; sFileSpec: string; iLimit: nativeint; ThrottleRate: int64; bRecurse: boolean; bKeepSourceFolder: boolean = true; c: TCommand = nil; p: PProgress = nil; dbg: TProc<string> = nil): nativeint;
begin
  result := 0;
  if brecurse and (sfilespec<>'*') then
    raise ECritical.create('cannot use recurse with filespec other than *');
    //^ this is because removing the sub-folders will end up deleting files outside the filespec

  var fi: TFileInformation := nil;
  var dirh: IHolder<TDirectory> := nil;
  repeat
    dirh := Tdirectory.CreateH(sSource, sfilespec, 0,0, false, false, false);

    if brecurse then
    while dirh.o.GetNextFolder(fi) do begin
      try
        inc(result, MoveFolderUntilEmpty(fi.FullName, slash(sDest)+fi.Name, sFilespec, iLimit-result, ThrottleRate, bRecurse, false, c, p));
        if (iLimit > 0) and (result >= iLimit) then
          exit;
      except
        on E:exception do begin
          debug.log('error moving folder '+sSource+' to '+sDest+' -- '+e.message);
          sleep(4000);
          exit;
        end;
      end;
    end;

    while dirh.o.GetNextFile(fi) do begin
      var s := fi.fullname;
      var d := slash(sDest)+fi.name;
      var cc := TfileMoveCommand.CreateMoveFile(s, d);
      try
        cc.RaiseExceptions := false;
        cc.NoAutoExpense := true;
        cc.Resources.SetResourceUsage(d, 1.0);
        cc.MemoryExpense := 0;
        cc.CPUExpense := 0;
//        cc.NetworkExpense := 1.0;
        cc.ThrottleRate := ThrottleRate;

        cc.start;

        while not cc.WaitFor(250) do begin
          if p <> nil then begin
            p^ := cc.volatile_progress;
          end;
          if assigned(dbg) then begin
            dbg(RenderProgressText(cc.volatile_progress)+cc.Destination);
          end;
        end;

        if cc.ErrorMessage <> '' then begin
          debug.log('error moving file '+s+' to '+d+' -- '+cc.errormessage);
          exit;
        end;

        inc(result,1);
        if (iLimit > 0) and (result >= iLimit) then
          exit;


      finally
        cc.free;
      end;
    end;

    if not bKeepSourceFolder then
    if (dirh.o.filecount = 0) and (dirh.o.Foldercount = 0) then  begin
      try
        RemoveDir(sSource);
      except
        on e: exception do begin
          debug.log('error removing dir '+sSource+' -- '+e.message);
          exit;
        end;

      end;
    end;

  until (dirh = nil) or (dirh.o=nil) or ((dirh.o.filecount=0) and (dirh.o.foldercount=0));



end;



{ TDrainFolderThread }

procedure TDrainFolderThread.AddSource(s: string);
begin
  var ilock :=LockI;
  for var t:= 0 to sources.o.count-1 do begin
    if (comparetext(sources.o[t],s)=0) then
      exit;
  end;

  sources.o.Add(s);

end;

procedure TDrainFolderThread.DoExecute;
begin
  inherited;
  try
    runhot := false;
    try
    var src := '';
    //briefly lock just we can get a source folder
    begin
      var lck := Locki;

      if sources.o.count=0 then
        exit;

      if idx >= sources.o.count then
        idx := 0;

      src := sources.o[idx];
    end;

    var deleted:  ni := 0;
    var cnt := 0;
    for var t := 0 to sources.o.count-1 do begin
      try
       inc(cnt, GetFileCount(sources.o[t], '*.plot'));
      except
      end;
    end;


    if cnt > 0 then begin
      if cleanDstFileSpec <> '' then begin
        DeletefileSpecEx(dst, '*.plot',cleanDstOlderThan, deleted, 1);
      end;
    end;


    var bestdest := dst;
    var mnt := GetBestMount(dst,procedure (s: string) begin

      Debug.Log(s);
    end);
    if mnt <> nil then
      bestDest := mnt.o.path;
      if ShouldPause then begin
        runhot := false;
        exit;
      end;


    MoveFolderUntilEmpty(src, bestDest, filespec, 1, ThrottleRate, recurse, true, nil, nil, procDebug);
    except
      on e: exception do begin
        Debug.Log('Error in '+Classname+': '+e.message);
      end;
    end;
  finally
    inc(idx);
  end;
end;

procedure TDrainFolderThread.InitFromPool;
begin
  inherited;
  Loop := true;
  ColdRunInterval := 10000;
  RunHot := false;
  filespec := '*';
  recurse := true;
  sources := stringToStringListH('');
  dst := '';
end;

function TDrainFolderThread.ShouldPause: boolean;
begin
  result := false;
end;

{$IFDEF MSWINDOWS}
procedure forcePermissions(sFileSpec: string; u: string= 'everyone'; p: string ='F');
begin
  forcePermissions_end(forcePermissions_begin(sFileSpec, u,p));
end;
function forcePermissions_begin(sFileSpec: string; u: string= 'everyone'; p: string ='F'): Tcmd_RunExe;
begin
  result := nil;
    result := Tcmd_RunExe.create();
    result.Prog := 'cacls';
    result.Params := quote(sFileSpec)+' /e /p '+u+':'+p;
    result.CaptureConsoleoutput := true;
    result.WorkingDir := extractfilepath(result.prog);
    result.RaiseExceptions := false;
    result.Start;
end;
procedure forcePermissions_end(c: Tcmd_RunExe);
begin
  c.WaitFor;
  c.Free;
end;
{$ENDIF}


initialization
  orderlyinit.init.RegisterProcs('commands_file', oinit, ofinal, 'Debug,ManagedThread,CommandProcessor');

finalization


end.
