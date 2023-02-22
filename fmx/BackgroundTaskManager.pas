unit BackgroundTaskManager;
{$I 'DelphiDefs.inc'}

interface

uses
{$IFDEF IOS}
  iOSapi.UIKit,
{$ENDIF}
  System.Classes;

type
  TBackgroundTaskManager = class(TObject)
  private
{$IFDEF IOS}
    FTaskID: UIBackgroundTaskIdentifier;
{$ENDIF}
    FOnExpiry: TNotifyEvent;
    procedure DoExpiry;
    procedure Reset;
  public
    constructor Create;
    function IsValidTask: Boolean;
    function Start: Boolean;
    procedure Stop;
    property OnExpiry: TNotifyEvent read FOnExpiry write FOnExpiry;
  end;

implementation

{$IFDEF IOS}
uses
  Macapi.ObjectiveC, iOSapi.Foundation, iOSapi.CocoaTypes;
{$ENDIF}

const
  UIKitFwk: string = '/System/Library/Frameworks/UIKit.framework/UIKit';

type
  TBackgroundTaskHandler = procedure of object;

{$IFDEF IOS}
  UIApplication = interface(UIResponder)
    ['{8237272B-1EA5-4D77-AC35-58FB22569953}']
    function beginBackgroundTaskWithExpirationHandler(handler: TBackgroundTaskHandler): UIBackgroundTaskIdentifier; cdecl;
    procedure endBackgroundTask(identifier: UIBackgroundTaskIdentifier); cdecl;
  end;
  TUIApplication = class(TOCGenericImport<UIApplicationClass, UIApplication>)  end;
{$ENDIF}

{$IFDEF IOS}
function SharedApplication: UIApplication;
begin
  Result := TUIApplication.Wrap(TUIApplication.OCClass.sharedApplication);
end;
{$ENDIF}

{$IFDEF IOS}
function UIBackgroundTaskInvalid: UIBackgroundTaskIdentifier;
begin
  Result := CocoaIntegerConst(UIKitFwk, 'UIBackgroundTaskInvalid');
end;
{$ENDIF}

{ TBackgroundTaskManager }

constructor TBackgroundTaskManager.Create;
begin
  inherited;
  Reset;
end;

procedure TBackgroundTaskManager.DoExpiry;
begin
{$IFDEF IOS}
  Stop;
  if Assigned(FOnExpiry) then
    FOnExpiry(Self);
{$ENDIF}
end;

function TBackgroundTaskManager.IsValidTask: Boolean;
begin
{$IFDEF IOS}
  Result := FTaskID <> UIBackgroundTaskInvalid;
{$ELSE}
  result := true;
{$ENDIF}
end;

procedure TBackgroundTaskManager.Reset;
begin
{$IFDEF IOS}
  FTaskID := UIBackgroundTaskInvalid;
{$ENDIF}
end;

function TBackgroundTaskManager.Start: Boolean;
begin
{$IFDEF IOS}
  FTaskID := SharedApplication.beginBackgroundTaskWithExpirationHandler(DoExpiry);
  Result := IsValidTask;
{$ELSE}
  result := true;
{$ENDIF}
end;

procedure TBackgroundTaskManager.Stop;
begin
{$IFDEF IOS}
  if IsValidTask then
    SharedApplication.endBackgroundTask(FTaskID);
  Reset;
{$ENDIF}
end;

end.
