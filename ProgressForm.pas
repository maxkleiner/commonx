unit ProgressForm;

{xDEFINE DISABLE_MODAL_COMMAND_WATCHING}

interface

uses
  numbers, tickcount, Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, ExceptionsX,orderlyinit,
  Dialogs, StdCtrls, ComCtrls, FormBase, GlassControls,exe, commandprocessor,
  ExtCtrls, generics.collections.fixed, debug, FrameHostPanel, FormBGThreadWatcher,
  Vcl.WinXCtrls, typex, betterobject;

const
  PB_HEIGHT = 14;
  LBL_HEIGHT = 32;
type
  TfrmProgress = class(TfrmBase)
    PB: TProgressBar;
    TimerWatchCommand: TTimer;
    TimerWatchQueue: TTimer;
    Timer1: TTimer;
    Timer2: TTimer;
    lbl: TLabel;
    panBG: TPanel;
    TimerWatchList: TTimer;
    procedure frmBaseCreate(Sender: TObject);
    procedure frmBaseClose(Sender: TObject; var Action: TCloseAction);
    procedure frmBaseDestroy(Sender: TObject);
    procedure TimerWatchCommandTimer(Sender: TObject);
    procedure TimerWatchQueueTimer(Sender: TObject);
    procedure frmBaseDblClick(Sender: TObject);
    procedure frmBaseFirstActivation(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure frmBaseActivate(Sender: TObject);
    procedure TimerWatchListTimer(Sender: TObject);
  private
    FcmdWatching: TCommand;
    FQueueWatching: TCommandProcessor;
    Fwatchlist: TCommandList<TCommand>;
    FWatchListHolder: IHolder<TCommandList<Tcommand>>;
    fReferences: integer;
    FPBs: TList<TProgressBar>;
    FLabels: TList<TLabel>;
    FOriginalHeight: integer;
    timeout: ticker;
    procedure AddPB;
    procedure RemovePB;
    procedure SetPBcount(cnt: ni);
    function GetCmdWatching: TCommand;
    procedure SetCmdWatching(const Value: TCommand);
    procedure AdjustFormHeight;


    { Private declarations }
  public
    tmStartWatching: ticker;
    bg: TfrmBGThreadWatcher;
    FDestroyItemsInListWhileWaiting: boolean;
    FDestroyItemsInListHolderWhileWaiting: boolean;

    constructor Create(aowner: TComponent);reintroduce;virtual;

    { Public declarations }
    procedure ExeConsole(ss: TConsolecaptureStatus; sStatus: string);
//    procedure WatchSingleCommand(cmd: TCommand);
    function WatchSingleCommand(bTakeOwnerShip: boolean; cmd: TCommand; timeout: ticker = 0): boolean;overload;
    function WatchSingleCommand(bTakeOwnership: boolean; level: ni; cmd: TCommand; timeout: ticker = 0; fin: TProc = nil): boolean;overload;


    procedure WatchSingleCommand_NonModal(cmd: TCommand);
    procedure WatchCommandQueue(q: TCommandProcessor);
    procedure WatchCommandList(l: TCommandList<TCommand>; destroycommandswhilewatiging: boolean);overload;
    procedure WatchCommandList(lh: IHolder<TCommandList<TCommand>>; destroycommandswhilewatiging: boolean);overload;
    procedure EnableCommandtimer(var msg: TMessage);message WM_USER+1;
    procedure EnableCommandQueuetimer(var msg: TMessage);message WM_USER+2;
    procedure EnableCommandListtimer(var msg: TMessage);message WM_USER+3;
    function beginProgress: nativeint;
    procedure EndProgress(bNoHide: boolean = false);
    function CurrentPB: TProgressBar;
    property CmdWatching: TCommand read GetCmdWatching write SetCmdWatching;
    procedure RefreshAllBars;
    procedure SyncBarsFromCommandList(cl: IHolder<TCommandList<TCommand>>);
//    function WatchCommandList(bTakeOwnership: boolean; cl: TCommandList<TCommand>; timeout: ticker=0): boolean;
  end;

var
  frmProgress: TfrmProgress = nil;

procedure ShowProgress(sStatus: string; min,max,pos: integer);overload;
procedure ShowProgress(pos,max: integer);overload;
//procedure HideProgress;
function BeginProgress(): ni;
procedure EndProgress();
function WatchSingleCommand(bTakeOwnership: boolean; cmd: TCommand; timeout: ticker = 0): boolean;overload;
function WatchCommandList(bTakeownership: boolean; cl: TCommandList<Tcommand>; timeout: ticker=0): boolean;overload;
function WatchCommandList(bTakeownership: boolean; cl: IHolder<TCommandList<Tcommand>>; timeout: ticker=0): boolean;overload;



implementation

{$R *.dfm}
function WatchCommandList(bTakeownership: boolean; cl: IHolder<TCommandList<Tcommand>>; timeout: ticker=0): boolean;overload;
begin
  if frmProgress = nil then
    frmProgress := TfrmProgress.create(application);

  frmProgress.WatchCommandList(cl, bTakeownership);
  result := true;

end;
function WatchCommandList(bTakeownership: boolean; cl: TCommandList<Tcommand>; timeout: ticker=0): boolean;
begin
  if frmProgress = nil then
    frmProgress := TfrmProgress.create(application);

  frmProgress.WatchCommandList(cl, bTakeownership);
  result := true;



end;


function WatchSingleCommand(bTakeOwnership: boolean; cmd: TCommand; timeout: ticker = 0): boolean;overload;
begin
  if frmProgress = nil then
    frmProgress := TfrmProgress.create(application);

  result := frmProgress.WatchSingleCommand(bTakeOwnership,cmd,timeout);
end;

function BeginProgress(): ni;
begin
  if frmProgress = nil then
    frmProgress := TfrmProgress.create(application);

  if not frmProgress.visible then begin
    frmProgress.show;

  end;
  frmProgress.SetFocus;
  result := frmProgress.BeginProgress();


end;
procedure EndProgress();
begin

  frmProgress.EndProgress();


end;


procedure ShowProgress(pos,max: integer);
begin
  ShowProgress('--', 0, max, pos);
end;

procedure ShowProgress(sStatus: string; min,max,pos: integer);
begin
  if not assigned(frmProgress) then
    application.createform(TfrmProgress, frmProgress);

  if not frmProgress.visible then begin
    frmProgress.show;

  end;
  frmProgress.SetFocus;
  if sStatus <> '--' then
    frmProgress.lbl.caption := sStatus;
  frmProgress.currentpb.min := min;
  frmProgress.currentpb.max := max;
  frmProgress.currentpb.position := pos;
  frmProgress.lbl.refresh;
  frmProgress.refreshallbars;

  frmProgress.refresh;
  if (max = 1) and (pos=0) then begin
    frmProgress.currentpb.Style  := pbstMarquee;
  end else begin
    frmProgress.currentpb.style := pbstnormal;
  end;

end;

procedure HideProgress;
begin
  postmessage(frmProgress.Handle, WM_CLOSE, 0,0);
//  frmProgress.visible := false;
end;


procedure TfrmProgress.AdjustFormHeight;
var
  pb: TProgressbar;
  pan_height: nativeint;
  pbheight: nativeint;
begin
  if not showing then
    exit;

  if panBG = nil then exit;
  if panBG.visible = false then
    pan_height := 0
  else
    pan_height := panBG.Height;

  if fpbs.count < 1 then begin
    self.clientheight := 150;
    exit;
  end;

  pbheight := FPbs[FPbs.count-1].top + PB_HEIGHT+FPbs[0].left;
  //(535-431) + ((5+(fpbs[0].height div 2)) * Fpbs.count);
  if panBG.Visible then begin
    if clientheight < (pbheight + 400) then begin
      clientheight := pbheight+pan_height;
    end else begin
      panBG.Height := clientheight - pbHeight;
      panBG.width := clientwidth;
      panBG.Left := 0;
    end;
  end else begin
    if clientheight > pbheight then
      clientheight := pbheight
    else if clientheight < pbheight then
      clientheight := pbheight;
  end;

//  clientheight := PAN_HEIGHT;


end;


procedure TfrmProgress.AddPB;
var
  pb: TProgressbar;
  pan_height: nativeint;
  pbheight: nativeint;
begin
  if panBG.visible = false then
    pan_height := 0
  else
    pan_height := panBG.Height;

  var c := FPBS.count;
  var lbl := TLabel.create(self);
  lbl.parent := self;
  lbl.width := fpbs[0].width;
  lbl.height := LBL_HEIGHT;
  lbl.anchors := fpbs[0].anchors;
  lbl.left := fpbs[0].left;
  lbl.top := fpbs[0].top + (c*(PB_HEIGHT+LBL_HEIGHT));
  lbl.Caption := '...';
  lbl.font := self.lbl.font;
  FLabels.add(lbl);

  pb := TProgressbar.create(self);
  pb.parent := self;
  pb.width := fpbs[0].width;
  pb.height := PB_HEIGHT;
  pb.anchors := fpbs[0].anchors;
  pb.left := fpbs[0].left;
  pb.top := fpbs[0].top + (c*(PB_HEIGHT+LBL_HEIGHT))+LBL_HEIGHT;
  Fpbs.add(pb);

  AdjustFormHeight;

  refresh;

end;

function TfrmProgress.beginProgress: nativeint;
begin
  inc(FReferences);
  if FReferences > 1 then begin
    AddPb();
  end;
  exit(fReferences);
end;

constructor TfrmProgress.Create(aowner: TComponent);
begin
  inherited Create(aowner);
end;

function TfrmProgress.CurrentPB: TProgressBar;
begin
  result := Fpbs[Fpbs.count-1];
end;

procedure TfrmProgress.EnableCommandListtimer(var msg: TMessage);
begin
  TimerWatchListTimer(self);
end;

procedure TfrmProgress.EnableCommandQueuetimer(var msg: TMessage);
begin
  TimerWatchQueueTimer(self);

end;

procedure TfrmProgress.EnableCommandtimer(var msg: TMessage);
begin
  TimerWatchCommandTimer(self);
end;

procedure TfrmProgress.EndProgress(bNoHide: boolean = false);
begin
  dec(FReferences);
  if FReferences < 0 then begin
    debug.log(self,'Progress form references less than ZERO!!!!', 'Error');
    FReferences := 0;
  end;

  if FReferences > 0 then
    RemovePB;
  if not bNoHide then begin
    if FReferences = 0 then begin
        Hide();
    end;
  end;



end;

procedure TfrmProgress.ExeConsole(ss: TConsolecaptureStatus; sStatus: string);
var
  sl: TStringlist;
begin
  sl := tStringlist.create;
  try
    case ss of
      ccStart: if not Showing then Show;
      ccProgress: begin
        if sStatus <> '' then begin
          sl.text := sStatus;
          lbl.caption := sl[sl.count-1];
        end;
      end;
    end;
  finally
    sl.free;
  end;
 end;

procedure TfrmProgress.frmBaseActivate(Sender: TObject);
begin
  inherited;
  AdjustFormHeight;
end;

procedure TfrmProgress.frmBaseClose(Sender: TObject; var Action: TCloseAction);
begin
  inherited;
  Action := caHide;
  timer1.Enabled := false;
  timer2.Enabled := false;
  TimerWatchCommand.enabled := false;
  TimerWatchQueue.enabled := false;

end;

procedure TfrmProgress.frmBaseCreate(Sender: TObject);
begin
  inherited frmBaseCreate(sender);
//  inherited;
  //stuff
  FReferences := 0;
  Fpbs := TList<TProgressBar>.create;
  FLabels := TList<TLabel>.create;

  pb.Height := 8;
  Fpbs.add(pb);
  FLabels.add(lbl);

  FOriginalHeight := self.height;
  FixLabelFlashing(lbl);
  AddPB;
  RemovePb;


end;

procedure TfrmProgress.frmBaseDblClick(Sender: TObject);
begin
  panBG.Visible := not panBG.Visible;

  if not panBG.Visible then
    height := height - panBG.Height
  else
    height := height + panBG.Height;

  if panBG.Visible then begin
    bg := TfrmBGThreadWatcher.Create(self);
    bg.Parent := panBG;
  end else begin
    bg.Free;
    bg := nil;
  end;

end;

procedure TfrmProgress.frmBaseDestroy(Sender: TObject);
begin
  timer1.Enabled := false;
  timer2.Enabled := false;
  inherited FormDestroy(sender);
  inherited;
  frmProgress := nil;
  FPbs.free;
  FLabels.free;


end;

procedure TfrmProgress.frmBaseFirstActivation(Sender: TObject);
begin
  self.panBG.Visible := false;
  self.clientHeight := 72;
  self.RecenterWindow;
  timer1.Enabled := true;


end;

function TfrmProgress.GetCmdWatching: TCommand;
begin
  Lock;
  try
    result:= FcmdWatching;
  finally
    Unlock;
  end;
end;

procedure TfrmProgress.RefreshAllBars;
var
  t: integer;
begin
  for t:= 0 to componentcount-1 do begin
    if components[t] is TProgressBar then begin
//      TProgressBar(components[t]).invalidate;
      TProgressBar(components[t]).Repaint;
    end;
  end;

end;

procedure TfrmProgress.RemovePB;
begin
  FPbs[fpbs.count-1].free;
  fpbs.delete(fpbs.count-1);
  FLabels[FLabels.count-1].free;
  FLabels.delete(FLabels.count-1);

end;

procedure TfrmProgress.SetCmdWatching(const Value: TCommand);
begin
  Lock;
  try
    FcmdWatching := value;
  finally
    unlock;
  end;
end;

procedure TfrmProgress.SetPBcount(cnt: ni);
begin
  while FPBs.count < cnt do
    AddPB;
  while FPBs.count > cnt do
    RemovePB;

end;

procedure TfrmProgress.SyncBarsFromCommandList(
  cl: IHolder<TCommandList<TCommand>>);
begin
  if cl = nil then
    exit;
  var l := cl.o.ToExecutingCommandListHolder;
  var x := l.o;

  var cnt := x.count;

  if cl.o.Count < 2 then
    cnt := 0;
  SetPBcount(cnt+1);
  var pc := cl.o.PercentComplete;
  FPbs[0].Min := 0;
  FPbs[0].Max := 1000;
  FPbs[0].Position := round(pc*1000.0);


  for var t := 1 to cnt do begin
    var xx := x[t-1];
    if xx <> nil then begin
      FPbs[t].Smooth := true;
      FPbs[t].Min := 0;
      FPbs[t].Max := xx.StepCount;
      FPbs[t].Position := greaterof(0, lesserof(xx.StepCount, xx.Step));
      FLabels[t].Caption := xx.Status;

    end;
  end;
end;

procedure TfrmProgress.Timer1Timer(Sender: TObject);
begin

  if not panBG.Visible then
    height := height - panBG.Height
  else
    height := height + panBG.Height;

  timer1.Enabled := false;
end;

procedure TfrmProgress.Timer2Timer(Sender: TObject);
begin
  ADjustFormHeight;
end;

procedure TfrmProgress.TimerWatchCommandTimer(Sender: TObject);
begin

  TimerWatchCommand.enabled := false;
  Lock;
  try
    if cmdWatching = nil then
      exit;

    if cmdWatching.IsComplete or (timeout>0) and (gettimesince(tmStartWatching)>timeout) then begin
      cmdWatching := nil;
      ModalResult := mrOK;
    end else begin
      try
        //Debug.ConsoleLog('currenpb='+inttostr(currentpb.top)+','+inttostr(currentpb.Left));
        if not currentpb.Visible then
          currentpb.visible := true;

        currentpb.Min := 0;
        currentpb.max := cmdWatching.StepCount;
        currentpb.Position := cmdWatching.Step;
        lbl.caption := cmdWatching.Status;
        if cmdWatching.StepCount = 1 then begin
          currentpb.Style  := pbstMarquee;
        end else begin
          currentpb.style := pbstnormal;
        end;

      finally
        TimerWatchCommand.enabled := true;
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TfrmProgress.TimerWatchListTimer(Sender: TObject);
begin

  TimerWatchList.enabled := false;
  Lock;
  try
    if currentpb = nil then exit;
    var w := FWatchList;
    var wh := FWatchListHolder;
    var dww := FDestroyItemsInListWhileWaiting;
    if wh <> nil then begin
      w := wh.o;
      dww := FDestroyItemsInListHolderWhileWaiting;
    end;


    if w = nil then
      exit;

    if w.IsComplete then begin
      {PASTED FROM BELOW!}
        if dww then begin
          w.lock;
          try
            for var tt:= 0 to w.Count-1 do begin
              if (w[tt] <> nil) and (w[tt].IsComplete) then begin
                w[tt].waitfor;
                w[tt].free;
                w[tt] := nil;
              end;
            end;
          finally
            w.unlock;
          end;
        end;
      {^^^PASTED FROM BELOW!^^^}

      w := nil;
      ModalResult := mrOK;
    end else begin
      try
        SyncBarsFromCommandList(FWatchListHolder);
        if dww then begin
          w.lock;
          try
            for var tt:= 0 to w.Count-1 do begin
              if (w[tt] <> nil) and (w[tt].IsComplete) then begin
                w[tt].waitfor;
                w[tt].free;
                w[tt] := nil;
              end;
            end;
          finally
            w.unlock;
          end;
        end;

        lbl.caption := 'Waiting for commands...';

      finally
        TimerWatchList.enabled := true;
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TfrmProgress.TimerWatchQueueTimer(Sender: TObject);
begin

  TimerWatchQueue.enabled := false;
  Lock;
  try
    if currentpb = nil then exit;

    if FqueueWatching = nil then
      exit;

    if FqueueWatching.IsComplete then begin
      FQueueWatching := nil;
      ModalResult := mrOK;
    end else begin
      try
        currentpb.Min := 0;
        currentpb.max := FqueueWatching.commandcount;
        currentpb.Position := FqueueWatching.completecount;
        if (currentpb.max = 1) and (currentpb.position=0) then begin
          frmProgress.currentpb.Style  := pbstMarquee;
        end else begin
          frmProgress.currentpb.style := pbstnormal;
        end;

        lbl.caption := 'Waiting for commands...';

      finally
        TimerWatchQueue.enabled := true;
      end;
    end;
  finally
    Unlock;
  end;
end;


procedure TfrmProgress.WatchCommandList(l: TCommandList<TCommand>; destroycommandswhilewatiging: boolean);
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  mq.pause := true;
  BeginProgress();
  try
    FWatchList := l;
    FDestroyItemsInListWhileWaiting := destroycommandswhilewatiging;

    PostMessage(self.handle, WM_USER+3, 0,0);

    IF showing then hide;
    showmodal;

  finally
    FqueueWatching := nil;
    EndProgress();
    Unlock;
    mq.pause := false;
  end;
{$ENDIF}

end;


procedure TfrmProgress.WatchCommandList(lh: IHolder<TCommandList<TCommand>>;
  destroycommandswhilewatiging: boolean);
begin
  mq.pause := true;
  BeginProgress();
  try
    FWatchListholder := lh;
    FDestroyItemsInListHolderWhileWaiting := destroycommandswhilewatiging;

    PostMessage(self.handle, WM_USER+3, 0,0);

    IF showing then
      hide;
    showmodal;

  finally
    FWatchListHolder := nil;
    FqueueWatching := nil;
    EndProgress();
    Unlock;
    mq.pause := false;
  end;

end;

procedure TfrmProgress.WatchCommandQueue(q: TCommandProcessor);
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  Lock;
  BeginProgress();
  try
    FqueueWatching := q;

    PostMessage(self.handle, WM_USER+2, 0,0);
    //TimerWatchCommand.Enabled := true;
    IF showing then hide;
    showmodal;

  finally
    FqueueWatching := nil;
    EndProgress();
    Unlock;
  end;
{$ENDIF}
end;

function TfrmProgress.WatchSingleCommand(bTakeOwnership: boolean; cmd: TCommand; timeout: ticker): boolean;
begin
  result := WatchSingleCommand(bTakeOwnership,0,cmd,timeout,nil);

end;

function TfrmProgress.WatchSingleCommand(bTakeOwnership: boolean; level: ni; cmd: TCommand;
  timeout: ticker; fin: TProc): boolean;
begin
  result := true;
{$IFDEF DISABLE_MODAL_COMMAND_WATCHING}
  WatchSingleCommand_nonModal(cmd);
  exit;
{$ENDIF}


  Lock;
  BeginProgress();
  try
    if cmd = nil then
      exit;

    if cmd.fireforget then
      raise Exception.create('You cannot watch a fireforget command');

    cmdWatching := cmd;
    if cmd.Fireforget then
      raise EClassException.create('You tried to watch a fire-forget command, this is BAD!');


    PostMessage(self.handle, WM_USER+1, 0,0);
    //TimerWatchCommand.Enabled := true;
    IF showing then hide;
    tmStartWatching := getticker;
    self.timeout := timeout;
    if not showing then
      showmodal;
    result := cmd.waitfor(lesserof(timeout,1));
  finally
    if bTakeOwnership then cmd.free;

    EndProgress(not result);
    Unlock;
  end;
end;
procedure TfrmProgress.WatchSingleCommand_NonModal(cmd: TCommand);
begin
  if cmd.Fireforget then
    raise EClassException.create('You tried to watch a fire-forget command, this is BAD!');

  bringtofront;
  if not showing then show;
  while not cmd.IsComplete do begin
    pb.Min := 0;
    pb.max := cmd.StepCount;
    pb.Position := cmd.Step;
    lbl.caption := cmd.Status;
    refresh;
    sleep(300);
  end;



end;

procedure oinit;
begin
  frmProgress := nil;
{$IFNDEF DESIGN_TIME_PACKAGE}
//  showmessage('progress form is being created');
//  frmProgress := TfrmProgress.create(nil);
{$ENDIF}
end;

procedure ofinal;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
//  showmessage('progress form is being destroyed');
//  frmProgress.free;
{$ENDIF}


end;

initialization
  init.RegisterProcs('ProgressForm', oinit, ofinal);


finalization

end.
