unit Network;
(*
  New network functins, events and fixes.
  Single-thread only, packet buffer is reused.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,

  PngImage,

  ApiJack,
  Core,
  DataLib,
  DlgMes,
  EventMan,
  Files,
  GameExt,
  Heroes,
  PatchApi,
  StrLib,
  WinUtils,
  ZlibUtils,
  Utils;


const
  DEST_ALL_PLAYERS = -1;


type
  (* Import *)
  TStrBuilder = StrLib.TStrBuilder;
  TObjDict    = DataLib.TObjDict;
  TList       = DataLib.TList;

  TNetworkStreamProgressHandler = function (BytesSent, TotalBytes: integer; {n} CustomParam: pointer): Heroes.TInt32Bool; stdcall;



(* Returns true if at least an attempt to call remote event was done. False for invalid event name *)
function FireRemoteEvent (DestPlayerId: integer; const EventName: string; {n} Data: pointer = nil; DataSize: integer = 0;
                          {n} ProgressHandler: TNetworkStreamProgressHandler = nil; {n} ProgressHandlerCustomParam: pointer = nil): boolean;


(***)  implementation  (***)


const
  NETWORK_MSG_ERA_EVENT_STREAM_START = 453470715;
  NETWORK_MSG_ERA_EVENT_STREAM_CHUNK = 453470716;
  NETWORK_MSG_WOG                    = 2000;

  MAX_NETWORK_EVENT_NAME_LEN       = 1000;
  MAX_PACKET_SIZE                  = 64000;
  PACKET_CHUNK_TIMEOUT_SEC         = 15;
  MIN_PAYLOAD_SIZE_FOR_COMPRESSION = 24;
  MIN_COMPRESSION_RATIO            = 0.9;


type
  TStreamStartPacketDebug = packed record
    StreamId:     integer;
    EventNameLen: integer;
    EventName:    Utils.TEmptyRec; // array EventNameLen of char
    UnpackedSize: integer;         // Size of unpacked data if data is compressed or negative value
    TotalSize:    integer;         // Total size of payload to send/receive
    PayloadSize:  integer;
    Payload:      Utils.TEmptyRec; // array PayloadSize of byte
  end;

  TStreamChunkPacketDebug = packed record
    StreamId:    integer;
    PayloadSize: integer; // array PayloadSize of byte
  end;

  TIncomingStream = class
  {O} Data:             TStrBuilder;
      TotalSize:        integer;
      UncompressedSize: integer;
      EventName:        string;
      UpdateTime:       integer;

    constructor Create (const EventName: string; TotalSize, UncompressedSize: integer);
    destructor Destroy; override;
    function WriteData ({n} Buf: pointer; BufSize: integer): boolean;
    function IsStale (CurrTimestamp: integer): boolean;
    function IsCompressed: boolean;
  end;

  TSingleSenderStreams = {O} TObjDict {of StreamId => TIncomingStream};


var
{O} PacketBuf:       {O} Files.TFixedBuf; // Output packet fixed memory builder
{O} PacketReader:    {U} Files.TFixedBuf; // Incoming packet reader
{O} IncomingStreams: {O} TObjDict {of SenderPlayerId => TSingleSenderStreams}; // Double level map of all incoming streams with garbage collection support

  // Autoincrement field, used as unique identifier for output network stream/event.
  OutStreamAutoId: integer = 0;


function IsValidNetworkEventName (const EventName: string): boolean;
begin
  result := (EventName <> '') and (Length(EventName) <= MAX_NETWORK_EVENT_NAME_LEN);
end;

function GenerateStreamId: integer;
begin
  Inc(OutStreamAutoId);
  result := OutStreamAutoId;
end;

constructor TIncomingStream.Create (const EventName: string; TotalSize, UncompressedSize: integer);
begin
  Self.Data             := TStrBuilder.Create;
  Self.TotalSize        := TotalSize;
  Self.UncompressedSize := UncompressedSize;
  Self.EventName        := EventName;
  Self.UpdateTime       := WinUtils.GetUnixTime;
end;

destructor TIncomingStream.Destroy;
begin
  SysUtils.FreeAndNil(Self.Data);
end;

function TIncomingStream.WriteData ({n} Buf: pointer; BufSize: integer): boolean;
begin
  {!} Assert(Utils.IsValidBuf(Buf, BufSize));
  result := Self.Data.Size + BufSize <= Self.TotalSize;

  if result then begin
    Self.Data.AppendBuf(BufSize, Buf);
  end;
end;

function TIncomingStream.IsStale (CurrTimestamp: integer): boolean;
begin
  result := CurrTimestamp - Self.UpdateTime >= PACKET_CHUNK_TIMEOUT_SEC;
end;

function TIncomingStream.IsCompressed: boolean;
begin
  result := Self.UncompressedSize >= 0;
end;

function FindIncomingStream (SenderPlayerId, StreamId: integer): {Un} TIncomingStream;
var
{Un} SenderStreams: TSingleSenderStreams;

begin
  result        := nil;
  SenderStreams := IncomingStreams[Ptr(SenderPlayerId)];

  if SenderStreams <> nil then begin
    result := SenderStreams[Ptr(StreamId)];
  end;
end;

procedure DestroyIncomingStream (SenderPlayerId, StreamId: integer);
var
{Un} SenderStreams: TSingleSenderStreams;
{Un} Stream:        TIncomingStream;

begin
  Stream        := nil;
  SenderStreams := IncomingStreams[Ptr(SenderPlayerId)];

  if SenderStreams <> nil then begin
    Stream := SenderStreams[Ptr(StreamId)];

    if Stream <> nil then begin
      SenderStreams.DeleteItem(Ptr(StreamId));
    end;
  end;
end;

function CreateIncomingStream (SenderPlayerId, StreamId: integer; const EventName: string; TotalSize, UncompressedSize: integer): {U} TIncomingStream;
var
{Un} SenderStreams: TSingleSenderStreams;

begin
  result        := nil;
  SenderStreams := IncomingStreams[Ptr(SenderPlayerId)];

  if SenderStreams = nil then begin
    SenderStreams                        := DataLib.NewObjDict(Utils.OWNS_ITEMS);
    IncomingStreams[Ptr(SenderPlayerId)] := SenderStreams;
  end;

  {!} Assert(SenderStreams[Ptr(StreamId)] = nil, 'Cannot create incoming stream. It''s already present');
  result := TIncomingStream.Create(EventName, TotalSize, UncompressedSize);
  SenderStreams[Ptr(StreamId)] := result;
end;

procedure GcIncomingStreams;
var
{O}  StaleStreams:  {U} TList { of StreamId};
{Un} SenderStreams: TSingleSenderStreams;
     GcTimestamp:   integer;
     i:             integer;

begin
  StaleStreams := DataLib.NewList(not Utils.OWNS_ITEMS);
  // * * * * * //
  GcTimestamp := WinUtils.GetUnixTime;

  with DataLib.IterateObjDict(IncomingStreams) do begin
    while IterNext do begin
      StaleStreams.Clear;
      SenderStreams := TObjDict(IterValue);

      with DataLib.IterateObjDict(SenderStreams) do begin
        while IterNext do begin
          if TIncomingStream(IterValue).IsStale(GcTimestamp) then begin
            StaleStreams.Add(IterKey);
          end;
        end;
      end;

      for i := 0 to StaleStreams.Count - 1 do begin
        SenderStreams.DeleteItem(StaleStreams[i]);
      end;
    end;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(StaleStreams);
end;

function FireRemoteEvent (DestPlayerId: integer; const EventName: string; {n} Data: pointer; DataSize: integer; {n} ProgressHandler: TNetworkStreamProgressHandler;
                          {n} ProgressHandlerCustomParam: pointer): boolean;
var
  StreamId:          integer;
  SizeWritten:       integer;
  CompressedPayload: Utils.TArrayOfByte;
  PayloadBuf:        pointer;
  PayloadBufSize:    integer;
  UncompressedSize:  integer;
  PacketPayloadSize: integer;
  Temp:              integer;

begin
  result := IsValidNetworkEventName(EventName);

  if not result then begin
    exit;
  end;

  PayloadBuf       := Data;
  PayloadBufSize   := DataSize;
  UncompressedSize := -1;

  if DataSize >= MIN_PAYLOAD_SIZE_FOR_COMPRESSION then begin
    CompressedPayload := ZlibUtils.Compress(Data, DataSize);

    if Length(CompressedPayload) / DataSize <= MIN_COMPRESSION_RATIO then begin
      PayloadBuf        := pointer(CompressedPayload);
      PayloadBufSize    := Length(CompressedPayload);
      UncompressedSize  := DataSize;
    end;
  end;

  StreamId    := GenerateStreamId;
  SizeWritten := 0;

  PacketBuf.Seek(0);
  PacketBuf.WriteInt(StreamId);
  PacketBuf.WriteInt(Length(EventName));
  PacketBuf.WriteStr(EventName);

  PacketBuf.WriteInt(PayloadBufSize);
  PacketBuf.WriteInt(UncompressedSize);
  PacketPayloadSize := Math.Min(PacketBuf.Size - PacketBuf.Pos - sizeof(PacketPayloadSize), PayloadBufSize);
  PacketBuf.WriteInt(PacketPayloadSize);

  PacketBuf.WriteUpTo(PacketPayloadSize, PayloadBuf, Temp);
  Inc(integer(PayloadBuf), PacketPayloadSize);

  Inc(SizeWritten, PacketPayloadSize);
  Heroes.SendNetData(DestPlayerId, NETWORK_MSG_ERA_EVENT_STREAM_START, PacketBuf.Buf, PacketBuf.Pos);

  while SizeWritten < PayloadBufSize do begin
    if @ProgressHandler <> nil then begin
      if ProgressHandler(SizeWritten, PayloadBufSize, ProgressHandlerCustomParam) = 0 then begin
        exit;
      end;
    end;

    PacketBuf.Seek(0);
    PacketBuf.WriteInt(StreamId);
    PacketPayloadSize := Math.Min(PacketBuf.Size - PacketBuf.Pos - sizeof(PacketPayloadSize), PayloadBufSize - SizeWritten);
    PacketBuf.WriteInt(PacketPayloadSize);

    PacketBuf.WriteUpTo(PacketPayloadSize, PayloadBuf, Temp);
    Inc(integer(PayloadBuf), PacketPayloadSize);

    Inc(SizeWritten, PacketPayloadSize);
    Heroes.SendNetData(DestPlayerId, NETWORK_MSG_ERA_EVENT_STREAM_CHUNK, PacketBuf.Buf, PacketBuf.Pos);
  end;
end; // .function FireRemoteEvent

function ProcessNetworkData (NetData: Heroes.PNetData): boolean;
var
{Un} Stream:           TIncomingStream;
     StreamId:         integer;
     EventNameLen:     integer;
     EventName:        string;
     TotalSize:        integer;
     UncompressedSize: integer;
     PayloadSize:      integer;
     EventData:        Utils.TArrayOfByte;

begin
  result := true;

  if NetData.MsgId = NETWORK_MSG_ERA_EVENT_STREAM_START then begin
    GcIncomingStreams;
    PacketReader.Open(@NetData.RawData, NetData.StructSize - sizeof(NetData^), Files.MODE_READ);
    PacketReader.ReadInt(StreamId);
    PacketReader.ReadInt(EventNameLen);
    PacketReader.ReadStr(EventNameLen, EventName);
    PacketReader.ReadInt(TotalSize);
    PacketReader.ReadInt(UncompressedSize);
    PacketReader.ReadInt(PayloadSize);
    {!} Assert(PayloadSize <= TotalSize, SysUtils.Format('Invalid PayloadSize field for incoming stream. It cannot be greater than TotalSize. Given: %d/%d', [PayloadSize, TotalSize]));
    DestroyIncomingStream(NetData.PlayerId, StreamId);

    if PayloadSize = TotalSize then begin
      if UncompressedSize >= 0 then begin
        EventData := ZlibUtils.Decompress(Utils.PtrOfs(PacketReader.Buf, PacketReader.Pos), PayloadSize);
        EventMan.GetInstance.Fire(EventName, pointer(EventData), Length(EventData));
      end else begin
        EventMan.GetInstance.Fire(EventName, Utils.PtrOfs(PacketReader.Buf, PacketReader.Pos), PayloadSize);
      end;
    end else begin
      Stream := CreateIncomingStream(NetData.PlayerId, StreamId, EventName, TotalSize, UncompressedSize);
      Stream.WriteData(Utils.PtrOfs(PacketReader.Buf, PacketReader.Pos), PayloadSize);
    end;
  end else if NetData.MsgId = NETWORK_MSG_ERA_EVENT_STREAM_CHUNK then begin
    GcIncomingStreams;
    PacketReader.Open(@NetData.RawData, NetData.StructSize - sizeof(NetData^), Files.MODE_READ);
    PacketReader.ReadInt(StreamId);
    PacketReader.ReadInt(PayloadSize);
    Stream := FindIncomingStream(NetData.PlayerId, StreamId);

    if Stream <> nil then begin
      {!} Assert(Stream.Data.Size + PayloadSize <= Stream.TotalSize, SysUtils.Format('Invalid PayloadSize field for incoming stream chunk. TotalSize is overflowed. Given: %d/%d', [Stream.Data.Size + PayloadSize, Stream.TotalSize]));
      Stream.WriteData(Utils.PtrOfs(PacketReader.Buf, PacketReader.Pos), PayloadSize);

      if Stream.Data.Size = Stream.TotalSize then begin
        EventName := Stream.EventName;
        EventData := Stream.Data.BuildBuf;

        if Stream.IsCompressed then begin
          EventData := ZlibUtils.Decompress(pointer(EventData), Length(EventData));
        end;

        DestroyIncomingStream(NetData.PlayerId, StreamId);
        EventMan.GetInstance.Fire(EventName, pointer(EventData), Length(EventData));
      end;
    end;
  end else if NetData.MsgId = NETWORK_MSG_WOG then begin
    result := false;
  end; // .else
end; // .function ProcessNetworkData

function Hook_NetworkProcessOtherData (OrigFunc: pointer; AdvMan: Heroes.PAdvManager; NetData: Heroes.PNetData): integer; stdcall;
const
  WOG_FUNC_RECEIVER_NET_AM_COMMAND = $768841;

begin
  if not ProcessNetworkData(NetData) and (NetData.MsgId = NETWORK_MSG_WOG) then begin
    PatchApi.Call(THISCALL_, Ptr(WOG_FUNC_RECEIVER_NET_AM_COMMAND), [NetData]);
  end;

  result := PatchApi.Call(THISCALL_, OrigFunc, [AdvMan, NetData]);
end;

function Hook_NetworkProcessBattleData (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  ProcessNetworkData(ppointer($2860290)^);

  result := true;
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  (* Fix HD-bug: IP/FU:D functionality was fully disabled due to patch at 557E01.
     The fix is to remove WoG hook for ReceiveNetAMCommand handler and call it manually in NetworkProcessOtherData splice.
     Additionally new FU:D implementation allows to transfer strings and always compresses the data *)
  // Splice NetworkProcessOtherData
  ApiJack.StdSplice(Ptr($557CC0), @Hook_NetworkProcessOtherData, ApiJack.CONV_THISCALL, 2);
  ApiJack.HookCode(Ptr($768809), @Hook_NetworkProcessBattleData);

  // Remove WoG hook for ReceiveNetAMCommand
  Core.p.WriteDataPatch(Ptr($557E07), ['E5320B00']);

  // WoG Hook must not free net data memory anymore. Leave it to original function/HD mod. Additionally convert its convention to thiscall.
  Core.p.WriteDataPatch(Ptr($76884B), ['0D']);
  Core.p.WriteDataPatch(Ptr($7688F6), ['90909090909090909090909090909090']);
end;

begin
  PacketBuf := Files.TFixedBuf.Create;
  PacketBuf.CreateNew(MAX_PACKET_SIZE);
  PacketReader    := Files.TFixedBuf.Create;
  IncomingStreams := DataLib.NewObjDict(Utils.OWNS_ITEMS);

  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.