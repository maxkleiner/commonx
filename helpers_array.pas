unit helpers_array;

interface

uses
  sysutils, types, typex;

type
  TArray_Helper = class
    class procedure SortAnon<T>(var a: TArray<T>; CompareProc_1isAgtB: TFunc<T,T,ni>);
    class function SortAnon_Bubble<T>(var a: TArray<T>; CompareProc_1isAgtB: TFunc<T,T,ni>): boolean;
    class procedure SortAnon_Quick<T>(var a: TArray<T>; CompareProc_1isAgtB: TFunc<T,T,ni>;iLo,iHi: ni);
    class procedure Delete<T>(var a: TArray<T>; idx: nativeint);
    class procedure Add<T>(var a:TArray<T>; tt: T);
    class procedure Move<T>(var a: TArray<T>; fromidx, toidx: nativeint);
    class procedure Insert<T>(var s: TArray<T>; idx: nativeint; elem: T);
    class procedure Remove<T>(var a: TArray<T>; ref: T; eq:TFunc<T,T,boolean>);
    class function IndexOf<T>(var a: Tarray<T>; ref: T; eq:TFunc<T,T,boolean>):nativeint;
  end;

implementation

{ TArray_Helper }

class procedure TArray_Helper.Add<T>(var a: TArray<T>; tt: T);
begin
  setlength(a,length(a)+1);
  a[high(a)] := tt;

end;

class procedure TArray_Helper.Delete<T>(var a: TArray<T>; idx: nativeint);
begin
  for var tt := idx to high(a)-1 do
    a[tt] := a[tt+1];

  setlength(a,length(a)-1);

end;

class function TArray_Helper.IndexOf<T>(var a: Tarray<T>; ref: T; eq:TFunc<T,T,boolean>): nativeint;
begin
  for var tt:= 0 to high(a) do begin
    if eq(ref,a[tt]) then begin
      exit(tt);
    end;
  end;
  exit(-1);
end;

class procedure TArray_Helper.Insert<T>(var s: TArray<T>; idx: nativeint;
  elem: T);
begin
  setlength(s,length(s)+1);
  for var tt := idx+1 to high(s) do begin
    s[tt] := s[tt-1];
  end;
  s[idx] := elem;

end;

class procedure TArray_Helper.Move<T>(var a: TArray<T>; fromidx,
  toidx: nativeint);
begin
  var element := a[fromidx];
  TArray_Helper.Delete<T>(a,fromidx);
  TArray_Helper.Insert<T>(a,toidx,element);
end;

class procedure TArray_Helper.Remove<T>(var a: TArray<T>; ref: T; eq:TFunc<T,T,boolean>);
begin
  var i := TArray_Helper.IndexOf<T>(a,ref,eq);
  if i >=0 then
    TArray_Helper.Delete<T>(a,i);

end;

class procedure TArray_Helper.SortAnon<T>(var a: TArray<T>; CompareProc_1isAgtB: TFunc<T, T, ni>);
begin
  if low(a)=high(a) then
    exit;
  SortAnon_Quick<T>(a,CompareProc_1isAgtB,low(a),high(a));
end;

class function TArray_Helper.SortAnon_Bubble<T>(var a: TArray<T>;
  CompareProc_1isAgtB: TFunc<T, T, ni>): boolean;
begin
  var solved := true;
  result := false;
  repeat
    solved := true;

    for var tt:= 0 to high(a)-1 do begin
      var comp := CompareProc_1isAgtB(a[tt], a[tt+1]);
      if comp > 0 then begin
        var c := a[tt];
        a[tt] := a[tt+1];
        a[tt+1] := c;
        solved := false;
        result := true;
      end;
    end;

  until solved;


end;

class procedure TArray_Helper.SortAnon_Quick<T>(var a: TArray<T>;
  CompareProc_1isAgtB: TFunc<T, T, ni>; iLo, iHi: ni);
var
   Lo, Hi: ni;
  TT,Pivot: T;
begin
   Lo := iLo;
   Hi := iHi;
   var pvtIDX := (Lo + Hi) shr 1;
   if pvtIDX > high(a) then
    exit;
   Pivot := A[pvtIDX];
   repeat
      while CompareProc_1isAgtB(a[lo],pivot) < 0 do
        begin
          inc(lo);
          if lo > high(a) then break;
        end;
      while CompareProc_1isAgtB(a[hi],pivot) > 0 do
        begin
          dec(hi);
          if hi < 0 then break;
        end;
      if Lo <= Hi then
      begin
        TT := A[Lo];
        A[Lo] := A[Hi];
        A[Hi] := TT;
        Inc(Lo) ;
        Dec(Hi) ;
      end;
   until Lo > Hi;
   if Hi > iLo then SortAnon_Quick<T>(A, CompareProc_1isAgtB, iLo, Hi) ;
   if Lo < iHi then SortAnon_Quick<T>(A, CompareProc_1isAgtB, Lo, iHi) ;
end;


end.
