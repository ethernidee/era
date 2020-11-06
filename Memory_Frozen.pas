unit Memory;
(*
  Description: Memory management.
  Author:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
  DEVELOPMENT IS FROZEN
*)


(***)  interface  (***)

uses
  SysUtils, Math,
  Utils, DataLib;

const
  IS_STATIC  = true;
  IS_DYNAMIC = not IS_STATIC;

type
  (* Import *)
  TList = DataLib.TList;

  TBuffer = class
  {OU} Addr:     Utils.PEndlessByteArr;
       Size:     integer;
       IsStatic: boolean;

    constructor Create (Size: integer; Addr: pointer; IsStatic: boolean);
  end;

  (* Simple contiguous memory manager *)
  TContiguousMemManager = class
   protected const
    NUM_BLOCKS_PER_SYS_ALLOCATION = 30;

   protected
    {O}  fBufs:                     TList {of TBuffer};
    {Un} fBuf:                      Utils.PEndlessByteArr;
         fBufSize:                  integer;
         fBufPos:                   integer;
         fBufInd:                   integer;
         fGuaranteedContiguousSize: integer;

    (* Makes next available buffer active at position 0. Updates cached buffer variables. Returns true on success *)
    function SwitchToNextBuf: boolean;

   public
    constructor Create (GuaranteedContiguousSize: integer);
    destructor Destroy; override;
    
    (* Allocates new block of memory, not dependent on the previous one *)
    function AllocNew (Size: integer): pointer;

    (* Allocates block of memory right after the previous one *)
    function AllocContinue (Size: integer): pointer;

    (* Adds static buffer to memory buffers pool, if buffer has sufficient size. An exception is raised
       if any allocation was performed before calling this method *)
    function AddStaticBuf (Size: integer; {n} Buf: pointer): TContiguousMemManager;

    (* Releases all allocated memory, fills static buffers with zeroes *)
    function Release: TContiguousMemManager;
  end;



(***)  implementation  (***)


constructor TBuffer.Create (Size: integer; Addr: pointer; IsStatic: boolean);
begin
  {!} Assert(Size > 0);
  {!} Assert(Addr <> nil);
  Self.Size     := Size;
  Self.Addr     := Addr;
  Self.IsStatic := IsStatic;
end;

constructor TContiguousMemManager.Create (GuaranteedContiguousSize: integer);
begin
  {!} Assert(GuaranteedContiguousSize > 0);
  inherited Create;
  Self.fGuaranteedContiguousSize := GuaranteedContiguousSize;
  Self.fBufs                     := DataLib.NewList(Utils.OWNS_ITEMS);
end;

destructor TContiguousMemManager.Destroy; override;
begin
  SysUtils.FreeAndNil(Self.fBufs);
  inherited Destroy;
end;

function TContiguousMemManager.AllocNew (Size: integer): pointer;
var
{On} AllocatedBuf:     pointer;
     AllocatedBufSize: integer;
     ReservedSize:     integer;

begin
  {!} Assert(Size > 0);
  result       := nil;
  AllocatedBuf := nil;
  // * * * * * //
  ReservedSize := Math.Max(Self.fGuaranteedContiguousSize, Size);

  while (Self.fBufPos + ReservedSize > Self.fBufSize) and Self.SwitchToNextBuf do begin
    // Next
  end;

  if Self.fBufPos + ReservedSize > Self.fBufSize then begin
    AllocatedBufSize := Math.Max(Self.fGuaranteedContiguousSize * Self.NUM_BLOCKS_PER_SYS_ALLOCATION, Size);
    System.GetMem(AllocatedBuf, AllocatedBufSize);
    Self.fBufs.Add(TBuffer.Create(AllocatedBufSize, AllocatedBuf, IS_DYNAMIC));
    Self.SwitchToNextBuf;
  end;
  
  result := @Self.fBuf[Self.fBufPos];
  Inc(Self.fBufPos, Size);
end; // .function TContiguousMemManager.AllocNew

function TContiguousMemManager.AllocContinue (Size: integer): pointer;
begin
  {!} Assert(Size > 0, 'Cannot continue allocating block of size 0');

  if Self.fBuf = nil then begin
    result := Self.AllocNew(Size);
  end else begin
    Inc(Self.fBufPos, Size);
    result := @Self.fBuf[Self.fBufPos];
    {!} Assert(Self.fBufPos <= Self.fBufSize, Format('Cannot continue allocating contiguous block of memory. Requested: %d bytes. Buffer of size %d is exhausted', [Size, Self.fBufSize]));
  end;
end;

function TContiguousMemManager.AddStaticBuf (Size: integer; {n} Buf: pointer): TContiguousMemManager;
begin
  {!} Assert(Utils.IsValidBuf(Buf, Size));
  {!} Assert(Self.fBuf = nil, 'Cannot add static buffer to pool. Allocations were already performed');

  if Buf <> nil then begin
    Self.fBufs.Add(TBuffer.Create(Size, Buf, IS_STATIC));
  end;

  result := Self;
end;

function TContiguousMemManager.Release: TContiguousMemManager;
var
  i: integer;

begin
  for i := 0 to Self.fBufs.Count - 1 do begin
    if not TBuffer(Self.fBufs[i]).IsStatic then begin
      System.FreeMem(TBuffer(Self.fBufs[i]).Addr);
      Self.fBufs[i] := nil;
    end;
  end;

  Self.fBufs.Pack;

  for i := 0 to Self.fBufs.Count - 1 do begin
    FillChar(TBuffer(Self.fBufs[i]).Addr^, TBuffer(Self.fBufs[i]).Size, 0);
  end;

  Self.fBuf     := nil;
  Self.fBufSize := 0;
  Self.fBufPos  := 0;
  Self.fBufInd  := -1;

  result := Self;
end; // .function TContiguousMemManager.Release

function TContiguousMemManager.SwitchToNextBuf: boolean;
var
{Un} Buf: TBuffer;

begin
  Buf := nil;
  // * * * * * //
  result := Self.fBufInd + 1 < Self.fBufs.Count;

  if result then begin
    Inc(Self.fBufInd);
    Buf           := TBuffer(Self.fBufs[Self.fBufInd]);
    Self.fBuf     := Buf.Addr;
    Self.fBufPos  := 0;
    Self.fBufSize := Buf.Size;
  end;
end; // .function TContiguousMemManager.SwitchToNextBuf

end.