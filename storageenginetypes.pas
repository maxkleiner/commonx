unit StorageEngineTypes;
{$D-}//causes wierd hiccups in debugger
//DONE: add mysql type for text
//DONE 1: Allow TSERowset to navigate using alternate indexes
//TODO 2: Return boolleans from database properly
//TODO 1: NULL keyword doesn't work
//TODO 1: Implement connection retries to SQL server.
interface

uses
  globalMultiQueue,anoncommand, commandprocessor,debug, betterobject, sqlexpr, sysutils, DB, classes, stringx, systemx, variants, typex, MultiBufferMemoryFileStream, helpers_stream, numbers, btree, JSONHelpers, mysqlstoragestring, mssqlStorageString, better_collections;

const
  SYSTEM_FIELD_COUNT = 1;

type
  TSERowSet = class;//forward

  TAnonRecFilter = reference to procedure (rs: TSERowSet; out accept: boolean; var bbreak: boolean);

  TSECell = variant;
  TSERowVals = array of TSECell;
  TSERow = record
    vals: TSERowVals;
    mods: TTightFlags;
    deletepending: boolean;
    appended: boolean;
    modded: boolean;
  public
    procedure SetWidth(w: ni);
    function GetWidth: ni;
    property width: ni read GetWidth write SetWidth;
    procedure Reset;
    procedure Init;
  end;
  PSERow = ^TSeRow;

  Tbti_Row = class(TBTreeItem)
  protected
    row: TSERow;
    indexfieldIndexes: TArray<nativeint>;
    desc: TArray<Boolean>;
    rownumber: ni;
    function Compare(const [unsafe] ACompareTo: TBTreeItem): NativeInt; override;
  end;


  TQueryList = class(TStringList)
  private
    Fidx: integer;
    function GetEOF: boolean;
  protected
  public
    procedure First;
    property EOF: boolean read GetEOF;
    procedure AddQuery(s: string);
    function GetNextQuery: string;
  end;

  TSERowsetFieldDef = record
    sName: string;
    vType: TFieldType;
  end;

  PSERowsetFieldDef = ^TSERowSetFieldDef;

  TIndexPair = packed record
    value: int64;
    addr: int64;
  end;

  TSEIndexFile = class(TbetterObject)
  private
    function Getitem(idx: int64): TIndexPair;
    function GetCount: int64;
  protected
    fs: TMultiBufferMemoryFileStream;
  public
    procedure Detach;override;
    procedure Close;
    procedure Open(sFile: string; bForWriting: boolean);
    property Items[idx: int64]: TIndexPair read Getitem;
    function AddrOf(val: int64): int64;
    property Count: int64 read GetCount;
  end;


  TRowAction = (raNone, raChange, raDelete);
  TPendingChange = record
    field: string;
    val: variant;
  end;

  TPendingRowAction = record
    action: TRowAction;
    changes: Tarray<TPendingChange>;
  end;


  TSERowSet = class(TSharedObject)
  private
    FBoundToTable: string;
    procedure SetCurRecordFields(sFieldName: string; const Value: variant);
    function GEtFieldDefs(idx: integer): PSERowsetFieldDef;
    procedure SetCurRecordFieldsByIdx(idx: integer; const Value: variant);
    function GetCurRecordFieldsByIdx(idx: integer): variant;
    function GetCurRecordFields(sFieldName: string): variant;
    function GetEOF: boolean;
    function GEtFieldCount: integer;
    function GEtRowCount: integer;
    function GetFieldDef(idx: integer): PSERowsetFieldDef;
    function GetValues(x, y: integer): variant;
    procedure SetValues(x, y: integer; const Value: variant);
    function GetValuesByFieldName(fld: string; y: integer): variant;
    procedure SetValuesByFieldName(fld: string; y: integer; const Value: variant);



  protected
    inMTIterator: boolean;
    FRowset: TArray<TSERow>;
    FFieldDefs: array of TSERowsetFieldDef;
    FCursor: nativeint;
    FIndexValues: array of array of int64;
    FIndexNames: array of string;
    FIndex: integer; //<<--This is the index used to nagivate the rowset via first/next etc.
    FMaintain: TStringlist;
    idxs: array of TMultiBufferMemoryFileStream;
    procedure UpdateRowWidths(iOldCount: integer);
    function GetfieldValue(iRow: nativeint; sFieldName: string): variant;
  public

    constructor Create;override;
    property fields[idx: integer]: PSERowsetFieldDef read GetFieldDef;
    function AddField:PSeRowSetFieldDef;

    function IndexOfField(sName: string): integer;
    function FindValue(sField: string; vValue: variant): ni;
    function FindValue_Presorted(sField: string; vValue: variant): ni;
    function FindValues(aFields: TArray<string>; aValues: TArray<variant>): ni;
    function FindValuesMT(aFields: TArray<string>; aValues: TArray<variant>): ni;
    function FindValueMT(sField: string; vValue: variant): ni;
    function FindValueAfter(iAfterRow: int64; sField: string;
      vValue: variant): ni;


    function SeekValue(sField: string; vValue: variant): boolean;
    function Lookup(sLookupField: string; vLookupValue: variant; sReturnField: string; bNoExceptions: boolean = false): variant;



    procedure Reset(nodelete: boolean);
    procedure SetFieldCount(iCount: integer);
    procedure SetRowCount(iCount: integer);

    property Values[x,y: integer]: variant read GetValues write SetValues;
    property ValuesN[fld: string; y: integer]: variant read GetValuesByFieldName write SetValuesByFieldName;
    property CurRecordFields[sFieldName: string]: variant read GetCurRecordFields write SetCurRecordFields;default;
    property Cur[sFieldName: string]: variant read GetCurRecordFields write SetCurRecordFields;
    property f[sFieldName: string]: variant read GetCurRecordFields write SetCurRecordFields;
    property CurRecordFieldsByIdx[idx: integer]: variant read GetCurRecordFieldsByIdx write SetCurRecordFieldsByIdx;
    property CurI[idx: integer]: variant read GetCurRecordFieldsByIdx write SetCurRecordFieldsByIdx;

    procedure CopyFromDAtaSet(ds: TCustomSQLDataset; bAppend: boolean = false);
    function AddRow: integer;
    function AddRowFirst: integer;
    procedure CancelRow;
    procedure DeleteRow(n: nativeint);

    property FieldDefs[idx: integer]: PSERowsetFieldDef read GEtFieldDefs;
    property FieldValues[iRow: nativeint; sName: string]: variant read GetfieldValue;

    property BoundToTable: string read FBoundToTable write FBoundToTable;
    property RowCount: integer read GEtRowCount;
    property FieldCount: integer read GEtFieldCount;

    procedure First;
    procedure LAst;
    procedure Next;
    procedure Previous;
    property EOF:boolean read GetEOF;
    procedure ApplyRowACtions(a:TArray<TPendingRowAction>);

    function AddBlankIndex(sName: string): integer;
    procedure BuildIndex(sName: string; sFields: string);overload;
    procedure BuildIndex_BUBBLE(sName: string; field_priorities: TArray<nativeint>; desc: TArray<boolean>);overload;
    procedure BuildIndex_BTREE(sName: string; field_priorities: TArray<nativeint>; desc: TArray<boolean>);overload;
    procedure BuildIndex(sName: string; field_priorities: TArray<nativeint>; desc: TArray<boolean>);overload;

    function GetIndexOfIndex(sName: string): integer;
    function IndexCount: integer;

    procedure SetIndex(idx: integer);
    function GetIndexedRow(iOrderIdx: integer): integer;
    property Cursor: nativeint read FCursor write FCursor;
    function ToString: string;override;
    procedure Append(rs: TSERowSet);overload;
    procedure Append(rs: IHolder<TSERowSet>);overload;
    procedure AppendRowFrom(rs: TSERowSet; iRow: ni);
    procedure PrePend(rs: TSERowSet);

    procedure SavetoFile(f: string; bAppend: boolean = false);
    procedure LoadFromfile(f: string; filterfunc: TAnonRecFilter; startAtIndex: string = ''; startAtIndexValue: int64 = 0);
    procedure LoadfromCSV(f: string);
    procedure SavetoCSV(f: string);
    procedure AddrowFromString(s: string);
    function RowToString: string;
    function GetHeaderString: string;
    procedure DefineFromHeaderString(s: string);
    procedure Maintain(sField: string);
    procedure WriteToIndex(sBaseFile: string; bForAppend: boolean; iStartAddr: int64);
    procedure OpenIndexes(sBaseFile: string; bForRead, bForAppend: boolean);
    procedure CloseIndexes;
    function FindSeekInIndex(sBaseFile, sIndex: string; value: int64): int64;
    procedure CopyFieldDefsTo(rs: TSERowSet);
    procedure CopyCurrentRecordTo(rs: TSERowSet);
    procedure CopyRecordFromByName(rs: TSERowSet);
    procedure AddDeltaColumn(sName: string; sSource: string; bSourceIsReverseTime: boolean);
    procedure FromCSV(csv: string; separator: string = ',');
    function ToJSONh: IHolder<TJSON>;
    procedure Clear;
    function ToMYSQLCreateTable(sTableName: string): string;
    function ToMYSQLImport(sTableName: string): string;
    function ToMSSQLImport(sTableName: string): string;
    function RowToMYSQLValues(r: TSERow): string;
    function RowToMSSQLValues(r: TSERow): string;
    function ToMYSQLValues: string;
    function ToMSSQLValues: string;
    property CurrentRecordIndex: nativeint read FCursor write FCursor;//alias
    function GetFieldList: IHolder<TStringlist>;
    function GetValueArray(fields: TDynStringArray): TDynVariantArray;
    function GetValueStringArray(fields: TDynStringArray): TDynStringArray;
    procedure Iterate(p: TProc);overload;
      //iterate through records, single threaded
    procedure IterateReverse(p: TProc);overload;
      //iterate through records, reverse order, single threaded
    procedure Iterate(p: TProc<int64>);overload;
      //iterate through records, single threaded, but with row number passed as parameter
    procedure IterateMT(iMinBatchSize: ni; p: TProc<int64>; opts: TForXOptions = []);overload;
      //iterate Multi-threaded
    procedure IterateMT(iMinBatchSize, iMaxBatchSize: ni; p: TProc<int64>; opts: TForXOptions = []);overload;
      //iterate Multi-threaded, min and max batch size options
    procedure IterateAC(p, commit: TProc<TStringList>; commitThreshold: int64 = 10000);
      //iterate Single-threaded.. Accumulate, commit
    procedure IterateMTAC(iMinBatchSize, iMaxBatchSize: ni; p: TProc<int64, TSharedStringList>; p2: TProc<TSharedStringList>; opts: TForXOptions = []);overload;
      //iterate Multi-threaded.. Accumulate, commit
    procedure IterateMTFAKE(iMinBatchSize: ni; p: TProc<int64>; opts: TForXOptions = []);overload;
      //iterate Single-Threaded, but with the same params as multi-threaded... useful for debugging, or if MT breaks
    procedure IterateMTFAKE(iMinBatchSize, iMaxBatchSize: ni; p: TProc<int64>; opts: TForXOptions = []);overload;
      //iterate Single-Threaded, but with the same params as multi-threaded... useful for debugging, or if MT breaks
    procedure IterateMTQI(iMinBatchSize: ni; p: TProc<int64>; StopPtr: PByte = nil);overload;
      //iterate Multi-threaded, using Queue instead of commands... more efficient for simpler operations
    procedure IterateMTQI(iMinBatchSize,iMaxBatchSize: ni; p: TProc<int64>;opts: TForXOptions = []; StopPtr: PByte = nil);overload;
      //iterate Multi-threaded, using Queue instead of commands... more efficient for simpler operations
    procedure IterateMTQIFAKE(iMinBatchSize,iMaxBatchSize: ni; p: TProc<int64>;opts: TForXOptions = []);overload;
      //iterate fake version of MTQI
    procedure IterateDelete(p: TFunc<boolean>);
      //iterate Sigle-threaded.. return of TRUE causes delete
    procedure IterateDeleteFWD(p: TFunc<boolean>);
      //iterate Sigle-threaded.. forward order (not as efficient, but sometimes necessary)... return of TRUE causes delete
    function ToHTMLTable: IHolder<TStringList>;
    function SortAnon(CompareProc_1_meansAisGreaterThanB: TFunc<TSERow, TSERow, ni>): boolean;
    procedure SortVariant(sField: string);
    function SortAnon_Bubble(CompareProc_1isAgtB: TFunc<TSERow, TSERow, ni>): boolean;
    procedure SortAnon_Quick(CompareProc_1isAgtB: TFunc<TSERow,TSERow,ni>;iLo,iHi: ni);
    procedure SumDuplicatesAndDelete(sCompareField, sSumField: string);
    function GetRowStruct(row: ni): PSERow;
    procedure FlagForDelete(row: ni);

  end;



  TSERowSetArray = array of TSERowset;



function FieldValuetoString(v: variant; vType: TFieldType): string;
function StringToFieldValue(s: string; fv: TFieldType): variant;
function MysqlTypeToFieldType(sMySQLType: string): TFieldType;
function FieldTypeToMYSQLType(ft: TFieldType; iSize: integer=0): string;
procedure FreeArrayOfRowsets(a: array of TSERowSet);

function DatasetToString(ds: TCustomSQLDAtaSet; destroyit: boolean = false): string;
function RowsetToString(ds: TSERowSet; destroyit: boolean = false): string;
function RowsetToValues(ds: TSERowset; bIncludeSEFields: boolean; bTrim: boolean = true): string;
function RowToValues_NoParens(ds: TSERowset; y: int64; bIncludeSEFields: boolean; bTrim: boolean): string;overload;
function RowToValues_NoParens(ds: TSERowset; bIncludeSEFields: boolean; bTrim: boolean = true): string;overload;
function RowsetToSETStatement(ds: TSERowset): string;
function stringToFieldType(s: string): TFieldType;
function DatasetToRowset(var ds: TCustomSQLDAtaset; bDestroy: boolean = true): TSERowSet;



function FieldClassToRSfieldType(fc: TfieldClass): TFieldType;


implementation

function DatasetToRowset(var ds: TCustomSQLDAtaset; bDestroy: boolean = true): TSERowSet;
begin
  result := nil;
  try
    result := TSERowset.create;
    result.CopyFromDAtaSet(ds);

  finally
    if bDestroy then begin
      ds.free;
      ds := nil;
    end;
  end;


end;

procedure FreeArrayOfRowsets(a: array of TSERowSet);
var
  t: integer;
begin
  for t:= low(a) to high(a) do begin
    a[t].free;
    a[t] := nil;
  end;

end;

function FieldTypeToMYSQLType(ft: TFieldType; iSize: integer): string;
begin
  //list of possible types
  //float=real
  //int=integer
  //tinyint=boolean
  //bigint=int64
  //timestamp=TDateTime
  //varchar=string
  //char=string
  //text=string
  case ft of
    ftFloat: result := 'float';
    ftInteger: result := 'int';
    ftLargeInt: result := 'bigint';
    ftString: result := 'varchar('+inttostr(iSize)+')';
    ftBoolean: result := 'bool';
    ftDateTime: result := 'timestamp';
  else
    result := 'UNKNOWN TYPE';
  end
end;

function stringToFieldType(s: string): TFieldType;
begin
  s := lowercase(s);
  if s = 'integer' then begin
    result := ftInteger;
  end else
  if s = 'varchar' then begin
    result := ftString;
  end else
  if s = 'string' then begin
    result := ftString;
  end else
  if s = 'datetime' then begin
    result := ftDateTime;
  end else
  if s = 'boolean' then begin
    result := ftBoolean;
  end else
  if s = 'float' then begin
    result := ftFloat
  end else
  if s = 'bigint' then begin
    result := ftLargeInt;
  end else
  begin
    raise Exception.create('unimplemented stringToFieldType ('+s+') in unit StorageEngineTypes');
  end;

end;


function MysqlTypeToFieldType(sMySQLType: string): TFieldType;
var
  sLeft, sRight: string;
begin
  sMYSQLType := lowercase(TrimStr(sMysqlType));

  //list of possible types
  //float=real
  //int=integer
  //tinyint=boolean
  //bigint=int64
  //timestamp=TDateTime
  //varchar=string
  //char=string
  //text=string

  SplitString(sMySQLType, '(', sMySQLType, sRight);
  result := ftUnknown;
  if sMYSQLType = 'float' then
    result := ftFloat
  else
  if sMYSQLType = 'bigint' then
    result := ftLargeInt
  else
  if sMYSQLType = 'int' then
    result := ftInteger
  else
  if sMYSQLType = 'bigfloat' then
    result := ftLargeInt
  else
  if sMYSQLType = 'timestamp' then
    result := ftDateTime
  else
  if sMYSQLType = 'tinyint' then
    result := ftBoolean
  else
  if sMYSQLType = 'bool' then
    result := ftBoolean
  else
  if sMYSQLType = 'varchar' then
    result := ftString
  else
  if sMYSQLType = 'text' then
    result := ftString
  else
  if sMYSQLType = 'char' then
    result := ftString;












end;
{ TSERow }

{ TSERowSet }

procedure TSERowSet.AddDeltaColumn(sName, sSource: string; bSourceIsReverseTime: boolean);
var
  def: PSERowsetFieldDef;
  t: ni;
  i, iSource: ni;
begin
  def := self.AddField;
  def.sName := sNAme;
  def.vType := TFieldType.ftFloat;
  i := fieldcount;
  isource := IndexOfField(sSource);
  if iSource < 0 then
    raise ECritical.create('Rowset does not have field '+sSource+'. cannot compute delta column.');
  SetFieldCount(FieldCount+1);
  if bSourceIsReverseTime then begin
    for t:=0 to rowcount-2 do begin

      self.Values[i, t] := self.Values[i, t] - self.Values[i, t+1];
    end;
    self.Values[i, rowcount-1] := 0.0;
  end else begin
    self.Values[i, 0] := 0.0;
    for t:=1 to rowcount-1 do begin
      self.Values[i, t] := self.Values[i, t] - self.Values[i, t-1];
    end;

  end;



end;

function TSERowSet.AddBlankIndex(sName: string): integer;
//r: Returns index of index added
var
  i: integer;
  t: integer;
begin
  i := IndexCount+1;
  setlength(self.FIndexNames, i);
  setlength(self.FIndexValues, i);
  setlength(self.FIndexValues[i-1], RowCount);

  dec(i);
  //put unique values in each
  for t:= low(FIndexValues[i]) to high(FIndexValues[i]) do begin
    FIndexValues[i][t] := t;
  end;

  result := high(FIndexNames);


end;

function TSERowSet.AddField: PSeRowSetFieldDef;
var
  t: integer;
begin
  SetLength(FFieldDefs, length(FFieldDefs)+1);
  result := @FFieldDefs[high(FFieldDefs)];
  result.sName := '';
  result.vType := ftUnknown;
  if RowCount > 0 then begin
    for t:= 0 to RowCount-1 do begin
      FRowSet[t].setwidth(length(FFieldDEfs));
//      SetLength(self.FRowset[t], length(FFieldDEfs));
    end;
  end;
end;

function TSERowSet.AddRow: integer;
begin
  self.SetRowCount(length(FRowset)+1);
  result := length(FRowset)-1;
  FCursor := result;
  self.FRowSet[result].appended := true;
end;

function TSERowSet.AddRowFirst: integer;
var
  t,u: ni;
begin
  self.SetRowCount(length(FRowset)+1);
  result := 0;

  for t:= high(FRowset) downto 1 do begin
    for u := 0 to fieldcount-1 do begin
      self.Values[u,t] := self.values[u,t-1];
    end;
  end;
  FCursor := result;
  self.FRowSet[result].appended := true;
end;

procedure TSERowSet.AddrowFromString(s: string);
var
  sl : Tstringlist;
  s1, s2, s3: string;
  t: ni;
  v: variant;
begin
  AddRow;
  sl := nil;
  try
    sl := ParseString(s,#1);
    for t:= 1 to sl.count-1 do begin
      s1 := sl[t];
      v := stringToFieldValue(s1, Self.FieldDefs[t-1].vType);
      CurRecordFieldsByIdx[t-1] := v;
    end;
  finally
    sl.free;
  end;
end;

procedure TSERowSet.Append(rs: TSERowSet);
var
  t: ni;
begin
  if rowcount = 0 then begin
    rs.CopyFieldDefsTo(self);
  end;
  rs.first;
  var intoRow: int64 := RowCount;
  SEtRowCount(RowCount + rs.rowcount);
  for t := intoRow to RowCount-1 do begin
    FRowset[t].appended := true;
  end;

  while not rs.EOF do begin
    for t:= 0 to fieldcount-1 do begin
      values[t,intoRow] := rs.CurRecordFieldsByIdx[t];
    end;
    inc(intoRow);
//    Debug.Log('Append #'+inttostr(rs.cursor)+': '+rs.RowToString);
    rs.Next;
  end;
end;

procedure TSERowSet.Append(rs: IHolder<TSERowSet>);
begin
  Append(rs.o);
end;

procedure TSERowSet.AppendRowFrom(rs: TSERowSet; iRow: ni);
var
  t: ni;
begin
  if rowcount = 0 then begin
    rs.CopyFieldDefsTo(self);
  end;
  AddRow;
  for t:= 0 to fieldcount-1 do begin
    values[t,cursor] := rs.values[t,iRow];
  end;
end;

procedure TSERowSet.ApplyRowACtions(a: TArray<TPendingRowAction>);
begin
  Lock;
  try
  if length(a) <> rowcount then
    raise Ecritical.create('rowcount/array mismatch');


  var newRows: TArray<TSERow>;
  setlength(newRows,length(FRowset));
  var outidx: nativeint := 0;
  for var t := 0 to high(FRowSet) do begin

    if a[t].action = raDelete then continue;
    newRows[outIdx] := Frowset[t];
    if a[t].action = raChange then begin
      for var u := 0 to high(a[t].changes) do begin
        var fidx :=Self.IndexOfField(a[t].changes[u].field);
        if fidx >=0 then
          newRows[outIdx].vals[fidx] := a[t].changes[u].val;
      end;
    end;
    inc(outIDx);

  end;
  setlength(newRows, outidx);
  FRowset := newRows;
  finally
    Unlock;
  end;

end;

procedure TSERowSet.BuildIndex(sName, sFields: string);
var
  field_priorities: TArray<nativeint>;
  desc: TArray<boolean>;
  sl : TStringlist;
  t: integer;
  iTemp: integer;
  sField: string;
  thisDesc: boolean;
begin
  sl := nil;
  try
    sl := TStringlist.create;
    sl.text := stringreplace(sFIelds, ',', #13#10, [rfReplaceAll]);

    //TODO 2: Support multilevel sorting with multiple fields
    SetLength(field_priorities, sl.count);
    SetLength(desc, sl.count);
    for t:= 0 to sl.count-1 do begin
      thisdesc := false;
      sField := sl[t];
      if zcopy(sField, 0,1) = '-' then begin
        thisdesc := true;
        sField := zcopy(sField, 1,length(sField)-1);
      end;
      iTemp := self.IndexOfField(sField);
      if iTemp < 0 then
        raise exception('Field '+sField+' could not be found when indexing');

      field_priorities[t] := iTEmp;
      desc[t] := thisdesc;
    end;

    BuildIndex(sName, field_priorities, desc);
  finally
    sl.free;
  end;
end;

procedure TSERowSet.BuildIndex(sName: string; field_priorities: TArray<nativeint>; desc: TArray<boolean>);
begin
{$IFDEF USE_BUBBLE}
  BuildIndex_BUBBLE(sName, field_priorities, desc);
{$ELSE}
  BuildIndex_BTREE(sName, field_priorities, desc);
{$ENDIF}

end;


procedure TSERowSet.BuildIndex_BTREE(sName: string;
  field_priorities: TArray<nativeint>; desc: TArray<boolean>);
var
  nu: Tbti_Row;
  bt: TBTree;
  t: ni;
  idx: ni;
  order: ni;
begin
  bt := TBtree.Create;
  try
    idx := AddBlankIndex(sName);
    for t:= 0 to rowcount-1 do begin
      nu := TBti_Row.create;
      nu.indexfieldIndexes := field_priorities;
      nu.row := Frowset[t];
      nu.rownumber := t;
      nu.desc := desc;
      bt.Add(nu);
    end;
    order := 0;
    bt.Iterate(
      procedure([unsafe] ABTreeItem:TBTreeItem)
      begin
        self.FIndexValues[idx][order] := Tbti_Row(ABtreeItem).rownumber;
        inc(order);
      end
    );

    SetIndex(idx);
  finally
    bt.free;
  end;

end;

procedure TSERowSet.BuildIndex_BUBBLE(sName: string;
  field_priorities: TArray<nativeint>; desc: TArray<boolean>);
var
  idx: integer;
  iTemp: integer;
  bSorted: boolean;
  t, f: integer;
  i1,i2: integer;
  iRowCount: integer;
  fLow, fHigh: integer;
  v1,v2: variant;

begin
  self.SetIndex(-1);
  if length(field_priorities) = 0 then
    exit;

  iRowCount := RowCount;
  if iRowCount = 0 then
    exit;

  idx := self.AddBlankIndex(sName);

  fLow := low(field_priorities);
  fhigh := high(field_priorities);

  //DONE 1: Build Quick Sort
  bSorted := false;

  while not bSorted do begin
    bSorted := true;

    //if we pass through this round and make no changes... then we're done
//      bSorted := true;

    for t := 0 to RowCount-2 do begin
      //gather indexes of rows to compare
      i1 := t; //todo 3: Rename i1 i2 to something that reflects that they are ROWS
      i2 := t+1;

        //if index hits out of bounds then break
      if (i1 >= iRowCount) or (i2 >=iRowCount) then
        break;

        //compare fields
      for f := fLow to fHigh do begin
        //gather values from rows and fields to compare
        v1 := self.Values[field_priorities[f], i1];
        v2 := self.Values[field_priorities[f], i2];
        //if values are out of order
        if desc[f] then begin
          if (v1<v2) then begin
            //swap the values
            numbers.Swap(self.FIndexValues[idx][i1],self.FIndexValues[idx][i2]);
            //flag that this changes were made...
            //so stuff is potentially not sorted
            bSorted := false;
            break;
          end;
        end else begin
          if (v1>v2) then begin
            //swap the values
            numbers.Swap(self.FIndexValues[idx][i1],self.FIndexValues[idx][i2]);
            //flag that this changes were made...
            //so stuff is potentially not sorted
            bSorted := false;
            break;
          end;
        end;
      end;
    end;
  end;

  //FINALLY SET THE INDEX TO THE ONE WE JUST BUILT;
  self.SetIndex(idx);

end;

procedure TSERowSet.CancelRow;
begin
  dec(FCursor);
  self.SetRowCount(RowCount-1);
end;

procedure TSERowSet.Clear;
begin
  SetLength(FFieldDefs,0);
  setlength(FRowset,0);
end;

procedure TSERowSet.CloseIndexes;
var
  t: ni;
begin
  for t:= 0 to high(idxs) do begin
    idxs[t].free;
  end;
  setlength(idxs,0);

end;

procedure TSERowSet.CopyCurrentRecordTo(rs: TSERowSet);
var
  f: PSERowsetFieldDef;
  t: ni;
begin
  for t := 0 to fieldcount-1 do begin
    rs.CurRecordFieldsByIdx[t] := self.CurRecordFieldsByIdx[t];
  end;
end;

procedure TSERowSet.CopyFieldDefsTo(rs: TSERowSet);
var
  f: PSERowsetFieldDef;
  t: ni;
begin

  for t := 0 to fieldcount-1 do begin
    if rs.IndexOfField(Self.FieldDefs[t].sName) < 0 then begin
      f := rs.AddField;
      f.sName := Self.FieldDefs[t].sName;
      f.vType := Self.FieldDefs[t].vType;
    end;
  end;

end;

procedure TSERowSet.CopyFromDAtaSet(ds: TCustomSQLDataset; bAppend: boolean=false);
var
  t, i,u: integer;
  s: string;
  u8: utf8string;
  c: array of char;
begin
  ds.first;
  i := 0;
  if not bAppend then begin
    self.SetFieldCount(ds.fieldcount);
    for t:= 0 to ds.fieldcount-1 do begin
      self.FFieldDefs[t].sName := ds.FieldDefs[t].Name;
      self.FFieldDefs[t].vType := ds.FieldDefs[t].DataType;
    end;
  end else begin
    if self.FieldCount <> ds.FieldCount then
      raise exception.create('appended dataset contains incorrect number of fields');
  end;

  ds.first;
  while not ds.eof do begin
    self.SetRowCount(i+1);
    for t:= 0 to ds.FieldCount-1 do begin
      if ds.Fields[t].IsBlob then begin
        if ds.FieldDefs[t].DataType = ftMemo then begin
          self.Values[t,i] := ds.fields[t].Value;
        end else begin
          SetLength(s, ds.Fields[t].DataSize);
          SEtLength(c, ds.Fields[t].DAtaSize);

          {$IFDEF MSWINDOWS}
            ds.Fields[t].GetData(@c[0]);
          {$ELSE}
            raise ECritical.create('ds.Fields[t].GetData(@c[0]); is not implemented on this platform.');
          {$ENDIF}
          for u := low(c) to high(c) do begin
            s[u+1] := c[u];
          end;
          self.Values[t,i] := s;
        end;

      end else
      if (vartype(ds.fields[t].Value) = varString)
      or (vartype(ds.fields[t].Value) = varOleStr)
      then begin
        self.Values[t,i] := ds.fields[t].Text;
      end else
      begin
        if ds.FieldDefs[t].DataType in [ftDateTime,ftTimeStamp] then begin
          if vartype(ds.Fields[t].AsVariant) = varNull then
            self.values[t,i] := NULL
          else
            self.Values[t,i] := strtodatetime(ds.Fields[t].AsVariant);
        end
        else
          self.Values[t,i] := ds.Fields[t].AsVariant;
      end;
    end;
    inc(i);
    ds.Next;
  end;
end;

procedure TSERowSet.CopyRecordFromByName(rs: TSERowSet);
var
  t: ni;
begin
  for t := 0 to rs.FieldCount-1 do
    self[rs.FieldDefs[t].sName] := rs.CurRecordFieldsByIdx[t];


end;

constructor TSERowSet.Create;
begin
  inherited;
  FIndex := -1;
  FMainTain := TStringlist.create;
end;

procedure TSERowSet.DefineFromHeaderString(s: string);
var
  sl: TStringlist;
  t: ni;
  fd: PSERowsetFieldDef;
  s1,s2: string;
begin
  sl := nil;
  try
    sl := ParseString(s, ',');
    for t:= 0 to sl.count-1  do begin
      if (t and 1) = 1 then
        continue;

      s1 := sl[t];
      s2 := sl[t+1];
      fd := self.AddField;
      fd.sName := s1;
      fd.vType := TFieldType(strtoint(trim(s2)));

    end;


  finally
    sl.free;
  end;

end;

procedure TSERowSet.DeleteRow(n: nativeint);
begin
  if n < 0 then
    exit;
  if n > high(Frowset) then
    exit;

  for var t:= n+1 to high(Frowset) do
    FRowset[t-1] := FRowset[t];

  setlength(Frowset,length(FRowset)-1);


end;

procedure TSERowSet.First;
begin
  FCursor := 0

end;

procedure TSERowSet.FlagForDelete(row: ni);
begin
  FRowset[row].deletepending := true;
end;

procedure TSERowSet.FromCSV(csv, separator: string);
var
  sl: IHolder<TStringlist>;
  t,f: ni;
  slLine: TStringlist;
  pfd: PSERowsetFieldDef;
begin
  sl := stringToStringListh(csv);
  for t:= 0 to sl.o.Count-1 do begin
    slLine := nil;
    try
      slLine := SplitStringIntoStringList(sl.o[t], ',', '"');

      if t = 0 then begin
        for f:= 0 to slLine.count-1 do begin
          pfd := self.AddField;
          pfd.sName := UnQuote(slLine[f]);
          pfd.vType := ftString;
        end;
      end else begin
        AddRow;
        for f:= 0 to slLine.count-1 do begin
          values[f,t-1] := UnQuote(slLine[f]);
        end;
      end;


    finally
      slLine.free;
    end;
  end;





end;

function TSERowSet.GetCurRecordFields(sFieldName: string): variant;
var
  idx: integer;
begin
  if inMTIterator then
    raise ECritical.create('you cannot call a cursor operation because you''re in a multi-threaded iterator');

  idx := self.IndexOfField(sFieldName);

  if idx < 0 then
    raise ECritical.create('Field '+sFieldName+' not found in rowset.');

  result:= values[idx, FCursor];


 end;



function TSERowSet.GetCurRecordFieldsByIdx(idx: integer): variant;
begin
  if inMTIterator then
    raise ECritical.create('you cannot called a cursor operation because you''re in a multi-threaded iterator');

  try
    result := values[idx, FCursor];
  except
    on e:exception do begin
      result := '*BAD*'+e.Message;
    end;
  end;
end;

function TSERowSet.GetEOF: boolean;
begin
  result := (FCURSOR > (self.RowCount-1)) or (RowCount = 0);

end;

function TSERowSet.GEtFieldCount: integer;
begin
  if FFieldDefs = nil then begin
    result := 0;
  end else
    result := length(self.FFieldDefs);



end;

function TSERowSet.GetFieldDef(idx: integer): PSERowsetFieldDef;
begin
  result := @FFieldDefs[idx];
end;

function TSERowSet.GEtFieldDefs(idx: integer): PSERowsetFieldDef;
begin
  result := @self.FFielddefs[idx];
end;

function TSERowSet.GetFieldList: IHolder<TStringlist>;
begin
  result := NewStringListH;
  for var t := 0 to Self.FieldCount-1 do begin
    result.o.add(self.fielddefs[t].sName);
  end;

end;

function TSERowSet.GetfieldValue(iRow: nativeint; sFieldName: string): variant;
var
  i: nativeint;
begin
  i := IndexOfField(sFieldNAme);
  if i < 0 then
    raise ECritical.create('field '+sfieldname+' does not exist.');
  result := Values[i,iRow];
end;

function TSERowSet.GetHeaderString: string;
var
  t: ni;
  sLine: string;
begin
  sLine := '';
  for t:= 0 to fieldcount-1 do begin
    if t>0 then
      sLine := sLine + ',';

    sLine := sLine + Self.FieldDefs[t].sName+','+inttostr(ord(self.FieldDefs[t].vType));
  end;

  result := sLine;
end;

function TSERowSet.GetIndexedRow(iOrderIdx: integer): integer;
begin
  if FIndex < 0 then
    result := iOrderIdx
  else
  if FIndex >= RowCount then
    raise Exception.create('Row index out of bounds '+inttostr(iOrderIdx))
  else
    result := FIndexValues[FIndex][iOrderIdx];

end;

function TSERowSet.GetIndexOfIndex(sName: string): integer;
begin

//TODO -cunimplemented: unimplemented block
  raise exception.create('unimplemented');
  result := -1;
end;

function TSERowSet.GEtRowCount: integer;
begin
  result := length(FRowset);
end;

function TSERowSet.GetRowStruct(row: ni): PSERow;
begin
  result := @FRowSet[row];

end;

function TSERowSet.GetValueArray(fields: TDynStringArray): TDynVariantArray;
var
  t: ni;
begin
  setlength(result, length(fields));
  for t:= 0 to high(fields) do begin
    result[t] := self[fields[t]];
  end;
end;

function TSERowSet.GetValues(x, y: integer): variant;
var
  iRow: integer;
begin

  if x < 0 then
    raise ECritical.create('negative column number '+x.tostring);
  if x >= fieldcount then
    raise ECritical.Create('trying to read column '+x.tostring+' which is >= column count '+fieldcount.tostring);
  iRow := GetIndexedRow(y);
  if FRowSet[iRow].width <> fieldCount then
    FRowSet[iRow].width := fieldcount;
//    SetLength(FRowset[iRow], fieldcount);

  result := FRowset[iRow].vals[x];
end;

function TSERowSet.GetValuesByFieldName(fld: string; y: integer): variant;
begin
  var idx := IndexOfField(fld);
  if idx < 0 then
    raise Ecritical.create('field '+fld+' not found in rowset');
  result := values[idx,y];
end;

function TSERowSet.GetValueStringArray(
  fields: TDynStringArray): TDynStringArray;
var
  t: ni;
begin
  setlength(result, length(fields));
  for t:= 0 to high(fields) do begin
    result[t] := self[fields[t]];
  end;
end;

function TSERowSet.IndexCount: integer;
begin
  result := length(FIndexNames);

end;

function TSERowSet.IndexOfField(sName: string): integer;
var
  t: integer;
begin
  sName := lowercase(sName);
  result := -1;
  for t:= 0 to FieldCount-1 do begin

    var lc := lowercase(self.Fields[t].sName);



    if lc=sName then begin
      result := t;
      break;
    end;

    var dotted := '.'+sName;

    if endsWithnocase(lc, dotted) then begin
      result := t;
      break;
    end;

  end;
end;

procedure TSERowSet.Iterate(p: TProc);
begin
  for var t := 0 to rowcount-1 do begin
    SetCommandProgress(t,rowcount-1);
    cursor := t;
    p();
  end;
end;

procedure TSERowSet.IterateAC(p: TProc<TStringList>; commit: TProc<TStringList>; commitThreshold: int64 = 10000);
//                                     ^Acquire                     ^Commit
begin
  var slh := NewStringListH;
  for var t := 0 to rowcount-1 do begin
    SetCommandProgress(t,rowcount-1);
    cursor := t;
    p(slh.o);//<<<<<-----------MAIN PROC

    //if accumulated a bunch then
    if slh.o.Count>=commitThreshold then begin
      commit(slh.o);//<<<<<---------call the commit anon proc<> to commit the accumulation
      slh.o.Clear;
    end;
  end;

  if slh.o.Count > 0 then
    commit(slh.o);//<<<<<------final commit if anything is left
end;


procedure TSERowSet.IterateDelete(p: TFunc<boolean>);
begin
  for var t := rowcount-1 downto 0 do begin
    cursor := t;
    if p() then begin
      DeleteRow(t);
    end;
  end;
end;

procedure TSERowSet.IterateDeleteFWD(p: TFunc<boolean>);
begin
  var t: int64 := 0;
  while t < rowcount do begin
    cursor := t;
    if p() then begin
      DeleteRow(t);
    end else
      inc(t);
  end;
end;

procedure TSERowSet.Iterate(p: TProc<int64>);
begin
  var t: int64 := 0;
  var len: int64 := rowcount;
  while t < len do begin
    SetCommandProgress(t,len-1);
    p(t);
    inc(t);
  end;
end;


procedure TSERowSet.IterateMT(iMinBatchSize: ni; p: TProc<int64>;
  opts: TForXOptions);
begin
  inMTIterator := true;
  try
    ForX(0,rowcount, iMinBatchSize, 64, p, opts);
  finally
    inMTIterator := false;
  end;
end;

procedure TSERowSet.IterateMT(iMinBatchSize, iMaxBatchSize: ni; p: TProc<int64>;
  opts: TForXOptions);
begin
  inMTIterator := true;
  try
    ForX(0,rowcount, iMinBatchSize, iMaxBatchSize, p, opts);
  finally
    inMTIterator := false;
  end;

end;

procedure TSERowSet.IterateMTAC(iMinBatchSize, iMaxBatchSize: ni;
  p: TProc<int64, TSharedStringList>; p2: TProc<TSharedStringList>;
  opts: TForXOptions);
begin
  inMTIterator := true;
  try
    var sl := TSharedStringList.create;
    try
      var pp :TProc<int64> := procedure (idx: int64) begin
        p(idx,sl);
        sl.lock;
        try
          if sl.count > 1000 then begin
            p2(sl);
            sl.clear;
          end;
        finally
          sl.unlock;
        end;
      end;


      ForX(0,rowcount, iMinBatchSize, iMaxBatchSize, pp, opts);

      if sl.count >0 then
        p2(sl);

    finally
      sl.free;
    end;
  finally
    inMTIterator := false;
  end;

end;

procedure TSERowSet.IterateMTFAKE(iMinBatchSize, iMaxBatchSize: ni;
  p: TProc<int64>; opts: TForXOptions);
begin
  iterate(p);
end;

procedure TSERowSet.IterateMTFAKE(iMinBatchSize: ni; p: TProc<int64>;
  opts: TForXOptions);
begin
  iterate(p);
end;

procedure TSERowSet.IterateMTQI(iMinBatchSize, iMaxBatchSize: ni;
  p: TProc<int64>;opts: TForXOptions = []; StopPtr: PByte = nil);
begin

  ForX_QI(0, rowcount, iMinBatchSize, iMaxBatchSize, p,opts, StopPtr);

end;

procedure TSERowSet.IterateMTQIFAKE(iMinBatchSize, iMaxBatchSize: ni;
  p: TProc<int64>; opts: TForXOptions);
begin
  ForXFAKE(0, rowcount, iMinBatchSize, iMaxBatchSize, p,opts);

end;

procedure TSERowSet.IterateMTQI(iMinBatchSize: ni; p: TProc<int64>; StopPtr: Pbyte = nil);
begin
  ForX_QI(0, rowcount, iMinBatchSize, p,[], StopPtr);

end;

procedure TSERowSet.IterateReverse(p: TProc);
begin
  for var t := rowcount-1 downto 0 do begin
    cursor := t;
    p();
  end;

end;

procedure TSERowSet.LAst;
begin
  high(FRowset);
end;

procedure TSERowSet.LoadfromCSV(f: string);
var
  sl: TStringlist;
  sLine, sValue: string;
  row,fld: ni;
  h: IHolder<TStringlist>;
  var pf: PSERowsetFieldDef;
begin
  self.Clear;
  sl := TStringlist.create;
  try
    sl.LoadFromFile(f);

    if sl.count = 0 then
      raise ECritical.create('Empty CSV file');
    //header
    sLine := sl[0];
    h := stringx.ParseStringNotInH(sLine, ',', '"');
    for fld := 0 to h.o.Count-1 do begin
      sValue := h.o[fld];
      if sValue <> '' then begin
        sValue := stringreplace(sValue, 'CHANGE', '_CHANGE', [rfReplaceAll, rfIgnoreCase]);
        sValue := stringreplace(sValue, ' ', '_', [rfReplaceAll]);
        sValue := stringreplace(sValue, '-', '_', [rfReplaceAll]);
        sValue := stringreplace(sValue, '/', '_per_', [rfReplaceAll]);
        if svalue <> '' then begin
          pf := self.AddField;
          pf.sName := sValue;
          pf.vType := TFieldType.ftString;
        end;
      end;
    end;

    for row := 1 to sl.count-1 do begin
      sLine := sl[row];
      h := stringx.ParseStringNotInH(sLine, ',', '"');
      if not stringlist_valuesblank(h.o) then begin
        self.AddRow;
        for fld := 0 to lesserof(h.o.Count, fieldcount)-1 do begin
          sValue := h.o[fld];
          self.CurRecordFieldsByIdx[fld] := sValue;
        end;
      end;
    end;

  finally
    sl.free;
  end;

end;

procedure TSERowSet.LoadFromfile(f: string; filterfunc: TAnonRecFilter; startAtIndex: string = ''; startAtIndexValue: int64 = 0);
var
  sLine: string;
  c: char;
//  fs: TMBMemoryStringStream;
  fs: TMultiBufferMemoryFileStream;
  x,y: ni;
  v: variant;
  iStarT: int64;
  iLen: int64;
  bAccept: boolean;
  bHeaderFound: boolean;
  bBreak: boolean;
begin
  fs := nil;
  try
    if (not fileexists(f)) then
      raise ECritical.create('local table does not exist '+f)
    else begin
      fs := TMultiBufferMemoryFileStream.Create(f, fmOpenRead);
      fs.Seek(0,soBeginning);
    end;

    if startAtIndex <> '' then begin
      iStart := FindSeekInIndex(f, startAtIndex, startAtIndexValue);
      if iStart > 0 then
        fs.Seek(iStart, soBeginning);
    end;

    bHeaderFound := false;
    while fs.position < fs.size do begin
      iStart := fs.Position;
      bBreak := false;
      while fs.position < fs.size do begin
        stream_guaranteeread(fs, @c, sizeof(c));
        if c = #10 then begin
          iLen := (fs.Position - iStart);
          setlength(sLine, iLen shr 1);
          fs.Seek(iStart, soBeginning);
          stream_guaranteeRead(fs, @sLine[strz], iLen);
          if not bHeaderFound then begin
            DefineFromHeaderString(sLine);
            bHeaderFound := true;
            break;
          end else begin
            AddRowFromString(sLine);
            filterfunc(self, bAccept, bBreak);
            if not bAccept then
              SetLength(self.FRowset, length(FRowset)-1);
            break;
          end;
        end;
      end;
      if bBreak then
        break;
    end;


  finally
    fs.free;
    fs := nil;
  end;
end;


function TSERowSet.Lookup(sLookupField: string; vLookupValue: variant;
  sReturnField: string; bNoExceptions: boolean = false): variant;
var
  r: ni;
  f: ni;
begin
  result := null;
  r := FindValue(sLookupField, vLookupValue);
  f := indexoffield(sReturnfield);

  if f < 0 then begin
    if bNoExceptions then
      exit(null)
    else
      raise ECritical.create('Return field '+sReturnField+' not found.');
  end;

  if r >=0 then
    result := values[f,r];


end;

procedure TSERowSet.Maintain(sField: string);
begin
  FMaintain.Duplicates := dupIgnore;
  FMaintain.Add(lowercase(sField));

end;

procedure TSERowSet.Next;
begin
  inc(FCursor);

end;

function TSERowSet.FindSeekInIndex(sBaseFile, sIndex: string; value: int64): int64;
var
  sIDXFile: string;
  sex: TSEIndexfile;
begin
  sIDXFile := sBasefile+'.'+sIndex+'.idx';
  if not fileexists(sIDXfile) then
    raise ECritical.create('Index not found '+sIndex);

  sex := TSEIndexFile.Create;
  try
    sex.Open(sIDXFile, false);
    result := sex.AddrOf(value);
  finally
    sex.free;
  end;




end;

function TSERowSet.FindValue(sField: string; vValue: variant): ni;
begin
  result := FindValueAfter(-1,sField, vValue);
end;

function TSERowSet.FindValueAfter(iAfterRow: int64; sField: string; vValue: variant): ni;
var
  t: ni;
  f: ni;
  v: variant;
begin
  result := -1;
  f := self.IndexOfField(sField);
  if f< 0 then
    raise ECritical.create('Rowset does not have field '+sField);

  for t:= (iAfterRow+1) to rowcount-1 do begin
    v := values[f,t];
    if varType(v) = varString then begin
      if comparetext(values[f,t], vValue) = 0 then begin
        exit(t);
      end
    end else begin
      if Values[f,t] = vValue then
        exit(t);
    end;
  end;

end;

function TSERowSet.FindValueMT(sField: string; vValue: variant): ni;
begin
  result := FindValuesMT([sfield],[vValue]);
end;

function TSERowSet.FindValues(aFields: TArray<string>;
  aValues: TArray<variant>): ni;
var
  t: ni;
  fs: TArray<nativeint>;
  f1,f2: ni;
  vv: variant;
begin
  result := -1;
  if length(aFields) <> length(aValues) then
    raise ECritical.create('FindValues requires two arrays of equal length');
  setlength(fs,length(aFields));


  for var v := low(aFields) to high(aFields) do begin
    fs[v] := self.IndexOfField(aFields[v]);
//    debug.log(aFields[v]+' is at '+inttostr(fs[v]));
    if fs[v] < 0 then
      raise ECritical.create('field '+aFields[v]+' not found in TSERowSet');
  end;

  for t:= 0 to rowcount-1 do begin
    var bGood := true;

    for var v := low(aFields) to high(aFields) do begin
      var vValue := aValues[v];
      vv := values[fs[v],t];
      if varType(vv) = varString then begin
        if comparetext(vv, vValue) <> 0 then begin
          bGood := false;
          break;
        end
      end else begin
        if v <> vValue then begin
          bGood := false;
          break;
        end;
      end;
    end;

    if bGood then exit(t);
  end;


end;

function TSERowSet.FindValuesMT(aFields: TArray<string>;
  aValues: TArray<variant>): ni;
var
  t: ni;
  fs: TArray<nativeint>;
  f1,f2: ni;
  vv: variant;
begin
  var sectAtomResult: TCLXCriticalSection;
  ics(sectAtomResult);
  try
  result := -1;
  var resultIdx: int64 := -1;
  if length(aFields) <> length(aValues) then
    raise ECritical.create('FindValuesMT requires two arrays of equal length');
  setlength(fs,length(aFields));


  for var v := low(aFields) to high(aFields) do begin
    fs[v] := self.IndexOfField(aFields[v]);
//    debug.log(aFields[v]+' is at '+inttostr(fs[v]));
    if fs[v] < 0 then
      raise ECritical.create('field '+aFields[v]+' not found in TSERowSet');
  end;

  var stop: byte := 0;
  ForX_QI(0,rowcount,SIMPLE_BATCH_SIZE, procedure (t: int64) begin
    var bGood := true;

    for var v := low(aFields) to high(aFields) do begin
      var vValue := aValues[v];
      vv := values[fs[v],t];
      if varType(vv) = varString then begin
        if comparetext(vv, vValue) <> 0 then begin
          bGood := false;
          break;
        end
      end else begin
        if v <> vValue then begin
          bGood := false;
          break;
        end;
      end;
    end;

    if bGood then begin
      ecs(sectAtomresult);
      stop := 1;//this is monitored by the QueueItem (passed by pointer below)
      resultIdx := t;//TODO 1: Not Atomic on 32-bit systems
      lcs(sectAtomresult);
    end;
  end, [], @stop {pointer allows iterator to be stopped when a match is found});

  result := resultIdx;
  finally
    dcs(sectAtomResult);
  end;
end;

function TSERowSet.FindValue_Presorted(sField: string; vValue: variant): ni;
var
  ipos: nativeint;
  finalIdx, testIdx: int64;
  iTemp: nativeint;
begin
  iPos := 63;
  ipos := 0;
  var cnt := rowcount;
  testIdx := 0;
  finalIdx := 0;

  for iPos := 63 downto 0 do begin
    testIdx := finalIdx or (1 shl iPos);//propose to add a bit to the index

    //if index in range
    if testIdx < cnt then begin //Never put a 1 in for indexes greater than the count
      //if search > testcase, keep value
      var testV := valuesn[sField,testIDx];
      if vValue < testV then
        iTemp := -1
      else if vValue > testV then
        iTemp := 1
      else
        iTemp := 0;
      if itemp >= 0 then
        finalIdx := testIdx;

      if itemp = 0 then
        exit(finalIdx);


    end;
  end;

  testIDX := 0;

  var testV := valuesn[sField,testIDx];

  if vValue < testV then
    iTemp := -1
  else if vValue > testV then
    iTemp := 1
  else
    iTemp := 0;


  if iTemp = 0 then
    exit(finalIdx);

  exit(-1);

end;

procedure TSERowSet.OpenIndexes(sBaseFile: string; bForRead, bForAppend: boolean);
var
  t: ni;
  sidx: string;
  sIdxFile: string;
begin
  setlength(idxs, FMaintain.count);
  for t:= 0 to FMaintain.Count-1 do begin
    sIDX := FMaintain[t];
    sIDXFile := sBasefile+'.'+sIDX+'.idx';
    if bForRead then begin
      if not fileexists(sIDXfile) then
        TFileStream.Create(sIDXFile, fmCreate).free;

      idxs[t] := TMultiBufferMemoryFileStream.create(sIDXFile, fmOpenRead);

    end else begin
      if (not fileexists(sIDXfile)) or (not bForAppend) then
        idxs[t] := TMultiBufferMemoryFileStream.Create(sIDXFile, fmCreate)
      else
        idxs[t] := TMultiBufferMemoryFileStream.create(sIDXFile, fmOpenReadWrite);
    end;
  end;
end;

procedure TSERowSet.PrePend(rs: TSERowSet);
var
  t: ni;
begin
  rs.last;
  while cursor>=0 do begin
    AddRowFirst;
    for t:= 0 to fieldcount-1 do begin
      CurRecordFieldsByIdx[t] := rs.CurRecordFieldsByIdx[t];
    end;
    rs.Previous;
  end;
end;

procedure TSERowSet.Previous;
begin
  dec(FCursor);
end;

procedure TSERowSet.Reset(nodelete: boolean);
begin

  for var t:= high(FRowset) downto 0 do begin
    if (not nodelete) and FRowset[t].deletepending then begin
      self.deleterow(t);
    end else
      FRowset[t].reset;
  end;


end;

function TSERowSet.RowToMSSQLValues(r: TSERow): string;
var
  t: ni;
  cell: TSECell;
begin
  result := '(';
  for t:= 0 to high(r.vals) do begin
    cell := r.vals[t];
    case vartype(cell) of
      varString, varUString, varOleStr:
      begin
//        cell := StringReplace(cell, 'â„¢', '™', [rfReplaceAll]);
      end;
    end;

    if t > 0 then
      result := result + ',';

    result := result + gvs(cell);


  end;
  result := result + ')';
end;

function TSERowSet.RowToMYSQLValues(r: TSERow): string;
var
  t: ni;
  cell: TSECell;
  fdef: PSERowsetFieldDef;
begin
  result := '(';
  for t:= 0 to high(r.vals) do begin
    cell := r.vals[t];
    case vartype(cell) of
      varString, varUString, varOleStr:
      begin
        cell := StringReplace(cell, 'â„¢', '™', [rfReplaceAll]);
      end;
    end;

    if t > 0 then
      result := result + ',';

    fdef := FieldDefs[t];
    case fdef.vType of
      ftDate, ftDateTime: begin
        result := result + gss(varDate, cell);
      end;
    else
      result := result + gvs(cell);
    end;






  end;
  result := result + ')';
end;

function TSERowSet.RowToString: string;
var
  x,y: ni;
  v: variant;
begin
  result := '';
  y := cursor;
  for x:= 0 to self.FieldCount-1 do begin
    v := self.Values[x,y];
    result := result + (#1+fieldvaluetostring(v, self.FieldDefs[x].vType));
  end;
end;

procedure TSERowSet.SavetoCSV(f: string);
begin

  raise ECritical.create('unimplemented because it is database specific... look in mysqlstoragestring.pas');
//TODO -cunimplemented: unimplemented block
end;

procedure TSERowSet.SavetoFile(f: string; bAppend: boolean);
var
  sLine: string;
//  fs: TMBMemoryStringStream;
  fs: TMultiBufferMemoryFileStream;
  x,y: ni;
  v: variant;
  iStartAddr: int64;
begin
  fs := nil;
  try
    if (not fileexists(f)) or (not bAppend) then begin
      fs := TMultiBufferMemoryFileStream.Create(f, fmCReate);
      sLine := GetHeaderString+#10;
      Stream_GuaranteeWrite(fs, @sLine[STRZ], length(sLine) shl 1);//<<--- write HEADER LINE
    end else begin
      fs := TMultiBufferMemoryFileStream.Create(f, fmOpenReadWrite);
      fs.Seek(0,soEnd);
    end;

    OpenIndexes(f, false, bAppend);
    try
      for y := 0 to Self.RowCount-1 do begin
        cursor := y;
        sLine := rowtostring+#10;
        iStartAddr := fs.Position;
        Stream_GuaranteeWrite(fs, @sLine[STRZ], length(sLine) shl 1);//<<---- WRITE individual lines
        WriteToIndex(f, bAppend, iStartAddr);
      end;
    finally
      CloseIndexes;
    end;

  finally
    fs.free;
    fs := nil;
  end;
end;

function TSERowSet.SeekValue(sField: string; vValue: variant): boolean;
//THIS Finds a value and syncs the cursor on the row
//returns TRUE if found, else false
var
  t: ni;
  f: ni;
  v: variant;
begin
  result := false;
  f := self.IndexOfField(sField);
  if f< 0 then
    raise ECritical.create('Rowset does not have field '+sField);

  for t:= 0 to rowcount-1 do begin
    v := values[f,t];
    if varType(v) = varString then begin
      if comparetext(values[f,t], vValue) = 0 then begin
        self.Cursor := t;
        exit(true);
      end
    end else begin
      if Values[f,t] = vValue then begin
        self.Cursor := t;
        exit(true);
      end;
    end;

  end;

end;

procedure TSERowSet.SetCurRecordFields(sFieldName: string;
  const Value: variant);
var
  idx: integer;
begin
  idx := self.IndexOfField(sFieldName);

  values[idx, FCursor] := value;


end;

procedure TSERowSet.SetCurRecordFieldsByIdx(idx: integer; const Value: variant);
begin
  if idx >= FieldCount then
    raise Exception('Record index out of X bounds: '+inttostr(idx));

  if FCursor > high(FRowSet)  then
    raise Exception('Record index out of X bounds: '+inttostr(idx));


  values[idx, self.FCursor] := value;
end;

procedure TSERowSet.SetFieldCount(iCount: integer);
begin
  SetLength(FFieldDefs, iCount);
  UpdateRowWidths(0);

end;

procedure TSERowSet.SetIndex(idx: integer);
begin
  FIndex := idx;
  First;
end;

procedure TSERowSet.SetRowCount(iCount: integer);
var
  iOldCount: integer;
begin
  iOldCount := length(FRowset);
  SetLength(self.FRowset, iCount);
  UpdateRowWidths(iOldCount); //TODO 2:optimize for insert and cancel... source of SLOWness

end;

procedure TSERowSet.SetValues(x, y: integer; const Value: variant);
begin
  if y >= RowCount then
    raise ECritical.create(classname+' does not have row '+inttostr(y));
  if x >= FieldCount then
    raise ECritical.create(classname+' does not have field #'+inttostr(x));

  FRowset[y].vals[x] := value;
  FRowset[y].mods[x] := true;
  FRowset[y].modded := true;

end;

procedure TSERowSet.SetValuesByFieldName(fld: string; y: integer;
  const Value: variant);
begin
  values[IndexOfField(fld),y] := value;
end;

function TSERowSet.SortAnon(
  CompareProc_1_meansAisGreaterThanB: TFunc<TSERow, TSERow, ni>): boolean;
begin
{$IFDEF BUBBLE_SORT}
  result := SortAnon_Bubble(CompareProc_1isAgtB);
{$ELSE}
  SortAnon_Quick(CompareProc_1_meansAisGreaterThanB,0,rowcount-1);
  result := true;
{$ENDIF}
end;

function TSERowSet.SortAnon_Bubble(
  CompareProc_1isAgtB: TFunc<TSERow, TSERow, ni>): boolean;
//returns TRUE if anything changed, else FALSE if already sorted
var
  solved: boolean;
begin
  result := false;
  repeat
    solved := true;

    for var t:= 0 to high(FRowset)-1 do begin
      var comp := CompareProc_1isAgtB(FRowset[t], FRowset[t+1]);
      if comp > 0 then begin
        var c := FRowset[t];
        FRowset[t] := FRowset[t+1];
        FRowset[t+1] := c;
        solved := false;
        result := true;
      end;
    end;

  until solved;

end;

procedure TSERowSet.SortAnon_Quick(
  CompareProc_1isAgtB: TFunc<TSERow, TSERow, ni>; iLo, iHi: ni);
var
  Lo, Hi: ni;
  TT,Pivot: TSERow;
begin
   Lo := iLo;
   Hi := iHi;
   var pvtIDX := (Lo + Hi) shr 1;
   if pvtIDX > (rowcount-1) then
    exit;
   Pivot := FRowset[pvtIDX];
   repeat
      while CompareProc_1isAgtB(FRowset[lo],pivot) < 0 do
        begin
          inc(lo);
          if lo >= (rowcount) then break;
        end;
      while CompareProc_1isAgtB(FRowset[hi],pivot) > 0 do
        begin
          dec(hi);
          if hi < 0 then break;
        end;
      if Lo <= Hi then
      begin
        TT := FRowset[Lo];
        FRowset[Lo] := FRowset[Hi];
        FRowset[Hi] := TT;
        Inc(Lo) ;
        Dec(Hi) ;
      end;
   until Lo > Hi;
   if Hi > iLo then SortAnon_Quick(CompareProc_1isAgtB, iLo, Hi) ;
   if Lo < iHi then SortAnon_Quick(CompareProc_1isAgtB, Lo, iHi) ;
end;

procedure TSERowSet.SortVariant(sField: string);
begin
  var af := IndexOfField(sField);
  if af < 0 then
    raise Ecritical.create('cannot sort on field '+sField+' because it doesn''t exist in TSERowset');
  SortAnon(function (a,b: TSERow): nativeint begin
    if a.vals[af] < b.vals[af] then
      exit(-1);
    if a.vals[af] > b.vals[af] then
      exit(1);
    exit(0);
  end);

end;

procedure TSERowSet.SumDuplicatesAndDelete(sCompareField, sSumField: string);
begin
  IterateMTFake(1,procedure (idx: int64) begin
    if self.valuesN[sCompareField,idx] = 'If It Hadn''t Been For Love' then
      debug.log('checking '+vartostr(self.valuesN[sCompareField,idx])+' '+vartostr(self.valuesN[sSumField,idx]));
    for var idx2 := idx to rowcount-1 do begin
      //debug.log(idx.tostring+' '+idx2.tostring);
      if idx = idx2 then
        exit;
      if self.valuesN[sCompareField,idx2] = self.valuesN[sCompareField,idx] then begin
        var a: int64 := self.valuesN[sSumField,idx];
        var b: int64 := self.valuesN[sSumField,idx2];
        
        if self.valuesN[sCompareField,idx] = 'If It Hadn''t Been For Love' then begin
          debug.log('checking '+vartostr(self.valuesN[sCompareField,idx])+' '+vartostr(self.valuesN[sSumField,idx]));
          debug.log('adding '+a.tostring+' + '+b.tostring);
        end;
        self.valuesN[sSumField,idx] := a+b;
        self.valuesN[sSumField,idx2] := 0;
        if self.valuesN[sCompareField,idx] = 'If It Hadn''t Been For Love' then
          debug.log('checking '+vartostr(self.valuesN[sCompareField,idx])+' '+vartostr(self.valuesN[sSumField,idx]));

      end;
    end;
  end);

  for var t:= rowcount-1 downto 0 do begin
    if self.valuesN[sSumField,t] = 0 then begin
      self.DeleteRow(t);
    end;
  end;
  
  var f := self.IndexOfField(sSumField);

  SortAnon(function (a,b: TSERow): nativeint begin
    if b.vals[f] > a.vals[f] then
      exit(1);
    if a.vals[f] > b.vals[f] then
      exit(-1);
    exit(0);
    
  end);
end;

function TSERowSet.ToHTMLTable: IHolder<TStringList>;
begin
  result := NewStringListH;
  var oo := result.o;
  oo.add('<table>');
  oo.add('<tr>');
  for var t := 0 to fieldcount-1 do begin
    oo.add('<th>'+fielddefs[t].sname+'<th>');
  end;
  oo.add('</tr>');
  Iterate(procedure begin
    oo.add('<tr>');
    for var t := 0 to fieldcount-1 do begin
      oo.add('<td>'+self.values[t,cursor]+'<td>');
    end;
    oo.add('</tr>');
  end);
  oo.add('</table>');
end;

function TSERowSet.ToJSONh: IHolder<TJSON>;
var
  x,y: ni;
  jRec: TJSON;
begin
  result := THOlder<TJSON>.create;
  result.o := TJSON.create;

  for y := 0 to rowcount-1 do begin
    jrec := nil;
    try
      jrec := TJSON.create;
      for x := 0 to fieldcount-1 do begin
        jrec.AddMemberPrimitiveVariant(self.FieldDefs[x].sName, self.Values[x,y]);
      end;

      result.o.AddIndexed(jrec);
    finally
      jrec.free;
    end;
  end;
end;

function TSERowSet.ToMSSQLImport(sTableName: string): string;
begin
  var flds := GetFieldList;
  var unparsed := stringx.UnParseString(',', flds.o);
  result := 'insert into '+sTableName+' ('+unparsed+') values '+ToMSSQLValues+';';
end;

function TSERowSet.ToMSSQLValues: string;
var
  t: ni;
begin
  result := '';
  for t:= 0 to rowcount-1 do begin
    if t > 0 then
      result := result + ',';
    result := result + self.RowToMYSQLValues(self.FRowset[t]);
  end;
end;

function TSERowSet.ToMYSQLCreateTable(sTableName: string): string;
var
  t: ni;
  sName: string;
begin
  result := 'create table '+sTableName+' (';

  for t:= 0 to Self.FieldCount-1 do begin
    if t> 0 then
      result := result + ',';

    sName := self.fields[t].sName;
    if sName = '' then
      sName := 'FLD'+inttostr(t);

    sName := stringreplace(sName, ' ', '_', [rfReplaceAll]);
    sName := stringreplace(sName, '-', '_', [rfReplaceAll]);
    sName := stringreplace(sName, '/', '_', [rfReplaceAll]);
    result := result + sName+' varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci';
  end;

  result := result + ') ;';


end;

function TSERowSet.ToMYSQLImport(sTableName: string): string;
begin
  result := 'insert into '+sTableName+' values '+ToMySQLValues+';';
end;

function TSERowSet.ToMYSQLValues: string;
var
  t: ni;
begin
  result := '';
  for t:= 0 to rowcount-1 do begin
    if t > 0 then
      result := result + ',';
    result := result + self.RowToMYSQLValues(self.FRowset[t]);
  end;
end;

function TSERowSet.ToString: string;
begin
  result := RowSettoString(self);
end;

procedure TSERowSet.UpdateRowWidths(iOldCount: integer);
var
  t: integer;
  i: integer;
begin
  i := length(self.FFieldDefs);
  for t := low(FRowSet)+iOldCount to high(FRowset) do begin
    SetLength(FRowset[t].vals, i);
    FRowSet[t].init;
    FRowset[t].mods.FlagCount := i;

  end;

end;

procedure TSERowSet.WriteToIndex(sBaseFile: string; bForAppend: boolean; iStartAddr: int64);
var
  t: ni;
  sidx: string;
  sIdxFile: string;
  pair: TIndexPair;
begin
  for t:= 0 to FMaintain.Count-1 do begin
    sIDX := FMaintain[t];
    idxs[t].Seek(0,soEnd);
    pair.addr := iStartAddr;
    pair.value := CurRecordFields[sIDX];
    stream_GuaranteeWrite(idxs[t],@pair, sizeof(pair));
  end;

end;

{ TQueryList }

procedure TQueryList.AddQuery(s: string);
begin
  add(s);
  add('--execute--');
end;

procedure TQueryList.First;
begin
  FIdx := 0;
end;

function TQueryList.GetEOF: boolean;
begin
  result := FIDx >= (count-1);
end;

function TQueryList.GetNextQuery: string;
begin
  result := '';
  while not (self[FIDX] = '--execute--') do begin
    result := result+self[FIDX];
    inc(FIDX);
  end;
  inc(FIDX);
end;

function DatasetToString(ds: TCustomSQLDAtaSet; destroyit: boolean = false): string;
var
  iCount: integer;
  t: integer;
  s: string;
begin
  s := '';
  for t:= 0 to ds.FieldCount-1 do begin
    s := s+'['+ds.FieldDefs[t].Name+']';
  end;
  s := s+#13#10;


  ds.First;
  while not ds.Eof do begin
    for t:= 0 to ds.FieldCount-1 do begin
      s := s+'['+ds.Fields[t].AsString+']';
    end;
    s := s+#13#10;
    ds.next;
  end;

  result := s;

end;

function RowsetToString(ds: TSERowSet; destroyit: boolean = false): string;
var
  iCount: integer;
  t,u: integer;
  s: string;
  iCount2: integer;
begin
  s := '';
  for t:= 0 to ds.FieldCount-1 do begin
    s := s+'['+ds.fields[t].sName+']'#9;
  end;
  s := s+#13#10;

  iCount2 := ds.RowCount;
//  if iCount2 > 10 then
//    iCount2 := 10;
  for u := 0 to iCount2-1 do begin
    for t:= 0 to ds.FieldCount-1 do begin
      s := s+'['+vartostr(ds.Values[t,u])+']'#9;
    end;
    s := s+#13#10;
  end;


  result := s;

end;
function RowsetToValues(ds: TSERowset; bIncludeSEFields: boolean; bTrim: boolean): string;
begin
  result := '';
  result := '('+RowToValues_NoParens(ds, bIncludeSEFields, bTrim)+')';

end;


function RowToValues_NoParens(ds: TSERowset; y: int64; bIncludeSEFields: boolean; bTrim: boolean): string;
var
  x: integer;
  v: variant;
  sRow: string;
begin
  result := '';
//  for y:= 0 to ds.RowCount-1 do begin
    sRow := '';
    for x:= 0 to ds.FieldCount-1 do begin
      if x > 0 then
        sRow := sRow+','+mysqlstoragestring.gvs(ds.Values[x,y])
      else begin
        if bIncludeSEFields then
          sRow := '0,'+mysqlstoragestring.gvs(ds.Values[x,y])
        else
          sRow := ''+mysqlstoragestring.gvs(ds.Values[x,y])
      end;
    end;

  result := sRow;


end;

function RowToValues_NoParens(ds: TSERowset; bIncludeSEFields: boolean; bTrim: boolean): string;
var
  x: integer;
  v: variant;
  sRow: string;
begin
  result := '';
//  for y:= 0 to ds.RowCount-1 do begin
    sRow := '';
    for x:= 0 to ds.FieldCount-1 do begin
      if x > 0 then
        sRow := sRow+','+mysqlstoragestring.gvs(ds.Values[x,ds.cursor])
      else begin
        if bIncludeSEFields then
          sRow := '0,'+mysqlstoragestring.gvs(ds.Values[x,ds.cursor])
        else
          sRow := ''+mysqlstoragestring.gvs(ds.Values[x,ds.cursor])
      end;
    end;

  result := sRow;


end;


function RowsetToSETStatement(ds: TSERowset): string;
var
  x,y: integer;
  v: variant;
  sRow: string;
begin
  if ds.RowCount > 1 then begin
    raise exception.create('Cannot use INSERT SET with more than more row in set');
  end;

  for y:= 0 to ds.RowCount-1 do begin
    sRow := '';
    for x:= 0 to ds.FieldCount-1 do begin
      if x > 0 then
        sRow := sRow+',';

      sRow := sRow+ds.fielddefs[x].sName+'='+mysqlstoragestring.gvs(ds.Values[x,y]);
    end;
  end;

  result := sRow;


end;

function FieldValuetoString(v: variant; vType: TFieldType): string;
begin
  case vType of
    ftTimeStamp: result := floattostr(v)
  else
    result := vartostr(v);
  end;
end;

function StringToFieldValue(s: string; fv: TFieldType): variant;
  procedure Unsupported;
  begin
    raise ECritical.create('unsupported type');
  end;
begin
//  s := trim(s);  NO!
  case  fv of
    ftUnknown: unsupported;
    ftString: exit(s);
    ftSmallint:exit(strtoint(s));
    ftInteger: exit(strtoint(s));
    ftWord: exit(strtoint(s));
    ftBoolean: exit(strtobool(s));
    ftFloat: exit(strtofloat(s));
    ftCurrency: exit(strtofloat(s));
    ftBCD: exit(strtoint(s));
    ftDate: exit(strtodatetime(s));
    ftTime: exit(strtodatetime(s));
    ftDateTime: exit(strtodatetime(s));
    ftBytes:unsupported;
    ftVarBytes: unsupported;
    ftAutoInc: unsupported;
    ftBlob: unsupported;
    ftMemo: exit(s);
    ftGraphic: unsupported;
    ftFmtMemo: exit(s);
    ftParadoxOle: unsupported;
    ftDBaseOle: unsupported;
    ftTypedBinary: unsupported;
    ftCursor: unsupported;
    ftFixedChar: unsupported;
    ftWideString: exit(s);
    ftLargeint:exit(strtoint(s));
    ftADT: unsupported;
    ftArray: unsupported;
    ftReference: unsupported;
    ftDataSet: unsupported;
    ftOraBlob: unsupported;
    ftOraClob: unsupported;
    ftVariant: exit(s);
    ftInterface: unsupported;
    ftIDispatch:unsupported;
    ftGuid: exit(s);
    ftTimeStamp: exit(strtofloat(s));
    ftFMTBcd: exit(strtofloat(s));
    ftFixedWideChar: exit(s);
    ftWideMemo: exit(s);
    ftOraTimeStamp: unsupported;
    ftOraInterval: unsupported;
    ftLongWord: exit(strtoint(s));
    ftShortint: exit(strtoint(s));
    ftByte: exit(strtoint(s));
    ftExtended:exit(strtofloat(s));
    ftConnection: unsupported;
    ftParams: unsupported;
    ftStream: unsupported;
    ftTimeStampOffset: unsupported;
    ftObject: unsupported;
    ftSingle: exit(strtofloat(s));
  else
    unsupported;
  end;

end;




{ TSEIndexFile }

function TSEIndexFile.AddrOf(val: int64): int64;
var
  t: ni;
begin
  for t:= 0 to Self.Count-1 do begin
    if Items[t].value = val then
      exit(t);
  end;

  exit(-1);

end;

procedure TSEIndexFile.Close;
begin
  fs.free;
  fs := nil;
end;

procedure TSEIndexFile.Detach;
begin
  if detached then exit;

  fs.free;
  fs := nil;

  inherited;

end;

function TSEIndexFile.GetCount: int64;
begin
  result := fs.size shr 4;
end;

function TSEIndexFile.Getitem(idx: int64): TIndexPair;
begin
  fs.Seek(idx shr 4, soBeginning);
  stream_GuaranteeRead(fs, @result, sizeof(result));
end;

procedure TSEIndexFile.Open(sFile: string; bForWriting: boolean);
begin
  close;

  if not fileexists(sFile) then
    TFileStream.create(sFile, fmCreate).Free;

  if bForWriting then begin
    fs := TMultiBufferMemoryFileStream.create(sFile, fmOpenReadWrite);
  end else begin
    fs := TMultiBufferMemoryFileStream.create(sFile, fmOpenRead);
  end;




end;

{ Tbti_Row }

function Tbti_Row.Compare(const [unsafe] ACompareTo: TBTreeItem): NativeInt;
var
  t: ni;
  other: Tbti_Row;
  f: ni;
begin
  other := Tbti_Row(acompareto);

  for t:= low(indexfieldIndexes) to high(indexfieldIndexes) do begin
    f := indexfieldIndexes[t];
    if desc[t] then begin
      if other.row.vals[f] > row.vals[f] then
        exit(-1);
      if other.row.vals[f] < row.vals[f] then
        exit(1);
    end else begin
      if other.row.vals[f] < row.vals[f] then
        exit(-1);
      if other.row.vals[f] > row.vals[f] then
        exit(1);
    end;
  end;

  exit(0);

end;

function FieldClassToRSfieldType(fc: TfieldClass): TFieldType;
begin
  if fc = DB.TIntegerField then
    exit(TFieldType.ftInteger);
  if fc = DB.TLargeintField then
    exit(TFieldType.ftLargeint);
  if fc = DB.TSmallintField then
    exit(TFieldType.ftSmallint);
  if fc = DB.TStringField then
    exit(TFieldType.ftString);
  if fc = TFloatField then
    exit(ftFloat);
  if fc = TBooleanField then
    exit(ftBoolean);
  if fc = TDateTimeField then
    exit(ftDateTime);
  if fc = TLongWordField then
    exit(TFieldType.ftLongWord);

  raise ECritical.create('unhandled field class '+fc.ClassName);


end;

{ TSERow }

function TSERow.GetWidth: ni;
begin
  result := lesserof(length(vals),mods.FlagCount);

end;

procedure TSERow.Init;
begin
  reset;
  deletepending := false;
end;

procedure TSERow.Reset;
begin
  //deletepending := false;  !! Deliberately do not reset deletepending, can still be used to ignore record
  //                         !! should we choose to skip deleting the record from the array (potentially slow)
  mods.reset;
  modded := false;
  appended := false;

end;

procedure TSERow.SetWidth(w: ni);
begin
  setlength(vals,w);
  mods.flagcount := w;

end;

end.
