unit Libspng;
(*
  Libspng 0.6.2+ library wrapper.
  @see https://libspng.org/
*)


(***)  interface  (***)

uses
  SysUtils,

  GraphTypes,
  DlgMes,
  Utils;


(* Decodes already loaded png file into Color32 image with alpha. Fails on invalid/malformed or huge image. *)
function DecodePng (PngBuf: pointer; PngBufSize: integer; MaxWidth: integer = GraphTypes.MAX_IMAGE_WIDTH; MaxHeight: integer = GraphTypes.MAX_IMAGE_HEIGHT): {On} GraphTypes.TRawImage32;


(***)  implementation  (***)


const
  LIB_SPNG   = 'libspng.dll';

  NO_ERROR   = 0;
  SOME_ERROR = 1;

  NO_FLAGS = 0;

  SPNG_FMT_RGBA8   = 1;
  SPNG_DECODE_TRNS = 1;

  SPNG_COLOR_TYPE_GRAYSCALE       = 0;
  SPNG_COLOR_TYPE_TRUECOLOR       = 2;
  SPNG_COLOR_TYPE_INDEXED         = 3;
  SPNG_COLOR_TYPE_GRAYSCALE_ALPHA = 4;
  SPNG_COLOR_TYPE_TRUECOLOR_ALPHA = 6;

type
  TPngContext = pointer;

type
  TPngHeader = packed record
    Width:             integer;
    Height:            integer;
    BitDepth:          byte;
    ColorType:         byte;
    CompressionMethod: byte;
    FilterMethod:      byte;
    InterlaceMethod:   byte;
    _Align1:           array [1..3] of byte;
  end;

  TPngTransparency = packed record
    Gray:              word;
    Red:               word;
    Green:             word;
    Blue:              word;
    NumPaletteEntries: integer;
    PaletteAlphas:     array [0..255] of byte;
  end;

  PMemoryHandlers = ^TMemoryHandlers;
  TMemoryHandlers = packed record
    Alloc:      function (Size: integer): pointer; cdecl;
    Realloc:    function (Buf: pointer; NewSize: integer): pointer; cdecl;
    AllocItems: function (NumItems, ItemSize: integer): pointer; cdecl;
    Free:       procedure (Buf: pointer); cdecl;
  end;

function spng_ctx_new (Flags: integer): TPngContext; cdecl external LIB_SPNG;
function spng_ctx_new2 (MemoryHandlers: PMemoryHandlers; Flags: integer): TPngContext; cdecl external LIB_SPNG;
function spng_set_png_buffer (Context: TPngContext; Buf: pointer; Size: integer): integer; cdecl external LIB_SPNG;
function spng_set_image_limits (Context: TPngContext; MaxWidth, MaxHeight: integer): integer; cdecl external LIB_SPNG;
function spng_get_ihdr (Context: TPngContext; var Header: TPngHeader): integer; cdecl external LIB_SPNG;
function spng_get_trns (Context: TPngContext; var Transparency: TPngTransparency): integer; cdecl external LIB_SPNG;
function spng_decoded_image_size (Context: TPngContext; Format: integer; out ImageSize: integer): integer; cdecl external LIB_SPNG;
function spng_decode_image (Context: TPngContext; OutBuf: pointer; BufSize: integer; Format: integer; Flags: integer): integer; cdecl external LIB_SPNG;
procedure spng_ctx_free (Context: TPngContext); cdecl external LIB_SPNG;

function Bridge_Alloc (Size: integer): pointer; cdecl;
begin
  GetMem(result, Size);
end;

function Bridge_Realloc (Buf: pointer; NewSize: integer): pointer; cdecl;
begin
  ReallocMem(Buf, NewSize);
  result := Buf;
end;

function Bridge_AllocItems (NumItems, ItemSize: integer): pointer; cdecl;
var
  BufSize: integer;

begin
  BufSize := NumItems * ItemSize;
  GetMem(result, BufSize);
  System.FillChar(result^, BufSize, #0);
end;

procedure Bridge_Free (Buf: pointer); cdecl;
begin
  FreeMem(Buf);
end;

procedure InitMemoryHandlers (var MemoryHandlers: TMemoryHandlers);
begin
  with MemoryHandlers do begin
    Alloc      := Bridge_Alloc;
    Realloc    := Bridge_Realloc;
    AllocItems := Bridge_AllocItems;
    Free       := Bridge_Free;
  end;
end;

function DecodePng (PngBuf: pointer; PngBufSize: integer; MaxWidth: integer = GraphTypes.MAX_IMAGE_WIDTH; MaxHeight: integer = GraphTypes.MAX_IMAGE_HEIGHT): {On} GraphTypes.TRawImage32;
var
  LastResult:      integer;
  MemoryHandlers:  TMemoryHandlers;
  PngContext:      TPngContext;
  PngHeader:       TPngHeader;
  PngTransparency: TPngTransparency;
  ImageSize:       integer;
  Pixels:          GraphTypes.TArrayOfColor32;
  RawImage32Setup: GraphTypes.TRawImage32Setup;

begin
  {!} Assert(PngBuf <> nil);
  {!} Assert(PngBufSize > 0);
  {!} Assert(MaxWidth > 0);
  {!} Assert(MaxHeight > 0);

  result     := nil;
  LastResult := NO_ERROR;
  PngContext := nil;
  // * * * * * //
  RawImage32Setup.Init;
  RawImage32Setup.HasTransparency := false;

  InitMemoryHandlers(MemoryHandlers);
  PngContext := spng_ctx_new2(@MemoryHandlers, NO_FLAGS);

  if PngContext = nil then begin
    LastResult := SOME_ERROR;
  end;

  if LastResult = NO_ERROR then begin
    LastResult := spng_set_png_buffer(PngContext, PngBuf, PngBufSize);
  end;

  if LastResult = NO_ERROR then begin
    LastResult := spng_set_image_limits(PngContext, MaxWidth, MaxHeight);
  end;

  if LastResult = NO_ERROR then begin
    LastResult := spng_get_ihdr(PngContext, PngHeader);
  end;

  if LastResult = NO_ERROR then begin
    if (PngHeader.ColorType in [SPNG_COLOR_TYPE_GRAYSCALE_ALPHA, SPNG_COLOR_TYPE_TRUECOLOR_ALPHA]) or (spng_get_trns(PngContext, PngTransparency) = 0) then begin
      RawImage32Setup.HasTransparency := true;
    end;

    LastResult := spng_decoded_image_size(PngContext, 1, ImageSize);
  end;

  if LastResult = NO_ERROR then begin
    SetLength(Pixels, ImageSize div sizeof(Pixels[0]));

    if RawImage32Setup.HasTransparency then begin
      LastResult := spng_decode_image(PngContext, @Pixels[0], ImageSize, SPNG_FMT_RGBA8, SPNG_DECODE_TRNS);
    end else begin
      LastResult := spng_decode_image(PngContext, @Pixels[0], ImageSize, SPNG_FMT_RGBA8, NO_FLAGS);
    end;
  end;

  if LastResult = NO_ERROR then begin
    GraphTypes.RgbaToBgraPixels(Pixels);
    result := GraphTypes.TRawImage32.Create(Pixels, PngHeader.Width, PngHeader.Height, ImageSize div PngHeader.Height, RawImage32Setup);
  end;

  if PngContext <> nil then begin
    spng_ctx_free(PngContext);
  end;
end;

end.