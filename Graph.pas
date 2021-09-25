unit Graph;

(***)  interface  (***)

uses
  Classes,
  Jpeg,
  Math,
  SysUtils,
  Windows,

  Alg,
  ApiJack,
  Core,
  DataLib,
  DlgMes,
  EventMan,
  Files,
  GameExt,
  Graphics,
  GraphTypes,
  Heroes,
  Libspng,
  Lodman,
  PatchApi,
  PngImage,
  ResLib,
  StrLib,
  Trans,
  Types,
  TypeWrappers,
  WinUtils,
  Utils, KubaZip, EraZip;

const
  (* ResizeBmp24.FreeOriginal argument *)
  FREE_ORIGINAL_BMP      = true;
  DONT_FREE_ORIGINAL_BMP = false;

  BMP_24_COLOR_DEPTH = 24;

  (* Width and height values *)
  AUTO_WIDTH  = 0;
  AUTO_HEIGHT = 0;

  (* Colors *)
  COLOR_TRANSPARENT                      = integer($00000000);
  COLOR_ADV_MAP_OBJECT_FLAG_PLACEHOLDER  = integer($FFFFFF00);
  COLOR_BATTLE_DEF_SELECTION_PLACEHOLDER = integer($FFFFFF00);

  (* Paths *)
  DEF_PNG_FRAMES_DIR = 'Data\Defs';
  PCX_PNG_FRAMES_DIR = 'Data\Pcx';

type
  (* Import *)
  TGraphic    = Graphics.TGraphic;
  TBitmap     = Graphics.TBitmap;
  TJpegImage  = Jpeg.TJpegImage;
  TPngObject  = PngImage.TPngObject;
  TDict       = DataLib.TDict;
  TRect       = Types.TRect;
  TString     = TypeWrappers.TString;
  TInt        = TypeWrappers.TInt;
  TRawImage   = GraphTypes.TRawImage;
  TRawImage16 = GraphTypes.TRawImage16;
  TRawImage32 = GraphTypes.TRawImage32;

  TImageType = (IMG_UNKNOWN, IMG_BMP, IMG_JPG, IMG_PNG);
  TResizeAlg = (ALG_NO_RESIZE = 0, ALG_STRETCH = 1, ALG_CONTAIN = 2, ALG_DOWNSCALE = 3, ALG_UPSCALE = 4, ALG_COVER = 5, ALG_FILL = 6);

  TDimensionsDetectionType = (USE_IMAGE_VALUES, CALC_PROPORTIONALLY);

  TDrawDefFrameFlag  = (DDF_CROP, DDF_MIRROR, DDF_NO_SPECIAL_PALETTE_COLORS);
  TDrawDefFrameFlags = set of TDrawDefFrameFlag;

  PColorizablePlayerPalette32 = ^TColorizablePlayerPalette32;
  TColorizablePlayerPalette32 = array [0..31] of integer;
  PColorizablePlayerPalette16 = ^TColorizablePlayerPalette16;
  TColorizablePlayerPalette16 = array [0..31] of word;

  TPcx8ToRawImageAdapter = class (TRawImage)
   protected
   {O} fPcxItem: Heroes.PPcx8Item;

   public
    constructor Create (PcxItem: Heroes.PPcx8Item);
    destructor Destroy; override;

    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
  end;

  TPcx16ToRawImageAdapter = class (TRawImage)
   protected
   {O} fPcxItem: Heroes.PPcx16Item;

   public
    constructor Create (PcxItem: Heroes.PPcx16Item);
    destructor Destroy; override;

    procedure DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                 const DrawImageSetup: TDrawImageSetup); override;
  end;


(* Wraps Pcx8/16 item into TRawImage adapter on the fly *)
function AdaptPcxItemToRawImage ({On} PcxItem: Heroes.PPcxItem): {On} TRawImage;

function LoadImage (const FilePath: string): {n} TGraphic;

(* Fast bitmap scaling. Input bitmap is forced to be 24 bit. *)
function ResizeBmp24 ({OU} Image: TBitmap; NewWidth, NewHeight, MaxWidth, MaxHeight: integer; ResizeAlg: TResizeAlg; FreeOriginal: boolean): {O} TBitmap;

(* ©Charles Hacker, adapted by ethernidee. Input bitmap is forced to be 24 bit. *)
function SmoothResizeBmp24 ({OU} abmp: TBitmap; NewWidth, NewHeight: integer; FreeOriginal: boolean): {O} TBitmap;

function LoadImageAsPcx16 (FilePath:  string;      PcxName:   string  = '';
                           Width:     integer = 0; Height:    integer = 0;
                           MaxWidth:  integer = 0; MaxHeight: integer = 0;
                           ResizeAlg: TResizeAlg = ALG_DOWNSCALE): {OU} Heroes.PPcx16Item;

procedure DecRef (Resource: Heroes.PBinaryTreeItem); stdcall;

(* Loads pcx8 or pcx16 resource, based on file extension: ".pcx16" for pcx16 and ".pcx" for pcx8.
   This function is necessary because pcx8 and pcx16 formats are indistinguishable in lod/pac-packages *)
function LoadPcxEx (const PcxName: string): {On} Heroes.PPcxItem;

(* Loads given png file from cache or file system and returns TRawImage in the best format wrapped into shared resource *)
function LoadPngResource (const FilePath: string): {On} ResLib.TSharedResource;

function GetDefFrameWidth (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): integer;
function GetDefFrameHeight (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): integer;

procedure DrawInterfaceDefFrameEx (Def: Heroes.PDefItem; GroupInd, FrameInd: integer; SrcX, SrcY, BoxWidth, BoxHeight: integer; Buf: pointer;
                                   DstX, DstY, DstWidth, DstHeight, DstScanlineSize: integer;
                                   const DrawFlags: TDrawDefFrameFlags = []);

(* Draws any raw image to game draw buffer *)
procedure DrawRawImageToGameBuf (Image: TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH: integer; Buf: pointer; DstScanlineSize: integer;
                                 const DrawImageSetup: GraphTypes.TDrawImageSetup);

(* Draws any raw image to Pcx16 canvas *)
procedure DrawRawImageToPcx16Canvas (Image: TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; Canvas: Heroes.PPcx16Item;
                                     const DrawImageSetup: GraphTypes.TDrawImageSetup);


var
  DefaultPlayerInterfacePalette: TColorizablePlayerPalette32 = (
    integer($FF131F40), integer($FF18264F), integer($FF192855), integer($FF1D2C5A), integer($FF1D2F63), integer($FF1F3269), integer($FF20336D), integer($FF20346D),
    integer($FF283865), integer($FF20346E), integer($FF213571), integer($FF223671), integer($FF223673), integer($FF223773), integer($FF223774), integer($FF233877),
    integer($FF233977), integer($FF233979), integer($FF243A79), integer($FF243A7B), integer($FF243B7D), integer($FF253C7F), integer($FF263D82), integer($FF273F83),
    integer($FF274086), integer($FF324272), integer($FF28418B), integer($FF374A82), integer($FF2A4590), integer($FF2F4B9C), integer($FF495B90), integer($FF6C7AA3)
  );


(***)  implementation  (***)


const
  // Image is marked with the player color it was colorized with
  META_PLAYER_COLOR = 'player_color';

  // Formal background pcx name for composed image
  META_BACK_PCX_NAME = 'back_pcx_name';

  // Redirected background pcx name for composed image
  META_REDIRECTED_BACK_PCX_NAME = 'redirected_back_pcx_name';

  DO_VERT_MIRROR  = true;
  DO_HORIZ_MIRROR = true;

var
{O} DefFramesPngFileMap: {U} TDict {of Ptr(1)};                 // Caseinsensitive map of "defname.def\frame_index.png" => 1 if frame png file exists.
{O} PcxPngFileMap:       {O} TDict {of png file path: TString};
{O} PcxPngRedirections:  {O} TDict {of pcx file name: TString}; // Used for runtime pcx alternatives like special variant for each player, cleared on rescan
{O} ColorizedPcxPng:     {U} TDict {of Ptr(PlayerId + 1)};      // Used to track, which pcx were colorized to which player colors. Is never reset.
{O} DefBattleEffects:    {U} TDict {of effect palette pointer}; // Used for clone/blood lust/petrification battle effects implementation

  DefFramePngFilePathPrefix: string; // Like "D:\Games\Heroes 3\Data\Defs\"

  CloneEffectPalette:         array [0..(1 shl GraphTypes.FILTER_PALETTE_BIT_DEPTH) - 1] of integer;
  BloodLustEffectPalette:     array [0..9, 0..(1 shl GraphTypes.FILTER_PALETTE_BIT_DEPTH) - 1] of integer;
  PetrificationEffectPalette: array [0..9, 0..(1 shl GraphTypes.FILTER_PALETTE_BIT_DEPTH) - 1] of integer;


constructor TPcx8ToRawImageAdapter.Create (PcxItem: Heroes.PPcx8Item);
var
  ImageSetup: GraphTypes.TRawImageSetup;

begin
  ImageSetup.Init;
  ImageSetup.HasTransparency := false;

  inherited Create(PcxItem.Width, PcxItem.Height, ImageSetup);

  Self.fPcxItem := PcxItem;
end;

destructor TPcx8ToRawImageAdapter.Destroy;
begin
  Self.fPcxItem.DecRef; Self.fPcxItem := nil;

  inherited Destroy;
end;

procedure TPcx8ToRawImageAdapter.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                                     const DrawImageSetup: TDrawImageSetup);
var
{On} Drawer:       GraphTypes.TRawImage16;
     Pixels:       GraphTypes.TArrayOfColor16;
     ScanlineSize: integer;
     ImageSetup:   GraphTypes.TRawImage16Setup;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Types.Bounds(0, 0, Self.fWidth, Self.fHeight), Types.Bounds(0, 0, DstWidth, DstHeight),
                  DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
      Self.fPcxItem.DrawToBuf(SrcX, SrcY, BoxWidth, BoxHeight, DstBuf, DstX, DstY, DstWidth, DstHeight, DstScanlineSize, 0);
    end else begin
      Pixels := nil;
      SetLength(Pixels, Self.fWidth * Self.fHeight);
      ScanlineSize := Self.fWidth * sizeof(Pixels[0]);

      Self.fPcxItem.DrawToBuf(0, 0, Self.fWidth, Self.fHeight, @Pixels[0], 0, 0, Self.fWidth, Self.fHeight, ScanlineSize, 1);

      ImageSetup.Init;
      Drawer := GraphTypes.TRawImage16.Create(Pixels, Self.fWidth, Self.fHeight, ScanlineSize, ImageSetup);

      Drawer.DrawToOpaque32Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight, DstBuf, DstScanlineSize, DrawImageSetup);

      SysUtils.FreeAndNil(Drawer);
    end;
  end; // .if
end; // .procedure TPcx8ToRawImageAdapter.DrawToOpaque32Buf

constructor TPcx16ToRawImageAdapter.Create (PcxItem: Heroes.PPcx16Item);
var
  ImageSetup: GraphTypes.TRawImageSetup;

begin
  ImageSetup.Init;
  ImageSetup.HasTransparency := false;

  inherited Create(PcxItem.Width, PcxItem.Height, ImageSetup);

  Self.fPcxItem := PcxItem;
end;

destructor TPcx16ToRawImageAdapter.Destroy;
begin
  Self.fPcxItem.DecRef; Self.fPcxItem := nil;

  inherited Destroy;
end;

procedure TPcx16ToRawImageAdapter.DrawToOpaque32Buf (SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight: integer; DstBuf: PColor32Arr; DstScanlineSize: integer;
                                                     const DrawImageSetup: TDrawImageSetup);
var
{On} Drawer:       GraphTypes.TRawImage16;
     Pixels:       GraphTypes.TArrayOfColor16;
     ScanlineSize: integer;
     ImageSetup:   GraphTypes.TRawImage16Setup;

begin
  if (DstBuf <> nil) and (DstScanlineSize > 0) and
    RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Types.Bounds(0, 0, Self.fWidth, Self.fHeight), Types.Bounds(0, 0, DstWidth, DstHeight),
                  DrawImageSetup.DoHorizMirror and DrawImageSetup.EnableFilters, DrawImageSetup.DoVertMirror and DrawImageSetup.EnableFilters)
  then begin
    if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
      Self.fPcxItem.DrawToBuf(SrcX, SrcY, BoxWidth, BoxHeight, DstBuf, DstX, DstY, DstWidth, DstHeight, DstScanlineSize, 0);
    end else begin
      Pixels := nil;
      SetLength(Pixels, Self.fWidth * Self.fHeight);
      ScanlineSize := Self.fWidth * sizeof(Pixels[0]);

      Self.fPcxItem.DrawToBuf(0, 0, Self.fWidth, Self.fHeight, @Pixels[0], 0, 0, Self.fWidth, Self.fHeight, ScanlineSize, 0);

      ImageSetup.Init;
      Drawer := GraphTypes.TRawImage16.Create(Pixels, Self.fWidth, Self.fHeight, ScanlineSize, ImageSetup);

      Drawer.DrawToOpaque32Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstWidth, DstHeight, DstBuf, DstScanlineSize, DrawImageSetup);

      SysUtils.FreeAndNil(Drawer);
    end;
  end; // .if
end; // .procedure TPcx16ToRawImageAdapter.DrawToOpaque32Buf

function AdaptPcxItemToRawImage ({On} PcxItem: Heroes.PPcxItem): {On} TRawImage;
begin
  result := nil;

  if PcxItem <> nil then begin
    if PcxItem.IsPcx8 then begin
      result := TPcx8ToRawImageAdapter.Create(Heroes.PPcx8Item(PcxItem));
    end else if PcxItem.IsPcx16 then begin
      result := TPcx16ToRawImageAdapter.Create(Heroes.PPcx16Item(PcxItem));
    end;
  end;
end;

(* Checks, that image is valid object with non-null dimensions and forces required pixel format. Returns same object instance. *)
function ValidateBmp24 ({OU} Image: TBitmap): {OU} TBitmap;
begin
  {!} Assert(Image <> nil);
  {!} Assert((Image.Width > 0) and (Image.Height > 0), Format('Invalid bitmap24 dimensions: %dx%d', [Image.Width, Image.Height]));
  Image.PixelFormat := pf24bit;
  result            := Image;
end;

procedure ValidateImageSize (Width: integer; Height: integer);
begin
  {!} Assert((Width > 0) and (Height > 0), Format('Invalid image dimensions specified: %dx%d', [Width, Height]));
end;

(* Returns number of bits per pixels, 0 for unknown or unsupported. *)
function GetBmpColorDepth (Image: TBitmap): integer;
begin
  {!} Assert(Image <> nil);
  case Image.PixelFormat of
    Graphics.pf1bit:  result := 1;
    Graphics.pf4bit:  result := 4;
    Graphics.pf8bit:  result := 8;
    Graphics.pf16bit: result := 16;
    Graphics.pf24bit: result := 24;
    Graphics.pf32bit: result := 32;
  else
    result := 0;
  end;
end; // .function GetBmpColorDepth

function GetBmpScanlineSize (Image: TBitmap): integer;
begin
  {!} Assert(Image <> nil);
  result := GetBmpColorDepth(Image);
  {!} Assert(result <> 0, 'Unsupported bitmap pixel format ' + SysUtils.IntToStr(integer(Image.PixelFormat)));
  result := (result * Image.Width + 31) div 32 * 4;
end;

(* Returns image type by image object *)
function GetImageType (const Image: TGraphic): TImageType;
begin
  if      Image is TBitmap    then result := IMG_BMP
  else if Image is TJpegImage then result := IMG_JPG
  else if Image is TPngObject then result := IMG_PNG
  else                             result := IMG_UNKNOWN;
end;

(* Returns image type by image extension *)
function GetImageTypeByName (const ImgName: string): TImageType;
var
  ImgExt: string;

begin
  ImgExt := SysUtils.AnsiLowerCase(SysUtils.ExtractFileExt(ImgName));

  if      ImgExt = '.bmp' then result := IMG_BMP
  else if ImgExt = '.jpg' then result := IMG_JPG
  else if ImgExt = '.png' then result := IMG_PNG
  else                         result := IMG_UNKNOWN;
end;

(* Given type. Create 1x1 image instance object of given type *)
function CreateImageOfType (ImageType: TImageType): TGraphic;
begin
  {!} Assert(ImageType <> IMG_UNKNOWN, 'Cannot create image of unknown type');
  result := nil;

  if      ImageType = IMG_BMP then result := TBitmap.Create
  else if ImageType = IMG_JPG then result := TJpegImage.Create
  else if ImageType = IMG_PNG then result := TPngObject.Create
  else {!} Assert(false);
end;

function CreateDefaultBmp24 (Width: integer = 32; Height: integer = 32): {O} TBitmap;
const
  DEF_IMAGE_SIZE = 32;

var
  Rect: TRect;

begin
  ValidateImageSize(Width, Height);
  result                    := TBitmap.Create;
  result.PixelFormat        := pf24bit;
  result.SetSize(Width, Height);
  result.Canvas.Brush.Style := bsDiagCross;
  result.Canvas.Brush.Color := clRed;

  with Rect do begin
    Left   := 0;
    Top    := 0;
    Right  := Width;
    Bottom := Height;
  end;

  result.Canvas.FillRect(Rect);
end; // .function CreateDefaultBmp24

function GetImageRatio (Image: TBitmap): GraphTypes.TImageRatio;
var
  Width, Height: integer;

begin
  ValidateBmp24(Image);
  // * * * * * //
  Width         := Image.Width;
  Height        := Image.Height;
  result.Width  := Width / Height;
  result.Height := Height / Width;
end;

procedure DetectMissingDimensions (Image: TBitmap; var Width, Height: integer; DetectionType: TDimensionsDetectionType);
begin
  if (Width = AUTO_WIDTH) or (Height = AUTO_HEIGHT) then begin
    if (Width = AUTO_WIDTH) and (Height = AUTO_HEIGHT) then begin
      Width  := Image.Width;
      Height := Image.Height;
    end else begin
      case DetectionType of
        USE_IMAGE_VALUES: begin
          if Width = AUTO_WIDTH then begin
            Width  := Image.Width;
          end else begin
            Height := Image.Height;
          end;
        end;

        CALC_PROPORTIONALLY: begin
          if Width = AUTO_WIDTH then begin
            Width  := round(Height * (Image.Width / Image.Height));
          end else begin
            Height := round(Width * (Image.Height / Image.Width));
          end;
        end;
      end; // .switch
    end; // .else
  end; // .if
end; // .procedure DetectMissingDimensions

procedure ApplyMinMaxDimensionConstraints (var Width, Height: integer; MinWidth, MinHeight, MaxWidth, MaxHeight: integer);
begin
  if MaxWidth = AUTO_WIDTH then begin
    MaxWidth := Width;
  end;

  if MaxHeight = AUTO_HEIGHT then begin
    MaxHeight := Height;
  end;

  Width  := Alg.ToRange(Width,  MinWidth,  MaxWidth);
  Height := Alg.ToRange(Height, MinHeight, MaxHeight);
end;

function ResizeBmp24 ({OU} Image: TBitmap; NewWidth, NewHeight, MaxWidth, MaxHeight: integer; ResizeAlg: TResizeAlg; FreeOriginal: boolean): {O} TBitmap;
var
  DimensionsDetectionType: TDimensionsDetectionType;
  NeedsScaling:            boolean;
  Width:                   double;
  Height:                  double;

begin
  // Treat negative constraints and dimensions as AUTO
  MaxWidth  := Math.Max(0, MaxWidth);
  MaxHeight := Math.Max(0, MaxHeight);
  NewWidth  := Math.Max(0, NewWidth);
  NewHeight := Math.Max(0, NewHeight);

  // Convert AUTO dimensions into real
  DimensionsDetectionType := CALC_PROPORTIONALLY;

  if ResizeAlg = ALG_FILL then begin
    DimensionsDetectionType := USE_IMAGE_VALUES;
  end else if ResizeAlg = ALG_COVER then begin
    ResizeAlg := ALG_STRETCH;
  end;

  DetectMissingDimensions(Image, NewWidth, NewHeight, DimensionsDetectionType);
  // End

  ApplyMinMaxDimensionConstraints(NewWidth, NewHeight, 1, 1, MaxWidth, MaxHeight);

  if (Image.Width = NewWidth) and (Image.Height = NewHeight) then begin
    ResizeAlg := ALG_NO_RESIZE;
  end;

  if FreeOriginal and (ResizeAlg = ALG_NO_RESIZE) then begin
    result := Image; Image := nil;
  end else begin
    result             := TBitmap.Create;
    result.PixelFormat := pf24bit;

    case ResizeAlg of
      ALG_NO_RESIZE: begin
        result.SetSize(NewWidth, NewHeight);
        result.Canvas.Draw(0, 0, Image);
      end;

      ALG_STRETCH: begin
        result.SetSize(NewWidth, NewHeight);
        result.Canvas.StretchDraw(Rect(0, 0, NewWidth, NewHeight), Image);
      end;

      ALG_CONTAIN, ALG_UPSCALE, ALG_DOWNSCALE: begin
        NeedsScaling := (ResizeAlg  = ALG_CONTAIN)                                                                 or
                        ((ResizeAlg = ALG_DOWNSCALE) and ((Image.Width > NewWidth) or (Image.Height > NewHeight))) or
                        ((ResizeAlg = ALG_UPSCALE)   and ((Image.Width < NewWidth) and (Image.Height < NewHeight)));

        if NeedsScaling then begin
          // Fit to box width
          Width  := NewWidth;
          Height := NewWidth * Image.Height / Image.Width;

          // Fit to box height
          if Height > NewHeight then begin
            Width  := Width * NewHeight / Height;
            Height := NewHeight;
          end;

          // Get final rounded width/height
          NewWidth  := round(Width);
          NewHeight := round(height);
          ApplyMinMaxDimensionConstraints(NewWidth, NewHeight, 1, 1, MaxWidth, MaxHeight);

          result.SetSize(NewWidth, NewHeight);
          result.Canvas.StretchDraw(Rect(0, 0, NewWidth, NewHeight), Image);
        end else begin
          FreeAndNil(result);
          result := Image; Image := nil;
        end; // .else
      end; // .case ALG_CONTAIN, ALG_UPSCALE, ALG_DOWNSCALE

      ALG_FILL: begin
        result.SetSize(NewWidth, NewHeight);
        result.Canvas.Brush.Bitmap := Image;
        result.Canvas.FillRect(Rect(0, 0, NewWidth, NewHeight));
        result.Canvas.Brush.Bitmap := nil;
      end;
    end; // .switch ResizeAlg
  end; // .else

  if FreeOriginal then begin
    FreeAndNil(Image);
  end;
end; // .procedure ResizeBmp24

function GetScaledBmp24Size (Image: TBitmap; NewWidth, NewHeight: integer): GraphTypes.TImageSize;
var
  OldWidth:   integer;
  OldHeight:  integer;
  ImageRatio: GraphTypes.TImageRatio;

begin
  ValidateBmp24(Image);
  // * * * * * //
  if NewWidth <= 0 then begin
    NewWidth := AUTO_WIDTH;
  end;

  if NewHeight <= 0 then begin
    NewHeight := AUTO_HEIGHT;
  end;

  OldWidth  := Image.Width;
  OldHeight := Image.Height;

  if (NewWidth <> AUTO_WIDTH) and (NewHeight <> AUTO_HEIGHT) then begin
    // Physical dimensions, ok
  end else if (NewWidth = AUTO_WIDTH) and (NewHeight = AUTO_HEIGHT) then begin
    NewWidth  := OldWidth;
    NewHeight := OldHeight;
  end else begin
    ImageRatio := GetImageRatio(Image);

    if NewWidth = AUTO_WIDTH then begin
      NewWidth := Round(NewHeight * ImageRatio.Width);
    end else begin
      NewHeight := Round(NewWidth * ImageRatio.Height);
    end;
  end; // .else

  result.Width  := NewWidth;
  result.Height := NewHeight;
end; // .function GetScaledBmp24Size

function SmoothResizeBmp24 ({OU} abmp: TBitmap; NewWidth, NewHeight: integer; FreeOriginal: boolean): {O} TBitmap;
var
  xscale, yscale:         single;
  sfrom_y, sfrom_x:       single;
  ifrom_y, ifrom_x:       integer;
  to_y, to_x:             integer;
  weight_x, weight_y:     array [0..1] of single;
  weight:                 single;
  new_red, new_green:     integer;
  new_blue:               integer;
  total_red, total_green: single;
  total_blue:             single;
  ix, iy:                 integer;
  bTmp:                   TBitmap;
  sli, slo:               GraphTypes.PColor24Arr;

begin
  with GetScaledBmp24Size(abmp, NewWidth, NewHeight) do begin
    NewWidth  := Width;
    NewHeight := Height;
  end;
  // * * * * * //
  abmp.PixelFormat := pf24bit;
  bTmp             := TBitmap.Create;
  bTmp.PixelFormat := pf24bit;
  bTmp.SetSize(NewWidth, NewHeight);
  xscale           := bTmp.Width / (abmp.Width - 1);
  yscale           := bTmp.Height / (abmp.Height - 1);

  for to_y := 0 to bTmp.Height - 1 do begin
    sfrom_y     := to_y / yscale;
    ifrom_y     := Trunc(sfrom_y);
    weight_y[1] := sfrom_y - ifrom_y;
    weight_y[0] := 1 - weight_y[1];

    for to_x := 0 to bTmp.Width - 1 do begin
      sfrom_x     := to_x / xscale;
      ifrom_x     := Trunc(sfrom_x);
      weight_x[1] := sfrom_x - ifrom_x;
      weight_x[0] := 1 - weight_x[1];
      total_blue  := 0.0;
      total_green := 0.0;
      total_red   := 0.0;

      for ix := 0 to 1 do begin
        for iy := 0 to 1 do begin
          sli         := abmp.Scanline[ifrom_y + iy];
          new_blue    := sli[ifrom_x + ix].Blue;
          new_green   := sli[ifrom_x + ix].Green;
          new_red     := sli[ifrom_x + ix].Red;
          weight      := weight_x[ix] * weight_y[iy];
          total_blue  := total_blue  + new_blue  * weight;
          total_green := total_green + new_green * weight;
          total_red   := total_red   + new_red   * weight;
        end;
      end;

      slo             := bTmp.ScanLine[to_y];
      slo[to_x].Blue  := Round(total_blue);
      slo[to_x].Green := Round(total_green);
      slo[to_x].Red   := Round(total_red);
    end;
  end;

  result := bTmp;

  if FreeOriginal then begin
    abmp.Free;
  end;
end; // .procedure SmoothResizeBmp24

(* Loads image without format conversion by specified path. Returns nil on failure. *)
function LoadImage (const FilePath: string): {n} TGraphic;
var
  ImageType: TImageType;

begin
  result    := nil;
  ImageType := GetImageTypeByName(FilePath);

  if (ImageType <> IMG_UNKNOWN) and SysUtils.FileExists(FilePath) then begin
    result := CreateImageOfType(ImageType);

    try
      result.LoadFromFile(FilePath);
    except
      SysUtils.FreeAndNil(result);
    end;
  end;
end; // .function LoadImage

(* Loads image and converts it to 24 bit BMP. Returns new default image on error and notifies user. *)
function LoadImageAsBmp24 (const FilePath: string): TBitmap;
var
{On} Image: TGraphic;

begin
  Image  := LoadImage(FilePath);
  result := nil;
  // * * * * * //
  if Image = nil then begin
    //Core.NotifyError(Format('Failed to load image at "%s"', [FilePath]));
    result := CreateDefaultBmp24();
  end else begin
    if GetImageType(Image) = IMG_BMP then begin
      result             := Image as TBitmap; Image := nil;
      result.PixelFormat := Graphics.pf24bit;
    end else begin
      result             := TBitmap.Create;
      result.PixelFormat := Graphics.pf24bit;
      result.Width       := Image.Width;
      result.Height      := Image.Height;
      result.Canvas.Draw(0, 0, Image);
    end;
  end;
  // * * * * * //
  FreeAndNil(Image);
end; // .function LoadImageAsBmp24

function Bmp24ToPcx16 (Image: TBitmap; const Name: string): {O} Heroes.PPcx16Item;
var
    Width:           integer;
    Height:          integer;
{U} BmpPixels:       GraphTypes.PColor24;
{U} PcxPixels:       pword;
    PcxScanlineSize: integer;
    x, y:            integer;

begin
  ValidateBmp24(Image);
  BmpPixels := nil;
  PcxPixels := nil;
  result    := nil;
  // * * * * * //
  Width  := Image.Width;
  Height := Image.Height;
  result := Heroes.TPcx16ItemStatic.Create(Name, Width, Height);
  {!} Assert(result <> nil, Format('Failed to create pcx16 image of size %dx%d', [Width, Height]));

  PcxPixels       := pointer(result.Buffer);
  PcxScanlineSize := result.ScanlineSize;

  for y := 0 to Height - 1 do begin
    BmpPixels := Image.Scanline[y];

    for x := 0 to Width - 1 do begin
      PcxPixels^ := (BmpPixels.Blue shr 3) or ((BmpPixels.Green shr 2) shl 5) or ((BmpPixels.Red shr 3) shl 11);
      inc(PcxPixels);
      inc(BmpPixels);
    end;

    PcxPixels := Utils.PtrOfs(PcxPixels, -Width * PCX16_BYTES_PER_COLOR + PcxScanlineSize);
  end;
end; // .function Bmp24ToPcx16

function Bmp24ToPcx24 (Image: TBitmap; const Name: string): {O} Heroes.PPcx24Item;
var
    Width:           integer;
    Height:          integer;
{U} BmpPixels:       GraphTypes.PColor24;
{U} PcxPixels:       GraphTypes.PColor24;
    PcxScanlineSize: integer;
    y:               integer;

begin
  ValidateBmp24(Image);
  BmpPixels := nil;
  PcxPixels := nil;
  result    := nil;
  // * * * * * //
  Width  := Image.Width;
  Height := Image.Height;
  result := Heroes.TPcx24ItemStatic.Create(Name, Width, Height);
  {!} Assert(result <> nil, Format('Failed to create pcx24 image of size %dx%d', [Width, Height]));

  PcxScanlineSize := Width * Heroes.PCX24_BYTES_PER_COLOR;
  PcxPixels       := pointer(result.Buffer);

  for y := 0 to Height - 1 do begin
    BmpPixels := Image.Scanline[y];
    Utils.CopyMem(PcxScanlineSize, BmpPixels, PcxPixels);
    Inc(integer(PcxPixels), PcxScanlineSize);
  end;
end; // .function Bmp24ToPcx24

(* Loads Pcx16 resource with rescaling support. Values <= 0 are considered 'auto'. Image scaling depends on chosen algorithm.
   Resource name (name in binary resource tree) can be either fixed or automatic. Pass empty PcxName for automatic name.
   If PcxName exceeds 12 characters, it's replaced with valid unique name. Check name field of result.
   If resource is already registered and has proper format, it's returned with RefCount increased.
   Result image dimensions may differ from requested if fixed PcxName is specified. Use automatic naming
   to load image of desired size for sure.
   Default image is returned in case of missing file and user is notified. *)
function LoadImageAsPcx16 (FilePath:  string;      PcxName:   string  = '';
                           Width:     integer = 0; Height:    integer = 0;
                           MaxWidth:  integer = 0; MaxHeight: integer = 0;
                           ResizeAlg: TResizeAlg = ALG_DOWNSCALE): {OU} Heroes.PPcx16Item;
var
{O}  Bmp:           TBitmap;
{Un} CachedItem:    Heroes.PPcx16Item;
{On} Pcx24:         Heroes.PPcx24Item;
     UseAutoNaming: boolean;

begin
  Bmp        := nil;
  CachedItem := nil;
  result     := nil;
  // * * * * * //
  UseAutoNaming := PcxName = '';

  if UseAutoNaming then begin
    PcxName := Heroes.ResourceNamer.GenerateUniqueResourceName();
  end else begin
    // Search fixed named resource in cache. It must be absent or be pcx16
    PcxName := Heroes.ResourceNamer.GetResourceName(PcxName);

    if Heroes.ResourceTree.FindItem(PcxName, Heroes.PBinaryTreeItem(CachedItem)) then begin
      {!} Assert(CachedItem.IsPcx16(), Format('Image "%s", requested to be loaded from "%s" is already loaded, but has non-pcx16 type', [PcxName, FilePath]));
      result := CachedItem;
      result.IncRef();
    end;
  end;

  // Cache miss, load image from file
  if result = nil then begin
    FilePath := SysUtils.ExpandFileName(FilePath);
    Bmp      := ResizeBmp24(LoadImageAsBmp24(FilePath), Width, Height, MaxWidth, MaxHeight, ResizeAlg, FREE_ORIGINAL_BMP);

    // Perform image conversion and resource insertion
    Pcx24  := Bmp24ToPcx24(Bmp, PcxName);
    result := Heroes.TPcx16ItemStatic.Create(PcxName, Bmp.Width, Bmp.Height);
    Pcx24.DrawToPcx16(0, 0, Bmp.Width, Bmp.Height, result, 0, 0);
    Pcx24.Destruct;

    // Register item in resources binary tree and increase reference counter
    result.IncRef();
    Heroes.ResourceTree.AddItem(result);
  end; // .if
  // * * * * * //
  FreeAndNil(Bmp);
end; // .function LoadImageAsPcx16

procedure DecRef (Resource: Heroes.PBinaryTreeItem); stdcall;
begin
  Resource.DecRef;
end;

function LoadPcxEx (const PcxName: string): {On} Heroes.PPcxItem;
begin
  if SysUtils.AnsiLowerCase(SysUtils.ExtractFileExt(PcxName)) = '.pcx16' then begin
    result := LoadPcx16(SysUtils.ChangeFileExt(PcxName, '.pcx'));
  end else begin
    result := LoadPcx8(PcxName);
  end;
end;

function RawImageToString (Image: TRawImage): string;
var
{O} Stream:         Classes.TStringStream;
{O} Png:            TPngObject;
    Pixel:          GraphTypes.PColor32;
    Canvas:         GraphTypes.TArrayOfColor32;
    DrawImageSetup: TDrawImageSetup;
    i, j:           integer;

begin
  {!} Assert(Image <> nil);
  Stream := Classes.TStringStream.Create('');
  Png    := TPngObject.CreateBlank(PngImage.COLOR_RGB, 8, Image.Width, Image.Height);
  result := '';
  // * * * * * //
  Canvas := nil;
  SetLength(Canvas, Image.Width * Image.Height);
  DrawImageSetup.Init;
  Image.DrawToOpaque32Buf(0, 0, 0, 0, Image.Width, Image.Height, Image.Width, Image.Height, @Canvas[0], Image.Width * sizeof(Canvas[0]), DrawImageSetup);
  Pixel := @Canvas[0];

  for j := 0 to Image.Height - 1 do begin
    for i := 0 to Image.Width - 1 do begin
      Png.Pixels[i, j] := (Pixel.Red + Pixel.Green shl 8 + Pixel.Blue shl 16);
      Inc(Pixel);
    end;
  end;

  Png.SaveToStream(Stream);
  result := Stream.DataString;
  // * * * * * //
  SysUtils.FreeAndNil(Stream);
  SysUtils.FreeAndNil(Png);
end; // .function RawImageToString

procedure SaveRawImageAsPng (RawImage: TRawImage; const FilePath: string);
begin
  Files.WriteFileContents(RawImageToString(RawImage), FilePath);
end;

function GetPcxPng (PcxName: string): {On} ResLib.TSharedResource; forward;

function LoadRawImage32NoCaching (const FilePath: string): {On} TRawImage32;
var
  FileContents: string;

begin
  result := nil;

  if EraZip.ReadFileContentsFromZipFs(FilePath, FileContents) then begin
    result := Libspng.DecodePng(pchar(FileContents), Length(FileContents));
  end;
end;

(* Searches, whether there is a setting to apply pcx-png background for specified png image. If such setting is found, composes new opaque TRawImage32,
   drawing background first and foreground then. Returns new image or nil if nothing to compose *)
function ApplyImageBackgroundFromConfig (ForegroundImage: TRawImage; const ForegroundPngFilePath: string): {On} TRawImage32;
var
     BaseConfigKey:        string;
     ConfigKey:            string;
     BackPcxName:          string;
{Un} BackImage:            TRawImage;
     ComposedImagePixels:  GraphTypes.TArrayOfColor32;
     ComposedScanlineSize: integer;
     ImageSetup:           TRawImage32Setup;
     DrawImageSetup:       GraphTypes.TDrawImageSetup;

begin
  {!} Assert(ForegroundImage <> nil);
  result        := nil;
  BaseConfigKey := 'era.png_backs.' + SysUtils.AnsiLowerCase(EraZip.ToRelativePathIfPossible(ForegroundPngFilePath, GameExt.GameDir));
  ConfigKey     := BaseConfigKey + '.file';
  BackPcxName   := Trans.Tr(ConfigKey, []);

  if BackPcxName <> ConfigKey then begin
    BackImage := AdaptPcxItemToRawImage(LoadPcxEx(BackPcxName));

    if BackImage <> nil then begin
      ComposedImagePixels  := nil;
      SetLength(ComposedImagePixels, ForegroundImage.Width * ForegroundImage.Height);
      ComposedScanlineSize := ForegroundImage.Width * sizeof(ComposedImagePixels[0]);
      DrawImageSetup.Init;

      BackImage.DrawToOpaque32Buf(
        Heroes.a2i(pchar(Trans.Tr(BaseConfigKey + '.x', []))),
        Heroes.a2i(pchar(Trans.Tr(BaseConfigKey + '.y', []))),
        0,
        0,
        ForegroundImage.Width,
        ForegroundImage.Height,
        ForegroundImage.Width,
        ForegroundImage.Height,
        @ComposedImagePixels[0],
        ComposedScanlineSize,
        DrawImageSetup
      );

      ForegroundImage.DrawToOpaque32Buf(
        0,
        0,
        0,
        0,
        ForegroundImage.Width,
        ForegroundImage.Height,
        ForegroundImage.Width,
        ForegroundImage.Height,
        @ComposedImagePixels[0],
        ComposedScanlineSize,
        DrawImageSetup
      );

      ImageSetup.Init;
      ImageSetup.HasTransparency := false;

      result := TRawImage32.Create(ComposedImagePixels, ForegroundImage.Width, ForegroundImage.Height, ComposedScanlineSize, ImageSetup);

      result.Meta[META_BACK_PCX_NAME]            := TString.Create(BackPcxName);
      result.Meta[META_REDIRECTED_BACK_PCX_NAME] := TString.Create(Lodman.GetRedirectedName(BackPcxName, [Lodman.FRF_EXCLUDE_FALLBACKS]));

      SysUtils.FreeAndNil(BackImage);
    end; // .if
  end; // .if
end; // .function ApplyImageBackgroundFromConfig

function LoadPngResource (const FilePath: string): {On} ResLib.TSharedResource;
var
{On} Image:             TRawImage;
{On} Image16:           TRawImage16;
{On} Image32:           TRawImage32;
{On} Image32Alpha:      GraphTypes.TPremultipliedRawImage32;
{On} ComposedImage32:   TRawImage32;
{Un} CachedImage:       TRawImage;
     UsedComposition:   boolean;
     BackPcxName:       TString;
     ImageSize:         integer;
     Image16Setup:      TRawImage16Setup;
     Image32AlphaSetup: GraphTypes.TPremultipliedRawImage32Setup;

begin
  Image           := nil;
  Image16         := nil;
  Image32         := nil;
  Image32Alpha    := nil;
  ComposedImage32 := nil;
  // * * * * * //
  result := ResLib.ResMan.GetResource(FilePath);

  // Something is found in cache
  if result <> nil then begin
    // Object in cache is not image, fail
    if not (result.Data is TRawImage) then begin
      result.DecRef;
      result := nil;

      exit;
    end;

    CachedImage := TRawImage(result.Data);
    BackPcxName := CachedImage.Meta[META_BACK_PCX_NAME];

    // Is it composed image, for which background pcx redirection was changed, try to remove it from cache and recreate
    if (BackPcxName <> nil) and (TString(CachedImage.Meta[META_REDIRECTED_BACK_PCX_NAME]).Value <> Lodman.GetRedirectedName(BackPcxName.Value, [Lodman.FRF_EXCLUDE_FALLBACKS])) then begin
      result.DecRef;
      result := nil;

      // Failed to free image, return cached variant as is
      if not ResLib.ResMan.TryCollectResource(FilePath) then begin
        result := ResLib.ResMan.GetResource(FilePath);

        exit;
      end;
    end else begin
      exit;
    end;
  end;

  Image32 := LoadRawImage32NoCaching(FilePath);

  if Image32 = nil then begin
    exit;
  end;

  if Image32.HasTransparency then begin
    Image32AlphaSetup.Init;
    Image32Alpha := TPremultipliedRawImage32.Create(Image32.Pixels, Image32.Width, Image32.Height, Image32.ScanlineSize, Image32AlphaSetup);
    Image32Alpha.AutoCrop;
    Utils.Exchange(Image, Image32Alpha);
  end else if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
    Utils.Exchange(Image, Image32);
  end else begin
    Image16Setup.Init;
    Image16Setup.Color16Mode := GraphTypes.GetColor16Mode;

    Image16 := TRawImage16.Create(
      GraphTypes.Color32ToColor16Pixels(Image32.Pixels),
      Image32.Width,
      Image32.Height,
      Image32.ScanlineSize div (sizeof(GraphTypes.TColor32) div sizeof(GraphTypes.TColor16)),
      Image16Setup
    );

    Utils.Exchange(Image, Image16);
  end;

  ComposedImage32 := ApplyImageBackgroundFromConfig(Image, FilePath);
  UsedComposition := ComposedImage32 <> nil;

  if UsedComposition then begin
    Utils.Exchange(Image, ComposedImage32);
  end;

  ImageSize := Image.Width * Image.Height * Image.GetPixelSize;
  result    := ResLib.ResMan.AddResource(Image, ImageSize, FilePath); Image := nil;
  // * * * * * //
  SysUtils.FreeAndNil(Image);
  SysUtils.FreeAndNil(Image16);
  SysUtils.FreeAndNil(Image32);
  SysUtils.FreeAndNil(Image32Alpha);
  SysUtils.FreeAndNil(ComposedImage32);
end; // .function LoadPngResource

procedure DrawRawImageToGameBuf (Image: TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH: integer; Buf: pointer; DstScanlineSize: integer;
                                 const DrawImageSetup: GraphTypes.TDrawImageSetup);
begin
  {!} Assert(Image <> nil);
  {!} Assert(Buf <> nil);

  if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
    Image.DrawToOpaque32Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH, Buf, DstScanlineSize, DrawImageSetup);
  end else begin
    Image.DrawToOpaque16Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH, Buf, DstScanlineSize, DrawImageSetup);
  end;
end;

procedure DrawRawImageToPcx16Canvas (Image: TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; Canvas: Heroes.PPcx16Item;
                                     const DrawImageSetup: GraphTypes.TDrawImageSetup);
begin
  DrawRawImageToGameBuf(Image, SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Canvas.Width, Canvas.Height, pointer(Canvas.Buffer), Canvas.ScanlineSize, DrawImageSetup);
end;

function GetDefPngFrame (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): {On} ResLib.TSharedResource;
var
  DefRelPath:  string;
  PngFileName: string;
  PngFilePath: string;

begin
  result      := nil;
  PngFileName := StrLib.Concat([SysUtils.IntToStr(GroupInd), '_', SysUtils.IntToStr(FrameInd), '.png']);
  DefRelPath  := StrLib.Concat([Lodman.GetRedirectedName(Def.GetName, [Lodman.FRF_EXCLUDE_FALLBACKS]), '\', PngFileName]);

  if DefFramesPngFileMap[DefRelPath] <> nil then begin
    PngFilePath := DefFramePngFilePathPrefix + DefRelPath;
    Lodman.FindRedirection(StrLib.Concat([Def.GetName, ':', PngFileName]), PngFilePath, [Lodman.FRF_EXCLUDE_FALLBACKS]);

    result := LoadPngResource(PngFilePath);
  end;
end;

function DefPngFrameExists (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): boolean;
var
{On} ImageResource: ResLib.TSharedResource;

begin
  ImageResource := GetDefPngFrame(Def, GroupInd, FrameInd);
  result        := ImageResource <> nil;

  if result then begin
    ImageResource.DecRef;
  end;
end;

function GetPcxRedirectedName (const PcxName: string): string;
var
{Un} PcxRedirectedName: TString;

begin
  result            := PcxName;
  PcxRedirectedName := PcxPngRedirections[PcxName];

  if PcxRedirectedName <> nil then begin
    result := PcxRedirectedName.Value;
  end;
end;

function GetPcxPng (PcxName: string): {On} ResLib.TSharedResource; overload;
var
     PcxAltName:             string;
{Un} PngFilePath:            TString;
{Un} Image:                  TRawImage;
     PlayerColor:            integer;
     UsePaletteColorization: boolean;
     PlayerPalette:          PColorizablePlayerPalette16;
     WithColors:             TArrayOfColor32;
     i:                      integer;

begin
  result                 := nil;
  PngFilePath            := nil;
  UsePaletteColorization := false;

  PcxName     := Lodman.GetRedirectedName(PcxName, [Lodman.FRF_EXCLUDE_FALLBACKS]);
  PlayerColor := integer(ColorizedPcxPng[PcxName]) - 1;

  // Suppoprt for alternative images for each player color
  if PlayerColor in [Heroes.PLAYER_FIRST..Heroes.PLAYER_LAST] then begin
    PcxAltName  := SysUtils.ChangeFileExt(PcxName, '_p' + SysUtils.IntToStr(PlayerColor) + '.pcx');
    PngFilePath := PcxPngFileMap[GetPcxRedirectedName(PcxAltName)];

    if PngFilePath = nil then begin
      UsePaletteColorization := true;
    end;
  end;

  if PngFilePath = nil then begin
    PngFilePath := PcxPngFileMap[GetPcxRedirectedName(PcxName)];
  end;

  if PngFilePath <> nil then begin
    result := LoadPngResource(PngFilePath.Value);

    // Apply native fixed 32-palette to fixed 32-palette colorization if not applied already to cached image
    if (result <> nil) and UsePaletteColorization then begin
      Image := TRawImage(result.Data);

      if TInt.ToInteger(TInt(Image.Meta[META_PLAYER_COLOR]), -1) <> PlayerColor then begin
        Image.Meta[META_PLAYER_COLOR] := TInt.Create(PlayerColor);
        PlayerPalette                 := @Heroes.PlayerPalettesPtr^.Colors[Length(DefaultPlayerInterfacePalette) * PlayerColor];
        SetLength(WithColors, Length(DefaultPlayerInterfacePalette));

        for i := 0 to High(DefaultPlayerInterfacePalette) do begin
          WithColors[i].Value := GraphTypes.Color16To32(PlayerPalette[i]);
        end;

        Image.RestoreFromBackup;
        Image.MakeBackup;
        Image.ReplaceColors(@DefaultPlayerInterfacePalette[0], @WithColors[0], Length(DefaultPlayerInterfacePalette));
      end; // .if
    end; // .if
  end; // .if
end; // .function GetPcxPng

function GetDefFrameCroppingRect (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): TRect;
var
{On} ImageResource: ResLib.TSharedResource;
{U}  DefFrame:      PDefFrame;

begin
  result.Left   := 0;
  result.Top    := 0;
  result.Right  := Def.Width;
  result.Bottom := Def.Height;

  ImageResource := GetDefPngFrame(Def, GroupInd, FrameInd);

  if ImageResource <> nil then begin
    result := (ImageResource.Data as TRawImage).CroppingRect;
    ImageResource.DecRef;
  end else begin
    DefFrame := Def.GetFrame(GroupInd, FrameInd);

    if DefFrame <> nil then begin
      result.Left   := DefFrame.FrameLeft;
      result.Top    := DefFrame.FrameTop;
      result.Right  := DefFrame.FrameLeft + DefFrame.FrameWidth;
      result.Bottom := DefFrame.FrameTop  + DefFrame.FrameHeight;
    end;
  end;
end; // .function GetDefFrameCroppingRect

function GetDefFrameWidth (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): integer;
begin
  result := GraphTypes.GetRectWidth(GetDefFrameCroppingRect(Def, GroupInd, FrameInd));
end;

function GetDefFrameHeight (Def: Heroes.PDefItem; GroupInd, FrameInd: integer): integer;
begin
  result := GraphTypes.GetRectHeight(GetDefFrameCroppingRect(Def, GroupInd, FrameInd));
end;

procedure DrawInterfaceDefFrameEx (Def: Heroes.PDefItem; GroupInd, FrameInd: integer; SrcX, SrcY, BoxWidth, BoxHeight: integer; Buf: pointer;
                                   DstX, DstY, DstWidth, DstHeight, DstScanlineSize: integer;
                                   const DrawFlags: TDrawDefFrameFlags = []);
var
  FrameCroppingRect: TRect;

begin
  if (BoxWidth <= 0) or (BoxHeight <= 0) or (DstWidth <= 0) or (DstHeight <= 0) then begin
    exit;
  end;

  if DDF_CROP in DrawFlags then begin
    FrameCroppingRect := GetDefFrameCroppingRect(Def, GroupInd, FrameInd);

    BoxWidth  := Math.Min(GraphTypes.GetRectWidth(FrameCroppingRect) - SrcX, BoxWidth);
    BoxHeight := Math.Min(GraphTypes.GetRectHeight(FrameCroppingRect) - SrcY, BoxHeight);
    Inc(SrcX, FrameCroppingRect.Left);
    Inc(SrcY, FrameCroppingRect.Top);
  end;

  if not GraphTypes.RefineDrawBox(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Types.Bounds(0, 0, GraphTypes.MAX_IMAGE_WIDTH, GraphTypes.MAX_IMAGE_HEIGHT),
                                  Types.Bounds(0, 0, DstWidth, DstHeight), DDF_MIRROR in DrawFlags, not DO_VERT_MIRROR) then begin
    exit;
  end;

  if DDF_MIRROR in DrawFlags then begin
    SrcX := Def.Width - SrcX - BoxWidth;
  end;

  PatchApi.Call(THISCALL_, Ptr($47B610), [
    Def, GroupInd, FrameInd, SrcX, SrcY, BoxWidth, BoxHeight, Buf, DstX, DstY, DstWidth, DstHeight, DstScanlineSize,
    ord(DDF_MIRROR in DrawFlags), ord(not (DDF_NO_SPECIAL_PALETTE_COLORS in DrawFlags))
  ]);
end; // .procedure DrawInterfaceDefFrameEx

procedure RescanDefFramesPngFiles;
var
  DefName: string;

begin
  DefFramesPngFileMap.Clear;

  with EraZip.LocateInZipFs(GameExt.GameDir + '\' + DEF_PNG_FRAMES_DIR + '\*', Files.ONLY_DIRS) do begin
    while FindNext do begin
      if (FoundName <> '.') and (FoundName <> '..') then begin
        DefName := FoundName;

        with EraZip.LocateInZipFs(FoundPath + '\' + '*.png', Files.ONLY_FILES) do begin
          while FindNext do begin
            if FoundRec.Rec.Size > 0 then begin
              DefFramesPngFileMap[DefName + '\' + FoundName] := Ptr(1);
            end;
          end;
        end; // .with
      end; // .if
    end; // .while
  end; // .with
end; // .procedure RescanDefFramesPngFiles

procedure ScanDirPcxPngFiles (const DirPath: string);
begin
  with EraZip.LocateInZipFs(DirPath + '\*', Files.FILES_AND_DIRS) do begin
    while FindNext do begin
      if (FoundName <> '.') and (FoundName <> '..') then begin
        if FoundRec.IsDir then begin
          ScanDirPcxPngFiles(FoundPath);
        end else if (FoundRec.Rec.Size > 0) and (SysUtils.AnsiLowerCase(SysUtils.ExtractFileExt(FoundName)) = '.png') then begin
          PcxPngFileMap[SysUtils.ChangeFileExt(FoundName, '.pcx')] := TString.Create(FoundPath);
        end;
      end;
    end; // .while
  end; // .with
end; // .procedure ScanDirPcxPngFiles

procedure RescanPcxPngFiles;
begin
  PcxPngFileMap.Clear;
  PcxPngRedirections.Clear;
  ScanDirPcxPngFiles(GameExt.GameDir + '\' + PCX_PNG_FRAMES_DIR);
end;

procedure SetupColorMode;
var
  Color16Mode: GraphTypes.TColor16Mode;

begin
  Color16Mode := GraphTypes.COLOR_16_MODE_565;

  if Heroes.Color16GreenChannelMaskPtr^ = GraphTypes.GREEN_CHANNEL_MASK_16 then begin
    Color16Mode := GraphTypes.COLOR_16_MODE_565;
  end else if Heroes.Color16GreenChannelMaskPtr^ = GREEN_CHANNEL_MASK_15 then begin
    Color16Mode := GraphTypes.COLOR_16_MODE_555;
  end else begin
    {!} Assert(false, Format('Invalid color 16 green channel mask: %d', [Heroes.Color16GreenChannelMaskPtr^]));
  end;

  GraphTypes.SetColor16Mode(Color16Mode);
end;

procedure OnBeforeScriptsReload (Event: GameExt.PEvent); stdcall;
begin
  RescanDefFramesPngFiles;
  RescanPcxPngFiles;
  ResLib.ResMan.CollectGarbage;
end;

(* Returns true if png frame was found *)
function DrawDefPngFrame (
  Def: Heroes.PDefItem;
  GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoHorizMirror, DoVertMirror: boolean
): boolean;

var
{On} ImageResource:  ResLib.TSharedResource;
{Un} Image:          TRawImage;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetDefPngFrame(Def, GroupInd, FrameInd);
  result        := ImageResource <> nil;

  if ImageResource <> nil then begin
    Image := TRawImage(ImageResource.Data);

    DrawImageSetup.Init;
    DrawImageSetup.EnableFilters := DoHorizMirror or DoVertMirror;
    DrawImageSetup.DoHorizMirror := DoHorizMirror;
    DrawImageSetup.DoVertMirror  := DoVertMirror;

    if DoHorizMirror then begin
      SrcX := Def.Width - SrcX - SrcWidth;
    end;

    if DoVertMirror then begin
      SrcY := Def.Height - SrcY - SrcHeight;
    end;

    DrawRawImageToGameBuf(Image, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end; // .if
end; // .function DrawDefPngFrame

function Hook_DrawInterfaceDefFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror: boolean
): integer; stdcall;

begin
  result := Def.DrawInterfaceDefGroupFrame(0, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, DoMirror, true);
end;

function Hook_DrawInterfaceDefButtonFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror: boolean
): integer; stdcall;

begin
  result := Def.DrawInterfaceDefGroupFrame(0, FrameInd, 0, 0, Def.Width, Def.Height, Buf, DstX, DstY, DstW, DstH, ScanlineSize, DoMirror, true);
end;

procedure Hook_DrawInterfaceDefGroupFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror, UsePaletteSpecialColors: boolean
); stdcall;

begin
  if not DrawDefPngFrame(Def, GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, DoMirror, not DO_VERT_MIRROR) then begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoMirror), ord(UsePaletteSpecialColors)
    ]);
  end;
end;

procedure Hook_DrawInterfaceDefGroupFrameWithOptHalfTransp (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror, UsePaletteSpecialColors: boolean
); stdcall;

var
  CurrentDlg: Heroes.PDlg;

begin
  CurrentDlg := Heroes.AdvManagerPtr^.CurrentDlg;

  if
    (CurrentDlg = nil) or

    not DrawDefPngFrame(
      Def, GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX + CurrentDlg.PosX, DstY + CurrentDlg.PosY, DstW, DstH, ScanlineSize, DoMirror, not DO_VERT_MIRROR
    )
  then begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoMirror), ord(UsePaletteSpecialColors)
    ]);
  end;
end;

procedure Hook_DrawFlagObjectDefFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  FlagColor: word;
  DoMirror: boolean
); stdcall;

var
{On} ImageResource:  ResLib.TSharedResource;
{Un} Image:          TRawImage;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetDefPngFrame(Def, 0, FrameInd);

  if ImageResource <> nil then begin
    Image := ImageResource.Data as TRawImage;

    DrawImageSetup.Init;
    DrawImageSetup.EnableFilters                     := true;
    DrawImageSetup.DoHorizMirror                     := DoMirror;
    DrawImageSetup.NumColorsToReplace                := 5;
    DrawImageSetup.ReplaceColorPairs[0].First.Value  := Image.InternalizeColor32(COLOR_ADV_MAP_OBJECT_FLAG_PLACEHOLDER);
    DrawImageSetup.ReplaceColorPairs[0].Second.Value := GraphTypes.Color16To32(FlagColor);

    DrawImageSetup.ReplaceColorPairs[1].First.Value  := Image.InternalizeColor32(integer($FFFF00FF));
    DrawImageSetup.ReplaceColorPairs[1].Second.Value := integer($80000000);
    DrawImageSetup.ReplaceColorPairs[2].First.Value  := Image.InternalizeColor32(integer($FFFF96FF));
    DrawImageSetup.ReplaceColorPairs[2].Second.Value := integer($60000000);
    DrawImageSetup.ReplaceColorPairs[3].First.Value  := Image.InternalizeColor32(integer($FFFF64FF));
    DrawImageSetup.ReplaceColorPairs[3].Second.Value := integer($40000000);
    DrawImageSetup.ReplaceColorPairs[4].First.Value  := Image.InternalizeColor32(integer($FFFF32FF));
    DrawImageSetup.ReplaceColorPairs[4].Second.Value := integer($20000000);

    if DoMirror then begin
      SrcX := Def.Width - SrcX - SrcWidth;
    end;

    DrawRawImageToGameBuf(Image, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, FlagColor, ord(DoMirror)
    ]);
  end;
end; // .procedure Hook_DrawFlagObjectDefFrame

procedure Hook_DrawNotFlagObjectDefFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror: boolean
); stdcall;

var
{On} ImageResource:  ResLib.TSharedResource;
{Un} Image:          TRawImage;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetDefPngFrame(Def, 0, FrameInd);

  if ImageResource <> nil then begin
    Image := ImageResource.Data as TRawImage;

    DrawImageSetup.Init;
    DrawImageSetup.EnableFilters                     := true;
    DrawImageSetup.DoHorizMirror                     := DoMirror;
    DrawImageSetup.NumColorsToReplace                := 4;
    DrawImageSetup.ReplaceColorPairs[0].First.Value  := Image.InternalizeColor32(integer($FFFF00FF));
    DrawImageSetup.ReplaceColorPairs[0].Second.Value := integer($80000000);
    DrawImageSetup.ReplaceColorPairs[1].First.Value  := Image.InternalizeColor32(integer($FFFF96FF));
    DrawImageSetup.ReplaceColorPairs[1].Second.Value := integer($60000000);
    DrawImageSetup.ReplaceColorPairs[2].First.Value  := Image.InternalizeColor32(integer($FFFF64FF));
    DrawImageSetup.ReplaceColorPairs[2].Second.Value := integer($40000000);
    DrawImageSetup.ReplaceColorPairs[3].First.Value  := Image.InternalizeColor32(integer($FFFF32FF));
    DrawImageSetup.ReplaceColorPairs[3].Second.Value := integer($20000000);

    if DoMirror then begin
      SrcX := Def.Width - SrcX - SrcWidth;
    end;

    DrawRawImageToGameBuf(Image, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoMirror)
    ]);
  end; // .else
end; // .procedure Hook_DrawNotFlagObjectDefFrame

procedure Hook_DrawDefFrameType0Or2 (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoHorizMirror, DoVertMirror: boolean
); stdcall;

begin
  if not DrawDefPngFrame(Def, 0, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, DoHorizMirror, DoVertMirror) then begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoHorizMirror), ord(DoVertMirror)
    ]);
  end;
end;

procedure Hook_DrawBattleMonDefFrame (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoHorizMirror:  boolean;
  SelectionColor: word
); stdcall;

var
{On} ImageResource:  ResLib.TSharedResource;
{Un} Image:          TRawImage;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetDefPngFrame(Def, GroupInd, FrameInd);

  if ImageResource <> nil then begin
    Image := ImageResource.Data as TRawImage;

    DrawImageSetup.Init;
    DrawImageSetup.DoHorizMirror                    := DoHorizMirror;
    DrawImageSetup.NumColorsToReplace               := 5;
    DrawImageSetup.EnableFilters                    := true;
    DrawImageSetup.ReplaceColorPairs[0].First.Value := Image.InternalizeColor32(COLOR_BATTLE_DEF_SELECTION_PLACEHOLDER);
    DrawImageSetup.Palette                          := DefBattleEffects[Def.GetName];
    DrawImageSetup.DoUsePalette                     := DrawImageSetup.Palette <> nil;

    if DrawImageSetup.DoUsePalette then begin
      DefBattleEffects.DeleteItem(Def.GetName);
      {!} Assert(DefBattleEffects[Def.GetName] = nil);
    end;

    if SelectionColor = 0 then begin
      DrawImageSetup.ReplaceColorPairs[0].Second.Value := COLOR_TRANSPARENT;
    end else begin
      DrawImageSetup.ReplaceColorPairs[0].Second.Value := GraphTypes.Color16To32(SelectionColor);
    end;

    DrawImageSetup.ReplaceColorPairs[1].First.Value  := Image.InternalizeColor32(integer($FFFF00FF));
    DrawImageSetup.ReplaceColorPairs[1].Second.Value := integer($80000000);
    DrawImageSetup.ReplaceColorPairs[2].First.Value  := Image.InternalizeColor32(integer($FFFF96FF));
    DrawImageSetup.ReplaceColorPairs[2].Second.Value := integer($60000000);
    DrawImageSetup.ReplaceColorPairs[3].First.Value  := Image.InternalizeColor32(integer($FFFF64FF));
    DrawImageSetup.ReplaceColorPairs[3].Second.Value := integer($40000000);
    DrawImageSetup.ReplaceColorPairs[4].First.Value  := Image.InternalizeColor32(integer($FFFF32FF));
    DrawImageSetup.ReplaceColorPairs[4].Second.Value := integer($20000000);

    if DoHorizMirror then begin
      SrcX := Def.Width - SrcX - SrcWidth;
    end;

    DrawRawImageToGameBuf(Image, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoHorizMirror), SelectionColor
    ]);
  end;
end; // .procedure Hook_DrawBattleMonDefFrame

function Hook_ApplyBloodLustToDefPalette (Context: ApiJack.PHookContext): longbool; stdcall;
var
  EffectLevel: integer;

begin
  EffectLevel := (trunc(Heroes.TValue(Context.EDX).f * 100) + 5) div 10 - 1;

  if EffectLevel >= 0 then begin
    DefBattleEffects[Heroes.PDefItem(pinteger(Context.EBX + $164)^).GetName] := @BloodLustEffectPalette[Alg.ToRange(EffectLevel, 0, 9)];
  end;

  result := true;
end;

function Hook_ApplyPetrificationToDefPalette (Context: ApiJack.PHookContext): longbool; stdcall;
var
  EffectLevel: integer;

begin
  EffectLevel := (trunc((1.0 - Heroes.TValue(Context.EDX).f) * 100) + 5) div 10 - 1;

  if EffectLevel >= 0 then begin
    DefBattleEffects[Heroes.PDefItem(pinteger(Context.EBX + $164)^).GetName] := @PetrificationEffectPalette[Alg.ToRange(EffectLevel, 0, 9)];
  end;

  result := true;
end;

function Hook_ApplyGrayscaleToDefPalette (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  DefBattleEffects[Heroes.PDefItem(pinteger(Context.EBX + $164)^).GetName] := @PetrificationEffectPalette[High(PetrificationEffectPalette)];

  result := true;
end;

function Hook_ApplyCloningToDefPalette (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  DefBattleEffects[Heroes.PDefItem(pinteger(Context.EBX + $164)^).GetName] := @CloneEffectPalette;

  result := true;
end;

function Hook_AfterBattleDefPaletteEffects (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  DefBattleEffects.DeleteItem(Heroes.PDefItem(pinteger(Context.EBX + $164)^).GetName);
  result := true;
end;

procedure Hook_DrawDefFrameType0Or2Shadow (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoHorizMirror, DoVertMirror: boolean
); stdcall;

begin
  if not DefPngFrameExists(Def, 0, FrameInd) then begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoHorizMirror), ord(DoVertMirror)
    ]);
  end;
end;

procedure Hook_DrawDefFrameType3Shadow (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoHorizMirror: boolean
); stdcall;

begin
  if not DefPngFrameExists(Def, 0, FrameInd) then begin
    PatchApi.Call(THISCALL_, OrigFunc, [
      Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoHorizMirror)
    ]);
  end;
end;

procedure Hook_DrawPcx16ToPcx16 (
  OrigFunc: pointer;
  Pcx: Heroes.PPcx16Item;
  SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize, TransparentColor: integer
); stdcall;

var
{On} ImageResource:  ResLib.TSharedResource;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetPcxPng(Pcx.GetName);

  if ImageResource <> nil then begin
    DrawImageSetup.Init;
    DrawRawImageToGameBuf(ImageResource.Data as TRawImage, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [Pcx, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, TransparentColor]);
  end;
end; // .procedure Hook_DrawPcx16ToPcx16

procedure Hook_DrawPcx8ToPcx16 (
  OrigFunc: pointer;
  Pcx: Heroes.PPcx8Item;
  SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize, TransparentColor: integer
); stdcall;

var
{On} ImageResource:  ResLib.TSharedResource;
     DrawImageSetup: GraphTypes.TDrawImageSetup;

begin
  ImageResource := GetPcxPng(Pcx.GetName);

  if ImageResource <> nil then begin
    DrawImageSetup.Init;
    DrawRawImageToGameBuf(ImageResource.Data as TRawImage, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize, DrawImageSetup);

    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [Pcx, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, TransparentColor]);
  end;
end; // .procedure Hook_DrawPcx8ToPcx16

function Hook_ColorizePcx8ToPlayerColors (
  OrigFunc:        pointer;
  Palette16Colors: Heroes.PPalette16Colors;
  PlayerId:        integer
): integer; stdcall;

var
  Pcx8:    Heroes.PPcx8Item;
  PcxName: string;

begin
  result  := PatchApi.Call(FASTCALL_, OrigFunc, [Palette16Colors, PlayerId]);
  PcxName := '';

  try
    Pcx8 := Utils.PtrOfs(Palette16Colors, -integer(@Heroes.PPcx8Item(0).Palette16.Colors));

    if Pcx8.IsPcx8() then begin
      PcxName := Pcx8.GetName;
    end;
  except
    exit;
  end;

  if PcxName <> '' then begin
    ColorizedPcxPng[PcxName] := Ptr(PlayerId + 1);
  end;
end; // .function Hook_ColorizePcx8ToPlayerColors

function Hook_LoadPcx8 (
  OrigFunc: pointer;
  FileName: pchar
): Heroes.PPcx8Item; stdcall;

var
{Un} PngFilePath:   TString;
{On} ImageResource: ResLib.TSharedResource;
{Un} Image:         TRawImage;
     FileNameStr:   string;

begin
  FileNameStr := FileName;
  PngFilePath := PcxPngFileMap[FileNameStr];

  // Create stubs for images, for which there are known png replacements
  if PngFilePath <> nil then begin
    ImageResource := LoadPngResource(PngFilePath.Value);

    if ImageResource <> nil then begin
      Image  := ImageResource.Data as TRawImage;
      result := TPcx8ItemStatic.Create(FileNameStr, Image.Width, Image.Height);

      ImageResource.DecRef;
    end else begin
      result := Ptr(PatchApi.Call(THISCALL_, OrigFunc, [FileName]));
    end;
  end else begin
    result := Ptr(PatchApi.Call(THISCALL_, OrigFunc, [FileName]));
  end;
end; // .function Hook_LoadPcx8

function Hook_LoadPcx16 (
  OrigFunc: pointer;
  FileName: pchar
): Heroes.PPcx16Item; stdcall;

var
{Un} PngFilePath:   TString;
{On} ImageResource: ResLib.TSharedResource;
{Un} Image:         TRawImage;
     FileNameStr:   string;

begin
  FileNameStr := FileName;
  PngFilePath := PcxPngFileMap[FileNameStr];

  // Create stubs for images, for which there are known png replacements
  if PngFilePath <> nil then begin
    ImageResource := LoadPngResource(PngFilePath.Value);

    if ImageResource <> nil then begin
      Image  := ImageResource.Data as TRawImage;
      result := TPcx16ItemStatic.Create(FileNameStr, Image.Width, Image.Height);

      ImageResource.DecRef;
    end else begin
      result := Ptr(PatchApi.Call(THISCALL_, OrigFunc, [FileName]));
    end;
  end else begin
    result := Ptr(PatchApi.Call(THISCALL_, OrigFunc, [FileName]));
  end;
end; // .function Hook_LoadPcx16

function GetMicroTime: Int64;
var
  Freq: Int64;

begin
  QueryPerformanceCounter(result);
  QueryPerformanceFrequency(Freq);
  result := result * 1000000 div Freq;
end;

procedure GenerateBattleStackEffectPalettes;
const
  PALETTE_COLOR_TO_31_SCALE   = High(integer) div ((1 shl GraphTypes.FILTER_PALETTE_BITS_PER_COLOR) - 1);
  COLOR_8_TO_31_SCALE         = High(integer) div ((1 shl 8) - 1);
  PALETTE_LOW_CHANNEL_BITMASK = (1 shl GraphTypes.FILTER_PALETTE_BITS_PER_COLOR) - 1;

var
  Hue:              single;
  Saturation:       single;
  Brightness:       single;
  NewHue:           single;
  EffectPercent: single;
  Red:              integer;
  Green:            integer;
  Blue:             integer;
  i, j:             integer;

begin
  for i := 0 to High(CloneEffectPalette) do begin
    Heroes.Rgb96ToHsb(
      ((i and (PALETTE_LOW_CHANNEL_BITMASK shl 10)) shr (GraphTypes.FILTER_PALETTE_BITS_PER_COLOR * 2)) * PALETTE_COLOR_TO_31_SCALE,
      ((i and (PALETTE_LOW_CHANNEL_BITMASK shl 5)) shr (GraphTypes.FILTER_PALETTE_BITS_PER_COLOR * 1)) * PALETTE_COLOR_TO_31_SCALE,
      (i and PALETTE_LOW_CHANNEL_BITMASK) * PALETTE_COLOR_TO_31_SCALE,
      Hue, Saturation, Brightness
    );

    Heroes.HsbToRgb96(Red, Green, 0.67, 1 - ((1 - Saturation) / 2), 1 - ((1 - Brightness) / 2), Blue);
    CloneEffectPalette[i] := ((cardinal(Red) div COLOR_8_TO_31_SCALE) shl 16) or ((cardinal(Green) div COLOR_8_TO_31_SCALE) shl 8) or (cardinal(Blue) div COLOR_8_TO_31_SCALE);

    for j := Low(BloodLustEffectPalette) to High(BloodLustEffectPalette) do begin
      EffectPercent := (j + 1) * 0.1;

      if (Hue > 0.5) and (EffectPercent < 1.0) then begin
        NewHue := Hue + (1.0 - Hue) * EffectPercent;
      end else begin
        NewHue := Hue * (1.0 - EffectPercent);
      end;

      Heroes.HsbToRgb96(Red, Green, NewHue, 1 - ((1 - Saturation) / (1.0 + EffectPercent)), 1 - ((1 - Brightness) / (1.0 + EffectPercent)), Blue);
      BloodLustEffectPalette[j, i] := ((cardinal(Red) div COLOR_8_TO_31_SCALE) shl 16) or ((cardinal(Green) div COLOR_8_TO_31_SCALE) shl 8) or (cardinal(Blue) div COLOR_8_TO_31_SCALE);
    end; // .for

    for j := Low(PetrificationEffectPalette) to High(PetrificationEffectPalette) do begin
      EffectPercent := (j + 1) * 0.1;

      Heroes.HsbToRgb96(Red, Green, Hue, Saturation * (1.0 - EffectPercent), Brightness, Blue);
      PetrificationEffectPalette[j, i] := ((cardinal(Red) div COLOR_8_TO_31_SCALE) shl 16) or ((cardinal(Green) div COLOR_8_TO_31_SCALE) shl 8) or (cardinal(Blue) div COLOR_8_TO_31_SCALE);
    end; // .for
  end; // .for
end; // .procedure GenerateBattleStackEffectPalettes

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
begin
  SetupColorMode;
  GenerateBattleStackEffectPalettes;
  ApiJack.StdSplice(Ptr($47B820), @Hook_DrawInterfaceDefFrame, ApiJack.CONV_THISCALL, 13);
  ApiJack.StdSplice(Ptr($47B7D0), @Hook_DrawInterfaceDefButtonFrame, ApiJack.CONV_THISCALL, 9);
  ApiJack.StdSplice(Ptr($47B610), @Hook_DrawInterfaceDefGroupFrame, ApiJack.CONV_THISCALL, 15);
  ApiJack.StdSplice(Ptr($47BA90), @Hook_DrawInterfaceDefGroupFrameWithOptHalfTransp, ApiJack.CONV_THISCALL, 15);
  ApiJack.StdSplice(Ptr($47B730), @Hook_DrawFlagObjectDefFrame, ApiJack.CONV_THISCALL, 14);
  ApiJack.StdSplice(Ptr($47B6E0), @Hook_DrawNotFlagObjectDefFrame, ApiJack.CONV_THISCALL, 13);
  ApiJack.StdSplice(Ptr($47B870), @Hook_DrawDefFrameType0Or2, ApiJack.CONV_THISCALL, 14);
  ApiJack.StdSplice(Ptr($47B8C0), @Hook_DrawDefFrameType0Or2Shadow, ApiJack.CONV_THISCALL, 14);
  ApiJack.StdSplice(Ptr($47B780), @Hook_DrawDefFrameType3Shadow, ApiJack.CONV_THISCALL, 13);
  ApiJack.StdSplice(Ptr($44DF80), @Hook_DrawPcx16ToPcx16, ApiJack.CONV_THISCALL, 12);
  ApiJack.StdSplice(Ptr($44F940), @Hook_DrawPcx8ToPcx16, ApiJack.CONV_THISCALL, 12);
  ApiJack.StdSplice(Ptr($6003E0), @Hook_ColorizePcx8ToPlayerColors, ApiJack.CONV_FASTCALL, 2);
  ApiJack.StdSplice(Ptr($55AA10), @Hook_LoadPcx8, ApiJack.CONV_THISCALL, 1);
  ApiJack.StdSplice(Ptr($55AE50), @Hook_LoadPcx16, ApiJack.CONV_THISCALL, 1);

  ApiJack.StdSplice(Ptr($47B680), @Hook_DrawBattleMonDefFrame, ApiJack.CONV_THISCALL, 15);
  ApiJack.HookCode(Ptr($43E013),  @Hook_ApplyBloodLustToDefPalette);
  ApiJack.HookCode(Ptr($43E0B9),  @Hook_ApplyPetrificationToDefPalette);
  ApiJack.HookCode(Ptr($43E12E),  @Hook_ApplyGrayscaleToDefPalette);
  ApiJack.HookCode(Ptr($43E1BA),  @Hook_ApplyCloningToDefPalette);
  ApiJack.HookCode(Ptr($43E288),  @Hook_AfterBattleDefPaletteEffects);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  DefFramePngFilePathPrefix := GameExt.GameDir + '\' + DEF_PNG_FRAMES_DIR + '\';
  RescanDefFramesPngFiles;
  RescanPcxPngFiles;
end;

begin
  DefFramesPngFileMap := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  PcxPngFileMap       := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  PcxPngRedirections  := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  ColorizedPcxPng     := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  DefBattleEffects    := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);

  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnBeforeScriptsReload', OnBeforeScriptsReload);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.