unit VideoSync;

interface

uses
  classes, windows, mmsystem, typex, systemx, sysutils;

const
  VF_PAUSE = 1;
  VF_KARAOKE = 2;
  TRACK_ANNOUNCE = 100;
  TRACK_ROTATION_NOW_APPEARING = 101;
  TEXT_CHANNEL_ANNOUNCE = 0;
  TEXT_CHANNEL_NOW_APPEARING = 1;
type
  TVideoSyncTrack = packed record
    Alpha: byte;
    Time: single;
    FrameRate: byte;
    TimeToOut: single;
    flags: byte;
    vuL,vuR: byte;
    trigger: byte;
    FileName: array[0..512] of ansichar;
    procedure SetFileName(value: string);
  end;

  TVideoSyncPacket = packed record
    typ: byte;
    SequenceNumber: int64;
    tracknum: byte;
    activetrack: byte;
    activeoverlay: byte;
    vuL,vuR: byte;
    tr: array[0..0] of TVideoSyncTrack;
  end;

  TVideoAudioInfoPacket = packed record
    typ: byte;
    SequenceNumber: int64;
    tracknum: byte;
    trigger: byte;
    vuL,vuR: byte;
  end;



implementation

{ TVideoSyncPacket }


{ TVideoSyncTrack }

procedure TVideoSyncTrack.SetFileName(value: string);
var
  s: ansistring;
  p: PByte;
begin
  s := ansistring(value);
  p := @s[1];
  if p = nil then
    filename[0] := #0
  else
    movemem32(@filename[0], @s[1], length(s)+1);

end;

end.
