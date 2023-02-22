unit PerfMessage;
{$I DelphiDefs.inc}
interface

uses
{$IFDEF NEED_FAKE_ANSISTRING}
  ios.stringx.iosansi,
{$ENDIF}
  stringx, typex, systemx, numbers, sysutils, tickcount;

{

  [Network] ---> [VD] ----> [Cache]  ---> Payload  ---> Cache  ---> Physical
                                    |---> Payload  ---> Cache  ---> Physical
                                    |---> Payload  ---> Cache  ---> Physical
                  |---> [ARchive]



[Node Types]
[0] Network
[1] VD
[2] VDCache
[3] Payload
[4] PCache
[5] Physcial
[6] Archiver Queue
[7] Archiver


Output is basically an array on nodes... each node with an upstream and a count


}

const
  MT_PERFORMANCE_DATA=0;
  MT_DESCRIPTORS=1;

  NT_UNALLOCATED = 0;
  NT_IO = 1;
  NT_BUCKETFILL = 1;
  NT_CYCLES = 2;
  NT_CPU_OVERALL = 3;
  NT_CPU = 4;
  NT_DISK = 5;
  NT_NIC = 6;
  NT_RAM = 7;

  FLAGMASK = $B0;
  TYPMASK=$3f;


type
  TPerfNode = packed record
  public
    id: smallint;
    Ftyp: byte;
    Fr: int64;
    Fw: int64;
    procedure Init;
  private
    function GetType: byte;inline;
    procedure SetType(const Value: byte);inline;
    function GetBusyR: boolean;inline;
    procedure SetBusyR(const Value: boolean);inline;
    procedure SetR(const Value: int64);inline;
    procedure SetW(const Value: int64);inline;
    function GetBusyW: boolean;
    procedure SetBusyW(const Value: boolean);
  public
    property typ: byte read GetType write SetType;
    property busyR: boolean read GetBusyR write SetBusyR;
    property busyW: boolean read GetBusyW write SetBusyW;
    property r: int64 read Fr write SetR;
    property w: int64 read Fw write SetW;
    procedure incw(by: int64);inline;
    procedure incr(by: int64);inline;
    function percent: double;

  end;
  PPerfNode = ^TPerfNode;
  TPerfNodeEx = packed record
    received: ticker;
    node: TPerfNode;
  end;

  TPerfDescriptor = packed record
  public
    id: smallint;
    left: smallint;
    above: smallint;
  private
    Fdesc: array[0..64] of ansichar;
    function GetDesc: string;
    procedure SetDesc(const Value: string);
  public
    property Desc: string read GetDesc write SetDesc;
    procedure Init;
  end;
  PPerfDescriptor = ^TPerfDescriptor;

  TPerfHandle = record
  private
    function getID: ni;
    procedure setid(const Value: ni);
  public
    node: PPerfNode;
    desc: PPerfDescriptor;
    property id: ni read getID write setid;
  end;

  TPerfMessageHeader = packed record
    zero: byte;
    Fcomputername: array[0..15] of ansichar;
    processid: int64;
    ticker: int64;
    startnode: smallint;
    nodesinmessage: smallint;
    totalnodes: smallint;
    mtyp: byte;

  private
    function GetComputerName: string;
    procedure SetComputername(const Value: string);
  public
    procedure Init;
    property ComputerName: string read GetComputerName write SetComputername;
  end;


implementation

{ TPerfDescriptor }

function TPerfDescriptor.GetDesc: string;
var
  ss: AnsiString;
begin
  var s: PAnsiChar := @Fdesc[0];
  if s = nil then
    exit('');
  ss := AnsiString(StrPasEx(s));
  result := string(ss);

end;

procedure TPerfDescriptor.Init;
begin
  fillmem(@self, sizeof(self), 0);
  id := -1;
  left := -1;
  above := -1;
end;

procedure TPerfDescriptor.SetDesc(const Value: string);
begin

  var lastidx := lesserof(length(value),length(FDesc))-1;
  for var t := 0 to lastidx do begin
    FDesc[t] := ansichar(value[t+STRZ]);
  end;


  FDesc[lesserof(lastidx+1, high(FDesc))] := #0;


end;

{ TPerfNode }

function TPerfNode.GetBusyR: boolean;
begin
  result := BitGet(@FTyp, 7);
end;

function TPerfNode.GetBusyW: boolean;
begin
  result := BitGet(@FTyp, 6);
end;

function TPerfNode.GetType: byte;
begin
  result := FTyp and TYPMASK;
end;

procedure TPerfNode.incr(by: int64);
begin
  inc(Fr, by);
  BusyR := false;
end;

procedure TPerfNode.incw(by: int64);
begin
  inc(Fw, by);
  BusyW := false;

end;

procedure TPerfNode.Init;
begin
  fillmem(@self, sizeof(self), 0);
  id := -1;
end;

function TPerfNode.percent: double;
begin
  if w= 0 then
    exit(0);
  result := r/w;
end;

procedure TPerfNode.SetBusyR(const Value: boolean);
begin
  BitSet(@Ftyp, 7, value);

end;

procedure TPerfNode.SetBusyW(const Value: boolean);
begin
  BitSet(@Ftyp, 6, value);

end;

procedure TPerfNode.SetR(const Value: int64);
begin
  Fr := Value;
  Ftyp := fTyp and TYPMASK;
end;

procedure TPerfNode.SetType(const Value: byte);
begin
  FTyp := (FTyp and FLAGMASK) or (value and TYPMASK);

end;

procedure TPerfNode.SetW(const Value: int64);
begin
  Fw := Value;
  Ftyp := fTyp and TYPMASK;
end;

{ TPerfHandle }

function TPerfHandle.getID: ni;
begin
  if node = nil then
    exit(-1);
  result := node.id;
end;

procedure TPerfHandle.setid(const Value: ni);
begin
  if node = nil then
    raise Ecritical.create('cannot set id of nil node');

  node.id := value;
  desc.id := value;


end;

{ TPerfMessageHeader }

function TPerfMessageHeader.GetComputerName: string;
begin
{$IFDEF NEED_FAKE_ANSISTRING}
  setlength(result, length(FComputerName));
  fillmem(@result[low(result)], length(result)*sizeof(char), 0);

  var outidx := 0;
  while outidx < length(FComputerName) do begin
    result[STRZ+outidx] := char(FComputername[outidx]);
  end;
{$ELSE}
  result := string(Fcomputername);
{$ENDIF}
end;

procedure TPerfMessageHeader.init;
begin
  zero := 0;
  FillMem(@Fcomputername[0], length(Fcomputername), 0);
end;

procedure TPerfMessageHeader.SetComputername(const Value: string);
var
  astr: ansistring;
begin
  astr := ansistring(value);
{$IFDEF NEED_FAKE_ANSISTRING}
  movemem32(@Fcomputername[0], astr.addrof[STRZ], lesserof(length(astr)+1, length(Fcomputername)));
{$ELSE}
  movemem32(@Fcomputername[0], @astr[low(astr)], lesserof(length(astr)+1, length(Fcomputername)));
{$ENDIF}


end;

end.
