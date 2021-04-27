unit GraphTypes;
(*
  Common types and constants for graphics units.
*)


(***)  interface  (***)

uses
  DlgMes,
  Math,
  SysUtils,
  Types,

  Utils;


const
  BMP_24_COLOR_DEPTH = 24;

  (* Color15 masks *)
  BLUE_CHANNEL_MASK15  = $00001F;
  GREEN_CHANNEL_MASK15 = $0003E0;
  RED_CHANNEL_MASK15   = $007C00;

  (* Color16 masks *)
  BLUE_CHANNEL_MASK16  = $00001F;
  GREEN_CHANNEL_MASK16 = $0007E0;
  RED_CHANNEL_MASK16   = $00F800;

  (* Color32 masks *)
  ALPHA_CHANNEL_MASK_32        = integer($FF000000);
  RGB_CHANNELS_MASK_32         = $00FFFFFF;
  RED_BLUE_CHANNELS_MASK_32    = $00FF00FF;
  GREEN_CHANNEL_MASK_32        = $0000FF00;
  ALPHA_GREEN_CHANNELS_MASK_32 = integer(ALPHA_CHANNEL_MASK_32 or GREEN_CHANNEL_MASK_32);
  FULLY_OPAQUE_MASK32          = integer($FF000000);

  (* Limits *)
  MAX_IMAGE_WIDTH  = 10000;
  MAX_IMAGE_HEIGHT = 10000;

type
  (* Color encoding in 16 bits: R5G5B5 or R5G6B5*)
  TColor16Mode = (COLOR_16_MODE_565, COLOR_16_MODE_555);

  (* Bits per channel depend on source color16 mode. See TColor16Node *)
  PColor16 = ^TColor16;
  TColor16 = packed record
    Value: word;
  end;

  PColor24 = ^TColor24;
  TColor24 = packed record
    Blue:  byte;
    Green: byte;
    Red:   byte;
  end;

  PColor32 = ^TColor32;
  TColor32 = packed record
    case byte of
      0: (Value: integer);
      1: (
        Blue:  byte;
        Green: byte;
        Red:   byte;
        Alpha: byte;
      );
  end;

  PColor16Arr = ^TColor16Arr;
  TColor16Arr = array [0..high(integer) div sizeof(TColor16) - 1] of TColor16;
  PColor24Arr = ^TColor24Arr;
  TColor24Arr = array [0..high(integer) div sizeof(TColor24) - 1] of TColor24;
  PColor32Arr = ^TColor32Arr;
  TColor32Arr = array [0..high(integer) div sizeof(TColor32) - 1] of TColor32;

  TArrayOfColor16 = array of TColor16;
  TArrayOfColor24 = array of TColor24;
  TArrayOfColor32 = array of TColor32;

  TImageRatio = packed record
    Width:  single; // Width / Height
    Height: single; // Height / Width
  end;

  TImageSize = packed record
    Width:  integer;
    Height: integer;
  end;

  TRawImageSetup = record
    HasTransparency: boolean; // Default is false

    procedure Init;
  end;

  TRawImage16Setup = record
    Color16Mode: TColor16Mode; // Default is global mode

    procedure Init;
  end;

  TRawImage32Setup = record
    HasTransparency: boolean; // Default is false

    procedure Init;
  end;

  TDrawImageSetup = record
    EnableFilters:  boolean;
    DoReplaceColor: boolean;
    ReplaceColor1:  TColor32;
    ReplaceColor2:  TColor32;
    DoHorizMirror:  boolean;

    procedure Init;
  end;

  (* Decoded image without direct pixels access *)
  TRawImage = class
   protected
    fWidth:           integer;
    fHeight:          integer;
    fHasTransparency: boolean;

   public
    constructor Create (Width, Height: integer; const Setup: TRawImageSetup);

    property Width:           integer read fWidth;
    property Height:          integer read fHeight;
    property HasTransparency: boolean read fHasTransparency;

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); virtual;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); virtual;
  end;

  TRawImage16 = class (TRawImage)
   protected
    fScanlineSize: integer;
    fPixels:       TArrayOfColor16;

   public
    constructor Create (Pixels: TArrayOfColor16; Width, Height, ScanlineSize: integer; const Setup: TRawImage16Setup);

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;

    property ScanlineSize: integer         read fScanlineSize;
    property Pixels:       TArrayOfColor16 read fPixels;
  end;

  TRawImage32 = class (TRawImage)
   protected
    fScanlineSize: integer;
    fPixels:       TArrayOfColor32;

   public
    constructor Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TRawImage32Setup);

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;

    property ScanlineSize: integer         read fScanlineSize;
    property Pixels:       TArrayOfColor32 read fPixels;
  end;

  (* Premultiplication occurs during construction. Do not use this class for images without transparency. See PremultiplyImageColorChannels *)
  TPremultipliedRawImage32 = class (TRawImage32)
   public
    constructor Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer);

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
  end;


  function GetColor16Mode: TColor16Mode;
  function SetColor16Mode (NewMode: TColor16Mode): TColor16Mode;

  function Color32To15Func (Color32: integer): integer;
  function Color32To16Func (Color32: integer): integer;
  function Color16To32Func (Color16: integer): integer;
  function Color15To32Func (Color15: integer): integer;
  function Color32ToCode   (Color32: integer): string;

  (* Premultiplies RGB color channels by color opacity *)
  function PremultiplyColorChannelsByAlpha (Color32: integer): integer;

  (* Efficient Color32 pixels alpha blending *)
  function AlphaBlend32 (FirstColor32, SecondColor32: integer): integer;

  (* Efficient Color32 pixels alpha blending. RGB channels of the second color must be premultiplied by opacity and opacity will be converted to transparency *)
  function AlphaBlendWithPremultiplied32 (FirstColor32, SecondColor32Premultiplied: integer): integer; inline;

  (* Each pixel color channel is multiplied by opacity value and alpha channel is converted from opacity to transparency *)
  procedure PremultiplyImageColorChannels (Pixels: TArrayOfColor32);

  (* Converts RGBA pixels array into standard BGRA/Color32 *)
  procedure RgbaToBgraPixels (Pixels: TArrayOfColor32);

  (* Converts Color32 pixels array into Color16 pixels array. Alpha channel is ignored *)
  function Color32ToColor16Pixels (Pixels: TArrayOfColor32): TArrayOfColor16;

  (* Returns true if there is intersected area to copy pixels from/to. Updates input parameters with new fixed values *)
  function RefineDrawBox (var SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; SrcWidth, SrcHeight, DstWidth, DstHeight: integer): boolean;


var
  // Global functions, dependent on SetColor16Mode.
  Color32To16: function (Color32: integer): integer;
  Color16To32: function (Color16: integer): integer;


(***)  implementation  (***)


const
  DRAW_PIXEL_COPY_PIXEL   = false;
  DRAW_PIXEL_USE_BLENDING = true;

var
  Color16Mode: TColor16Mode = COLOR_16_MODE_565;


function Color32To15Func (Color32: integer): integer;
begin
  result :=
    ((Color32 and $0000F8) shr 3) or
    ((Color32 and $00F800) shr 6) or
    ((Color32 and $F80000) shr 9);
end;

function Color32To16Func (Color32: integer): integer;
begin
  result :=
    ((Color32 and $0000F8) shr 3) or
    ((Color32 and $00FC00) shr 5) or
    ((Color32 and $F80000) shr 8);
end;

function Color16To32Func (Color16: integer): integer;
begin
  result :=
    (
      ((Color16 and BLUE_CHANNEL_MASK16)  shl 3) or
      ((Color16 and GREEN_CHANNEL_MASK16) shl 5) or
      ((Color16 and RED_CHANNEL_MASK16)   shl 8) or
      GraphTypes.FULLY_OPAQUE_MASK32
    ) and $FFF8FCF8;
end;

function Color15To32Func (Color15: integer): integer;
begin
  result :=
    (
      ((Color15 and BLUE_CHANNEL_MASK15)  shl 3) or
      ((Color15 and GREEN_CHANNEL_MASK15) shl 6) or
      ((Color15 and RED_CHANNEL_MASK15)   shl 9) or
      FULLY_OPAQUE_MASK32
    ) and $FFF8F8F8;
end;

function Color32ToCode (Color32: integer): string;
begin
  result := SysUtils.Format('%.8x', [((Color32 and RGB_CHANNELS_MASK_32) shl 8) or ((Color32 shr 24) and $FF)]);
end;

function GetColor16Mode: TColor16Mode;
begin
  result := Color16Mode;
end;

function SetColor16Mode (NewMode: TColor16Mode): TColor16Mode;
begin
  result      := Color16Mode;
  Color16Mode := NewMode;

  if NewMode = COLOR_16_MODE_565 then begin
    Color32To16 := Color32To16Func;
    Color16To32 := Color16To32Func;
  end else begin
    Color32To16 := Color32To15Func;
    Color16To32 := Color15To32Func;
  end;
end;

function PremultiplyColorChannelsByAlpha (Color32: integer): integer;
var
  AlphaChannel:    integer;
  ColorOpaqueness: integer;

begin
  AlphaChannel    := Color32 and ALPHA_CHANNEL_MASK_32;
  ColorOpaqueness := AlphaChannel shr 24;
  result          := (((ColorOpaqueness * (Color32 and RED_BLUE_CHANNELS_MASK_32)) shr 8) and RED_BLUE_CHANNELS_MASK_32) or
                     (((ColorOpaqueness * (Color32 and GREEN_CHANNEL_MASK_32))     shr 8) and GREEN_CHANNEL_MASK_32)     or
                     integer(ALPHA_CHANNEL_MASK_32 - AlphaChannel);
end;

function AlphaBlendWithPremultiplied32 (FirstColor32, SecondColor32Premultiplied: integer): integer; inline;
var
  SecondColorTransparency: integer;

begin
  SecondColorTransparency := (SecondColor32Premultiplied and ALPHA_CHANNEL_MASK_32) shr 24;

  // Convert TransparencyMult=255 into TransparencyMult=256 to prevent original pixel changing if the second one is fully transparent
  // *255 shr 8 (same as div 256) was not ideal solution
  Inc(SecondColorTransparency, (SecondColorTransparency + 1) shr 8);

  result := ((((SecondColorTransparency * (FirstColor32  and RED_BLUE_CHANNELS_MASK_32))   shr 8)  and RED_BLUE_CHANNELS_MASK_32) or
            ((  SecondColorTransparency * ((FirstColor32 and ALPHA_GREEN_CHANNELS_MASK_32) shr 8)) and ALPHA_GREEN_CHANNELS_MASK_32))
            + SecondColor32Premultiplied;
end;

function AlphaBlend32 (FirstColor32, SecondColor32: integer): integer;
const
  ONE_ALPHA_CHANNEL_MASK_32 = $01000000;

var
  SecondColorTransparency: integer;
  SecondColorOpacity:      integer;
  RedBlueChannels:         integer;
  AlphaGreenChannels:      integer;

begin
  SecondColorOpacity  := (SecondColor32 and ALPHA_CHANNEL_MASK_32) shr 24;
  SecondColorTransparency:= 255 - SecondColorOpacity;
  RedBlueChannels        := (SecondColorTransparency * (FirstColor32  and RED_BLUE_CHANNELS_MASK_32) +
                             SecondColorOpacity      * (SecondColor32 and RED_BLUE_CHANNELS_MASK_32))   shr 8;
  AlphaGreenChannels     := SecondColorTransparency  * ((FirstColor32 and ALPHA_GREEN_CHANNELS_MASK_32) shr 8) +
                            SecondColorOpacity       * (ONE_ALPHA_CHANNEL_MASK_32 or ((SecondColor32 and GREEN_CHANNEL_MASK_32) shr 8));
  result                 := (RedBlueChannels and RED_BLUE_CHANNELS_MASK_32) or (AlphaGreenChannels and ALPHA_GREEN_CHANNELS_MASK_32);
end;

procedure PremultiplyImageColorChannels (Pixels: TArrayOfColor32);
var
  i:            integer;
  Color32:      integer;
  AlphaChannel: integer;
  ColorOpacity: integer;

begin
  for i := 0 to High(Pixels) do begin
    Color32         := Pixels[i].Value;
    AlphaChannel    := Color32 and ALPHA_CHANNEL_MASK_32;
    ColorOpacity    := AlphaChannel shr 24;
    Pixels[i].Value := (((ColorOpacity * (Color32 and RED_BLUE_CHANNELS_MASK_32)) shr 8) and RED_BLUE_CHANNELS_MASK_32) or
                       (((ColorOpacity * (Color32 and GREEN_CHANNEL_MASK_32))     shr 8) and GREEN_CHANNEL_MASK_32)     or
                       integer(ALPHA_CHANNEL_MASK_32 - AlphaChannel);
  end;
end;

procedure RgbaToBgraPixels (Pixels: TArrayOfColor32);
var
  i:       integer;
  Color32: integer;

begin
  for i := 0 to High(Pixels) do begin
    Color32         := Pixels[i].Value;
    Pixels[i].Value := (Color32 and integer($FF00FF00)) or ((Color32 and $FF) shl 16) or ((Color32 and $FF0000) shr 16);
  end;
end;

function Color32ToColor16Pixels (Pixels: TArrayOfColor32): TArrayOfColor16;
var
  i: integer;

begin
  SetLength(result, Length(Pixels));

  for i := 0 to High(Pixels) do begin
    result[i].Value := Color32To16(Pixels[i].Value);
  end;
end;

function RefineDrawBox (var SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; SrcWidth, SrcHeight, DstWidth, DstHeight: integer): boolean;
var
  SrcBox: TRect;
  DstBox: TRect;

begin
  result := (BoxWidth > 0) and (BoxHeight > 0) and (SrcWidth > 0) and (SrcHeight > 0) and (DstWidth > 0) and (DstHeight > 0);

  if result then begin
    // Get source and destination boxes with pixels to read/write
    result := Types.IntersectRect(SrcBox, Types.Rect(0, 0, SrcWidth, SrcHeight), Types.Rect(SrcX, SrcY, SrcX + BoxWidth, SrcY + BoxHeight)) and
              Types.IntersectRect(DstBox, Types.Rect(0, 0, DstWidth, DstHeight), Types.Rect(DstX, DstY, DstX + BoxWidth, DstY + BoxHeight));
  end;

  if result then begin
    // Move source box to destination box and determine intersection. If it exists, then we have pixels to draw for sure
    Types.OffsetRect(SrcBox, DstX - SrcX, DstY - SrcY);
    result := Types.IntersectRect(DstBox, DstBox, SrcBox);
  end;

  if result then begin
    // Source box is DstBox with origin moved back
    SrcBox := DstBox;
    Types.OffsetRect(SrcBox, SrcX - DstX, SrcY - DstY);

    // Update all out parameters
    SrcX      := SrcBox.Left;
    SrcY      := SrcBox.Top;
    BoxWidth  := SrcBox.Right  - SrcBox.Left;
    BoxHeight := SrcBox.Bottom - SrcBox.Top;
    DstX      := DstBox.Left;
    DstY      := DstBox.Top;
  end;
end; // .function RefineDrawBox

procedure DrawPixelWithFilters (SrcPixelValue, DstPixelValue: integer; DstPixelPtr: pointer; DstPixelSize: integer; UseBlending: boolean; const DrawImageSetup: TDrawImageSetup); inline;
begin
  if DrawImageSetup.DoReplaceColor and (SrcPixelValue = DrawImageSetup.ReplaceColor1.Value) then begin
    DstPixelValue := DrawImageSetup.ReplaceColor2.Value;
  end else if UseBlending then begin
    DstPixelValue := AlphaBlendWithPremultiplied32(DstPixelValue, SrcPixelValue);
  end else begin
    DstPixelValue := SrcPixelValue;
  end;

  if DstPixelSize = sizeof(TColor32) then begin
    pinteger(DstPixelPtr)^ := DstPixelValue;
  end else begin
    pword(DstPixelPtr)^ := Color32To16(DstPixelValue);
  end;
end;

procedure TRawImageSetup.Init;
begin
  Self.HasTransparency := false;
end;

procedure TRawImage.DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                       const DrawImageSetup: TDrawImageSetup);
begin
  // Implement in descendants
end;

procedure TRawImage.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                       const DrawImageSetup: TDrawImageSetup);
begin
  // Implement in descendants
end;

procedure TRawImage16Setup.Init;
begin
  Self.Color16Mode := GetColor16Mode;
end;

procedure TRawImage16.DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                         const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  MinScanlineSize: integer;
  SrcScanline:     PColor16;
  DstScanline:     PColor16;
  i:               integer;

  DstPixelStep: integer;
  SrcPixel:     PColor16;
  DstPixel:     PColor16;
  j:            integer;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight) then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      MinScanlineSize := Math.Min(SrcScanlineSize, DstScanlineSize);
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for i := 0 to BoxHeight - 1 do begin
        System.Move(SrcScanline^, DstScanline^, MinScanlineSize);
        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    // Slow drawing with filters support
    end else begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));
      DstPixelStep    := sizeof(DstBuf[0]);

      if DrawImageSetup.DoHorizMirror then begin
        Inc(integer(DstScanline), (BoxWidth - 1) * sizeof(DstBuf[0]));
        DstPixelStep := -DstPixelStep;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(Color16To32(SrcPixel.Value), Color16To32(DstPixel.Value), DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_COPY_PIXEL, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end;
end;

procedure TRawImage32Setup.Init;
begin
  Self.HasTransparency := false;
end;

procedure TDrawImageSetup.Init ();
begin
  System.FillChar(Self, sizeof(Self), #0);
end;

constructor TRawImage.Create (Width, Height: integer; const Setup: TRawImageSetup);
begin
  {!} Assert(Width > 0);
  {!} Assert(Height > 0);

  Self.fWidth      := Width;
  Self.fHeight     := Height;
  Self.fHasTransparency := Setup.HasTransparency;
end;

constructor TRawImage16.Create (Pixels: TArrayOfColor16; Width, Height, ScanlineSize: integer; const Setup: TRawImage16Setup);
var
  RawImageSetup: TRawImageSetup;

begin
  {!} Assert(Pixels <> nil);
  RawImageSetup.Init;
  RawImageSetup.HasTransparency := false;
  inherited Create(Width, Height, RawImageSetup);
  {!} Assert(ScanlineSize >= Width * sizeof(Pixels[0]));

  Self.fPixels       := Pixels;
  Self.fScanlineSize := ScanlineSize;
end;

constructor TRawImage32.Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TRawImage32Setup);
var
  RawImageSetup: TRawImageSetup;

begin
  {!} Assert(Pixels <> nil);
  RawImageSetup.Init;
  RawImageSetup.HasTransparency := Setup.HasTransparency;
  inherited Create(Width, Height, RawImageSetup);
  {!} Assert(ScanlineSize >= Width * sizeof(Pixels[0]));

  Self.fPixels       := Pixels;
  Self.fScanlineSize := ScanlineSize;
end;

procedure TRawImage32.DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                         const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  SrcScanline:     PColor32;
  SrcPixel:        PColor32;
  DstScanline:     PColor16;
  DstPixel:        PColor16;
  i, j:            integer;

  DstPixelStep: integer;

begin
  {!} Assert(not Self.HasTransparency, 'TRawImage32.DrawToOpaque16Buffer does not support alpha channel yet. Use TPremultipliedRawImage32');

  if (DstBuf <> nil) and (DstScanlineSize > 0) and RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight) then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := Color32To16(SrcPixel.Value);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    // Slow drawing with filters support
    end else begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));
      DstPixelStep    := sizeof(DstBuf[0]);

      if DrawImageSetup.DoHorizMirror then begin
        Inc(integer(DstScanline), (BoxWidth - 1) * sizeof(DstBuf[0]));
        DstPixelStep := -DstPixelStep;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(SrcPixel.Value, Color16To32(DstPixel.Value), DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_COPY_PIXEL, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end;
end; // .procedure TRawImage32.DrawToOpaque16Buf

procedure TRawImage32.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                         const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  MinScanlineSize: integer;
  SrcScanline:     PColor32;
  DstScanline:     PColor32;
  i:               integer;

  DstPixelStep: integer;
  SrcPixel:     PColor32;
  DstPixel:     PColor32;
  j:            integer;

begin
  {!} Assert(not Self.HasTransparency, 'TRawImage32.DrawToOpaque32Buffer does not support alpha channel yet. Use TPremultipliedRawImage32');

  if (DstBuf <> nil) and (DstScanlineSize > 0) and RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight) then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      MinScanlineSize := Math.Min(SrcScanlineSize, DstScanlineSize);
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for i := 0 to BoxHeight - 1 do begin
        System.Move(SrcScanline^, DstScanline^, MinScanlineSize);
        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    // Slow drawing with filters support
    end else begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));
      DstPixelStep    := sizeof(DstBuf[0]);

      if DrawImageSetup.DoHorizMirror then begin
        Inc(integer(DstScanline), (BoxWidth - 1) * sizeof(DstBuf[0]));
        DstPixelStep := -DstPixelStep;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(SrcPixel.Value, DstPixel.Value, DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_COPY_PIXEL, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end; // .if
end; // .procedure TRawImage32.DrawToOpaque32Buf

constructor TPremultipliedRawImage32.Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer);
var
  Setup: TRawImage32Setup;

begin
  Setup.Init;
  Setup.HasTransparency := true;

  inherited Create(Pixels, Width, Height, ScanlineSize, Setup);

  PremultiplyImageColorChannels(Self.fPixels);
end;

procedure TPremultipliedRawImage32.DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                                      const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  SrcScanline:     PColor32;
  SrcPixel:        PColor32;
  DstScanline:     PColor16;
  DstPixel:        PColor16;
  i, j:            integer;

  DstPixelStep: integer;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight) then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := Color32To16(AlphaBlendWithPremultiplied32(Color16To32(DstPixel.Value), SrcPixel.Value));

          Inc(SrcPixel);
          Inc(DstPixel);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    // Slow drawing with filters support
    end else begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));
      DstPixelStep    := sizeof(DstBuf[0]);

      if DrawImageSetup.DoHorizMirror then begin
        Inc(integer(DstScanline), (BoxWidth - 1) * sizeof(DstBuf[0]));
        DstPixelStep := -DstPixelStep;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(SrcPixel.Value, Color16To32(DstPixel.Value), DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_USE_BLENDING, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end; // .if
end; // .procedure TPremultipliedRawImage32.DrawToOpaque16Buf

procedure TPremultipliedRawImage32.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                                      const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  SrcScanline:     PColor32;
  SrcPixel:        PColor32;
  DstScanline:     PColor32;
  DstPixel:        PColor32;
  i, j:            integer;

  DstPixelStep: integer;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight) then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := AlphaBlendWithPremultiplied32(DstPixel.Value, SrcPixel.Value);

          Inc(SrcPixel);
          Inc(DstPixel);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    // Slow drawing with filters support
    end else begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));
      DstPixelStep    := sizeof(DstBuf[0]);

      if DrawImageSetup.DoHorizMirror then begin
        Inc(integer(DstScanline), (BoxWidth - 1) * sizeof(DstBuf[0]));
        DstPixelStep := -DstPixelStep;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(SrcPixel.Value, DstPixel.Value, DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_USE_BLENDING, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end; // .if
end; // .procedure TPremultipliedRawImage32.DrawToOpaque32Buf

end.