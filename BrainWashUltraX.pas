unit BrainWashUltraX;
{$D+}
//TODO 1: Update Batch build to set directive BIGBRAINDLL when building DLL.

interface

uses
  Classes, ManagedThread, OrderlyInit;


type
  TMemCleaner = class(TManagedThread)
  private
    FDone: boolean;
  public
    class function NewInstance: TObject;override;
    procedure FreeInstance;override;
    procedure DoExecute; override;
    property Done: boolean read FDone;

  end;

procedure StartMemoryCleaner;
procedure StopMemoryCleaner;

procedure ReferenceMemoryCleaner; export;
procedure DereferenceMemoryCleaner;export;

var
  refs: integer;
  cleaner: TMemCleaner;


implementation


uses BigBrainUltra;

{ TMemCleaner }

procedure TMemCleaner.DoExecute;
var
  t: integer;
  u: integer;
  v: integer;
  w: integer;
  x: integer;
  s: integer;
  man: TBlockManager;
  iTotal: integer;
  iFreed: integer;
  mancount: integer;
  worked: nativeint;
begin
  inherited;
  Status := 'Operational';
  iFreed := 0;
  iTotal := 0;
  u := 0;
  v := 0;
  w:= 0;
  x := 0;
  mancount := 0;

  while not terminated do begin
    inc(u);
    inc(v);
    inc(w);
    inc(x);
    worked := 0;

    if (u mod 30) = 0 then
      mancount := manman.ManagerCount;

    if mancount > 50 then
      mancount := 50;

    if (u >= (45-mancount)) then begin

      if ManMan.TryLock then
      try
        inc(worked, ManMan.Clean);
        u:=0;
      finally
        ManMan.Unlock;
      end;
    end;
    if w = 200 then begin
      w := 0;
      iTotal := ManMan.TotalBytes;
    end;

    if v = 1 then begin
      v:=0;
//      {$IFNDEF NOSTATS}if MainMan.Freebytes > (iTotal shr 2) then begin{$ENDIF}
      {$IFNDEF PEAK_MEMORY}
        inc(worked, MainMan.Clean);
      {$ENDIF}
//      {$IFNDEF NOSTATS}end;{$ENDIF}
    end;



    if ManMan.TryLock then
    try
        iFreed := 0;
        for t := 1 to ManMan.Managercount-1 do begin
          man := ManMan.Managers[t];
          if Man.TryLock then
          try
            inc(worked,Man.Clean);
            inc(iFreed);
          finally
            Man.Unlock;
          end;
        end
    finally
      ManMan.Unlock;
    end;

{$IFDEF CLEAN_PAGES}
    if x=25 then begin
      x := 0;
      if ManMan.TryLock then
      try
          for t := 1 to ManMan.Managercount-1 do begin
            man := ManMan.Managers[t];
            if Man.TryLock then
            try
              //Man.CleanPages;
            finally
              Man.Unlock;

            end;
          end
      finally
        ManMan.Unlock;
      end;
    end;
{$ENDIF}

    if worked > 0 then begin
//  {$IFDEF OLD_SLEEPS}
      if random(iFreed) > 3 then
        sleep(1)
      else
        if random(10) > 4 then
          sleep(1);
//  {$ENDIF}
    end else begin
      for s := 1 to 20 do begin
        endActiveTime;
        sleep(200);
        BeginActivetime;
        if Terminated then break;
      end;
    end;





  end;

  FDone := true;

end;

procedure StartMemoryCleaner;
begin
  cleaner := TPM.Needthread<TMemCleaner>(nil);// TMemCleaner.create(false);
  cleaner.Start;
end;

procedure StopMemoryCleaner;
begin
  cleaner.Stop;
  cleaner.WaitForFinish;
  TPM.NoNeedthread(cleaner);
  cleaner := nil;
//  cleaner.terminate;
//  while not cleaner.Done do begin
//    {$IFDEF MACOS}
//    {$ELSE}
//    sleep(100);
//    {$ENDIF}
//  end;
//
//  cleaner.free;

end;





procedure TMemCleaner.FreeInstance;
begin
  OldMan.FreeMem(self);
end;

class function TMemCleaner.NewInstance: TObject;
begin
  result := InitInstance(OldMan.GetMem(InstanceSize));
end;

procedure ReferenceMemoryCleaner; export;
begin
  //this function should really only be called in the initialization section, so it should be okay wiuthout locks
  interlockedincrement(refs);
  if refs = 1 then
    STartMemoryCleaner;

end;
procedure DereferenceMemoryCleaner;export;
begin
  //this function should really only be called in the FINALIZATION section, so it should be okay wiuthout locks
  interlockeddecrement(refs);
  if refs = 0 then
    StopMemoryCleaner;

end;



initialization
  {$IFNDEF NOCLEAN}
  {$IFNDEF BIGBRAINDLL}
{$IFNDEF DISABLE_BIG_BRAIN}
  init.RegisterProcs('BrainWashUltraX', procedure begin
    StartMemoryCleaner;
  end, procedure begin
    StopMemoryCleaner;
  end, 'ManagedThread');
{$ENDIF}
  {$ENDIF}
  {$ENDIF}

finalization
  //cleaner.Suspend;
  {$IFNDEF NOCLEAN}
  {$IFNDEF BIGBRAINDLL}
{$IFNDEF DISABLE_BIG_BRAIN}
//  StopMemoryCleaner;
{$ENDIF}

  {$ENDIF}
  {$ENDIF}





end.
