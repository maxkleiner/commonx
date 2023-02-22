unit better_collections;
{$MESSAGE '*******************COMPILING Better_Collections.pas'}
{$INCLUDE DelphiDefs.inc}
{$IFDEF MSWINDOWS}
{$DEFINE USE_FAST_LIST}
{$ENDIF}
{$DEFINE DEBUG_ITEMS}
{$D+}
interface


uses
  debug, generics.collections.fixed, systemx, sharedobject, typex, betterobject, classes,


{$IFDEF USE_FAST_LIST}
  fastlist,
{$ENDIF}
  sysutils;

type
{$IFDEF USE_FAST_LIST}
  TBetterList<T: class> = class(TFastList<T>)
{$ELSE}
  TBetterList<T: class> = class(TList<T>)
{$ENDIF}
  private
    FOwnsObjects: boolean;
    function GetLastItem: T;
  public
    type TStoppableIterateProc = reference to procedure (a: T; var bStop: boolean);
    constructor Create;reintroduce;virtual;
    function Has(obj: T): boolean;
    procedure ClearandFree;
    procedure Replace(old, nu: T);
    procedure BetterRemove(obj: T);
    procedure AddList(list: TBetterList<T>);
    procedure AddListSorted(list: TBetterList<T>;CompareProc_1isAgtB: TFunc<T,T, ni>);
    property LastItem: T read GetLastItem;
    function SortAnon(CompareProc_1isAgtB: TFunc<T,T, ni>): boolean;
    function SortAnonMT(CompareProc_1isAgtB: TFunc<T,T, ni>): boolean;
    function SortAnon_Bubble(CompareProc_1isAgtB: TFunc<T,T,ni>): boolean;
    procedure SortAnon_Quick(CompareProc_1isAgtB: TFunc<T,T,ni>;iLo,iHi: ni);

    property OwnsObjects: boolean read FOwnsObjects write FOwnsObjects;
    procedure Iterate(p: TProc<T>);overload;
    procedure Iterate(p: TStoppableIterateProc);overload;
    function SplitintoEqualParts(cnt: ni): TArray<IHolder<TBetterList<T>>>;


  end;

  TBetterStack<T: class> = class(TStack<T>)
  private
    function GetTop: T;
  public
    property Top: T read GetTop;
  end;

  TSharedList<T: class> = class(TSharedObject)
  private
    FOwnsObjects: boolean;
    function GEtItem(idx: nativeint): T;
    procedure SetItem(idx: nativeint; const Value: T);
  protected
    FList: TBetterList<T>;
    FVolatileCount: ni;
    function GetCount: nativeint;virtual;
  public

    RestrictedtoThreadID: nativeuint;
    constructor Create;override;
    destructor Destroy;override;

    function Add(obj: T): nativeint;virtual;
    procedure AddList(l: TSharedList<T>);virtual;
    procedure Delete(idx: nativeint);virtual;
    procedure Remove(obj: T);virtual;
    procedure BetterRemove(obj: T);

    procedure Insert(idx: ni; obj: T);virtual;

    property Count: nativeint read GetCount;
    function IndexOf(obj: T): nativeint;virtual;
    function Has(obj: T): boolean;virtual;
    property Items[idx: nativeint]: T read GEtItem write SetItem;default;
    procedure Clear;
    procedure FreeAndClear;
    property VOlatileCount: ni read FVolatileCount;
    property OwnsObjects: boolean read FOwnsObjects write FOwnsObjects;
  end;

  TSharedStringList = class(TSharedObject)
  strict private
    FList: TStringList;
  private
    function GetItem(idx: ni): string;
    procedure Setitem(idx: ni; const Value: string);
    function GetText: string;
    procedure SetText(const Value: string);
    function GetCount: ni;
  public
    constructor Create; override;
    destructor Destroy; override;

    property Text: string read GetText write SetText;
    procedure Add(s: string);
    procedure Remove(s: string);
    property Items[idx: ni]: string read GetItem write Setitem;default;
    procedure Delete(i: ni);
    function IndexOf(s: string): ni;
    property Count: ni read GetCount;
    procedure Clear;
    function GetStringList_UseOnlyUnderLock: TStringlist;
  end;



  TStringObjectList<T_OBJECTTYPE: class> = class(TBetterObject)
  strict private
    FItems: TStringlist;
  private

    FTakeOwnership: boolean;
    FDuplicates: TDuplicates;
    function GetItem(sKey: string): T_OBJECTTYPE;
    procedure SetItem(sKey: string; const Value: T_OBJECTTYPE);
    function GetKey(idx: ni): string;
    function GetItemByIndex(idx: ni): T_ObjectType;
  public
    enable_debug: boolean;
    procedure Add(sKey: string; obj: T_OBJECTTYPE);
    procedure Clear;
    procedure Delete(i: ni);
    procedure Remove(o: T_OBJECTTYPE);
    function IndexOfKey(sKey: string): ni;
    function IndexOfObject(o: T_OBJECTTYPE): ni;
    function Count: ni;

    procedure Init; override;
    constructor Create; override;
    destructor Destroy; override;
    property Items[sKey: string]: T_OBJECTTYPE read GetItem write SetItem;default;
    property ItemsByIndex[idx: ni]: T_ObjectType read GetItemByIndex;
    property Keys[idx: ni]: string read GetKey;
    property TakeOwnership: boolean read FTakeOwnership write FTakeOwnership;
    property Duplicates: TDuplicates read FDuplicates write FDuplicates;

    procedure DebugItems;

  end;


implementation

{$IFDEF DEBUG_ITEMS}
uses
  JSONHelpers, AnonCommand;
{$ENDIF}

{ TBetterList<T> }

procedure TBetterList<T>.AddList(list: TBetterList<T>);
var
  t: ni;
begin
  for t := 0 to list.count-1 do begin
    self.Add(list[t]);
  end;

end;

procedure TBetterList<T>.AddListSorted(list: TBetterList<T>;
  CompareProc_1isAgtB: TFunc<T, T, ni>);
begin
  var a := Self.SplitintoEqualParts(1);
  var tl := a[0].o;
  var cx := list.count + tl.count;
  var ix1, ix2: ni;
  ix1 := 0;
  ix2 := 0;
  self.clear;
  while cx > 0 do begin
    var comp := 0;
    if ix1 > tl.count then
      comp := -1
    else
    if ix2 > list.count then
      comp := 1
    else
      comp := CompareProc_1isAgtB(tl[ix1],list[ix2]);
    if comp<0 then begin
      self.add(tl[ix1]);
      inc(ix1);
    end else begin
      self.add(list[ix2]);
      inc(ix2);
    end;
  end;
end;

procedure TBetterList<T>.BetterRemove(obj: T);
var
  t: ni;
begin
  for t:= count-1 downto 0 do begin
    if items[t] = obj then
      delete(t);
  end;

end;



procedure TBetterList<T>.ClearandFree;
var
  o: T;
begin
  while count > 0 do begin
    o := items[0];
    remove(items[0]);
    o.free;
    o := nil;

  end;

end;

constructor TBetterList<T>.Create;
begin
  inherited;
end;

function TBetterList<T>.GetLastItem: T;
begin
  result := self[self.count-1];
end;

function TBetterList<T>.Has(obj: T): boolean;
begin
  result := IndexOf(obj) >= 0;
end;


procedure TBetterList<T>.Iterate(p: TStoppableIterateProc);
begin
  var stop := false;
  for var t := 0 to count-1 do begin
    p(self[t],stop);
    if stop then
      break;
  end;

end;

procedure TBetterList<T>.Iterate(p: TProc<T>);
begin
  for var t := 0 to count-1 do begin
    p(self[t]);
  end;
end;

procedure TBetterList<T>.Replace(old, nu: T);
var
  t: ni;
begin
  for t:= 0 to count-1 do begin
    if Self.Items[t] = old then
      self.items[t] := nu;
  end;
end;

function TBetterList<T>.SortAnon(CompareProc_1isAgtB: TFunc<T, T, ni>): boolean;
begin
  //Todo 1: implement Sort() in TBetterList with something better than a bubble sort
  result := true;
  SortAnon_Quick(CompareProc_1isAgtB,0,count-1);
end;


function TBetterList<T>.SortAnonMT(
  CompareProc_1isAgtB: TFunc<T, T, ni>): boolean;
var
  a: TArray<IHolder<TBetterList<T>>>;
begin
  var cpus := GetNumberOfLogicalProcessors;
  a := Self.SplitintoEqualParts(cpus);
  ForX(0,length(a),1, procedure (idx: int64) begin
    a[idx].o.SortAnon(CompareProc_1isAgtB);
  end);

  while length(a) > 1 do begin
    ForX(0,length(a) shr 1,1, procedure (idx: int64) begin
      var iix := idx * 2;
      if iix < high(a) then begin
        a[iix].o.AddListSorted(a[iix+1].o,Compareproc_1isAgtB);
      end;
    end);
    //remove odd numbered lists
    var last := 0;
    for var tt := 0 to high(a) do begin
      if (tt and 1) = 0 then begin
        last := tt shr 1;
        a[last] := a[tt];
      end;
    end;
    setlength(a,last+1);
  end;



end;

function TBetterList<T>.SortAnon_Bubble(CompareProc_1isAgtB: TFunc<T, T, ni>): boolean;
var solved: boolean;
//returns TRUE if anything changed, else FALSE if already sorted
begin
  result := false;
  repeat
    solved := true;

    for var t:= 0 to count-2 do begin
      var comp := CompareProc_1isAgtB(items[t], items[t+1]);
      if comp > 0 then begin
        var c := items[t];
        items[t] := items[t+1];
        items[t+1] := c;
        solved := false;
        result := true;
      end;
    end;

  until solved;

end;

procedure TBetterList<T>.SortAnon_Quick(CompareProc_1isAgtB: TFunc<T, T, ni>; iLo, iHi: ni);
var
   Lo, Hi: ni;
  TT,Pivot: T;
begin
   Lo := iLo;
   Hi := iHi;
   var pvtIDX := (Lo + Hi) shr 1;
   if pvtIDX > (self.Count-1) then
    exit;
   Pivot := self[pvtIDX];
   repeat
      while CompareProc_1isAgtB(self[lo],pivot) < 0 do
        begin
          inc(lo);
          if lo > (count-1) then break;
        end;
      while CompareProc_1isAgtB(self[hi],pivot) > 0 do
        begin
          dec(hi);
          if hi < 0 then break;
        end;
      if Lo <= Hi then
      begin
        TT := self[Lo];
        self[Lo] := self[Hi];
        self[Hi] := TT;
        Inc(Lo) ;
        Dec(Hi) ;
      end;
   until Lo > Hi;
   if Hi > iLo then SortAnon_Quick(CompareProc_1isAgtB, iLo, Hi) ;
   if Lo < iHi then SortAnon_Quick(CompareProc_1isAgtB, Lo, iHi) ;
end;

function TBetterList<T>.SplitintoEqualParts(cnt: ni): TArray<IHolder<TBetterList<T>>>;
begin
  var chunksize := (count div cnt)+1;
  setlength(result, cnt);
  for var tt:= 0 to cnt-1 do begin
    result[tt] := THolder<TBetterList<T>>.create(TBetterList<T>.create());
  end;

  var cx := chunksize;
  var idx := 0;
  for var x := 0 to count-1 do begin
    result[idx].o.add(self[idx]);
    dec(cx);
    if (cx = 0) then begin
      cx := chunksize;
      if idx < high(result) then
        inc(idx);
    end;
  end;




end;

{ TSharedList<T> }

{$MESSAGE '*******************1 COMPILING Better_Collections.pas'}
function TSharedList<T>.Add(obj: T): nativeint;
begin
  if (RestrictedtoThreadID <> 0) and (TThread.CurrentThread.ThreadID <> RestrictedToThreadID) then
{$IFDEF STRICT_THREAD_ENFORCEMENT}
    raise Ecritical.create(self.ClassName+' is restricted to thread #'+RestrictedToThreadID.ToString+' but you are accessing it from #'+TThread.CurrentThread.ThreadID.tostring);
{$ELSE}
    Debug.Log(CLR_ERR+self.ClassName+' is restricted to thread #'+RestrictedToThreadID.ToString+' but you are accessing it from #'+TThread.CurrentThread.ThreadID.tostring);
{$ENDIF}
  Lock;
  try
    result := FList.add(obj);
    FVolatileCount := FList.count;
  finally
    Unlock;
  end;
end;
{$MESSAGE '*******************2 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.AddList(l: TSharedList<T>);
var
  x: nativeint;
begin
  if (RestrictedtoThreadID <> 0) and (TThread.CurrentThread.ThreadID <> RestrictedToThreadID) then
    raise Ecritical.create(self.ClassName+' is restricted to thread #'+RestrictedToThreadID.ToString+' but you are accessing it from #'+TThread.CurrentThread.ThreadID.tostring);
  l.Lock;
  try
    Lock;
    try
      for x := 0 to l.count-1 do begin
        self.Add(l[x]);
      end;
    finally
      Unlock;
    end;
  finally
    l.Unlock;
  end;
end;

{$MESSAGE '*******************3 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.BetterRemove(obj: T);
begin
  Remove(obj);
end;

{$MESSAGE '*******************4 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.Clear;
begin
  Lock;
  try
    FList.Clear;
    FVolatileCount := FList.count;
  finally
    Unlock;
  end;
end;

{$MESSAGE '*******************5 COMPILING Better_Collections.pas'}
constructor TSharedList<T>.Create;
{$MESSAGE '*******************5.1 COMPILING Better_Collections.pas'}
begin
  {$MESSAGE '*******************5.2 COMPILING Better_Collections.pas'}
  inherited;
  {$MESSAGE '*******************5.3 COMPILING Better_Collections.pas'}
  FList := TBetterList<T>.create();
  {$MESSAGE '*******************5.4 COMPILING Better_Collections.pas'}
end;
{$MESSAGE '*******************5 COMPILING Better_Collections.pas'}

{$MESSAGE '*******************6 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.Delete(idx: nativeint);
begin
  Lock;
  try
    FList.Delete(idx);
    FVolatileCount := FList.count;
  finally
    Unlock;
  end;
end;

{$MESSAGE '*******************7 COMPILING Better_Collections.pas'}
destructor TSharedList<T>.Destroy;
begin
  if OwnsObjects then begin
    while FList.count > 0 do begin
      FList[FList.count].free;
      FList.delete(FList.count);
    end;
  end;
  FList.free;
  FList := nil;
  inherited;
end;

procedure TSharedList<T>.FreeAndClear;
begin
  while count > 0 do begin
    items[count-1].free;
    delete(count-1);
  end;
end;

{$MESSAGE '*******************8 COMPILING Better_Collections.pas'}
function TSharedList<T>.GetCount: nativeint;
begin
  Lock;
  try
    result := FList.count;
  finally
    Unlock;
  end;
end;

{$MESSAGE '*******************9 COMPILING Better_Collections.pas'}
function TSharedList<T>.GEtItem(idx: nativeint): T;
begin
  lock;
  try
    result := FList[idx];
  finally
    Unlock;
  end;
end;

function TSharedList<T>.Has(obj: T): boolean;
begin
  result := IndexOf(obj) >=0;
end;

{$MESSAGE '*******************10 COMPILING Better_Collections.pas'}
function TSharedList<T>.IndexOf(obj: T): nativeint;
begin
  Lock;
  try
    result := FList.IndexOf(obj);
  finally
    Unlock;
  end;

end;

{$MESSAGE '*******************11 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.Insert(idx: ni; obj: T);
begin
  Lock;
  try
    FList.Insert(idx, obj);
    FVolatileCount := FList.count;
  finally
    unlock;
  end;

end;

{$MESSAGE '*******************12 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.Remove(obj: T);
begin
  Lock;
  try
    FList.BetterRemove(obj);
    FVolatileCount := FList.count;
  finally
    Unlock;
  end;
end;


{$MESSAGE '*******************13 COMPILING Better_Collections.pas'}
procedure TSharedList<T>.SetItem(idx: nativeint; const Value: T);
begin
  lock;
  try
    FLIst[idx] := value;
  finally
    Unlock;
  end;
end;



{ TBetterStack<T> }

function TBetterStack<T>.GetTop: T;
begin
  result := Peek;
end;

{ TStringObjectList<T_OBJECTTYPE> }

procedure TStringObjectList<T_OBJECTTYPE>.Add(sKey: string; obj: T_OBJECTTYPE);
begin
  case duplicates of
    Tduplicates.dupIgnore: begin

      if FItems.IndexOf(sKey) >=0 then begin
        self[sKey] := obj;
        exit;
      end;
    end;
    Tduplicates.dupError: begin
      raise ECritical.create(classname+' already has item with key '+sKey);
    end;
  end;
  FItems.AddObject(sKey, obj);
  DebugItems();
end;

procedure TStringObjectList<T_OBJECTTYPE>.Clear;
begin
  if takeownership then begin
    while count > 0 do begin
      delete(count-1);
    end;
  end;
  FItems.Clear;

end;

function TStringObjectList<T_OBJECTTYPE>.Count: ni;
begin
  result := FItems.count;
end;

constructor TStringObjectList<T_OBJECTTYPE>.Create;
begin
  inherited;
  FItems := TStringList.create;
  Fitems.CaseSensitive := true;

end;

procedure TStringObjectList<T_OBJECTTYPE>.DebugItems;

var
  t: ni;
begin
{$IFDEF DEBUG_ITEMS}
  if not enable_debug then
    exit;
  Debug.Log('----------------');
  for t:= 0 to FItems.count-1 do begin
    if FItems.Objects[t] is TJSON then begin
      Debug.Log(FItems[t]+' = '+TJSON(FItems.Objects[t]).tojson);
    end;

  end;
{$ENDIF}


end;

procedure TStringObjectList<T_OBJECTTYPE>.Delete(i: ni);
begin
  if takeownership then
    FItems.objects[i].free;
  FItems.Delete(i);
end;

destructor TStringObjectList<T_OBJECTTYPE>.Destroy;
begin
  Clear;
  FItems.free;
  FItems := nil;
  inherited;
end;

function TStringObjectList<T_OBJECTTYPE>.GetItem(sKey: string): T_OBJECTTYPE;
var
  i: ni;
begin
  i := IndexofKey(sKey);
  result := nil;
  if i >=0 then
    result := T_OBJECTTYPE(FItems.Objects[i])
  else
    raise ECritical.create('no object named '+sKey+' was found in '+self.ClassName);

end;

function TStringObjectList<T_OBJECTTYPE>.GetItemByIndex(idx: ni): T_ObjectType;
begin
  result := T_OBJECTTYPE(FItems.Objects[idx]);
end;

function TStringObjectList<T_OBJECTTYPE>.GetKey(idx: ni): string;
begin
  result := FItems[idx];
end;

function TStringObjectList<T_OBJECTTYPE>.IndexOfKey(sKey: string): ni;
begin
  result := FItems.IndexOf(sKey);

end;

function TStringObjectList<T_OBJECTTYPE>.IndexOfObject(o: T_OBJECTTYPE): ni;
begin
  result := FItems.IndexOfObject(o);

end;

procedure TStringObjectList<T_OBJECTTYPE>.Init;
begin
  inherited;

end;

procedure TStringObjectList<T_OBJECTTYPE>.Remove(o: T_OBJECTTYPE);
var
  i: ni;
begin
  i := FItems.IndexOfObject(o);
  if i >=0 then begin
    Delete(i);
  end;



end;

procedure TStringObjectList<T_OBJECTTYPE>.SetItem(sKey: string;
  const Value: T_OBJECTTYPE);
var
  i: ni;
begin
  i := Fitems.IndexOf(sKey);
  if i >= 0 then
    FItems.Objects[i] := value;
end;

{ TSharedStringList }

procedure TSharedStringList.Add(s: string);
var
  l : ILock;
begin
  l := self.LockI;
  FList.add(s);
end;

procedure TSharedStringList.Clear;
var
  l: ILock;
begin
  l := self.locki;
  FList.clear;

end;

constructor TSharedStringList.Create;
begin
  inherited;
  FList := TStringlist.create;
end;

procedure TSharedStringList.Delete(i: ni);
var
  l: ILock;
begin
  l := self.LockI;
  FList.delete(i);
end;

destructor TSharedStringList.Destroy;
begin
  FList.free;
  inherited;
end;

function TSharedStringList.GetCount: ni;
var
  l: ILock;
begin
  l := self.locki;
  result := FList.count;

end;

function TSharedStringList.GetItem(idx: ni): string;
var
  l: ILock;
begin
  l := self.LockI;
  result := FList[idx];
end;

function TSharedStringList.GetStringList_UseOnlyUnderLock: TStringlist;
begin
  result := FList;
end;

function TSharedStringList.GetText: string;
var
  l: ILock;
begin
  l := self.LockI;
  result := Flist.Text;
end;

function TSharedStringList.IndexOf(s: string): ni;
var
  l: ILock;
begin
  l := self.LockI;
  result := Flist.IndexOf(s);

end;

procedure TSharedStringList.Remove(s: string);
var
  l: ILock;
  i: ni;
begin
  l := self.LockI;
  i := FList.IndexOf(s);
  if i>=0 then
    FList.delete(i);

end;

procedure TSharedStringList.Setitem(idx: ni; const Value: string);
var
  l: ILock;
begin
  l := self.LockI;
  Flist[idx] := value;

end;

procedure TSharedStringList.SetText(const Value: string);
var
  l: ILock;
begin
  l := self.LockI;
  Flist.Text := value;
end;

end.

