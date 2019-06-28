unit Heroes;
{
DESCRIPTION:  Internal game functions and structures
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Windows, SysUtils, Utils, PatchApi, DataLib, TypeWrappers, Alg, Core;

type
  (* Import *)
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

  PGameType = ^TGameType;
  TGameType = (GAMETYPE_SINGLE, GAMETYPE_IPX, GAMETYPE_TCP, GAMETYPE_HOTSEAT, GAMETYPE_DIRECT_CONNECT, GAMETYPE_MODEM);

const
  (* Graphics *)
  PCX16_COLOR_DEPTH     = 16;
  PCX24_COLOR_DEPTH     = 24;
  PCX16_BYTES_PER_COLOR = PCX16_COLOR_DEPTH div 8;
  PCX24_BYTES_PER_COLOR = PCX24_COLOR_DEPTH div 8;

  (* Resource types in resource tree *)
  RES_TYPE_PCX_8  = $10;
  RES_TYPE_PCX_24 = $11;
  RES_TYPE_PCX_16 = $12;

  (* Game settings *)
  GAME_SETTINGS_FILE    = 'heroes3.ini';
  GAME_SETTINGS_SECTION = 'Settings';
  
  (* Stacks on battlefield *)
  NUM_BATTLE_STACKS = 42;
  
  (*  BattleMon  *)
  STACK_STRUCT_SIZE = 1352;
  STACK_TYPE        = $34;
  STACK_POS         = $38;
  STACK_POS_SHIFT   = $44;
  STACK_NUM         = $4C;
  STACK_LOSTHP      = $58;
  STACK_FLAGS       = $84;
  STACK_HP          = $C0;
  STACK_SIDE        = $F4;

  (* Game version *)
  ROE         = 0;
  AB          = 1;
  SOD         = 2;
  SOD_AND_AB  = AB + SOD;

  (* Player colors *)
  PLAYER_NONE   = -1;
  PLAYER_FIRST  = 0;
  PLAYER_RED    = 0;
  PLAYER_BLUE   = 1;
  PLAYER_TAN    = 2;
  PLAYER_GREEN  = 3;
  PLAYER_ORANGE = 4;
  PLAYER_PURPLE = 5;
  PLAYER_TEAL   = 6;
  PLAYER_PINK   = 7;
  PLAYER_LAST   = 7;

  (* Secondary Skills *)
  MAX_SECONDARY_SKILLS = 28;
  SKILL_LEVEL_NONE     = 0;
  SKILL_LEVEL_BASIC    = 1;
  SKILL_LEVEL_ADVANCED = 2;
  SKILL_LEVEL_EXPERT   = 3;
  
  SHOW_INTRO_OPT:             pinteger  = Ptr($699410);
  MUSIC_VOLUME_OPT:           pinteger  = Ptr($6987B0);
  SOUND_VOLUME_OPT:           pinteger  = Ptr($6987B4);
  LAST_MUSIC_VOLUME_OPT:      pinteger  = Ptr($6987B8);
  LAST_SOUND_VOLUME_OPT:      pinteger  = Ptr($6987BC);
  WALK_SPEED_OPT:             pinteger  = Ptr($6987AC);
  COMP_WALK_SPEED_OPT:        pinteger  = Ptr($6987A8);
  SHOW_ROUTE_OPT:             pinteger  = Ptr($6987C4);
  MOVE_REMINDER_OPT:          pinteger  = Ptr($6987C8);
  QUICK_COMBAT_OPT:           pinteger  = Ptr($6987CC);
  VIDEO_SUBTITLES_OPT:        pinteger  = Ptr($6987D0);
  TOWN_OUTLINES_OPT:          pinteger  = Ptr($6987D4);
  ANIMATE_SPELLBOOK_OPT:      pinteger  = Ptr($6987D8);
  WINDOW_SCROLL_SPEED_OPT:    pinteger  = Ptr($6987DC);
  BLACKOUT_COMPUTER_OPT:      pinteger  = Ptr($6987E0);
  FIRST_TIME_OPT:             pinteger  = Ptr($699574);
  TEST_DECOMP_OPT:            pinteger  = Ptr($699578);
  TEST_READ_OPT:              pinteger  = Ptr($69957C);
  TEST_BLIT_OPT:              pinteger  = Ptr($699580);
  BINK_VIDEO_OPT:             pinteger  = Ptr($6987F8);
  UNIQUE_SYSTEM_ID_OPT:       pchar     = Ptr($698838);
  NETWORK_DEF_NAME_OPT:       pchar     = Ptr($698867);
  AUTOSAVE_OPT:               pinteger  = Ptr($6987C0);
  SHOW_COMBAT_GRID_OPT:       pinteger  = Ptr($69880C);
  SHOW_COMBAT_MOUSE_HEX_OPT:  pinteger  = Ptr($698810);
  COMBAT_SHADE_LEVEL_OPT:     pinteger  = Ptr($698814);
  COMBAT_ARMY_INFO_LEVEL_OPT: pinteger  = Ptr($698818);
  COMBAT_AUTO_CREATURES_OPT:  pinteger  = Ptr($6987E4);
  COMBAT_AUTO_SPELLS_OPT:     pinteger  = Ptr($6987E8);
  COMBAT_CATAPULT_OPT:        pinteger  = Ptr($6987EC);
  COMBAT_BALLISTA_OPT:        pinteger  = Ptr($6987F0);
  COMBAT_FIRST_AID_TENT_OPT:  pinteger  = Ptr($6987F4);
  COMBAT_SPEED_OPT:           pinteger  = Ptr($69883C);
  MAIN_GAME_SHOW_MENU_OPT:    pinteger  = Ptr($6987FC);
  MAIN_GAME_X_OPT:            pinteger  = Ptr($698800);
  MAIN_GAME_Y_OPT:            pinteger  = Ptr($698804);
  MAIN_GAME_FULL_SCREEN_OPT:  pinteger  = Ptr($698808);
  APP_PATH_OPT:               pchar     = Ptr($698614);
  CD_DRIVE_OPT:               pchar     = Ptr($698888);
  
  (* Dialog Ids *)
  ADVMAP_DLGID              = $402AE0;
  BATTLE_DLGID              = $4723E0;
  HERO_SCREEN_DLGID         = $4E1790;
  HERO_MEETING_SCREEN_DLGID = $5AE6E0;
  TOWN_SCREEN_DLGID         = $5C5CB0;

  LOAD_TXT_FUNC   = $55C2B0;  // F (Name: pchar); FASTCALL;
  UNLOAD_TXT_FUNC = $55D300;  // F (PTxtFile); FASTCALL;
  {
  F
  (
    Name:       PCHAR;
    AddExt:     LONGBOOL;
    ShowDialog: LONGBOOL;
    Compress:   INTBOOL;
    SaveToData: LONGBOOL
  ); THISCALL ([GAME_MANAGER]);
  }
  SAVEGAME_FUNC     = $4BEB60;
  LOAD_LOD          = $559420;  // F (Name: pchar); THISCALL (PLod);
  LOAD_LODS         = $559390;
  LOAD_DEF_SETTINGS = $50B420;  // F();
  SMACK_OPEN        = $63A464;  // F(FileName: pchar; BufSize, BufMask: int): HANDLE or 0; stdcall;
  BINK_OPEN         = $63A390;  // F(hFile, BufMask or $8000000: int): HANDLE or 0; stdcall;
  
  hWnd:           pinteger  = Ptr($699650);
  hHeroes3Event:  pinteger  = Ptr($69965C);
  MarkedSavegame: pchar     = Ptr($68338C);
  Mp3Name:        pchar     = Ptr($6A33F4);
  GameType:       PGameType = Ptr($698A40);
  GameVersion:    pinteger  = Ptr($67F554);
  
  (* Managers *)
  GAME_MANAGER     = $699538;
  HERO_WND_MANAGER = $6992D0;
  
  (* Colors *)
  RED_COLOR         = '0F2223E';
  HEROES_GOLD_COLOR = '0FFFE794';

type
  PValue  = ^TValue;
  TValue  = packed record
    case byte of
      0:  (v:   integer);
      1:  (p:   pointer);
      2:  (pc:  pchar);
  end; // .record TValue

  PTxtFile  = ^TTxtFile;
  TTxtFile  = packed record
    Dummy:    array [0..$17] of byte;
    RefCount: integer;
    (* Dummy *)
  end; // .record TTxtFile
  
  PLod  = ^TLod;
  TLod  = packed record
    Dummy:  array [0..399] of byte;
  end; // .record TLod
  
  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end; // .record TGameState

  ppinteger = ^pinteger;

  PMapTile = ^TMapTile;
  TMapTile = packed record
    _0: array [1..38] of byte;
  end; // .record TMapTile

  PMapTiles = ^TMapTiles;
  TMapTiles = array [0..255 * 255 * 2 - 1] of TMapTile;

  TMapCoords = array [0..2] of integer;

  PPAdvManager = ^PAdvManager;
  PAdvManager  = ^TAdvManager;
  TAdvManager  = packed record
    _0:              array [1..80] of byte;
    RootDlgIdPtr:    ppinteger;
    CurrentDlgIdPtr: ppinteger;
  end; // .record TAdvManager

  PPGameManager = ^PGameManager;
  PGameManager  = ^TGameManager;
  TGameManager  = packed record
    _0:              array [1..130112] of byte;
    MapTiles:        PMapTiles;
    MapSize:         integer;
    IsTwoLevelMap:   boolean;
  end; // .record TGameManager
  
  PScreenPcx16  = ^TScreenPcx16;
  TScreenPcx16  = packed record
    Dummy:  array [0..35] of byte;
    Width:  integer;
    Height: integer;
    (* Dummy *)
  end; // .record TScreenPcx16
  
  PWndManager = ^TWndManager;
  TWndManager = packed record
    Dummy:        array [0..63] of byte;
    ScreenPcx16:  PScreenPcx16;
    (* Dummy *)
  end; // .record TWndManager

  PSecSkillNames = ^TSecSkillNames;
  TSecSkillNames = array [0..MAX_SECONDARY_SKILLS - 1] of pchar;

  PSecSkillDesc = ^TSecSkillDesc;
  TSecSkillDesc = packed record
    case boolean of
      false: (
        Basic:    pchar;
        Advanced: pchar;
        Expert:   pchar;
      );

      true: (
        Descs: array [0..SKILL_LEVEL_EXPERT - 1] of pchar;
      );
  end; // .record TSecSkillDesc

  PSecSkillText = ^TSecSkillText;
  TSecSkillText = packed record
    case boolean of
      false: (
        _0:       pchar; // use Name instead
        Basic:    pchar;
        Advanced: pchar;
        Expert:   pchar;
      );

      true: (
        Texts: array [0..SKILL_LEVEL_EXPERT] of pchar;
      );
  end; // .record TSecSkillText

  PSecSkillDescs = ^TSecSkillDescs;
  TSecSkillDescs = array [0..MAX_SECONDARY_SKILLS - 1] of TSecSkillDesc;

  PSecSkillTexts = ^TSecSkillTexts;
  TSecSkillTexts = array [0..MAX_SECONDARY_SKILLS - 1] of TSecSkillText;

  TMAlloc = function (Size: integer): pointer; cdecl;
  TMFree  = procedure (Addr: pointer); cdecl;
  
  TGzipWrite  = procedure (Data: pointer; DataSize: integer); cdecl;
  TGzipRead   = function (Dest: pointer; DataSize: integer): integer; cdecl;
  TWndProc    = function (hWnd, Msg, wParam, lParam: integer): longbool; stdcall;
  
  TGetBattleCellByPos = function (Pos: integer): pointer; cdecl;
  TMemAllocFunc       = function (Size: integer): pointer; cdecl;
  TMemFreeFunc        = procedure (Buf: pointer); cdecl;

  TMapItemToCoords  = procedure (MapItem: pointer; var x, y, z: integer); cdecl;
  TCoordsToMixedPos = function (x, y, z: integer): integer; cdecl;

  (* Overcomes 12-char unique name restriction for all in-game resources. Maps any name to unique 12-char name. Names with ':' character are reserved. *)
  TResourceNamer = class
   protected
    {O} fNamesMap: {O} TDict {OF TString};
        fAutoId:   integer;

   public
    constructor Create;

    (* Returns unique string for given name, not bigger then 12 characters in length. If name is already max 12 chars in length, it's returned untouched *)
    function  GetResourceName (const OrigResourceName: string): string;

    (* Returns new globally unique resource name. *)
    function  GenerateUniqueResourceName: string;
  end; // .class TResourceNamer

  PChars12 = ^TChars12;
  TChars12 = packed array [0..11] of char;

  {$ALIGN OFF}
  PBinaryTreeItem = ^TBinaryTreeItem;
  TBinaryTreeItem = object
   public
    VTable:   Utils.PEndlessPtrArr;
    Name:     TChars12;
    NameEnd:  integer;
    ItemType: integer;
    RefCount: integer;

    procedure SetName (const aName: string);
    procedure IncRef;
    procedure DecRef;
    procedure Destruct (IsHeapObject: boolean = true);

    function  IsPcx8: boolean;
    function  IsPcx16: boolean;
    function  IsPcx24: boolean;
  end; // .object TBinaryTreeItem
  {$ALIGN ON}

  {$ALIGN OFF}
  PBinaryTreeNode = ^TBinaryTreeNode;
  TBinaryTreeNode = object
   public
    Left:    PBinaryTreeNode;
    Parent:  PBinaryTreeNode;
    Right:   PBinaryTreeNode;
    Name:    TChars12;
    NameEnd: integer;
    Item:    PBinaryTreeItem;
    Field20: integer;

    function  FindItem (const aName: string; var {out} aItem: PBinaryTreeItem): boolean;
    function  FindNode (const aName: string; var {out} aNode: PBinaryTreeNode): boolean;
    procedure RemoveNode (Node: PBinaryTreeNode);
    procedure AddItem (aItem: PBinaryTreeItem);
  end; // .object TBinaryTreeNode
  {$ALIGN ON}

  PBinaryTree = ^TBinaryTree;
  TBinaryTree = TBinaryTreeNode;

  {$ALIGN OFF}
  PPcxItem = ^TPcxItem;
  TPcxItem = object (TBinaryTreeItem)
   public
    BufSize:      integer;
    PicSize:      integer;
    Width:        integer;
    Height:       integer;
    ScanlineSize: integer;
    Buffer:       Utils.PEndlessByteArr;
  end; // .object TPcxItem
  {$ALIGN ON}

  {$ALIGN OFF}
  PPcx16Item = ^TPcx16Item;
  TPcx16Item = object (TPcxItem)
   public
    HasDdSurfaceBuffer: boolean;
  end; // .object TPcx16Item

  PPcx24Item = ^TPcx24Item;
  TPcx24Item = object (TBinaryTreeItem)
   public
    BufSize:    integer;
    PicSize:    integer;
    Width:      integer;
    Height:     integer;
    Buffer:     Utils.PEndlessByteArr;
    Reserved_1: integer;
    Reserved_2: integer;

    procedure DrawToPcx16 (SrcX, SrcY, aWidth, aHeight: integer; Pcx16: PPcx16Item; DstX, DstY: integer);
  end; // .object TPcx24Item
  {$ALIGN ON}

  TPcx16ItemStatic = class
    (* Create new Pcx16 image with RefCount = 0 and not assigned to any binary tree *)
    class function Create (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item; static;
    class function Create_ (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item; static;
    
    (* Uses default pcx loading mechanism to load item, RefCount is increased by one *)
    class function Load (const aName: string): {U} PPcx16Item; static;
  end;

  TPcx24ItemStatic = class
    (* Create new Pcx24 image with RefCount = 0 and not assigned to any binary tree *)
    class function Create (const aName: string; aWidth, aHeight: integer): {On} PPcx24Item; static;
  end;


const
  MAlloc: TMAlloc = Ptr($617492);
  MFree:  TMFree  = Ptr($60B0F0);

  AdvManagerPtr:  PPAdvManager  = Ptr($6992D0);
  WndManagerPtr:  ^PWndManager  = Ptr($6992D0); // CHECKME!
  GameManagerPtr: PPGameManager = Ptr(GAME_MANAGER);

  CurrentPlayer: pinteger = Ptr($69CCF4);

  ZvsGzipWrite: TGzipWrite  = Ptr($704062);
  ZvsGzipRead:  TGzipRead   = Ptr($7040A7);
  WndProc:      TWndProc    = Ptr($4F8290);
  
  GetBattleCellByPos: TGetBattleCellByPos = Ptr($715872);
  MemAllocFunc:       TMemAllocFunc       = Ptr($617492);
  MemFree:            TMemFreeFunc        = Ptr($60B0F0);
  
  MapItemToCoords:  TMapItemToCoords  = Ptr($711EC6);
  CoordsToMixedPos: TCoordsToMixedPos = Ptr($711E7F);

  SecSkillNames: PSecSkillNames = Ptr($698BC4);
  SecSkillDescs: PSecSkillDescs = Ptr($698C30);
  SecSkillTexts: PSecSkillTexts = Ptr($698D88);


var
{O} ResourceNamer: TResourceNamer;
{U} ResourceTree:  PBinaryTree = Ptr($69E560);


function  MemAlloc (Size: integer): {On} pointer;
procedure MemFreeAndNil (var p);
procedure GZipWrite (Count: integer; {n} Addr: pointer);
function  GzipRead (Count: integer; {n} Addr: pointer): integer;
function  LoadTxt (Name: pchar): {n} PTxtFile; stdcall;
procedure LoadLod (const LodName: string; Res: PLod);
procedure GetGameState (out GameState: TGameState); stdcall;
function  GetMapSize: integer;
function  IsTwoLevelMap: boolean;
function  IsLocalGame: boolean;
function  IsNetworkGame: boolean;
function  GetCurrentPlayer: integer;
function  IsThisPcTurn: boolean;
function  GetObjectEntranceTile (MapTile: PMapTile): PMapTile;
procedure MapTileToCoords (MapTile: PMapTile; var Coords: TMapCoords);
function  GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): integer;
function  GetStackIdByPos (StackPos: integer): integer;
procedure RedrawHeroMeetingScreen;
function  IsCampaign: boolean;
function  GetMapFileName: string;
function  GetCampaignFileName: string;
function  GetCampaignMapInd: integer;
{Low level}
function  GetVal (BaseAddr: pointer; Offset: integer): PValue; overload;
function  GetVal (BaseAddr, Offset: integer): PValue; overload;


(***) implementation (***)


constructor TResourceNamer.Create;
begin
  fNamesMap := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end;

function TResourceNamer.GetResourceName (const OrigResourceName: string): string;
var
{U} MapItem: TString;

begin
  if length(OrigResourceName) <= sizeof(TChars12) then begin
    result := OrigResourceName;
  end else begin
    MapItem := fNamesMap[OrigResourceName];

    if MapItem = nil then begin
      inc(fAutoId);
      {!} Assert(fAutoId <> 0, 'Resource Namer IDs are exhausted');
      MapItem                     := TString.Create(':' + SysUtils.IntToStr(fAutoId));
      fNamesMap[OrigResourceName] := MapItem;
    end;

    result := MapItem.Value;
  end; // .else
end; // .function TResourceNamer.GetResourceName

function TResourceNamer.GenerateUniqueResourceName: string;
begin
  inc(fAutoId);
  {!} Assert(fAutoId <> 0, 'Resource Namer IDs are exhausted');
  result := ':' + SysUtils.IntToStr(fAutoId);
end;

procedure TBinaryTreeItem.SetName (const aName: string);
begin
  Utils.SetPcharValue(@Self.Name, aName, sizeof(Self.Name) + 1);
end;

procedure TBinaryTreeItem.IncRef;
begin
  inc(Self.RefCount);
end;

procedure TBinaryTreeItem.DecRef;
begin
  PatchApi.Call(PatchApi.THISCALL_, Self.VTable[1], [@Self]);
end;

procedure TBinaryTreeItem.Destruct (IsHeapObject: boolean = true);
begin
  PatchApi.Call(PatchApi.THISCALL_, Self.VTable[0], [@Self, ord(IsHeapObject)]);
end;

function TBinaryTreeItem.IsPcx8: boolean;
begin
  result := Self.VTable = Ptr($63BA14);
end;

function TBinaryTreeItem.IsPcx16: boolean;
begin
  result := Self.VTable = Ptr($63B9C8);
end;

function TBinaryTreeItem.IsPcx24: boolean;
begin
  result := Self.VTable = Ptr($63B9F4);
end;

function TBinaryTreeNode.FindItem (const aName: string; var {out} aItem: PBinaryTreeItem): boolean;
var
{U} Node: PBinaryTreeNode;

begin
  Node   := nil;
  result := false;
  // * * * * * //
  if aName <> '' then begin
    Node := PBinaryTreeNode(PatchApi.Call(PatchApi.THISCALL_, Ptr($55EE00), [@Self, pchar(aName)]));

    if (Node <> Self.Parent) and (SysUtils.AnsiCompareText(aName, Node.Name) = 0) then begin
      aItem  := Node.Item;
      result := true;
    end;
  end;
end; // .function TBinaryTreeNode.FindItem

function TBinaryTreeNode.FindNode (const aName: string; var {out} aNode: PBinaryTreeNode): boolean;
var
{U} Node: PBinaryTreeNode;

begin
  Node   := nil;
  result := false;
  // * * * * * //
  if aName <> '' then begin
    Node := PBinaryTreeNode(PatchApi.Call(PatchApi.THISCALL_, Ptr($55EE00), [@Self, pchar(aName)]));

    if (Node <> Self.Parent) and (SysUtils.AnsiCompareText(aName, Node.Name) = 0) then begin
      aNode  := Node;
      result := true;
    end;
  end;
end; // .function TBinaryTreeNode.FindNode

procedure TBinaryTreeNode.RemoveNode (Node: PBinaryTreeNode);
var
  Temp: pointer;

begin
  {!} Assert(Node <> nil);
  // * * * * * //
  PatchApi.Call(PatchApi.THISCALL_, Ptr($55DF20), [@Self, @Temp, Node]);
end;

procedure TBinaryTreeNode.AddItem (aItem: PBinaryTreeItem);
var
  ResPtrs: packed array [0..1] of pointer;

  NewItem: packed record
    Name:    TChars12;
    NameEnd: integer;
    Item:    PBinaryTreeItem;
  end;

begin
  NewItem.Name    := aItem.Name;
  NewItem.NameEnd := 0;
  NewItem.Item    := aItem;
  
  PatchApi.Call(PatchApi.THISCALL_, Ptr($55DDF0), [@Self, @ResPtrs, @NewItem]);
end; // .procedure TBinaryTreeNode.AddItem

class function TPcx16ItemStatic.Create (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item;
begin
  result := MemAlloc(Alg.IntRoundToBoundary(sizeof(result^), sizeof(integer)));
  PatchApi.Call(PatchApi.THISCALL_, Ptr($44DD20), [result, pchar(aName), aWidth, aHeight]);
  {!} Assert(result.RefCount = 0);
end;

class function TPcx16ItemStatic.Create_ (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item;
begin
  result := nil;

  if (aWidth <= 0) or (aHeight <= 0) then begin
    Core.NotifyError(Format('Cannot create pcx16 image of size %dx%d', [aWidth, aHeight]));

    aWidth  := Utils.IfThen(aWidth > 0, aWidth, 1);
    aHeight := Utils.IfThen(aHeight > 0, aHeight, 1);
  end;

  if (aWidth > 0) and (aHeight > 0) then begin
    result := MemAlloc(Alg.IntRoundToBoundary(sizeof(result^), sizeof(integer)));

    FillChar(result^, sizeof(result^), 0);
    result.VTable             := Ptr($63B9C8);
    result.SetName(aName);
    result.ItemType           := RES_TYPE_PCX_16;
    result.Width              := aWidth;
    result.Height             := aHeight;
    result.ScanlineSize       := Alg.IntRoundToBoundary(aWidth * 2, sizeof(integer));
    result.BufSize            := result.ScanlineSize * aHeight;
    result.PicSize            := result.BufSize;
    result.HasDdSurfaceBuffer := false;
    result.Buffer             := MemAlloc(result.BufSize);
  end; // .if
end; // .function TPcx16ItemStatic.Create_

class function TPcx16ItemStatic.Load (const aName: string): {U} PPcx16Item;
begin
  result := PPcx16Item(PatchApi.Call(PatchApi.FASTCALL_, Ptr($55B1E0), [pchar(aName)]));
  {!} Assert(result <> nil, Format('Failed to load pcx16 image "%s". "dfault24.pcx" is also missing', [aName]));
  {!} Assert(result.IsPcx16(), Format('Loaded image "%s" is not requested pcx16', [aName]));
end;

class function TPcx24ItemStatic.Create (const aName: string; aWidth, aHeight: integer): {On} PPcx24Item;
begin
  result := nil;

  if (aWidth <= 0) or (aHeight <= 0) then begin
    Core.NotifyError(Format('Cannot create pcx24 image of size %dx%d', [aWidth, aHeight]));

    aWidth  := Utils.IfThen(aWidth > 0, aWidth, 1);
    aHeight := Utils.IfThen(aHeight > 0, aHeight, 1);
  end;

  if (aWidth > 0) and (aHeight > 0) then begin
    result := MemAlloc(Alg.IntRoundToBoundary(sizeof(result^), sizeof(integer)));

    FillChar(result^, sizeof(result^), 0);
    result.VTable     := Ptr($63B9F4);
    result.ItemType   := RES_TYPE_PCX_24;
    result.Width      := aWidth;
    result.Height     := aHeight;
    result.BufSize    := aWidth * aHeight * PCX24_BYTES_PER_COLOR;
    result.PicSize    := result.BufSize;
    result.Reserved_1 := 0;
    result.Reserved_2 := 0;
    result.Buffer     := MemAlloc(result.BufSize);
    result.SetName(aName);
  end; // .if
end; // .function TPcx24ItemStatic.Create

procedure TPcx24Item.DrawToPcx16 (SrcX, SrcY, aWidth, aHeight: integer; Pcx16: PPcx16Item; DstX, DstY: integer);
begin
  {!} Assert(Pcx16 <> nil);
  PatchApi.Call(PatchApi.THISCALL_, Ptr($44ECA0), [@Self, SrcX, SrcY, Width, Height, Pcx16, DstX, DstY]);
end;

function MemAlloc (Size: integer): {On} pointer;
begin
  {!} Assert(Size >= 0, Format('Cannot allocate memory block of %u size', [cardinal(Size)]));
  result := nil;
  // * * * * * //
  if cardinal(Size) > 0 then begin
    result := MemAllocFunc(Size);
    {!} Assert(result <> nil, Format('Failed to allocate memory block of %u size', [cardinal(Size)]));
  end;
end;

procedure MemFreeAndNil (var p);
var
  Temp: pointer;

begin
  Temp       := pointer(p);
  pointer(p) := nil;
  
  if Temp <> nil then begin
    MemFree(Temp);
  end;
end; // .procedure MemFreeAndNil

function GetVal (BaseAddr: pointer; Offset: integer): PValue; overload;
begin
  result := Utils.PtrOfs(BaseAddr, Offset);
end;

function GetVal (BaseAddr, Offset: integer): PValue; overload;
begin
  result := Utils.PtrOfs(Ptr(BaseAddr), Offset);
end;

procedure GZipWrite (Count: integer; {n} Addr: pointer);
begin
  {!} Assert(Utils.IsValidBuf(Addr, Count));
  ZvsGzipWrite(Addr, Count);
end;

function GzipRead (Count: integer; {n} Addr: pointer): integer;
begin
  {!} Assert(Utils.IsValidBuf(Addr, Count));
  result := ZvsGzipRead(Addr, Count) + Count;
end; 

function LoadTxt (Name: pchar): {n} PTxtFile;
begin
  asm
    MOV ECX, Name
    MOV EAX, LOAD_TXT_FUNC
    CALL EAX
    MOV @result, EAX
  end; // .asm
end;

procedure LoadLod (const LodName: string; Res: PLod);
begin
  {!} Assert(Res <> nil);
  asm
    MOV ECX, Res
    PUSH LodName
    MOV EAX, LOAD_LOD
    CALL EAX
  end; // .asm
end;

procedure GetGameState (out GameState: TGameState);
begin
  if (AdvManagerPtr^ <> nil) and (AdvManagerPtr^.RootDlgIdPtr <> nil) then begin
    GameState.RootDlgId :=  AdvManagerPtr^.RootDlgIdPtr^^;
  end else begin
    GameState.RootDlgId :=  0;
  end;
  
  if (AdvManagerPtr^ <> nil) and (AdvManagerPtr^.CurrentDlgIdPtr <> nil) then begin
    GameState.CurrentDlgId := AdvManagerPtr^.CurrentDlgIdPtr^^;
  end else begin
    GameState.CurrentDlgId := 0;
  end;
end; // .procedure GetDialogsIds

function GetMapSize: integer; ASSEMBLER; {$W+}
asm
  MOV EAX, [GAME_MANAGER]
  MOV EAX, [EAX + $1FC44]
end;

function IsTwoLevelMap: boolean; ASSEMBLER; {$W+}
asm
  MOV EAX, [GAME_MANAGER]
  MOVZX EAX, byte [EAX + $1FC48]
end;

function IsLocalGame: boolean;
begin
  result := (GameType^ = GAMETYPE_SINGLE) or (GameType^ = GAMETYPE_HOTSEAT);
end;

function IsNetworkGame: boolean;
begin
  result := (GameType^ <> GAMETYPE_SINGLE) and (GameType^ <> GAMETYPE_HOTSEAT);
end;

function GetCurrentPlayer: integer;
begin
  result := CurrentPlayer^;
end;

function IsThisPcTurn: boolean;
var
  PlayerId: integer;

begin
  PlayerId := CurrentPlayer^;
  result   := (PlayerId >= PLAYER_FIRST) and (PlayerId <= PLAYER_LAST);

  if result then begin
    result := pbyte(pinteger(GAME_MANAGER)^ + $20AD0 + $E1 + $168 * PlayerId)^ <> 0;
  end;
end;

function GetObjectEntranceTile (MapTile: PMapTile): PMapTile; assembler; {W+}
asm
  PUSH EBP
  MOV EBP, ESP
  PUSH 0
  PUSH 0
  PUSH 0
  MOV ECX, ESP
  PUSH 0
  PUSH 0
  PUSH MapTile
  MOV EAX, $40AF10
  CALL EAX
  MOV ESP, EBP
  POP EBP
end; // .function GetObjectEntranceTile

procedure MapTileToCoords (MapTile: PMapTile; var Coords: TMapCoords);
var
  TileIndex: integer;
  MapSize:   integer;

begin
  {!} Assert(MapTile <> nil);
  TileIndex := (integer(MapTile) - integer(@GameManagerPtr^.MapTiles[0])) div sizeof(TMapTile);
  MapSize   := GameManagerPtr^.MapSize;
  Coords[0] := TileIndex mod MapSize;
  TileIndex := TileIndex div MapSize;
  Coords[1] := TileIndex mod MapSize;
  Coords[2] := TileIndex div MapSize;
end; // .procedure MapTileToCoords

function GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): integer;
const
  SLOTS_PER_SIDE  = 21;
  SIDE_OFFSET     = $18;
  STACKID_OFFSET  = $19;
  
var
  Side: byte;

begin
  Side := BattleCell[SIDE_OFFSET];
  
  if Side = 255 then begin
    result := -1;
  end else begin
    result := SLOTS_PER_SIDE * Side + BattleCell[STACKID_OFFSET];
  end;
end; // .function GetBattleCellStackId

function GetStackIdByPos (StackPos: integer): integer;
type
  PStackField = ^TStackField;
  TStackField = packed record
    v:  integer;
  end; // .record TStackField

const
  NO_STACK  = -1;

  STACK_POS = $38;

  function Stacks (Ind: integer; FieldOfs: integer): PStackField; inline;
  begin
    result  :=  Utils.PtrOfs(PPOINTER($699420)^, 21708 + 1352 * Ind + FieldOfs);
  end;

var
  i:  integer;
  
begin
  result := -1;
  i      := 0;
  
  while (i < NUM_BATTLE_STACKS) and (result = NO_STACK) do begin
    if Stacks(i, STACK_POS).v = StackPos then begin
      result  :=  i;
    end else begin
      Inc(i);
    end;
  end;
end; // .function GetStackIdByPos

procedure RedrawHeroMeetingScreen; ASSEMBLER;
asm
  MOV ECX, [$6A3D90]
  PUSH 0
  MOV EAX, $5AF4E0
  CALL EAX

  MOV ECX, [$6A3D90]
  PUSH 1
  MOV EAX, $5AF4E0
  CALL EAX

  MOV ECX, [$6A3D90]
  MOV EAX, $5B1200
  CALL EAX

  MOV ECX, [$6A3D90]
  MOV ECX, [ECX + 56]
  MOV EAX, [ECX]
  MOV EAX, [EAX + 20]
  PUSH $0000FFFF
  PUSH $FFFF0001
  PUSH 0
  CALL EAX

  MOV ECX, [$6992D0]
  PUSH DWORD [$40144F] // 600
  PUSH DWORD [$401448] // 800
  PUSH 0
  PUSH 0
  MOV EAX, $603190
  CALL EAX
end; // .procedure RedrawHeroMeetingScreen

function IsCampaign: boolean;
begin
  result := pbyte($69779C)^ <> 0;
end;

function GetMapFileName: string;
begin
  result := pchar(pinteger(GAME_MANAGER)^ + $1F6D9);
end;

function GetCampaignFileName: string;
type
  TFuncRes = packed record
    _0:               integer;
    CampaignFileName: pchar;
    _1:               array [0..247] of byte;
  end; // .record TFuncRes

var
  FuncRes:    TFuncRes;
  FuncResPtr: ^TFuncRes;

begin
  {!} Assert(IsCampaign);
  asm
    LEA EAX, FuncRes
    PUSH EAX
    MOV ECX, [GAME_MANAGER]
    ADD ECX, $1F458
    MOV EAX, $45A0C0
    CALL EAX
    MOV [FuncResPtr], EAX
  end; // .asm
  
  result := FuncResPtr.CampaignFileName;
end; // .function GetCampaignFileName

function GetCampaignMapInd: integer;
begin
  {!} Assert(IsCampaign);
  result := pbyte(pinteger(GAME_MANAGER)^ + $1F45A)^;
end;

begin
  ResourceNamer := TResourceNamer.Create;
end.
