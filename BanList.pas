unit BanList;

interface

uses
  debug, better_collections, systemx, typex,stringx, betterobject, generics.collections, numbers, sysutils, tickcount, orderlyinit;

type
  TBanRec = record
    ip: string;
    banUntil: TDateTime;
    violations: integer;
    found: boolean;
  end;



  TBanList = class(TSharedObject)
  private
    list: TList<TBanRec>;
    lastExpirationCheck: ticker;
    function FindBan(sIP: string): TBanRec;
    function FindBanIndex(sIP: string): nativeint;

  public
    constructor Create;override;
    destructor Destroy;override;
    function IsBanned(sIP: string): boolean;
    procedure ExpireBans;
    procedure ExpireBansIfTime;
    procedure Ban(sIP: string);
  end;

var
  BannedIPs: TBanList = nil;

implementation

{ TBanList }

procedure TBanList.Ban(sIP: string);
var
  r: TBanRec;
begin
  var il := self.LockI;
  var idx := FindBanindex(sIP);
  if idx >=0 then begin
    r := list[idx];
    inc(r.violations);
    Debug.Log(r.ip+' has '+r.violations.tostring+' volations');
    r.banUntil := greaterof(now+(1/(24*60)), r.banUntil+(r.violations/(24*60)));
    if r.violations > 3 then begin
      Debug.Log(r.ip+' banned until '+datetimetostr(r.banuntil));
    end;
    list[idx] := r;
  end else begin
    r.found := true;
    r.ip := sIP;
    r.banUntil := now+(1/(24*60));
    r.violations := 1;
    list.add(r);
    Debug.Log(r.ip+' will be banned if continued login attempts fail.');
  end;




end;

constructor TBanList.Create;
begin
  inherited;
  list := TList<TBanRec>.create;
end;

destructor TBanList.Destroy;
begin

  list.free;
  list := nil;
  inherited;
end;

procedure TBanList.ExpireBans;
begin
  var tmStart := GetTicker;
  var il := self.LockI;
  for var t:= list.count-1 downto 0 do begin
    var l := list[t];
    if l.banUntil < now() then begin
      list.delete(t);
    end;
    //optimization... never spend more than 1 second expiring bans....
    //if ban list gets big, this function gets slower... if they're banned... we are in no hurry to unban them
    if GetTimeSince(tmStart) > 1000 then
      break;
  end;
  lastExpirationCheck := getticker;

end;

procedure TBanList.ExpireBansIfTime;
begin
  var il := self.LockI;
  if gettimesince(lastExpirationCheck) > 60000 then
    ExpireBans;

end;

function TBanList.FindBan(sIP: string): TBanRec;
begin
  var il := self.LockI;
  var idx := self.FindBanIndex(sIP);
  result.found := false;
  if idx >=0 then
    result := list[idx];
end;

function TBanList.FindBanIndex(sIP: string): nativeint;
var
  l: TBanRec;
begin
  var il := self.LockI;
  result := -1;
  for var t:= 0 to list.count-1 do begin
    l := list[t];
    if l.ip = sIP then begin
      exit(t);
    end;
  end;

end;

function TBanList.IsBanned(sIP: string): boolean;
var
  banrec: TBanRec;
begin
  banrec := FindBan(sIP);
  result := banrec.found;
  if result then
    result := (banrec.violations > 3);
  ExpireBansIfTime;
end;


procedure oinit;
begin
  BannedIPs := TBanList.create;

end;
procedure ofinal;
begin
  BannedIPs.Free;
  BannedIPs := nil;
end;

initialization
  init.RegisterProcs('BanList',oinit, ofinal,'');


end.
