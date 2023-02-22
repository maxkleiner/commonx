unit SysUsageTypes;

interface


uses
  types;

type
  TPointlessLargeIntegerStruct = record
    case Integer of
    0: (
      LowPart: DWORD;
      HighPart: Longint);
    1: (
      QuadPart: Int64);
  end;

  TCPUUSage = record
    liIdleTime: TPointlessLargeIntegerStruct;
    liSystemTime: TPointlessLargeIntegerStruct;
    liActiveTime: TPointlessLargeIntegerStruct;
    deltaIdleTime: double;
    deltaSystemTime: double;

    usage: double;
    max: double;
    procedure init;
  end;

function Li2Double(x: TPointlessLargeIntegerStruct): Double;


implementation



function Li2Double(x: TPointlessLargeIntegerStruct): Double;
begin
  Result := x.HighPart * 4.294967296E9 + x.LowPart
end;

procedure TCPUUSage.init;
begin
  self.liIdleTime.QuadPart := 0;
  self.liSystemTime.QuadPart := 0;
  Self.max := 0.0;
  self.usage := 0.0;


end;


end.
