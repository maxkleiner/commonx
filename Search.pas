unit Search;

interface

uses
  typex, classes, sysutils;


type
  TBinarySearchOp = (bsoTest, bsoResult, bsoNoResult);
  TBinarySearchFunctionEval = function(test: int64; data: pointer; op: TBinarySearchOp): nativeint;
  TBinarySearchFunctionEvalOfObject = function(test: int64; op: TBinarySearchOp): int64 of object;

function BinarySearch(func: TBinarySearchFunctionEVal; data: pointer; out res: TBinarySearchOp): nativeint;overload;
function BinarySearch(func: TBinarySearchFunctionEValOfObject; out res: TBinarySearchOp): int64;overload;
function BinarySearchStringList(sl: TStringlist; sFor: string; bIgnoreCase: boolean = false): int64;


implementation

function BinarySearchStringList(sl: TStringlist; sFor: string; bIgnoreCase: boolean = false): int64;
var
  ipos: nativeint;
  finalIdx, testIdx: int64;
  iTemp: nativeint;
begin
  iPos := 63;
  ipos := 0;
  var cnt := sl.count;
  testIdx := 0;
  finalIdx := 0;

  for iPos := 63 downto 0 do begin
    testIdx :=   finalIdx or (1 shl iPos);//propose to add a bit to the index

    //if index in range
    if testIdx < cnt then begin //Never put a 1 in for indexes greater than the count
      //if search > testcase, keep value
      if bIgnoreCase then
        iTemp := CompareText(sFor, sl[testIdx])
      else
        iTemp := CompareStr(sFor, sl[testIdx]);

      if itemp >= 0 then
        finalIdx := testIdx;

      if itemp = 0 then
        exit(finalIdx);


    end;
  end;

  if bIgnoreCase then
    iTemp := CompareText(sFor, sl[finalIdx])
  else
    iTemp := CompareStr(sFor, sl[finalIdx]);


  if iTemp = 0 then
    exit(finalIdx);

  exit(-1);

end;

function BinarySearch(func: TBinarySearchFunctionEVal; data: pointer; out res: TBinarySearchOp): nativeint;
var
  ipos: nativeint;
  test: int64;
  iTemp: nativeint;
begin
  iPos := 63;
  result := 0;
  res := bsoNoResult;

  for iPos := 63 downto 0 do begin
    test :=   result or (1 shl iPos);
    iTemp := func(test,data, bsoTest);
    //if the function reports that the value is LOW then
    if iTemp < 0 then
      //put a 1 in the result position
      result := result or test;

    //if we're dead on, break
    if iTemp = 0 then begin
      func(test, data, bsoResult);
      result := test;
      res := bsoResult;
      exit;
    end;
  end;

  //no rsult
  result := -1;
  func(test, data, bsoNoResult);








end;

function BinarySearch(func: TBinarySearchFunctionEValOfObject; out res: TBinarySearchOp): int64;
var
  ipos: nativeint;
  test: int64;
  iTemp: nativeint;
begin
  iPos := 63;
  result := 0;
  res := bsoNoResult;

  for iPos := 62 downto -1 do begin
    if iPos < 0 then
      test := 0
    else
      test :=   result or ((int64(1) shl int64(iPos)));
    iTemp := func(test, bsoTest);
    //if the function reports that the value is LOW then
    if iTemp < 0 then
      //put a 1 in the result position
      result := result or test;

    //if we're dead on, break
    if iTemp = 0 then begin
      func(test, bsoResult);
      res := bsoResult;
      result := test;
      exit;
    end;
  end;

  //no result
  result := -1;
  func(test, bsoNoResult);


end;


end.
