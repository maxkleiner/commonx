unit graphicsx;
{$i delphidefs.inc}

interface

uses
{$IFDEF FMX}
  system.UITypes, system.UIConsts,
{$ELSE}
  graphics,
{$ENDIF}
  sysutils,
  typex,
  types;


{$IFDEF FMX}
const
  clBlack = claBlack;
  clSilver = claSilver;
  clGrey = claGrey;
  clNavy = claNavy;
  clBlue = claBlue;
  clGreen = claGreen;
  clLime = claLime;
  clRed = claRed;
  clMagenta = claMagenta;
  clFuchia = claMagenta;
  clCyan = claCyan;
  clWhite = claWhite;
{$ELSE}
const clOrange = $007fFF;
const clCyan = $FFFF00;
const clMagenta = $FF00FF;

{$ENDIF}

const primary_hues: array[0..8] of TColor = ($FF, $7fFF, $FFFF, $FF00, $FFFF00, $FF0000, $FF009F, $FF00FF,$FFFFFF);
const Chart_colors: array[0..21] of Tcolor = ($FF, $7FFF, $FFFF,$FF00,$FFFF00,$FF7F00,$FF0000,$FF007f,$7f, $3F7F, $7F7F,$3F00,$7F7F00,$7F3F00,$7F0000,$7F003f, $8080FF, $807FFF, $80FFFF,$80FF80,$FF8080,$FF807f);
const Chart_colors_dark_mode: array[0..20] of Tcolor = ($7f7fFF, $00FFFF,$00FF00,$FFFF00,$FF7F00,$FF3f00,$FF007f,$7f7f7f, $7f3FFF, $7f7FFF,$7fFF7f,$FFFF7f,$FF7f3f,$FF7f7f,$fF3f3f, $8080FF, $807FFF, $80FFFF,$80FF80,$FF8080,$FF807f);




type
  TXPixelFormat = (xpf8bit, xpf16bit, xpf24Bit, xpf32bit);
{$IFDEF FMX}
  TColor = TAlphaColor;
  TPixelFormat = (gpf8bit, gpf16bit, gpf24Bit, gpf32bit);

{$ELSE}
  TColor = graphics.TColor;
  TPixelFormat = graphics.Tpixelformat;
      //(pfDevice, pf1bit, pf4bit, pf8bit, pf15bit, pf16bit, pf24bit, pf32bit, pfCustom);
{$ENDIF}

function PixelSize(pf: TPixelFormat): ni;overload;
function PixelSize(pf: TXPixelFormat): ni;overload;

function GetVUColor(segmentmod: double): TColor;
function GetVUColorNarrow(segmentmod: double): TColor;


implementation

uses
  colorblending;

function GetVUColor(segmentmod: double): TColor;
begin
  if segmentmod < 0.25 then
    exit(colorblend(clBlack, clNavy, segmentmod*4));
  if segmentmod < 0.50 then
    exit(colorblend(clNavy, clGreen, (segmentmod-0.25)*4.0));
  if segmentmod < 0.75 then
    exit(colorblend(clGreen, clRed, (segmentmod-0.5)*4.0));

{$IFDEF FMX}
  var clWhite := claWhite;
{$ENDIF}
  exit(colorblend(clRed, clWhite, (segmentmod-0.75)*4.0));
end;

function GetVUColorNarrow(segmentmod: double): TColor;
begin
  result := GetVUColor((segmentmod*0.5)+0.25);

end;



function PixelSize(pf: TXPixelFormat): ni;
begin
  result := 0;
  case pf of
    xpf8Bit: exit(1);
    xpf16bit: exit(2);
    xpf24bit: exit(3);
    xpf32bit: exit(4);
  else
    raise ECritical.create('TXPixelFormat size not handled');
  end;
  raise ECritical.create('unhandled pixel type');
end;

function PixelSize(pf: TPixelFormat): ni;
begin
  case pf of
{$IFDEF FMX}
    gpf8Bit: exit(1);
    gpf16bit: exit(2);
    gpf24bit: exit(3);
    gpf32bit: exit(4);
{$ELSE}
    pf8Bit: exit(1);
    pf16bit: exit(2);
    pf24bit: exit(3);
    pf32bit: exit(4);
{$ENDIF}
  else
    raise ECritical.create('pixel format not byte size. '+inttostr(ord(pf)));
  end;
end;


end.

