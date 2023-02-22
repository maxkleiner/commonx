unit global_sound_thread_for_oscillators;

interface

uses
  soundtools, sounddevice_portaudio, managedthread, orderlyinit, debug;

var
  GSnd : TsoundDevice_portaudio = nil;

procedure StartSound;
procedure StopSound;

implementation

procedure StartSound;
begin
  if Gsnd <> nil then
    exit;
  GSnd := TPM.Needthread<TsoundDevice_portaudio>(nil);
  Gsnd.Start;
end;



procedure StopSound;
begin
  GSnd.ShuttingDown := true;
  GSnd.stop;
  Debug.log('stopped '+GSnd.classname);
  TPM.noNeedThread(GSnd);
  Gsnd := nil;
end;

procedure oinit;
begin
end;

procedure ofinal;
begin
end;


initialization
  Gsnd := nil;



end.
