unit GraphTypes;
(*
  Common types and constants for graphics units.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,
  Types,

  DataLib,
  DlgMes,
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
  (* Import *)
  TRect = Types.TRect;
  TDict = DataLib.TDict;

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

  TPremultipliedRawImage32Setup = record
    procedure Init;
  end;

  PDrawImageSetup = ^TDrawImageSetup;
  TDrawImageSetup = record
    EnableFilters:  boolean;
    DoReplaceColor: boolean;
    ReplaceColor1:  TColor32;
    ReplaceColor2:  TColor32;
    DoHorizMirror:  boolean;
    DoVertMirror:   boolean;

    procedure Init;
  end;

  (* Decoded image without direct pixels access *)
  TRawImage = class
   protected
       fWidth:           integer; // Virtual width (may be cropped by transparent pixels)
       fHeight:          integer; // Virtual height (may be cropped by transparent pixels)
       fHasTransparency: boolean;
       fCroppingRect:    TRect;   // Area used for cropping
    {O}fMeta:            {O} TDict {of TObject};

    function GetCroppedWidth: integer; inline;
    function GetCroppedHeight: integer; inline;

   public
    constructor Create (Width, Height: integer; const Setup: TRawImageSetup);
    destructor Destroy; override;

    property Width:           integer read fWidth;
    property Height:          integer read fHeight;
    property HasTransparency: boolean read fHasTransparency;
    property CroppingRect:    TRect   read fCroppingRect; // Area with really existing pixels after cropping
    property Meta:            TDict   read fMeta;

    function GetPixelSize: integer; virtual;
    function InternalizeColor32 (Color32: integer): integer; virtual;
    procedure MakeBackup; virtual;
    procedure RestoreFromBackup; virtual;
    procedure ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer); virtual;

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); virtual;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); virtual;
  end;

  TRawImage16 = class (TRawImage)
   protected
    fScanlineSize: integer;
    fPixels:       TArrayOfColor16;
    fPixelsBackup: TArrayOfColor16;

   public
    constructor Create (Pixels: TArrayOfColor16; Width, Height, ScanlineSize: integer; const Setup: TRawImage16Setup);

    function GetPixelSize: integer; override;
    function InternalizeColor32 (Color32: integer): integer; override;
    procedure MakeBackup; override;
    procedure RestoreFromBackup; override;
    procedure ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer); override;

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;

    property ScanlineSize: integer         read fScanlineSize;
    property Pixels:       TArrayOfColor16 read fPixels;
  end;

  TRawImage32 = class (TRawImage)
   protected
    fScanlineSize: integer;
    fPixels:       TArrayOfColor32;
    fPixelsBackup: TArrayOfColor32;

   public
    constructor Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TRawImage32Setup);

    procedure MakeBackup; override;
    procedure RestoreFromBackup; override;
    procedure ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer); override;

    procedure DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;

    property ScanlineSize: integer         read fScanlineSize;
    property Pixels:       TArrayOfColor32 read fPixels;
  end;

  (* Premultiplication occurs during construction. Do not use this class for images without transparency. See PremultiplyImageColorChannels.
     Support cropping. Real pixels array holds only cropped area. *)
  TPremultipliedRawImage32 = class (TRawImage)
   protected
    fScanlineSize: integer;
    fPixels:       TArrayOfColor32;
    fPixelsBackup: TArrayOfColor32;

   public
    constructor Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TPremultipliedRawImage32Setup);

    procedure MakeBackup; override;
    procedure RestoreFromBackup; override;
    function InternalizeColor32 (Color32: integer): integer; override;
    procedure ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer); override;
    procedure AutoCrop;

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
  function AlphaBlend32OpaqueBack (FirstColor32, SecondColor32: integer): integer;

  (* Efficient Color32 pixels alpha blending. RGB channels of the second color must be premultiplied by opacity and opacity will be converted to transparency *)
  function AlphaBlend32OpaqueBackWithPremultiplied (FirstColor32, SecondColor32Premultiplied: integer): integer; inline;

  (* Each pixel color channel is multiplied by opacity value and alpha channel is converted from opacity to transparency *)
  procedure PremultiplyImageColorChannels (Pixels: TArrayOfColor32);

  (* Converts RGBA pixels array into standard BGRA/Color32 *)
  procedure RgbaToBgraPixels (Pixels: TArrayOfColor32);

  (* Converts Color32 pixels array into Color16 pixels array. Alpha channel is ignored *)
  function Color32ToColor16Pixels (Pixels: TArrayOfColor32): TArrayOfColor16;

  (* TRect dimensions calculation routines *)
  function GetRectWidth  (const Rect: TRect): integer;
  function GetRectHeight (const Rect: TRect): integer;

  (* Returns true if there is intersected area to copy pixels from/to. Updates input parameters with new fixed values *)
  function RefineDrawBox (var SrcX, SrcY, DstX, DstY, DrawBoxWidth, DrawBoxHeight: integer; const SrcBox, DstBox: TRect; DoHorizMirror, DoVertMirror: boolean): boolean;

  (* Returns true if there is intersected area to copy pixels from/to. Updates input parameters with new fixed values. All src coordinates and dimensions are virtual
     and correspond to source image before cropping. They will be adjusted to real coordinates *)
  function RefineDrawBoxWithSourceCropping (var SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; SrcWidth, SrcHeight, DstWidth, DstHeight: integer;
                                            const SourceCroppingRect: TRect; DoHorizMirror, DoVertMirror: boolean): boolean;


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

function AlphaBlend32OpaqueBackWithPremultiplied (FirstColor32, SecondColor32Premultiplied: integer): integer; inline;
var
  SecondColorTransparency: integer;

begin
  // Convert TransparencyMult=255 into TransparencyMult=256 to prevent original pixel changing if the second one is fully transparent
  // *255 shr 8 (same as div 256) is not ideal solution
  SecondColorTransparency := (SecondColor32Premultiplied and ALPHA_CHANNEL_MASK_32) shr 24 + 1;

  result := ((((SecondColorTransparency * (FirstColor32  and RED_BLUE_CHANNELS_MASK_32))   shr 8)  and RED_BLUE_CHANNELS_MASK_32) or
            ((  SecondColorTransparency * ((FirstColor32 and ALPHA_GREEN_CHANNELS_MASK_32) shr 8)) and ALPHA_GREEN_CHANNELS_MASK_32))
            + SecondColor32Premultiplied;
end;

function AlphaBlend32OpaqueBack (FirstColor32, SecondColor32: integer): integer;
const
  ONE_ALPHA_CHANNEL_MASK_32 = $01000000;

var
  SecondColorTransparency: integer;
  SecondColorOpacity:      integer;
  RedBlueChannels:         integer;
  AlphaGreenChannels:      integer;

begin
  SecondColorOpacity      := (SecondColor32 and ALPHA_CHANNEL_MASK_32) shr 24;
  SecondColorTransparency := 255 - SecondColorOpacity;
  RedBlueChannels         := (SecondColorTransparency * (FirstColor32  and RED_BLUE_CHANNELS_MASK_32) +
                              SecondColorOpacity      * (SecondColor32 and RED_BLUE_CHANNELS_MASK_32))   shr 8;
  AlphaGreenChannels      := SecondColorTransparency  * ((FirstColor32 and ALPHA_GREEN_CHANNELS_MASK_32) shr 8) +
                             SecondColorOpacity       * (ONE_ALPHA_CHANNEL_MASK_32 or ((SecondColor32 and GREEN_CHANNEL_MASK_32) shr 8));
  result                  := (RedBlueChannels and RED_BLUE_CHANNELS_MASK_32) or (AlphaGreenChannels and ALPHA_GREEN_CHANNELS_MASK_32);
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

function GetRectWidth (const Rect: TRect): integer;
begin
  result := Rect.Right - Rect.Left;
end;

function GetRectHeight (const Rect: TRect): integer;
begin
  result := Rect.Bottom - Rect.Top;
end;

function RefineDrawBox (var SrcX, SrcY, DstX, DstY, DrawBoxWidth, DrawBoxHeight: integer; const SrcBox, DstBox: TRect; DoHorizMirror, DoVertMirror: boolean): boolean;
var
  SrcDstOffsetX:             integer;
  SrcDstOffsetY:             integer;
  SrcDrawBox:                TRect;
  DstDrawBox:                TRect;
  MovedSrcBox:               TRect;
  CorrectedDstDrawBox:       TRect;
  CorrectedDstDrawBoxOffset: integer;

begin
  SrcDstOffsetX := 0;
  SrcDstOffsetY := 0;
  result        := (DrawBoxWidth > 0) and (DrawBoxHeight > 0) and not Types.IsRectEmpty(SrcBox) and not Types.IsRectEmpty(DstBox);

  if result then begin
    SrcDstOffsetX := DstX - SrcX;
    SrcDstOffsetY := DstY - SrcY;
    DstDrawBox    := Types.Rect(DstX, DstY, DstX + DrawBoxWidth, DstY + DrawBoxHeight);

    // Move SrcBox to DstBox so, that top-left draw box border became the same
    MovedSrcBox := SrcBox;
    Types.OffsetRect(MovedSrcBox, SrcDstOffsetX, SrcDstOffsetY);

    // Intersect DstDrawBox, DstBox and moved SrcBox as CorrectedDstDrawBox
    // We get box with pixels to copy, unless mirroring is necessary
    result := Types.IntersectRect(CorrectedDstDrawBox, DstBox, DstDrawBox) and Types.IntersectRect(CorrectedDstDrawBox, CorrectedDstDrawBox, MovedSrcBox);
  end;

  if result then begin
    // Perform horizontal mirroring
    if DoHorizMirror then begin
      CorrectedDstDrawBoxOffset := (CorrectedDstDrawBox.Right - DstDrawBox.Right) + (CorrectedDstDrawBox.Left - DstDrawBox.Left);
      Types.OffsetRect(CorrectedDstDrawBox, -CorrectedDstDrawBoxOffset, 0);
      result := Types.IntersectRect(CorrectedDstDrawBox, CorrectedDstDrawBox, DstDrawBox) and Types.IntersectRect(CorrectedDstDrawBox, CorrectedDstDrawBox, MovedSrcBox);
    end;
  end;

  if result then begin
    // Perform vertical mirroring
    if DoVertMirror then begin
      CorrectedDstDrawBoxOffset := (CorrectedDstDrawBox.Bottom - DstDrawBox.Bottom) + (CorrectedDstDrawBox.Top - DstDrawBox.Top);
      Types.OffsetRect(CorrectedDstDrawBox, 0, -CorrectedDstDrawBoxOffset);
      result := Types.IntersectRect(CorrectedDstDrawBox, CorrectedDstDrawBox, DstDrawBox) and Types.IntersectRect(CorrectedDstDrawBox, CorrectedDstDrawBox, MovedSrcBox);
    end;
  end;

  if result then begin
    // SrcDrawBox is CorrectedDstDrawBox substracting SrcDstOffset
    SrcDrawBox := CorrectedDstDrawBox;
    Types.OffsetRect(SrcDrawBox, -SrcDstOffsetX, -SrcDstOffsetY);

    // Update all out parameters
    SrcX          := SrcDrawBox.Left;
    SrcY          := SrcDrawBox.Top;
    DrawBoxWidth  := SrcDrawBox.Right  - SrcDrawBox.Left;
    DrawBoxHeight := SrcDrawBox.Bottom - SrcDrawBox.Top;
    DstX          := CorrectedDstDrawBox.Left;
    DstY          := CorrectedDstDrawBox.Top;
  end;
end; // .function RefineDrawBox

function RefineDrawBoxWithSourceCropping (var SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; SrcWidth, SrcHeight, DstWidth, DstHeight: integer;
                                          const SourceCroppingRect: TRect; DoHorizMirror, DoVertMirror: boolean): boolean;
begin
  result := not Types.IsRectEmpty(SourceCroppingRect) and (SourceCroppingRect.Left >= 0) and (SourceCroppingRect.Right  <= SrcWidth)  and
                                                          (SourceCroppingRect.Top >= 0)  and (SourceCroppingRect.Bottom <= SrcHeight) and
            RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, SourceCroppingRect, Types.Rect(0, 0, DstWidth, DstHeight), DoHorizMirror, DoVertMirror);

  if result then begin
    Dec(SrcX, SourceCroppingRect.Left);
    Dec(SrcY, SourceCroppingRect.Top);
  end;
end;

procedure DrawPixelWithFilters (SrcPixelValue, DstPixelValue: integer; DstPixelPtr: pointer; DstPixelSize: integer; UseBlending: boolean; const DrawImageSetup: TDrawImageSetup); inline;
begin
  if DrawImageSetup.DoReplaceColor and (SrcPixelValue = DrawImageSetup.ReplaceColor1.Value) then begin
    DstPixelValue := DrawImageSetup.ReplaceColor2.Value;
  end else if UseBlending then begin
    DstPixelValue := AlphaBlend32OpaqueBackWithPremultiplied(DstPixelValue, SrcPixelValue);
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

constructor TRawImage.Create (Width, Height: integer; const Setup: TRawImageSetup);
begin
  {!} Assert(Width > 0);
  {!} Assert(Height > 0);

  Self.fWidth           := Width;
  Self.fHeight          := Height;
  Self.fHasTransparency := Setup.HasTransparency;
  Self.fCroppingRect    := Types.Rect(0, 0, Self.fWidth, Self.fHeight);
  Self.fMeta            := DataLib.NewDict(Utils.ITEMS_ARE_OBJECTS, DataLib.CASE_SENSITIVE);
end;

destructor TRawImage.Destroy;
begin
  SysUtils.FreeAndNil(Self.fMeta);
end;

function TRawImage.GetCroppedWidth: integer;
begin
  result := Self.fCroppingRect.Right - Self.fCroppingRect.Left;
end;

function TRawImage.GetCroppedHeight: integer;
begin
  result := Self.fCroppingRect.Bottom - Self.fCroppingRect.Top;
end;

function TRawImage.GetPixelSize: integer;
begin
  result := sizeof(TColor32);
end;

function TRawImage.InternalizeColor32 (Color32: integer): integer;
begin
  result := Color32;
end;

procedure TRawImage.MakeBackup;
begin
  // Implement in descendants
end;

procedure TRawImage.RestoreFromBackup;
begin
  // Implement in descendants
end;

procedure TRawImage.ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer);
begin
  // Implement in descendants
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

function TRawImage16.GetPixelSize: integer;
begin
  result := sizeof(Self.fPixels[0]);
end;

function TRawImage16.InternalizeColor32 (Color32: integer): integer;
begin
  result := Color32To16(Color32);
end;

procedure TRawImage16.MakeBackup;
begin
  if (Self.fPixelsBackup = nil) and (Self.fPixels <> nil) then begin
    SetLength(Self.fPixelsBackup, Length(Self.fPixels));
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixels[0], @Self.fPixelsBackup[0]);
  end;
end;

procedure TRawImage16.RestoreFromBackup;
begin
  if Self.fPixelsBackup <> nil then begin
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixelsBackup[0], @Self.fPixels[0]);
  end;
end;

procedure TRawImage16.ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer);
var
  WhatColors16: TArrayOfColor16;
  Scanline:     PColor16;
  Pixel:        PColor16;
  PixelValue:   integer;
  ColorInd:     integer;
  i, j:         integer;

begin
  SetLength(WhatColors16, NumColors);

  for i := 0 to NumColors - 1 do begin
    WhatColors16[i].Value := Color32To16(WhatColors[i].Value);
  end;

  Scanline := @Self.fPixels[0];

  for j := 0 to Self.fHeight - 1 do begin
    Pixel := Scanline;

    for i := 0 to Self.fWidth - 1 do begin
      ColorInd   := 0;
      PixelValue := Pixel.Value;

      while (ColorInd < NumColors) and (WhatColors16[ColorInd].Value <> PixelValue) do begin
        Inc(ColorInd);
      end;

      if ColorInd < NumColors then begin
        Pixel.Value := Color32To16(WithColors[ColorInd].Value);
      end;

      Inc(Pixel);
    end;

    Inc(integer(Scanline), Self.fScanlineSize);
  end;
end; // .procedure TRawImage16.ReplaceColors

procedure TRawImage16.DrawToOpaque16Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor16Arr; DstScanlineSize: integer;
                                         const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize:  integer;
  DrawLineByteSize: integer;
  SrcScanline:      PColor16;
  DstScanline:      PColor16;
  i:                integer;

  DstPixelStep: integer;
  SrcPixel:     PColor16;
  DstPixel:     PColor16;
  j:            integer;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
     RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize  := Self.fScanlineSize;
      DrawLineByteSize := BoxWidth * sizeof(DstBuf[0]);
      SrcScanline      := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline      := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for i := 0 to BoxHeight - 1 do begin
        System.Move(SrcScanline^, DstScanline^, DrawLineByteSize);
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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
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

procedure TRawImage16.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                         const DrawImageSetup: TDrawImageSetup);
var
  SrcScanlineSize: integer;
  SrcScanline:     PColor16;
  SrcPixel:        PColor16;
  DstScanline:     PColor32;
  DstPixel:        PColor32;
  i, j:            integer;

  DstPixelStep: integer;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := Color16To32(SrcPixel.Value);

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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
      end;

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DrawPixelWithFilters(Color16To32(SrcPixel.Value), DstPixel.Value, DstPixel, sizeof(DstBuf[0]), DRAW_PIXEL_COPY_PIXEL, DrawImageSetup);

          Inc(SrcPixel);
          Inc(integer(DstPixel), DstPixelStep);
        end;

        Inc(integer(SrcScanline), SrcScanlineSize);
        Inc(integer(DstScanline), DstScanlineSize);
      end;
    end; // .else
  end;
end; // .procedure TRawImage16.DrawToOpaque32Buf

procedure TRawImage32Setup.Init;
begin
  Self.HasTransparency := false;
end;

procedure TDrawImageSetup.Init ();
begin
  System.FillChar(Self, sizeof(Self), #0);
end;

constructor TRawImage32.Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TRawImage32Setup);
var
  RawImageSetup: TRawImageSetup;

begin
  {!} Assert(Pixels <> nil);
  {!} Assert(ScanlineSize >= Width * sizeof(Pixels[0]));

  RawImageSetup.Init;
  RawImageSetup.HasTransparency := Setup.HasTransparency;

  inherited Create(Width, Height, RawImageSetup);

  Self.fPixels       := Pixels;
  Self.fScanlineSize := ScanlineSize;
end;

procedure TRawImage32.MakeBackup;
begin
  if (Self.fPixelsBackup = nil) and (Self.fPixels <> nil) then begin
    SetLength(Self.fPixelsBackup, Length(Self.fPixels));
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixels[0], @Self.fPixelsBackup[0]);
  end;
end;

procedure TRawImage32.RestoreFromBackup;
begin
  if Self.fPixelsBackup <> nil then begin
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixelsBackup[0], @Self.fPixels[0]);
  end;
end;

procedure TRawImage32.ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer);
var
  Scanline:   PColor32;
  Pixel:      PColor32;
  PixelValue: integer;
  ColorInd:   integer;
  i, j:       integer;

begin
  Scanline := @Self.fPixels[0];

  for j := 0 to Self.fHeight - 1 do begin
    Pixel := Scanline;

    for i := 0 to Self.fWidth - 1 do begin
      ColorInd   := 0;
      PixelValue := Pixel.Value;

      while (ColorInd < NumColors) and (WhatColors[ColorInd].Value <> PixelValue) do begin
        Inc(ColorInd);
      end;

      if ColorInd < NumColors then begin
        Pixel.Value := WithColors[ColorInd].Value;
      end;

      Inc(Pixel);
    end;

    Inc(integer(Scanline), Self.fScanlineSize);
  end;
end; // .procedure TRawImage32.ReplaceColors

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
  {!} Assert(not Self.HasTransparency, 'TRawImage32.DrawToOpaque16Buf does not support alpha channel yet. Use TPremultipliedRawImage32');

  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
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
  SrcScanlineSize:  integer;
  DrawLineByteSize: integer;
  SrcScanline:      PColor32;
  DstScanline:      PColor32;
  i:                integer;

  DstPixelStep: integer;
  SrcPixel:     PColor32;
  DstPixel:     PColor32;
  j:            integer;

begin
  {!} Assert(not Self.HasTransparency, 'TRawImage32.DrawToOpaque32Buf does not support alpha channel yet. Use TPremultipliedRawImage32');

  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize  := Self.fScanlineSize;
      DrawLineByteSize := BoxWidth * sizeof(DstBuf[0]);
      SrcScanline      := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline      := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for i := 0 to BoxHeight - 1 do begin
        System.Move(SrcScanline^, DstScanline^, DrawLineByteSize);
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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
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

procedure TPremultipliedRawImage32Setup.Init;
begin
end;

constructor TPremultipliedRawImage32.Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer; const Setup: TPremultipliedRawImage32Setup);
var
  RawImageSetup: TRawImageSetup;

begin
  {!} Assert(Pixels <> nil);
  {!} Assert(ScanlineSize >= Width * sizeof(Pixels[0]));

  RawImageSetup.Init;
  RawImageSetup.HasTransparency := true;
  inherited Create(Width, Height, RawImageSetup);

  Self.fPixels       := Pixels;
  Self.fScanlineSize := ScanlineSize;

  PremultiplyImageColorChannels(Self.fPixels);
end;

procedure TPremultipliedRawImage32.MakeBackup;
begin
  if (Self.fPixelsBackup = nil) and (Self.fPixels <> nil) then begin
    SetLength(Self.fPixelsBackup, Length(Self.fPixels));
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixels[0], @Self.fPixelsBackup[0]);
  end;
end;

procedure TPremultipliedRawImage32.RestoreFromBackup;
begin
  if Self.fPixelsBackup <> nil then begin
    Utils.CopyMem(Length(Self.fPixels) * sizeof(Self.fPixels[0]), @Self.fPixelsBackup[0], @Self.fPixels[0]);
  end;
end;

function TPremultipliedRawImage32.InternalizeColor32 (Color32: integer): integer;
begin
  result := PremultiplyColorChannelsByAlpha(Color32);
end;

procedure TPremultipliedRawImage32.ReplaceColors (const WhatColors, WithColors: PColor32Arr; NumColors: integer);
var
  PremultipliedWhatColors: TArrayOfColor32;
  Scanline:                PColor32;
  Pixel:                   PColor32;
  PixelValue:              integer;
  ColorInd:                integer;
  i, j:                    integer;

begin
  SetLength(PremultipliedWhatColors, NumColors);

  for i := 0 to NumColors - 1 do begin
    PremultipliedWhatColors[i].Value := PremultiplyColorChannelsByAlpha(WhatColors[i].Value);
  end;

  Scanline := @Self.fPixels[0];

  for j := 0 to Self.GetCroppedHeight - 1 do begin
    Pixel := Scanline;

    for i := 0 to Self.GetCroppedWidth - 1 do begin
      ColorInd   := 0;
      PixelValue := Pixel.Value;

      while (ColorInd < NumColors) and (PremultipliedWhatColors[ColorInd].Value <> PixelValue) do begin
        Inc(ColorInd);
      end;

      if ColorInd < NumColors then begin
        Pixel.Value := PremultiplyColorChannelsByAlpha(WithColors[ColorInd].Value);
      end;

      Inc(Pixel);
    end;

    Inc(integer(Scanline), Self.fScanlineSize);
  end;
end; // .procedure TPremultipliedRawImage32.ReplaceColors

procedure TPremultipliedRawImage32.AutoCrop;
var
  CroppingRect:    TRect;
  Scanline:        PColor32;
  ScanlineEnd:     PColor32;
  Pixel:           PColor32;
  LeftBorder:      integer;
  RightBorder:     integer;
  NewPixels:       TArrayOfColor32;
  NewScanline:     PColor32;
  OldScanlineSize: integer;
  j:               integer;

begin
  // Already cropped
  if not Types.EqualRect(Types.Rect(0, 0, Self.fWidth, Self.fHeight), Self.fCroppingRect) then begin
    exit;
  end;

  CroppingRect := Types.Rect(0, 0, Self.fWidth, Self.fHeight);

  // Trim from top
  j        := 0;
  Scanline := @Self.fPixels[0];

  while (j < CroppingRect.Bottom) do begin
    Pixel       := Scanline;
    ScanlineEnd := Utils.PtrOfs(Scanline, Self.fWidth, sizeof(Pixel^));

    while (cardinal(Pixel) < cardinal(ScanlineEnd)) and (Pixel.Alpha = 255) do begin
      Inc(Pixel);
    end;

    if cardinal(Pixel) < cardinal(ScanlineEnd) then begin
      break;
    end;

    Inc(j);
    Inc(integer(Scanline), Self.fScanlineSize);
  end;

  CroppingRect.Top := j;

  // Trim from bottom
  j        := CroppingRect.Bottom - 1;
  Scanline := Utils.PtrOfs(@Self.fPixels[0], j * Self.fScanlineSize);

  while (j > CroppingRect.Top) do begin
    Pixel       := Scanline;
    ScanlineEnd := Utils.PtrOfs(Scanline, Self.fWidth, sizeof(Pixel^));

    while (cardinal(Pixel) < cardinal(ScanlineEnd)) and (Pixel.Alpha = 255) do begin
      Inc(Pixel);
    end;

    if cardinal(Pixel) < cardinal(ScanlineEnd) then begin
      break;
    end;

    Dec(j);
    Dec(integer(Scanline), Self.fScanlineSize);
  end;

  CroppingRect.Bottom := j + 1;

  // Trim from left
  LeftBorder := CroppingRect.Right;

  j        := CroppingRect.Top;
  Scanline := Utils.PtrOfs(@Self.fPixels[0], j, Self.fScanlineSize);

  while (j < CroppingRect.Bottom) do begin
    Pixel       := Scanline;
    ScanlineEnd := Utils.PtrOfs(Scanline, LeftBorder, sizeof(Pixel^));

    while (cardinal(Pixel) < cardinal(ScanlineEnd)) and (Pixel.Alpha = 255) do begin
      Inc(Pixel);
    end;

    if cardinal(Pixel) < cardinal(ScanlineEnd) then begin
      LeftBorder := Utils.ItemPtrToIndex(Pixel, Scanline, sizeof(Pixel^));

      if LeftBorder = 0 then begin
        break;
      end;
    end;

    Inc(j);
    Inc(integer(Scanline), Self.fScanlineSize);
  end;

  CroppingRect.Left := LeftBorder;

  // Trim from right
  RightBorder := CroppingRect.Left;

  j        := CroppingRect.Top;
  Scanline := Utils.PtrOfs(@Self.fPixels[0], j, Self.fScanlineSize);

  while (j < CroppingRect.Bottom) do begin
    Pixel       := Utils.PtrOfs(Scanline, CroppingRect.Right - 1, sizeof(Pixel^));
    ScanlineEnd := Utils.PtrOfs(Scanline, RightBorder, sizeof(Pixel^));

    while (cardinal(Pixel) > cardinal(ScanlineEnd)) and (Pixel.Alpha = 255) do begin
      Dec(Pixel);
    end;

    if cardinal(Pixel) > cardinal(ScanlineEnd) then begin
      RightBorder := Utils.ItemPtrToIndex(Pixel, Scanline, sizeof(Pixel^));

      if (RightBorder + 1) = CroppingRect.Right then begin
        break;
      end;
    end;

    Inc(j);
    Inc(integer(Scanline), Self.fScanlineSize);
  end;

  CroppingRect.Right := RightBorder + 1;

  if Types.IsRectEmpty(CroppingRect) then begin
    System.FillChar(CroppingRect, sizeof(CroppingRect), #0);
  end;

  Self.fCroppingRect := CroppingRect;

  // Perform real image cropping to save memory
  if not Types.EqualRect(Types.Rect(0, 0, Self.fWidth, Self.fHeight), Self.fCroppingRect) then begin
    NewPixels          := nil;
    Self.fScanlineSize := 0;

    if not Types.IsRectEmpty(Self.fCroppingRect) then begin
      SetLength(NewPixels, Self.GetCroppedWidth * Self.GetCroppedHeight);
      OldScanlineSize    := Self.fWidth * sizeof(Self.fPixels[0]);
      Self.fScanlineSize := Self.GetCroppedWidth * sizeof(NewPixels[0]);
      Scanline           := @Self.fPixels[Self.fCroppingRect.Top * Self.fWidth + Self.fCroppingRect.Left];
      NewScanline        := @NewPixels[0];

      for j := Self.fCroppingRect.Top to Self.fCroppingRect.Bottom - 1 do begin
        Utils.CopyMem(Self.fScanlineSize, Scanline, NewScanline);
        Inc(integer(Scanline),    OldScanlineSize);
        Inc(integer(NewScanline), Self.fScanlineSize);
      end;
    end;

    Self.fPixels := NewPixels;
  end;
end; // .procedure TPremultipliedRawImage32.AutoCrop

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
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := Color32To16(AlphaBlend32OpaqueBackWithPremultiplied(Color16To32(DstPixel.Value), SrcPixel.Value));

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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
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
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBoxWithSourceCropping(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Self.fWidth, Self.fHeight, DstWidth, DstHeight, Self.fCroppingRect,
                                     DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    // Fast default drawing without filters
    if not DrawImageSetup.EnableFilters then begin
      SrcScanlineSize := Self.fScanlineSize;
      SrcScanline     := Ptr(integer(@Self.fPixels[0]) + SrcY * Self.fScanlineSize + SrcX * sizeof(Self.fPixels[0]));
      DstScanline     := Ptr(integer(DstBuf) + DstY * DstScanlineSize + DstX * sizeof(DstBuf[0]));

      for j := 0 to BoxHeight - 1 do begin
        SrcPixel := SrcScanline;
        DstPixel := DstScanline;

        for i := 0 to BoxWidth - 1 do begin
          DstPixel.Value := AlphaBlend32OpaqueBackWithPremultiplied(DstPixel.Value, SrcPixel.Value);

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

      if DrawImageSetup.DoVertMirror then begin
        Inc(integer(DstScanline), (BoxHeight - 1) * DstScanlineSize);
        DstScanlineSize := -DstScanlineSize;
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