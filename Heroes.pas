unit Heroes;
{
DESCRIPTION:  Internal game functions and structures
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Math,
  Utils, PatchApi, DataLib, TypeWrappers, Alg, StrLib, DlgMes,
  Core;

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

  (* Game settings *)
  DEFAULT_GAME_SETTINGS_FILE = 'default heroes3.ini';
  GAME_SETTINGS_FILE         = 'heroes3.ini';
  GAME_SETTINGS_SECTION      = 'Settings';

  (* Stacks on battlefield *)
  NUM_BATTLE_STACKS          = 42;
  NUM_BATTLE_STACKS_PER_SIDE = 21;

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

  LOAD_TXT_FUNC   = $55C2B0;  // F (Name: pchar); FASTCALL;
  UNLOAD_TXT_FUNC = $55D300;  // F (PTxtFile); FASTCALL;
  { F ( Name: PCHAR; AddExt: LONGBOOL; ShowDialog: LONGBOOL; Compress: INTBOOL; SaveToData: LONGBOOL); THISCALL ([GAME_MANAGER]); }
  SAVEGAME_FUNC     = $4BEB60;
  LOAD_LOD          = $559420;  // F (Name: pchar); THISCALL (PLod);
  LOAD_LODS         = $559390;
  LOAD_DEF_SETTINGS = $50B420;  // F();
  SMACK_OPEN        = $63A464;  // F(FileName: pchar; BufSize, BufMask: int): HANDLE or 0; stdcall;
  BINK_OPEN         = $63A390;  // F(hFile, BufMask or $8000000: int): HANDLE or 0; stdcall;

  (* Limits *)
  MAX_MONS_IN_STACK = 32767;

  hWnd:           pinteger  = Ptr($699650);
  hHeroes3Event:  pinteger  = Ptr($69965C);
  MarkedSavegame: pchar     = Ptr($68338C);
  Mp3Name:        pchar     = Ptr($6A33F4);
  GameType:       PGameType = Ptr($698A40);
  GameVersion:    pinteger  = Ptr($67F554);

  (* Managers *)
  GAME_MANAGER   = $699538;
  TOWN_MANAGER   = $69954C;
  WND_MANAGER    = $6992D0;
  SOUND_MANAGER  = $699414;
  COMBAT_MANAGER = $699420;

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

type
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
    Id:                byte;
    NumHeroes:         byte;
    Unk1:              array [1..2] of byte;
    ActiveHeroId:      integer;
    VisibleHeroIds:    array [0..7] of integer;
    TavernLeftHeroId:  integer;
    TavernRightHeroId: integer;
    Unk2:              array [1..13] of byte;
    DaysLeft:          byte;
    NumTowns:          byte;
    ActiveTownInd:     byte;
    TownIds:           array [0..47] of byte;
    Unk3:              array [1..113] of byte; // +$70
    IsThisPcPlayer:    boolean;                // +$E1
    Unk:               array [1..134] of byte;
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
    PoxX:             integer;
    PoxY:             integer;
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

  PPAdvManager = ^PAdvManager;
  PAdvManager  = ^TAdvManager;
  TAdvManager  = packed record
    _0:         array [1..80] of byte;
    RootDlg:    PDlg;
    CurrentDlg: PDlg;

    function GetRootDlgId:    integer;
    function GetCurrentDlgId: integer;
  end;

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

  PPGameManager = ^PGameManager;
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

  PPCombatManager = ^PCombatManager;
  PCombatManager  = ^TCombatManager;
  TCombatManager  = packed record
    Dummy:     array [1..$13D68] of byte;
    IsTactics: boolean;
    Align_1:   array [1..3] of byte;
    Round:     integer;
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
  end; // .TCombatManager

  PScreenPcx16  = ^TScreenPcx16;
  TScreenPcx16  = packed record
    Dummy:  array [0..35] of byte;
    Width:  integer;
    Height: integer;
    (* Dummy *)
  end; // .record TScreenPcx16

  PWndManager = ^TWndManager;
  TWndManager = packed record
    _1:           array [1..55] of byte;
    DlgResItemId: integer;
    _2:           array [60..64] of byte;
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

  PCurrentMp3Track = ^TCurrentMp3Track;
  TCurrentMp3Track = array [0..255] of char;

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

  TDrawImageFlag  = (DFL_CROP, DFL_MIRROR, DFL_NO_SPECIAL_PALETTE_COLORS);
  TDrawImageFlags = set of TDrawImageFlag;

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
  PPalette16 = ^TPalette16;
  TPalette16 = object (TBinaryTreeItem)
   public
    Colors: array [0..255] of word;
  end;
  {$ALIGN ON}

  {$ALIGN OFF}
  PPalette24 = ^TPalette24;
  TPalette24 = object (TBinaryTreeItem)
   public
    Colors: array [0..255] of integer;
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

    procedure DrawFrameToBufEx (SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer; Palette16: PPalette16; DrawFlags: TDrawImageFlags = []);
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

    function  GetFrame (GroupInd, FrameInd: integer): {n} PDefFrame;
    function  GetFrameWidth (GroupInd, FrameInd: integer): integer;
    function  GetFrameHeight (GroupInd, FrameInd: integer): integer;
    procedure DrawFrameToBuf (GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer; DrawFlags: TDrawImageFlags = []);
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
    MonTypes:     array [0..6] of integer;        // +91  dd*7  = tip suschestv (-1 - net)
    MonNums:      array [0..6] of integer;        // +AD  dd*7  = kolichestvo
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
    IArt:         array [0..18, 0..1] of integer; // +12D dd*2*13h = artifakty dd-nomer,dd-(FF) (kniga 3,FF)
    FreeAddSlots: byte;                           // +1C5 kolichestvo pustyh dop. slotov sleva
    LockedSlot:   array [0..13] of byte;          // +1C6
    OArt:         array [0..63, 0..1] of integer; // +1D4 dd*2*40 = art v ryukzake dd-nomer, dd-(FF)
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
    GuardTypes:    array [0..6] of integer;      // +E0 = ohrana zamka
    GuardNums:     array [0..6] of integer;      // +FC = kol-vo ohrany
    GuardsT0:      array [0..6] of integer;      // +118 = ohrana zamka
    GuardsN0:      array [0..6] of integer;      // +134 = kol-vo ohrany
    Built:         array [0..7] of byte;         // +150h = uzhe postroennye zdaniya (0400)
    Bonus:         array [0..7] of byte;         // +158h = bonus na suschestv, resursy i t.p., vyzvannyj stroeniyami
    BMask:         array [0..1] of integer;      // +160h = maska dostupnyh dlya stroeniya stroenij
  end; // .record TTown

  TTowns = packed array [0..999] of TTown;
  PTowns = ^TTowns;

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

const
  MAlloc:    TMAlloc = Ptr($617492);
  MFree:     TMFree  = Ptr($60B0F0);
  ZvsRandom: function (MinValue, MaxValue: integer): integer cdecl = Ptr($710509);

  AdvManagerPtr:    PPAdvManager    = Ptr($6992D0);
  WndManagerPtr:    ^PWndManager    = Ptr($6992D0); // CHECKME!
  GameManagerPtr:   PPGameManager   = Ptr(GAME_MANAGER);
  CombatManagerPtr: PPCombatManager = Ptr(COMBAT_MANAGER);

  CurrentPlayerId:  pinteger   = Ptr($69CCF4);
  GameDate:         ^PGameDate = Ptr($840CE0);
  BytesPerPixelPtr: pbyte      = Ptr($5FA228 + 3);

  ZvsGzipWrite:   TGzipWrite = Ptr($704062);
  ZvsGzipRead:    TGzipRead  = Ptr($7040A7);
  WndProc:        TWndProc   = Ptr($4F8290);
  ZvsGetHero:     function (HeroId: integer): {n} PHero cdecl = Ptr($71168D);
  ZvsGetTowns:    function: {n} PTowns cdecl = Ptr($711BD4);
  ZvsCountTowns:  function: integer = Ptr($711C0E);
  ZvsLoadTxtFile: function (FilePath: pchar; var TxtFile: TTxtFile): longbool cdecl = Ptr($777030); // true on error
  ZvsGetTxtValue: function (Row, Col: integer; TxtFile: PTxtFile): pchar cdecl = Ptr($77710B);
  ZvsFindNextObjects: function (ObjType, ObjSubtype: integer; var x, y, z: integer; Direction: integer): longbool cdecl = Ptr($72F67B);
  ZvsFindObjects: function (ObjType, ObjSubtype, ObjectN: integer; var x, y, z: integer): longbool cdecl = Ptr($72F539);
  ZvsChangeHeroPortraitN: procedure (DstHeroId, SrcHeroId: integer) cdecl = Ptr($753ABF);
  ZvsChangeHeroPortrait: procedure (HeroId: integer; {n} LargePortrait, {n} SmallPortrait: pchar) cdecl = Ptr($7539A6);
  ZvsRedrawMap:   procedure = Ptr($7126EA);
  a2i:            function (Str: pchar): int cdecl = Ptr($6184D9);
  a2f:            function (Str: pchar): single cdecl = Ptr($619366);

  GetBattleCellByPos:  TGetBattleCellByPos = Ptr($715872);
  MemAllocFunc:        TMemAllocFunc       = Ptr($617492);
  MemFree:             TMemFreeFunc        = Ptr($60B0F0);
  ComplexDlgResItemId: pinteger            = Ptr($699424);

  MapItemToCoords:  TMapItemToCoords  = Ptr($711EC6);
  CoordsToMixedPos: TCoordsToMixedPos = Ptr($711E7F);

  SecSkillNames: PSecSkillNames = Ptr($698BC4);
  SecSkillDescs: PSecSkillDescs = Ptr($698C34);
  SecSkillTexts: PSecSkillTexts = Ptr($698D88);

  TextBuf:        PGeneralPurposeTextBuf = Ptr($697428);
  MonInfos:       PMonInfos = Ptr($7D0C90);
  NumMonstersPtr: pinteger  = Ptr($733326);
  ArtInfos:       PArtInfos = Ptr($660B68);
  NumArtsPtr:     pinteger  = Ptr($7324BD);
  NumHeroes:      pinteger  = Ptr($7116B2);

  (* Variable is protected with two crit sections: pint(SOUND_MANAGER)^ + $a8 and pint(SOUND_MANAGER)^ + $c0 *)
  CurrentMp3Track: PCurrentMp3Track = Ptr($6A32F0);


var
{O} ResourceNamer: TResourceNamer;
{U} ResourceTree:  PBinaryTree = Ptr($69E560);


function  MemAlloc (Size: integer): {On} pointer;
procedure MemFreeAndNil (var p);
function  Rand (Min, Max: integer): integer;
procedure SRand (Seed: integer);
procedure GZipWrite (Count: integer; {n} Addr: pointer);
function  GzipRead (Count: integer; {n} Addr: pointer): integer;
function  LoadTxt (Name: pchar): {n} PTxtFile; stdcall;
procedure LoadLod (const LodName: string; Res: PLod);
function  LoadDef (const DefName: string): {n} PDefItem;
function  LoadPcx8 (const PcxName: string): {n} PPcxItem;
procedure GetGameState (out GameState: TGameState); stdcall;
function  GetMapSize: integer;
function  IsTwoLevelMap: boolean;
function  IsLocalGame: boolean;
function  IsNetworkGame: boolean;
function  GetTownManager: PTownManager;
function  GetPlayer (PlayerId: integer): {n} PPlayer;

(* Returns this PC current human player ID *)
function GetThisPcPlayerId: integer;

function  IsThisPcTurn: boolean;
function  GetObjectEntranceTile (MapTile: PMapTile): PMapTile;
function  PackCoords (x, y, z: integer): integer;
procedure UnpackCoords (PackedCoords: integer; var x, y, z: integer); overload;
procedure UnpackCoords (PackedCoords: integer; var Coords: TMapCoords); overload;
procedure MapTileToCoords (MapTile: PMapTile; var Coords: TMapCoords);
function  StackProp (StackId: integer; PropOfs: integer): PValue;
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

procedure PrintChatMsg (const Msg: string);
var
  PtrMsg: pchar;

begin
  PtrMsg := pchar(Msg);
  // * * * * * //
  asm
    PUSH PtrMsg
    PUSH $69D800
    MOV EAX, $553C40
    CALL EAX
    ADD ESP, $8
  end; // .asm
end; // .procedure PrintChatMsg

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
  PatchApi.Call(THISCALL_, Ptr($404B80), [@Self, NewLen]);
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

  PatchApi.Call(THISCALL_, Ptr($404180), [@Self, Str, StrLen]);
end;

function TAdvManager.GetRootDlgId: integer;
begin
  result := 0;

  if AdvManagerPtr^.RootDlg <> nil then begin
    result := integer(AdvManagerPtr^.RootDlg.VTable[0]);
  end;
end;

function TAdvManager.GetCurrentDlgId: integer;
begin
  result := 0;

  if AdvManagerPtr^.CurrentDlg <> nil then begin
    result := integer(AdvManagerPtr^.CurrentDlg.VTable[0]);
  end;
end;

procedure TDlgTextLines.Reset;
begin
  PatchApi.Call(THISCALL_, Ptr($4B5D70), [@Self, Self.FirstStr, Self.FirstFreeStr]);
end;

procedure TDlgTextLines.AppendLine ({n} Line: pchar; LineLen: integer = -1);
var
  NewLine: TH3Str;

begin
  NewLine.Reset;
  NewLine.AssignPchar(Line, LineLen);
  PatchApi.Call(THISCALL_, Ptr($4AF250), [@Self, Self.FirstFreeStr, 1, @NewLine]);
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

procedure TDefFrame.DrawFrameToBufEx (SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer; Palette16: PPalette16; DrawFlags: TDrawImageFlags = []);
var
  SrcMaxWidth:  integer;
  SrcMaxHeight: integer;

begin
  if (SrcWidth <= 0) or (SrcHeight <= 0) or (DstX >= DstW) or (DstY >= DstH) then begin
    exit;
  end;

  if DFL_CROP in DrawFlags then begin
    SrcMaxWidth  := Self.FrameWidth;
    SrcMaxHeight := Self.FrameHeight;
  end else begin
    SrcMaxWidth  := Self.DefWidth;
    SrcMaxHeight := Self.DefHeight;
  end;

  if SrcX < 0 then begin
    Inc(SrcWidth, SrcX);
    SrcX := 0;
  end;

  if SrcY < 0 then begin
    Inc(SrcHeight, SrcY);
    SrcY := 0;
  end;

  if (SrcWidth <= 0) or (SrcHeight <= 0) then begin
    exit;
  end;

  SrcWidth  := Math.Min(SrcMaxWidth,  SrcWidth - SrcX);
  SrcHeight := Math.Min(SrcMaxHeight, SrcHeight - SrcY);

  if DFL_CROP in DrawFlags then begin
    if DFL_MIRROR in DrawFlags then begin
      Inc(SrcX, Self.DefWidth - Self.FrameLeft - Self.FrameWidth)
    end else begin
      Inc(SrcX, Self.FrameLeft);
    end;

    Inc(SrcY, Self.FrameTop);
  end;

  PatchApi.Call(THISCALL_, Ptr($47BE90), [@Self, SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, Palette16, ord(DFL_MIRROR in DrawFlags), ord(not (DFL_NO_SPECIAL_PALETTE_COLORS in DrawFlags))]);
end; // .procedure TDefFrame.DrawFrameToBufEx

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

function TDefItem.GetFrameWidth (GroupInd, FrameInd: integer): integer;
var
{U} DefFrame: PDefFrame;

begin
  DefFrame := Self.GetFrame(GroupInd, FrameInd);

  if DefFrame <> nil then begin
    result := DefFrame.FrameWidth;
  end else begin
    result := 0;
  end;
end;

function TDefItem.GetFrameHeight (GroupInd, FrameInd: integer): integer;
var
{U} DefFrame: PDefFrame;

begin
  DefFrame := Self.GetFrame(GroupInd, FrameInd);

  if DefFrame <> nil then begin
    result := DefFrame.FrameHeight;
  end else begin
    result := 0;
  end;
end;

procedure TDefItem.DrawFrameToBuf (GroupInd, FrameInd, SrcX, SrcY, SrcWidth, SrcHeight: integer; Buf: pointer; DstX, DstY, DstW, DstH, ScanlineSize: integer; DrawFlags: TDrawImageFlags = []);
var
{U} DefFrame: PDefFrame;

begin
  DefFrame := Self.GetFrame(GroupInd, FrameInd);

  if DefFrame <> nil then begin
    DefFrame.DrawFrameToBufEx(SrcX, SrcY, SrcWidth, SrcHeight, Buf, DstX, DstY, DstW, DstH, ScanlineSize, Self.Palette16, DrawFlags);
  end;
end;

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

function Rand (Min, Max: integer): integer;
begin
  result := PatchApi.Call(FASTCALL_, Ptr($50C7C0), [Min, Max]);
end;

procedure SRand (Seed: integer);
begin
  PatchApi.Call(THISCALL_, Ptr($50C7B0), [Seed]);
end;

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

function LoadDef (const DefName: string): {n} PDefItem;
begin
  result := PDefItem(PatchApi.Call(THISCALL_, Ptr($55C9C0), [pchar(DefName)]));
end;

function LoadPcx8 (const PcxName: string): {n} PPcxItem;
begin
  result := PPcxItem(PatchApi.Call(THISCALL_, Ptr($55AA10), [pchar(PcxName)]));
end;

procedure GetGameState (out GameState: TGameState);
begin
  GameState.RootDlgId    := AdvManagerPtr^.GetRootDlgId;
  GameState.CurrentDlgId := AdvManagerPtr^.GetCurrentDlgId;
end;

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

function GetTownManager: PTownManager;
begin
  result := ppointer(TOWN_MANAGER)^;
end;

function GetPlayer (PlayerId: integer): {n} PPlayer;
begin
  result := nil;

  if Math.InRange(PlayerId, PLAYER_FIRST, PLAYER_LAST)  then begin
    result := Utils.PtrOfs(ppointer(GAME_MANAGER)^, $20AD0 + sizeof(TPlayer) * PlayerId);
  end;
end;

function GetThisPcPlayerId: integer;
begin
  result := PatchApi.Call(THISCALL_, Ptr($4CE6E0), [ppointer(GAME_MANAGER)^]);
end;

function IsThisPcTurn: boolean;
var
  Player: PPlayer;

begin
  Player := GetPlayer(CurrentPlayerId^);
  result := (Player <> nil) and (Player.IsThisPcPlayer);
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

  result := PMapTile(PatchApi.Call(THISCALL_, Ptr($40AF10), [integer(@ExtendedRes), integer(MapTile), 0, 0]));

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
  result := Utils.PtrOfs(ppointer(COMBAT_MANAGER)^, 21708 + 1352 * StackId + PropOfs);
end;

function GetStackIdByPos (StackPos: integer): integer;
type
  PStackField = ^TStackField;
  TStackField = packed record
    v:  integer;
  end; // .record TStackField

const
  NO_STACK  = -1;
  STACK_POS = $38;

var
  i: integer;

begin
  result := NO_STACK;

  for i := 0 to NUM_BATTLE_STACKS - 1 do begin
    if StackProp(i, STACK_POS).v = StackPos then begin
      result := i;

      if StackProp(i, STACK_NUM).v > 0 then begin
        exit;
      end;
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

procedure HideHero (Hero: PHero);
begin
  PatchApi.Call(THISCALL_, Ptr($4D7950), [Hero]);
end;

procedure ShowHero (Hero: PHero);
const
  TYPE_HERO = 34;

begin
  PatchApi.Call(THISCALL_, Ptr($4D7840), [Hero, TYPE_HERO, Hero.Id]);
end;

procedure ShowBoat (Boat: PBoat);
const
  TYPE_BOAT = 8;

begin
  PatchApi.Call(THISCALL_, Ptr($4D7840), [Boat, TYPE_BOAT, Boat.Index]);
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
  // Windows.EnterCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $A8)^);
  Windows.EnterCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $C0)^);
  result := pchar(@CurrentMp3Track[0]);
  Windows.LeaveCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $C0)^);
 // Windows.LeaveCriticalSection(PRtlCriticalSection(pinteger(SOUND_MANAGER)^ + $A8)^);
end;

procedure ChangeMp3Theme (const Mp3TrackName: string; DontTrackPos: boolean = false; Loop: boolean = true);
begin
  PatchApi.Call(THISCALL_, Ptr($59AFB0), [pinteger(SOUND_MANAGER)^, pchar(Mp3TrackName), ord(DontTrackPos), ord(Loop)]);
end;

procedure PauseMp3Theme;
begin
  PatchApi.Call(THISCALL_, Ptr($59B380), [pinteger(SOUND_MANAGER)^]);
end;

procedure ResumeMp3Theme;
begin
  PatchApi.Call(THISCALL_, Ptr($59AF00), [pinteger(SOUND_MANAGER)^]);
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
  PatchApi.Call(FASTCALL_, Ptr($4F7D20), [Text, PicsConfig, -1, -1, Opts]);
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
end; // .function DisplayComplexDialog

procedure OnAfterStructRelocations (Event: GameExt.PEvent); stdcall;
begin
  SecSkillNames := GameExt.GetRealAddr(SecSkillNames);
  SecSkillDescs := GameExt.GetRealAddr(SecSkillDescs);
  SecSkillTexts := GameExt.GetRealAddr(SecSkillTexts);
  MonInfos      := GameExt.GetRealAddr(MonInfos);
  ArtInfos      := ppointer(ArtInfos)^;
end;

begin
  ResourceNamer := TResourceNamer.Create;
  EventMan.GetInstance.On('OnAfterStructRelocations', OnAfterStructRelocations);
end.
