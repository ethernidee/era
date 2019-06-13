unit Graph;

(***)  interface  (***)

uses
  SysUtils, Graphics, Jpeg, Types, PngImage, Utils, Core,
  Heroes, GameExt, EventMan;

const
  (* ResizeBmp24.FreeOriginal argument *)
  FREE_ORIGINAL_BMP      = true;
  DONT_FREE_ORIGINAL_BMP = false;

  BMP_24_COLOR_DEPTH = 24;

  (* Width and height values *)
  AUTO_WIDTH  = 0;
  AUTO_HEIGHT = 0;

type
  (* Import *)
  TGraphic   = Graphics.TGraphic;
  TBitmap    = Graphics.TBitmap;
  TJpegImage = Jpeg.TJpegImage;
  TPngObject = PngImage.TPngObject;

  TImageType = (IMG_UNKNOWN, IMG_BMP, IMG_JPG, IMG_PNG);

  PColor24 = ^TColor24;
  TColor24 = packed record
    Blue:  byte;
    Green: byte;
    Red:   byte;
  end;

  PColor24Arr = ^TColor24Arr;
  TColor24Arr = array [0..MAXLONGINT div sizeof(TColor24) - 1] of TColor24;

  TImageRatio = record
    Width:  single;
    Height: single;
  end;

  TImageSize = record
    Width:  integer;
    Height: integer;
  end;


function  LoadImage (const FilePath: string): {n} TGraphic;

(* Fast bitmap scaling. Input bitmap is forced to be 24 bit. *)
function ResizeBmp24 ({OU} Image: TBitmap; NewWidth, NewHeight: integer; FreeOriginal: boolean): {O} TBitmap;

(* ©Charles Hacker, adapted by ethernidee. Input bitmap is forced to be 24 bit. *)
function  SmoothResizeBmp24 ({OU} abmp: TBitmap; NewWidth, NewHeight: integer; FreeOriginal: boolean): {O} TBitmap;

function LoadImageAsPcx16 (FilePath: string; PcxName: string = ''; Width: integer = AUTO_WIDTH; Height: integer = AUTO_HEIGHT): {OU} Heroes.PPcx16Item;


(***)  implementation  (***)


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

function GetImageRatio (Image: TBitmap): TImageRatio;
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

function GetScaledBmp24Size (Image: TBitmap; NewWidth, NewHeight: integer): TImageSize;
var
  OldWidth:   integer;
  OldHeight:  integer;
  ImageRatio: TImageRatio;

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

function ResizeBmp24 ({OU} Image: TBitmap; NewWidth, NewHeight: integer; FreeOriginal: boolean): {O} TBitmap;
var
  NewImageSize: TImageSize;

begin
  NewImageSize := GetScaledBmp24Size(Image, NewWidth, NewHeight);
  // * * * * * //
  if FreeOriginal and (Image.Width = NewWidth) and (Image.Height = NewHeight) then begin
    result := Image; Image := nil;
  end else begin
    result             := TBitmap.Create;
    result.PixelFormat := pf24bit;
    result.SetSize(NewImageSize.Width, NewImageSize.Height);
    result.Canvas.StretchDraw(Rect(0, 0, NewImageSize.Width, NewImageSize.Height), Image);

    if FreeOriginal then begin
      FreeAndNil(Image);
    end;
  end; // .else
end; // .procedure ResizeBmp24

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
  sli, slo:               PColor24Arr;

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
{U} BmpPixels:       PColor24;
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
{U} BmpPixels:       PColor24;
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

(* Loads Pcx16 resource with rescaling support. Values <= 0 are considered 'auto'. If it's possible, images are scaled proportionally.
   Resource name (name in binary resource tree) can be either fixed or automatic. Pass empty PcxName for automatic name.
   If PcxName exceeds 12 characters, it's replaced with valid unique name. Check name field of result.
   If resource is already registered and has proper format, it's returned with RefCount increased.
   Result image dimensions may differ from requested if fixed PcxName is specified. Use automatic naming
   to load image of desired size for sure.
   Default image is returned in case of missing file and user is notified. *)
function LoadImageAsPcx16 (FilePath: string; PcxName: string = ''; Width: integer = AUTO_WIDTH; Height: integer = AUTO_HEIGHT): {OU} Heroes.PPcx16Item;
var
{O}  Bmp:               TBitmap;
{Un} CachedItem:        Heroes.PPcx16Item;
{On} Pcx24:             Heroes.PPcx24Item;
     NewSize:           TImageSize;
     UseAutoNaming:     boolean;
     IsUnsizedNameFree: boolean;
     IsSizedNameFree:   boolean;

begin
  Bmp        := nil;
  CachedItem := nil;
  result     := nil;
  // * * * * * //

  UseAutoNaming     := PcxName = '';
  IsUnsizedNameFree := true;
  IsSizedNameFree   := true;
  FilePath          := SysUtils.ExpandFileName(FilePath);

  // Fixed name is used, item must be absent in resource tree or have pcx24 format.
  // Cached item is used even if dimensions are different from desired.
  if not UseAutoNaming then begin
    PcxName := Heroes.ResourceNamer.GetResourceName(PcxName);

    if Heroes.ResourceTree.FindItem(PcxName, Heroes.PBinaryTreeItem(CachedItem)) then begin
      {!} Assert(CachedItem.IsPcx16(), Format('Image "%s", requested to be loaded from "%s" is already loaded, but has non-pcx16 type', [PcxName, FilePath]));
      result := CachedItem;
      result.IncRef();
    end;
  end
  // Auto naming is used
  else begin
    // No size is forced, form name without dimensions and search for pcx16 only in cache
    if (Width <= 0) and (Height <= 0) then begin
      PcxName    := Heroes.ResourceNamer.GetResourceName(FilePath);
      CachedItem := nil;

      if Heroes.ResourceTree.FindItem(PcxName, Heroes.PBinaryTreeItem(CachedItem)) and (CachedItem.IsPcx16()) then begin
        result := CachedItem;
        result.IncRef();
      end;

      IsUnsizedNameFree := IsUnsizedNameFree and (CachedItem = nil);
    end
    // Fixed dimensions are specified, look for exact sized pcx16 result in cache
    else if (Width > 0) and (Height > 0) then begin
      PcxName    := Heroes.ResourceNamer.GetResourceName(Format('%s:%dx%d', [FilePath, Width, Height]));
      CachedItem := nil;

      if Heroes.ResourceTree.FindItem(PcxName, Heroes.PBinaryTreeItem(CachedItem)) and (CachedItem.IsPcx16()) and (CachedItem.Width = Width) and (CachedItem.Height = Height) then begin
        result := CachedItem;
        result.IncRef();
      end;

      IsSizedNameFree := IsSizedNameFree and (CachedItem = nil);
    end; // .elseif
  end; // .else

  // All initial cache queries failed, need to load image from file to get extra information
  if result = nil then begin
    Bmp     := LoadImageAsBmp24(FilePath);
    NewSize := GetScaledBmp24Size(Bmp, Width, Height);

    // Query cache for exact sized pcx24 in case of autonaming
    if UseAutoNaming then begin
      PcxName    := Heroes.ResourceNamer.GetResourceName(Format('%s:%dx%d', [FilePath, NewSize.Width, NewSize.Height]));
      CachedItem := nil;

      if Heroes.ResourceTree.FindItem(PcxName, Heroes.PBinaryTreeItem(CachedItem)) and (CachedItem.IsPcx24()) and (CachedItem.Width = NewSize.Width) and (CachedItem.Height = NewSize.Height) then begin
        result := CachedItem;
        result.IncRef();
      end;

      IsSizedNameFree := IsSizedNameFree and (CachedItem = nil);
    end;  // .if
  end; // .if

  // Image is loaded, but all possible cache queries failed
  if result = nil then begin
    // Form final image name in cache, if necessary
    if UseAutoNaming then begin
      if (Width <= 0) and (Height <= 0) and IsUnsizedNameFree then begin
        PcxName := Heroes.ResourceNamer.GetResourceName(FilePath);
      end else if IsSizedNameFree then begin
        PcxName := Heroes.ResourceNamer.GetResourceName(Format('%s:%dx%d', [FilePath, NewSize.Width, NewSize.Height]));
      end else begin
        PcxName := Heroes.ResourceNamer.GenerateUniqueResourceName();
      end;
    end;

    // Perform image scaling if necessary
    if (Bmp.Width <> NewSize.Width) or (Bmp.Height <> NewSize.Height) then begin
      Bmp := ResizeBmp24(Bmp, NewSize.Width, NewSize.Height, FREE_ORIGINAL_BMP);
    end;
    
    // Perform image conversion and resource insertion
    Pcx24  := Bmp24ToPcx24(Bmp, PcxName);
    result := Heroes.TPcx16ItemStatic.Create(PcxName, Bmp.Width, Bmp.Height);
    Pcx24.DrawToPcx16(0, 0, Bmp.Width, Bmp.Height, result, 0, 0);
    Pcx24.Destruct;
    //result := pointer(Pcx24);

    result.IncRef();
    Heroes.ResourceTree.AddItem(result);
  end; // .if

  // * * * * * //
  FreeAndNil(Bmp);
end; // .function LoadImageAsPcx16

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
var
  pic: PPcx16Item;

begin
  (* testing *)
  pic := LoadImageAsPcx16('D:\Leonid Afremov. Zima.png', 'zpic1005.pcx', 800, 600);
end;

begin
  if false (* testing *) then begin
    EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
  end;
end.