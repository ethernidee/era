unit Heroes;
(*
  Description: Internal game functions and structures.
  Author:      Alexander Shostak aka Berserker.
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,
  Windows,

  Alg,
  ApiJack,
  DataLib,
  Debug,
  DlgMes,
  StrLib,
  TypeWrappers,
  Utils;

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

  (* Text alignment in dialogs *)
  TEXT_ALIGN_LEFT   = 0;
  TEXT_ALIGN_CENTER = 1;
  TEXT_ALIGN_RIGHT  = 2;
  TEXT_ALIGN_TOP    = 0;
  TEXT_ALIGN_MIDDLE = 4;
  TEXT_ALIGN_BOTTOM = 8;

  HORIZ_TEXT_ALIGNMENT_MASK = TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT;
  VERT_TEXT_ALIGNMENT_MASK  = TEXT_ALIGN_MIDDLE or TEXT_ALIGN_BOTTOM;

  (* Stacks on battlefield *)
  NUM_BATTLE_STACKS          = 42;
  NUM_BATTLE_STACKS_PER_SIDE = 21;

  (* Multiple constants *)
  {$INCLUDE HeroesConsts}

  (*  BattleMon  *)
  NO_STACK          = -1;
  STACK_STRUCT_SIZE = 1352;
  STACK_TYPE        = $34;
  STACK_POS         = $38;
  STACK_POS_SHIFT   = $44;
  STACK_NUM         = $4C;
  STACK_LOSTHP      = $58;
  STACK_FLAGS       = $84;
  STACK_HP          = $C0;
  STACK_SIDE        = $F4;
  STACK_IND         = $F8;

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

  (* Dialog actions *)
  DLG_ACTION_HOVER               = 4;
  DLG_ACTION_OUTDLG_LMB_PRESSED  = 8;
  DLG_ACTION_OUTDLG_LMB_RELEASED = 16;
  DLG_ACTION_OUTDLG_RMB_PRESSED  = 32;
  DLG_ACTION_OUTDLG_RMB_RELEASED = 64;
  DLG_ACTION_KEY_PRESSED         = 256;
  DLG_ACTION_INDLG_CLICK         = 512;
  DLG_ACTION_SCROLL_WHEEL        = 522;

  (* Dialog items *)
  NO_DLG_ITEM = -1;

  LOAD_TXT_FUNC   = $55C2B0;  // F (Name: pchar); FASTCALL;
  UNLOAD_TXT_FUNC = $55D300;  // F (PTxtFile); FASTCALL;
  { F ( Name: PCHAR; AddExt: LONGBOOL; ShowDialog: LONGBOOL; Compress: INTBOOL; SaveToData: LONGBOOL); THISCALL ([GAME_MANAGER]); }
  SAVEGAME_FUNC     = $4BEB60;
  LOAD_LOD          = $559420;  // F (Name: pchar); THISCALL (PLod);
  LOAD_LODS         = $559390;
  LOAD_DEF_SETTINGS = $50B420;  // F();

  (* Limits *)
  MAX_MONS_IN_STACK = 32767;

  hWnd:           pinteger  = Ptr($699650);
  hHeroes3Event:  pinteger  = Ptr($69965C);
  MarkedSavegame: pchar     = Ptr($68338C);
  Mp3Name:        pchar     = Ptr($6A33F4);
  GameType:       PGameType = Ptr($698A40);
  GameVersion:    pinteger  = Ptr($67F554);
  ScreenWidth:    pinteger  = Ptr($401448);
  ScreenHeight:   pinteger  = Ptr($40144F);

  (* Managers *)
  GAME_MANAGER   = $699538;
  TOWN_MANAGER   = $69954C;
  WND_MANAGER    = $6992D0;
  SOUND_MANAGER  = $699414;
  COMBAT_MANAGER = $699420;
  SWAP_MANAGER   = $6A3D90;

  (* Colors *)
  RED_COLOR              = 'F2223E';
  HEROES_GOLD_COLOR      = 'FFE794';
  HEROES_GOLD_COLOR_CODE = integer($FFFFE794);

  (* Resources *)
  RES_FIRST   = 0;
  RES_WOOD    = 0;
  RES_MERCURY = 1;
  RES_ORE     = 2;
  RES_SULFUR  = 3;
  RES_CRYSTAL = 4;
  RES_GEMS    = 5;
  RES_GOLD    = 6;
  RES_MITHRIL = 7;
  RES_LAST    = RES_GOLD;

  (* Map object types *)
  OBKTYPE_NONE = -1;
  OBJTYPE_TOWN = 98;

  (* Msg result *)
  MSG_RES_OK        = 0;
  MSG_RES_CANCEL    = 2;
  MSG_RES_LEFTPIC   = 0;
  MSG_RES_RIGHTPIC  = 1;

  (*  Dialog Pictures Types and Subtypes  *)
  NO_PIC_TYPE = -1;

  (* Internal structures *)
  H3STR_CONST_REF_COUNT = -1;

  (* Input manager keyboard events *)
  INPUT_MES_OTHER   = 0;
  INPUT_MES_KEYDOWN = 1;
  INPUT_MES_KEYUP   = 2;

type
  TInt32Bool = integer;

  TMesType =
  (
    MES_MES         = 1,
    MES_QUESTION    = 2,
    MES_RMB_HINT    = 4,
    MES_CHOOSE      = 7,
    MES_MAY_CHOOSE  = 10
  );

  PValue  = ^TValue;
  TValue  = packed record
    case byte of
      0: (v:  integer);
      1: (p:  pointer);
      2: (pc: pchar);
      3: (b:  byte);
      4: (w:  word);
      5: (f:  single);
      6: (longbool: longbool);
  end;

  SavegameWriter = record
    class procedure Write (Size: integer; {n} Addr: pointer); static;
    class procedure WriteInt (Value: integer); static;
    class procedure WriteStrWithLenField (const Str: string); static;
  end;

  SavegameReader = record
    class function  TryRead (Count: integer; {n} Addr: pointer): integer; static;
    class procedure Read (Count: integer; {n} Addr: pointer); static;
    class function  ReadInt: integer; static;
    class function  ReadStrWithLenField: string; static;
  end;

  PTxtFile = ^TTxtFile;
  TTxtFile = packed record
    Data:     pointer;
    NumLines: integer;
  end;

  PTxtFileNode  = ^TTxtFileNode;
  TTxtFileNode  = packed record
    Dummy:    array [0..$17] of byte;
    RefCount: integer;
    (* Dummy *)
  end;

  PLod = ^TLod;
  TLod = packed record
    Dummy: array [0..399] of byte;
  end;

  PFontCharInfo = ^TFontCharInfo;
  TFontCharInfo = packed record
    SpaceBefore: integer;
    Width:       integer;
    SpaceAfter:  integer;
  end;

  PBasicString = ^TBasicString;
  TBasicString = packed record
    Value: pchar;
    Len:   integer;
  end;

  PExtString = ^TExtString;
  TExtString = packed record
    Value:    pchar;
    Len:      integer;
    Capacity: integer;

    function ToString: string;
  end;

  PH3Str = ^TH3Str;
  TH3Str = packed record
    Special:  integer;
    Value:    pchar;   // Zero-terminated string or null. If not null, pbyte(Value - 1) is reference counter (zero for single owner) or -1 for constants
    Len:      integer;
    Capacity: integer;

    (* Resets the structure without freeing memory *)
    procedure Reset;

    (* Resets the structure and frees memory if necessary *)
    procedure Clear;

    procedure SetLen (NewLen: integer);
    procedure AssignPchar ({n} Str: pchar; StrLen: integer = -1);
  end;

  PDlgTextLines = ^TDlgTextLines;
  TDlgTextLines = packed record
    NumLines:     integer;
    FirstStr:     PH3Str;
    FirstFreeStr: PH3Str;
    ListEnd:      PH3Str;

    procedure Reset;
    procedure AppendLine ({n} Line: pchar; LineLen: integer = -1);
  end;

  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end; // .record TGameState

  ppinteger = ^pinteger;

  PMapTile = ^TMapTile;
  TMapTile = packed record
    _0: array [1..38] of byte;
  end;

  PMapTiles = ^TMapTiles;
  TMapTiles = array [0..255 * 255 * 2 - 1] of TMapTile;

  TMapCoords = array [0..2] of integer;

  PPlayer = ^TPlayer;
  TPlayer = packed record
    Id:                  byte;
    NumHeroes:           byte;
    Unk1:                array [1..2] of byte;
    ActiveHeroId:        integer;
    VisibleHeroIds:      array [0..7] of integer;
    TavernLeftHeroId:    integer;
    TavernRightHeroId:   integer;
    Unk2:                array [1..13] of byte;
    DaysLeft:            byte;
    NumTowns:            byte;
    ActiveTownInd:       byte;
    TownIds:             array [0..47] of byte;
    Unk3:                array [1..113] of byte; // +$70
    IsThisPcHumanPlayer: boolean;                // +$E1
    IsHuman:             boolean;                // +$E2
    Unk:                 array [1..133] of byte;

    function IsOnActiveNetworkSide: boolean;
  end;

  {$ALIGN OFF}
  // Field names should be rechecked
  PDlg = ^TDlg;
  TDlg = object
    VTable:           Utils.PEndlessPtrArr;
    ZOrder:           integer;
    NextDlg:          PDlg;
    LastDlg:          PDlg;
    Flags:            integer;
    State:            integer;
    PosX:             integer;
    PosY:             integer;
    Width:            integer;
    Height:           integer;
    LastDlgItem:      pointer;
    FirstDlgItem:     pointer;
    DlgItemsStruct:   pointer;
    SomeDlgItems:     array [0..2] of pointer;
    FocusedItemId:    integer;
    SomePcx:          integer;
    DeactivatesCount: integer;
    field_4C:         pointer;
    field_50:         pointer;
    field_54:         pointer;
    DlgScrollBar:     pointer;
    field_5C:         pointer;
    Vector:           pointer;
    field_64:         integer;
  end;
  {$ALIGN ON}

  (* Events are stored in random order, except events for the same day *)
  PGlobalEvent = ^TGlobalEvent;
  TGlobalEvent = packed record
    _u1:            integer;
    Message:        TExtString;
    Resources:      array [0..6] of integer;
    ForPlayers:     byte;
    EnableForHuman: boolean;
    EnableForAi:    boolean;
    _u3:            byte;
    FirstDay:       word;
    RepeatInterval: word;
  end;

  TGlobalEvents = packed record First, Last, Dummy: PGlobalEvent; end;

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

  PHeroBiographiesTable = ^THeroBiographiesTable;
  THeroBiographiesTable = array [0..High(integer) div sizeof(pchar) - 1] of pchar;

  PCurrentMp3Track = ^TCurrentMp3Track;
  TCurrentMp3Track = array [0..255] of char;

  TMAlloc = function (Size: integer): pointer; cdecl;
  TMFree  = procedure (Addr: pointer); cdecl;

  TWndProc = function (hWnd, Msg, wParam, lParam: integer): integer; stdcall;

  TGetAdvMapTileVisibility = function (x, y, z: integer): integer; cdecl;
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
    function  GetName: string;
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

    function  FindItem (const aName: string; var {out} aItem: PBinaryTreeItem): boolean; overload;
    function  FindItem (aName: pchar; var {out} aItem: PBinaryTreeItem): boolean; overload;
    function  FindNode (const aName: string; var {out} aNode: PBinaryTreeNode): boolean;
    procedure RemoveNode (Node: PBinaryTreeNode);
    procedure AddItem (aItem: PBinaryTreeItem);
  end; // .object TBinaryTreeNode
  {$ALIGN ON}

  PBinaryTree = ^TBinaryTree;
  TBinaryTree = TBinaryTreeNode;

  TPalette16Color = word;

  PPalette24Color = ^TPalette24Color;
  TPalette24Color = packed record
    Blue:  byte;
    Green: byte;
    Red:   byte;
  end;

  PPalette16Colors = ^TPalette16Colors;
  TPalette16Colors = array [0..255] of TPalette16Color;

  PPalette24Colors = ^TPalette24Colors;
  TPalette24Colors = array [0..255] of TPalette24Color;

  {$ALIGN OFF}
  PPalette16 = ^TPalette16;
  TPalette16 = object (TBinaryTreeItem)
   public
    Colors: TPalette16Colors;
  end;
  {$ALIGN ON}

  {$ALIGN OFF}
  PPalette24 = ^TPalette24;
  TPalette24 = object (TBinaryTreeItem)
   public
    Colors: TPalette24Colors;
  end;
  {$ALIGN ON}

  {$ALIGN OFF}
  PFontItem = ^TFontItem;
  TFontItem = object (TBinaryTreeItem)
   public
    FirstChar:       char;
    LastChar:        char;
    BppDepth:        byte; // Bits per pixel, 8 for Heroes fonts
    XSpace:          byte; // 0?
    YSpace:          byte; // 0?
    Height:          byte; // In bits
    Unk1:            array [1..26] of byte;
    CharInfos:       array [#0..#255] of TFontCharInfo;
    CharDataOffsets: array [#0..#255] of integer;
    Palette16:       TPalette16;
    CharsDataPtr:    Utils.PEndlessByteArr;
  end; // .object TFontItem
  {$ALIGN ON}

  {$ALIGN OFF}
  PDefFrame = ^TDefFrame;
  TDefFrame = object (TBinaryTreeItem)
   public
    FrameSize:       integer;
    BufSize:         integer;
    CompressionType: integer;
    DefWidth:        integer;
    DefHeight:       integer;
    FrameWidth:      integer;
    FrameHeight:     integer;
    FrameLeft:       integer;
    FrameTop:        integer;
    Unk1:            integer;
    Buffer:          pointer;
  end; // .object TDefFrame
  {$ALIGN ON}

  PDefFrames = ^TDefFrames;
  TDefFrames = array [0..High(integer) div sizeof(integer) - 1] of PDefFrame;

  PDefGroup = ^TDefGroup;
  TDefGroup = packed record
    NumFrames: integer;
    FrameSize: integer;
    Frames:    PDefFrames;
  end;

  PDefGroups = ^TDefGroups;
  TDefGroups = array [0..High(integer) div sizeof(integer) - 1] of PDefGroup;

  {$ALIGN OFF}
  PDefItem = ^TDefItem;
  TDefItem = object (TBinaryTreeItem)
   public
    Groups:        PDefGroups;
    Palette16:     PPalette16;
    Palette24:     PPalette24;
    NumGroups:     integer;
    ActiveGroups:  pointer;
    Width:         integer;
    Height:        integer;

    function GetFrame (GroupInd, FrameInd: integer): {n} PDefFrame;

    function DrawInterfaceDefGroupFrame (GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer;
                                         DoMirror, UsePaletteSpecialColors: boolean): integer;
  end; // .object TDefItem
  {$ALIGN ON}

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
  PPcx8Item = ^TPcx8Item;
  TPcx8Item = object (TPcxItem)
   public
    Palette16: TPalette16;
    Palette24: TPalette24;

    procedure DrawToBuf (
      SrcX, SrcY, SrcWidth, SrcHeight: integer;
      Buf: pointer;
      DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor: integer
    );
  end;
  {$ALIGN ON}

  {$ALIGN OFF}
  PPcx16Item = ^TPcx16Item;
  TPcx16Item = object (TPcxItem)
   public
    HasDdSurfaceBuffer: boolean;

    procedure DrawToBuf (
      SrcX, SrcY, SrcWidth, SrcHeight: integer;
      Buf: pointer;
      DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor: integer
    );
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

  TPcx8ItemStatic = class
    class function Create (const aName: string; aWidth, aHeight: integer): {On} PPcx8Item;
  end;

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

  PMonInfo = ^TMonInfo;
  TMonInfo = packed record
    Group:        integer; // +0  0...8,-1 - neutral
    SubGroup:     integer; // +4  0...6,-1 - not available (423D87, 42A0FC)
    ShortName:    pchar;   // +8  (4242B7)
    DefName:      pchar;   // +C  loading and setting battlefield in 43DA45
    Flags:        integer; // +10 (424354, 42C6C0)

    Names:        packed record
      case byte of
        1: (
          Singular:  pchar;
          Plural:    pchar;
          Specialty: pchar;
        );

        2: (
          Texts: array [0..2] of pchar;
        );
    end;

    CostRes:      array [0..6] of integer;// +20 (42B73A)
    FightValue:   integer; // +3C
    AiValue:      integer; // +40
    Grow:         integer; // +44 initial number for hiring
    HGrow:        integer; // +48
    HitPoints:    integer; // +4C
    Speed:        integer; // +50
    Attack:       integer; // +54
    Defence:      integer; // +58
    DamageLow:    integer; // +5C
    DamageHight:  integer; // +60
    NumShots:     integer; // +64
    NumCasts:     integer; // +68 - how many times creature can cas
    AdvMapLow:    integer; // +6C
    AdvMapHigh:   integer; // +70
  end; // .record TMonInfo

  TMonInfos = array [0..high(integer) div sizeof(TMonInfo) - 1] of TMonInfo;
  PMonInfos = ^TMonInfos;

  PMouseEventInfo = ^TMouseEventInfo;
  TMouseEventInfo = packed record
    ActionType:    integer;
    ActionSubtype: integer;
    Item:          integer;
    Flags:         integer;
    X:             integer;
    Y:             integer;
    Param1:        integer;
    Param2:        integer;
  end;

  PSpell = ^TSpell;
  TSpell = packed record // size 0x88 = 136
    TargetType:          integer;                 // +0 -1=enemy, 0=square/global/area, 1=friend
    SoundFileName:       pchar;                   // +4
    DefIndex:            integer;                 // +8 used to get DefName
    Flags:               integer;                 // +C
    Name:                pchar;                   // +10h
    ShortName:           pchar;                   // +14h
    Level:               integer;                 // +18h
    SchoolBits:          integer;                 // +1Ch Air=1,Fire=2,Water=4,Earth=8
    Cost:                array [0..3] of integer; // +20h cost mana per skill level
    Power:               integer;                 // +30h
    Effect:              array [0..3] of integer; // +34h effect per skill level
    ChanceToGetForClass: array [0..8] of integer; // +44h chance per class
    AiValue:             array [0..3] of integer; // +68h
    Description:         array [0..3] of pchar;   // +78h

    // 0 for name, 1 short name, 2 - description without magic skill, 3..5 - description with basic..expert skill, 6 - sound name
    function GetTextField (Ind: integer): PValue;
  end;

  PSpells = ^TSpells;
  TSpells = array [0..high(integer) div sizeof(TSpell) - 1] of TSpell;

  TArtHandle = packed record
    Id:       integer;
    Modifier: integer;
  end;

  PArmyMonTypes = ^TArmyMonTypes;
  TArmyMonTypes = array [0..6] of integer;

  PArmyMonNums = ^TArmyMonNums;
  TArmyMonNums = array [0..6] of integer;

  PArmy = ^TArmy;
  TArmy = packed record
    MonTypes: TArmyMonTypes;
    MonNums:  TArmyMonNums;
  end;

  (* Ported from WoG. Needs refactoring *)
  PHero = ^THero;
  THero = packed record
    X:            smallint;                       // +00  dw    = x position
    Y:            smallint;                       // +02  dw    = y position
    L:            smallint;                       // +04  dw    = ? uroven' starshaya chast' y (y<<2>>C)
    Visible:      byte;                           // +06  db    = 1 - est' na karte (vnutri goroda ili ne aktiven)
                                                  // Byte  _u1[17];
                                                  // +07 db - x
                                                  // +08 db - (?) musor (k x)
                                                  // +09 db - y
                                                  // +0A db - l(?) musor (k y)
    PlMapItem:    integer;                        // MixedPos
                                                  // +0B db - (?) l
    _u1:          byte;
                                                  // +0C dd - tip ob'ekta na kotorom geroj stoyal
    PlOType:      integer;                        // dd +1E s karty
                                                  // +10 db - bit zanyatosti vo flagah poverhnosti 00001000
                                                  // eto bit oznachayuschij, chto zdes' est'/byla tochka vhoda (zheltaya kletka)
    Pl0Cflag:     integer;
                                                  // +14 dd - SetUp s karty
    PlSetUp:      integer;                        // dd +0 s karty
    SpPoints:     word;                           // +18  dw    = bally zaklinanij
    Id:           integer;                        // +1A  dd    = nomer podtipa (konkretnyj geroj)
    BadFood:      integer;                        // +1E  dd    = BAD FOOD marker
    Owner:        byte;                           // +22  db    = xozyain (czvet)
    Name:         array [0..12] of char;          // +23  db*D  = imya,0
    Spec:         integer;                        // +30  dd    = str[8] str=(*[67CD08])[nomer podtipa *5C]
    Pic:          byte;                           // +34  db    = nomer kartinki
                                                  // dw +35 ???
                                                  // dw +41 ???
                                                  // db +43 0
    _u2:          array [0..14] of byte;
                                                  // +3E db -??? 4E3BB5 - used in luck calculation
    x0:           byte;                           // +44  db    = bazovyj x dlya obeganiya (FF-ne ogranichen)
    y0:           byte;                           // +45  db    = bazovyj y dlya obeganiya (FF-ne ogranichen)
    Run:          byte;                           // +46  db    = radius obeganiya (FF-ne ogranichen)
    _u3:          byte;                           // +47  db    = ???
    Flags:        byte;                           // +48  8*bb  (463253)
                                                  // 01 - tip gruppirovki yunitov
                                                  // 02 - razreshena taktika dlya geroya
    Movement0:    integer;                        // +49  dd    = polnoe peremeschenie nachal'noe
    Movement:     integer;                        // +4D  dd    = ostavshiesya peremescheniya
    Exp:          integer;                        // +51  dd    = opyt
    ExpLevel:     word;                           // +55  dw    = uroven'
                                                  // Dword  VStones;  // +57 32 kamnya (1-poseschen,2-net)
                                                  // Dword  VMTower;  // +5B Bashnya Mardetto
                                                  // Dword  VGarden;  // +5F sad otkroveniya
                                                  // Dword  VMCamp;   // +63 lager' naemnikov
                                                  // Dword  VSAxis;   // +67 zvezdnoe koleso
                                                  // Dword  VKTree;   // +6B derevo znanij
                                                  // Dword  VUniver;  // +6F universitet
                                                  // Dword  VArena;   // +73 arena
                                                  // Dword  VSMagic;  // +77 shkola magov
                                                  // Dword  VSWar;    // +7B shkola vojny
    Visited:      array [0..9] of integer;
    _u4:          array [0..17] of byte;          // +7F
    Army:         TArmy;                          // +91  dd*7, +AD  dd*7
    SSkill:       array [0..27] of byte;          // +C9  db*1C = uroven' 2-h skilov (odin bajt - uroven' etogo nomera skila 1,2,3) 0-net
                                                  // C9=Pathfinding CA=Archery CB=Logistics CC=Scouting CD=Diplomacy CE=Navigation CF=Leadership
                                                  // D0=Wisdom D1=Mysticism D2=Luck D3=Ballistics D4=Eagle Eye D5=Necromancy D6=Estates D7=Fire Magic
                                                  // D8=Air Magic D9=Water Magic DA=Earth Magic DB=Scholar DC=Tactics DD=Artillery DE=Learning DF=Offence
                                                  // E0=Armorer E1=Intelligence E2=Sorcery E3=Resistance E4=First Aid
    SShow:        array [0..27] of byte;          // +E5  db*1C = poryadok otobrazheniya 2-h skilov v okne geroya (1,2,3,4,5,6)
    SSNum:        integer;                        // +101 dd    = kolichestvo 2-h skilov
                                                  // Word  RefData1;  //   +105  4814D3+...
                                                  // Word  RefData2;  //   +107  4DA466
    TempMod:      integer;                        // +105 vremennye modifikatory
                                                  // nach. inicz. pri najme 0xFFF9FFFF
                                                  //  00000002 = konyuschnya 3.59 ERM
                                                  //  00000008 = lebedinoe ozero swan pond 3.59 ERM
                                                  //  00000020 = (???) fontan udachi fountain of fortune 3.59 ERM
                                                  //  00000080 = oazis
                                                  //  00002000 = domik fej
                                                  //  00040000 = v lodke na vode
                                                  //  00200000 = -3morale v varior tomb
                                                  //  00400000 = Give Maximum Luck
                                                  //  00800000 = Give Maximum Moral
                                                  //  38000000 = konkretnyj tip fontana udachi
    _u6:          array [0..8] of byte;           // +109
    _u7:          integer;                        // +112
    DMorale:      byte;                           // +116 modifikatory morali (nakaplivayutsya)
    _u60:         array [0..2] of byte;
    DMorale1:     byte;                           // +11A modif morali (oazis)
    DLuck:        byte;                           // +11B modif udachi do sled bitvy
    _u6a:         array [0..16] of byte;
    EquippedArts: array [0..18] of TArtHandle; // +12D dd*2*13h = artifakty dd-nomer,dd-(FF) (kniga 3,FF)
    FreeAddSlots: byte;                           // +1C5 kolichestvo pustyh dop. slotov sleva
    LockedSlot:   array [0..13] of byte;          // +1C6
    BackpackArts: array [0..63] of TArtHandle; // +1D4 dd*2*40 = art v ryukzake dd-nomer, dd-(FF)
    OANum:        byte;                           // +3D4 db   = chislo artifaktov v ryukzake
    Sex:          integer;                        // +3D5 dd    = pol
    fl_B:         byte;                           // +3D9 db    = est' biografiya
                                                  // char  *Bibl;     //   +3DA dd    -> biografiya
                                                  // Byte  _u7[12];    //  +3DE
    _5b:          integer;                        // +3DA
    Bibl:         TExtString;                     // +3DE
    Spell:        array [0..69] of byte;          // +3EA db*46 = zaklinanie (est'/net)
    LSpell:       array [0..69] of byte;          // +430 db*46 = uroven' zaklinaniya (>=1)
    PSkill:       array [0..3]  of byte;          // +476 db*4  = pervichnye navyki
    _u8:          array [0..23] of byte;

    function HasArtOnDoll (ArtId: integer): boolean;
  end; // .record THero

  THeroes = packed array [0..999] of THero;
  PHeroes = ^THeroes;

  (*
  struct H3Boat // size 0x28 from 0x4CE5C0
  {
  INT16 x;
  INT16 y;
  INT16 z;
  INT8 visible;
  H3MapItem* item; // 7
  h3unk _f_0B;
  INT32 object_type; // C
  INT8 object_flag;
  h3unk _f_11[3];
  INT32 object_setup; // 14h
  INT8 exists; // 18h
  INT8 index; // 19h
  INT8 par1;
  INT8 par2;
  INT8 owner; // 1Ch
  h3unk _f_1D[3];
  INT32 hero_id; // 20h
  INT8 has_hero; //24h
  h3unk _f_25[3];
  };
  *)
  PBoat = ^TBoat;

  TBoat = record
    x:                 word;                 // +0h
    y:                 word;                 // +2h
    z:                 word;                 // +4h
    IsVisible:         boolean;              // +6h
    MapTile:           PMapTile;             // +7h
    _1:                byte;                 // +0Bh
    ObjType:           integer;              // +0Ch
    ObjFlag:           byte;                 // +10h
    _2:                array [1..3] of byte; // +11h
    ObjSetup:          integer;              // +14h
    IsPresentOnAdvMap: boolean;              // +18h
    Index:             byte;                 // +19h
    Param1:            byte;                 // +1Ah
    Param2:            byte;                 // +1Bh
    Owner:             byte;                 // +1Ch
    _3:                array [1..3] of byte; // +1Dh
    HeroId:            integer;              // +20h
    HasHero:           boolean;              // +24h
    _4:                array[1..3] of byte;  // +25h
  end;

  (* Ported from WoG. Needs refactoring *)
  PTown = ^TTown;
  TTown = packed record
    Id:            byte;                         // +0 0,1,2,...
    Owner:         char;                         // +1 0,...
    BuiltThisTurn: char;                         // +2 - uzhe stroili v etot turn (0-net, 1-da, 2-ne nash gorod)
    _u2:           byte;                         // +3 0
    TownType:      byte;                         // +4 0,1...,8
    x:             byte;                         // +5
    y:             byte;                         // +6
    l:             byte;                         // +7
    Pos2PlaceBoatX:byte;                         // +8 pomeschat' lodku pri pokupki v Shipyard
    Pos2PlaceBoatY:byte;                         // +9
    _uAa:          array [0..1] of byte;         // +0A
    IHero:         integer;                      // +0Ch = nomer geroya vnutri goroda (-1 - nikogo net)
    VHero:         integer;                      // +10h = nomer geroya snaruzhi goroda (-1 - nikogo net)
    MagLevel:      char;                         // +14h = uroven' magicheskoj gil'dii v gorode (isp. AI dlya postrojki)
    _u15:          byte;
    DwellingMons:  array [0..1, 0..6] of word;   // +16h ko-lvo prostyh i apgrejdnutyh
    _u32:          char;                         // +32 = ?
    _u33:          char;                         // +33 = 1
    _u34:          char;                         // +34 = 0
    _u35a:         array [0..2] of byte;
    _u38:          integer;                      // +38 = -1
    _u3C:          integer;                      // +3C = -1
    _u40:          short;                        // +40
    _u42:          word;                         // +42
    Spells:        array [0..4, 0..5] of integer;// +44 sami zaklinaniya
    MagicHild:     array [0..4] of char;         // +BCh = kolvo zaklinanij v urovne gil'dii
    _uC1:          array [0..2] of byte;
    _uC4:          char;                         // +C4 = 0
    _uC5:          array [0..2] of byte;
    Name:          TExtString;                   // +C8 -> Imya goroda
    _u8:           array [0..2] of integer;      // +D4 = 0
    Guards:        TArmy;                        // +E0 = ohrana zamka, +FC = kol-vo ohrany
    GuardsUnk:     TArmy;                        // +118 = ohrana zamka, +134 = kol-vo ohrany
    Built:         array [0..7] of byte;         // +150h = uzhe postroennye zdaniya (0400)
    Bonus:         array [0..7] of byte;         // +158h = bonus na suschestv, resursy i t.p., vyzvannyj stroeniyami
    BMask:         array [0..1] of integer;      // +160h = maska dostupnyh dlya stroeniya stroenij
  end; // .record TTown

  TTowns = packed array [0..999] of TTown;
  PTowns = ^TTowns;

  PTownMonTypes = ^TTownMonTypes;
  TTownMonTypes = packed array [0..1] of packed array [0..6] of integer;

  PMonAssignmentsPerTown = ^TMonAssignmentsPerTown;
  TMonAssignmentsPerTown = packed array [0..999] of TTownMonTypes;

  PTownManager = ^TTownManager;
  TTownManager = packed record
    Unk1: array [0..$38 - 1] of byte;
    Town: PTown;
  end;

  PGameDate = ^TGameDate;
  TGameDate = packed record
    Day:   word;
    Week:  word;
    Month: word;
  end;

  PArtInfo = ^TArtInfo;
  TArtInfo = packed record
    Name:           pchar;                // +00
    Cost:           integer;              // +04
    Pos:            integer;              // +08
    ArtType:        integer;              // +0C
    Desc:           pchar;                // +10
    ComboArtId:     integer;              // +14
    ComboArtPartId: integer;              // +18
    IsDisabled:     boolean;              // +1C
    GivesSpell:     boolean;              // +1D
    Reserved:       array [1..2] of byte; // +1E

    // 0 for name, 1 for description
    function GetTextField (Ind: integer): PValue;
  end;

  PArtInfos = ^TArtInfos;
  TArtInfos = array [0..99999] of TArtInfo;

  TTextTableCells = array of Utils.TArrayOfStr;

  TTextTable = class
   protected
    fCells:   TTextTableCells;
    fNumCols: integer;
    fNumRows: integer;

   public
    constructor Create (Cells: TTextTableCells);

    function GetItem (Row, Col: integer): string;

    property Items[Row, Col: integer]: string read GetItem; default;
    property NumCols: integer read fNumCols;
    property NumRows: integer read fNumRows;
  end; // .class TTextTable

  PGeneralPurposeTextBuf = ^TGeneralPurposeTextBuf;
  TGeneralPurposeTextBuf = array [0..767] of char;

  PGameManager  = ^TGameManager;
  TGameManager  = packed record
    _0:      array [1..129904] of byte;
    Align_0: integer;                 _Types_:       array [0..2] of integer;                             // +00
    Align_1: integer;                 _Position_:    array [0..2] of integer;                             // +10
    Align_2: array [0..3] of integer; // DEFs                                                             // +20
    Align_3: integer;                 _ArtRes_:      array [0..2] of integer;                             // +30
    Align_4: integer;                 _Monster_:     array [0..2] of integer;                             // +40
    Align_5: integer;                 _Event_:       array [0..2] of integer;                             // +50
    Align_6: array [0..3] of integer;                                                                     // +60
    Align_7: array [0..3] of integer;                                                                     // +70
    Align_8: integer;                 GlobalEvents:  TGlobalEvents;                                       // +80
    Align_9: integer;                 _CastleEvent_: array [0..2] of integer;                             // +90
    Align_10: array [0..3] of integer;                                                                    // +A0
    Align_11: array [0..3] of integer;                                                                    // +B0
    Align_12: array [0..3] of integer;                                                                    // +C0
    MapTiles:      PMapTiles;
    MapSize:       integer;
    IsTwoLevelMap: boolean;
  end; // .record TGameManager

  PBattleStack = ^TBattleStack;
  TBattleStack = packed record
    Unk1:           array [0..$34 - 1] of byte;
    MonType:        integer; // +0x34
    Pos:            integer; // +0x38
    Unk2:           array [$3C..$4C - 1] of byte;
    Num:            integer; // +0x4C
    Unk3:           array [$50..$58 - 1] of byte;
    HpLost:         integer; // +0x58
    Unk4:           array [$5C..$84 - 1] of byte;
    Flags:          integer;
    Unk5:           array [$88..$C0 - 1] of byte;
    HitPoints:      integer;
    Unk6:           array [$C4..$F4 - 1] of byte;
    Side:           integer;
    Index:          integer; // 0..21
    Unk7:           array [$FC..$198 - 1] of byte;
    SpellDurations: array [0..80] of integer; // +0x198 spellID => duration
    SpellLevels:    array [0..80] of integer; // +0x2DC spellID => magic skill level (0..3)
    Unk8:           array [$420..$548 - 1] of byte;

    function GetId: integer; inline;
  end; // .record TBattleStack

  PBaseManager = ^TBaseManager;
  TBaseManager = packed record
    VMT:         pointer;
    NextManager: {n} PBaseManager;
    PrevManager: {n} PBaseManager;
    Id:          integer;
    Priority:    integer;
    Name:        array [0..31] of char;
    Status:      integer;
  end;

  PSwapManager = ^TSwapManager;
  TSwapManager = packed record
    Base:               TBaseManager;
    Parent:             pointer;
    Border:             pointer;
    Heroes:             array [0..1] of PHero;
    SourceHeroInd:      integer; // 0..1
    TargetHeroInd:      integer; // 0..1
    SourceSlot:         integer;
    DestSlot:           integer;
    IsSlotClicked:      TInt32Bool;
    _Align1:            byte;
    IsSamePlayer:       boolean;
    _Align2:            array [1..2] of byte;
    ChatMessageHandler: pointer;
    NetMessageHandler:  pointer;
  end;

  PCombatManager  = ^TCombatManager;
  TCombatManager  = packed record
    Unk1:          array [0..$3C - 1] of byte;
    Action:        integer; // +0x3C
    Spell:         integer; // +0x40
    TargetPos:     integer; // +0x44
    ActionParam2:  integer; // +0x48
    Unk2:          array [$4C..$53CC - 1] of byte;
    Heroes:        array [0..1] of PHero; // +0x53CC
    Unk3:          array [$53CC + sizeof(pointer) * 2..$132B8 - 1] of byte;
    CurrStackSide: integer; // 0x132B8
    CurrStackInd:  integer; // 0x132BC
    ControlSide:   integer; // 0x132C0, the side, which is really controlling current stack
    Unk4:          array [$132C0 + 4..$13D68 - 1] of byte;
    IsTactics:     boolean; // 0x13D68
    Align1:        array [1..3] of byte;
    Round:         integer; // 0x13D6C

    // _byte_ field_0[452]; // + 0 ?
    // _BattleHex_ hex[187]; // + 0x1c4 187=17*11
    // _byte_ field_5394[56]; //?

    // _Hero_* hero[2]; // + 21452 // 0 - attacker, 1 - defender
    // _byte_ field_53D4[212]; // + 21460d
    // _int32_ owner_id[2]; // + 21672d // 0 - attacker, 1 - defender
    // _byte_ field_54B0[12];  // + 21680
    // _int32_ stacks_count[2];//+0x54BC  // 0 - attacker, 1 - defender
    // _Army_* army[2]; // + 21700 // 0 - attacker, 1 - defender
    // //_BattleStack_ stack[42]; //+ 21708
    // _BattleStack_ stack[2][21]; //+ 21708

    // _byte_ field_1329C[28]; // + 0x1329C
    // _int32_ unk_side; // +78520 0x132B8
    // _int32_ current_stack_ix; // +78524 0x132BC
    // _int32_ current_side; // +78528 0x132C0

    // //_byte_ field_132C4[56]; // + 0x132C4
    // _byte_ field_132C4[36]; // + 0x132C4
    // _Def_* current_spell_def; // + 0x132E8
    // _int_  current_spell_id; // + 0x132EC
    // _dword_ field_132F0; // + 0x132F0
    // _int32_ town_fort_type; // + 0x132F4
    // _dword_ field_132F8; // + 0x132F8

    // _Dlg_* dlg;       // + 0x132FC
    // _byte_ field_13300[3564];

    function GetActiveStack: PBattleStack;
    procedure RedrawGridAndSelection;
  end; // .record TCombatManager

  PMouseManager = ^TMouseManager;
  TMouseManager = packed record
    VMT:                 integer; // 00000000
    field_4:             integer; // 00000004
    field_8:             integer; // 00000008
    field_C:             integer; // 0000000C
    field_10:            integer; // 00000010
    ClassName:           array [0..11] of char; // 00000014
    field_20:            integer; // 00000020
    field_24:            integer; // 00000024
    field_28:            integer; // 00000028
    field_2C:            integer; // 0000002C
    field_30:            integer; // 00000030
    field_34:            integer; // 00000034
    field_38:            integer; // 00000038
    field_3C:            integer; // 0000003C
    field_40:            integer; // 00000040 struct offset (_Pcx16_)
    field_44:            integer; // 00000044
    field_48:            integer; // 00000048
    CursorType:          integer; // 0000004C
    CursorFrameInd:      integer; // 00000050
    CursorDef:           PDefItem; // 00000054 offset
    CursorDrawX:         integer; // 00000058
    CursorDrawY:         integer; // 0000005C
    field_60:            integer; // 00000060
    field_64:            integer; // 00000064
    CursorHidden:        integer; // 00000068
    _align69:            array [1..3] of byte;
    MouseX:              integer; // 0000006C
    MouseY:              integer; // 00000070
    field_74:            integer; // 00000074
    field_78:            Windows._RTL_CRITICAL_SECTION; // 00000078
  end;

  PKeyboardInputMessage = ^TKeyboardInputMessage;
  TKeyboardInputMessage = packed record
    KeyCode:      integer;    // Scancode or ANSI character code if IsTranslated field is TRUE
    Zero_1:       integer;
    Modifiers:    integer;    // Modifier key flags
    IsTranslated: TInt32Bool; // ERA new field. If true, KeyCode is ANSI char code and should not be translated
    Zero_2:       integer;
    Zero_3:       integer;
    Zero_4:       integer;
  end;

  PInputMessage = ^TInputMessage;
  TInputMessage = packed record
    MsgType: integer; // One of INPUT_MES_XXX constants

    case byte of
      0: (Key:   TKeyboardInputMessage);
      1: (Other: packed array [0..27] of byte);
  end;

  // Circular buffer
  PInputMessageQueue = ^TInputMessageQueue;
  TInputMessageQueue = packed record
    IsEnabled:   TInt32Bool;
    Messages:    array [0..63] of TInputMessage;
    ReadPosInd:  integer;
    WritePosInd: integer;

    procedure Enqueue (InputMsg: PInputMessage);
    procedure AddTranslatedKeyInputMsg (KeyCode: integer; Modifiers: integer = 0);
  end;

  PInputManager = ^TInputManager;
  TInputManager = packed record
    VTable: pointer;
    Unk1:   array [5..52] of byte;
    Queue:  TInputMessageQueue;
    Unk2:   integer;
    f844:   array [1..260] of byte;
    f948:   integer;
    f94C:   integer;
    PreventAutoKeyTranslation: TInt32Bool;
    f954:   integer;
    f958:   integer;
    f95C:   integer;
  end;

  PWndManager  = ^TWndManager;
  TWndManager  = packed record
    _1:           array [1..55] of byte;
    DlgResItemId: integer;
    _2:           array [60..64] of byte;
    ScreenPcx16:  PPcx16Item;
    _0:           array [69..80] of byte;
    RootDlg:      PDlg;
    CurrentDlg:   PDlg;

    function GetRootDlgId:    integer;
    function GetCurrentDlgId: integer;
  end;

  PNetData = ^TNetData;
  TNetData = object
    PlayerId:   integer; // Sender ID if sending, Receiver ID if receiving
    Zero_1:     integer;
    MsgId:      integer;
    StructSize: integer;
    Zero_2:     integer;
    RawData:    record end;

    procedure Init;
    procedure Send (aDestPlayerId: integer);
  end;

  PWogDlgItem = pointer;

  TWogDlgAnimatedDef = packed record
    FrameInd: integer;
    Item:     PWogDlgItem;
  end;

  PWogDlgHint = ^TWogDlgHint;
  TWogDlgHint = packed record
      ItemId: integer;
  {O} Text:   pchar; // not owned in original WoG, but owned in Era
  end;

  PWogDlgHints = ^TWogDlgHints;
  TWogDlgHints = array [0..High(integer) div sizeof(TWogDlgHint) - 1] of TWogDlgHint;

  PWogDialog = ^TWogDialog;
  TWogDialog = packed record
    NativeData:   array [1..96] of byte;
    AnimatedDefs: array [1..10] of TWogDlgAnimatedDef;
    VideoIndex:   integer; // or -1
    VideoX:       integer;
    VideoY:       integer;
    HintItemInd:  integer;
    Hints:        PWogDlgHints;
    NumItems:     integer;
    Id:           integer;
  end;

  PWogDialogLink = ^TWogDialogLink;
  TWogDialogLink = packed record
    {O}  Dlg:   PWogDialog;
    {On} Next:  PWogDialogLink;
         Flags: integer;
  end;

const
  MAlloc:      TMAlloc = Ptr($617492);
  MFree:       TMFree  = Ptr($60B0F0);
  ZvsRandom:   function (MinValue, MaxValue: integer): integer cdecl = Ptr($710509);
  TimeGetTime: function: integer = Ptr($77114A);

  WndManagerPtr:    ^PWndManager    = Ptr($6992D0);
  MouseManagerPtr:  ^PMouseManager  = Ptr($6992B0);
  InputManagerPtr:  ^PInputManager  = Ptr($699530);
  GameManagerPtr:   ^PGameManager   = Ptr(GAME_MANAGER);
  CombatManagerPtr: ^PCombatManager = Ptr(COMBAT_MANAGER);
  SwapManagerPtr:   ^PSwapManager   = Ptr($6A3D90);
  MainMenuTarget:   pinteger        = Ptr($697728);

  CursorHotspotsX:  Utils.PEndlessIntArr = Ptr($67FFA0);
  CursorHotspotsY:  Utils.PEndlessIntArr = Ptr($67FFA4);

  ThisPcHumanPlayerId: pinteger   = Ptr($6995A4);
  CurrentPlayerId:     pinteger   = Ptr($69CCF4);
  GameDate:            ^PGameDate = Ptr($840CE0);
  IsGameEnd:           pboolean   = Ptr($697308);
  GameEndKind:         pbyte      = Ptr($699560);

  BytesPerPixelPtr:           pbyte = Ptr($5FA228 + 3);
  Color16GreenChannelMaskPtr: pword = Ptr($694DB0);

  ZvsWriteSavegame: function (Data: pointer; DataSize: integer): integer cdecl = Ptr($704062);
  ZvsReadSavegame:  function (Dest: pointer; DataSize: integer): integer cdecl = Ptr($7040A7);
  WndProc:          TWndProc = Ptr($4F8290);
  ZvsGetHero:       function (HeroId: integer): {n} PHero cdecl = Ptr($71168D);
  ZvsGetTowns:      function: {n} PTowns cdecl = Ptr($711BD4);
  ZvsCountTowns:    function: integer = Ptr($711C0E);
  ZvsLoadTxtFile:   function (FilePath: pchar; var TxtFile: TTxtFile): longbool cdecl = Ptr($777030); // true on error
  ZvsGetTxtValue:   function (Row, Col: integer; TxtFile: PTxtFile): pchar cdecl = Ptr($77710B);
  ZvsFindNextObjects:     function (ObjType, ObjSubtype: integer; var x, y, z: integer; Direction: integer): longbool cdecl = Ptr($72F67B);
  ZvsFindObjects:         function (ObjType, ObjSubtype, ObjectN: integer; var x, y, z: integer): longbool cdecl = Ptr($72F539);
  ZvsChangeHeroPortraitN: procedure (DstHeroId, SrcHeroId: integer) cdecl = Ptr($753ABF);
  ZvsChangeHeroPortrait:  procedure (HeroId: integer; {n} LargePortrait, {n} SmallPortrait: pchar) cdecl = Ptr($7539A6);
  ZvsRedrawMap:     procedure = Ptr($7126EA);
  a2i:              function (Str: pchar): int cdecl = Ptr($6184D9);
  a2f:              function (Str: pchar): single cdecl = Ptr($619366);

type
  TOpenSmackApiFunc = function (FileHandle: Windows.THandle; BufSize, MinusOne: int): {n} pointer stdcall;
  TOpenBinkApiFunc  = function (FileHandle: Windows.THandle; BufMask: integer): {n} pointer stdcall; // BufMask must be ORed with $8000000

const
  Video: record
    OpenSmack: ^TOpenSmackApiFunc;
    OpenBink:  ^TOpenBinkApiFunc;
  end = (
    OpenSmack: Ptr($63A464);
    OpenBink:  Ptr($63A390);
  );

  GetAdvMapTileVisibility: TGetAdvMapTileVisibility = Ptr($715A7E);
  GetBattleCellByPos:  TGetBattleCellByPos = Ptr($715872);
  MemAllocFunc:        TMemAllocFunc       = Ptr($617492);
  MemFree:             TMemFreeFunc        = Ptr($60B0F0);
  ComplexDlgResItemId: pinteger            = Ptr($699424);

  MapItemToCoords:  TMapItemToCoords  = Ptr($711EC6);
  CoordsToMixedPos: TCoordsToMixedPos = Ptr($711E7F);

  SecSkillNames:   PSecSkillNames = Ptr($698BC4);
  SecSkillDescs:   PSecSkillDescs = Ptr($698C34);
  SecSkillTexts:   PSecSkillTexts = Ptr($698D88);
  HeroBiographies: PHeroBiographiesTable = Ptr($778820); // Original biographies copy from txt by WoG

  Spells:       PSpells  = Ptr($7BD2C0);
  NumSpellsPtr: pinteger = Ptr($7751ED + 3);

  TextBuf:               PGeneralPurposeTextBuf = Ptr($697428);
  MonInfos:              PMonInfos = Ptr($7D0C90);
  MonAssignmentsPerTown: PMonAssignmentsPerTown = Ptr($6747B4);
  NumMonstersPtr:        pinteger  = Ptr($733326);
  ArtInfos:              PArtInfos = Ptr($7B6DA0);
  NumArtsPtr:            pinteger  = Ptr($7324BD);
  NumHeroes:             pinteger  = Ptr($7116B2);

  (* Variable is protected with two crit sections: pint(SOUND_MANAGER)^ + $a8 and pint(SOUND_MANAGER)^ + $c0 *)
  CurrentMp3Track: PCurrentMp3Track = Ptr($6A32F0);

  PlayerPalettesPtr: ^PPalette16 = Ptr($6AAD10);


var
{O} ResourceNamer: TResourceNamer;
{U} ResourceTree:  PBinaryTree = Ptr($69E560);


function  MemAlloc (Size: integer): {On} pointer;
procedure MemFreeAndNil (var p);
function  RandomRange (Min, Max: integer): integer;
procedure SRand (Seed: integer);
function  LoadTxt (Name: pchar): {n} PTxtFile; stdcall;
procedure LoadLod (const LodName: string; Res: PLod);
function  LoadDef (const DefName: string): {n} PDefItem;
function  LoadPcx8 (const PcxName: string): {n} PPcxItem;
function  LoadPcx16 (const PcxName: string): {n} PPcx16Item;

(* All colors should be int31 integer values *)
procedure Rgb96ToHsb (Red, Green, Blue: integer; out Hue, Saturation, Brightness: single); stdcall;

(* All colors should be int31 integer values *)
procedure HsbToRgb96 (var Red, Green: integer; Hue, Saturation, Brightness: single; var Blue: integer); stdcall;

procedure GetGameState (out GameState: TGameState); stdcall;
function  GetMapSize: integer;
function  IsTwoLevelMap: boolean;
function  IsLocalGame: boolean;
function  IsNetworkGame: boolean;
function  GetTownManager: PTownManager;
function  GetPlayer (PlayerId: integer): {n} PPlayer;
function  IsValidPlayerId (PlayerId: integer): boolean;
procedure SendNetData (DestPlayerId, MsgId: integer; {n} Data: pointer; DataSize: integer);

(* Returns this PC current human player ID or the last human player ID if it's HotSeat and it's AI turn *)
function GetThisPcHumanPlayerId: integer;

function  IsThisPcHumanTurn: boolean;
function  IsThisPcNetworkActiveSide: boolean;
function  GetObjectEntranceTile (MapTile: PMapTile): PMapTile;
function  PackCoords (x, y, z: integer): integer;
procedure UnpackCoords (PackedCoords: integer; var x, y, z: integer); overload;
procedure UnpackCoords (PackedCoords: integer; var Coords: TMapCoords); overload;
procedure MapTileToCoords (MapTile: PMapTile; var Coords: TMapCoords);
function  StackProp (StackId: integer; PropOfs: integer): PValue;
function  StackPtrToId (StackPtr: pointer): integer;
function  GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): integer;
function  GetStackIdByPos (StackPos: integer): integer;
procedure RedrawHeroMeetingScreen;
procedure HideHero (Hero: PHero);
procedure ShowHero (Hero: PHero);
procedure ShowBoat (Boat: PBoat);
function  IsCampaign: boolean;
function  GetMapFileName: string;
function  GetCampaignFileName: string;
function  GetCampaignMapInd: integer;
{Low level}
function  GetVal (BaseAddr: pointer; Offset: integer): PValue; overload;
function  GetVal (BaseAddr, Offset: integer): PValue; overload;

procedure PrintChatMsg (const Msg: string);
function  Msg
(
  const Mes:          string;
        MesType:      TMesType  = MES_MES;
        Pic1Type:     integer   = NO_PIC_TYPE;
        Pic1SubType:  integer   = 0;
        Pic2Type:     integer   = NO_PIC_TYPE;
        Pic2SubType:  integer   = 0;
        Pic3Type:     integer   = NO_PIC_TYPE;
        Pic3SubType:  integer   = 0
): integer;

procedure ShowMessage (const Mes: string);
function  Ask (const Question: string): boolean;
function  GetCurrentMp3Track: string;

(* Changes current MP3 theme to another one. Loop is used only if DontTrackPos = false *)
procedure ChangeMp3Theme (const Mp3TrackName: string; DontTrackPos: boolean = false; Loop: boolean = true);

procedure PauseMp3Theme;
procedure ResumeMp3Theme;
procedure PlaySound (FileName: pchar); stdcall; overload;
procedure PlaySound (FileName: string); overload;

function ParseTextTable (const TextTable: string): TTextTableCells;

(* Show H3 complex dialog with up to 8 pictures and text. Returns 0/1 for question or 0..7 for selected picture or -1 for cancel *)
function DisplayComplexDialog (Text: pchar; PicsConfig: pointer; MsgType: TMesType = MES_MES; TextAlignment: integer = -1; Timeout: integer = 15000): integer;


(***) implementation (***)

uses GameExt, EventMan;


function TArtInfo.GetTextField (Ind: integer): PValue;
begin
  if Ind = 0 then begin
    result := @Self.Name;
  end else if Ind = 1 then begin
    result := @Self.Desc;
  end else begin
    result := nil;
    {!} Assert(false, 'Cannot get TArtInfo field with invalid index ' + SysUtils.IntToStr(Ind));
  end;
end;

function TSpell.GetTextField (Ind: integer): PValue;
begin
  case Ind of
    0: result := @Self.Name;
    1: result := @Self.ShortName;
    2: result := @Self.Description[0];
    3: result := @Self.Description[1];
    4: result := @Self.Description[2];
    5: result := @Self.Description[3];
    6: result := @Self.SoundFileName;
  else
    result := nil;
    {!} Assert(false, 'Cannot get TSpell field with invalid index ' + SysUtils.IntToStr(Ind));
  end; // .switch Ind
end;

constructor TTextTable.Create (Cells: TTextTableCells);
var
  i: integer;

begin
  Self.fCells   := Cells;
  Self.fNumRows := Length(Cells);
  Self.fNumCols := 0;

  for i := 0 to Self.fNumRows - 1 do begin
    if Length(Cells[i]) > Self.fNumCols then begin
      Self.fNumCols := Length(Cells[i]);
    end;
  end;
end;

function TTextTable.GetItem (Row, Col: integer): string;
var
  RowItems: Utils.TArrayOfStr;

begin
  result := '';

  if (Row >= 0) and (Row < Self.fNumRows) then begin
    RowItems := Self.fCells[Row];

    if (Col >= 0) and (Col < Length(RowItems)) then begin
      result := RowItems[Col];
    end;
  end;
end;

procedure TNetData.Init;
begin
  System.FillChar(Self, sizeof(Self), #0);
  Self.StructSize := sizeof(Self);
end;

procedure TNetData.Send (aDestPlayerId: integer);
begin
  Self.PlayerId := -1;

  if aDestPlayerId = -1 then begin
    aDestPlayerId := 127;
  end;

  ApiJack.CallFast(Ptr($5549E0), int(@Self), aDestPlayerId, 0, 1);
end;

function TBattleStack.GetId: integer;
begin
  result := Self.Side * NUM_BATTLE_STACKS_PER_SIDE + Self.Index;
end;

function TCombatManager.GetActiveStack: PBattleStack;
Type
  TGetActiveStackMethod = function (CombatMgr: PCombatManager): PBattleStack; cdecl;

begin
  result := TGetActiveStackMethod(Ptr($75AF06))(@Self);
end;

procedure TCombatManager.RedrawGridAndSelection;
begin
  ApiJack.CallThis(Ptr($4773F0), int(@Self));
end;

procedure TInputMessageQueue.Enqueue (InputMsg: PInputMessage);
begin
  if Self.IsEnabled = 0 then begin
    exit;
  end;

  Self.Messages[Self.WritePosInd] := InputMsg^;
  Self.WritePosInd                := (Self.WritePosInd + 1) mod Length(Self.Messages);

  if Self.WritePosInd = Self.ReadPosInd then begin
    Self.ReadPosInd := (Self.ReadPosInd + 1) mod Length(Self.Messages);
  end;
end;

procedure TInputMessageQueue.AddTranslatedKeyInputMsg (KeyCode: integer; Modifiers: integer = 0);
var
  InputMessage: TInputMessage;

begin
  System.FillChar(InputMessage, sizeof(InputMessage), #0);
  InputMessage.MsgType          := INPUT_MES_KEYDOWN;
  InputMessage.Key.KeyCode      := KeyCode;
  InputMessage.Key.Modifiers    := Modifiers;
  InputMessage.Key.IsTranslated := ord(true);

  Self.Enqueue(@InputMessage);
end;

procedure SendNetData (DestPlayerId, MsgId: integer; {n} Data: pointer; DataSize: integer);
var
  NetDataBuf: Utils.TArrayOfByte;
  NetData:    PNetData;

begin
  {!} Assert(Utils.IsValidBuf(Data, DataSize));
  SetLength(NetDataBuf, sizeof(TNetData) + DataSize);
  NetData := pointer(NetDataBuf);
  NetData.Init;
  NetData.MsgId      := MsgId;
  NetData.StructSize := sizeof(TNetData) + DataSize;
  Utils.CopyMem(DataSize, Data, @NetData.RawData);
  NetData.Send(DestPlayerId);
end;

procedure PrintChatMsg (const Msg: string);
var
  EncodedMsg: string;
  PtrMsg:     pchar;

begin
  EncodedMsg := SysUtils.StringReplace(Msg, '%', '%%', [SysUtils.rfReplaceAll]);
  PtrMsg     := pchar(EncodedMsg);

  asm
    PUSH PtrMsg
    PUSH $69D800
    MOV EAX, $553C40
    CALL EAX
    ADD ESP, $8
  end;
end;

function Msg
(
  const Mes:          string;
        MesType:      TMesType  = MES_MES;
        Pic1Type:     integer   = NO_PIC_TYPE;
        Pic1SubType:  integer   = 0;
        Pic2Type:     integer   = NO_PIC_TYPE;
        Pic2SubType:  integer   = 0;
        Pic3Type:     integer   = NO_PIC_TYPE;
        Pic3SubType:  integer   = 0
): integer;

var
  MesStr:     pchar;
  MesTypeInt: integer;
  Res:        integer;

begin
  MesStr     := pchar(Mes);
  MesTypeInt := ORD(MesType);

  asm
    MOV ECX, MesStr
    PUSH Pic3SubType
    PUSH Pic3Type
    PUSH -1
    PUSH -1
    PUSH Pic2SubType
    PUSH Pic2Type
    PUSH Pic1SubType
    PUSH Pic1Type
    PUSH -1
    PUSH -1
    MOV EAX, $4F6C00
    MOV EDX, MesTypeInt
    CALL EAX
    MOV EAX, [WND_MANAGER]
    MOV EAX, [EAX + $38]
    MOV Res, EAX
  end; // .asm

  result := MSG_RES_OK;

  if MesType = MES_QUESTION then begin
    if Res = 30726 then begin
      result := MSG_RES_CANCEL;
    end // .if
  end else if MesType in [MES_CHOOSE, MES_MAY_CHOOSE] then begin
    case Res of
      30729: result := MSG_RES_LEFTPIC;
      30730: result := MSG_RES_RIGHTPIC;
    else
      result := MSG_RES_CANCEL;
    end; // .SWITCH Res
  end; // .elseif
end; // .function Msg

procedure ShowMessage (const Mes: string);
begin
  Msg(Mes);
end;

function Ask (const Question: string): boolean;
begin
  result := Msg(Question, MES_QUESTION) = MSG_RES_OK;
end;

function TExtString.ToString: string;
begin
  SetLength(result, Self.Len);
  Utils.CopyMem(Self.Len, Self.Value, pointer(result));
end;

procedure TH3Str.Reset;
begin
  Self.Value    := nil;
  Self.Len      := 0;
  Self.Capacity := 0;
end;

procedure TH3Str.Clear;
var
  RefCounterPtr: pshortint;

begin
  if (Self.Value <> nil) then begin
    RefCounterPtr := pointer(integer(Self.Value) - sizeof(byte));

    if (RefCounterPtr^ <> 0) and (RefCounterPtr^ <> H3STR_CONST_REF_COUNT) then begin
      Dec(RefCounterPtr^);
    end else begin
      MFree(RefCounterPtr);
    end;
  end;

  Self.Reset;
end;

procedure TH3Str.SetLen (NewLen: integer);
begin
  ApiJack.CallThis(Ptr($404B80), int(@Self), NewLen);
end;

procedure TH3Str.AssignPchar ({n} Str: pchar; StrLen: integer = -1);
begin
  if StrLen = -1 then begin
    if Str = nil then begin
      StrLen := 0;
    end else begin
      StrLen := Windows.LStrLen(Str);
    end;
  end;

  ApiJack.CallThis(Ptr($404180), int(@Self), int(Str), StrLen);
end;

function TWndManager.GetRootDlgId: integer;
begin
  result := 0;

  if WndManagerPtr^.RootDlg <> nil then begin
    result := integer(WndManagerPtr^.RootDlg.VTable[0]);
  end;
end;

function TWndManager.GetCurrentDlgId: integer;
begin
  result := 0;

  if WndManagerPtr^.CurrentDlg <> nil then begin
    result := integer(WndManagerPtr^.CurrentDlg.VTable[0]);
  end;
end;

procedure TDlgTextLines.Reset;
begin
  ApiJack.CallThis(Ptr($4B5D70), int(@Self), int(Self.FirstStr), int(Self.FirstFreeStr));
end;

procedure TDlgTextLines.AppendLine ({n} Line: pchar; LineLen: integer = -1);
var
  NewLine: TH3Str;

begin
  NewLine.Reset;
  NewLine.AssignPchar(Line, LineLen);
  ApiJack.CallThis(Ptr($4AF250), int(@Self), int(Self.FirstFreeStr), 1, int(@NewLine));
  NewLine.Clear;
end;

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
end;

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

function TBinaryTreeItem.GetName: string;
begin
  result := pchar(@Self.Name[0]);
end;

procedure TBinaryTreeItem.IncRef;
begin
  inc(Self.RefCount);
end;

procedure TBinaryTreeItem.DecRef;
begin
  ApiJack.CallThis(Self.VTable[1], int(@Self));
end;

procedure TBinaryTreeItem.Destruct (IsHeapObject: boolean = true);
begin
  ApiJack.CallThis(Self.VTable[0], int(@Self), ord(IsHeapObject));
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
    Node := PBinaryTreeNode(ApiJack.CallThis(Ptr($55EE00), int(@Self), int(pchar(aName))));

    if (Node <> Self.Parent) and (SysUtils.AnsiCompareText(aName, Node.Name) = 0) then begin
      aItem  := Node.Item;
      result := true;
    end;
  end;
end;

function TBinaryTreeNode.FindItem (aName: pchar; var {out} aItem: PBinaryTreeItem): boolean;
var
{U} Node: PBinaryTreeNode;

begin
  Node   := nil;
  result := false;
  // * * * * * //
  if (aName <> nil) and (aName^ <> #0) then begin
    Node := PBinaryTreeNode(ApiJack.CallThis(Ptr($55EE00), int(@Self), int(aName)));

    if (Node <> Self.Parent) and (StrLib.ComparePchars(aName, Node.Name) = 0) then begin
      aItem  := Node.Item;
      result := true;
    end;
  end;
end;

function TBinaryTreeNode.FindNode (const aName: string; var {out} aNode: PBinaryTreeNode): boolean;
var
{U} Node: PBinaryTreeNode;

begin
  Node   := nil;
  result := false;
  // * * * * * //
  if aName <> '' then begin
    Node := PBinaryTreeNode(ApiJack.CallThis(Ptr($55EE00), int(@Self), int(pchar(aName))));

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
  ApiJack.CallThis(Ptr($55DF20), int(@Self), int(@Temp), int(Node));
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

  ApiJack.CallThis(Ptr($55DDF0), int(@Self), int(@ResPtrs), int(@NewItem));
end;

function TDefItem.GetFrame (GroupInd, FrameInd: integer): {n} PDefFrame;
var
{U} DefGroup: PDefGroup;

begin
  result := nil;

  if Math.InRange(GroupInd, 0, Self.NumGroups - 1) then begin
    DefGroup := Self.Groups[GroupInd];

    if Math.InRange(FrameInd, 0, DefGroup.NumFrames - 1) then begin
      result := DefGroup.Frames[FrameInd];
    end;
  end;
end;

function TDefItem.DrawInterfaceDefGroupFrame (GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer;
                                              DoMirror, UsePaletteSpecialColors: boolean): integer;
begin
  result := ApiJack.CallThis(Ptr($47B610),
    int(@Self), GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight, int(Buf), DstX, DstY, DstW, DstH, ScanlineSize, ord(DoMirror), ord(UsePaletteSpecialColors)
  );
end;

procedure TPcx8Item.DrawToBuf (
  SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor: integer
);

begin
  ApiJack.CallThis(Ptr($44F940), int(@Self), SrcX, SrcY, SrcWidth, SrcHeight, int(Buf), DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor);
end;

procedure TPcx16Item.DrawToBuf (
  SrcX, SrcY, SrcWidth, SrcHeight: integer;
  Buf: pointer;
  DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor: integer
);

begin
  ApiJack.CallThis(Ptr($44DF80), int(@Self), SrcX, SrcY, SrcWidth, SrcHeight, int(Buf), DstX, DstY, DstW, DstH, aScanlineSize, TransparentColor);
end;

class function TPcx8ItemStatic.Create (const aName: string; aWidth, aHeight: integer): {On} PPcx8Item;
begin
  result := nil;

  if (aWidth <= 0) or (aHeight <= 0) then begin
    Debug.NotifyError(Format('Cannot create pcx8 image of size %dx%d', [aWidth, aHeight]));

    aWidth  := Utils.IfThen(aWidth > 0, aWidth, 1);
    aHeight := Utils.IfThen(aHeight > 0, aHeight, 1);
  end;

  if (aWidth > 0) and (aHeight > 0) then begin
    result := MemAlloc(Alg.IntRoundToBoundary(sizeof(result^), sizeof(integer)));

    FillChar(result^, sizeof(result^), 0);
    result.VTable          := Ptr($63BA14);
    result.SetName(aName);
    result.ItemType        := RES_TYPE_PCX_8;
    result.Width           := aWidth;
    result.Height          := aHeight;
    result.ScanlineSize    := Alg.IntRoundToBoundary(aWidth, sizeof(integer));
    result.BufSize         := result.ScanlineSize * aHeight;
    result.PicSize         := result.BufSize;
    result.Buffer          := MemAlloc(result.BufSize);

    System.FillChar(result.Palette16, sizeof(TBinaryTreeItem), #0);
    result.Palette16.RefCount := -1;

    System.FillChar(result.Palette24, sizeof(TBinaryTreeItem), #0);
    result.Palette24.RefCount := -1;
  end; // .if
end; // .function TPcx8ItemStatic.Create

class function TPcx16ItemStatic.Create (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item;
begin
  result := MemAlloc(Alg.IntRoundToBoundary(sizeof(result^), sizeof(integer)));
  ApiJack.CallThis(Ptr($44DD20), int(result), int(pchar(aName)), aWidth, aHeight);
  {!} Assert(result.RefCount = 0);
end;

class function TPcx16ItemStatic.Create_ (const aName: string; aWidth, aHeight: integer): {On} PPcx16Item;
begin
  result := nil;

  if (aWidth <= 0) or (aHeight <= 0) then begin
    Debug.NotifyError(Format('Cannot create pcx16 image of size %dx%d', [aWidth, aHeight]));

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
    result.ScanlineSize       := Alg.IntRoundToBoundary(aWidth * BytesPerPixelPtr^, sizeof(integer));
    result.BufSize            := result.ScanlineSize * aHeight;
    result.PicSize            := result.BufSize;
    result.HasDdSurfaceBuffer := false;
    result.Buffer             := MemAlloc(result.BufSize);
  end; // .if
end; // .function TPcx16ItemStatic.Create_

class function TPcx16ItemStatic.Load (const aName: string): {U} PPcx16Item;
begin
  result := PPcx16Item(ApiJack.CallThis(Ptr($55B1E0), int(pchar(aName))));
  {!} Assert(result <> nil, Format('Failed to load pcx16 image "%s". "dfault24.pcx" is also missing', [aName]));
  {!} Assert(result.IsPcx16(), Format('Loaded image "%s" is not requested pcx16', [aName]));
end;

class function TPcx24ItemStatic.Create (const aName: string; aWidth, aHeight: integer): {On} PPcx24Item;
begin
  result := nil;

  if (aWidth <= 0) or (aHeight <= 0) then begin
    Debug.NotifyError(Format('Cannot create pcx24 image of size %dx%d', [aWidth, aHeight]));

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
  ApiJack.CallThis(Ptr($44ECA0), int(@Self), SrcX, SrcY, Width, Height, int(Pcx16), DstX, DstY);
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
end;

function RandomRange (Min, Max: integer): integer;
begin
  result := ApiJack.CallFast(Ptr($50C7C0), Min, Max);
end;

procedure SRand (Seed: integer);
begin
  ApiJack.CallThis(Ptr($50C7B0), Seed);
end;

function GetVal (BaseAddr: pointer; Offset: integer): PValue; overload;
begin
  result := Utils.PtrOfs(BaseAddr, Offset);
end;

function GetVal (BaseAddr, Offset: integer): PValue; overload;
begin
  result := Utils.PtrOfs(Ptr(BaseAddr), Offset);
end;

class procedure SavegameWriter.Write (Size: integer; {n} Addr: pointer);
begin
  {!} Assert(Utils.IsValidBuf(Addr, Size));
  {!} Assert(ZvsWriteSavegame(Addr, Size) = 0, 'Failed to write ' + SysUtils.IntToStr(Size) + ' bytes to savegame');
end;

class procedure SavegameWriter.WriteInt (Value: integer);
begin
  SavegameWriter.Write(sizeof(Value), @Value);
end;

class procedure SavegameWriter.WriteStrWithLenField (const Str: string);
var
  StrLen: integer;

begin
  StrLen := Length(Str);
  SavegameWriter.WriteInt(StrLen);
  SavegameWriter.Write(StrLen, pointer(Str));
end;

class function SavegameReader.TryRead (Count: integer; {n} Addr: pointer): integer;
begin
  {!} Assert(Utils.IsValidBuf(Addr, Count));
  result := ZvsReadSavegame(Addr, Count) + Count;
end;

class procedure SavegameReader.Read (Count: integer; {n} Addr: pointer);
var
  BytesRead: integer;

begin
  BytesRead := SavegameReader.TryRead(Count, Addr);
  {!} Assert(BytesRead = Count, 'Failed to read ' + SysUtils.IntToStr(Count) + ' bytes from savegame. Bytes read: ' + SysUtils.IntToStr(BytesRead));
end;

class function SavegameReader.ReadInt: integer;
begin
  SavegameReader.Read(sizeof(result), @result);
end;

class function SavegameReader.ReadStrWithLenField: string;
var
  StrLen: integer;

begin
  StrLen := SavegameReader.ReadInt;
  {!} Assert(StrLen >= 0, 'Invalid string field length read from savegame: ' + SysUtils.IntToStr(StrLen));

  result := '';

  if StrLen > 0 then begin
    SetLength(result, StrLen);
    SavegameReader.Read(StrLen, pointer(result));
  end;
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

function LoadDef (const DefName: string): {n} PDefItem;
begin
  result := PDefItem(ApiJack.CallThis(Ptr($55C9C0), int(pchar(DefName))));
end;

function LoadPcx8 (const PcxName: string): {n} PPcxItem;
begin
  result := PPcxItem(ApiJack.CallThis(Ptr($55AA10), int(pchar(PcxName))));
end;

function LoadPcx16 (const PcxName: string): {n} PPcx16Item;
begin
  result := PPcx16Item(ApiJack.CallThis(Ptr($55AE50), int(pchar(PcxName))));
end;

procedure Rgb96ToHsb (Red, Green, Blue: integer; out Hue, Saturation, Brightness: single); stdcall; assembler; {$STACKFRAMES ON}
asm
  POP EBP
  POP EAX

  POP ECX
  POP EDX
  PUSH EAX
  MOV EAX, $523680
  JMP EAX
end;

procedure HsbToRgb96 (var Red, Green: integer; Hue, Saturation, Brightness: single; var Blue: integer); stdcall; assembler; {$STACKFRAMES ON}
asm
  POP EBP
  POP EAX

  POP ECX
  POP EDX
  PUSH EAX
  MOV EAX, $5237E0
  JMP EAX
end;

procedure GetGameState (out GameState: TGameState);
begin
  GameState.RootDlgId    := 0;
  GameState.CurrentDlgId := 0;

  if WndManagerPtr^ <> nil then begin
    GameState.RootDlgId    := WndManagerPtr^.GetRootDlgId;
    GameState.CurrentDlgId := WndManagerPtr^.GetCurrentDlgId;
  end;
end;

function GetMapSize: integer; assembler; {$W+}
asm
  MOV EAX, [GAME_MANAGER]
  MOV EAX, [EAX + $1FC44]
end;

function IsTwoLevelMap: boolean; assembler; {$W+}
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

function GetTownManager: PTownManager;
begin
  result := ppointer(TOWN_MANAGER)^;
end;

function IsValidPlayerId (PlayerId: integer): boolean; inline;
begin
  result := Math.InRange(PlayerId, PLAYER_FIRST, PLAYER_LAST)
end;

function GetPlayer (PlayerId: integer): {n} PPlayer;
begin
  result := nil;

  if IsValidPlayerId(PlayerId) then begin
    result := Utils.PtrOfs(ppointer(GAME_MANAGER)^, $20AD0 + sizeof(TPlayer) * PlayerId);
  end;
end;

function TPlayer.IsOnActiveNetworkSide: boolean;
var
  i: integer;

begin
  // For local game any player is on active side.
  // If tested player is current player, he is always on active side
  result := IsLocalGame or (Self.Id = CurrentPlayerId^);

  // Exit if it's current player, invalid player ID or non-current human player
  if result or not IsValidPlayerId(CurrentPlayerId^) or GetPlayer(CurrentPlayerId^).IsHuman then begin
    exit;
  end;

  // Check all players, skipping AI and finding the last human player
  // The AI is treated as resident on the last human player PC, though local human vs AI battles are performed on one PC
  i := PLAYER_LAST;

  while (i >= PLAYER_FIRST) and (not GetPlayer(i).IsHuman) do begin
    Dec(i);
  end;

  result := (i >= PLAYER_FIRST) and GetPlayer(i).IsThisPcHumanPlayer;
end;

function THero.HasArtOnDoll (ArtId: integer): boolean;
begin
  result := ApiJack.CallThis(Ptr($4D9460), int(@Self), ArtId) <> 0;
end;

function GetThisPcHumanPlayerId: integer;
begin
  result := ApiJack.CallThis(Ptr($4CE6E0), pinteger(GAME_MANAGER)^);
end;

function IsThisPcHumanTurn: boolean;
begin
  result := IsValidPlayerId(CurrentPlayerId^) and GetPlayer(CurrentPlayerId^).IsThisPcHumanPlayer;
end;

function IsThisPcNetworkActiveSide: boolean;
var
  ThisPcHumanPlayerId: integer;

begin
  ThisPcHumanPlayerId := GetThisPcHumanPlayerId;
  result              := IsValidPlayerId(ThisPcHumanPlayerId) and GetPlayer(ThisPcHumanPlayerId).IsOnActiveNetworkSide;
end;

function GetObjectEntranceTile (MapTile: PMapTile): PMapTile;
type
  TExtendedResult = packed record
    Hero:         PHero;
    Boat:         PBoat;
    MustHideHero: longbool;
  end;

var
  ExtendedRes: TExtendedResult;

begin
  with ExtendedRes do begin
    Hero         := nil;
    Boat         := nil;
    MustHideHero := false;
  end;

  result := PMapTile(ApiJack.CallThis(Ptr($40AF10), int(@ExtendedRes), int(MapTile), 0, 0));

  if ExtendedRes.Hero <> nil then begin
    ShowHero(ExtendedRes.Hero);
  end else if ExtendedRes.Boat <> nil then begin
    ShowBoat(ExtendedRes.Boat);
  end else if ExtendedRes.MustHideHero then begin
    HideHero(ExtendedRes.Hero);
  end;
end;

function PackCoords (x, y, z: integer): integer;
begin
  result := ((z and 1) shl 26) or ((y and $3FF) shl 16) or (x and $3FF);
end;

procedure UnpackCoords (PackedCoords: integer; var x, y, z: integer); overload;
begin
  x := PackedCoords and $3FF;
  y := (PackedCoords shr 16) and $3FF;
  z := (PackedCoords and $04000000) shr 26;
end;

procedure UnpackCoords (PackedCoords: integer; var Coords: TMapCoords); overload;
begin
  UnpackCoords(PackedCoords, Coords[0], Coords[1], Coords[2]);
end;

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

function StackProp (StackId: integer; PropOfs: integer): PValue; inline;
begin
  result := Utils.PtrOfs(ppointer(COMBAT_MANAGER)^, 21708 + STACK_STRUCT_SIZE * StackId + PropOfs);
end;

function GetStackIdByPos (StackPos: integer): integer;
type
  PStackField = ^TStackField;
  TStackField = packed record
    v:  integer;
  end;

const
  STACK_POS = $38;

var
  BattleCell: pointer;
  i:          integer;

begin
  BattleCell := GetBattleCellByPos(StackPos);
  result     := NO_STACK;

  if BattleCell <> nil then begin
    result := GetBattleCellStackId(BattleCell);
  end;

  if result = NO_STACK then begin
    for i := 0 to NUM_BATTLE_STACKS - 1 do begin
      if StackProp(i, STACK_POS).v = StackPos then begin
        result := i;

        if StackProp(i, STACK_NUM).v > 0 then begin
          exit;
        end;
      end;
    end;
  end; // .if
end; // .function GetStackIdByPos

function StackPtrToId (StackPtr: pointer): integer;
begin
  result := integer((cardinal(StackPtr) - cardinal(StackProp(0, 0))) div STACK_STRUCT_SIZE);

  if (result < 0) or (result >= NUM_BATTLE_STACKS) then begin
    result := GetStackIdByPos(pinteger(integer(StackPtr) + STACK_POS)^);
  end;
end;

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

procedure HideHero (Hero: PHero);
begin
  ApiJack.CallThis(Ptr($4D7950), int(Hero));
end;

procedure ShowHero (Hero: PHero);
const
  TYPE_HERO = 34;

begin
  ApiJack.CallThis(Ptr($4D7840), int(Hero), TYPE_HERO, Hero.Id);
end;

procedure ShowBoat (Boat: PBoat);
const
  TYPE_BOAT = 8;

begin
  ApiJack.CallThis(Ptr($4D7840), int(Boat), TYPE_BOAT, Boat.Index);
end;

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

function GetCurrentMp3Track (): string;
begin
  (* Note, $A8 critsection lock of sound manager is not necessary and can take up to several seconds *)
  Windows.EnterCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $C0)^);
  result := pchar(@CurrentMp3Track[0]);
  Windows.LeaveCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $C0)^);
end;

procedure ChangeMp3Theme (const Mp3TrackName: string; DontTrackPos: boolean = false; Loop: boolean = true);
begin
  ApiJack.CallThis(Ptr($59AFB0), pinteger(SOUND_MANAGER)^, int(pchar(Mp3TrackName)), ord(DontTrackPos), ord(Loop));
end;

procedure PauseMp3Theme;
begin
  ApiJack.CallThis(Ptr($59B380), pinteger(SOUND_MANAGER)^);
end;

procedure ResumeMp3Theme;
begin
  ApiJack.CallThis(Ptr($59AF00), pinteger(SOUND_MANAGER)^);
end;

procedure PlaySound (FileName: pchar); stdcall; overload;
begin
  asm
    mov ecx, FileName
    mov edx, -1
    push 3
    mov eax, $59A890
    call eax
  end;
end;

procedure PlaySound (FileName: string); overload;
begin
  PlaySound(pchar(FileName));
end;

function ParseTextTable (const TextTable: string): TTextTableCells;
const
  ROW_DELIM = #13#10;
  COL_DELIM = #9;

var
  Lines: Utils.TArrayOfStr;
  i:     integer;

begin
  result := nil;

  if TextTable <> '' then begin
    Lines := StrLib.Explode(TextTable, ROW_DELIM);

    // Always exclude the last empty row
    SetLength(result, Length(Lines) - 1);

    for i := 0 to Length(Lines) - 2 do begin
      result[i] := StrLib.Explode(Lines[i], COL_DELIM);
    end;
  end;
end; // .function ParseTextTable

function DisplayComplexDialog (Text: pchar; PicsConfig: pointer; MsgType: TMesType = MES_MES; TextAlignment: integer = -1; Timeout: integer = 15000): integer;
const
  ITEM_OK        = 30725;
  ITEM_PIC_FIRST = 30729;
  ITEM_PIC_LAST  = 30737;

var
  Opts:      integer;
  ResItemId: integer;

begin
  Opts      := (((TextAlignment + 1) and $0F) shl 20) or ((ord(MsgType) and $0F) shl 16) or (Timeout and $FFFF);
  ApiJack.CallFast(Ptr($4F7D20), int(Text), int(PicsConfig), -1, -1, Opts);
  ResItemId := WndManagerPtr^.DlgResItemId shr 8;

  result := -1;

  if MsgType = MES_QUESTION then begin
    result := ord(ResItemId = ITEM_OK);
  end else if MsgType in [MES_CHOOSE, MES_MAY_CHOOSE] then begin
    if (ResItemId >= ITEM_PIC_FIRST) and (ResItemId <= ITEM_PIC_LAST) then begin
      result := ResItemId - ITEM_PIC_FIRST;
    end else begin
      result := -1;
    end;
  end;
end;

procedure OnAfterStructRelocations (Event: GameExt.PEvent); stdcall;
begin
  SecSkillNames         := ppointer($4E6C00)^;
  SecSkillDescs         := ppointer($4E6C10)^;
  SecSkillTexts         := ppointer($4E6C1A)^;
  HeroBiographies       := ppointer($7466D4)^;
  MonInfos              := ppointer($6747B0)^;
  MonAssignmentsPerTown := ppointer($428605)^;
  ArtInfos              := ppointer($660B68)^;
  Spells                := ppointer($687FA8)^;
  CursorHotspotsX       := ppointer($50D09D)^;
  CursorHotspotsY       := ppointer($50D0AF)^;
end;

begin
  ResourceNamer := TResourceNamer.Create;
  EventMan.GetInstance.On('OnAfterStructRelocations', OnAfterStructRelocations);
end.
