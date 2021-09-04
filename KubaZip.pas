unit KubaZip;
(*
  Kuba Podgórski Zip 0.2+ library wrapper.
  @see https://github.com/kuba--/zip
*)


(***)  interface  (***)

uses
  SysUtils,

  DlgMes,
  Utils;


const
  LIB_KUBAZIP = 'kubazip.dll';

  ZIP_NO_ERROR    = 0;
  ZIP_ENOINIT     = -1;  // not initialized
  ZIP_EINVENTNAME = -2;  // invalid entry name
  ZIP_ENOENT      = -3;  // entry not found
  ZIP_EINVMODE    = -4;  // invalid zip mode
  ZIP_EINVLVL     = -5;  // invalid compression level
  ZIP_ENOSUP64    = -6;  // no zip 64 support
  ZIP_EMEMSET     = -7;  // memset error
  ZIP_EWRTENT     = -8;  // cannot write data to entry
  ZIP_ETDEFLINIT  = -9;  // cannot initialize tdefl compressor
  ZIP_EINVIDX     = -10; // invalid index
  ZIP_ENOHDR      = -11; // header not found
  ZIP_ETDEFLBUF   = -12; // cannot flush tdefl buffer
  ZIP_ECRTHDR     = -13; // cannot create entry header
  ZIP_EWRTHDR     = -14; // cannot write entry header
  ZIP_EWRTDIR     = -15; // cannot write to central dir
  ZIP_EOPNFILE    = -16; // cannot open file
  ZIP_EINVENTTYPE = -17; // invalid entry type
  ZIP_EMEMNOALLOC = -18; // extracting data using no memory allocation
  ZIP_ENOFILE     = -19; // file not found
  ZIP_ENOPERM     = -20; // no permission
  ZIP_EOOMEM      = -21; // out of memory
  ZIP_EINVZIPNAME = -22; // invalid zip archive name
  ZIP_EMKDIR      = -23; // make dir error
  ZIP_ESYMLINK    = -24; // symlink error
  ZIP_ECLSZIP     = -25; // close archive error
  ZIP_ECAPSIZE    = -26; // capacity size too small
  ZIP_EFSEEK      = -27; // fseek error
  ZIP_EFREAD      = -28; // fread error
  ZIP_EFWRITE     = -29; // fwrite error

type
  PZipStruct = ^TZipStruct;
  TZipStruct = record end;

  TExtractChunkHandler        = function (arg: pointer; offset: Int64; data: pointer; size: integer): integer;
  TOnAfterEntryExtractHandler = function (filename: pchar; arg: pointer): integer;


function zip_strerror (errnum: integer): pchar; cdecl external LIB_KUBAZIP;
function zip_open (zipname: pchar; level: integer; mode: char): PZipStruct; cdecl external LIB_KUBAZIP;
procedure zip_close (zip: PZipStruct); cdecl external LIB_KUBAZIP;
function zip_is64 (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entry_open (zip: PZipStruct; entryname: pchar): integer; cdecl external LIB_KUBAZIP;
function zip_entry_openbyindex (zip: PZipStruct; index: integer): integer; cdecl external LIB_KUBAZIP;
function zip_entry_close (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entry_name (zip: PZipStruct): pchar; cdecl external LIB_KUBAZIP;
function zip_entry_index (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entry_isdir (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entry_size (zip: PZipStruct): Int64; cdecl external LIB_KUBAZIP;
function zip_entry_crc32 (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entry_write (zip: PZipStruct; buf: pointer; bufsize: integer): integer; cdecl external LIB_KUBAZIP;
function zip_entry_fwrite (zip: PZipStruct; filename: pchar): integer; cdecl external LIB_KUBAZIP;
function zip_entry_read (zip: PZipStruct; var buf: pointer; var bufsize: integer): integer; cdecl external LIB_KUBAZIP;
function zip_entry_noallocread (zip: PZipStruct; buf: pointer; bufsize: integer): integer; cdecl external LIB_KUBAZIP;
function zip_entry_fread (zip: PZipStruct; filename: pchar): integer; cdecl external LIB_KUBAZIP;
function zip_entry_extract (zip: PZipStruct; extractChunkHandler: TExtractChunkHandler): integer; cdecl external LIB_KUBAZIP;
function zip_entries_total (zip: PZipStruct): integer; cdecl external LIB_KUBAZIP;
function zip_entries_delete (zip: PZipStruct; filenames: Utils.PEndlessPCharArr; len: integer): integer; cdecl external LIB_KUBAZIP;
function zip_stream_extract (stream: pchar; size: integer; dir: pchar; onAfterEntryExtract: TOnAfterEntryExtractHandler; arg: pointer): integer; cdecl external LIB_KUBAZIP;
function zip_stream_open (stream: pchar; size: integer; level: integer; mode: byte): PZipStruct; cdecl external LIB_KUBAZIP;
function zip_stream_copy (zip: PZipStruct; var buf: pointer; var bufsize: integer): integer; cdecl external LIB_KUBAZIP;
procedure zip_stream_close (zip: PZipStruct); cdecl external LIB_KUBAZIP;
function zip_create (zipname: pchar; filenames: Utils.PEndlessPCharArr; len: integer): integer; cdecl external LIB_KUBAZIP;
function zip_extract (zipname: pchar; dir: pchar; onAfterEntryExtract: TOnAfterEntryExtractHandler; arg: pointer): integer; cdecl external LIB_KUBAZIP;
procedure zip_free_buf (buf: pointer); cdecl external LIB_KUBAZIP;


(***)  implementation  (***)

end.