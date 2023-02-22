unit FormBase;
//TfrmBase is a common base-class that adds some generic, needed features
//to the Delphi base form class.  It is a work in progress, and I don't
//really ever "publish" visual apps... so little effort is put into making things
//perfect... but if you make bug fixes... please CHECK THEM IN and share!  Thanks!


// -- Some rudimentary functions for saving the positions of columns and
//    remembering the last size and position of the window.

// -- HardWork() and LazyWork() functions for keeping the GUI responsive while
//    performing background tasks
// -- Placeholders for implementing Busy-animations for when background operations are working
// -- A "FatMessageQueue" which processes messages that are more robust than
//    standard windows messages
// -- Override "FirstActivation" to perform one-time tasks that occur when the
//    form is activated for the first time.
// -- More is always coming.

//To use this:
// -- Add FormBase.pas to your project
// -- Inherit form this form by going to File->New->Other->Inheritable Items->TfrmBase
// -- Profit

{how to use hardwork()

begin

  var  SomeVariableFromSomeGUIElement := checkbox.checked;
  var someResult: boolean;

  HardWork(procedure begin
    //THIS CODE executes in a background thread... DO NOT TOUCH GUI CONTROLS HERE
    //rather gather data outsize this section into variables local to the function

    someResult := DoSomething(SomeVariableFromSomeGUIElement);


  end, procedure begin

    //THIS CODE EXECUTES IN THE GUI THREAD... you can now update controls
    checkbox.Checked := someResult;

  end);

end;
}



interface
{$DEFINE DISABLE_GLASS}
{x$DEFINE BEEP_ON_STATE_SAVE}
{x$DEFINE LOCALCOMMANDWAIT}//<<DONT USE THIS... if you do, then any commands with Synchronized finishes will fail

uses
  Windows, anoncommand, vcl.themes, vcl.styles, hardworker,
{$IFNDEF DESIGN_TIME_PACKAGE}
  ApplicationParams,
  fatmessage,
  commandprocessor,
tickcount,
  easyimage,
  GUIHelpers, GlassControls, numbers, geometry ,guiproclist, stringx,
{$ENDIF}
  betterobject,
{$IFDEF BEEP_ON_STATE_SAVE}
  beeper,
{$ENDIF}
  menus, extctrls, Variants, SysUtils, Dialogs, GDIPOBJ, StdCtrls, typex, systemx, gdiplus, generics.collections, Messages, ComCtrls, Classes, Graphics, Controls, Forms;

const
  CM_UPDATE_STATE = WM_USER+100;
type
  TworkOption = (woSerialize,woNeverCancel);
  TWorkOptions = set of TWorkOption;
  TfrmBase = class;//forward
  TAnonTimerProc = reference to procedure();

  TAnonFormTimer = class(TAnonymousCommand<boolean>)
  public
    form: TfrmBase;
    timerproc: TAnonTimerProc;
    procedure InitExpense;override;
  end;

  TFixedFormStyleHook = class(TFormStyleHook)
  protected
    procedure WndProc(var AMessage: TMessage); override;
  end;

  TSplitterHelper = class helper for TSplitter
  public
    function HackGetControl: TControl;
  end;


  TfrmBase = class(TForm)
    tmAfterFirstActivation: TTimer;
    tmDelayedFormSave: TTimer;
    tmFatMessage: TTimer;
    tmCommandWait: TTimer;
    procedure FormPaint(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FrmBaseCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure tmAfterFirstActivationTimer(Sender: TObject);
    procedure tmDelayedFormSaveTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure tmFatMessageTimer(Sender: TObject);
    procedure tmCommandWaitTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    Painted: boolean;
    FatMessagesPending: boolean;
    FLateLoaded: boolean;
    FDisabledtimers: TList<TTimer>;
    FCreatingThreadID: THandle;
    FSectReady: boolean;
    FOnPaintPLus: TGPGraphicEvent;
    FCanvasPLus: TCanvasPLus;
    FOriginallySheetOfGlass: boolean;
    FFakeSheetOfGlass: boolean;
    FOnFirstActivation: TNotifyEvent;
    FActivated: boolean;
    FUpdatingState: boolean;
    FOnUpdateState: TNotifyEvent;
    FCursorStack: array of TCursor;
    FManager: TForm;
    FPreviousWindowState: TWindowState;
    sect: TCLXCriticalSection;
    FonMove: TNotifyEvent;
    FshowHardWork: boolean;
    function GetCAnvasPLus: TCanvasPlus;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure SetManager(const Value: TForm);
{$ENDIF}
    function Getbottom: ni;
    function GetRight: ni;
    procedure SetBottom(const Value: ni);
    procedure SetRight(const Value: ni);
    procedure SetToken(const Value: string);

    { Private declarations }

  protected
{$IFNDEF DESIGN_TIME_PACKAGE}
    FLazyWork: TCommandList<TAnonymousCommand<boolean>>;
    ActiveCommands: TCommandList<TCommand>;
{$ENDIF}
    FToken: string;
{$IFNDEF DESIGN_TIME_PACKAGE}
    statuspanel: TPanel;
    statusprog: TProgressBar;

    MQ: TFatMessageQueue;
{$ENDIF}
    procedure SaveState;virtual;
    procedure LoadState;virtual;
    procedure CancelHardWork;
    procedure CancelLazyWork;
    procedure LoadLateState;virtual;
    procedure DoUpdateState;virtual;
{$IFNDEF DESIGN_TIME_PACKAGE}
    function HandleFatMessage(m: TFatMessage): boolean;virtual;
{$ENDIF}
    procedure WM_FATMSGPOSTED(var msg: TMessage); message WM_USER+999;
    function PPIKEY: string;

  public
    WorkingHard: boolean;
{$IFNDEF DESIGN_TIME_PACKAGE}
    progproc: TProc<TProgress>;
    progmethod: TProgMethod;
{$ENDIF}
    destructor Destroy;override;
    { Public declarations }
{$IFNDEF DESIGN_TIME_PACKAGE}
    class function GetUniqueHash: string; virtual;
    class function GetExistingForm(manager: TForm): TfrmBase;virtual;
    class function GetExistingOrCreate(manager: TForm): TfrmBase;virtual;
{$ENDIF}
    procedure EnableGlass;
    procedure AfterConstruction;override;
    property OriginallySheetOfGlass: boolean read FOriginallySheetOfGlass write FOriginallySheetOfGlass;
    procedure AdjustGlass;
    function HasMenu: boolean;
    procedure RecenterWindow;
    procedure Activate;override;
    property Activated: boolean read FActivated;
    property UpdatingState: boolean read FUpdatingState write FUpdatingState;
    procedure MSG_UpdateState(var msg: TMessage);message CM_UPDATE_STATE;
    procedure UpdateState;
    function WatchCommands: boolean;
    function DoWatchCommands: boolean;virtual;
    procedure UpdatecommandProgress(status: string; p: TProgress; index, cnt: nativeint);virtual;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure ResizeFrames;
{$ENDIF}
    procedure Detach;virtual;
{$IFNDEF DESIGN_TIME_PACKAGE}
    property Manager: TForm read FManager write SetManager;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
    function GetMyScreen: integer;
{$ENDIF}
    procedure _WM_GETMINMAXINFO(var mmInfo : TWMGETMINMAXINFO ); message wm_GetMinMaxInfo;
    procedure WMSize(var M : TWMSIZE); message WM_Size;
    property PreviousWindowState: TWindowState read FPreviousWindowState write FPreviousWindowState;
    procedure Lock;
    procedure Unlock;
    function TryLock: boolean;
    procedure SeekAndSaveColumns;
    procedure SeekAndSaveSplitters;
    procedure SeekAndLoadColumns;
    procedure SeekAndLoadSplitters;
    procedure SaveColumns(lv: TListView);
    procedure LoadColumns(lv: TListView);
    procedure SaveControlState(c: TComponent);
    procedure LoadControlState(c: TComponent);
    procedure FirstActivation;virtual;
    property CanvasPlus: TCanvasPlus read GetCanvasPlus;
    property CreatingThreadID: THandle read FCreatingThreadID;
    procedure Move(var Msg: TWMMove);message WM_MOVE;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure DoMove;virtual;
    procedure ShowStatus();overload;
    procedure ShowStatus(sMEssage: string);overload;
    procedure ShowStatus(c: TCommand);overload;
    procedure ShowStatus(p: TProgress);overload;
    procedure ShowProgress(prog: TProgress);
{$ENDIF}
    procedure FixListViewFlashing(lv: TListView);overload;
    procedure FixLabelFlashing(lbl: TLabel);
    procedure FixListViewFlashing();overload;

  published
    property OnPaintPlus: TGPGraphicEvent read FOnPaintPLus write FOnPaintPLus;
    property OnFirstActivation: TNotifyEvent read FOnFirstActivation write FOnFirstACtivation;
    property OnUpdateState: TNotifyEvent read FOnUpdateState write FonupdateState;

    procedure EnforceFormThread;
    property Right: ni read GetRight write SetRight;
    property Bottom: ni read Getbottom write SetBottom;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure DisableActiveTimers;
    procedure RestoreDisabledTimers;
{$ENDIF}
    function AsInterface<T:IUnknown>(guid: TGUID):T;
    function IsInterface(guid: TGUID):boolean;


    procedure LazyStateChange(b:boolean);virtual;
    function WindowCenter: TPoint;
    function GetToken: string;virtual;
    property Token: string read GetToken write SetToken;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure HideStatus;
    procedure WaitForSinglecommand(takeownership: boolean; c: TCommand; timeout: ticker = 0);
{$ENDIF}
    property OnMove: TNotifyEvent read FonMove write FOnMove;
    procedure SaveComponentStates;
    procedure DelaySaveState;
    procedure PushCursor(cr: TCursor);
    procedure PopCursor;
    property ShowHardWork: boolean read FshowHardWork write FShowHardWork;
{$IFNDEF DESIGN_TIME_PACKAGE}
    procedure CleanupExpiredCommands;
    function SetTimer(interval: ni; ontimerproc: TAnonTimerProc): TAnonFormTimer;
    procedure SetTimerAndWatch(interval: ni; ontimerproc: TAnonTimerProc);
    procedure HardWork(proc: TProc; guiSuccess: TProc = nil; guifail: TProc = nil);overload;

    procedure LazyWork(proc: TProc; guiproc: TProc = nil; workopts: TworkOptions = [woSerialize]);

    function ProcessFatMessage: boolean;
    function ProcessFatMessages: boolean;
    function HasLazyWork: boolean;
{$ENDIF}
    procedure WorkError(s: string);virtual;
    procedure ToggleBusy(busy: boolean);virtual;
    function BeginBusy: ni;
    procedure BusyUpdate(busylevel: ni; prog: TProgress; status: string= '');
    procedure EndBusy;

    procedure ShowSecondaryDock;virtual;
    procedure hideSecondaryDock;virtual;
    function IsSecondaryDockShowing: boolean;virtual;
    procedure FirstPaint;virtual;


  end;


type
  TfrmBaseClass = class of TfrmBase;

implementation


{$IFNDEF DESIGN_TIME_PACKAGE}
uses
  FrameBaseVCL,
  FormWindowManager,
{$IFNDEF LOCALCOMMANDWAIT}
  progressform,
{$ENDIF}
  debug;
{$ENDIF}

{$R *.dfm}

procedure TfrmBase.Activate;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  if not FActivated then begin
    FActivated := true;
    FirstActivation;
  end;
{$ENDIF}
  inherited;
  if csDesigning in componentstate then
    exit;
{$IFNDEF DESIGN_TIME_PACKAGE}


  if assigned(Manager) then
    TfrmWindowManager(Manager).ActiveForm := self;
{$ENDIF}

end;

procedure TfrmBase.AdjustGlass;
var
  t: integer;
  wc: TWinControl;
begin
  if csDestroying in componentstate then exit;

{$IFNDEF DISABLE_GLASS}
  if OriginallySheetOfGlass and HasMenu then begin
    self.GlassFrame.Bottom := clientheight+3;
  end;

  for t:= 0 to ControlCount-1 do begin
    if controls[t] is TWinControl then begin
      wc := controls[t] as TWinControl;
      wc.Repaint;
    end else
      continue;


  end;
{$ENDIF}

end;

procedure TfrmBase.AfterConstruction;
begin
  inherited;
  {$IFDEF DISABLE_GLASS}
  GlassFrame.Enabled := false;
  {$ELSE}
  if GlassFrame.Enabled then begin
    self.DoubleBuffered := true;
    OriginallySheetOfGlass := GlassFrame.SheetOfGlass;
    self.EnableGlass;
  end;
  {$ENDIF}

end;



procedure TfrmBase.EnableGlass;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  t: integer;
  c: TComponent;
  wc: TWinControl;
begin
  if csDestroying in componentstate then exit;
{$IFNDEF DISABLE_GLASS}
  OriginallySheetOfGlass := GlassFrame.SheetOfGlass;
  if HasMenu then begin
    GlassFrame.SheetOfGlass := false;
    AdjustGlass;
  end;


  self.DoubleBuffered := true;
  self.GlassFrame.Enabled := true;
  for t:= 0 to self.ComponentCount -1 do begin
    c := self.components[t ];
    if c is TWinControl then begin
      wc := c as TWincontrol;
      //wc.DoubleBuffered := true;
    end;
  end;
{$ENDIF}

end;
procedure TfrmBase.EndBusy;
begin
  //defautl code, don't call inherited if you want to fuck with shit
  progressform.EndProgress;
end;

{$ENDIF}

procedure TfrmBase.EnforceFormThread;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  if csDesigning in componentstate then
    exit;

  if GetcurrentThreadID <> CreatingThreadID then
    raise exception.Create('A function was called that requires threadid '+inttostr(CreatingThreadID)+' but was actually called from '+inttostr(GetCurrentThreadID));
{$ENDIF}

end;

procedure TfrmBase.FirstActivation;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  if Application.MainForm = self then
    MMQ.onposted := procedure begin
      tmFatMessage.enabled := true;
    end;

{$ENDIF}


  if csDesigning in componentstate then
    exit;
  FixListViewFlashing;
  LoadState;
  SeekAndLoadColumns;
  SeekAndLoadSplitters;
  if assigned(OnFirstActivation) then
    OnFirstActivation(self);
  tmAfterFirstActivation.enabled := true;
  Loaded;


end;

procedure TfrmBase.FirstPaint;
begin
  Activate;
end;

procedure TfrmBase.FixLabelFlashing(lbl: TLabel);
begin
  lbl.color := StyleServiceS.GetSystemColor(clWindow);
  lbl.StyleElements := lbl.StyleElements - [seClient];
  lbl.Transparent := false;

end;

procedure TfrmBase.FixListViewFlashing;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  self.ForEachComponent<TListView>(procedure (lv: TListView) begin
    FixListViewFlashing(lv);
  end);
{$ENDIF}
end;

procedure TfrmBase.FixListViewFlashing(lv: TListView);
begin
  lv.color := StyleServiceS.GetSystemColor(clWindow);
  lv.StyleElements := lv.StyleElements - [seClient];
end;

procedure TfrmBase.FormClose(Sender: TObject; var Action: TCloseAction);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}

begin
  SaveState;
  if Manager <> nil then
    Action := caFree;
end;
{$ENDIF}

procedure TfrmBase.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  CleanupExpiredCommands;
  //if you don't cleanup any commands that are potentially referencing
  //the form before shutting down, an Access Violation may likely occur.
  CanClose := ((ActiveCommands = nil) or (ActiveCommands.count = 0))
           and((FLazyWork = nil) or (FLazyWork.count = 0));


  if not CanClose then self.MQ.QuickBroadcast('RetryClose');
{$ENDIF}

end;

procedure TfrmBase.FrmBaseCreate(Sender: TObject);
begin
  inherited;
{$IFNDEF DESIGN_TIME_PACKAGE}
  progproc := procedure (prog: TProgress) begin
    var m := self.MQ.NewMessage;
    setlength(m.o.params,3);
    m.o.messageClass := 'Progress';
    m.o.params[0] := 'Working...';
    m.o.params[1] := prog.step.tostring;
    m.o.params[2] := prog.stepcount.tostring;
    mq.Post(m);
//    ShowProgress(prog);
  end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
  ShowHardWork := true;
    MQ := MMQ.NewSubQueue;

    mq.handler := function (m: IHolder<TFatMessage>): boolean begin
      result := HandleFatMessage(m.o);
    end;

    mq.onposted := procedure begin
      FatMessagesPending := true;
      PostMessage(self.Handle, WM_USER+999,0,0);
    end;

{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
  ActiveCommands := TcommandList<TCommand>.create;
  FLazyWork := TcommandList<TAnonymousCommand<boolean>>.create;
{$ENDIF}
  FToken := name;
  FCreatingThreadID := GetCurrentThreadId;
  ics(sect, classname+'-formBase');
  FSectReady:= true;
  FDisabledtimers := TList<TTimer>.create;



end;

procedure TfrmBase.FormDestroy(Sender: TObject);
begin
  Detach;
  FDisabledTimers.free;
{$IFNDEF DESIGN_TIME_PACKAGE}
  if FLazyWork <> nil then begin
    FLazyWork.WaitForAll_DestroyWhileWaiting;
    FLazyWork.Free;
    FLazyWork := nil;
  end;
  ActiveCommands.free;
  ActiveCommands := nil;
{$ENDIF}
  inherited;


end;

procedure TfrmBase.FormPaint(Sender: TObject);
begin
  inherited;
  if not painted then begin
    FirstPaint;
    Painted := true;
  end;
//  canvas.brush.color := 0;
//  canvas.Pen.Color := 0;
//  canvas.TextOut(0,0,'1');
end;


procedure TfrmBase.FormResize(Sender: TObject);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
procedure TfrmBase.FormShow(Sender: TObject);
begin
  inherited;
  //
end;

{$ELSE}
var
  mon: TMonitor;
begin
  inherited;
  if csDesigning in componentstate then
    exit;
  self.tmDelayedFormSave.enabled := false;
  self.tmDelayedFormSave.enabled := true;

  if csDestroying in componentstate then exit;
  if visible then
    adjustglass;

  if (WindowState = wsNormal) then begin
    if not IsValidScreenCoordinate(left, top) then begin
      mon := Screen.MonitorFromRect(rect(left, top, left+width-1, right+height-1));
      if mon <> nil then begin
        left := mon.left;
        top := mon.top;
      end;
    end;
  end;

end;
procedure TfrmBase.FormShow(Sender: TObject);
begin
  inherited;
//  ACtivate;
end;

{$ENDIF}

function TfrmBase.Getbottom: ni;
begin
  result := (top+height)-1;
end;

function TfrmBase.GetCanvasPLus: TCanvasPlus;
begin

  if FCAnvasPLus = nil then
    FCAnvasPLus := TCanvasPLus.Create(self.canvas.Handle);

  result := FCAnvasPLus;

end;


{$IFNDEF DESIGN_TIME_PACKAGE}
class function TfrmBase.GetExistingForm(manager: TForm): TfrmBase;
var
  t: integer;
  wm: TfrmWindowManager;
  s1, s2: string;
begin
  wm := manager as TfrmWindowManager;
  result := nil;
  for t := 0 to wm.windowcount-1 do begin

    if (TfrmBaseClass(wm.windows[t].Form.ClassType).GetUniqueHash) = GetUniqueHash then begin
      result := wm.Windows[t].form;
    end;
  end;
end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
class function TfrmBase.GetExistingOrCreate(manager: TForm): TfrmBase;

begin
  result := GetExistingForm(manager);
  if result = nil then begin
    result := create(manager);
    result.manager := TfrmWindowManager(manager);
  end;
end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.GetMyScreen: integer;
var
  t: integer;
  a: array of nativefloat;
  p1,p2: TPoint;
  m: TMonitor;
  max: nativefloat;
  maxt: ni;
begin
  result := 0;


  setlength(a, screen.monitorcount);
  //calculate area on screen

  p1.x := 0;
  p1.Y := 0;


  max := -1;
  maxt := 0;
  var pcenter: TPoint;
  pcenter.x := self.left + (self.width div 2);
  pcenter.y := self.top+ (self.height div 2);
//  for var t := 0 to screen.monitorcount-1 do begin
//    if pcenter.x
//  end;


  for t:= 0 to screen.monitorcount-1 do begin
    m := screen.Monitors[t];

    a[t] := GetIntersectedArea(self.Left, self.Top, self.Right, self.Bottom,
                               m.left, m.Top, m.Left+m.Width-1, m.top+m.Height-1);

    if a[t] > max then begin
      max := a[t];
      maxt := t;
    end;

  end;

  result := maxt;

end;
{$ENDIF}

function TfrmBase.GetRight: ni;
begin
  result := left+width-1;
end;

function TfrmBase.GetToken: string;
begin
  result := FToken;
end;

{$IFNDEF DESIGN_TIME_PACKAGE}
class function TfrmBase.GetUniqueHash: string;
begin
  result := classname;
end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.HandleFatMessage(m: TFatMessage): boolean;
begin
  result := false;
  if assigned(m.p) then
    m.p();
  if m.messageClass = 'RetryClose' then begin
    Close;
  end;

  if m.messageClass = 'MAXIMIZE' then begin
    debug.log('message maximize');
    WindowState := TWindowState.wsMaximized;
  end;

  if m.messageClass = 'NORMALIZE' then
    WindowState := TWindowState.wsNormal;

  if m.messageClass = 'Progress' then begin
    var s := m.params[0];
    var step :=m.params[1];
    var stepcount :=m.params[2];
    var p: TProgress;
    p.step := strtoint64(step);
    p.stepcount := strtoint64(stepcount);
    ShowStatus(s);
    showStatus(p);
  end;

end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.HardWork(proc: TProc; guiSuccess: TProc = nil; guifail: TProc = nil);
var
  cl: TCommandLIst<TCommand>;
begin
  Cursor := crHourGlass;
  WorkingHard := true;
  try
    cl := ActiveCommands;

    var p := InlineProcWithGuiEx(proc, procedure begin if assigned(guisuccess) then guisuccess() end, procedure(s: string) begin WorkError(s) end);
    p.Resources.SetResourceUsage('HardWork',1.0);
    cl.Add(p);
    p.start;
    WatchCommands;
  finally
    //WorkingHard := false;

  end;



end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.HasLazyWork: boolean;
begin
  result := FLazyWork.Count > 0;
end;
{$ENDIF}

function TfrmBase.HasMenu: boolean;
var
  t: integer;
begin
  result := false;
  for t:= 0 to componentcount-1 do begin
    if components[t] is TMainMenu then begin
      result := true;
      break;
    end;
  end;

end;

procedure TfrmBase.hideSecondaryDock;
begin
//
end;

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.HideStatus;
begin
  if csDesigning in componentstate then
    exit;

  statuspanel.free;
  statuspanel := nil;
end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.LazyStateChange(b: boolean);
begin
  // no implementation required
end;

procedure TfrmBase.LazyWork(proc:Tproc; guiproc: TProc = nil; workopts: TworkOptions = [woSerialize]);
var
  c: TAnonymousCommand<boolean>;
begin
  if csDesigning in componentstate then
    exit;

  if not assigned(guiproc) then
    c := InlineProc(proc)
  else
    c := InlineProcWithGui(proc, guiproc);
//  ActiveCommands.add(c);
//  hardworker := c;
  c.FireForget := false;
  if woSerialize in workopts then begin
    c.Resources.SetResourceUsage('LazyWork',1.0);
//    c.MemoryExpense := 1.0;
  end;
  if woNeverCancel in workopts then
    c.CanCancel := false;
  c.Start;
{$IFNDEF DESIGN_TIME_PACKAGE}
  FLazyWork.add(c);
  LazyStateChange(HasLazyWork);
  FatMessagesPending := true;
  PostMessage(self.Handle, WM_USER+999,0,0);
{$ENDIF}

//  if ShowHardWork then

//  else
//    c.WaitFor;

end;
{$ENDIF}

procedure TfrmBase.LoadColumns(lv: TListView);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  ap: TAppParams;
  sKey: string;
  t: ni;
  newwid: ni;
begin
  ap := NeedUserParams;
  try
    for t:= 0 to lv.Columns.Count-1 do begin
      sKey := PPIKEY+'STATE_'+self.Token+'->'+lv.Name+'['+inttostr(t)+'].width';
      newwid := ap.GetItemEx(sKey, lv.Columns[t].Width);

      lv.Columns[t].Width := newwid;
    end;
  finally
    NoNeedUserParams(ap);
  end;

end;
{$ENDIF}
procedure TfrmBase.LoadControlState(c: TComponent);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
begin
  var prefix :=   PPIKEY+'STATE_'+token+'_'+c.name+'_';
  if c is TEdit then
    (c as TEdit).text := (UPGet(prefix+'text',''));

  if c is TMemo then
    (c as TMemo).lines.text := hextostring(UPGet(prefix+'text',''));

end;
{$ENDIF}



procedure TfrmBase.LoadLateState;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  x,y: int64;
  bDoMaximize: boolean;
begin
  if csDesigning in componentstate then
    exit;
  UpdatingState := true;
  try

    bDoMaximize := UPGet(PPIKEY+'STATE_'+token+'_maximize', false);

    SeekAndLoadColumns;

    x := UPGet(PPIKEY+'STATE_'+token+'_left', -1);
    y := UPGet(PPIKEY+'STATE_'+token+'_top', -1);
    if bDoMaximize or IsValidScreenCoordinate(x,y) then begin
      self.Left := x;
      self.Top := y;

      x := UPGet(PPIKEY+'STATE_'+token+'_width', -1);
      if x > 0 then
        self.Width := x;

      x := UPGet(PPIKEY+'STATE_'+token+'_height', -1);
      if x > 0 then
        self.height := x;

    end;

    if bDoMaximize then begin
      MQ.QuickPost('MAXIMIZE');
      debug.log('maximize!');
//      self.WindowState := wsMaximized
    end
    else begin
      debug.log('normalize!');
      MQ.QuickPost('NORMALIZE');
//      self.WindowState := wsNormal;
    end;


  finally
    FLateLoaded := true;
    Loaded;
    UpdatingState := false;

  end;
end;
{$ENDIF}

procedure TfrmBase.LoadState;
begin
  //
end;

procedure TfrmBase.Lock;
begin
  ecs(sect);
end;

procedure TfrmBase.Move(var Msg: TWMMove);
begin
  if csDesigning in componentstate then
    exit;

{$IFNDEF DESIGN_TIME_PACKAGE}

  if assigned(tmDelayedFormSave) then begin
    self.tmDelayedFormSave.enabled := false;
    self.tmDelayedFormSave.enabled := true;
  end;

  if csDesigning in componentstate then
    exit;
  DoMove;


  if assigned(OnMove) then
    FonMove(self);
{$ENDIF}
end;

procedure TfrmBase.MSG_UpdateState(var msg: TMessage);
begin
  if csDesigning in componentstate then
    exit;
  UpdateState;
end;



procedure TfrmBase.PopCursor;
begin
  if csDesigning in componentstate then
    exit;

  cursor := FCursorStack[high(FCursorStack)];
  setlength(FCursorStack, length(FCursorStack)-1);
  invalidate;
  refresh;
end;

function TfrmBase.PPIKEY: string;
begin
  result := pixelsperinch.tostring+'ppi_';
end;

{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.ProcessFatMessage: boolean;
begin
  if csDesigning in componentstate then
    exit(false);

  if mq = nil then begin
    raise ECritical.create('form construction problem, MQ is nil, did you call inherited for '+classname+'?');
  end;

  result := MQ.ProcessNextMessage;

  var lck: ILock := FLazyWork.Locki;
  while (FLazywork.count > 0) and (FLazywork.Items[0].IsComplete) do begin
    var c := FLazywork.Items[0];
    FLazywork.delete(0);
    LazyStateChange(HasLazyWork);
    c.RaiseExceptions := false;
    c.WaitFor;
    if c.ErrorMessage<>'' then begin
      Debug.log('Error during lazy work. '+c.ErrorMessage)
    end;
//    if assigned(c.) then
//      c.guiproc();

    c.free;
  end;


//  result := result or HasLazyWork;


end;
{$ENDIF}


{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.ProcessFatMessages: boolean;
begin
  if csDesigning in componentstate then
    exit(false);

  repeat
    result := ProcessfatMessage
  until result = false;

end;
{$ENDIF}

procedure TfrmBase.PushCursor(cr: TCursor);
begin
  if csDesigning in componentstate then
    exit;

  setlength(FCursorStack, length(FCursorStack)+1);
  FCursorStack[high(FCursorStack)] := cursor;
  cursor := cr;
  invalidate;
  refresh;
end;

procedure TfrmBase.RecenterWindow;
{$IFDEF DESIGN_TIME_PACKAGE}
begin{}end;
{$ELSE}
var
  pm: TMonitor;
begin
  if csDesigning in componentstate then
    exit;
  //centering calculation
  pm := GetPrimaryMonitor;
  if pm <> nil then begin
    Top := ((pm.Height div 2) - (self.height div 2))+pm.top;
    Left := ((pm.Width div 2) - (self.Width div 2))+pm.left;
  end;

end;
{$ENDIF}



{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.ResizeFrames;
VAR
  t: integer;
  f: TfrmFrameBase;
begin
  for t:= 0 to Componentcount-1 do begin
    if components[t] is TfrmFrameBase then begin
      f := components[t] as TfrmFrameBase;
      f.ForceResize(f);
    end;
  end;

end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.RestoreDisabledTimers;
begin
  if csDesigning in componentstate then
    exit;

  if csDesigning in componentstate then
    exit;
  while fdisabledTimers.count > 0 do begin
    Fdisabledtimers[FDisabledTimers.count-1].Enabled := true;
    FdisabledTimers.delete(FDisabledTimers.count-1);
  end;

end;
{$ENDIF}

procedure TfrmBase.Unlock;
begin
  lcs(sect);
end;

procedure TfrmBase.UpdatecommandProgress(status: string; p: TProgress; index, cnt: nativeint);
begin
  //
end;

procedure TfrmBase.UpdateState;
var
  bOld: boolean;
begin
  if csDesigning in componentstate then
    exit;
{$IFNDEF DESIGN_TIME_PACKAGE}
  if GetCurrentThreadID <> CreatingThreadID then
    Debug.Log('THREAD VIOLATION in UpdateState');
{$ENDIF}
  bOld := UpdatingState;
  UpdatingState := true;
  try
    DoUpdateState;
    if Assigned(OnUpdateState) then begin
      OnupdateState(self);
    end;
  finally
    updatingState := bOld;
  end;
end;

procedure TfrmBase._WM_GETMINMAXINFO(var mmInfo: TWMGETMINMAXINFO);
var
  i: integer;
begin
//  tagMINMAXINFO = packed record
//    ptReserved: TPoint;
//    ptMaxSize: TPoint;
//    ptMaxPosition: TPoint;
//    ptMinTrackSize: TPoint;
//    ptMaxTrackSize: TPoint;
//  end;

{$IFNDEF DESIGN_TIME_PACKAGE}
  if Manager = nil then exit;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
  if GetMyScreen = TfrmBase(Manager).GetMyScreen then begin
    i := GetMyScreen;

    mmInfo.MinMaxinfo.ptMaxPosition.x := (screen.monitors[i].Left+manager.Width);
    mmInfo.MinMaxinfo.ptMaxPosition.y := 0;//screen.monitors[i].Top div 10;
    mmInfo.MinMaxinfo.ptMaxSize.x := screen.monitors[i].Width-manager.Width;
    mmInfo.MinMaxinfo.ptMaxSize.y := manager.height;


  end;
{$ENDIF}





end;


{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.WaitForSinglecommand(takeownership: boolean; c: TCommand; timeout: ticker = 0);
var
  wasenabled: boolean;
  tmLastUpdate: ticker;
begin
  if csDesigning in componentstate then
    exit;

//  var level := BeginBusy;
  progressform.WatchSingleCommand(takeownership,c, timeout);


end;

function TfrmBase.WatchCommands: boolean;
begin
//  try

  var wererunning := ActiveCommands.count = 0;
  if ActiveCommands.count > 0 then begin
//    Debug.Log(self.classname+'.WatchCommands');
    ToggleBusy(true);
{$IFDEF SINGLE_PROG}
    UpdateCommandProgress(activecommands[0].status, activecommands[0].volatile_progress,0,1);
    if activecommands[0].IsComplete then begin
      var c := activecommands[0];

      activecommands.delete(0);
      c.free;
      c := nil;
      if activecommands.count = 0 then
        ToggleBusy(false);

    end;
{$ELSE}

    activecommands.Lock;
    for var t:= 0 to activecommands.count-1 do begin
      UpdateCommandProgress(activecommands[t].status, activecommands[t].volatile_progress,t,activecommands.count);
    end;
    for var t:= activecommands.count-1 downto 0 do begin
      if activecommands[t].IsComplete then begin
        var c := activecommands[t];

        activecommands.delete(t);
        c.free;
        c := nil;
        if activecommands.count = 0 then
          ToggleBusy(false);

      end;
    end;
    tmCommandWait.enabled := false;
    try
      var il := ActiveCommands.LockI;
      if not doWatchCommands then begin
        var towatch := activecommands.ToCommandListHolder;
        progressform.WatchCommandList(false, towatch);
      end //else
        //WAtchcommands;
    finally
      tmCommandWait.enabled := true;
    end;



{$ENDIF}
  end;
  result := ActiveCommands.count = 0;
  if result and (result <> wererunning) then begin
//    Debug.Log(CLR_F+'*********************************************************');
    Debug.Log(CLR_F+'********* ALL COMMANDS watched by '+self.classname+' ARE COMPLETE');
//    Debug.Log(CLR_F+'*********************************************************');
  end;
//  finally
  if result then begin
    WorkingHard := not result;
    ToggleBusy(not result);
    enabled := true;
    Cursor := crDefault;
  end else begin
    WorkingHard := not result;
    ToggleBusy(not result);
    enabled := false;
    Cursor := crHourGlass;
  end;
//  end;

end;

{$ENDIF}


function TfrmBase.WindowCenter: TPoint;
begin
  result := point((left+width) div 2, (top+height) div 2);
end;

procedure TfrmBase.WMSize(var M : TWMSIZE) ;
begin
  if Application.MainForm = self then begin
    inherited;
    exit;
  end;



  if m.SizeType <> Size_Minimized then begin
    case m.SizeType of
      SIZE_RESTORED: PreviousWindowState := wsNormal;
//      SIZE_MINIMIZED: PreviousWindowState := wsMinimized;
      SIZE_MAXIMIZED: PreviousWindowState := wsMaximized;
      SIZE_MAXSHOW: PreviousWindowState := wsMaximized;
      SIZE_MAXHIDE: PreviousWindowState := wsMaximized;
    end;
  end;

  if M.SizeType = Size_Minimized then
  begin
//    PreviousWindowState := WindowState;
    ShowWindow(Handle,Sw_Hide) ;
    M.Result := 0;
  end
  else
    inherited;//DefaultHandler(m);
end;


procedure TfrmBase.WM_FATMSGPOSTED(var msg: TMessage);
begin
  FatMessagesPending := true;
//  ProcessFatMessages;
  tmFatMessage.enabled := true;


end;

procedure TfrmBase.WorkError(s: string);
begin
  showmessage(s);
end;

procedure TfrmBase.DelaySaveState;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  tmDelayedFormSave.Enabled := false;
  tmDelayedFormSave.Enabled := true;
{$ENDIF}

end;

destructor TfrmBase.Destroy;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  MMQ.DeleteSubQueue(MQ);
{$ENDIF}
  inherited;
  dcs(sect);
end;

procedure TfrmBase.Detach;
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  Manager := nil;
{$ENDIF}
end;


{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.DisableActiveTimers;
var
  tm: TTimer;
  t: ni;
begin
  if csDesigning in componentstate then
    exit;

  for t:= 0 to componentcount-1 do begin
    if components[t] is TTimer then begin
      tm := components[t] as TTimer;
      if tm.enabled then begin
        FDisabledtimers.add(tm);
        tm.enabled := false;
      end;
    end;
  end;
end;
{$ENDIF}

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.DoMove;
begin
  if csDesigning in componentstate then
    exit;

  if not Activated then
    exit;

  tmDelayedFormSave.enabled := false;
  tmDelayedFormSave.enabled := true;
//  FormResize(self);
end;
{$ENDIF}

procedure TfrmBase.DoUpdateState;
begin
  if csDesigning in componentstate then
    exit;
  //no implementation required

end;

function TfrmBase.DoWatchCommands: boolean;
begin
  //return true to indicate that you've handled this
  result := false;

end;

procedure TfrmBase.SaveColumns(lv: TListView);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  ap: TAppParams;
  sKey: string;
  t: ni;
begin
  UPBegin;
  try
    for t:= 0 to lv.Columns.Count-1 do begin
      sKey := PPIKEY+'STATE_'+self.Token+'->'+lv.Name+'['+inttostr(t)+'].width';
      UPPut(sKey, inttostr(lv.Columns[t].Width));

    end;

  finally
    UPEnd;
  end;

end;
{$ENDIF}

procedure TfrmBase.SaveComponentStates;
begin
  if csDesigning in componentstate then
    exit;
  if not UpdatingState then begin
    SaveState;
  end;
end;


procedure TfrmBase.SaveState;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  x: int64;
begin
  if csDesigning in componentstate then
    exit;
  if not FLateLoaded then
    exit;
  SeekAndSaveColumns;
  SeekAndSaveSplitters;
//  if not (windowstate=wsMaximized) then begin
    UPPut(PPIKEY+'STATE_'+token+'_width', width);
    UPPut(PPIKEY+'STATE_'+token+'_height', height);
    UPPut(PPIKEY+'STATE_'+token+'_left', left);
    UPPut(PPIKEY+'STATE_'+token+'_top', top);
//  end;
  UPPut(PPIKEY+'STATE_'+token+'_maximize', WindowState=wsMaximized);
{$IFDEF BEEP_ON_STATE_SAVE}
  beeper.BeepArray([500,1000], [50,50]);
{$ENDIF}
end;
{$ENDIF}

procedure TfrmBase.SeekAndLoadColumns;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  lv: TlistView;
  t: ni;
begin
  if csDesigning in componentstate then
    exit;
  for t:= 0 to componentcount-1 do begin
    if components[t] is TListView then begin
      lv := components[t] as TListView;
      LoadColumns(lv);
    end;
  end;
end;
{$ENDIF}

procedure TfrmBase.SeekAndLoadSplitters;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
begin
  if csDesigning in componentstate then
    exit;
  for var t:= 0 to componentcount-1 do begin
    if components[t] is TSplitter then begin
      var sp := components[t] as TSplitter;
      var c:= sp.HackGetControl;
      if c = nil then continue;
      var sKey := PPIKEY+'STATE_'+self.Token+'->'+c.Name+'['+inttostr(t)+'].width';
      var w: ni := UPGet(sKey, -1);
      if c =  nil then continue;
      if w > -1 then
        c.Width := w;


    end;
  end;
end;
{$ENDIF}

procedure TfrmBase.SeekAndSaveColumns;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
var
  lv: TlistView;
  t: ni;
begin
  if csDesigning in componentstate then
    exit;
  for t:= 0 to componentcount-1 do begin
    if components[t] is TListView then begin
      lv := components[t] as TListView;
      SaveColumns(lv);
    end;
  end;
end;
{$ENDIF}


procedure TfrmBase.SeekAndSaveSplitters;
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
begin
  if csDesigning in componentstate then
    exit;
  for var t:= 0 to componentcount-1 do begin
    if components[t] is TSplitter then begin
      var sp := components[t] as TSplitter;
      var c:= sp.HackGetControl;
      if c = nil then continue;
      var sKey := PPIKEY+'STATE_'+self.Token+'->'+c.Name+'['+inttostr(t)+'].width';
      UPPut(sKey, c.Width);

    end;
  end;
end;
{$ENDIF}


procedure TfrmBase.SetBottom(const Value: ni);
var
  i: ni;
begin
  i := value-top;
  if i > 0 then begin
    height := i;
  end;
end;

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.SetManager(const Value: TForm);
begin
  if not (csDesigning in componentstate) then begin
    if assigned(FManager) then begin
      TfrmWindowManager(FManager).UnregisterWindow(self);
    end;


    FManager := Value;


    if assigned(FManager) then begin
      TfrmWindowManager(FManager).registerWindow(self);
    end;

  end;

end;
{$ENDIF}

procedure TfrmBase.SetRight(const Value: ni);
var
  i: ni;
begin
  i := value-left;
  if i > 0 then begin
    width := i;
  end;
end;

{$IFNDEF DESIGN_TIME_PACKAGE}
function TfrmBase.SetTimer(interval: ni; ontimerproc: TAnonTimerProc): TAnonFormTimer;
var
  c: TAnonFormTimer;
  tmStart: ticker;
begin
  if csDesigning in componentstate then
    exit(nil);

  c := TAnonFormTimer.create(
    function : boolean
    begin
      tmStart := GetTicker;
      c.status := 'Please wait...';
      c.step := 0;
      c.stepcount := interval;
      while gettimesince(tmStart) < interval do begin
        sleep(lesserof(interval, ((tmSTart+interval)-getticker), 500));
        c.step := gettimesince(tmStart);
      end;
      exit(true);
    end,
    procedure (b: boolean)
    begin
      ontimerproc();
    end,
    procedure (e: exception)
    begin
    end
  );
  result := c;
  result.FireForget := false;
  result.SynchronizeFinish := true;
  result.form := self;
  result.start;
{$IFNDEF DESIGN_TIME_PACKAGE}
  ActiveCommands.add(result);
{$ENDIF}
  CleanupExpiredcommands;


end;
{$ENDIF}
{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.SetTimerAndWatch(interval: ni;
  ontimerproc: TAnonTimerProc);
var
  c: TAnonFormTimer;
begin
  if csDesigning in componentstate then
    exit;

  c := SetTimer(interval, ontimerproc);
  self.WaitForSinglecommand(false,c);
  CleanupExpiredCommands;
end;
{$ENDIF}

procedure TfrmBase.SetToken(const Value: string);
begin
  FToken := value;
end;

procedure TfrmBase.ShowSecondaryDock;
begin

end;

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.ShowStatus;
begin
  if csDesigning in componentstate then
    exit;

  if csDesigning in componentstate then
    exit;
  if statuspanel = nil then begin
    statuspanel := TPanel.create(self);

    statusprog := TProgressBar.create(self);
    statusprog.parent := statuspanel;
    statusprog.align := alBottom;
  end;

  statuspanel.Font.Size := 18;
  statuspanel.parent := self;
  statuspanel.Width := clientwidth;
  statuspanel.Height := clientheight div 8;
  statuspanel.Left := 0;
  statuspanel.top := (clientheight div 16) * 7;
  statuspanel.BringToFront;


end;

procedure TfrmBase.ShowProgress(prog: TProgress);
begin
  if csDesigning in componentstate then
    exit;

  statuspanel.caption := 'Please wait...';
  ShowStatus(prog);
  //application.processmessages;
end;

procedure TfrmBase.ShowStatus(c: TCommand);
begin
  if csDesigning in componentstate then
    exit;

  showstatus();
  statuspanel.caption := c.Status;
  statusprog.visible := true;
  statusprog.Min := 0;
  statusprog.MAx := c.StepCount;
  statusprog.Position := c.Step;
  refresh;

end;


procedure TfrmBase.ShowStatus(p: TProgress);
begin
  if csDesigning in componentstate then
    exit;

//  if p = nil then begin
    if p.step < 0 then begin
      hidestatus();
      exit;
    end;
//  end;

  showstatus();
  statusprog.visible := true;
  statusprog.Min := 0;
  statusprog.MAx := p.stepcount;
  statusprog.Position := p.Step;
  refresh;

end;


procedure TfrmBase.ShowStatus(sMEssage: string);
begin
  if csDesigning in componentstate then
    exit;

  showStatus();
  statuspanel.caption := sMessage;
  statusprog.visible := false;
  refresh;
end;
{$ENDIF}

procedure TfrmBase.tmAfterFirstActivationTimer(Sender: TObject);
begin
  if csDesigning in componentstate then
    exit;
  tmAfterFirstActivation.enabled := false;
  LoadLateState;

end;

procedure TfrmBase.tmCommandWaitTimer(Sender: TObject);
begin
{$IFNDEF DESIGN_TIME_PACKAGE}
  var il := ActiveCommands.LockI;
  WAtchcommands;
{
  if ActiveCommands.count = 0 then begin
    enabled := true;
    MQ.Pause := false;
  end else begin
    var c := ActiveCommands[0];
    if c.IsComplete then begin
      ActiveCommands.remove(c);
      c.free;
    end;
  end;}
{$ENDIF}
end;

procedure TfrmBase.tmDelayedFormSaveTimer(Sender: TObject);
begin
  if csDesigning in componentstate then
    exit;
  SaveComponentStates;
  tmDelayedFormSave.enabled := false;
end;

procedure TfrmBase.tmFatMessageTimer(Sender: TObject);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
begin
  tmFatMessage.enabled := ((application.mainform=self) and MMQ.ProcessNextMessage) or ProcessFatMessage or HasLazywork;
end;
{$ENDIF}

procedure TfrmBase.ToggleBusy(busy: boolean);
begin
  //
end;

function TfrmBase.TryLock: boolean;
begin
  result := tecs(sect);
end;

function TfrmBase.AsInterface<T>(guid: TGUID): T;
begin
  if IsInterface(guid) then begin
    //Supports(self, T, result);
    self.QueryInterface(guid,result);
  end;

end;


function TfrmBase.BeginBusy: ni;
begin
  result := progressform.beginprogress;


end;

procedure TfrmBase.BusyUpdate(busylevel: ni; prog: TProgress; status: string);
begin
  progressform.ShowProgress(status, 0,prog.step, prog.stepcount);

end;

{$IFNDEF DESIGN_TIME_PACKAGE}
procedure TfrmBase.CancelHardWork;
begin
  ACtiveCommands.locki;
  for var t:= 0 to activecommands.count-1 do begin
    ActiveCommands[t].Cancel;
  end;
end;

procedure TfrmBase.CancelLazyWork;
begin
  FLazyWork.locki;
  for var t:= 0 to FLazyWork.count-1 do begin
    FLazyWork[t].Cancel;
  end;
end;

procedure TfrmBase.CleanupExpiredCommands;
begin
  if csDesigning in componentstate then
    exit;

  if ActiveCommands = nil then
    exit;

  var lck :ILock := ActiveCommands.Locki;
  while (ActiveCommands.count > 0) and (ActiveCommands[0].IsComplete) do begin
    try
      ActiveCommands[0].RaiseExceptions := false;
      ActiveCommands[0].WaitFor;
    finally
      var c := ActiveCommands[0];
      ActiveCommands.delete(0);

      c.RaiseExceptions := false;
      c.free;

    end;

  end;


end;
{$ENDIF}


function TfrmBase.IsInterface(guid: TGUID): boolean;
var
  cout:IUnknown;
begin
  result := self.QueryInterface(guid,cout)= 0;
end;



function TfrmBase.IsSecondaryDockShowing: boolean;
begin
  result := false;
end;

{ TAnonymousTimer }

procedure TAnonFormTimer.InitExpense;
begin
  inherited;
  cpuexpense := 0.0;
end;

{ TFixedFormStyleHook }

procedure TFixedFormStyleHook.WndProc(var AMessage: TMessage);
var
  NewMessage: TMessage;
  ncParams: NCCALCSIZE_PARAMS;
begin
  if (AMessage.Msg = WM_NCCALCSIZE) and (AMessage.WParam = 0) then
  begin
    // Convert message to format with WPARAM = TRUE due to VCL styles
    // failure to handle it when WPARAM = FALSE.  Note that currently,
    // TFormStyleHook only ever makes use of rgrc[0] and the rest of the
    // structure is ignored. (Which is a good thing, because that's all
    // the information we have...)
    ZeroMemory(@ncParams,SizeOf(NCCALCSIZE_PARAMS));
    ncParams.rgrc[0] := TRect(Pointer(AMessage.LParam)^);

    NewMessage.Msg := WM_NCCALCSIZE;
    NewMessage.WParam := 1;
    NewMessage.LParam := Integer(@ncParams);
    NewMessage.Result := 0;
    inherited WndProc(NewMessage);

    if Handled then
    begin
      TRect(Pointer(AMessage.LParam)^) := ncParams.rgrc[0];
      AMessage.Result := 0;
    end;
  end
  else
    inherited;
end;

{ TSplitterHelper }

function TSplitterHelper.HackGetControl: TControl;
begin
  with self do begin
    result := FindControl;
  end;
end;

procedure TfrmBase.SaveControlState(c: TComponent);
{$IFDEF DESIGN_TIME_PACKAGE}
begin
  //
end;
{$ELSE}
begin
  var prefix :=   PPIKEY+'STATE_'+token+'_'+c.name+'_';
  if c is TEdit then
    UPPut(prefix+'text',(c as TEdit).text);

  if c is TMemo then
    UPPut(prefix+'text',stringx.StringTohex((c as TMemo).text));


end;
{$ENDIF}


initialization

{$IFNDEF DESIGN_TIME_PACKAGE}
  TCustomStyleEngine.RegisterStyleHook(TForm,TFixedFormStyleHook);
  TCustomStyleEngine.RegisterStyleHook(TCustomForm,TFixedFormStyleHook);
{$ENDIF}


end.

