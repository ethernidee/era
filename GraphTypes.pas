unit GraphTypes;
(*
  Common types and constants for graphics units.
*)


(***)  interface  (***)

uses
  SysUtils, Utils;


const
  BMP_24_COLOR_DEPTH = 24;

  (* RGBA masks *)
  ALPHA_CHANNEL_MASK_32        = integer($FF000000);
  RED_BLUE_CHANNELS_MASK_32    = $00FF00FF;
  GREEN_CHANNEL_MASK_32        = $0000FF00;
  ALPHA_GREEN_CHANNELS_MASK_32 = integer(ALPHA_CHANNEL_MASK_32 or GREEN_CHANNEL_MASK_32);
  FULLY_OPAQUE_MASK32          = integer($FF000000);

  (* RGB masks *)
  RGB_MASK_32 = $00FFFFFF;

  (* Limits *)
  MAX_IMAGE_WIDTH  = 10000;
  MAX_IMAGE_HEIGHT = 10000;

type
  PColor24 = ^TColor24;
  TColor24 = packed record
    Blue:  byte;
    Green: byte;
    Red:   byte;
  end;

  PColor24Arr = ^TColor24Arr;
  TColor24Arr = array [0..high(integer) div sizeof(TColor24) - 1] of TColor24;

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

  PColor32Arr = ^TColor32Arr;
  TColor32Arr = array [0..high(integer) div sizeof(TColor32) - 1] of TColor32;

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

  TRawImage32 = class
   protected
    fSize:         TImageSize;
    fScanlineSize: integer;
    fPixels:       TArrayOfColor32;

   public
    constructor Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer);

    property Size:         TImageSize read fSize;
    property ScanlineSize: integer read fScanlineSize;
    property Pixels:       TArrayOfColor32 read fPixels;
  end;


(***)  implementation  (***)


constructor TRawImage32.Create (Pixels: TArrayOfColor32; Width, Height, ScanlineSize: integer);
begin
  {!} Assert(Pixels <> nil);
  {!} Assert(Width > 0);
  {!} Assert(Height > 0);
  {!} Assert(ScanlineSize >= Width * sizeof(TColor32));

  Self.fPixels       := Pixels;
  Self.fSize.Width   := Width;
  Self.fSize.Height  := Height;
  Self.fScanlineSize := ScanlineSize;
end;

end.