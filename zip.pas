unit zip;
{$I DelphiDefs.inc}
interface

uses
  typex,
{$IFDEF WINDOWS}
  activex,
  comobj,
{$ENDIF}
  commandprocessor, variants, stringx, sysutils,zlib, classes, memoryfilestream, helpers_stream, systemx, System.zip;

const
  SHCONTCH_NOPROGRESSBOX = 4;
  SHCONTCH_AUTORENAME = 8;
  SHCONTCH_RESPONDYESTOALL = 16;
  SHCONTF_INCLUDEHIDDEN = 128;
  SHCONTF_FOLDERS = 32;
  SHCONTF_NONFOLDERS = 64;

{$IFDEF WINDOWS}
function ShellUnzip(const zipfile, targetfolder: string; filter: string = ''): boolean;deprecated;
function ShellUnzipToTempFolder(const zipfile: string; filter: string = ''): string;deprecated;
{$ENDIF}


type
{$IFDEF WINDOWS}
  Tcmd_ShellUnzip = class(TCommand)
  private
    FZipFile: string;
    FTargetFolder: string;
  public
    procedure Initexpense;override;
    procedure DoExecute;override;
    property ZipFile: string read FZipFile write FZipFile;
    property TargetFolder: string read FTargetFolder write FTargetFolder;
  end;
{$ENDIF}
  Tcmd_ZipRam = class(TCommand)
  private
  public
    psource: pbyte;
    pdest: pbyte;
    sourcelen: nativeint;
    destlen: nativeint;
    resultlen: nativeint;
    procedure DoExecute;override;
    class function BeginZipRam(pSource, pDest: pbyte; sourcelen: nativeint; destlen: nativeint): Tcmd_ZipRam;
    class function EndZipRam(c: Tcmd_ZipRam):nativeint;
  end;


procedure ZZip(sSource, sDest: string);
procedure ZUnZip(sSource, sDest: string);
function ZipRam(pSource, pDest: pbyte; sourcelen: nativeint; destlen: nativeint; prog: PProgress; CompressionLevel: TCompressionLevel = clDefault): nativeint;
function UnZipRam(pSource, pDest: pbyte; sourcelen: nativeint; destlen: nativeint; prog: PProgress): nativeint;
function ZCompressStrA(const s: ansistring; level: TZCompressionLevel): TBytes; overload;
function ZDecompressStrA(const s: TBytes): ansistring;
function UnzipFile(sSource, sDest: string): boolean;






implementation

uses
 exe;

function UnzipFile(sSource, sDest: string): boolean;
begin
{$IFDEF MSWINDOWS}
  if fileexists(dllpath+'7-zip\7z.exe') then begin
    RunProgramAndWait(dllpath+'7-zip\7z.exe','x -y -o'+quote(sDest)+' '+quote(sSource),'', true);
    exit(true);
  end;
{$ENDIF}

  result := false;
  var myZipFile := TZipFile.Create;
//  myZipFile.OnCreateDecompressStream := OnCreateDecompressStream;
  try
    myZipFile.Open(sSource, zmRead);
    myZipFile.ExtractAll(sDest);
    myZipFile.Close;
    exit(true);
  finally
    myZipFile.Free;
  end;
end;


{$IFDEF WINDOWS}
function ShellUnzipToTempFolder(const zipfile: string; filter: string = ''): string;
begin
  var topath := GetTempPathForThread;
  try
    if not ShellUnzip(zipfile, toPath,filter) then
      exit('');
    result := topath;
  except
  end;
end;
function ShellUnzip(const zipfile, targetfolder: string; filter: string = ''): boolean;
var
  shellobj: olevariant;
  srcfldr, destfldr: olevariant;
  shellfldritems: olevariant;
  vstr1, vstr2: olevariant;
begin
  shellobj := CreateOleObject('Shell.Application');

  vstr1 := CleanupParentsInPath(zipfile);
  vstr2 := CleanupParentsInPath(targetfolder);

  srcfldr := shellobj.NameSpace(vstr1);
  forcedirectories(vstr2);
  destfldr := shellobj.NameSpace(vstr2);

  if VArIsNUll(srcfldr) then
    exit(false);
  if VArIsNUll(destfldr) then
    exit(false);
  if not ((VarType(srcfldr) and varObject) = varObject) then
    exit(false);

  shellfldritems := srcfldr.Items;
  if (filter <> '') then
    shellfldritems.Filter(SHCONTF_INCLUDEHIDDEN or SHCONTF_NONFOLDERS or SHCONTF_FOLDERS,filter);

  destfldr.CopyHere(shellfldritems, SHCONTCH_NOPROGRESSBOX or SHCONTCH_RESPONDYESTOALL);
  result := true;
end;

{ Tcmd_ShellUnzip }

procedure Tcmd_ShellUnzip.DoExecute;
begin
  inherited;
  CoInitialize(nil);
  ShellUnzip(zipfile, targetfolder);
end;

procedure Tcmd_ShellUnzip.Initexpense;
begin
  inherited;
  CpuExpense := 0.5;
end;
{$ENDIF}

function ZipRam(pSource, pDest: pbyte; sourcelen: nativeint; destlen: nativeint; prog: PProgress; CompressionLevel: TCompressionLevel = clDefault): nativeint;
var
  cs: TCompressionStream;
  ms: TMemoryStream;
begin
  try
    ms := TMemoryStream.Create;
    try
      cs := TCompressionStream.create(CompressionLevel, ms);
      try
        Stream_GuaranteeWrite(cs, pSource, sourcelen, prog);
      finally
        cs.free;
      end;
{$IFDEF APPLE}
      ms.Seek(int64(0),TSeekOrigin.soBeginning);
{$ELSE}
      ms.Seek(0,0);
{$ENDIF}
      if destlen >= ms.size then begin
        movemem32(pDest, pbyte(ms.memory), ms.Size);
        result := ms.Size;
      end else begin
        result := -1;
      end;
    finally
      ms.Free;
    end;
  finally
  end;
end;

function UnZipRam(pSource, pDest: pbyte; sourcelen: nativeint; destlen: nativeint; prog: PProgress): nativeint;
var
  cs: TDeCompressionStream;
  ms,ms2: TMemoryStream;
begin
  try
    ms := TMemoryStream.Create;
    ms2 := TMemoryStream.Create;
    try
      cs := TDeCompressionStream.create(ms);
      try
        Stream_GuaranteeWrite(ms, pSource, sourcelen);
        Stream_GuaranteeCopy(cs, ms2, prog, cs.Size);
      finally
        cs.free;
      end;
      ms2.Seek(int64(0),TSeekOrigin.soBeginning);
      if destlen >= ms2.size then begin
        movemem32(pDest, pbyte(ms2.memory), ms2.Size);
        result := ms2.Size;
      end else begin
        result := 0-ms2.size;
      end;
    finally
      ms.Free;
      ms2.Free;
    end;
  finally
  end;
end;


procedure ZZip(sSource, sDest: string);
var
  cs: TCompressionStream;
  s: TFileStream;
  sTarget: TFileStream;
begin
  s := TFileStream.create(sSource, fmOpenRead+fmShareDenyWrite);
  try
    sTarget := TFileStream.create(sDest, fmCreate);
    try
      cs := TCompressionStream.create(sTarget);
      try
        cs.CopyFrom(s, s.Size);

      finally
        cs.free;
      end;
    finally
      sTarget.free;
    end;
  finally
    s.free;
  end;

end;

procedure ZunZip(sSource, sDest: string);
var
  cs: TDeCompressionStream;
  s: TFileStream;
  sTarget: TFileStream;
begin
  s := TFileStream.create(sSource, fmOpenRead+fmShareDenyWrite);
  try
    sTarget := TFileStream.create(sDest, fmCreate);
    try
      cs := TDeCompressionStream.create(s);
      try
        Stream_GuaranteeCopy(cs, sTarget);
//        cs.CopyFrom(s, s.Size);

      finally
        cs.free;
      end;
    finally
      sTarget.free;
    end;
  finally
    s.free;
  end;

end;


{ Tcmd_ZipRam }

class function Tcmd_ZipRam.BeginZipRam(pSource, pDest: pbyte; sourcelen,
  destlen: nativeint): Tcmd_ZipRam;
begin
  result := Tcmd_ZipRam.create;
  result.psource := psource;
  result.pdest := pdest;
  result.sourcelen := sourcelen;
  result.destlen := destlen;
  result.start;

end;

procedure Tcmd_ZipRam.DoExecute;
begin
  inherited;
  resultlen := zipram(psource, pdest, sourcelen, destlen, @self.volatile_progress);
end;

class function Tcmd_ZipRam.EndZipRam(c: Tcmd_ZipRam): nativeint;
begin
  c.waitfor;
  result := c.resultlen;
  c.detachandfree;
  c := nil;
end;

function ZCompressStrA(const s: ansistring; level: TZCompressionLevel): TBytes; overload;
var
  b: TBytes;
begin
  b := AnsiStringToTBytes(s);
  setlength(result, length(b)*3);
  system.zlib.ZCompress(b, result, level);

end;
function ZDecompressStrA(const s: TBytes): ansistring;
var
  b: TBytes;
begin
  system.zlib.ZDeCompress(s, b);
  result := BytesToAnsiString(b);

end;


end.
