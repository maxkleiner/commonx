unit FormMockMobile;
{$I 'DelphiDefs.inc'}



//this unit is intended to allow windows apps to
//behave similarly to mobile apps.
{x$DEFINE NEW_MOVE}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, ScaledLayoutProportional,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, typex, numbers,
  formFMXBase, FMX.Objects, FMX.Controls.Presentation, better_collections, guihelpers_fmx,
{$IFDEF IOS}
  iosapi.uikit, fmx.helpers.ios,
{$ENDIF}
  FMX.Platform, FMX.Gestures, tickcount, betterobject, geometry, stringx, FMX.Effects,
  BackgroundTaskManager, FMX.Layouts, LayoutPortionOfParent, errortransmitter;

type
  TSetupProc = reference to procedure (frm: TfrmFMXBAse);

  TMQInfo = record
    startTime: ticker;
    msg: string;
    visual: TRectangle;
    function Opacity: single;
    function IsFinished: boolean;
    function Enabled: boolean;
  end;
  PMQinfo = ^TMQInfo;

  Tmm = class(TfrmFMXBase)
    BackGroundPanel: TPanel;
    TempMessageTimer: TTimer;
    BusyTimer: TTimer;
    tmIOSBG: TTimer;
    procedure btnGestureTestGesture(Sender: TObject;
      const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure TempMessageTimerTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BusyTimerTimer(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormVirtualKeyboardShown(Sender: TObject;
      KeyboardVisible: Boolean; const Bounds: TRect);
    procedure FormVirtualKeyboardHidden(Sender: TObject;
      KeyboardVisible: Boolean; const Bounds: TRect);
    procedure FormDestroy(Sender: TObject);
    procedure tmIOSBGTimer(Sender: TObject);
  private
    FIOSBG_Manager: TBackgroundTaskManager;
    IOSHack: boolean;
    function GetShowingForm: TfrmFMXBase;
  protected
    lastbusytimertime: ticker;
    FTemporaryMessageQueue: IHolder<TStringList>;
    FTempMsgInfo: TMQInfo;
    formstack: TBetterList<TfrmFMXBase>;
    procedure DoShow; override;
    { Private declarations }
    procedure PushForm(f: TfrmFMXBase);
    function PopForm: TfrmFMXBase;
    procedure ApplicationException(Sender: TObject; E: Exception);
  public
    FancyFrame: TFrame;
    OnShowFancy: TProc;
    OnHideFancy: TProc;
    OnFancyUpdate: TProc<nativeint>;
    OnFancyMessage: TProc<string>;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    procedure ToggleBusy(busy: Boolean); override;
    function WatchCommands: Boolean; override;


    { Public declarations }
    property showingform: TfrmFMXBase read GetShowingForm;
    procedure TakeControls;
    procedure MoveControls(owner, cfrm, cto: TFMXObject);
    procedure GiveBackControls;
    procedure ShowForm(f:TfrmFMXBase);
    constructor Create(AOwner: TComponent); override;
    procedure RemoveForm(f: TfrmFMXBase);
    procedure ShowFormClass<T: TfrmFMXBase>(var f: T);
    procedure ShowFormClassAndSetup<T: TfrmFMXBase>(var f: T; p: TProc);
    procedure TemporaryMessage(s: string);
    procedure TempMessageEngine;
    function IsHome: boolean;

    procedure ShowFancy;
    procedure HideFancy;
    procedure Fancyupdate(intv: ni);
    procedure FancyMessage(s: string);
    procedure MQVisualOnClick(sender: TObject);
    procedure GoHome;
    function IOSBG_ApplicationEventHandler(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure IOSBG_SetApplicationEventHandler;
    procedure IOSBG_Start;
    procedure IOSBG_Stop;
    procedure IOSBG_TaskExpiryHandler(Sender: TObject);

  end;

type
  TFormClass = class of TfrmFMXBase;
var
  frmDefault: TFormClass;
  OnConfigureMM: Tproc;
  mm: Tmm;

procedure MM_ShowForm(frm: TfrmFMXBase);
procedure MM_CloseForm(frm: TfrmFMXBase);


procedure SetMMConfig(proc: TProc);
procedure ConfigureMM();


type
  TAlignSet = set of TAlignLayout;
  TChildFindProc = reference to function (alignset: TAlignset; parent: TFMXObject): TFMXObject;


implementation

uses
{$IFNDEF DESIGN_TIME_PACKAGE}
{$IFNDEF NO_COMMON_NAV}
    ufrmCommonNav,
{$ENDIF}
{$ENDIF}
    debug;


procedure Tmm.ShowFormClass<T>(var f: T);
begin
  if f = nil then begin
    Debug.Log(CLR_UI+'***Creating form: '+ T.classname);
    f := T.create(application);
    Debug.Log(CLR_UI+'***Created form: '+ T.classname);
  end;
  Debug.Log(CLR_UI+'***Showing form: '+ f.classname);
  MM_ShowForm(f);
end;

procedure Tmm.ShowFormClassAndSetup<T>(var f: T; p: TProc);
begin
  if f = nil then begin
    Debug.Log(CLR_UI+'***Created form: '+ T.classname);
    f := T.create(application);
    Debug.Log(CLR_UI+'***Created form: '+ f.classname);
  end;

  Debug.Log(CLR_UI+'***running lambda setup proc()');
  p();

  Debug.Log(CLR_UI+'***Showing form: '+ f.classname);
  MM_ShowForm(f);
end;

procedure MM_ShowForm(frm: TfrmFMXBase);
begin
  //Transfer controls from form to this one
  if frm = nil then
    raise ECritical.create('trying to show a nil form');
  mm.ShowForm(frm);



end;

{$R *.fmx}

{ TfrmMockMobile }

procedure Tmm.AfterConstruction;
begin
  inherited;
  formMockmobile.configureMM;
end;

procedure Tmm.ApplicationException(Sender: TObject; E: Exception);
begin
  self.showmessage(e.message);
  SendErrorReport(e);
end;

procedure Tmm.BeforeDestruction;
begin
  inherited;
  for var t := 0 to formstack.count-1 do begin
    var f := formstack.Items[t];
    f.mock := nil;
  end;
  formstack.free;

end;

procedure Tmm.btnGestureTestGesture(Sender: TObject;
  const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  inherited;
//  btnGestureTest.text := 'gesture!'+getticker.tostring;
end;

procedure Tmm.BusyTimerTimer(Sender: TObject);
begin
  inherited;
  var tmSince := gettimesince(lastbusytimertime);
  lastbusytimertime := getticker;
  WatchCommands;
  if Assigned(OnFancyUpdate) then begin
    OnFancyUpdate(tmSince);
  end;
  Curtains_Frame(tmSince);
  application.OnException := self.applicationexception;
end;

constructor Tmm.Create(AOwner: TComponent);
begin
  inherited;
  formstack := TBetterList<TfrmFMXBase>.create;
  Debug.Log(self.ClassName+' created.');
  IOSBG_SetApplicationEventHandler;
  FIOSBG_Manager := TBackgroundTaskManager.Create;
  FIOSBG_Manager.OnExpiry := IOSBG_TaskExpiryHandler;

end;


procedure Tmm.DoShow;
begin
  inherited;
  if showingform = nil then begin
    Curtains(procedure begin
      var f := frmDefault.create(application);
      showform(f);
    end);
  end;

end;

procedure Tmm.FancyMessage(s: string);
begin
  //
end;

procedure Tmm.Fancyupdate(intv: ni);
begin
  if assigned(Onfancyupdate) then
    OnFancyUpdate(intv);
end;

procedure Tmm.FormCreate(Sender: TObject);
begin
  inherited;
  //
end;

procedure Tmm.FormDestroy(Sender: TObject);
begin
  inherited;
  application.onexception := nil;
end;

procedure Tmm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  inherited;
  //THIS code does not run because the form is actually MockMobile.
  {$IFDEF MSWINDOWS}
  if KeyChar = '`' then begin
  {$ELSE}
  if Key = vkHardwareBack then begin
  {$ENDIF}
  {$IFNDEF DESIGN_TIME_PACKAGE}
  {$IFNDEF NO_COMMON_NAV}
    if FormStack.LastItem is TfrmCommonNav then begin
      if not (FormStack.LastItem as TfrmCommonNav).HardwareBackAct then begin
//      Curtains(procedure begin  CURTAINS should be specifically and optionally called by backact
        (FormStack.LastItem as TfrmCommonNav).BackAct;
//      end);
      key := 0;
    end;
    end;
  {$ENDIF}
  {$ENDIF}
  end;

end;

procedure Tmm.FormResize(Sender: TObject);
begin
  inherited;

//  self.ShowMessage('resized to '+self.Width.ToString+'x'+self.Height.ToString);
  {$IFDEF IOS_HACK}
  if not IOSHack then begin
    IOSHack := true;
    try
      if self.Width < self.Height then begin
        self.ShowMessage('hack to '+self.Width.ToString+'x'+self.Height.ToString);
      end;
      mm.SetBounds(mm.Left, mm.Top, mm.Height, mm.Width);
    finally
      IOSHack := false;
    end;
  end;

  {$ENDIF}
  if (formstack <> nil) then
    if (formstack.count > 0) then
      TfrmFMXBase(formstack.lastitem).resize;
end;

procedure Tmm.FormVirtualKeyboardHidden(Sender: TObject;
  KeyboardVisible: Boolean; const Bounds: TRect);
begin
  inherited;
  if not keyboardvisible then begin
    BackGroundPanel.Align := TAlignLayout.client;
    BackGroundPanel.Height := Bounds.Top;
  end else begin
    BackGroundPanel.Align := TAlignLayout.top;
    BackGroundPanel.Height := Bounds.Top;

  end;
  if formstack.LastItem <> nil then begin
    formstack.LastItem.DealWithOnscreenKeyboard(keyboardvisible, bounds);
  end;

end;

procedure Tmm.FormVirtualKeyboardShown(Sender: TObject;
  KeyboardVisible: Boolean; const Bounds: TRect);
begin
  inherited;
  if not keyboardvisible then begin
    BackGroundPanel.Align := TAlignLayout.client;
    BackGroundPanel.Height := Bounds.Top;
  end else begin
    BackGroundPanel.Align := TAlignLayout.top;
    BackGroundPanel.Height := Bounds.Top;
  end;
  if formstack.LastItem <> nil then begin
    formstack.LastItem.DealWithOnscreenKeyboard(keyboardvisible, bounds);
  end;

end;

function Tmm.GetShowingForm: TfrmFMXBase;
begin
  if formstack.count = 0 then
    exit(nil);
  result := formstack.LastItem;
end;

procedure Tmm.GiveBackControls;
begin
  MoveControls(showingform, BackGroundPanel, showingform);
end;


procedure Tmm.GoHome;
begin
  Curtains(procedure begin
{$IFNDEF NO_COMMON_NAV}
    while not IsHome do begin
      if FormStack.LastItem is TfrmCommonNav then begin
        if not (FormStack.LastItem as TfrmCommonNav).HardwareBackAct then begin
    //      Curtains(procedure begin  CURTAINS should be specifically and optionally called by backact
            (FormStack.LastItem as TfrmCommonNav).BackAct(true);
    //      end);
        end;
      end;
    end;
{$ENDIF}
  end);

end;

procedure Tmm.HideFancy;
begin
  if assigned(OnHideFancy) then
    OnHideFancy;

end;

function Tmm.IOSBG_ApplicationEventHandler(AAppEvent: TApplicationEvent;
  AContext: TObject): Boolean;
begin
  case AAppEvent of
    TApplicationEvent.EnteredBackground:
    begin
      log('Entered Background');
      IOSBG_Start;
      Result := True;
    end;
    TApplicationEvent.WillBecomeForeground:
    begin
      IOSBG_Stop;
      log('Becoming foreground, so I told iOS that I am not running a background task any more');
      Result := True;
    end;
  else
    Result := False;
  end;
end;

procedure Tmm.IOSBG_SetApplicationEventHandler;
var
  LService: IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, LService) then
    LService.SetApplicationEventHandler(IOSBG_ApplicationEventHandler);
end;

procedure Tmm.IOSBG_Start;
begin
{$IFDEF IOS}
  FIOSBG_Manager.Start;
  Log(Format('Time left: %.2f', [SharedApplication.backgroundTimeRemaining]));
  tmIOSBG.Tag := 0;
  tmIOSBG.Enabled := True;
{$ENDIF}
end;

procedure Tmm.IOSBG_Stop;
begin
{$IFDEF IOS}
  tmIOSBG.Enabled := False;
  FIOSBG_Manager.Stop;
{$ENDIF}
end;

procedure Tmm.IOSBG_TaskExpiryHandler(Sender: TObject);
begin
  log('Oops! Expired');
end;

function Tmm.IsHome: boolean;
begin
  result := formstack.LastItem.IsHomeForm
end;

function Tmm.PopForm: TfrmFMXBase;
begin
  result := showingform;
  formstack.remove(result);
end;

procedure Tmm.PushForm(f: TfrmFMXBase);
begin
  formstack.add(f);
end;

procedure Tmm.RemoveForm(f: TfrmFMXBase);
begin
  Debug.Log('REMOVE FORM '+f.name+' from form stack.');
  if f = showingform then
    GiveBackControls;
  formstack.remove(f);

  if showingform <> nil then begin
    TakeControls;
    showingform.ActivateOrTransplant;
    showingform.ActivateByPop;
  end;
end;

procedure Tmm.ShowFancy;
begin
  if assigned(OnShowFancy) then begin
    OnShowFancy();
  end;

end;

procedure Tmm.ShowForm(f: TfrmFMXBase);
begin

  if showingform <> nil then begin
      showingform.Parent := nil;
    showingform.DeactivateOrTransplant;
    giveBackControls;
//    showingform.Hide;
  end;


  f.mock := self;
  PushForm(f);
  if showingform <> nil then begin
    Debug.Log(CLR_F+'*********************************************************');
    Debug.Log(CLR_F+'Form: '+showingform.classname);
    Debug.Log(CLR_F+'*********************************************************');
    showingform.parent := self;
    showingform.left := 0;
    showingform.width := width;
    showingform.top := 0;
    showingform.height := height;
    TakeControls;
    showingform.ActivateOrTransplant;
    showingform.ActivateByPush;
//    showingform.show;
  end;

  show;

end;

procedure Tmm.TakeControls;
begin
  MoveControls(showingform, showingform, self.BackGroundPanel);
{
  var mq : PMQinfo := @FTempMsginfo;

  if mq.enabled then begin
    if mq.visual <> nil then begin
      mq.visual.BringToFront;
    end;

  end;
}
end;

procedure Tmm.MoveControls(owner, cfrm, cto: TFMXObject);
{$IFNDEF NEW_MOVE}
begin
  if cfrm = nil then
    exit;
  var hitend := false;
  repeat
    hitend := true;
    //NOTE... Z-Order is an issue when transplanting controls
    //it would probably be best to analyze z-order ahead of time
    //then ensure that the z-ORder matches afterwards
    //right now, as long as t goes forwards... Z-Order seems okay

//    for var t:= cfrm.ChildrenCount-1 downto 0 do begin
    if cto <> nil then begin
      for var t:= 0 to cfrm.ChildrenCount-1 do begin
        var c := cfrm.Children[t];
        if c.owner = owner then begin
          if c.parent <> cto then begin
  //          Debug.Log('taking control: '+c.name+' from '+cfrm.name+' to '+cto.name);
            hitend := false;
            c.Parent := cto;
  //          c.SendToBack;
  //          Debug.Log('control now belongs to '+c.parent.name);
            break;
          end;
        end;
      end;
    end else begin
      for var t:= cfrm.ChildrenCount-1 downto 0 do begin
//      for var t:= 0 to cfrm.ChildrenCount-1 do begin
        var c := cfrm.Children[t];
        if c.owner = owner then begin
          if c.parent <> cto then begin
  //          Debug.Log('taking control: '+c.name+' from '+cfrm.name+' to '+cto.name);
            hitend := false;
            c.Parent := cto;
  //          c.SendToBack;
  //          Debug.Log('control now belongs to '+c.parent.name);
            break;
          end;
        end;
      end;
    end;
  until hitend;
end;
{$ELSE}
begin
  var LR: TChildFindProc := function (alignset: TAlignSet; parent: TFMXObject): TFMXObject
      begin
        var best: single := 0.0;
        result := nil;
        for var t:= 0 to parent.ChildrenCount-1 do begin
          var o := parent.Children[t];
          if o is TControl then begin
            var c := parent.Children[t] as TControl;
            if c.Align in alignset then begin
              if t = 0 then best := guihelpers_fmx.control_GetPosition(c).x
              else begin
                best := lesserof(best,guihelpers_fmx.control_GetPosition(c).x);
                result := c;
              end;
            end;
          end;
        end;
      end;

  var RL: TChildFindProc := function (alignset: TAlignSet; parent: TFMXObject): TFMXObject
      begin
        var best: single := 0.0;
        result := nil;
        for var t:= 0 to parent.ChildrenCount-1 do begin
          var o := parent.Children[t];
          if o is TControl then begin
            var c := parent.Children[t] as TControl;
            if c.Align in alignset then begin
              if t = 0 then best := guihelpers_fmx.control_GetPosition(c).x
              else begin
                best := greaterof(best,guihelpers_fmx.control_GetPosition(c).x);
                result := c;
              end;
            end;
          end;
        end;
      end;

  var UD: TChildFindProc := function (alignset: TAlignSet; parent: TFMXObject): TFMXObject
      begin
        var best: single := 0.0;
        result := nil;
        for var t:= 0 to parent.ChildrenCount-1 do begin
          var o := parent.Children[t];
          if o is TControl then begin
            var c := parent.Children[t] as TControl;
            if c.Align in alignset then begin
              if t = 0 then best := guihelpers_fmx.control_GetPosition(c).y
              else begin
                best := lesserof(best,guihelpers_fmx.control_GetPosition(c).y);
                result := c;
              end;
            end;
          end;
        end;
      end;

  var DU: TChildFindProc := function (alignset: TAlignSet; parent: TFMXObject): TFMXObject
      begin
        var best: single := 0.0;
        result := nil;
        for var t:= 0 to parent.ChildrenCount-1 do begin
          var o := parent.Children[t];
          if o is TControl then begin
            var c := parent.Children[t] as TControl;
            if c.Align in alignset then begin
              if t = 0 then best := guihelpers_fmx.control_GetPosition(c).y
              else begin
                best := greaterof(best,guihelpers_fmx.control_GetPosition(c).y);
                result := c;
              end;
            end;
          end;
        end;
      end;

  var mov: TProc<TAlignSet, TChildFindProc> := procedure (alignset: TAlignset; proc: TChildFindProc) begin
    var cc: TFMXObject := nil;
    repeat
      cc := proc(alignset, cfrm);
      if assigned(cc) then begin
//        Debug.Log('taking control: '+cc.name);
        cc.parent := cto;
        if cc is TScaledLayoutProportional then
          TScaledLayoutProportional(cc).ForceRealign;
      end;
    until cc = nil;
  end;

  mov([ TAlignLayout.Client,
        TAlignLayout.Contents,
        TAlignLayout.Center,
        TAlignLayout.VertCenter,
        TAlignLayout.HorzCenter,
        TAlignLayout.Vertical,
        TAlignLayout.Scale,
        TAlignLayout.Fit], UD);
  mov([TAlignLayout.Left, TAlignLayout.MostLeft, TAlignLayout.FitLeft], LR);
  mov([TAlignLayout.Right, TAlignLayout.MostRight, TAlignLayout.FitRight], RL);
  mov([TAlignLayout.Top, TAlignLayout.MostTop], UD);
  mov([TAlignLayout.Bottom, TAlignLayout.MostBottom], DU);







  showingform.transplanted := cto = showingform;
end;
{$ENDIF}
procedure Tmm.MQVisualOnClick(sender: TObject);
begin
  var mq : PMQinfo := @FTempMsginfo;
  if (not mq.enabled) and (FTemporaryMessageQueue=nil) then
    exit;
  if (not mq.enabled) and (FTemporaryMessageQueue.o.count = 0) then
    exit;

  mq.startTime := getticker-60000;

end;


procedure MM_CloseForm(frm: TfrmFMXBase);
begin
  frm.UnregisterWithMockMobile;

end;

{ TMQInfo }

function TMQInfo.Enabled: boolean;
begin
  result := starttime <> 0;
end;

function TMQInfo.IsFinished: boolean;
begin
  result := GetTimeSince(starttime) > 6000;
end;

function TMQInfo.Opacity: single;
const
  MAX_OPACITY = 0.85;
begin
  var nao := GetTicker;
  var dif := gettimesince(nao, starttime);
  if dif < 500 then
    exit(lesserof(MAX_OPACITY,dif / 500))
  else if dif > 5000 then
    exit(0.0)
  else if dif > 4500 then
    exit(lesserof(MAX_OPACITY,(6000-dif)/500))
  else
    exit(lesserof(MAX_OPACITY,1.0));



end;

procedure Tmm.TempMessageEngine;
begin
  var mq : PMQinfo := @FTempMsginfo;
  if (not mq.enabled) and (FTemporaryMessageQueue=nil) then
    exit;
  if (not mq.enabled) and (FTemporaryMessageQueue.o.count = 0) then
    exit;

  //start if not enabled
  if not mq.Enabled then begin
    mq.msg := FTemporaryMessageQueue.o[0];
    FTemporaryMessageQueue.o.delete(0);
    mq.startTime := getticker;
    mq.visual := TRectangle.Create(self);
    mq.visual.XRadius := 10;
    mq.visual.YRadius := 10;
    mq.visual.Fill.color := $EF000000;
    mq.visual.width := self.clientwidth;
    var txt: TLabel := TLabel.create(mq.visual);
    txt.parent := mq.visual;
    txt.AutoSize := true;
    txt.WordWrap := true;
    txt.Text := mq.msg;
    txt.width := mq.visual.Width;
//    txt.FontColor := $FFFFFFFF;
    txt.Font.Size := 24.0;
    txt.TextSettings.FontColor := $FFFFFFFF;
    txt.StyledSettings := [];
    //txt.align := TAlignLayout.Contents;
    txt.TextAlign := TTextAlign.Center;
    mq.visual.parent := self;

    Debug.Log('vis = '+mq.visual.width.tostring+', form = '+self.clientwidth.tostring);
    mq.visual.position.x := 0;
    mq.visual.position.y := 0;
    mq.visual.height := 1000;
//  mq.visual.align := TAlignLayout.top;
    mq.visual.BringToFront;
    mq.visual.OnClick := self.MQVisualOnClick;

    mq.visual.Height := txt.height;
//    mq.visual.Height := mq.visual.Height * (1+    stringx.CountChar(txt.Text, #13));





  end;
  //continue if enabled
  if mq.enabled then begin
    mq.visual.Height := mq.visual.Controls[0].height;
    mq.visual.Opacity := mq.Opacity;

//    mq.visual.position.y := Interpolate(gettimesince(mq.startTime)/3000, 32,0);
//    debug.Log(mq.visual.opacity.tostring);
  end;
  //finish
  if mq.IsFinished then begin
    mq.startTime := 0;
    mq.visual.parent := nil;
    mq.visual.DisposeOf;
    mq.visual := nil;
  end;

  if ((not mq.enabled) and (FTemporaryMessageQueue.o.count=0)) then
    TempMessageTimer.enabled := false;

end;

procedure Tmm.TempMessageTimerTimer(Sender: TObject);
begin
  inherited;
  TempMessageEngine;
end;

procedure Tmm.TemporaryMessage(s: string);
begin
  if FTemporaryMessageQueue = nil then begin
    FTemporaryMessageQueue := Tholder<TSTringList>.create;
    FTemporaryMessageQueue.o := TStringlist.create;
  end;

  FTemporaryMessageQueue.o.add(s);
  TempMessageTimer.Enabled := true;


end;

procedure Tmm.tmIOSBGTimer(Sender: TObject);
begin
  inherited;
  tmIOSBG.TagFloat := tmIOSBG.TagFloat + tmIOSBG.Interval / 1000;
  log(Format('Hopefully still running - %.0f', [tmIOSBG.TagFloat]));
  if tmIOSBG.TagFloat > 200 then
  begin
    log('Been running long enough..');
    IOSBG_Stop;
  end;
end;

procedure Tmm.ToggleBusy(busy: Boolean);
begin
  inherited;
  if busy then begin
    ShowFancy;
  end else begin
    HideFancy;
  end;
end;

function Tmm.WatchCommands: boolean;
begin
  result := inherited;
  if not BusyTimer.Enabled then
    BusyTimer.Enabled := true;
end;

procedure ConfigureMM();
begin
  if assigned(OnConfigureMM) then
    OnConfigureMM();
end;

procedure SetMMConfig(proc: TProc);
begin
  OnconfigureMM := proc;
end;

end.
