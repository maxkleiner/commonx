unit AppLock;

interface

uses
  betterobject, sharedobject;



type
  TFakeLock = class(TObject)
  public
    procedure lock;
    procedure unlock;
  end;

  TAppLock = class(TSharedObject)
  public
  end;

var
  AL: TappLock = nil;


implementation

{ TFakeLock }

procedure TFakeLock.lock;
begin

//TODO -cunimplemented: unimplemented block
end;

procedure TFakeLock.unlock;
begin

//TODO -cunimplemented: unimplemented block
end;

initialization
  AL := TAppLock.create;

finalization
  if assigned(AL) then
    AL.free;

end.
