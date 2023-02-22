unit Archiver;
{$I DelphiDefs.inc}
{x$DEFINE USE_MBFS}
{x$DEFINE LINKDEBUG}
{$DEFINE USE_ZONE_LOCKS}
{x$DEFINE DONT_COMPRESS_INITIAL}
//In order to make the archiver work, I need
//1. An Arc VAT that points to the most recent block3s for each zone
//2. A log of all changes, preferebly split into multiple files so I can more easily roll shit forward
//3. A list of paths where payloads will be placed
//4. A fileid-filename dictionary
//5. A master object that serves up the requests
//6. An RDTP Server

//[ ] Future Things needed for RDTP SERVER
//[ ] List Backup Stors
//[ ] New Backup Stor
//[ ]

{$IFNDEF CPUX64}
//  {$ERROR WTF}//this program makes use of int64 atomics
{$ENDIF}

{x$DEFINE FORCE_MODE_4}
{x$DEFINE VERIFY}

interface

uses
  betterobject, stringx, namevaluepair, search, debug,applicationparams, helpers_stream, numbers, generics.defaults, sharedobject, systemx, typex, classes, generics.collections, sysutils, virtualdiskconstants, queuestream, compression, zip, windows{beep}, MultiBufferMemoryFileStream, memoryfilestream, better_collections, tickcount, consolelock,  simplequeue, globalmultiqueue,dir, dirfile;


CONST
  BACKUP_DURATION = 365;
  MIRROR_FLAG =$4000000000000000;
  NULL_PIN = 0;
  ZONE_BUILDER_CACHE_SIZE = 96;
type
  ENoZone = class(Exception);
  EZoneRebuildError = class(Exception);
  TdataResult = (drNoDataToRebuild, drSuccess, drCriticalError);

  TArchiver = class;//
  ENoSpace = class(Exception);

  TArcStorHeader = packed record
    fileid: int64;
    parentfileid: int64;
  end;

  TArcEncoding =
    ( aeInvalid,  //0
      aeComplete, //1
      aeCompleteXor, //2
      aePartial, //3
      aePartialUncompressed,//4
      aePartialXor //5
    );

  TArcRecord = packed record
    logid: int64;
    Fparentfileid: int64;
    parentaddr: int64;
    startblock: cardinal;
    lengthInBlocks: cardinal;
    compressedLength: cardinal;
    Fencoding: byte;
    checksum: int64;
    logtime: TDateTime;
    zonechecksum: int64;
    FUNCTION DebugString: string;
    function IsValid: boolean;
    function checksumIsValid: boolean;
    procedure CalculateChecksum;
    function ToString: string;
    class operator equal(a,y: TArcRecord): boolean;
  private
    function GetEncoding: TArcEncoding;
    procedure SetEncoding(const Value: TArcEncoding);
    function GetParentfileID: int64;
  public
    property Encoding: TArcEncoding read GetEncoding write SetEncoding;
    procedure CheckLengths;
    property parentfileid: int64 read GetParentfileID write FParentFileId;

  end;

  TArcRecordEx = packed record
    fileid: int64;
    addr: int64;
    rec: TArcRecord;
    function DebugStr: string;
    class operator equal(a,y: TArcRecordEx): boolean;
  end;



  TArcRecordBuilder = packed record
    header: TARcRecord;
    data: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;

  end;

  TARcFileDef = record
    fileid: int64;
    filename: string;
  end;



  TArcFileDictionaryComparer = TComparer<TArcFileDef>;

{$IFDEF DICT}
  TArcFileDictionary = class(TSharedObject)
  private
    foundfileid: int64;
    FFileName: string;
    FPathForNewFiles: string;
    procedure SetFileName(value: string);
    function bsfunc(test: int64; op: TBinarySearchOp): int64;
  //ArcFileDictionary is a list of fileids and filenames
  strict protected
    FList: TList<TArcFileDef>;
    bsSearchVal: int64;
  public
    procedure Init;override;
    destructor Destroy;override;
    property FileName: string read FFileName write SetFileName;
    procedure Load(sFile: string = '');
    procedure Save;
    function FileIDtoFileName(fileid: int64): string;
    function NewFileID: int64;
    procedure Add(iFileID: int64; name: string; bNoSort: boolean = false);
    procedure Sort;
    property PathForNewFiles: string read FPathForNewFiles write FPathForNewfiles;
    end;
{$ENDIF}


  TArcVatEntry = packed record
    zoneidx: int64;
    logid: int64;
    fileid: int64;
    addr: int64;
    check: int64;
    function TOString: string;
    function CalcCheck:int64;
    procedure SetCalcCheck;
    function IsValid: boolean;
    procedure Init(zoneidx: int64);

  end;

{$IFDEF USE_MBFS}
  TLocalFileStream = TMemoryFileStream;
{$ELSE}
  TLocalFileStream = TFileStream;
{$ENDIF}
  TVatFileStream = TMemoryFileStream;

  TArcVat = class(TSharedObject)
  private
    FFileName: string;
    procedure SetFileName(value: string);
  //arcvat is a list of the fileids and final blocks associated with each ARC zone.
  protected
    FCachedNextID: int64;
    fs: TVatFileStream;
    function GetEntryAddress(idx: int64): int64;
  public
    procedure Init;override;
    procedure Detach;override;
    function GetEntry(idx: int64): TArcVatEntry;
    procedure PutEntry(ent: TArcVatEntry);
    procedure GrowEntries(toIdx: int64);
    property FileName: string read FFileName write SetFileName;
    function Getchecksum(zStart, zCount: int64): int64;
  end;



  TArcStor = class(TSharedObject)
  private
    FPath: string;
  protected
    fArc: TArchiver;
  public
    constructor Create(arch: TARchiver);reintroduce;virtual;
    destructor Destroy;override;

    property Path: string read FPath write FPath;

  end;

  TZoneStackInfo = record
        blockaddr: int64;
        blocklength: int64;
        toid: int64;
        nao: TDatetime;
  end;
  TZoneBuilder = class(TSharedObject)
  strict private
    FFs: IHolder<TLocalfileStream>;
    FSyncedFileStreamID: int64;
    scratch_ram: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;
    scratch_ram2: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;
    scratch_ram3: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;
    zip1,zip2,zip3,zip5: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;

    zone: array[0..ARC_ZONE_SIZE_IN_BYTES-1] of byte;
    completeness: array[0..ARC_ZONE_SIZE_IN_BLOCKS-1] of byte;
    zone_vatent: TArcVatEntry;
    zone_stack: array of TArcRecordEx;
    tmLastDebug: ticker;
  private
    procedure WipeZone(zoneidx: int64);
    procedure RebuildZone(bMirror: boolean; zoneidx: int64; pin: TDateTime; bFullDepth: boolean);
    function IsComplete: boolean;
    function RebuildData(bmirror: boolean; blockaddr: int64; pOutData: PByte; blocklength:int64; pin: TDateTime; prog: PProgress): int64;
    function RecordDataEx(bMirror: boolean; blockaddr: int64; pData: PByte; blocklength: int64; fromid: int64; toid: int64; var actual: int64; bShallow: boolean; nao: TDatetime): boolean;
    procedure CheckAndMoveZone;
    procedure OptDebug(s: string);
  public
    arc: TArchiver;
    rebuilt_zone_idx: int64;
    rebuilt_zone_pin: TDateTime;
    rebuilt_zone_logtime: TDateTime;
    rebuilt_zone_logid: int64;
    rebuilt_zone_full_depth: boolean;
    bad_zone: boolean;
    locked_fileid: int64;

    function SyncFS(ifileID: int64; bAllowCreate: boolean): TLocalFileSTream;
    function GetZoneStackReport(zidx: int64;logid: int64; fullstack: boolean): string;
    function GetZoneStackReportA(zidx: int64;logid: int64; fullstack: boolean): TArray<TZoneStackinfo>;
    function GetZoneChecksum(zoneidx: int64; pin: TDateTime; out iSum, iXor: int64): boolean;
    procedure Detach;override;
    destructor Destroy; override;
    constructor Create; override;
    procedure Lock; override;
    procedure Unlock; override;
    procedure ReplaceStreamFrom(otherzonebuilder: TZoneBuilder);
    procedure ReplaceStreamMirror();


  end;


  Tqi_LookForZone = class(TQueueItem)
  protected
    in_paths: TArray<string>;
    in_zone: int64;
    out_bestpath: string;
    procedure DoExecute; override;
  end;


  TArchiver = class(TSharedObject)
  private
    FVatPath: string;
    Fname: string;
    FConfigPrefix: string;
    FParamsFileName: string;

    procedure SEtVatPath(value: string);
    procedure GetName(value: string);

  strict protected
    FPAths: TStringlist;
    hint_pendingRebuilds: boolean;
{$IFDEF DICT}
    FFiles: TArcFileDictionary;
{$ENDIF}
    FVat: TARcVat;
    FStors: TList<TARcStor>;
    zone_builders: TSharedList<TZoneBuilder>;
    procedure LoadStors;
    procedure DestroyStors;


    function GetStor(idx: ni): TArcStor;
    procedure CleanupZoneBuilders;
  protected
    tmLastDebug: ticker;
    property vat: TArcVat read FVat;
    function NewFile: int64;
    procedure OptDebug(s: string);
  public
    zoneLocks: TNamedLocks;
    function NeedParams: TNameValuePairList;
    procedure NoNeedParams(nvpl: TNameValuepairList);
    function GetZoneRevision(idx: int64; logpin: TDateTime = NULL_PIN): int64;
    function SetZoneRevision(idx: int64; rev: int64): int64;
    function GetZoneRevisions(startidx: int64; count: int64; logpin: TDateTime = NULL_PIN): TDynInt64Array;
    property ConfigPrefix: string read FConfigPrefix;
    constructor Create;override;
    destructor Destroy;override;
    procedure GuaranteeRecordData(blockaddr: int64; pData: PByte; blocklength: int64);
    procedure GuaranteeRebuildData(bMirror: boolean; blockaddr: int64; pData: PByte; blocklength: int64; pin: TDateTime; prog: PProgress);


    function RebuildZone(bMirror: boolean; zoneidx: int64; pin: TDateTime): TZoneBuilder;//<<------------------------------------
    procedure AbridgeZone(zoneidx: int64; preserve_after: TdateTime);
    function AbridgeFileFromPath(sPath: string; maxsize: int64 = -1): boolean;
    function AbridgeFilesFromAllPaths(): boolean;
    function RecordDataEx(bMirror: boolean; blockaddr: int64; pData: PByte; blocklength: int64; fromid: int64; toid: int64; var actual: int64): boolean;
    procedure VerifyRecordedData(blockaddr: int64; pData: PByte; blocklength: int64; logid: int64; prog: PProgress);
    function RebuildData(bMirror: boolean; blockaddr: int64; pOutData: PByte; blocklength: int64; pin: TDateTime; prog: PProgress): int64;
    function GetZoneChecksum(zoneidx: int64; pin: TDateTime; out iSum, iXor: int64): boolean;
    function GetArcVatCheckSum(zStart, zCount: int64): int64;

    function StorCount: ni;
    function ChoosePath: string;
    property VatPath: string read FVatPath write SEtVatPath;
    property Name: string read Fname write GetName;
    procedure LoadConfig(sPrefix: string);
    procedure Test;
    property Stors[idx: ni]: TArcStor read GetStor;
    function GetNextLogID(zoneidx, iReserve: int64): int64;
    property ParamsFileName: string read FParamsFileName write FparamsFileNAme;
    function SyncZone(bMirror: boolean; zoneidx: int64; pin: TDateTime): TZoneBuilder;
{$IFDEF DICT}
    property Files: TArcFileDictionary read FFiles;
{$ENDIF}
    function GetZoneStackReport(zidx, logid: int64; fullstack: boolean): string;
    function GetZonePresenceHints(zstart, zcount: int64): TDynByteArray;
    function FindFileIDinStors(iFileID: int64): string;
    function GetStorPaths: TArray<string>;
    function BeginLookForZone(z: int64; paths: TArray<string>): Tqi_LookForZone;
  end;

function FileIDtoFileName(iFileID: int64): string;

function guaranteeOpen(sFile: string): TLocalfileStream;

function ArcEncodingToString(ae: TArcEncoding): string;

function IsMirrorZone(zoneidx: int64): boolean;
function GetMirroredZoneIdx(zoneid: int64): int64;


implementation


function ArcEncodingToString(ae: TArcEncoding): string;
begin
  result := 'UNKNOWN';
  case ae of
    aeInvalid: result := 'aeInvalid';
    aeComplete: result := 'aeComplete';
    aeCompleteXor: result := 'aeCompleteXor';
    aePartial: result := 'aePartial';
    aePartialUncompressed: result := 'aePartialUncompressed';
    aePartialXor: result := 'aePartialXor';
  end;


end;

{ TArcStor }

function guaranteeOpen(sFile: string): TLocalfileStream;
var
  bsuccess: boolean;
  bExists: boolean;
  tmStart: ticker;
const
  OPEN_TIMEOUT = 15000;
begin
  bSuccess := false;
  tmStart := GetTicker;
  repeat
    try
      bExists := fileexists(sFile);
      if bExists then
        result := TLocalFileStream.Create(sFile, fmOpenReadWRite+fmShareExclusive)
      else begin
        ForceDirectories(extractfilepath(sfile));
        result := TLocalfileStream.Create(sFile, fmCreate);
      end;
      bSuccess := true;
      if not (bSuccess) and (GetTimeSince(tmStart) > 1500) then begin
//        sleep(100);
        raise ECritical.create('failed to open: '+sFile);
      end;
    except
      if GetTimeSince(tmStart) > 6000 then
        raise
      else
        sleep(100);
    end;
  until bSuccess;
end;

function FileIDtoFileName(iFileID: int64): string;
begin
  result := inttohex((iFileID shr 14) shl 14,16)+'\'+inttohex(iFileID, 16)+'.arc';

end;



constructor TArcStor.Create(arch: TARchiver);
begin
  inherited Create;
  FArc := arch;
end;

destructor TArcStor.Destroy;
begin

  inherited;
end;



{ TArchiver }

function TArchiver.AbridgeFileFromPath(sPath: string; maxsize: int64): boolean;
begin
  exit;
  result := false;
  var dir := TDirectory.CreateH(sPath, '*.arc',0,0,false,false,false);
  dir.o.SortBySizeDesc;
  var fol := -1;
  var f := random(dir.o.filecount);
  var tryfolder := dir.o.foldercount > 0;

  if tryfolder then
    fol := random(dir.o.foldercount);

  if (fol > -1) and (fol<dir.o.foldercount) then
    result := AbridgeFileFromPath(dir.o.folders[fol].fullname, maxsize)
  else begin
    for var t:= 0 to dir.o.filecount-1 do begin
      if (maxsize < 0) or (dir.o.files[t].size < maxsize) then begin
        try
          var zidx := dir.o.files[t].NamePart;
          var izidx := StrToInt64('$'+zidx);
          AbridgeZone(izidx, now - BACKUP_DURATION);
          exit(true);
        except
          exit(false);
        end;
      end;
    end;
  end;

end;

var
  tmLastAbridge: ticker = 0;

function TArchiver.AbridgeFilesFromAllPaths: boolean;
begin
  result := false;
//  exit;
  if gettimesince(tmLastAbridge) < 30000 then
    exit(true);
  Lock;
  try
    tmLastAbridge := getticker;
    for var t := 0 to FStors.Count-1 do begin
      result := AbridgeFileFromPath(FStors[t].Path, -1);
      if result then break;
    end;
    tmLastAbridge := getticker;


  finally
    Unlock;
  end;
end;

procedure TArchiver.AbridgeZone(zoneidx: int64; preserve_after: TdateTime);
var
  scratch: array of byte;
const
  MIN_ABRIDGE_SIZE : int64 = 200000;
begin
  //rebuild zone, hold zone builder
  var mirroredidx := GetMirroredZoneIdx(zoneidx);
  if zonelocks.TryGetLock(zoneidx.tostring) then
  try
    if zonelocks.TryGetLock(mirroredidx.tostring) then
    try
      var oldfile := FindFileIDinStors(zoneidx);

      var sz := getfilesize(oldfile);
      if  sz < MIN_ABRIDGE_SIZE then
        exit;

      var newfile := FindFileIDinStors(mirroredidx);
      try
        if fileexists(newfile) then
          deletefile(pchar(newfile));
      except
      end;


      Debug.log('----------->ABRIDGE '+inttohex(zoneidx));

{      if not zone_builders.TryLock(8000) then begin
        Debug.log('Cannot abridge zones right now because we couldn''t get the zone builder lock');
        exit;
      end else try
        for var t := 0 to zone_builders.count-1 do begin
          if zone_builders[t].rebuilt_zone_idx = zoneidx then begin
            Debug.Log('cannot abridge zone right now'+inttohex(zoneidx)+' because it is currently in memory');
            exit;
          end;

          if zone_builders[t].rebuilt_zone_idx = mirroredidx then begin
            Debug.Log('cannot abridge zone right now'+inttohex(zoneidx)+' because it is currently in memory');
            exit;
          end;


        end;
        if zone_builders.HasZoneIndex(zoneidx) then
      finally
        zone_builders.unlock;
      end;}




      var sourcezone := RebuildZone(false, zoneidx, NULL_PIN);
      //get list of dates from zone
      var dates := sourcezone.GetZoneStackReportA(zoneidx,0, true);
      //setup targetzone
      var targetzone := RebuildZone(true, mirroredidx, NULL_PIN);
      //wipe target
      targetzone.RebuildZone(true, mirroredidx, NULL_PIN,false);
      targetzone.WipeZone(mirroredidx);
      //build appropriate dates in target


      setlength(scratch,ARC_ZONE_SIZE_IN_BYTES);
      var atleastone := false;
      for var t:= high(dates) downto 0 do begin
        var d := dates[t];
        //skip rebuilding this one UNLESS
        // -- it is the last one in the list
        // -- or it is newer than the preserve_after date
        if (t > 0)
        and (dates[t].nao < preserve_after) then
          continue;


        //rebuild the ENTIRE zone
        sourcezone.RebuildData(false, d.blockaddr and ARC_ZONE_BLOCK_BLOCK_ALIGN_MASK, @scratch[0], ARC_ZONE_SIZE_IN_BLOCKS, d.nao,nil);

        //blockaddr: int64;
        //pData: PByte;
        //blocklength: int64;
        //fromid: int64;
        //toid: int64;
        //var actual: int64;
        //bShallow:boolean;
        //nao: TDatetime): boolean;
        var act : int64 := int64(0);
        //record the entire zone at target

        optDebug('Abridging zone 0x'+inttohex(zoneidx,1)+' '+t.tostring+' remaining.');

        if not atleastone then begin
          targetzone.RecordDataEx(true, (d.blockaddr div ARC_ZONE_SIZE_IN_BLOCKS)*ARC_ZONE_SIZE_IN_BLOCKS, @scratch[0], ARC_ZONE_SIZE_IN_BLOCKS, targetzone.rebuilt_zone_logid, d.toid, act, false, d.nao)
        end else begin
          var zoneblockbase : int64 := (d.blockaddr div ARC_ZONE_SIZE_IN_BLOCKS)*ARC_ZONE_SIZE_IN_BLOCKS;
          targetzone.RecordDataEx(true, d.blockaddr, @scratch[(d.blockaddr - zoneblockbase) shl BLOCKSHIFT], d.blocklength, targetzone.rebuilt_zone_logid, d.toid, act, false, d.nao);
        end;

        atleastone := true;
      end;
      sourcezone.SyncFS(-1, false);
      targetzone.SyncFS(-1, false);

      oldfile := FindFileIDinStors(zoneidx);
      var backupfile := oldfile+'.backup';
      newfile := FindFileIDinStors(mirroredidx);
      try
        if fileexists(backupfile) then
          deletefile(pchar(backupfile));
        if GetFileSize(oldfile) > GetfileSize(newfile) then begin

          RenameFile(oldfile, backupfile);
          if fileexists(backupfile) and (not fileexists(oldfile)) then
            dir.CopyFile(newfile, oldfile);
            if fileexists(oldfile) then begin
              var entold := vat.getEntry(zoneidx);
              var ent := vat.GetEntry(mirroredidx);
              ent.zoneidx := entold.zoneidx;
              ent.fileid := entold.fileid;
              vat.PutEntry(ent);
              if fileexists(newfile) then
                deletefile(pchar(newfile));
{$DEFINE DELETE_BACKUPS}
{$IFDEF DELETE_BACKUPS}
              if fileexists(backupfile) then
                deletefile(pchar(backupfile));
{$ENDIF}
          end;
        end else begin
          //new file was not smaller
          Debug.log('Abridged file was not smaller '+oldfile);
              if fileexists(newfile) then
                deletefile(pchar(newfile));

        end;

        sourcezone.RebuildZone(false, zoneidx, NULL_PIN, false);

      except
        on E: Exception do begin
          debug.log('rollback! '+e.message);
          if fileexists(oldfile) then
            deletefile(pchar(oldfile));
          renamefile(backupfile, oldfile);
        end;
      end;
//      sourcezone.replacestreamfrom(targetzone);


    finally
      zonelocks.ReleaseLock(mirroredidx.tostring);
    end;
  finally
    zonelocks.ReleaseLock(zoneidx.tostring);
  end;




end;

function TArchiver.BeginLookForZone(z: int64; paths: TArray<string>): Tqi_LookForZone;
begin
  result := Tqi_LookForZone.Create;
  result.in_paths := paths;
  result.in_zone := z;
  GMQ.additem(result);
end;

function TArchiver.ChoosePath: string;
var
  best, t: ni;
  space, bestspace: int64;
  bestpath: string;
begin
  lock;
  try
    bestspace := -1;
    best := -1;
    for t:= 0 to FStors.Count-1 do begin
      ForceDirectories(Fstors[t].Path);
      space := GetFreeSpaceOnPath(Fstors[t].Path);
      if space > bestspace then begin
        bestpath := Fstors[t].path;
        bestspace := space;
        best := t;
      end;
    end;
    if best < 0 then begin
      raise ENoSpace.create('Could not determine best place for data. Possibly all stors critically low on space!');
    end;

    result := FStors[best].Path;

    if bestspace < 1000000000 then begin begin
      raise ENoSpace.create('All stors critically low on space!');
    end;
    end;
  finally
    unlock;
  end;


end;

procedure TArchiver.CleanupZoneBuilders;
var
  t: ni;
  zb : TZoneBuilder;
begin
  zone_builders.lock;
  try
    while zone_builders.count > 0 do begin
      zb := zone_builders[0];
      zone_builders.delete(0);
      zb.free;
      zb := nil;
    end;
  finally
    zone_builders.unlock;
  end;

end;

constructor TArchiver.Create;
begin
  inherited;
  zone_builders := TSharedList<TZoneBuilder>.create;
  fStors := TList<TArcStor>.create;
  FVat := TArcVat.Create;
{$IFDEF DICT}
  FFiles := TArcFileDictionary.Create;
{$ENDIF}

  zonelocks := TNAmedLocks.Create;


end;

destructor TArchiver.Destroy;
begin

  DestroyStors;
  CleanupZoneBuilders;
  zone_builders.Free;
  zone_builders := nil;
  FVat.Free;
  FVat := nil;
  FStors.free;
  FStors := nil;
  FPaths.Free;
  FPaths := nil;
{$IFDEF DICT}
  FFiles.Free;
  fFiles := nil;
{$ENDIF}
  zoneLocks.free;
  zonelocks := nil;

  inherited;
end;

procedure TArchiver.DestroyStors;
var
  stor: TArcStor;
begin
  while FStors.count > 0 do begin
    stor := FStors[0];
    FStors.delete(0);
    stor.Free;
    stor := nil;

  end;

end;

function TArchiver.FindFileIDinStors(iFileID: int64): string;
var
  t: ni;
  sOrigFile: string;
  sFile: string;
  bestfile: string;
  bestdate: TDateTime;
begin
  Lock;
  try
    bestDate := 0.0;
    bestfile := '';
    sOrigFile := FileIDToFileName(iFileID);
    for t:= 0 to StorCount-1 do begin
      sFile := Stors[t].Path+sOrigFile;
      if FileExists(sFile) then begin
        var fi := TFIleInformation.Create;
        try
          fi.LoadFromFile(sFile);
          if fi.Date > bestDate then begin
            bestfile := sFile;
            bestDate := fi.date;
          end;
        finally
          fi.free;
        end;
      end;
    end;
    //if file not found in stors then
    //choose a new path and return it
    if bestfile = '' then begin
      exit(ChoosePath+sOrigfile);
    end else begin
      result := bestfile;
    end;
  finally
    Unlock;
  end;
end;

function TArchiver.GetArcVatCheckSum(zStart,zCount: int64): int64;
begin
  result := self.vat.Getchecksum(zStart, zCount);
end;

procedure TArchiver.GetName(value: string);
begin
  Lock;
  try
    Fname := Value;
  finally
    Unlock;
  end;
end;


function TArchiver.GetStor(idx: ni): TArcStor;
var
  t: ni;
begin
  Lock;
  try
    result := Fstors[idx];
  finally
    Unlock;
  end;


end;

function TArchiver.GetStorPaths: TArray<string>;
begin
  Lock;
  try
    setlength(result, StorCount);
    for var t:= 0 to high(result) do begin
      result[t] := Stors[t].Path;
    end;
  finally
    Unlock;
  end;
end;

function TArchiver.GetZoneChecksum(zoneidx: int64; pin: TDateTime; out iSum,
  iXor: int64): boolean;
var
  builder: TZoneBuilder;
begin
  while hint_PendingRebuilds do
    sleep(10000);

  result := true;
{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(zoneidx), false);
{$ELSE}
  Lock;
{$ENDIF}
  try
    builder := SyncZone(false, zoneidx, pin);
    result := builder.getZoneChecksum(zoneidx, pin, iSum, iXor);

  finally
{$IFDEF USE_ZONE_LOCKS}
    zonelocks.ReleaseLock(inttostr(zoneidx), false);
{$ELSE}
    UnLock;
{$ENDIF}
  end;
end;

function TArchiver.GetZonePresenceHints(zstart, zcount: int64): TDynByteArray;
var
  qis: Tarray<Tqi_LookForZone>;
  paths: Tarray<string>;
begin
  var cx := zcount;
  var idx := zstart;
  var outidx := 0;
  paths := GetStorPaths;

  setlength(qis, cx);
  while cx > 0 do begin
    qis[outidx] := BeginLookForZone(idx, paths);
    inc(idx);
    inc(outidx);
    dec(cx);

  end;

  cx := zcount;
  idx := zstart;
  outidx := 0;
  setlength(result, cx);
  while cx > 0 do begin
    qis[outidx].WAitFor;
    if qis[outidx].out_bestpath <> '' then
      result[outidx] := 1
    else
      result[outidx] := 0;

    qis[outidx].free;
    qis[outidx] := nil;
    inc(idx);
    inc(outidx);
    dec(cx);
  end;

end;

function TArchiver.GetZoneRevision(idx:int64; logpin: TDateTime = NULL_PIN): int64;
var
  l: TArcVatEntry;
begin
  result := -2;
  FVat.Lock;
  try
    if idx < 0 then
      raise ECritical.create('illegal zone index '+inttostr(idx));
    l := FVat.GetEntry(idx);
    if logpin >0 then begin
      raise ECritical.create('Need to walk up through entries, but mechanism is not implemented nor defined with a logpin');
    end;
    result := l.logid;
  finally
    FVat.Unlock;
  end;
end;

function TArchiver.GetZoneRevisions(startidx, count: int64; logpin: TDateTime): TDynInt64Array;
var
  t: int64;
  ent: TARcVatEntry;
begin
  setlength(result, count);
  t := 0;
  vat.Lock;
  try
    while t< count do begin
      ent := vat.GetEntry(startidx+t);
      if not ent.IsValid then
        ent.Init(startidx+t);
      result[t] := ent.logid;
      inc(t);
    end;
  finally
    vat.unlock;
  end;

end;

function TArchiver.GetZoneStackReport(zidx, logid: int64; fullstack: boolean): string;
var
  builder: TZoneBuilder;
begin
{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(zidx), false);
{$ENDIF}
  Lock;
  try
    builder := SyncZone(false, zidx, logid);
    result := builder.GetZoneStackReport(zidx, logid, fullstack);
  finally
    unlock;
{$IFDEF USE_ZONE_LOCKS}
    zonelocks.ReleaseLock(inttostr(zidx), false);
{$ENDIF}

  end;

end;

function TZoneBuilder.GetZoneStackReport(zidx: int64;logid: int64; fullstack: boolean): string;
var
  t: ni;
begin
  Lock;
  try
    RebuildZone(false, zidx, logid, fullstack);
    result := inttohex(zidx,1)+'::';
    for t:= 0 to high(zone_stack) do begin
      result := result + zone_stack[t].DebugStr+CRLF;
    end;
  finally
    Unlock;
  end;
end;

function TZoneBuilder.GetZoneStackReportA(zidx, logid: int64;
  fullstack: boolean): TArray<TZoneStackinfo>;
var
  t: ni;
begin
  Lock;
  try
    RebuildZone(false, zidx, logid, fullstack);
    setlength(result, length(zone_stack));
    for t:= 0 to high(zone_stack) do begin
      result[t].nao := zone_stack[t].rec.logtime;
      result[t].blockaddr := zone_stack[t].rec.startblock + (zidx * ARC_ZONE_SIZE_IN_BLOCKS);
      result[t].blocklength := zone_stack[t].rec.lengthInBlocks;
      result[t].toid := zone_stack[t].rec.logid;


    end;
  finally
    Unlock;
  end;
end;

procedure TArchiver.GuaranteeRecordData(blockaddr: int64; pData: PByte;
  blocklength: int64);
var
  iRecordedBlocks: int64;
  iToRecord: int64;
  iJustRecorded: int64;
  bRan: boolean;
begin
  raise ECritical.create('deprecated');
  iRecordedBlocks := 0;
  iToRecord := blocklength;
  bRan := false;
  while (not bRan) or (iToRecord > 0) do begin
    bRan := true;
    iToRecord := blocklength-iRecordedBlocks;
    iJustRecorded := 0;//RecordDataEx(blockAddr, @pData[iRecordedBlocks*BLOCKSIZE], iToRecord);
    inc(iRecordedBlocks, iJustRecorded);
    dec(iToRecord, iJustRecorded);
    inc(blockAddr, iJustRecorded);
  end;

end;

procedure TArchiver.GuaranteeRebuildData(bMirror: boolean; blockaddr: int64; pData: PByte;
  blocklength: int64; pin: TDateTime; prog: PProgress);
var
  iTotal: int64;
  iTo: int64;
  iJust: int64;
begin
  iTotal := 0;
  iTo := blocklength;
  while iTo > 0 do begin
    hint_PendingRebuilds := true;
    iJust := RebuildData(bMirror, blockAddr, @pData[iTotal*BLOCKSIZE], iTo, pin, prog);
    inc(iTotal, iJust);
    dec(iTo, iJust);
    inc(blockAddr, iJust);
  end;
  hint_pendingRebuilds := false;
end;


function TZoneBuilder.IsComplete: boolean;
var
  t: ni;
begin
  result := false;
  for t:= 0 to high(completeness) do begin
    if completeness[t] = 0 then
      exit;
  end;

  result := true;

end;

function IsMirrorZone(zoneidx: int64): boolean;
begin
  result := (zoneidx and MIRROR_FLAG) <> 0;

end;

procedure TZoneBuilder.Lock;
begin
  inherited;
//  Debug.Log(self, 'locked '+sect.RecursionCount.tostring);
//  if sect.recursioncount = 2 then
//    Debug.Log('trap');

end;

procedure TZoneBuilder.OptDebug(s: string);
begin
  if gettimesince(tmLastDebug) > 2000 then begin
    debug.log(self, s);
    tmLastDebug := getticker;

  end;
end;

procedure TArchiver.LoadConfig(sPrefix: string);
var
  ap: TAppParams;
  t,cnt: ni;
  stor: TArcStor;
begin
  ap := NeedAppParams;
  try
    FconfigPrefix := sPrefix;
    name := ap.GetItemEx(sPrefix+'Name', '');
    VatPath := ap.GetItemEx(sPrefix+'VatPath', '');
{$IFDEF DICT}
    FFiles.FileName := vatpath+'dictionary.dict';
{$ENDIF}
    ParamsFileName := vatpath+'params.params';
//    FFiles.Load;

  finally
    NoNeedAppParams(ap);
  end;

  LoadStors;

  Test;


end;

procedure TArchiver.LoadStors;
var
  ap: TAppParams;
  iCount: ni;
  t: ni;
  sStor: string;
  s: TArcStor;
begin
  ap := NeedAppParams;
  try
    iCount := ap.GetItemEx(ConfigPrefix+'StorCount', 1);
    for t:= 0 to iCount-1 do begin
      sstor := ap.GetItemEx(ConfigPrefix+'Stor'+inttostr(t)+'Path', slash(VatPath)+'1stStor\');
      Debug.Log(self, 'Stor'+inttostr(t)+'='+sstor);


      s := TArcStor.Create(self);
      s.Path := sStor;
      ForceDirectories(sStor);
      FStors.Add(s);
    end;
  finally
    noneedappParams(ap);
  end;

end;

function TArchiver.NeedParams: TNameValuePairList;
begin
  Lock;
  result := TNameValuePairList.create;
  result.AutoAdd := true;
  result.LoadFromFile(self.ParamsFileName);


end;

function TArchiver.NewFile: int64;
begin

//  raise ECritical.create('unimplemented');
//TODO -cunimplemented: unimplemented block
end;

{$IFDEF DICT}
function TArchiver.NewFile: int64;
var
  sPath: string;

begin
  Lock;
  try
    sPath := ChoosePath;
    fFiles.PathForNewFiles := sPath;
    result := FFiles.NewfileID;
  finally
    unlock;
  end;


end;
{$ENDIF}

procedure TArchiver.NoNeedParams(nvpl: TNameValuepairList);
begin
  nvpl.SaveToFile;
  nvpl.free;
  Unlock;
end;

procedure TArchiver.OptDebug(s: string);
begin
  if gettimesince(tmLastDebug) > 200 then begin
    debug.log(self, s);
    tmLastDebug := getticker;
  end;
end;

function TZoneBuilder.RebuildData(bmirror: boolean; blockaddr: int64; pOutData: PByte;
  blocklength: int64; pin: TdateTime; prog: PProgress): int64;
var
  zoneidx: ni;
  oldent, ent: TArcVatEntry;
  rec: TArcRecordEx;
  fs: TLocalFileStream;
  parent_stack: array of TArcRecordEx;
  t,idx: ni;
  byte_start, byte_can,block_start, block_can: int64;

begin
//  DEBUG.Log('RebuildData->Lock');
  Lock;
//  DEBUG.Log('RebuildData<-Lock');
  try

    zoneidx := blockaddr shr ARC_ZONE_BLOCK_SHIFT;
    if bmirror then
      zoneidx := zoneidx or MIRROR_FLAG;

//    DEBUG.Log('RebuildData->RebuildZone');
    RebuildZone(bMirror, zoneidx, pin,false);
//    DEBUG.Log('RebuildData<-RebuildZone');

    //extract the specific part that we want

    block_start := (blockaddr and ((1 shl ARC_ZONE_BLOCK_SHIFT)-1));
    block_can := ARC_ZONE_SIZE_IN_BLOCKS - block_start;
    block_can := lesserof(block_can, blocklength);
    byte_start := block_start shl BLOCKSHIFT;
    byte_can := block_can shl BLOCKSHIFT;
    result := block_can;


//    DEBUG.Log('RebuildData->Movemem32');
    movemem32(pOutdata, @zone[byte_start], byte_can);
//    DEBUG.Log('RebuildData<-movemem32');


  finally
//    SyncFS(-1, false);
//    DEBUG.Log('RebuildData->Unlock');
    Unlock;
//    DEBUG.Log('RebuildData<-Unlock');
  end;

end;

procedure TZoneBuilder.RebuildZone(bMirror: boolean; zoneidx: int64; pin: TDateTime; bFullDepth: boolean);
var
  oldent, ent: TArcVatEntry;
  rec: TArcRecordEx;
  fs: TLocalFileStream;
  t,idx: ni;
  junk: int64;
  bNeed: boolean;
  start: ni;
  bDone: boolean;
  newrec: TARcRecordEx;
  tmStart, tmDif: ticker;
  trapped: boolean;
  function checkIfDone: boolean;
  var
    x: ni;
  begin
    result := true;
    for x:= 0 to ARC_ZONE_SIZE_IN_BLOCKS-1 do begin
      if completeness[x] = 0 then begin
        result := false;
        break;
      end;
    end;
  end;
    procedure ParialXorCopy;
    var t: ni;
    begin
            start := rec.rec.startblock shl BLOCKSHIFT;
            if rec.rec.lengthInBlocks > 0 then
            for t:= 0 to (ni(rec.rec.lengthInBlocks) shl BLOCKSHIFT)-1 do begin
              zone[t+start] := zone[t+start] xor scratch_ram2[t+start];
            end;
    end;

    procedure PartialFullUncompressedCopy;
    var t: ni;
    begin
            start := rec.rec.startblock shl BLOCKSHIFT;
            if rec.rec.lengthInBlocks > 0 then
            for t:= 0 to (ni(rec.rec.lengthInBlocks) shl BLOCKSHIFT)-1 do begin
              zone[t+start] := scratch_ram[t+start];
            end;
    end;
    procedure PartialCopy;
    var t: ni;
    begin
            start := rec.rec.startblock shl BLOCKSHIFT;
            if rec.rec.lengthInBlocks > 0 then
            for t:= 0 to (ni(rec.rec.lengthInBlocks) shl BLOCKSHIFT)-1 do begin
              zone[t+start] := scratch_ram2[t+start];
            end;
    end;

    procedure XORCopy;
    var t: ni;
    begin
            for t:= 0 to ARC_ZONE_SIZE_IN_BYTES-1 do begin
              zone[t] := zone[t] xor scratch_ram2[t];
            end;
    end;
    procedure CompleteCopy;
    var t: ni;
    begin
            for t:= 0 to ARC_ZONE_SIZE_IN_BYTES-1 do begin
              zone[t] := scratch_ram2[t];
            end;
    end;

    procedure CopyScratchRam;
    var t: ni;
    begin
          for t:= 0 to (ARC_ZONE_SIZE_IN_BYTES)-1 do begin
            zone[t] := scratch_ram2[t];
          end;
    end;

begin
  rebuilt_zone_logtime := 0.0;
//  DEBUG.Log('->RebuildZone');
  {$IFDEF LINKDEBUG}Debug.Log('Rebuild '+zoneidx.ToHexString+' at '+datetimetostr(pin));{$ENDIF}
  if (rebuilt_zone_idx = zoneidx) and (rebuilt_zone_pin = pin) and (rebuilt_zone_full_depth= bFullDepth) then
    exit;

  if (zoneidx = 0) then begin

  end;

  rebuilt_zone_logid := 0;
  setlength(zone_stack, 0);
  idx := length(zone_stack);

  //pass <0 to clean-up/flush rebuilt zone
  if zoneidx < 0 then begin
    rebuilt_zone_idx := -1;
    rebuilt_zone_pin := NULL_PIN;
    rebuilt_zone_logid := -1;
    rebuilt_zone_full_depth := false;
    SyncFS(-1,false);
    exit;
  end;

  Debug.Log([ltThread], self,'Rebuild zone '+zoneidx.tohexstring+' to '+datetimetostr(pin));
  tmStart := GetTicker;
  Lock;
  try

    try
      fillmem(@zone[0], ARC_ZONE_SIZE_IN_BYTES,0);
      //find/create new ArcVat Entry
      ent.fileid := -1;
      ent.logid := 0;
      ent := arc.Vat.GetEntry(zoneidx);
      if ent.zoneidx <> zoneidx then begin
        ent.zoneidx := 0;
        ent.fileid := -1;
        ent.addr := 0;
        ent.logid := -1;
      end;

      if (ent.fileid < 0) or (ent.logid < 0) then begin
  {$IFDEF VERIFY}      Debug.Log(self,'zone doesn'' exist, initializing '+inttostr(zoneidx));{$ENDIF VERIFY}
        zone_vatent := ent;
        fillmem(@zone[0], ARC_ZONE_SIZE_IN_BYTES, 0);
        setlength(zone_stack,0);
        rebuilt_zone_idx := zoneidx;
        rebuilt_zone_logid := 0;
        exit;
      end;


  {$IFDEF VERIFY}    Debug.Log(self,'synfs '+inttostr(ent.fileid)); {$ENDIF}
      //switch to desired file
      if ent.zoneidx <> zoneidx then begin
        ent.zoneidx := zoneidx;
        ent.fileid := -1;
        ent.addr := -1;

      end;

      if not ent.IsValid then
        raise ECritical.create('catastrophe '+ent.tostring);
      fs := SyncFS(zoneidx, false);
      if fs = nil then
        exit;

      //read last entry
      if ent.addr < 0 then
        raise Ecritical.create('Bad Zone, entry address < 0 '+ent.addr.tostring);
      fs.Seek(ent.addr, soBeginning);
      if ent.fileid <> Self.FSyncedFileStreamID then
        raise ECritical.create('trying to read but the fileids did not match');
      rec.fileid := ent.fileid;
      rec.addr := ent.addr;


      if fs.Size >= fs.position+sizeof(rec.rec) then
        stream_GuaranteeRead(fs, @rec.rec, sizeof(rec.rec));//<<------FIRST RECORD

      rebuilt_zone_logid := rec.rec.logid;
      rebuilt_zone_logtime := rec.rec.logtime;


      if (not rec.rec.IsValid) or (ent.addr < 0) or ((ent.addr+sizeof(rec.rec)) > fs.Size) then begin
        debug.Log(self,'BAD ZONE! '+inttostr(zoneidx));
        windows.beep(1000,25);
        zone_vatent := ent;
        ent.fileid := -1;
        arc.vat.PutEntry(ent);
        fillmem(@zone[0], ARC_ZONE_SIZE_IN_BYTES, 0);
        setlength(zone_stack,0);
        rebuilt_zone_idx := zoneidx;
        rebuilt_zone_pin := pin;
        rebuilt_zone_full_depth := bFullDepth;
        rebuilt_zone_logid := 0;
        exit;
      end;




      //record file and addr in extended record
      rec.fileid := ent.fileid;
      rec.addr := ent.addr;



      //read the record
  //    stream_GuaranteeREad(fs, @rec.rec, sizeof(rec.rec));
      idx := length(zone_stack);

      Fillmem(@completeness[0], ARC_ZONE_SIZE_IN_BLOCKS, 0);


      //if we need it, put it in the stack
      if (pin = NULL_PIN) or (rec.rec.logtime <= pin) then begin
      {$IFDEF LINKDEBUG}Debug.Log('(init) We need this: '+rec.DebugStr);{$ENDIF}
        setlength(zone_stack,idx+1);
        zone_stack[idx] := rec;
        inc(idx);
      {$IFDEF LINKDEBUG}Debug.Log(self,'add to stack '+rec.DebugStr);{$ENDIF}

        rec.rec.checkLengths;
        if (rec.rec.encoding in [aeComplete, aePartialUncompressed,aePartial]) then begin
          for t:= ni(rec.rec.startblock) to (ni(rec.rec.startblock)+ ni(rec.rec.lengthInBlocks)-ni(1)) do begin
            completeness[t] := 1;
          end;
        end;
      end;




      //inc(idx);

      //------------------------------------------
      //------------------------------------------
      //work back through parents
      //------------------------------------------
      //------------------------------------------
      while (rec.rec.parentfileid >= 0) do begin
        if not rec.rec.IsValid then begin
          Debug.Log('Invalid rec, breaking.');
          break;
        end;

        //if completeness[] is all 1s then we can stop looking backwards
        bdone := (not bFullDepth) and checkifdone;
        if bFullDepth then
          bDone := rec.rec.parentfileid < 0;
        if bDone then break;



  {$IFDEF LINKDEBUG}
    if idx = 0 then
      debug.log('idx=0');
    debug.log(self,'Walk Back Link '+inttostr(idx-1)+' ent='+rec.rec.ToSTring);
{$ENDIF}
        Optdebug('Walk Back Link '+inttostr(idx-1)+' ent='+rec.rec.ToSTring);
        if self.FSyncedFileStreamID <> rec.rec.parentfileid then
          raise ENotSupportedException.Create('parenting to different file id ('+inttohex(rec.rec.parentfileid,1)+') in this zone '+inttohex(FSyncedFileStreamID,1)+' is not supported');
        fs := SyncFS(rec.rec.parentfileid,false);
        if rec.rec.parentaddr < 0 then begin
          debug.Log(self, 'BAD ZONE PARENT! '+inttostr(zoneidx));
          raise ECritical.create('BAD ZONE PARENT '+inttostr(zoneidx));
        end;
        fs.Seek(rec.rec.parentaddr, soBeginning);
        //record parents fileid/addr as new record's local addr/fileid
        rec.fileid := greaterof(rec.rec.parentfileid,-1);
        if rec.fileid < 0 then begin
          Debug.Log('No more data history, breaking');
          break;
        end;
        rec.addr := rec.rec.parentaddr;
        //read subrec from parent location
        stream_GuaranteeREad(fs, @newrec.rec, sizeof(newrec.rec));
        if newrec.rec = rec.rec then begin
          debug.Log(self,'BAD ZONE! Circular! '+inttostr(zoneidx));
          windows.beep(1000,25);
          zone_vatent := ent;
          ent.fileid := -1;
          arc.vat.PutEntry(ent);
          fillmem(@zone[0], ARC_ZONE_SIZE_IN_BYTES, 0);
          setlength(zone_stack,0);
          rebuilt_zone_idx := zoneidx;
          rebuilt_zone_pin := pin;
          rebuilt_zone_full_depth := bFullDepth;
          rebuilt_zone_logid := 0;
          exit;

        end;
        rec.rec := newrec.rec;


        //determine if we need this record, if we don't then break
        //if we need this record, put it on the stack
        if (pin = NULL_PIN) or (rec.rec.logtime <= pin) then begin
      {$IFDEF LINKDEBUG}Debug.Log('(parent) We need this: '+rec.DebugStr);{$ENDIF}
          rec.rec.checkLengths;
          if (rec.rec.encoding in [aeComplete, aePartialUncompressed,aePartial]) then begin
            for t:= ni(rec.rec.startblock) to (ni(rec.rec.startblock)+ ni(rec.rec.lengthInBlocks)-ni(1)) do begin
              completeness[t] := 1;
            end;
          end;
          //put the record in the stack
          setlength(zone_stack,idx+1);
          zone_stack[idx] := rec;
          {$IFDEF VERIFY}      Debug.Log(self,'add to stack '+rec.DebugStr);{$ENDIF}
          inc(idx);

        end else begin
      {$IFDEF LINKDEBUG}OptDebug('(parent) We DONT need this: '+rec.DebugStr);{$ENDIF}
          OptDebug('(parent) We DONT need this: '+rec.DebugStr);
        end;

      end;

      Fillmem(@completeness[0], ARC_ZONE_SIZE_IN_BLOCKS, 0);
//      if high(zone_stack) < 0 then
//        raise ENoZone.create('No zone was found '+idx.tohexstring );
      //------------------------------------------
      //------------------------------------------
      //work forward through children
      //------------`------------------------------
      //------------------------------------------
      for idx := high(zone_stack) downto 0 do begin

        {$ifdef LINKDEBUG}Debug.log(self, 'zone_stack high='+high(zone_stack).tostring);{$ENDIF}
        rec := zone_stack[idx];
  {$IFDEF LINKDEBUG}      debug.log(self,'Walk Forward Link '+inttostr(idx)+' ent='+rec.rec.ToSTring);{$ENDIF}
  {$IFDEF LINKDEBUG}      Debug.Log(self,'work forward***');{$ENDIF}
  {$IFDEF LINKDEBUG}      Debug.Log(self,'['+inttostr(idx)+'] '+rec.DebugStr);{$ENDIF}
        Optdebug('Forward: '+'['+inttostr(idx)+'] '+rec.DebugStr);
        if self.FSyncedFileStreamID <> rec.fileid then
          raise ENotSupportedException.Create('switching to different file id ('+inttohex(rec.fileid,1)+') in this zone '+inttohex(FSyncedFileStreamID,1)+' is not supported');

        fs := SyncFS(rec.fileid, false);
        fs.Seek(rec.addr+sizeof(rec.rec), soBeginning);
        //read the compressed stream
        //stream_GuaranteeRead(fs, @rec.rec, sizeof(rec.rec));

        if rec.rec.compressedLength > sizeof(scratch_ram) then
          raise ECritical.Create('scratch ram is not big enough for '+inttostr(rec.rec.compressedLength)+' bytes.');
        stream_guaranteeread(fs, @scratch_ram[0], rec.rec.compressedLength);
        if rec.rec.encoding <> TArcEncoding(4) then begin
          unzipram(@scratch_ram[0], @scratch_ram2[rec.rec.startblock shl (BLOCKSHIFT)], rec.rec.compressedLength, ARC_ZONE_SIZE_IN_BYTES, nil);
        end else begin
          movemem32(@scratch_ram2[rec.rec.startblock shl (BLOCKSHIFT)], @scratch_ram[0], rec.rec.compressedLength);
        end;

        if idx = high(zone_stack) then begin
          CopyScratchRam;

        end else begin
          //1 = complete copy
          if rec.rec.encoding = TArcEncoding.aeComplete then begin
            CompleteCopy;
          end else
          //2 = xor copy
          if rec.rec.encoding = TArcEncoding.aeCompleteXor then begin
            XORCopy;
          end else
          //3 = partial copy
          if rec.rec.encoding = TArcEncoding.aePartial then begin
            PartialCopy;
          end else
          //4 = partial/full copy uncompressed
          if rec.rec.encoding = TArcEncoding.aePartialUncompressed then begin
            PartialFullUncompressedCopy;
          end;
          //5 = partial xor copy
          if rec.rec.encoding = TArcEncoding.aePartialXor then begin
            ParialXorCopy;
          end;
        end;
      end;

      rebuilt_zone_idx := zoneidx;
      rebuilt_zone_pin := pin;
      rebuilt_zone_full_depth := bFullDepth;
      zone_vatent := ent;


    except
      on E: Exception do begin
        debug.Log(self,'BAD ZONE! '+inttostr(zoneidx)+' Exception: '+E.Message);
        windows.beep(1000,25);
        zone_vatent := ent;
        ent.fileid := -1;
        arc.vat.PutEntry(ent);
        fillmem(@zone[0], ARC_ZONE_SIZE_IN_BYTES, 0);
        setlength(zone_stack,0);
        rebuilt_zone_idx := zoneidx;
        rebuilt_zone_pin := pin;
        rebuilt_zone_logid := 0;
        exit;
      end;
    end;

  finally
    rebuilt_zone_idx := zoneidx;//even in case zone is bad, we still need to flag that we rebuilt it
    rebuilt_zone_pin := pin;//even in case zone is bad, we still need to flag that we rebuilt it
    tmDif := GetTimeSince(tmStart);
    Debug.Log([ltThread], self,'Rebuilt zone '+inttohex(zoneidx,1)+' at logtime '+datetimetostr(rebuilt_zone_logtime)+' logid '+rebuilt_zone_logid.tostring+' in '+tmDif.tostring+'ms.');
    if tmDif > 8000 then begin
      try
        if pin <= strtoDateTime('12/30/1899') then
          RecordDataEx(bMirror,zoneidx * ARC_ZONE_SIZE_IN_BLOCKS, @zone[0], ARC_ZONE_SIZE_IN_BLOCKS, rebuilt_zone_logid, rebuilt_zone_logid,junk,true,rebuilt_zone_logtime);
      finally
      end;
    end;
//    setlength(zone_stack,0);
    Unlock;
//    DEBUG.Log('<-RebuildZone');
  end;



end;

function TArchiver.RebuildData(bMirror: boolean; blockaddr: int64; pOutData: PByte;
  blocklength: int64;
  pin: TdateTime; prog: PProgress): int64;
var
  builder: TZoneBuilder;
begin
    hint_pendingRebuilds := true;
{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(blockaddr shr ARC_ZONE_BLOCK_SHIFT), false);
//  zonelocks.GetLock('diskopt');
{$ELSE}
  Lock;
{$ENDIF}
  try
    hint_pendingRebuilds := true;
//    dEBUG.lOG('RebuildData->SyncZone');
    builder := SyncZone(bMirror, blockaddr shr ARC_ZONE_BLOCK_SHIFT, pin);
//    DEBUG.lOG('RebuildData<-SyncZone');
//    DEBUG.Log('RebuildData->builder.RebuildData');
    hint_pendingRebuilds := true;
    result := builder.RebuildData(bMirror, blockaddr, poutdata, blocklength, pin, prog);
//    DEBUG.Log('RebuildData<-builder.RebuildData');
  finally
{$IFDEF USE_ZONE_LOCKS}
//    zonelocks.ReleaseLock('diskopt',false);
    zonelocks.ReleaseLock(inttostr(blockaddr shr ARC_ZONE_BLOCK_SHIFT), false);

{$ELSE}
    UnLock;
{$ENDIF}
  end;
end;

function TArchiver.RebuildZone(bMirror: boolean; zoneidx: int64; pin: TDateTime): TZoneBuilder;
begin
  result := nil;
  try
    if bMirror then
      zoneidx := zoneidx or MIRROR_FLAG;
    zoneLocks.GetLock(zoneidx.tostring, false);
    try
       result := SyncZone(bMirror, zoneidx, pin);
    finally
      zoneLocks.ReleaseLock(zoneidx.tostring, false);
    end;
  except
    result := nil;
  end;
end;

function TArchiver.RecordDataEx(bMirror: boolean; blockaddr: int64; pData: PByte; blocklength,
  fromid, toid: int64; var actual: int64): boolean;
var
  builder: TZoneBuilder;
  l: TArcVatEntry;
begin

{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(blockaddr shr ARC_ZONE_BLOCK_SHIFT),false);
//  zonelocks.GetLock('diskopt');
{$ELSE}
  Lock;
{$ENDIF}
  try
    builder := SyncZone(bMirror, blockaddr shr ARC_ZONE_BLOCK_SHIFT, NULL_PIN);
    result := builder.RecordDataEx(bMirror, blockaddr, pdata, blocklength, fromid, toid, actual, false, now);
    l := FVat.GetEntry(blockaddr shr ARC_zONE_BLOCK_SHIFT);
    l.logid := builder.rebuilt_zone_logid;
    FVat.PutEntry(l);
  finally
{$IFDEF USE_ZONE_LOCKS}
//    zonelocks.ReleaseLock('diskopt',false);
    zonelocks.ReleaseLock(inttostr(blockaddr shr ARC_ZONE_BLOCK_SHIFT), false);
{$ELSE}
    UnLock;
{$ENDIF}
  end;
end;


function TZoneBuilder.RecordDataEx(bMirror: boolean; blockaddr: int64; pData: PByte; blocklength,
  fromid: int64;  toid:int64; var actual: int64; bShallow: boolean; nao: TDatetime): boolean;
var
  zoneidx: ni;
  t: ni;
  oldent, ent: TArcVatEntry;
  rec: TArcRecord;
  recex: TArcRecordEx;
  fs: TLocalFileStream;
  newlen: ni;
  bytelength: int64;
  block_start, block_can, byte_start, byte_can: uint64;
  pbSrc, pbDest1,pbDest2: pbyte;
  l1,l2,l3,l5: int64;
  z1,z2,z3,z5: Tcmd_ZipRam;
  bCompressed: boolean;
  logid: int64;
  procedure TightSub1;
  var
    tt: nativeint;
  begin
    for tt := 0 to (byte_can-1) do begin
      //in scratch 1 - overwrite area
      pbDest1^ := pbSrc^;
      //in scratch 2 - xor area
      pbDest2^ := pbDest2^ xor pbSrc^;
      inc(pbSrc);
      inc(pbDest1);
      inc(pbDest2);
    end;
  end;
begin
{$IFDEF LOGID_DEBUG}  Debug.Log(self,'Log: '+inttohex(logid, 0));{$ENDIF}
  result := false;
  Lock;
  try
    zoneidx := blockaddr shr ARC_ZONE_BLOCK_SHIFT;
    if bmirror then
      zoneidx := zoneidx or MIRROR_FLAG;

//    if arc.Vat.FCachedNextID < 0 then
//      logid := arc.GetNextLogID(zoneidx, 1);
    logid := toid;

    //Rebuild Old Zone
    bytelength := blocklength * BLOCKsize;
    try
      try
        RebuildZone(bMirror, zoneidx,NULL_PIN, false);
      except
        on E: exception do begin
          bad_zone := true;
        end;
      end;

      ent := zone_vatent;
      oldent := zone_vatent;
    except
      on e: exception do begin
        bytelength := blocklength * BLOCKsize;
        ent := zone_vatent;
        oldent := zone_vatent;
        ent.fileid := -1;

      end;

    end;


    if rebuilt_zone_logid <> fromid then
      exit(false);

    logid := toid;



    //if virgin, then new files
    if ent.fileid < 0 then begin
      ent.Fileid := zoneidx;
      ent.addr := 0;
      ent.zoneidx := zoneidx;
    end;

    //determine how many bytes we can fit into this zone
    block_start := (blockaddr and ((1 shl ARC_ZONE_BLOCK_SHIFT)-1));
    block_can := lesserof(ARC_ZONE_SIZE_IN_BLOCKS - block_start, blocklength);
    actual := block_can;
    byte_start := block_start shl BLOCKSHIFT;
    byte_can := block_can shl BLOCKSHIFT;


    //move rebuilt zone into scratch ram
    movemem32(@scratch_ram[0], @zone[0], ARC_ZONE_SIZE_IN_BYTES);
    movemem32(@scratch_ram2[0], @zone[0], ARC_ZONE_SIZE_IN_BYTES);
    movemem32(@scratch_ram3[0], @zone[0], ARC_ZONE_SIZE_IN_BYTES);


    pbSrc := pData;
    pbDest1 := @scratch_ram[byte_start];
    pbDest2 := @scratch_ram2[byte_start];
    TightSub1();

    movemem32(@zone[0], @scratch_ram3[byte_start], byte_can);

//    debug.log(self,'-Rebuilt Zone- idx='+inttostr(zoneidx));
//    debug.log(self,MemoryToString(@zone, 128));
//    debug.log(self,'-Pre-Processed Before Compression-');
//    debug.log(self,MemoryToString(pData, 128));
//    debug.log(self,MemoryToString(@scratch_ram[0], 128));
//    debug.log(self,MemoryToString(@scratch_ram2[0], 128));




{$IFDEF DONT_COMPRESS_INITIAL}
    if rebuilt_zone_logid >0 then begin
{$ENDIF}
{$IFNDEF FORCE_MODE_4}
{$IFDEF NO_MT_ZIP}
    l1 := ZipRam(@scratch_ram[0],   @zip1[0], ARC_ZONE_SIZE_IN_BYTES, ARC_ZONE_SIZE_IN_BYTES);//method 1 copies block into rebuilt block
    l2 := ZipRam(@scratch_ram2[0],  @zip2[0], ARC_ZONE_SIZE_IN_BYTES, ARC_ZONE_SIZE_IN_BYTES);//method 2 XORs block with rebuilt block
    l3 := ZipRam(pData,             @zip3[0], block_can*BLOCKSIZE, ARC_ZONE_SIZE_IN_BYTES);//method  3 is partial verbatim data (multiple parents may still be needed to find complete data)
    l5 := ZipRam(@scratch_ram2[byte_start],@zip5[0], block_can*BLOCKSIZE, ARC_ZONE_SIZE_IN_BYTES);
{$ELSE}
    l1 := -1; l2 := -1;
    z2 := nil; z1 := nil;
    if block_can >= ARC_ZONE_SIZE_IN_BLOCKS shr 1 then begin
      z1 := Tcmd_ZipRam.BeginZipRam(@scratch_ram[0],   @zip1[0], ARC_ZONE_SIZE_IN_BYTES, ARC_ZONE_SIZE_IN_BYTES);//method 1 copies block into rebuilt block
      z2 := Tcmd_ZipRam.BeginZipRam(@scratch_ram2[0],  @zip2[0], ARC_ZONE_SIZE_IN_BYTES, ARC_ZONE_SIZE_IN_BYTES);//method 2 XORs block with rebuilt block
    end;
    z3 := Tcmd_ZipRam.BeginZipRam(pData,             @zip3[0], block_can*BLOCKSIZE, ARC_ZONE_SIZE_IN_BYTES);//method  3 is partial verbatim data (multiple parents may still be needed to find complete data)
    z5 := Tcmd_ZipRam.BeginZipRam(@scratch_ram2[byte_start],@zip5[0], block_can*BLOCKSIZE, ARC_ZONE_SIZE_IN_BYTES);

    if assigned(z1) then
      l1 := Tcmd_ZipRam.EndZipRam(z1);
    if assigned(z2) then
      l2 := Tcmd_ZipRam.EndZipRam(z2);
    l3 := Tcmd_ZipRam.EndZipRam(z3);
    l5 := Tcmd_ZipRam.EndZipRam(z5);
{$ENDIF}

    bCompressed := (l1>=0) or (l2>=0) or (l3>=0) or (l5>=0);


    if l1 < 0 then l1 := 999999999;
    if l2 < 0 then l2 := 999999999;
    if l3 < 0 then l3 := 999999999;
    if l5 < 0 then l5 := 999999999;
{$ENDIF}
{$IFDEF DONT_COMPRESS_INITIAL}
    end else begin
      bCompressed := false;
    end;
{$ENDIF}

    if (not bCompressed) {$IFDEF FORCE_MODE_4} or true{$ENDIF} or bShallow then begin
{$IFDEF METHOD_DEBUG}      Debug.Log('use method 4 (verbatim subset uncompressed) blockaddr='+inttohex(blockaddr,0));{$ENDIF}
      rec.logid := logid;

      rec.parentfileid := greaterof(oldent.fileid,-1);
      rec.parentaddr := oldent.addr;
      rec.startblock := blockaddr and ((1 shl ARC_ZONE_BLOCK_SHIFT)-1);
      rec.lengthinBlocks := block_can;
      rec.encoding := TArcEncoding.aePartialUncompressed;
      rec.compressedLength := block_can shl BLOCKSHIFT;
      //put the record into the file
      fs := SyncFS(ent.fileid,true);
      fs.Seek(0, soEnd);
      recex.addr := fs.Position;
      ent.addr := recex.addr;
      ent.zoneidx := rebuilt_zone_idx;
      ent.logid := logid;
      rec.logtime := nao;
      rec.CalculateChecksum;

      Stream_GuaranteeWrite(fs, pbyte(@rec), sizeof(rec));
      Stream_GuaranteeWrite(fs, pbyte(pData), rec.compressedlength);
    end else
    if (bad_zone) or ((l3 <= l2) and (l3 <=l1) and (l3 <= l5)) then begin
      //***BUIld THE RECORD
      //set/determine log id for new record
{$IFDEF METHOD_DEBUG}      Debug.Log('use method 3 (verbatim subset) blockaddr='+inttohex(blockaddr,0));{$ENDIF}
      rec.logid := logid;

      rec.parentfileid := greaterof(oldent.fileid,-1);
      rec.parentaddr := oldent.addr;
      rec.startblock := blockaddr and ((1 shl ARC_ZONE_BLOCK_SHIFT)-1);
      rec.lengthinBlocks := block_can;
      rec.encoding := TArcEncoding.aePartial;
      rec.compressedLength := l3;
      //put the record into the file
      fs := SyncFS(ent.fileid,true);
      fs.Seek(0, soEnd);
      recex.addr := fs.Position;
      ent.addr := recex.addr;
      ent.zoneidx := rebuilt_zone_idx;
      ent.logid := logid;
      rec.logtime := nao;
      rec.CalculateChecksum;
      Stream_GuaranteeWrite(fs, pbyte(@rec), sizeof(rec));
      Stream_GuaranteeWrite(fs, pbyte(@zip3[0]), l3);
    end else
    if (l5 <= l1) and (l5 <= l2) and (l5 <=l3) then begin
      //***BUIld THE RECORD
      //set/determine log id for new record
{$IFDEF METHOD_DEBUG}      Debug.Log('use method 5 (xor subset) blockaddr='+inttohex(blockaddr,0));{$ENDIF}
      rec.logid := logid;

      rec.parentfileid := greaterof(oldent.fileid,-1);
      rec.parentaddr := oldent.addr;
      rec.startblock := blockaddr and ((1 shl ARC_ZONE_BLOCK_SHIFT)-1);
      rec.lengthinBlocks := block_can;
      rec.encoding := TArcEncoding.aePartialXor;
      rec.compressedLength := l5;
      //put the record into the file
      fs := SyncFS(ent.fileid,true);
      fs.Seek(0, soEnd);
      recex.addr := fs.Position;
      ent.addr := recex.addr;
      ent.zoneidx := rebuilt_zone_idx;
      ent.logid := logid;
      rec.logtime := nao;
      rec.CalculateChecksum;
      Stream_GuaranteeWrite(fs, pbyte(@rec), sizeof(rec));
      Stream_GuaranteeWrite(fs, pbyte(@zip5[0]), l5);
    end
    else
    if (l1 <= l2) and (l1 <= l3) then begin
      //***BUIld THE RECORD
      //set/determine log id for new record
{$IFDEF METHOD_DEBUG}      Debug.Log('use method 1 (xor against full parent) blockaddr='+inttohex(blockaddr,0));{$ENDIF}
      rec.logid := logid;
      rec.parentfileid := greaterof(oldent.fileid,-1);
      rec.parentaddr := oldent.addr;
      rec.startblock := 0;
      rec.lengthinBlocks := ARC_ZONE_SIZE_IN_BLOCKS;
      rec.encoding := TArcEncoding.aeComplete;
      rec.compressedLength := l1;
      //put the record into the file
      fs := SyncFS(ent.fileid,true);
      fs.Seek(0, soEnd);
      recex.addr := fs.Position;
      ent.addr := recex.addr;
      ent.zoneidx := rebuilt_zone_idx;
      ent.logid := logid;
      rec.logtime := nao;
      rec.calculatechecksum;
      Stream_GuaranteeWrite(fs, pbyte(@rec), sizeof(rec));
      Stream_GuaranteeWrite(fs, pbyte(@zip1[0]), l1);
    end else
    begin

      //***BUIld THE RECORD
      //set/determine log id for new record
{$IFDEF METHOD_DEBUG}      Debug.Log('use method 2 (verbatim against full parent) blockaddr='+inttohex(blockaddr,0));{$ENDIF}
      rec.logid := logid;
      rec.parentfileid := greaterof(oldent.fileid, -1);
      rec.parentaddr := oldent.addr;
      rec.startblock := 0;
      rec.lengthinBlocks := ARC_ZONE_SIZE_IN_BLOCKS;
      rec.encoding := TArcEncoding.aeCompleteXor;
      rec.compressedLength := l2;
      //put the record into the file
      fs := SyncFS(ent.fileid,true);
      fs.Seek(0, soEnd);
      recex.addr := fs.Position;
      ent.addr := recex.addr;
      ent.zoneidx := rebuilt_zone_idx;
      ent.logid := logid;
      rec.logtime := nao;
      rec.CalculateChecksum;
      Stream_GuaranteeWrite(fs, pbyte(@rec), sizeof(rec));
      Stream_GuaranteeWrite(fs, pbyte(@zip2[0]), l2);
    end;


    if (not rec.IsValid) then begin
      raise ECritical.create('Trying to create an invalid record.');
    end;
    //update the ArcVAT
    arc.Vat.PutEntry(ent);
    zone_vatent := ent;
    recex.fileid := ent.fileid;
{$IFDEF LT_XE8}
    setlength(zone_stack, length(zone_stack)+1);
    for t:= 1 to high(zone_stack) do begin
      zone_stack[t] := zone_stack[t-1];
    end;
    zone_stack[0] := recex;
{$ELSE}
    Insert([recex], zone_stack, 0);
{$ENDIF}

{$IFDEF VERIFY}
    VerifyRecordedData(blockaddr, pData, blocklength, -1);
{$ENDIF}

  finally
    try
      SyncFS(-1, false);
    finally
      unlock;
    end;
//    Debug.Log('Log Complete!');
  end;


  //switch to desired file
  //append file
  rebuilt_zone_logid := toid;
  result := true;
end;


procedure TZoneBuilder.ReplaceStreamFrom(otherzonebuilder: TZoneBuilder);
begin
  if otherzonebuilder.FFs = nil then
    raise ECritical.create('other zone has no stream');
  if otherzonebuilder.FFs.o = nil then
    raise ECritical.create('other zone has no stream');
  otherzonebuilder.FFs.o.seek(0,soBeginning);


  FFs.o.seek(0,soBeginning);
  FFs.o.Size := 0;
  rebuilt_zone_logid := 0;
  rebuilt_zone_full_depth := false;

  Stream_GuaranteeCopy(otherzonebuilder.FFs.o,FFs.o);


end;

procedure TZoneBuilder.ReplaceStreamMirror;
begin
{  if otherzonebuilder.FFs = nil then
    raise ECritical.create('other zone has no stream');
  if otherzonebuilder.FFs.o = nil then
    raise ECritical.create('other zone has no stream');
  otherzonebuilder.FFs.o.seek(0,soBeginning);


  FFs.o.seek(0,soBeginning);
  FFs.o.Size := 0;
  rebuilt_zone_logid := 0;
  rebuilt_zone_full_depth := false;

  Stream_GuaranteeCopy(otherzonebuilder.FFs.o,FFs.o);
 }
end;

procedure TArchiver.SEtVatPath(value: string);
begin
  FVatPath := Value;
  FVat.filename := value+'.arc.vat';

end;

function TArchiver.SetZoneRevision(idx, rev: int64): int64;
var
  l: TArcVatEntry;
begin
  result := -2;
  FVat.Lock;
  try
    if idx < 0 then
      raise ECritical.create('illegal zone index '+inttostr(idx));
    l := FVat.GetEntry(idx);
    l.logid := rev;
    FVat.PutEntry(l);
    result := l.logid;
  finally
    FVat.Unlock;
  end;
end;

function TArchiver.StorCount: ni;
begin

  result := FStors.Count;
end;

function TZoneBuilder.SyncFS(ifileID: int64; bAllowCreate: boolean): TLocalFileSTream;
var
  bExists: boolean;
  sFileBackup, sfile: string;
  t: ni;
  sSub, sl,sr: string;
begin
//  Debug.Log('SyncFS '+inttohex(iFileid,1));
  //bail if we're already on this file
  if FSyncedFileStreamID = iFileid then begin
    if FFS = nil then
      exit(nil);
    result := FFS.o;
    exit;
  end;
  //free previous file and release lock
  if ffs<> nil then begin
//    arc.zoneLocks.ReleaseLock('f'+locked_fileid.tostring, false);
    //FFS.Free;
    FFS := nil;
  end;

  //???
  if iFileID < 0 then begin
    FSyncedFileStreamID := iFileID;
    exit;
  end;

  //get lock on new file
  locked_fileid := iFileid;
//  arc.zoneLocks.GetLock('f'+locked_fileid.tostring, false);

  arc.Lock;
  try
    //FIND THE FILE - or choose a new file name
    sFile := arc.FindFileIDInStors(iFileID);

    FFS := THolder<TLocalFileStream>.create;
    FFS.o := guaranteeOpen(sFile);


    CheckAndMoveZone;


    result := FFS.o;
    FSyncedFileStreamID := iFileID;


  finally
    arc.Unlock;
  end;



end;

procedure TZoneBuilder.Unlock;
begin
  inherited;
//  Debug.Log(self, 'unlocked '+sect.RecursionCount.tostring);

end;

procedure TZoneBuilder.WipeZone(zoneidx: int64);
begin
  if FFs <> nil then
    if FFs.o <> nil then
      FFs.o.Size := 0;
  rebuilt_zone_pin := NULL_PIN;
  rebuilt_zone_logid := 0;
  rebuilt_zone_full_depth := false;
  if FFs <> nil then
    if FFs.o <> nil then
      FFs.o.Seek(0,soBeginning);
end;

function TArchiver.SyncZone(bMirror: boolean; zoneidx: int64; pin:TDateTime): TZoneBuilder;
var
  has: TZoneBuilder;
  t: ni;
  hasid, junkid: int64;
  junk: TZoneBuilder;
  fails: nativeint;
  idx: nativeint;
begin
  result := nil;
  has := nil;
  if zoneidx = 93901 then begin
    Debug.Log('93901');
  end;
  if bMirror then
      zoneidx := zoneidx or MIRROR_FLAG;
{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(zoneidx),false);
{$ELSE}
  Lock;
{$ENDIF}
    try
      try
      lock;
      try
        zone_builders.lock;
        try
      //    Debug.Log('SyncZone '+inttostr(zoneidx));
          has := nil;
          for t:= 0 to zone_builders.count-1 do begin
            if zone_builders[t] <> nil then begin
              if zone_builders[t].rebuilt_zone_idx = zoneidx then begin
                has := zone_builders[t];
                zone_builders.delete(t);//>>>-----removed only for REORDERING
                break;                                                   // |
              end;                                                       // |
            end;                                                         // |
          end;                                                           // |
                                                                         // |
          if has = nil then begin                                        // |
            has := TZoneBuilder.create;                                  // |
            has.arc := self;
            has.rebuilt_zone_idx := zoneidx;                             // |
            has.rebuilt_zone_pin := -99999999.0;
            has.rebuilt_zone_logid := -1;
          end;                                                           // |
                                                                         // |
                                                                         // |
          zone_builders.Insert(0, has); //<<<<<-------PUT BACK AT THE TOP <<-

          var cnt := 0;
          for t:= 0 to zone_builders.count-1 do begin
            if zone_builders[t] <> nil then begin
              if zone_builders[t].rebuilt_zone_idx = zoneidx then begin
                inc(cnt);
              end;
            end;
          end;
//          if cnt > 1 then begin
//            Debug.Log('WHOOWHAOWHAOWHAOWHAOWH!  Too many of this zone. ' +inttohex(zoneidx,1));
//          END;


          //Clean out excess builders (if we can get locks)
          fails := 0;
          if zone_builders.count > (ZONE_BUILDER_CACHE_SIZE)+1 then
            debug.log('There are  '+zone_builders.count.ToString+' zone builders');
          while zone_builders.count > ZONE_BUILDER_CACHE_SIZE do begin
            idx := (zone_builders.count-1) - fails;
            if idx < 0 then idx := 0;
            junk := zone_builders[idx];
            junkid := junk.rebuilt_zone_idx;
            if zonelocks.TryGetLock(inttostr(junkid), false) then
            try
              zone_builders.Delete(idx);
              junk.free;
              junk := nil;
            finally
              zonelocks.releaseLock(inttostr(junkid), false);
            end else begin
              inc(fails);
              if fails > ZONE_BUILDER_CACHE_SIZE shr 1 then
                break;
            end;
          end;
        finally
          zone_builders.unlock;
        end;
      finally
        result := has;
        unlock;
        if result <> nil then begin
          result.RebuildZone(bMirror, zoneidx, pin, false);
        end else begin
          debug.log('result is nil!');
        end;
      end;



    except
    end;
  finally
{$IFDEF USE_ZONE_LOCKS}
    zonelocks.ReleaseLock(inttostr(zoneidx),false);
{$ELSE}
    UnLock;
{$ENDIF}
  end;
end;

procedure TArchiver.Test;
begin
  //self.AbridgeZone($0, now-90);
//  self.AbridgeZone($244E, now-90);
//  self.AbridgeZone($244E, now-90);
//  self.AbridgeZone($E4D, now-30);
//  self.AbridgeZone($E4D, now-30);
//  self.AbridgeZone($15A, now-90);
//  self.AbridgeZone($15A, now-90);
end;

procedure TArchiver.VerifyRecordedData(blockaddr: int64; pData: PByte;
  blocklength: int64; logid: int64; prog: PProgress);
var
  block_offset: int64;
  byte_offset: int64;
  dba: TDynByteArray;
  iCan, iDid, iTotal: int64;
begin
  RebuildZone(false, -1,NULL_PIN);
  setlength(dba, blocklength*512);
  iTotal := 0;
  while iTotal < blocklength do begin
    iCan := blocklength - iTotal;
    iDid := RebuildData(false, blockaddr+iTotal, @dba[0], iCAn,NULL_PIN, prog);

    if not CompareMem(@pData[iTotal*512], @dba[0], iDid*512) then begin
      Debug.Log(self,'FAILED COMPARE MEM!');
    end;

    inc(iTotal, iDid);
  end;



end;

{ TArcFileDictionary }

{$IFDEF DICT}
procedure TArcFileDictionary.Add(iFileID: int64; name: string; bNoSort: boolean = false);
var
  ent: TArcFileDef;
begin

  ent.fileid := iFileId;
   ent.filename := name;
  FList.Add(ent);
  if not bNoSort then
    Sort;

end;
{$ENDIF}
{$IFDEF DICT}
destructor TArcFileDictionary.Destroy;
begin
  FList.Free;
  inherited;
end;

function TArcFileDictionary.bsfunc(test: int64; op: TBinarySearchOp): int64;
begin
  case op of
    bsoTest:
    begin
      if test >= FList.count then
        result := 1
      else
        result :=  FList[test].fileid - bssearchval;
    end;
    bsoResult:
    begin
      foundfileid := test;
      exit(0);
    end;
    bsoNoResult:
    begin
      foundfileid := -1;
      exit(0);
    end;
  end;
end;
{$ENDIF}

{$IFDEF DICT}
function TArcFileDictionary.FileIDtoFileName(fileid: int64): string;
var
  idx: integer;
  res: TBinarySearchOp;
  t: ni;
begin
  Lock;
  try
    idx := -1;
    BsSearchVAl := fileid;
    idx := search.BinarySearch(bsfunc, res);


    result := '';
    if idx >= 0 then begin
      result := FList[idx].filename;
    end;
  finally
    Unlock;
  end;
end;
{$ENDIF}
{$IFDEF DICT}
procedure TArcFileDictionary.Init;
begin
  inherited;
  FList := TList<TArcFileDef>.create;
end;
{$ENDIF}

{$IFDEF DICT}
procedure TArcFileDictionary.Load(sFile: string);
var
  sl: TStringlist;
  t: ni;
  s1,s2: string;
  rec: TARcFileDef;


begin
  if sFile <> '' then
    FfileName := sFile;
  sl := TStringlist.Create;
  try
    if fileexists(sFile) then
      sl.LoadFromFile(sFile);
    sl.Sorted := false;
    for t:= 0 to sl.count-1 do
      begin
        if t mod 1000 = 0 then
          debug.log(self,'loading '+inttostr(t));
        s1 := sl[t];

       if SplitString(s1, ',', s1,s2) then
        begin
          rec.fileid := strtoint(s1);
          rec.filename := s2;
        end;
        self.Add(rec.fileid, rec.filename, true);


      end;
      Sort;
  finally
    sl.Free;
  end;

end;
{$ENDIF}
{$IFDEF DICT}
function TArcFileDictionary.NewFileID: int64;
var
  sFile: string;
begin
  if Flist.count = 0 then
    result := 1
  else
    result := FList[FList.Count-1].fileid+1;

  sFile := PathForNewFiles+inttohex((result shr 14) shl 14,16)+'\'+inttohex(result, 16)+'.arc';
//  debug.Log(self,sFile);
  Add(result, sFile);
//  FList.Sort;
  Save;
end;
{$ENDIF}
{$IFDEF DICT}
procedure TArcFileDictionary.Save;
var
  t: ni;
  sl: TStringlist;
  s: string;
begin
  sl := TStringList.Create;
  try
    for t:= 0 to FList.Count-1 do begin
      s := inttostr(FList[t].fileid)+','+FList[t].filename;
      sl.add(s);
    end;

    sl.SaveToFile(FileName);
  finally
    sl.Free;
  end;

end;
{$ENDIF}
{$IFDEF DICT}

procedure TArcFileDictionary.SetFileName(value: string);
begin
  FFileName := Value;
  Load(value);
end;
{$ENDIF}
{$IFDEF DICT}
procedure TArcFileDictionary.Sort;
begin
  FList.Sort(
    TArcFileDictionaryComparer.Construct(
      function (const L, R: TArcFileDef): integer
      begin
        result :=  l.fileid - r.fileid;
      end
    )
  );
end;
{$ENDIF}

{ TArcVat }

procedure TArcVat.Detach;
begin

  fs.Free;
  fs := nil;
  inherited;

end;

function TArcVat.Getchecksum(zStart, zCount: int64): int64;
var
  t: ni;
  ent: TArcVatEntry;
begin
  result := 0;
  Lock;
  try
    for t:= zStart to (zstart+zCount)-1 do begin
      ent := GetEntry(t);
      result := result + ent.logid;
    end;
  finally
    Unlock;
  end;
end;

function TArcVat.GetEntry(idx: int64): TArcVatEntry;
var
  addr: int64;
  bCreate: boolean;
begin
  Lock;
  try
    addr := GetentryAddress(idx);
    bCreate := fs.Size < addr+sizeof(result);
    if not bCreate then begin
      if addr >= fs.size then begin
        result.Init(idx);
      end else begin
        fs.Seek(addr, soBeginning);
        stream_GuaranteeRead(fs, pbyte(@result), sizeof(result));
        if (not result.IsValid) or (result.zoneidx <> idx) then begin
          result.Init(idx);
        end;
      end;
    end else begin
      result.Init(idx);
    end;
  finally
    Unlock;
  end;
end;

function TArcVat.GetEntryAddress(idx: int64): int64;
begin
  result := sizeof(TArcVatEntry) * idx;
end;

function TArchiver.GetNextLogID(zoneidx: int64; iReserve: int64): int64;
var
  p: TNameValuePairList;
var
  builder: TZoneBuilder;
begin
{$IFDEF USE_ZONE_LOCKS}
  zonelocks.GetLock(inttostr(zoneidx), false);
{$ELSE}
  Lock;
{$ENDIF}
  try
    builder := self.RebuildZone(false, zoneidx, NULL_PIN);
    result := builder.rebuilt_zone_logid+1;


  finally
    UnLock;
{$IFDEF USE_ZONE_LOCKS}
    zonelocks.ReleaseLock(inttostr(zoneidx), false);
{$ELSE}

{$ENDIF}
  end;
end;


procedure TArcVat.GrowEntries(toIdx: int64);
var
  t,startidx, endidx: int64;
  ent: TArcVatEntry;
begin
  Lock;
  try
    startidx := fs.Size div sizeof(TArcVatEntry);
    endidx := toIDx;


    fs.Seek(0, soEnd);
    for t:= startidx to endidx do begin
      ent.zoneidx := t;
      ent.addr := -1;
      ent.fileid := -1;
      ent.logid := -1;
      stream_GuaranteeWrite(fs, @ent, sizeof(ent));
    end;
  finally
    Unlock;
  end;


end;

procedure TArcVat.Init;
begin
  inherited;
  FCachedNextID := -1;
end;

procedure TArcVat.PutEntry(ent: TArcVatEntry);
var
  addr: int64;
begin
  Lock;
  try
    ent.fileid := ent.zoneidx;
    ent.SetCalcCheck;
    if not ent.IsValid then
      raise ECritical.create('trying to put invalid arcvat entry '+ent.TOString);
    addr := GetEntryAddress(ent.zoneidx);
    if addr > fs.size then
      GrowEntries(ent.zoneidx);

    fs.Seek(addr, soBeginning);
  {$IFDEF ENTRY_DEBUG}  debug.log(self,'about to put entry='+ent.tostring);{$ENDIF}
    ent.SetCalcCheck;
    stream_GuaranteeWrite(fs, pbyte(@ent), sizeof(ent));
  //  debug.log(self,'put sz='+inttostr(fs.Size));
{$IFDEF USE_MBFS}
    fs.Flush;
{$ENDIF}
  finally
    Unlock;
  end;
end;

procedure TArcVat.SetFileName(value: string);
begin
  fFileName := value;
  if (value <> FFileName) or (fs=nil) then begin
    fs.free;
    fs := nil;
    if not fileexists(fFileName) then begin
      forcedirectories(extractfilepath(FFileName));
      fs := TVatFileStream.create(FFileName, fmCreate);
    end else begin
      fs := TVatFileStream.create(FFileName, fmOpenReadWRite+fmShareExclusive);
    end;
  end;
end;




{ TArcRecordEx }

function TArcRecordEx.DebugStr: string;
begin
  RESULT := '[rec fileid='+inttostr(fileid)+'|addr='+inttohex(addr,2)+rec.DebugString+']';
end;

class operator TArcRecordEx.equal(a, y: TArcRecordEx): boolean;
begin
  result := (a.fileid=y.fileid) and (a.addr=y.addr);
end;

{ TArcRecord }

procedure TArcRecord.CalculateChecksum;
begin
  checksum := $7654321076543210;
end;

procedure TArcRecord.CheckLengths;
begin
  if Encoding in [aeComplete, aeCompleteXor] then begin
     startblock := 0;
     lengthInBlocks := ARC_ZONE_SIZE_IN_BLOCKS;
  end;
end;

function TArcRecord.checksumIsValid: boolean;
begin
  result := checksum = $7654321076543210;
end;

function TArcRecord.DebugString: string;
begin
//  result := '|pintime='+datetimetostr(logtime)+'|cmplen='+commaize(compressedlength)+'|logid='+inttostr(logid)+'|enc='+arcencodingtostring(encoding)+'|parenaddr='+inttohex(parentaddr,2);
  result := '|pintime='+datetimetostr(logtime)+'|pin='+floattostr(logtime)+'|logid='+inttostr(logid)+'|parentfile='+inttostr(parentfileid)+'|parentaddr='+inttohex(parentaddr,0)+'|startblock='+inttostr(startblock)+'|blocklength='+inttostr(Self.lengthInBlocks)+'|enc='+arcencodingtostring(encoding);

end;

class operator TArcRecord.equal(a, y: TArcRecord): boolean;
begin
  result := (a.logid=y.logid) and (a.parentfileid=y.parentfileid) and (a.parentaddr=y.parentaddr);
end;

function TArcRecord.GetEncoding: TArcEncoding;
begin
  result := TArcEncoding(FEncoding);
end;

function TArcRecord.GetParentfileID: int64;
begin
  if FParentFileid = -1 then
    exit(FParentFileID);
  Result := FParentFileId and (not MIRROR_FLAG);
end;

function TArcRecord.IsValid: boolean;
begin
  result := (startblock < ARC_ZONE_SIZE_IN_BLOCKS)
        and ((startblock+Lengthinblocks) <= ARC_ZONE_SIZE_IN_BLOCKS)
        and (lengthinblocks >= 0)
        and (startblock >= 0)
        and (logid >=-1)
        and (parentfileid >=-1)
        and (compressedlength <= (((lengthinblocks*BLOCKSIZE)*2))+8)
        and (logtime <> 0.0);

end;

procedure TArcRecord.SetEncoding(const Value: TArcEncoding);
begin
  FEncoding := ord(value);
end;

function TArcRecord.ToString: string;
begin
  result := '[logid='+inttostr(logid)+' parentfile='+inttostr(parentfileid)+' parentaddr='+inttohex(parentaddr,0)+' startblock='+inttostr(startblock)+' blocklength='+inttostr(Self.lengthInBlocks);
end;
{ TArcVatEntry }

function TArcVatEntry.CalcCheck: int64;
begin
  result := self.logid xor self.addr xor self.fileid xor self.zoneidx;

end;

procedure TArcVatEntry.Init(zoneidx: int64);
begin
  self.zoneidx := zoneidx;
  self.fileid := -1;
  self.addr := -1;
  self.logid := 0;
  SetCalcCheck;
end;

function TArcVatEntry.IsValid: boolean;
begin
  result := (calccheck = check) and (zoneidx = fileid);
end;

procedure TArcVatEntry.SetCalcCheck;
begin
  check := calccheck;
end;

function TArcVatEntry.TOString: string;
begin
//    logid: int64;
//    fileid: int64;
//    addr: int64;

  result := '[fileid='+inttostr(fileid)+' zidx='+inttostr(zoneidx)+' logid='+inttostr(logid)+' addr='+inttohex(addr,0)+' check='+inttohex(check,16)+']';
end;

{ TZoneBuilder }

procedure TZoneBuilder.CheckAndMoveZone;
begin
  try
  if ffs = nil then
    exit;

  if GetFreeSpaceOnPath(extractfilepath(FFs.o.FileName)) < 1000000000 then begin
    //YES we should move the zone
    if arc.TryLock(1000) then
    try
      var newpath := arc.ChoosePath;
      var fileid: int64 := strtoint64('$'+extractfilenamepart(ffs.o.filename));
      var newfile := slash(newpath)+FileIDtoFileName(fileid);
      var fs2 := Tholder<TLocalFileStream>.create;
      forcedirectories(extractfilepath(newfile));
      Debug.Log('Moving '+ffs.o.filename+'  >>>>>  '+newfile);
      fs2.o := TLocalFileStream.create(newfile, fmCreate);
      ffs.o.Seek(0,soBeginning);
      Stream_GuaranteeCopy(ffs.o, fs2.o, ffs.o.size);
      var oldfile := ffs.o.FileName;
//      ffs.Free;
      ffs := nil;
      ffs := fs2;
      try
        deletefile(pchar(oldfile));
      except
      end;
    finally
      arc.Unlock;
    end;
  end;
  except
    on E: exception do begin
      debug.log('when checking/moving file got: '+e.message);
    end;
  end;
end;

constructor TZoneBuilder.Create;
begin
  inherited;
  FSyncedFileStreamID := -1;
  rebuilt_zone_idx := -1;

end;


destructor TZoneBuilder.Destroy;
begin

  SyncFS(-1, false);
//  FFS.Free;
//[x] Cleanup zone builders
//[ ] RebuildZone - > SyncZone
//[ ] SyncZone -
//    [ ] Find Zone in zone_builders
//    [ ] Zone->RebuildZone (should automanage log-pin
//    [ ] Remove from zone_buildrs
//    [ ] Re-add/add to zone_builders
//    [ ] reduce size of zone_builders
//[ ] Record data
//    [ ] SyncZone
//    [ ] Zone->RecordData
//[ ] REbuildDAta data
//    [ ] SyncZone
//    [ ] Zone->RebuildData
//[ ] Checksum
//    [ ] SyncZone
//    [ ] Zone->GetZoneChecksum



  FFS := nil;

  inherited;
end;

procedure TZoneBuilder.Detach;
begin
  SyncFS(-1,false);
  inherited;

end;

function GetMirroredZoneIdx(zoneid: int64): int64;
begin
  result := zoneid or MIRROR_FLAG;

end;

function TZoneBuilder.GetZoneChecksum(zoneidx: int64; pin: TDateTime; out iSum,
  iXor: int64): boolean;
var
  cs: TChecksumresult;
begin
  result := true;
  cs := CalculateChecksum2020(@zone[0], ARC_ZONE_SIZE_IN_BYTES);
  isum := cs.cs1;
  iXor := cs.cs2;

end;


{ Tqi_LookForZone }

procedure Tqi_LookForZone.DoExecute;
var
  t: ni;
  sOrigFile: string;
  sFile: string;
  bestfile: string;
  bestdate: TDateTime;
begin
//  Lock;
  try
    bestDate := 0.0;
    bestfile := '';
    sOrigFile := FileIDToFileName(in_zone);
    for t:= 0 to high(in_paths) do begin
      sFile := in_paths[t]+sOrigFile;
      if FileExists(sFile) then begin
        var fi := TFIleInformation.Create;
        try
          fi.LoadFromFile(sFile);
          if fi.Date > bestDate then begin
            bestfile := sFile;
            bestDate := fi.date;
          end;
        finally
          fi.free;
        end;
      end;
    end;
    out_bestpath := bestfile;
  finally
//    Unlock;
  end;

end;

end.
