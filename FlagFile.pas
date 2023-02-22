unit FlagFile;

interface


uses
  betterobject, systemx, classes, ExceptionsX, sysutils, typex, tickcount;

type
  ILockFile = IHolder<TFileStream>;
  TFlagFileHandler = class(TSharedObject)
  public
    class function TryHoldFlag(sFile: string): ILockFile;
    class function AssertFlagHold(sFile: string): ILockFile;
    class function WaitForFlagHold(sFile: string; iTimeout: ni = -1): ILockFile;
  end;




implementation

{ TFlagFileHandler }


class function TFlagFileHandler.AssertFlagHold(sFile: string): ILockFile;
begin
  var tmLockStart := GetTicker;
  repeat
    result := TryHoldFlag(sFile);
    if gettimesince(tmLockStart) > 12000 then begin
      break;
    end;
    sleep(500);
  until result <> nil;
  if result = nil then
    raise ECritical.create('Could not hold lock file after trying for 12 seconds, another process might be running! '+sFile);

end;

class function TFlagFileHandler.TryHoldFlag(sFile: string): ILockFile;
begin
  try
    result := nil;
    var fs := TFileStream.create(sFile, fmCReate);
    result := Tholder<TfileStream>.create;
    result.o := fs;

  except
    result := nil;
  end;
end;

class function TFlagFileHandler.WaitForFlagHold(sFile: string;
  iTimeout: ni): ILockFile;
var
  tmStart: ticker;
begin
  result := nil;
  tmStart := GetTicker;
  repeat
    result := TryHoldFlag(sFile);
    if result <> nil then
      exit;
    sleep(random(1000));//use random sleep time to create jitter amongst competitors
  until (iTimeout >= 0) and (gettimesince(tmStart) > iTimeout);

  raise ECritical.Create('Failed to get Lock on '+sFile);

end;

end.
