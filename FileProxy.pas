unit FileProxy;

{x$DEFINE BAD_PATTERN_CHECK}
{x$DEFINE PX_DEBUG}
{x$DEFINE DISABLE_WRITES}
{x$DEFINE ATS}

interface
{$IFDEF MSWINDOWS}
{ NOTE!  THIS REQUIRES WINDOWS, it is a mistake to include this
  file in other platforms.
}

uses System.Sysutils, debug, numbers, systemx, windows, typex;

const
  MAX_SINGLE_OP = 262144;



function FileReadPx(ats: PAlignedTempSpace; const Handle: THandle; var Buffer; const Count: LongWord): Integer;inline;
function FileWritePx(ats: PAlignedTempSpace; const Handle: THandle; const Buffer; const Count: LongWord): Integer;inline;
function FileSeekPx(const Handle: THandle; const Offset: Int64; const Origin: Integer): Int64;inline;
function FileReadPx_BlockAlign(const addr: int64; const handle: THandle; var Buffer; const count: longword): integer;
function FileGuaranteeReadPx(const handle: THandle; buffer: PByte; const count: longword): integer;



{$IFDEF BAD_PATTERN_CHECK}
const
  BAD_PATTERN: array [0..9] of byte = ($0f, $00, $00, $00, $00, $00, $00, $00, $00, $18);
{$ENDIF}

{$ENDIF}
implementation

{$IFDEF MSWINDOWS}
function FileReadPx(ats: PAlignedTempSpace; const Handle: THandle; var Buffer; const Count: LongWord): Integer;inline;
var
  chunk: ni;
begin
  chunk := lesserof(count,MAX_SINGLE_OP);
{$IFNDEF ATS}
//  ats := nil;
{$ENDIF}
  if ats = nil then begin
    result := FileRead(Handle, buffer, chunk);
  {$IFDEF PX_DEBUG}
    Debug.Log('FileReadPx '+memorytohex(pbyte(@buffer), lesserof(count, 64)));
  {$ENDIF}
  end else begin
    result := FileRead(Handle, ats.aligned^, chunk);
    Movemem32(@buffer, ats.aligned, result);
  end;
end;

function FileGuaranteeReadPx(const handle: THandle; buffer: PByte; const count: longword): integer;
begin
  result := 0;
  var cx := count;
  var idxp : Pbyte := buffer;
  while cx > 0 do begin
    var just := FileRead(handle, idxp^, cx);
    inc(idxp, just);
    dec(cx, just);
    inc(result, just);
  end;
end;

function FileReadPx_BlockAlign(const addr: int64; const handle: THandle; var Buffer; const count: longword): integer;
begin
  Debug.Log('Addr = '+inttohex(addr,1));

  var aligned := addr and $FFFFFFFFFFFFFE00;
  Debug.Log('Aligned Addr = '+inttohex(aligned,1));

  var offset := addr and $1ff;
  Debug.Log('Offset Addr = '+inttohex(offset,1));
  aligned := addr - offset;
  Debug.Log('Aligned Addr = '+inttohex(aligned,1));


  var alignedsz := (((count -1) shr 9)+1) shl 9;
  FileSeek64(handle, aligned, 0);
  //if the target buffer has aligned sizes and addresses we can
  //read directly into it
  if (aligned = addr) and (alignedsz = count) then begin
    result := FileGuaranteeReadPx(handle, @buffer, count);
  end
  //else we have to read into temp space, then copy
  else begin
    var a: TDynByteArray;
    setlength(a, alignedsz);
    result := FileGuaranteeReadPx(handle, @a[0], alignedsz);
   //var offset := addr and $1FF;
    Movemem32(@buffer, @a[offset], count);
    result := count;
  end;


end;

function FileWritePx(ats: PAlignedTempSpace; const Handle: THandle; const Buffer; const Count: LongWord): Integer;inline;
begin
{$IFNDEF ATS}
  ats := nil;
{$ENDIF}
  if ats = nil then begin
  {$IFDEF BAD_PATTERN_CHECK}
    AlertMemoryPattern(@BAD_PATTERN[0], sizeof(BAD_PATTERN), pbyte(@Buffer), count);
  {$ENDIF}
  {$IFDEF PX_DEBUG}
    Debug.Log('FileWritePx '+memorytohex(pbyte(@buffer), lesserof(count, 64)));
  {$ENDIF}
  {$IFDEF DISABLE_WRITES}
    Debug.Log('WRITES ARE DISABLED: '+memorytohex(pbyte(@buffer), lesserof(count, 64)));
    result := count;
  {$ELSE}
    result := FileWrite(Handle, buffer, count);
  {$ENDIF}
  end
  else begin
  {$IFDEF DISABLE_WRITES}
    Debug.Log('WRITES ARE DISABLED: '+memorytohex(pbyte(@buffer), lesserof(count, 64)));
    result := count;
  {$ELSE}
    var chunk := lesserof(count,MAX_SINGLE_OP);
    Movemem32(ats.aligned,@buffer, chunk);
    result := fileWrite(Handle, ats.aligned^, chunk);
  {$ENDIF}
  end;

end;

function FileSeekPx(const Handle: THandle; const Offset: Int64; const Origin: Integer): Int64;inline;
begin
  {$IFDEF PX_DEBUG}
    Debug.Log('FileSeekPx 0x'+inttohex(offset, 16));
  {$ENDIF}
    result := FileSeek(Handle, offset, origin);
end;


{$ENDIF}
end.
