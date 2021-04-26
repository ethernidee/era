unit Graph;

(***)  interface  (***)

uses
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
  PatchApi,
  PngImage,
  ResLib,
  StrLib,
  Types,
  WinUtils,
  Utils;

const
  (* ResizeBmp24.FreeOriginal argument *)
  FREE_ORIGINAL_BMP      = true;
  DONT_FREE_ORIGINAL_BMP = false;

  BMP_24_COLOR_DEPTH = 24;

  (* Width and height values *)
  AUTO_WIDTH  = 0;
  AUTO_HEIGHT = 0;

  (* Paths *)
  DEF_PNG_FRAMES_DIR = 'Data\Defs';

type
  (* Import *)
  TGraphic   = Graphics.TGraphic;
  TBitmap    = Graphics.TBitmap;
  TJpegImage = Jpeg.TJpegImage;
  TPngObject = PngImage.TPngObject;
  TDict      = DataLib.TDict;

  TImageType = (IMG_UNKNOWN, IMG_BMP, IMG_JPG, IMG_PNG);
  TResizeAlg = (ALG_NO_RESIZE = 0, ALG_STRETCH = 1, ALG_CONTAIN = 2, ALG_DOWNSCALE = 3, ALG_UPSCALE = 4, ALG_COVER = 5, ALG_FILL = 6);

  TDimensionsDetectionType = (USE_IMAGE_VALUES, CALC_PROPORTIONALLY);


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

(* Loads given png file from cache or file system and returns TRawImage in the best format wrapped into shared resource *)
function LoadPngResource (const FilePath: string): {On} ResLib.TSharedResource;

(* Draws any raw image to Pcx16 canvas *)
procedure DrawRawImageToPcx16Canvas (Image: GraphTypes.TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; Canvas: Heroes.PPcx16Item);


(***)  implementation  (***)


var
// Caseinsensitive map of "defname.def\frame_index.png" => 1 if frame png file exists.
{O} DefFramesPngFileMap: {U} TDict {of Ptr(1)};

  DefFramePngFilePathPrefix: string; // Like "D:\Games\Heroes 3\Data\Defs\"


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
  Rect: Types.TRect;

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
    Core.NotifyError(Format('Failed to load image at "%s"', [FilePath]));
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
  end;

  // Search fixed named resource in cache. It must be absent or be pcx16
  if not UseAutoNaming then begin
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

function LoadPngResource (const FilePath: string): {On} ResLib.TSharedResource;
var
{On} Image:        GraphTypes.TRawImage;
{On} Image16:      GraphTypes.TRawImage16;
{On} Image32:      GraphTypes.TRawImage32;
{On} Image32Alpha: GraphTypes.TPremultipliedRawImage32;
     FileContents: string;
     ImageSize:    integer;
     Image16Setup: GraphTypes.TRawImage16Setup;
     Image32Setup: GraphTypes.TRawImage32Setup;

begin
  Image        := nil;
  Image16      := nil;
  Image32      := nil;
  Image32Alpha := nil;
  // * * * * * //
  result := ResLib.ResMan.GetResource(FilePath);

  if result <> nil then begin
    if not (result.Data is GraphTypes.TRawImage) then begin
      result.DecRef;
      result := nil;
    end;

    exit;
  end;

  if not Files.ReadFileContents(FilePath, FileContents) then begin
    exit;
  end;

  Image32 := Libspng.DecodePng(pchar(FileContents), Length(FileContents));

  if Image32 = nil then begin
    exit;
  end;

  ImageSize := Length(Image32.Pixels) * sizeof(Image32.Pixels[0]);

  if Image32.HasTransparency then begin
    Image32Setup.Init;
    Image32Setup.HasTransparency := true;
    Image32Alpha                 := TPremultipliedRawImage32.Create(Image32.Pixels, Image32.Width, Image32.Height, Image32.ScanlineSize);
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

    ImageSize := Length(Image16.Pixels) * sizeof(Image16.Pixels[0]);
    Utils.Exchange(Image, Image16);
  end;

  result := ResLib.ResMan.AddResource(Image, ImageSize, FilePath); Image := nil;
  // * * * * * //
  SysUtils.FreeAndNil(Image);
  SysUtils.FreeAndNil(Image16);
  SysUtils.FreeAndNil(Image32);
  SysUtils.FreeAndNil(Image32Alpha);
end; // .function LoadPngResource

procedure DrawRawImageToPcx16Canvas (Image: GraphTypes.TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight: integer; Canvas: Heroes.PPcx16Item);
begin
  {!} Assert(Image <> nil);
  {!} Assert(Canvas <> nil);

  if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
    Image.DrawToOpaque32Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Canvas.Width, Canvas.Height, pointer(Canvas.Buffer), Canvas.ScanlineSize);
  end else begin
    Image.DrawToOpaque16Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, Canvas.Width, Canvas.Height, pointer(Canvas.Buffer), Canvas.ScanlineSize);
  end;
end;

procedure DrawRawImageToGameBuf (Image: GraphTypes.TRawImage; SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH: integer; Buf: pointer; DstScanlineSize: integer);
begin
  {!} Assert(Image <> nil);
  {!} Assert(Buf <> nil);

  if Heroes.BytesPerPixelPtr^ = sizeof(GraphTypes.TColor32) then begin
    Image.DrawToOpaque32Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH, Buf, DstScanlineSize);
  end else begin
    Image.DrawToOpaque16Buf(SrcX, SrcY, DstX, DstY, BoxWidth, BoxHeight, DstW, DstH, Buf, DstScanlineSize);
  end;
end;

// procedure LoadPng (const FilePath: string);
// var
// {On} Image:        GraphTypes.TRawImage32;
//      FileContents: string;
//      Png: TPngObject;

// begin
//   Files.ReadFileContents(FilePath, FileContents);
//   Image := Libspng.DecodePng(pchar(FileContents), Length(FileContents));
//   Png := TPngObject.Create;
//   Png.LoadFromFile(FilePath);
// end;

procedure RescanDefFramesPngFiles;
var
  DefName: string;

begin
  DefFramesPngFileMap.Clear;

  with Files.Locate(GameExt.GameDir + '\' + DEF_PNG_FRAMES_DIR + '\*', Files.ONLY_DIRS) do begin
    while FindNext do begin
      if (FoundName <> '.') and (FoundName <> '..') then begin
        DefName := FoundName;

        with Files.Locate(FoundPath + '\' + '*.png', Files.ONLY_FILES) do begin
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

procedure SetupColorMode;
var
  Color16Mode: GraphTypes.TColor16Mode;

begin
  Color16Mode := GraphTypes.COLOR_16_MODE_565;

  if Heroes.Color16GreenChannelMaskPtr^ = GraphTypes.GREEN_CHANNEL_MASK16 then begin
    Color16Mode := GraphTypes.COLOR_16_MODE_565;
  end else if Heroes.Color16GreenChannelMaskPtr^ = GREEN_CHANNEL_MASK15 then begin
    Color16Mode := GraphTypes.COLOR_16_MODE_555;
  end else begin
    {!} Assert(false, Format('Invalid color 16 green channel mask: %d', [Heroes.Color16GreenChannelMaskPtr^]));
  end;

  GraphTypes.SetColor16Mode(Color16Mode);
end;

procedure OnBeforeScriptsReload (Event: GameExt.PEvent); stdcall;
begin
  RescanDefFramesPngFiles;
end;

procedure Hook_DrawInterfaceDef (
  OrigFunc: pointer;
  Def: Heroes.PDefItem;
  FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, ScanlineSize: integer;
  DoMirror: boolean
); stdcall;

var
{On} ImageResource: ResLib.TSharedResource;
     DefRelPath:    string;

begin
  ImageResource := nil;
  DefRelPath    := StrLib.Concat([pchar(@Def.Name[0]), '\', SysUtils.IntToStr(FrameInd), '.png']);

  if DefFramesPngFileMap[DefRelPath] <> nil then begin
    ImageResource := LoadPngResource(DefFramePngFilePathPrefix + DefRelPath);
  end;

  if ImageResource <> nil then begin
    DrawRawImageToGameBuf(ImageResource.Data as GraphTypes.TRawImage, SrcX, SrcY, DstX, DstY, SrcWidth, SrcHeight, DstW, DstH, Buf, ScanlineSize);
    ImageResource.DecRef;
  end else begin
    PatchApi.Call(THISCALL_, OrigFunc, [Def, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, ord(DoMirror)]);
  end;
end;

// function GetMicroTime: Int64;
// var
//   Freq: Int64;

// begin
//   QueryPerformanceCounter(result);
//   QueryPerformanceFrequency(Freq);
//   result := result * 1000 div Freq;
// end;

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
var
  i:            integer;
  StartTime:    Int64;
  ImgResource:  ResLib.TSharedResource;
  Img:          GraphTypes.TRawImage;
  Pixels:       GraphTypes.TArrayOfColor32;
  Canvas:       GraphTypes.TArrayOfColor32;
  PngImage:     TPngObject;
  FileContents: string;

begin
  SetupColorMode;
  ApiJack.StdSplice(Ptr($47B820), @Hook_DrawInterfaceDef, ApiJack.CONV_THISCALL, 13);
  //LoadImageAsPcx16('D:\Leonid Afremov. Zima.png', 'zpic1005.pcx', 800, 600);
  //ImgResource := LoadPngResource('D:\forum_ava_source.png');
  // StartTime   := GetMicroTime();
  // ReadFileContents('D:\forum_ava_source_alpha2.png', FileContents);
  // VarDump(['load file', GetMicroTime - StartTime]);
  // StartTime   := GetMicroTime();
  // Libspng.DecodePng(pchar(FileContents), Length(FileContents));
  // VarDump(['decode from memory', GetMicroTime - StartTime]);
  // StartTime   := GetMicroTime();
  // ImgResource := LoadPngResource('D:\forum_ava_source_alpha2.png');
  // Img         := ImgResource.Data as GraphTypes.TRawImage;
  // VarDump([GetMicroTime - StartTime, Img.ClassType]);
  // StartTime := GetMicroTime();
  // PngImage  := TPngObject.Create;
  // PngImage.LoadFromFile('D:\forum_ava_source_alpha2.png');
  // VarDump([GetMicroTime - StartTime]);
  // SetLength(Canvas, Img.Width * Img.Height);
  // StartTime   := GetMicroTime();
  // Img.DrawToOpaque32Buf(0, 0, 0, 0, Img.Width, Img.Height, Img.Width, Img.Height, pointer(Canvas), Img.Width * sizeof(Canvas[0]));
  // DlgMes.Msg('draw time: ' + inttostr(GetMicroTime - StartTime));
  //FileWrite(FileCreate('D:\forum_ava_source.raw'), Canvas[0], Length(Canvas) * sizeof(Canvas[0]));
  //ImgResource := LoadPngResource('Data\defs\AVMsulf0.def\0.png');
  //Img := ImgResource.Data as TRawImage32;
  //VarDump([Ptr(Img.Pixels[0].Value)]);

  // SetLength(Pixels, 10);
  // //Img := TRawImage32.Create(Pixels, 5, 2, 20, [RIF_HAS_TRANSPARENCY]);
  // Pixels := nil;
  // Pixels := Img.Pixels;
  // Pixels[3].Value := -1;
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  DefFramePngFilePathPrefix := GameExt.GameDir + '\' + DEF_PNG_FRAMES_DIR + '\';
  RescanDefFramesPngFiles;
end;

begin
  DefFramesPngFileMap := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);

  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnBeforeScriptsReload', OnBeforeScriptsReload);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.