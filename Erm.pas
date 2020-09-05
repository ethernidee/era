unit Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Math, Windows,
  Utils, Crypto, TextScan, AssocArrays, DataLib, CFiles, Files, Ini, TypeWrappers, ApiJack,
  Lists, StrLib, Alg, RandMt,
  Core, Heroes, GameExt, Trans, RscLists, EventMan, DlgMes;

type
  (* Import *)
  TAssocArray = AssocArrays.TAssocArray;
  TStrList    = DataLib.TStrList;
  TDict       = DataLib.TDict;
  TList       = DataLib.TList;
  TString     = TypeWrappers.TString;
  TResource   = RscLists.TResource;

const
  ERM_SCRIPTS_SECTION      = 'Era.ErmScripts';
  ERT_STRINGS_SECTION      = 'Era.ErtStrings';
  FUNC_NAMES_SECTION       = 'Era.FuncNames';
  ERM_SCRIPTS_PATH         = 'Data\s';
  ERS_FILES_PATH           = 'Data\s';
  EXTRACTED_SCRIPTS_PATH   = GameExt.DEBUG_DIR + '\Scripts';
  ERM_TRACKING_REPORT_PATH = DEBUG_DIR + '\erm tracking.erm';

  (* Erm command conditions *)
  LEFT_COND  = 0;
  RIGHT_COND = 1;
  COND_AND   = 0;
  COND_OR    = 1;

  (* ERM param check type *)
  // 0=nothing, 1?, 2=, 3<>, 4>, 5<, 6>=, 7<=
  PARAM_CHECK_NONE          = 0;
  PARAM_CHECK_GET           = 1;
  PARAM_CHECK_EQUAL         = 2;
  PARAM_CHECK_NOT_EQUAL     = 3;
  PARAM_CHECK_GREATER       = 4;
  PARAM_CHECK_LOWER         = 5;
  PARAM_CHECK_GREATER_EQUAL = 6;
  PARAM_CHECK_LOWER_EQUAL   = 7;

  (* ERM param variable types *)
  PARAM_VARTYPE_NUM   = 0;
  PARAM_VARTYPE_FLAG  = 1;
  PARAM_VARTYPE_QUICK = 2;
  PARAM_VARTYPE_V     = 3;
  PARAM_VARTYPE_W     = 4;
  PARAM_VARTYPE_X     = 5;
  PARAM_VARTYPE_Y     = 6;
  PARAM_VARTYPE_Z     = 7;
  PARAM_VARTYPE_E     = 8;
  PARAM_VARTYPE_I     = 9;
  PARAM_VARTYPE_S     = 11;
  PARAM_VARTYPE_STR   = 12;
  PARAM_VARTYPE_NONE  = 15; // Special marker for non-initialized parameters to be ignored in Apply-like functions

  PARAM_VARTYPES_MUTABLE       = [PARAM_VARTYPE_QUICK, PARAM_VARTYPE_V, PARAM_VARTYPE_W, PARAM_VARTYPE_X, PARAM_VARTYPE_Y, PARAM_VARTYPE_Z, PARAM_VARTYPE_E, PARAM_VARTYPE_I, PARAM_VARTYPE_S];
  PARAM_VARTYPES_VALUES        = [PARAM_VARTYPE_NUM, PARAM_VARTYPE_STR];
  PARAM_VARTYPES_INTS          = [PARAM_VARTYPE_NUM, PARAM_VARTYPE_QUICK, PARAM_VARTYPE_V, PARAM_VARTYPE_W, PARAM_VARTYPE_X, PARAM_VARTYPE_Y, PARAM_VARTYPE_I];
  PARAM_VARTYPES_ARRAYISH_INTS = [PARAM_VARTYPE_V, PARAM_VARTYPE_W, PARAM_VARTYPE_X, PARAM_VARTYPE_Y];
  PARAM_VARTYPES_FLOATS        = [PARAM_VARTYPE_E];
  PARAM_VARTYPES_NUMERIC       = PARAM_VARTYPES_INTS + PARAM_VARTYPES_FLOATS;
  PARAM_VARTYPES_STRINGS       = [PARAM_VARTYPE_Z, PARAM_VARTYPE_S, PARAM_VARTYPE_STR];

  PARAM_MODIFIER_NONE    = 0;
  PARAM_MODIFIER_ADD     = 1;
  PARAM_MODIFIER_SUB     = 2;
  PARAM_MODIFIER_MUL     = 3;
  PARAM_MODIFIER_DIV     = 4;
  PARAM_MODIFIER_MOD     = 5;
  PARAM_MODIFIER_OR      = 6;
  PARAM_MODIFIER_AND_NOT = 7;
  PARAM_MODIFIER_SHL     = 8;
  PARAM_MODIFIER_SHR     = 9;

  (* Normalized ERM parameter value types *)
  VALTYPE_INT   = 0;
  VALTYPE_FLOAT = 1;
  VALTYPE_BOOL  = 2;
  VALTYPE_STR   = 3;
  VALTYPE_ERROR = 999;

  ERM_MAX_FLOAT = 3.4e38;
  ERM_MIN_FLOAT = -3.4e38;

  ERM_CMD_MAX_PARAMS_NUM = 16;
  MIN_ERM_SCRIPT_SIZE    = Length('ZVSE'#13#10);
  LINE_END_MARKER        = #10;

  CONST_NAME_CHARSET = ['A'..'Z', '0'..'9', '_'];

  (* Erm script state*)
  SCRIPT_NOT_USED = 0;
  SCRIPT_IS_USED  = 1;
  SCRIPT_IN_MAP   = 2;

  AltScriptsPath: pchar     = Ptr($2730F68);
  CurrErmEventId: pinteger  = Ptr($27C1950);

  (* Trigger if-else-then *)
  ZVS_TRIGGER_IF_TRUE     = 1;
  ZVS_TRIGGER_IF_FALSE    = 0;
  ZVS_TRIGGER_IF_INACTIVE = -1;

  (* Erm triggers *)
  TRIGGER_FU1       = 1;
  TRIGGER_FU29999   = 29999;
  TRIGGER_TM1       = 30000;
  TRIGGER_TM100     = 30099;
  TRIGGER_HE0       = 30100;
  TRIGGER_HE198     = 30298;
  TRIGGER_BA0       = 30300;
  TRIGGER_BA1       = 30301;
  TRIGGER_BR        = 30302;
  TRIGGER_BG0       = 30303;
  TRIGGER_BG1       = 30304;
  TRIGGER_MW0       = 30305;
  TRIGGER_MW1       = 30306;
  TRIGGER_MR0       = 30307;
  TRIGGER_MR1       = 30308;
  TRIGGER_MR2       = 30309;
  TRIGGER_CM0       = 30310;
  TRIGGER_CM1       = 30311;
  TRIGGER_CM2       = 30312;
  TRIGGER_CM3       = 30313;
  TRIGGER_CM4       = 30314;
  TRIGGER_AE0       = 30315;
  TRIGGER_AE1       = 30316;
  TRIGGER_MM0       = 30317;
  TRIGGER_MM1       = 30318;
  TRIGGER_CM5       = 30319;
  TRIGGER_MP        = 30320;
  TRIGGER_SN        = 30321;
  TRIGGER_MG0       = 30322;
  TRIGGER_MG1       = 30323;
  TRIGGER_TH0       = 30324;
  TRIGGER_TH1       = 30325;
  TRIGGER_IP0       = 30330;
  TRIGGER_IP1       = 30331;
  TRIGGER_IP2       = 30332;
  TRIGGER_IP3       = 30333;
  TRIGGER_CO0       = 30340;
  TRIGGER_CO1       = 30341;
  TRIGGER_CO2       = 30342;
  TRIGGER_CO3       = 30343;
  TRIGGER_BA50      = 30350;
  TRIGGER_BA51      = 30351;
  TRIGGER_BA52      = 30352;
  TRIGGER_BA53      = 30353;
  TRIGGER_GM0       = 30360;
  TRIGGER_GM1       = 30361;
  TRIGGER_PI        = 30370;
  TRIGGER_DL        = 30371;
  TRIGGER_HM        = 30400;
  TRIGGER_HM0       = 30401;
  TRIGGER_HM198     = 30599;
  TRIGGER_HL        = 30600;
  TRIGGER_HL0       = 30601;
  TRIGGER_HL198     = 30799;
  TRIGGER_BF        = 30800;
  TRIGGER_MF1       = 30801;
  TRIGGER_TL0       = 30900;
  TRIGGER_TL1       = 30901;
  TRIGGER_TL2       = 30902;
  TRIGGER_TL3       = 30903;
  TRIGGER_TL4       = 30904;
  TRIGGER_OB_POS    = integer($10000000);
  TRIGGER_LE_POS    = integer($20000000);
  TRIGGER_OB_LEAVE  = integer($08000000);
  TRIGGER_INVALID   = -1;

  (* Era Triggers *)
  FIRST_ERA_TRIGGER                      = 77001;
  TRIGGER_SAVEGAME_WRITE                 = 77001;
  TRIGGER_SAVEGAME_READ                  = 77002;
  TRIGGER_KEYPRESS                       = 77003;
  TRIGGER_OPEN_HEROSCREEN                = 77004;
  TRIGGER_CLOSE_HEROSCREEN               = 77005;
  TRIGGER_STACK_OBTAINS_TURN             = 77006;
  TRIGGER_REGENERATE_PHASE               = 77007;
  TRIGGER_AFTER_SAVE_GAME                = 77008;
  TRIGGER_BEFOREHEROINTERACT             = 77010;
  TRIGGER_AFTERHEROINTERACT              = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE           = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT      = 77013;
  TRIGGER_ONCHAT                         = 77014;
  TRIGGER_ONGAMEENTER                    = 77015;
  TRIGGER_ONGAMELEAVE                    = 77016;
  TRIGGER_ONREMOTEEVENT                  = 77017;
  TRIGGER_DAILY_TIMER                    = 77018;
  TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE   = 77019;
  TRIGGER_BATTLEFIELD_VISIBLE            = 77020;
  TRIGGER_AFTER_TACTICS_PHASE            = 77021;
  TRIGGER_COMBAT_ROUND                   = 77022;
  TRIGGER_OPEN_RECRUIT_DLG               = 77023;
  TRIGGER_CLOSE_RECRUIT_DLG              = 77024;
  TRIGGER_RECRUIT_DLG_MOUSE_CLICK        = 77025;
  TRIGGER_TOWN_HALL_MOUSE_CLICK          = 77026;
  TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK   = 77027;
  TRIGGER_RECRUIT_DLG_RECALC             = 77028;
  TRIGGER_RECRUIT_DLG_ACTION             = 77029;
  TRIGGER_LOAD_HERO_SCREEN               = 77030;
  TRIGGER_BUILD_TOWN_BUILDING            = 77031;
  TRIGGER_OPEN_TOWN_SCREEN               = 77032;
  TRIGGER_CLOSE_TOWN_SCREEN              = 77033;
  TRIGGER_SWITCH_TOWN_SCREEN             = 77034;
  TRIGGER_PRE_TOWN_SCREEN                = 77035;
  TRIGGER_POST_TOWN_SCREEN               = 77036;
  TRIGGER_PRE_HEROSCREEN                 = 77037;
  TRIGGER_POST_HEROSCREEN                = 77038;
  TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE = 77039;
  TRIGGER_ADVMAP_TILE_HINT               = 77040;
  TRIGGER_BEFORE_STACK_TURN              = 77041;
  TRIGGER_CALC_TOWN_INCOME               = 77042;
  {!} LAST_ERA_TRIGGER                   = TRIGGER_CALC_TOWN_INCOME;

  INITIAL_FUNC_AUTO_ID = 95000;

  (* Remote Event IDs *)
  REMOTE_EVENT_NONE         = 0;
  REMOTE_EVENT_PLACE_OBJECT = 1;

  ZvsProcessErm:        Utils.TProcedure = Ptr($74C816);
  ZvsErmError:          procedure ({n} FileName: pchar; Line: integer; ErrStr: pchar) cdecl = Ptr($712333);
  ZvsIsErmError:        pinteger  = Ptr($2772744);
  ZvsBreakTrigger:      plongbool = Ptr($27F9A40);
  ZvsErmErrorsDisabled: plongbool = Ptr($2772740);
  ZvsErmHeapPtr:        ppointer  = Ptr($27F9548);
  ZvsErmHeapSize:       pinteger  = Ptr($27F9958);

  (* ERM Flags *)
  ERM_FLAG_NETWORK_BATTLE               = 997;
  ERM_FLAG_REMOTE_BATTLE_VS_HUMAN       = 998;
  ERM_FLAG_THIS_PC_HUMAN_PLAYER         = 999;
  ERM_FLAG_HUMAN_VISITOR_OR_REAL_BATTLE = 1000;

  (* WoG Options *)
  NUM_WOG_OPTIONS                           = 1000;
  CURRENT_WOG_OPTIONS                       = 0;
  GLOBAL_WOG_OPTIONS                        = 1;
  WOG_OPTION_TOWERS_EXP_DISABLED            = 1;
  WOG_OPTION_LEAVE_MONS_ON_ADV_MAP_DISABLED = 2;
  WOG_OPTION_COMMANDERS_DISABLED            = 3;
  WOG_OPTION_TOWN_DESTRUCT_DISABLED         = 4;
  WOG_OPTION_WOGIFY                         = 5;
  WOG_OPTION_COMMANDERS_NEED_HIRING         = 6;
  WOG_OPTION_MAP_RULES                      = 101;
  WOG_OPTION_ERROR                          = 905;
  WOG_OPTION_DISABLE_ERRORS                 = 904;
  DONT_WOGIFY                               = 0;
  WOGIFY_WOG_MAPS_ONLY                      = 1;
  WOGIFY_ALL                                = 2;
  WOGIFY_AFTER_ASKING                       = 3;

  NUM_WOG_HEROES = 156;


type
  TErmValType   = (ValNum, ValF, ValQuick, ValV, ValW, ValX, ValY, ValZ);
  TErmCheckType =
  (
    NO_CHECK,
    CHECK_GET,
    CHECK_EQUAL,
    CHECK_NOTEQUAL,
    CHECK_MORE,
    CHECK_LESS,
    CHECK_MOREEUQAL,
    CHECK_LESSEQUAL
  );

  PErmCmdParam = ^TErmCmdParam;
  TErmCmdParam = packed record
    Value:    integer;
    {
    [4 bits]  Type:             TErmValType;  // ex: y5;  y5 - type
    [4 bits]  IndexedPartType:  TErmValType;  // ex: vy5; y5 - indexed part;
    [3 bits]  CheckType:        TErmCheckType;
    [1 bit]   NeedsInterpolation: boolean; // For I-type determines, if string has % character
    [1 bit]   HasCurrDayModifier: boolean; // true if "c" modifier was used before parameter
    [1 bit]   CanBeFastIntEvaled: boolean; // true if it's v/y/x variable with valid known index
    }
    ValType:  integer;

    function  GetType: integer; inline;
    function  GetIndexedPartType: integer; inline;
    function  GetCheckType: integer; inline;
    procedure SetType (NewType: integer); inline;
    procedure SetIndexedPartType (NewType: integer); inline;
    procedure SetCheckType (NewCheckType: integer); inline;
    function  NeedsInterpolation: boolean; inline;
    procedure SetNeedsInterpolation (Value: boolean); inline;
    function  HasCurrDayModifier: boolean; inline;
    procedure SetHasCurrDayModifier (Value: boolean); inline;
    function  CanBeFastIntEvaled: boolean; inline;
    procedure SetCanBeFastIntEvaled (Value: boolean); inline;
  end; // .record TErmCmdParam

  TErmString = packed record
    Value:  pchar;
    Len:    integer;
  end; // .record TErmString

  TGameString = packed record
    Value:  pchar;
    Len:    integer;
    Dummy:  integer;
  end; // .record TGameString

  PErmCmdConditions = ^TErmCmdConditions;
  TErmCmdConditions = array [COND_AND..COND_OR, 0..15, LEFT_COND..RIGHT_COND] of TErmCmdParam;

  PErmCmdParams = ^TErmCmdParams;
  TErmCmdParams = array [0..ERM_CMD_MAX_PARAMS_NUM - 1] of TErmCmdParam;

  TErmCmdId = packed record
    case boolean of
      true:  (Name: array [0..1] of char);
      false: (Id: word);
  end; // .record TErmCmdId

  PErmCmd = ^TErmCmd;
  TErmCmd = packed record
    CmdId:        TErmCmdId;
    Disabled:     boolean;
    PrevDisabled: boolean;
    Conditions:   TErmCmdConditions;
    Structure:    pointer;
    Params:       TErmCmdParams;
    NumParams:    integer;
    CmdHeader:    TErmString; // ##:...
    CmdBody:      TErmString; // #^...^/...

    procedure SetIsGenerated (NewValue: boolean); inline;
    function  IsGenerated: boolean; inline;
  end; // .record TErmCmd

  PErmSubCmd = ^TErmSubCmd;
  TErmSubCmd = packed record
    Pos:        integer;
    Code:       TErmString;
    Conditions: TErmCmdConditions;
    Params:     TErmCmdParams;
    Chars:      array [0..15] of char;
    Modifiers:  array [0..15] of byte;
    Nums:       array [0..15] of integer;
  end; // .record TErmSubCmd

  PErmTrigger = ^TErmTrigger;
  TErmTrigger = packed record
    {n} Next:         PErmTrigger;
        Id:           integer;
        Name:         word;
        NumCmds:      word;
        Disabled:     byte;
        PrevDisabled: byte;
        Conditions:   TErmCmdConditions;
        FirstCmd:     record end;

    (* Returns trigger size in bytes, including all receivers *)
    function GetSize: integer; inline;
  end;

  PTriggerFastAccessListItem = ^TTriggerFastAccessListItem;
  TTriggerFastAccessListItem = record
    Trigger: PErmTrigger;
    Id:      integer;
  end;

  PTriggerFastAccessList = ^TTriggerFastAccessList;
  TTriggerFastAccessList = array [0..high(integer) div sizeof(TTriggerFastAccessListItem) - 1] of TTriggerFastAccessListItem;

  (* If result is true, event handlers execution must be repeated *)
  TTriggerLoopHandler = function ({OUn} Data: pointer): boolean;

  PTriggerLoopCallback = ^TTriggerLoopCallback;
  TTriggerLoopCallback = record
  {n} Handler: TTriggerLoopHandler;
      Data:    pointer;
  end;

  TScriptMan = class
     private
      {O} fScripts: RscLists.TResourceList;

     public const
       IS_FIRST_LOADING = true;
       IS_RELOADING     = false;

     public
      constructor Create;
      destructor  Destroy; override;

      procedure ClearScripts;
      procedure SaveScripts;
      function  LoadScript (const ScriptPath: string; ScriptName: string = ''): boolean;
      procedure LoadMapInternalScripts;
      procedure LoadScriptsFromSavedGame;
      procedure LoadScriptsFromDisk (IsFirstLoading: boolean);
      procedure ReloadScriptsFromDisk;
      procedure ExtractScripts;
      function  AddrToScriptNameAndLine ({n} Addr: pchar; var {out} ScriptName: string; out LineN: integer; out LinePos: integer): boolean;
      function  IsMapScript (ScriptInd: integer): boolean;

      property Scripts: RscLists.TResourceList read fScripts;
    end; // .class TScriptMan

  PErmVVars      = ^TErmVVars;
  TErmVVars      = array [1..10000] of integer;
  PWVars         = ^TWVars;
  TWVars         = array [0..255, 1..200] of integer;
  TErmZVar       = array [0..511] of char;
  PErmZVars      = ^TErmZVars;
  TErmZVars      = array [1..1000] of TErmZVar;
  PErmNZVars     = ^TErmNZVars;
  TErmNZVars     = array [1..10] of TErmZVar;
  PErmYVars      = ^TErmYVars;
  TErmYVars      = array [1..100] of integer;
  PErmNYVars     = ^TErmNYVars;
  TErmNYVars     = array [1..100] of integer;
  PErmXVars      = ^TErmXVars;
  TErmXVars      = array [1..16] of integer;
  PErmFlags      = ^TErmFlags;
  TErmFlags      = array [1..1000] of boolean;
  PErmEVars      = ^TErmEVars;
  TErmEVars      = array [1..100] of single;
  PErmNEVars     = ^TErmNEVars;
  TErmNEVars     = array [1..100] of single;
  PErmQuickVars  = ^TErmQuickVars;
  TErmQuickVars  = array [1..15] of integer;
  PZvsTriggerIfs = ^TZvsTriggerIfs;
  TZvsTriggerIfs = array [0..10] of shortint;

  TZvsLoadErmScript = function (ScriptId: integer): integer; cdecl;
  TZvsLoadErmTxt    = function (IsNewLoad: integer): integer; cdecl;
  TZvsLoadErtFile   = function (Dummy, FileName: pchar): integer; cdecl;
  TZvsShowMessage   = function (Mes: pchar; MesType: integer; DummyZero: integer = 0): integer; cdecl;
  TZvsCheckFlags    = function (Flags: PErmCmdConditions): longbool; cdecl;
  TFireErmEvent     = function (EventId: integer): integer; cdecl;
  TZvsDumpErmVars   = procedure (Error, {n} ErmCmdPtr: pchar); cdecl;
  TZvsRunTimer      = procedure (Owner: integer); cdecl;

  POnBeforeTriggerArgs  = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs  = packed record
    TriggerId:          integer;
    BlockErmExecution:  longbool;
  end; // .record TOnBeforeTriggerArgs

  TWoGOptions = array [CURRENT_WOG_OPTIONS..GLOBAL_WOG_OPTIONS, 0..NUM_WOG_OPTIONS - 1] of integer;

  PHeroSpecRecord = ^THeroSpecRecord;
  THeroSpecRecord = packed record
    Setup: array [0..6] of integer;

    case boolean of
      false: (
        ShortName:   pchar;
        FullName:    pchar;
        Description: pchar;
      );

      true: (Descr: array [0..2] of pchar;);
  end; // .record THeroSpecRecord

  PHeroSpecsTable = ^THeroSpecsTable;
  THeroSpecsTable = array [0..NUM_WOG_HEROES - 1] of THeroSpecRecord;

  THeroSpecSettings = packed record
    PicNum:    integer;
    ZVarDescr: array [0..2] of integer;
  end; // .record THeroSpecSettings

  PHeroSpecSettingsTable = ^THeroSpecSettingsTable;
  THeroSpecSettingsTable = array [0..NUM_WOG_HEROES - 1] of THeroSpecSettings;

  PSecSkillSettings = ^TSecSkillSettings;
  TSecSkillSettings = packed record
    case byte of
      0: (
        _0:       integer; // use Name instead
        Basic:    integer; // z-index, description
        Advanced: integer;
        Expert:   integer;
      );

      1: (
        Name:  integer;
        Descs: array [0..SKILL_LEVEL_EXPERT - 1] of integer;
      );

      2: (
        Texts: array [0..SKILL_LEVEL_EXPERT] of integer;
      );
  end; // .record TSecSkillSettings

  PSecSkillSettingsTable = ^TSecSkillSettingsTable;
  TSecSkillSettingsTable = array [0..Heroes.MAX_SECONDARY_SKILLS - 1] of TSecSkillSettings;

  TMonNamesSettings = packed record
    case byte of
      0: (
        NameSingular: integer; // z-index
        NamePlural:   integer; // z-index
        Specialty:    integer; // z-index
      );

      1: (
        Texts: array [0..2] of integer;
      );
  end;

  PMonNamesSettingsTable = ^TMonNamesSettingsTable;
  TMonNamesSettingsTable = array [0..high(integer) div sizeof(TMonNamesSettings) div 3 - 1] of TMonNamesSettings;

  TArtNamesSettings = packed record
    case byte of
      0: (
        Name: integer; // z-index
        Desc: integer; // z-index
      );

      1: (
        Texts: array [0..1] of integer;
      );
  end;

  PArtNamesSettingsTable = ^TArtNamesSettingsTable;
  TArtNamesSettingsTable = array [0..high(integer) div sizeof(TArtNamesSettings) div 3 - 1] of TArtNamesSettings;

  TFireRemoteEventProc = procedure (EventId: integer; Data: pinteger; NumInts: integer); cdecl;
  TZvsPlaceMapObject   = function (x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain: integer): integer; cdecl;
  TZvsCheckEnabled     = array [0..19] of integer;

  PCmdLocalObject = ^TCmdLocalObject;
  TCmdLocalObject = record
      ErtIndex: integer;
  {n} Prev:     PCmdLocalObject;
  end;

const
  (* WoG vars *)
  QuickVars: PErmQuickVars = Ptr($27718D0);
  v:  PErmVVars = Ptr($887668);
  w:  PWVars    = Ptr($A4AB10);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);
  nz: PErmNZVars = Ptr($A46D28);
  ny: PErmNYVars = Ptr($A46A30);
  ne: PErmNEVars = Ptr($27F93B8);

  ZvsIsGameLoading:           PBOOLEAN               = Ptr($A46BC0);
  ZvsTriggerIfs:              PZvsTriggerIfs         = Ptr($A46D18);
  ZvsTriggerIfsDepth:         pbyte                  = Ptr($A46D22);
  ZvsChestsEnabled:           ^TZvsCheckEnabled      = Ptr($27F99B0);
  ZvsGmAiFlags:               pinteger               = Ptr($793C80);
  ZvsAllowDefMouseReaction:   plongbool              = Ptr($A4AAFC);
  ZvsMouseEventInfo:          Heroes.PMouseEventInfo = Ptr($8912A8);
  ZvsEventX:                  pinteger               = Ptr($27F9964);
  ZvsEventY:                  pinteger               = Ptr($27F9968);
  ZvsEventZ:                  pinteger               = Ptr($27F996C);
  ZvsWHero:                   pinteger               = Ptr($27F9988);
  IsWoG:                      plongbool              = Ptr($803288);
  WoGOptions:                 ^TWoGOptions           = Ptr($2771920);
  ErmEnabled:                 plongbool              = Ptr($27F995C);
  ErmErrCmdPtr:               ppchar                 = Ptr($840E0C);
  ErmDlgCmd:                  pinteger               = Ptr($887658);
  MrMonPtr:                   PPOINTER               = Ptr($2846884); // MB_Mon
  HeroSpecsTable:             PHeroSpecsTable        = Ptr($7B4C40);
  HeroSpecsTableBack:         PHeroSpecsTable        = Ptr($91DA78);
  HeroSpecSettingsTable:      PHeroSpecSettingsTable = Ptr($A49BC0);
  SecSkillSettingsTable:      PSecSkillSettingsTable = Ptr($899410);
  SecSkillNamesBack:          Heroes.PSecSkillNames  = Ptr($A89190);
  SecSkillDescsBack:          Heroes.PSecSkillDescs  = Ptr($A46BC8);
  SecSkillTextsBack:          Heroes.PSecSkillTexts  = Ptr($A490A8);
  MonNamesSettingsTable:      PMonNamesSettingsTable = Ptr($A48440);
  MonNamesSingularTable:      Utils.PEndlessPcharArr = Ptr($7C8240);
  MonNamesPluralTable:        Utils.PEndlessPcharArr = Ptr($7B6650);
  MonNamesSpecialtyTable:     Utils.PEndlessPcharArr = Ptr($7C4018);
  MonNamesSingularTableBack:  Utils.PEndlessPcharArr = Ptr($A498A8);
  MonNamesPluralTableBack:    Utils.PEndlessPcharArr = Ptr($A48128);
  MonNamesSpecialtyTableBack: Utils.PEndlessPcharArr = Ptr($A88E78);
  ArtNamesSettingsTable:      PArtNamesSettingsTable = Ptr($A4A588);
  ArtInfosBack:               Heroes.PArtInfos       = Ptr($2731070);

  (* WoG funcs *)
  ZvsProcessCmd:      procedure (Cmd: PErmCmd; Dummy: integer = 0; IsPostInstr: longbool = false) cdecl = Ptr($741DF0);
  ZvsFindErm:         Utils.TProcedure  = Ptr($749955);
  ZvsClearErtStrings: Utils.TProcedure  = Ptr($7764F2);
  ZvsClearErmScripts: Utils.TProcedure  = Ptr($750191);
  ZvsLoadErmScript:   TZvsLoadErmScript = Ptr($72C297);
  ZvsLoadErmTxt:      TZvsLoadErmTxt    = Ptr($72C8B1);
  ZvsLoadErtFile:     TZvsLoadErtFile   = Ptr($72C641);
  ZvsShowMessage:     TZvsShowMessage   = Ptr($70FB63);
  ZvsCheckFlags:      TZvsCheckFlags    = Ptr($740DF1);
  ZvsGetNum:          function (SubCmd: PErmSubCmd; ParamInd: integer; DoEval: integer): longbool cdecl = Ptr($73E970);
  ZvsGetVal:          function (ValuePtr: pointer; ValueSize: byte): integer cdecl = Ptr($7418B0);
  ZvsPutVal:          function (ValuePtr: pointer; ValueSize: byte; SubCmd: PErmSubCmd; ParamInd: integer): integer cdecl = Ptr($7416FD);
  ZvsGetCurrDay:      function: integer cdecl = Ptr($7103D2);
  ZvsVnCopy:          procedure ({n} Src, Dst: PErmCmdParam) cdecl = Ptr($73E83B);
  ZvsFindMacro:       function (SubCmd: PErmSubCmd; IsSet: integer): {n} pchar cdecl = Ptr($734072);
  ZvsFindMacro2:      function (Str: pchar; IsSet: integer; var TokenLen: integer): {n} pchar cdecl = Ptr($734203);
  ZvsGetMacro:        function ({n} Macro: pchar): {n} PErmCmdParam cdecl = Ptr($7343E4);
  FireErmEvent:       TFireErmEvent    = Ptr($74CE30);
  ZvsDumpErmVars:     TZvsDumpErmVars  = Ptr($72B8C0);
  ZvsResetCommanders: Utils.TProcedure = Ptr($770B25);
  ZvsEnableNpc:       procedure (HeroId: integer; AutoHired: integer) cdecl = Ptr($76B541);
  ZvsDisableNpc:      procedure (HeroId: integer) cdecl = Ptr($76B5D6);
  ZvsIsAi:            function (Owner: integer): boolean cdecl = Ptr($711828);
  ZvsGetErtStr:       function (StrInd: integer): pchar cdecl = Ptr($776620);
  ZvsInterpolateStr:  function (Str: pchar): pchar cdecl = Ptr($73D4CD);
  ZvsApply:           function (Dest: pinteger; Size: integer; Cmd: PErmSubCmd; ParamInd: integer): integer cdecl = Ptr($74195D);
  ZvsGetVarValIndex:  function (Param: PErmCmdParam): integer cdecl = Ptr($72DCB0);
  ZvsGetVarVal:       function (Param: PErmCmdParam): integer cdecl = Ptr($72DEA5);
  ZvsSetVarVal:       function (Param: PErmCmdParam; NewValue: integer): integer cdecl = Ptr($72E301);
  ZvsGetParamValue:   function (var Param: TErmCmdParam): integer cdecl = Ptr($72DEA5);
  ZvsReparseParam:    function (var Param: TErmCmdParam): integer cdecl = Ptr($72D573);

  ZvsCrExpoSet_GetExpM: function (ItemType, ItemId, Modifier: integer): integer cdecl = Ptr($718D34);
  ZvsCrExpoSet_Find:    function (ItemType, ItemId: integer): pointer {*CrExpo} cdecl = Ptr($718617);
  ZvsCrExpoSet_GetExp:  function (ItemType, ItemId: integer): integer cdecl = Ptr($718CCD);
  ZvsCrExpoSet_Modify:  function (Oper, ItemType, ItemId, Exp, Modifier, MonType, OrigNum, NewNum: integer; {n} MonArr: pointer = nil): integer cdecl = Ptr($719260);

  ZvsStringSet_Clear: procedure () cdecl = Ptr($7764F2);
  ZvsStringSet_Add: function (Index: integer; Str: pchar): longbool cdecl = Ptr($776550);
  ZvsStringSet_GetText: function (Index: integer): pchar cdecl = Ptr($776620);
  ZvsStringSet_Load: function (): longbool cdecl = Ptr($776694);
  ZvsStringSet_Save: function (): longbool cdecl = Ptr($77679D);

  FireRemoteEventProc: TFireRemoteEventProc = Ptr($76863A);
  ZvsPlaceMapObject:   TZvsPlaceMapObject   = Ptr($71299E);

  ZvsAddItemToWogOptions: function (Script, Page, Group, Item, Default, Multip, Internal: integer; Text, Hint, PopUp: pchar): integer cdecl = Ptr($777E0C);

  ZvsIntToStr (* Itoa *): procedure (Value: integer; Buf: pchar; Base: integer) cdecl = Ptr($71682E);


var
{O} LoadedErsFiles:  {O} TList {of Heroes.TTextTable};
{O} ErtStrings:      {O} AssocArrays.TObjArray {of Index => pchar}; // use H3 Alloc/Free
{O} ScriptMan:       TScriptMan;
    ErmTriggerDepth: integer = 0;

    FreezedWogOptionWogify: integer = WOGIFY_ALL;

    MonNamesTables:     array [0..2] of Utils.PEndlessPcharArr;
    MonNamesTablesBack: array [0..2] of Utils.PEndlessPcharArr;

    ErmCmdOptimizer:         procedure (Cmd: PErmCmd) = nil;
    CurrentTriggerCmdIndPtr: pinteger = nil;
    QuitTriggerFlag:         boolean = false;
    TriggerLoopCallback:     TTriggerLoopCallback;

    // List of objects, that will be freed on current trigger end
    {Un} TriggerLocalObjects: {O} TList {of TObject} = nil;

    // Linked list of objects, that will be freed on ProcessCmd end. Currently optimized temporary ERT strings only.
    {Un} CmdLocalObjects: {U} PCmdLocalObject = nil;

    // Each trigger saves x-vars to RetXVars before restoring previous values on exit.
    // ArgXVars are copied to x on trigger start after saving previous x-values.
    ArgXVars: TErmXVars;
    RetXVars: TErmXVars;

    // May be set by function caller to signal, how many arguments are initialized
    NumFuncArgsPassed: integer = 0;

    // Value, accessable via !!FU:A
    NumFuncArgsReceived: integer = 0;

    // Single flag per each function argument, representing GET-syntax usage by caller
    FuncArgsGetSyntaxFlagsPassed:   integer = 0;
    FuncArgsGetSyntaxFlagsReceived: integer = 0;

    ErmLegacySupport: boolean = false;

  (* ERM tracking options *)
  TrackingOpts: record
    Enabled:              boolean;
    MaxRecords:           integer;
    DumpCommands:         boolean;
    IgnoreEmptyTriggers:  boolean;
    IgnoreRealTimeTimers: boolean;
  end;


procedure SetZVar (Str: pchar; const Value: string); overload;
procedure SetZVar (Str, Value: pchar); overload;

procedure ShowErmError (const Error: string);
function  GetErmFuncByName (const FuncName: string): integer;
function  GetErmFuncName (FuncId: integer; out Name: string): boolean;
function  AllocErmFunc (const FuncName: string; {i} out FuncId: integer): boolean;
function  GetTriggerReadableName (EventId: integer): string;
procedure ExecErmCmd (const CmdStr: string);
procedure ReloadErm; stdcall;
procedure ExtractErm; stdcall;
function  AddrToScriptNameAndLine (CharPos: pchar; var ScriptName: string; var LineN: integer; var LinePos: integer): boolean;
procedure AssignEventParams (const Params: array of integer);
procedure FireErmEventEx (EventId: integer; const Params: array of integer);
procedure NameTrigger (const TriggerId: integer; const FuncName: string);

(* Registers object as trigger local object. It will be freed on exit from current trigger *)
procedure RegisterTriggerLocalObject ({O} Obj: TObject);

(* Returns true if default reaction is allowed *)
function  FireMouseEvent (TriggerId: integer; MouseEventInfo: Heroes.PMouseEventInfo): boolean;

function  FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;

(*  Up to 16 arguments  *)
procedure FireRemoteErmEvent (EventId: integer; Args: array of integer);

(* Set/Get current hero *)
procedure SetErmCurrHero (NewInd: integer); overload;
procedure SetErmCurrHero ({n} NewHero: Heroes.PHero); overload;
function  GetErmCurrHero: {n} Heroes.PHero;
function  GetErmCurrHeroInd: integer; // or -1


(***) implementation (***)
uses PatchApi, Stores, AdvErm, ErmTracking;

const
  ERM_CMD_CACHE_LIMIT = 30000;

  (* GetErmParamValue flags *)
  FLAG_STR_EVALS_TO_ADDR_NOT_INDEX = 1; // Indicates, that caller expects string value address, not index

  (* SetErmParamValue flags *)
  FLAG_ASSIGNABLE_STRINGS = 1; // Indicates, that z/s^^ strings are assignable (NewValue is pchar for them)

  FAST_INT_TYPE_CHARS = ['f'..'t', 'v', 'x', 'y'];

  FIRST_LOCAL_ERT_INDEX = 1000000000;
  LAST_LOCAL_ERT_INDEX  = 2000000000;

type
  PCachedSubCmdParams = ^TCachedSubCmdParams;
  TCachedSubCmdParams = packed record
    AddrHash:  integer;
    NumParams: integer;
    Pos:       integer;
    Params:    TErmCmdParams;
    Modifiers: array [0..15] of byte;
  end;

  TFastIntVarSet = record
    MinInd: integer;
    MaxInd: integer;
  end;

  TTriggerLocalStr = class
   protected
   {O} Value:  pchar;
       zIndex: integer;

   public
    constructor Create ({n} Str: pchar; StrLen: integer = -1);
    destructor Destroy; override;
  end;

var
{O} FuncNames:         DataLib.TDict {OF FuncId: integer};
{O} FuncIdToNameMap:   DataLib.TObjDict {O} {OF TString};
    FuncAutoId:        integer;
{O} GlobalConsts:      DataLib.TDict {OF Value: integer};
{O} ScriptNames:       Lists.TStringList;
{O} ErmScanner:        TextScan.TTextScanner;
{O} ErmCmdCache:       {O} TAssocArray {OF PErmCmd};
{O} EventTracker:      ErmTracking.TEventTracker;
    ErmErrReported:    boolean = false;
    LocalErtAutoIndex: integer = FIRST_LOCAL_ERT_INDEX;

    (* Binary tree in array. Fast search for first trigger with given ID *)
    TriggerFastAccessList: PTriggerFastAccessList = nil;
    NullTrigger:           PErmTrigger            = nil;
    NumUniqueTriggers:     integer                = 0;
    CompiledErmOptimized:  boolean                = false;

    (* Speed up loops with native ERM receivers *)
    SubCmdCache: array [0..511] of TCachedSubCmdParams;

    (* Fast known integer variables like y3, x15 or v600 compilation optimization *)
    FastIntVarSets:  array [0..15] of TFastIntVarSet;
    FastIntVarAddrs: array [0..15] of Utils.PEndlessIntArr;


function TErmCmdParam.GetType: integer;
begin
  result := Self.ValType and $0F;
end;

function TErmCmdParam.GetIndexedPartType: integer;
begin
  result := (Self.ValType shr 4) and $0F;
end;

function TErmCmdParam.GetCheckType: integer;
begin
  result := (Self.ValType shr 8) and $07;
end;

procedure TErmCmdParam.SetType (NewType: integer);
begin
  Self.ValType := (Self.ValType and not $0F) or (NewType and $0F);
end;

procedure TErmCmdParam.SetIndexedPartType (NewType: integer);
begin
  Self.ValType := (Self.ValType and not $F0) or ((NewType and $0F) shl 4);
end;

procedure TErmCmdParam.SetCheckType (NewCheckType: integer);
begin
  Self.ValType := (Self.ValType and not $0700) or ((NewCheckType and $07) shl 8);
end;

function TErmCmdParam.NeedsInterpolation: boolean;
begin
  result := ((Self.ValType shr 11) and $1) <> 0;
end;

procedure TErmCmdParam.SetNeedsInterpolation (Value: boolean);
begin
  Self.ValType := (Self.ValType and not $0800) or (ord(Value) shl 11);
end;

function TErmCmdParam.HasCurrDayModifier: boolean;
begin
  result := ((Self.ValType shr 12) and $1) <> 0;
end;

procedure TErmCmdParam.SetHasCurrDayModifier (Value: boolean);
begin
  Self.ValType := (Self.ValType and not $1000) or (ord(Value) shl 12);
end;

function TErmCmdParam.CanBeFastIntEvaled: boolean;
begin
  result := ((Self.ValType shr 13) and $1) <> 0;
end;

procedure TErmCmdParam.SetCanBeFastIntEvaled (Value: boolean);
begin
  Self.ValType := (Self.ValType and not $2000) or (ord(Value) shl 13);
end;

procedure TErmCmd.SetIsGenerated (NewValue: boolean);
begin
  Self.Params[14].Value := (Self.Params[14].Value and not $1) or ord(NewValue);
end;

function TErmCmd.IsGenerated: boolean;
begin
  result := (Self.Params[14].Value and $1) <> 0;
end;

function TErmTrigger.GetSize: integer;
begin
  result := sizeof(Self) + Self.NumCmds * sizeof(TErmCmd);
end;

function AllocLocalErtIndex: integer; forward;

constructor TTriggerLocalStr.Create({n} Str: pchar; StrLen: integer = -1);
begin
  if Str = nil then begin
    Str    := '';
    StrLen := 0;
  end;

  if StrLen < 0 then begin
    StrLen := Windows.LStrLen(Str);
  end;

  GetMem(Self.Value, StrLen + 1);
  Utils.CopyMem(StrLen, Str, Self.Value);
  Self.Value[StrLen]           := #0;
  Self.zIndex                  := AllocLocalErtIndex;
  ErtStrings[Ptr(Self.zIndex)] := Self.Value;
end;

destructor TTriggerLocalStr.Destroy;
begin
  FreeMem(Self.Value);
  ErtStrings.DeleteItem(Ptr(Self.zIndex));
end;

procedure ShowErmError (const Error: string);
begin
  ZvsErmError(nil, 0, pchar(Error));
end;

function GetErmValType (c: char; out ValType: TErmValType): boolean;
begin
  result  :=  true;

  case c of
    '+', '-': ValType := ValNum;
    '0'..'9': ValType := ValNum;
    'f'..'t': ValType := ValQuick;
    'v':      ValType := ValV;
    'w':      ValType := ValW;
    'x':      ValType := ValX;
    'y':      ValType := ValY;
    'z':      ValType := ValZ;
  else
    result := false;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  end; // .switch
end; // .function GetErmValType

function IsValidConstName (const ConstName: string): boolean;
var
  Caret: pchar;

begin
  Caret := pchar(ConstName);

  while Caret^ in CONST_NAME_CHARSET do begin
    Inc(Caret);
  end;

  result := Caret^ = #0;
end;

function GetErmFuncByName (const FuncName: string): integer;
begin
  result := integer(FuncNames[FuncName]);
end;

function GetErmFuncName (FuncId: integer; out Name: string): boolean;
var
{U} SearchRes: TString;

begin
  SearchRes := TString(FuncIdToNameMap[Ptr(FuncId)]);
  result    := SearchRes <> nil;

  if result then begin
    Name := SearchRes.Value;
  end;
end;

procedure NameTrigger (const TriggerId: integer; const FuncName: string);
begin
  FuncNames[FuncName]                           := Ptr(TriggerId);
  FuncIdToNameMap[Ptr(TriggerId)]               := TString.Create(FuncName);
  AdvErm.GetOrCreateAssocVar(FuncName).IntValue := TriggerId;
end;

function AllocErmFunc (const FuncName: string; {i} out FuncId: integer): boolean;
begin
  FuncId := integer(FuncNames[FuncName]);
  result := FuncId = 0;

  if result then begin
    FuncId                       := FuncAutoId;
    FuncNames[FuncName]          := Ptr(FuncId);
    FuncIdToNameMap[Ptr(FuncId)] := TString.Create(FuncName);
    AdvErm.GetOrCreateAssocVar(FuncName).IntValue := FuncId;
    inc(FuncAutoId);
  end;
end; // .function AllocErmFunc

function GetTriggerReadableName (EventID: integer): string;
var
  BaseEventName: string;

  x:             integer;
  y:             integer;
  z:             integer;

  ObjType:       integer;
  ObjSubtype:    integer;

begin
  result := '';

  case EventID of
    {*} TRIGGER_FU1..TRIGGER_FU29999:
      result := 'OnErmFunction ' + SysUtils.IntToStr(EventID - TRIGGER_FU1 + 1);
    {*} TRIGGER_TM1..TRIGGER_TM100:
      result := 'OnErmTimer ' + SysUtils.IntToStr(EventID - TRIGGER_TM1 + 1);
    {*} TRIGGER_HE0..TRIGGER_HE198:
      result := 'OnHeroInteraction ' + SysUtils.IntToStr(EventID - TRIGGER_HE0);
    {*} TRIGGER_BA0:      result :=  'OnBeforeBattle';
    {*} TRIGGER_BA1:      result :=  'OnAfterBattle';
    {*} TRIGGER_BR:       result :=  'OnBattleRound';
    {*} TRIGGER_BG0:      result :=  'OnBeforeBattleAction';
    {*} TRIGGER_BG1:      result :=  'OnAfterBattleAction';
    {*} TRIGGER_MW0:      result :=  'OnWanderingMonsterReach';
    {*} TRIGGER_MW1:      result :=  'OnWanderingMonsterDeath';
    {*} TRIGGER_MR0:      result :=  'OnMagicBasicResistance';
    {*} TRIGGER_MR1:      result :=  'OnMagicCorrectedResistance';
    {*} TRIGGER_MR2:      result :=  'OnDwarfMagicResistance';
    {*} TRIGGER_CM0:      result :=  'OnAdventureMapRightMouseClick';
    {*} TRIGGER_CM1:      result :=  'OnTownMouseClick';
    {*} TRIGGER_CM2:      result :=  'OnHeroScreenMouseClick';
    {*} TRIGGER_CM3:      result :=  'OnHeroesMeetScreenMouseClick';
    {*} TRIGGER_CM4:      result :=  'OnBattleScreenMouseClick';
    {*} TRIGGER_CM5:      result :=  'OnAdventureMapLeftMouseClick';
    {*} TRIGGER_AE0:      result :=  'OnUnequipArt';
    {*} TRIGGER_AE1:      result :=  'OnEquipArt';
    {*} TRIGGER_MM0:      result :=  'OnBattleMouseHint';
    {*} TRIGGER_MM1:      result :=  'OnTownMouseHint';
    {*} TRIGGER_MP:       result :=  'OnMp3MusicChange';
    {*} TRIGGER_SN:       result :=  'OnSoundPlay';
    {*} TRIGGER_MG0:      result :=  'OnBeforeAdventureMagic';
    {*} TRIGGER_MG1:      result :=  'OnAfterAdventureMagic';
    {*} TRIGGER_TH0:      result :=  'OnEnterTownHall';
    {*} TRIGGER_TH1:      result :=  'OnLeaveTownHall';
    {*} TRIGGER_IP0:      result :=  'OnBeforeBattleBeforeDataSend';
    {*} TRIGGER_IP1:      result :=  'OnBeforeBattleAfterDataReceived';
    {*} TRIGGER_IP2:      result :=  'OnAfterBattleBeforeDataSend';
    {*} TRIGGER_IP3:      result :=  'OnAfterBattleAfterDataReceived';
    {*} TRIGGER_CO0:      result :=  'OnOpenCommanderWindow';
    {*} TRIGGER_CO1:      result :=  'OnCloseCommanderWindow';
    {*} TRIGGER_CO2:      result :=  'OnAfterCommanderBuy';
    {*} TRIGGER_CO3:      result :=  'OnAfterCommanderResurrect';
    {*} TRIGGER_BA50:     result :=  'OnBeforeBattleForThisPcDefender';
    {*} TRIGGER_BA51:     result :=  'OnAfterBattleForThisPcDefender';
    {*} TRIGGER_BA52:     result :=  'OnBeforeBattleUniversal';
    {*} TRIGGER_BA53:     result :=  'OnAfterBattleUniversal';
    {*} TRIGGER_GM0:      result :=  'OnAfterLoadGame';
    {*} TRIGGER_GM1:      result :=  'OnBeforeSaveGame';
    {*} TRIGGER_PI:       result :=  'OnAfterErmInstructions';
    {*} TRIGGER_DL:       result :=  'OnCustomDialogEvent';
    {*} TRIGGER_HM:       result :=  'OnHeroMove';
    {*} TRIGGER_HM0..TRIGGER_HM198:
      result := 'OnHeroMove ' + SysUtils.IntToStr(EventID - TRIGGER_HM0);
    {*} TRIGGER_HL:   result :=  'OnHeroGainLevel';
    {*} TRIGGER_HL0..TRIGGER_HL198:
      result := 'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - TRIGGER_HL0);
    {*} TRIGGER_BF:       result :=  'OnSetupBattlefield';
    {*} TRIGGER_MF1:      result :=  'OnMonsterPhysicalDamage';
    {*} TRIGGER_TL0:      result :=  'OnEverySecond';
    {*} TRIGGER_TL1:      result :=  'OnEvery2Seconds';
    {*} TRIGGER_TL2:      result :=  'OnEvery5Seconds';
    {*} TRIGGER_TL3:      result :=  'OnEvery10Seconds';
    {*} TRIGGER_TL4:      result :=  'OnEveryMinute';
    (* Era Triggers *)
    {*} TRIGGER_SAVEGAME_WRITE:               result := 'OnSavegameWrite';
    {*} TRIGGER_SAVEGAME_READ:                result := 'OnSavegameRead';
    {*} TRIGGER_KEYPRESS:                     result := 'OnKeyPressed';
    {*} TRIGGER_OPEN_HEROSCREEN:              result := 'OnOpenHeroScreen';
    {*} TRIGGER_CLOSE_HEROSCREEN:             result := 'OnCloseHeroScreen';
    {*} TRIGGER_STACK_OBTAINS_TURN:           result := 'OnBattleStackObtainsTurn';
    {*} TRIGGER_REGENERATE_PHASE:             result := 'OnBattleRegeneratePhase';
    {*} TRIGGER_AFTER_SAVE_GAME:              result := 'OnAfterSaveGame';
    {*} TRIGGER_BEFOREHEROINTERACT:           result := 'OnBeforeHeroInteraction';
    {*} TRIGGER_AFTERHEROINTERACT:            result := 'OnAfterHeroInteraction';
    {*} TRIGGER_ONSTACKTOSTACKDAMAGE:         result := 'OnStackToStackDamage';
    {*} TRIGGER_ONAICALCSTACKATTACKEFFECT:    result := 'OnAICalcStackAttackEffect';
    {*} TRIGGER_ONCHAT:                       result := 'OnChat';
    {*} TRIGGER_ONGAMEENTER:                  result := 'OnGameEnter';
    {*} TRIGGER_ONGAMELEAVE:                  result := 'OnGameLeave';
    {*} TRIGGER_ONREMOTEEVENT:                result := 'OnRemoteEvent';
    {*} TRIGGER_DAILY_TIMER:                  result := 'OnEveryDay';
    {*} TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE: result := 'OnBeforeBattlefieldVisible';
    {*} TRIGGER_BATTLEFIELD_VISIBLE:          result := 'OnBattlefieldVisible';
    {*} TRIGGER_AFTER_TACTICS_PHASE:          result := 'OnAfterTacticsPhase';
    {*} TRIGGER_COMBAT_ROUND:                 result := 'OnCombatRound';
    {*} TRIGGER_OPEN_RECRUIT_DLG:             result := 'OnOpenRecruitDlg';
    {*} TRIGGER_CLOSE_RECRUIT_DLG:            result := 'OnCloseRecruitDlg';
    {*} TRIGGER_RECRUIT_DLG_MOUSE_CLICK:      result := 'OnRecruitDlgMouseClick';
    {*} TRIGGER_TOWN_HALL_MOUSE_CLICK:        result := 'OnTownHallMouseClick';
    {*} TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK: result := 'OnKingdomOverviewMouseClick';
    {*} TRIGGER_RECRUIT_DLG_RECALC:           result := 'OnRecruitDlgRecalc';
    {*} TRIGGER_RECRUIT_DLG_ACTION:           result := 'OnRecruitDlgAction';
    {*} TRIGGER_LOAD_HERO_SCREEN:             result := 'OnLoadHeroScreen';
    {*} TRIGGER_BUILD_TOWN_BUILDING:          result := 'OnBuildTownBuilding';
    {*} TRIGGER_OPEN_TOWN_SCREEN:             result := 'OnOpenTownScreen';
    {*} TRIGGER_CLOSE_TOWN_SCREEN:            result := 'OnCloseTownScreen';
    {*} TRIGGER_SWITCH_TOWN_SCREEN:           result := 'OnSwitchTownScreen';
    {*} TRIGGER_PRE_TOWN_SCREEN:              result := 'OnPreTownScreen';
    {*} TRIGGER_POST_TOWN_SCREEN:             result := 'OnPostTownScreen';
    {*} TRIGGER_PRE_HEROSCREEN:               result := 'OnPreHeroScreen';
    {*} TRIGGER_POST_HEROSCREEN:              result := 'OnPostHeroScreen';
    {*} TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE: result := 'OnDetermineMonInfoDlgUpgrade';
    {*} TRIGGER_ADVMAP_TILE_HINT:             result := 'OnAdvMapTileHint';
    {*} TRIGGER_BEFORE_STACK_TURN:            result := 'OnBeforeBattleStackTurn';
    {*} TRIGGER_CALC_TOWN_INCOME:             result := 'OnCalculateTownIncome';
    (* END Era Triggers *)
  else
    if EventID >= TRIGGER_OB_POS then begin
      if ((EventID and TRIGGER_OB_POS) or (EventID and TRIGGER_LE_POS)) <> 0 then begin
        x := EventID and 1023;
        y := (EventID shr 16) and 1023;
        z := (EventID shr 26) and 1;

        if (EventID and TRIGGER_LE_POS) <> 0 then begin
          BaseEventName := 'OnLocalEvent ';
        end else begin
          if (EventID and TRIGGER_OB_LEAVE) <> 0 then begin
            BaseEventName := 'OnAfterVisitObject ';
          end else begin
            BaseEventName := 'OnBeforeVisitObject ';
          end;
        end;

        result :=
          BaseEventName + SysUtils.IntToStr(x) + '/' +
          SysUtils.IntToStr(y) + '/' + SysUtils.IntToStr(z);
      end else begin
        ObjType    := (EventID shr 12) and 255;
        ObjSubtype := (EventID and 255) - 1;

        if (EventID and TRIGGER_OB_LEAVE) <> 0 then begin
          BaseEventName := 'OnAfterVisitObject ';
        end else begin
          BaseEventName := 'OnBeforeVisitObject ';
        end;

        result :=
          BaseEventName + SysUtils.IntToStr(ObjType) + '/' + SysUtils.IntToStr(ObjSubtype);
      end; // .else
    end else begin
      if GetErmFuncName(EventID, result) then begin
        // Ok
      end else begin
        result := 'OnErmFunction ' + SysUtils.IntToStr(EventID);
      end;
    end; // .else
  end; // .switch
end; // .function GetTriggerReadableName

procedure SetZVar (Str: pchar; const Value: string); overload;
begin
  Utils.SetPcharValue(Str, Value, sizeof(z[1]));
end;

procedure SetZVar (Str, Value: pchar); overload;
begin
  Utils.SetPcharValue(Str, Value, sizeof(z[1]));
end;

function IsMutableZVarIndex (Ind: integer): boolean;
begin
  result := ((Ind >= Low(z^)) and (Ind <= High(z^))) or (-Ind in [Low(nz^)..High(nz^)]);
end;

function GetZVarAddr (Ind: integer): pchar;
begin
  if Ind > High(z^) then begin
    result := ZvsGetErtStr(Ind);
  end else if Ind >= Low(z^) then begin
    result := @z[Ind];
  end else if -Ind in [Low(nz^)..High(nz^)] then begin
    result := @nz[-Ind];
  end else begin
    ShowErmError('Invalid z-var index: ' + SysUtils.IntToStr(Ind));
    result := 'STRING NOT FOUND';
  end;
end;

function InterpolateErmStr (Str: pchar): pchar; cdecl; forward;

function GetInterpolatedZVarAddr (Ind: integer): pchar;
begin
  if Ind > High(z^) then begin
    result := ZvsGetErtStr(Ind);

    if (Ind < FIRST_LOCAL_ERT_INDEX) or (Ind > LAST_LOCAL_ERT_INDEX) then begin
      result := InterpolateErmStr(result);
    end;
  end else if Ind >= Low(z^) then begin
    result := @z[Ind];
  end else if -Ind in [Low(nz^)..High(nz^)] then begin
    result := @nz[-Ind];
  end else begin
    ShowErmError('Invalid z-var index: ' + SysUtils.IntToStr(Ind));
    result := 'STRING NOT FOUND';
  end;
end;

procedure ClearErmCmdCache;
begin
  with DataLib.IterateDict(ErmCmdCache) do begin
    while IterNext do begin
      FreeMem(Utils.PtrOfs(PErmCmd(IterValue).CmdHeader.Value, -Length('!!')));
      Dispose(PErmCmd(IterValue));
    end;
  end;

  ErmCmdCache.Clear;
end; // .procedure ClearErmCmdCache

procedure ExecSingleErmCmd (const CmdStr: string);
const
  LETTERS = ['A'..'Z'];
  DIGITS  = ['0'..'9'];
  SIGNS   = ['+', '-'];
  NUMBER  = DIGITS + SIGNS;
  DELIMS  = ['/', ':'];

var
{U} Cmd:      PErmCmd;
    CmdName:  string;
    NumArgs:  integer;
    Res:      boolean;
    c:        char;

  function ReadNum (out Num: integer): boolean;
  var
    StartPos: integer;
    Token:    string;
    c:        char;

  begin
    result := ErmScanner.GetCurrChar(c) and (c in NUMBER);

    if result then begin
      if c in SIGNS then begin
        StartPos := ErmScanner.Pos;
        ErmScanner.GotoNextChar;
        ErmScanner.SkipCharset(DIGITS);
        Token := ErmScanner.GetSubstrAtPos(StartPos, ErmScanner.Pos - StartPos);
      end else begin
        ErmScanner.ReadToken(DIGITS, Token);
      end;

      result := SysUtils.TryStrToInt(Token, Num) and ErmScanner.GetCurrChar(c) and (c in DELIMS);
    end; // .if
  end; // .function ReadNum

  function ReadArg (out Arg: TErmCmdParam): boolean;
  var
    ValType: TErmValType;
    IndType: TErmValType;

  begin
    result := ErmScanner.GetCurrChar(c) and GetErmValType(c, ValType);

    if result then begin
      IndType := ValNum;

      if ValType <> ValNum then begin
        result := ErmScanner.GotoNextChar and ErmScanner.GetCurrChar(c) and
                  GetErmValType(c, IndType);

        if result and (IndType <> ValNum) then begin
          ErmScanner.GotoNextChar;
        end;
      end;

      if result then begin
        result := ReadNum(Arg.Value);

        if result then begin
          Arg.ValType := ord(IndType) shl 4 + ord(ValType);
        end;
      end;
    end; // .if
  end; // .function ReadArg

begin
  Cmd := ErmCmdCache[CmdStr];
  // * * * * * //
  Res := true;

  if Cmd = nil then begin
    New(Cmd);
    FillChar(Cmd^, sizeof(Cmd^), 0);
    ErmScanner.Connect(CmdStr, LINE_END_MARKER);
    Res     := ErmScanner.ReadToken(LETTERS, CmdName) and (Length(CmdName) = 2);
    NumArgs := 0;

    while Res and ErmScanner.GetCurrChar(c) and (c <> ':') and (NumArgs < ERM_CMD_MAX_PARAMS_NUM) do begin
      Res := ReadArg(Cmd.Params[NumArgs]) and ErmScanner.GetCurrChar(c);

      if Res then begin
        Inc(NumArgs);

        if c = '/' then begin
          ErmScanner.GotoNextChar;
        end;
      end;
    end; // .while

    Res := Res and ErmScanner.GotoNextChar;

    if Res then begin
      Cmd.SetIsGenerated(true);

      // Allocate memory, because ERM engine changes command contents during execution
      GetMem(Cmd.CmdHeader.Value, Length(CmdStr) + 1 + Length('!!'));
      pchar(Cmd.CmdHeader.Value)[0] := '!';
      pchar(Cmd.CmdHeader.Value)[1] := '!';
      Inc(pchar(Cmd.CmdHeader.Value), 2);
      Utils.CopyMem(Length(CmdStr) + 1, pointer(CmdStr), Cmd.CmdHeader.Value);

      Cmd.CmdBody.Value := Utils.PtrOfs(Cmd.CmdHeader.Value, ErmScanner.Pos - 1);
      Cmd.CmdId.Name[0] := CmdName[1];
      Cmd.CmdId.Name[1] := CmdName[2];
      Cmd.NumParams     := NumArgs;
      Cmd.CmdHeader.Len := ErmScanner.Pos - 1;
      Cmd.CmdBody.Len   := Length(CmdStr) - ErmScanner.Pos + 1;

      if @ErmCmdOptimizer <> nil then begin
        ErmCmdOptimizer(Cmd);
      end;

      if ErmCmdCache.ItemCount = ERM_CMD_CACHE_LIMIT then begin
        ClearErmCmdCache;
      end;

      ErmCmdCache[CmdStr] := Cmd;
    end; // .if
  end; // .if

  if not Res then begin
    ShowMessage('ExecErmCmd: Invalid command "' + CmdStr + '"');
  end else begin
    ZvsProcessCmd(Cmd);
  end;
end; // .procedure ExecSingleErmCmd

procedure ExecErmCmd (const CmdStr: string);
var
  Commands: Utils.TArrayOfStr;
  Command:  string;
  i:        integer;

begin
  Commands := StrLib.ExplodeEx(CmdStr, ';', StrLib.INCLUDE_DELIM, not StrLib.LIMIT_TOKENS, 0);

  for i := 0 to High(Commands) do begin
    Command := SysUtils.Trim(Commands[i]);

    if Command <> '' then begin
      if (i = High(Commands)) and (Command[Length(Command)] <> ';') then begin
        Command := Command + ';';
      end;

      ExecSingleErmCmd(Command);
    end;
  end; // .for
end; // .procedure ExecErmCmd

procedure OnEraSaveScripts (Event: GameExt.PEvent); stdcall;
begin
  (* Save function names and auto ID *)
  with Stores.NewRider(FUNC_NAMES_SECTION) do begin
    WriteInt(FuncAutoId);
    WriteStr(DataLib.SerializeDict(FuncNames));
  end;

  ScriptMan.SaveScripts;
end;

procedure OnEraLoadScripts (Event: GameExt.PEvent); stdcall;
begin
  (* Read function names and auto ID *)
  with Stores.NewRider(FUNC_NAMES_SECTION) do begin
    FuncAutoId := ReadInt;
    FuncNames  := DataLib.UnserializeDict(ReadStr, not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  end;

  FreeAndNil(FuncIdToNameMap);
  FuncIdToNameMap := DataLib.FlipDict(FuncNames);

  (* Load scripts *)
  ScriptMan.LoadScriptsFromSavedGame;
end;

function Hook_LoadErtFile (Context: Core.PHookContext): longbool; stdcall;
const
  ARG_FILENAME = 2;

var
  FileName: pchar;

begin
  FileName := pchar(pinteger(Context.EBP + 12)^);
  Utils.CopyMem(SysUtils.StrLen(FileName) + 1, FileName, Ptr(Context.EBP - $410));

  Context.RetAddr := Ptr($72C760);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_LoadErtFile

procedure LoadErtFile (const ErmScriptName: string);
var
  ErtFilePath: string;

begin
  ErtFilePath := ERM_SCRIPTS_PATH + '\' + SysUtils.ChangeFileExt(ErmScriptName, '.ert');

  if SysUtils.FileExists(ErtFilePath) then begin
    ZvsLoadErtFile('', pchar('..\' + ErtFilePath));
  end;
end;

function Hook_LoadErsFiles (Context: ApiJack.PHookContext): longbool; stdcall;
var
{O} TextTable:         Heroes.TTextTable;
    TextTableContents: string;

begin
  TextTable := nil;
  // * * * * * //
  with Files.Locate(GameExt.GameDir + '\' + ERS_FILES_PATH + '\*.ers', Files.ONLY_FILES) do begin
    while FindNext do begin
      if Files.ReadFileContents(FoundPath, TextTableContents) then begin
        TextTable := Heroes.TTextTable.Create(Heroes.ParseTextTable(TextTableContents));
        LoadedErsFiles.Add(TextTable); TextTable := nil;
      end;
    end;
  end;

  Context.RetAddr := Ptr($77941A);
  result          := false;
  // * * * * * //
  SysUtils.FreeAndNil(TextTable);
end; // .function Hook_LoadErsFiles

function Hook_ApplyErsOptions (Context: ApiJack.PHookContext): longbool; stdcall;
var
{U} TextTable: Heroes.TTextTable;
    i, j:      integer;

begin
  TextTable := nil;
  // * * * * * //
  for i := 0 to LoadedErsFiles.Count - 1 do begin
    TextTable := Heroes.TTextTable(LoadedErsFiles[i]);

    for j := 0 to TextTable.NumRows - 1 do begin
      ZvsAddItemToWogOptions(
        Heroes.a2i(pchar(TextTable[j, 1])),
        Heroes.a2i(pchar(TextTable[j, 2])),
        Heroes.a2i(pchar(TextTable[j, 3])),
        Heroes.a2i(pchar(TextTable[j, 4])),
        Heroes.a2i(pchar(TextTable[j, 5])),
        Heroes.a2i(pchar(TextTable[j, 6])),
        Heroes.a2i(pchar(TextTable[j, 7])),
        pchar(TextTable[j, 8]),
        pchar(TextTable[j, 9]),
        pchar(TextTable[j, 10]),
      );
    end;
  end; // .for

  Context.RetAddr := Ptr($778613);
  result          := false;
end; // .function Hook_ApplyErsOptions



function AddrToLineAndPos (Document: pchar; DocSize: integer; CharPos: pchar; var LineN: integer; var LinePos: integer): boolean;
var
{Un} CharPtr: pchar;

begin
  CharPtr := nil;
  // * * * * * //
  result := (cardinal(CharPos) >= cardinal(Document)) and (cardinal(CharPos) < cardinal(Document) + cardinal(DocSize));

  if result then begin
    LineN   := 1;
    LinePos := 1;
    CharPtr := Document;

    while CharPtr <> CharPos do begin
      if CharPtr^ = #10 then begin
        inc(LineN);
        LinePos := 1;
      end else begin
        inc(LinePos);
      end;

      inc(CharPtr);
    end;
  end; // .if
end; // .function AddrToLineAndPos

function EscapeErmLiteralContents (const Literal: string): string;
var
{O} Buf:      TStrBuilder;
    Str:      pchar;
    StartPos: pchar;
    c:        char;

begin
  Buf := TStrBuilder.Create;
  Str := pchar(Literal);
  // * * * * * //
  while Str^ <> #0 do begin
    StartPos := Str;

    while not (Str^ in [#0, ';', '^', '%']) do begin
      Inc(Str);
    end;

    if Str > StartPos then begin
      Buf.AppendBuf(Str - StartPos, StartPos);
    end;

    c := Str^;

    case c of
      ';': begin
        Buf.Append('%\:');
        Inc(Str);
      end;

      '^': begin
        Buf.Append('%\"');
        Inc(Str);
      end;

      '%': begin
        Buf.Append('%%');
        Inc(Str);
      end;
    end;
  end; // .while

  result := Buf.BuildStr;
  // * * * * * //
  SysUtils.FreeAndNil(Buf);
end; // .function EscapeErmLiteralContents

type
  TErmLocalVar = class
    VarType:    char;
    IsNegative: boolean;
    StartIndex: integer;
    Count:      integer;
  end;

function PreprocessErm (const ScriptName, Script: string): string;
const
  ERM2_SIGNATURE = 'ZVSE2';

  ANY_CHAR            = [#1..#255];
  IDENT_CHARS         = ANY_CHAR - ['(', ')', #10, #13];
  LABEL_CHARS         = ANY_CHAR - [']', #10, #13];
  SPECIAL_CHARS       = ['[', '!'];
  INCMD_SPECIAL_CHARS = ['[', '(', '^', ';', '%'];
  CMD_END_CHARSET     = [';', #0];
  SAFE_BLANKS         = [#1..#32];
  NUMBER_START_CHARS  = ['+', '-', '0'..'9'];
  DIGITS              = ['0'..'9'];

  IDENT_TYPE_CONST = 1;
  IDENT_TYPE_FUNC  = 2;
  IDENT_TYPE_VAR   = 3;

  IS_INDIRECT_ADDRESSING = true;

  SUPPORTED_LOCAL_VAR_TYPES = ['x', 'y', 'e', 'z'];
  LOCAL_VAR_TYPE_ID_Y = 0;
  LOCAL_VAR_TYPE_ID_X = 1;
  LOCAL_VAR_TYPE_ID_Z = 2;
  LOCAL_VAR_TYPE_ID_E = 3;

  NO_LABEL = -1;

type
  TScope   = (GLOBAL_SCOPE, CMD_SCOPE);
  TCmdType = (CMD_TYPE_INSTRUCTION, CMD_TYPE_RECEIVER, CMD_TYPE_TRIGGER);

  PParsedLocalVar = ^TParsedLocalVar;
  TParsedLocalVar = record
    Name:          string;
    Index:         integer;
    VarType:       char;
    IsFreeing:     boolean;
    IsDeclaration: boolean;
    IsAddr:        boolean;
    HasIndex:      boolean;
  end;

  PVarRange = ^TVarRange;
  TVarRange = record
       StartIndex: integer;
       Count:      integer;
  {On} NextRange:  PVarRange;
  end;

  PLocalVarsPool = ^TLocalVarsPool;
  TLocalVarsPool = record
       StartIndex: integer;
       Count:      integer;
       IsNegative: longbool;
  {On} FreeRanges: PVarRange;
  end;

var
{
  For unresolved labels value for key is index of previous unresolved label in Buf.
  Zero indexes are ignored.
}
{O} Buf:                TStrList {of integer};
{O} Scanner:            TextScan.TTextScanner;
{O} Labels:             TDict {of CmdN + 1};
{O} LocalVars:          {O} TDict {of TErmLocalVar };
    LocalVarsPools:     array [LOCAL_VAR_TYPE_ID_Y..LOCAL_VAR_TYPE_ID_E] of TLocalVarsPool;
    UnresolvedLabelInd: integer; // index of last unresolved label or NO_LABEL
    CmdN:               integer; // index of next command
    StartPos:           integer;
    ConstValue:         integer;
    ExistingConstValue: integer;
    MarkedPos:          integer;
    IsInStr:            longbool;
    IsErm2:             longbool;
    VarPos:             integer;
    c:                  char;

  procedure ShowError (ErrPos: integer; const Error: string);
  var
    LineN:   integer;
    LinePos: integer;

  begin
    if not Scanner.PosToLine(ErrPos, LineN, LinePos) then begin
      LineN   := -1;
      LinePos := -1;
    end;

    ShowMessage(Format('{~gold}Error in "%s".'#10'Line: %d. Position: %d.{~}'#10 +
                       '%s.'#10#10'Context:'#10#10'%s',
                       [ScriptName, LineN, LinePos, Error,
                        Scanner.GetSubstrAtPos(ErrPos - 20, 20) + ' <<< ' +
                        Scanner.GetSubstrAtPos(ErrPos + 0,  100)]));
  end; // .procedure ShowError

  procedure MarkPos;
  begin
    MarkedPos := Scanner.Pos;
  end;

  procedure FlushMarked;
  begin
    if Scanner.Pos > MarkedPos then begin
      Buf.Add(Scanner.GetSubstrAtPos(MarkedPos, Scanner.Pos - MarkedPos));
      MarkedPos := Scanner.Pos;
    end;
  end;

  procedure DeclareLabel (const LabelName: string);
  begin
    Labels[LabelName] := Ptr(CmdN + 1);
  end;

  procedure ParseLabel (Scope: TScope);
  var
    IsDeclaration: boolean;
    LabelName:     string;
    LabelValue:    integer;
    c:             char;

  begin
    FlushMarked;
    Scanner.GotoNextChar;

    IsDeclaration := Scanner.GetCurrChar(c) and (c = ':');

    if IsDeclaration then begin
      Scanner.GotoNextChar;
    end;

    if Scanner.ReadToken(LABEL_CHARS, LabelName) and Scanner.GetCurrChar(c) then begin
      if c = ']' then begin
        Scanner.GotoNextChar;

        if IsDeclaration then begin
          if Scope = GLOBAL_SCOPE then begin
            DeclareLabel(LabelName);
          end else begin
            ShowError(Scanner.Pos, 'Label declaration inside command is prohibited');
          end;
        end else begin
          if Scope = CMD_SCOPE then begin
            LabelValue := integer(Labels[LabelName]);

            if LabelValue = 0 then begin
              UnresolvedLabelInd := Buf.AddObj(LabelName, Ptr(UnresolvedLabelInd));
            end else begin
              Buf.Add(IntToStr(LabelValue - 1));
            end;
          end else begin
            FlushMarked;
          end; // .else
        end; // .else
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in label name');

        if not IsDeclaration then begin
          Buf.Add('999999');
        end;
      end; // .else
    end else begin
      ShowError(Scanner.Pos, 'Missing closing "]"');

      if not IsDeclaration then begin
        Buf.Add('999999');
      end;
    end; // .else

    MarkPos;
  end; // .procedure ParseLabel

  procedure ResolveLabels;
  var
    LabelName:  string;
    LabelValue: integer;
    i:          integer;

  begin
    i := UnresolvedLabelInd;

    while i <> NO_LABEL do begin
      LabelName  := Buf[i];
      LabelValue := integer(Labels[LabelName]);

      if LabelValue = 0 then begin
        ShowError(Scanner.Pos, 'Unresolved label "' + LabelName + '"');
        Buf[i] := '999999';
      end else begin
        Buf[i] := IntToStr(LabelValue - 1);
      end;

      i := integer(Buf.Values[i]);
    end; // .while

    UnresolvedLabelInd := NO_LABEL;
  end; // .procedure ResolveLabels

  procedure InitLocalVarsPools;
  begin
    with LocalVarsPools[LOCAL_VAR_TYPE_ID_Y] do begin
      StartIndex := 1;
      Count      := 100;
      IsNegative := false;
      FreeRanges := nil;
    end;

    with LocalVarsPools[LOCAL_VAR_TYPE_ID_X] do begin
      StartIndex := 1;
      Count      := 15;
      IsNegative := false;
      FreeRanges := nil;
    end;

    with LocalVarsPools[LOCAL_VAR_TYPE_ID_Z] do begin
      StartIndex := 1;
      Count      := 10;
      IsNegative := true;
      FreeRanges := nil;
    end;

    with LocalVarsPools[LOCAL_VAR_TYPE_ID_E] do begin
      StartIndex := 1;
      Count      := 100;
      IsNegative := false;
      FreeRanges := nil;
    end;
  end; // procedure InitLocalVarsPools

  procedure FinalizeLocalVarsPools;
  var
    ListItem:     PVarRange;
    PrevListItem: PVarRange;
    i:            integer;

  begin
    for i := Low(LocalVarsPools) to High(LocalVarsPools) do begin
      ListItem := LocalVarsPools[i].FreeRanges;

      while ListItem <> nil do begin
        PrevListItem := ListItem;
        ListItem     := ListItem.NextRange;
        Dispose(PrevListItem);
      end;

      LocalVarsPools[i].FreeRanges := nil;
    end;

    LocalVars.Clear;
  end; // procedure FinalizeLocalVarsPools

  function LocalVarCharToId (c: char): integer;
  begin
    case c of
      'y': result := LOCAL_VAR_TYPE_ID_Y;
      'x': result := LOCAL_VAR_TYPE_ID_X;
      'z': result := LOCAL_VAR_TYPE_ID_Z;
      'e': result := LOCAL_VAR_TYPE_ID_E;
    else
      Assert(false, 'LocalVarCharToId: unknown variable type: ' + c);
      result := 0;
    end;
  end;

  function ParseLocalVar (VarName: pchar; var ParsedVar: TParsedLocalVar): boolean;
  var
    StartPtr: pchar;

  begin
    ParsedVar.IsFreeing     := VarName^ = '-';
    ParsedVar.IsDeclaration := false;
    ParsedVar.HasIndex      := false;
    ParsedVar.Index         := 1;

    if ParsedVar.IsFreeing then begin
      Inc(VarName);
    end else begin
      ParsedVar.IsAddr := VarName^ = '@';

      if ParsedVar.IsAddr then begin
        Inc(VarName);
      end;
    end;

    StartPtr := VarName;
    result   := VarName^ in ['a'..'z'];

    if not result then begin
      ShowError(VarPos, 'Local variable must start with "a".."z" character');
      exit;
    end;

    while (VarName^ in ['a'..'z', 'A'..'Z', '0'..'9']) do begin
      Inc(VarName);
    end;

    ParsedVar.Name := StrLib.ExtractFromPchar(StartPtr, integer(VarName) - integer(StartPtr));
    result         := VarName^ in [#0, '[', ':'];

    if not result then begin
      ShowError(VarPos, 'Invalid character in local variable name: "' + VarName^ + '"');
      exit;
    end else if VarName^ = #0 then begin
      exit;
    end;

    if VarName^ = '[' then begin
      Inc(VarName);
      ParsedVar.HasIndex := true;
      StartPtr           := VarName;

      while (VarName^ in ['-', '0'..'9']) do begin
        Inc(VarName);
      end;

      result := (VarName^ = ']') and SysUtils.TryStrToInt(StrLib.ExtractFromPchar(StartPtr, integer(VarName) - integer(StartPtr)), ParsedVar.Index);

      if result then begin
        Inc(VarName);
      end else begin
        ShowError(VarPos, 'Invalid ERM local array subscript');
        exit;
      end;
    end; // .if

    result := VarName^ in [#0, ':'];

    if not result then begin
      ShowError(VarPos, 'Unexpected local variable termination. Expected ")" or ":"');
      exit;
    end else if VarName^ = #0 then begin
      exit;
    end;

    Inc(VarName);
    ParsedVar.IsDeclaration := true;
    result                  := VarName^ in SUPPORTED_LOCAL_VAR_TYPES;

    if not result then begin
      ShowError(VarPos, 'Invalid local variable type in declaration. Expected one of "x", "y", "z" or "e"');
      exit;
    end else begin
      ParsedVar.VarType := VarName^;
    end;
  end; // .function ParseLocalVar

  procedure FreeLocalVar (const VarName: string);
  var
  {Un} LocalVar: TErmLocalVar;
       VarsPool: PLocalVarsPool;
       VarRange: PVarRange;

  begin
    LocalVar := LocalVars[VarName];

    if LocalVar = nil then begin
      ShowError(VarPos, 'Cannot free local ERM variable, which was never allocated. Variable name: ' + VarName);
    end else begin
      VarsPool := @LocalVarsPools[LocalVarCharToId(LocalVar.VarType)];

      if VarsPool.StartIndex = (LocalVar.StartIndex + LocalVar.Count) then begin
        Dec(VarsPool.StartIndex, LocalVar.Count);
        Inc(VarsPool.Count, LocalVar.Count);
      end else begin
        New(VarRange);
        VarRange.StartIndex := LocalVar.StartIndex;
        VarRange.Count      := LocalVar.Count;
        VarRange.NextRange  := VarsPool.FreeRanges;
        VarsPool.FreeRanges := VarRange;
      end;

      LocalVars.DeleteItem(VarName);
    end; // .else
  end; // .procedure FreeLocalVar

  function AllocLocalVar (const VarName: string; VarType: char; Count: integer; {Un} out LocalVar: TErmLocalVar): boolean;
  var
    VarsPool:  PLocalVarsPool;
    VarRange:  PVarRange;
    PrevRange: PVarRange;

  begin
    VarsPool := @LocalVarsPools[LocalVarCharToId(VarType)];
    result   := false;

    if Count < 0 then begin
      ShowError(VarPos, 'Cannot allocate local ERM variables array of ' + IntToStr(Count) + ' size');
      exit;
    end;

    if Count = 0 then begin
      Inc(Count);
    end;

    VarRange  := VarsPool.FreeRanges;
    PrevRange := nil;

    while not result and (VarRange <> nil) do begin
      if VarRange.Count >= Count then begin
        result              := true;
        LocalVar            := TErmLocalVar.Create;
        LocalVar.StartIndex := VarRange.StartIndex;
        LocalVar.Count      := Count;
        LocalVar.VarType    := VarType;
        LocalVar.IsNegative := VarsPool.IsNegative;
        LocalVars[VarName]  := LocalVar;

        if VarRange.Count = Count then begin
          if PrevRange = nil then begin
            VarsPool.FreeRanges := VarRange.NextRange;
          end else begin
            PrevRange.NextRange := VarRange.NextRange;
          end;

          Dispose(VarRange);
        end else begin
          Inc(VarRange.StartIndex, Count);
          Dec(VarRange.Count,      Count);
        end;
      end else begin
        VarRange := VarRange.NextRange;
      end; // .else

      PrevRange := VarRange;
    end; // .while  

    if not result then begin
      if VarsPool.Count < Count then begin
        ShowError(VarPos, 'Cannot allocate more local ' + VarType + '-vars');
      end else begin
        result              := true;
        LocalVar            := TErmLocalVar.Create;
        LocalVar.StartIndex := VarsPool.StartIndex;
        LocalVar.Count      := Count;
        LocalVar.VarType    := VarType;
        LocalVar.IsNegative := VarsPool.IsNegative;
        LocalVars[VarName]  := LocalVar;
        Inc(VarsPool.StartIndex, Count);
        Dec(VarsPool.Count,      Count);
      end;
    end;
  end; // .function AllocLocalVar

  function GetLocalVar (const VarName: string; out {Un} LocalVar: TErmLocalVar; out ArrIndex: integer; out IsAddr: longbool): boolean;
  var
    ParsedVar: TParsedLocalVar;

  begin
    result := ParseLocalVar(pchar(VarName), ParsedVar);

    if result then begin
      IsAddr   := ParsedVar.IsAddr;
      ArrIndex := 0;

      if ParsedVar.HasIndex and not ParsedVar.IsDeclaration then begin
        ArrIndex := ParsedVar.Index;
      end;

      if ParsedVar.IsFreeing then begin
        FreeLocalVar(ParsedVar.Name);
        LocalVar := nil;
      end else begin
        LocalVar := LocalVars[ParsedVar.Name];

        if LocalVar = nil then begin
          result := ParsedVar.IsDeclaration;

          if not result then begin
            ShowError(VarPos, Format('Usage of underclared local variable "%s". Assuming "t"-variable', [ParsedVar.Name]));
          end else begin
            result := AllocLocalVar(ParsedVar.Name, ParsedVar.VarType, ParsedVar.Index, LocalVar);
          end;
        end else begin
          if ParsedVar.IsDeclaration and ((LocalVar.VarType <> ParsedVar.VarType) or (LocalVar.Count <> ParsedVar.Index)) then begin
            ShowError(VarPos, Format('Redeclaration of local variable "%s" must have the same type and length as original declaration', [ParsedVar.Name]));
            result := false; exit;
          end;

          if ArrIndex < 0 then begin
            ArrIndex := LocalVar.Count + ArrIndex;
          end;

          result := (ArrIndex >= 0) and (ArrIndex < LocalVar.Count);

          if not result then begin
            ShowError(VarPos, Format('Local array index %d is out of range: 0..%d', [ArrIndex, LocalVar.Count - 1]));
          end;
        end; // .else
      end; // .else
    end; // .if
  end; // .unction GetLocalVar

  procedure HandleLocalVar (const VarName: string; VarStartPos: integer; IsIndirectAddressing: longbool);
  var
  {U} LocalVar: TErmLocalVar;
      VarIndex: integer;
      ArrIndex: integer;
      IsAddr:   longbool;

  begin
    VarPos := VarStartPos;

    if not GetLocalVar(VarName, LocalVar, ArrIndex, IsAddr) then begin
      Buf.Add('0');
    end
    // It it's not free var operation
    else if LocalVar <> nil then begin
      VarIndex := LocalVar.StartIndex + ArrIndex;

      if LocalVar.IsNegative then begin
        VarIndex := -VarIndex;
      end;

      if not IsAddr then begin
        if IsInStr then begin
          if not IsIndirectAddressing then begin
            Buf.Add('%');
          end;
          
          Buf.Add(LocalVar.VarType + IntToStr(VarIndex));
        end else begin
          Buf.Add(LocalVar.VarType + IntToStr(VarIndex));
        end;
      end else begin
        Buf.Add(IntToStr(VarIndex));
      end;
    end; // .elseif
  end; // .procedure HandleLocalVar

  function HandleConstDeclaration: boolean;
  var
    ConstName: string;

  begin
    Scanner.GotoRelPos(-2);
    FlushMarked;

    Scanner.GotoRelPos(+4);
    result := Scanner.c = '(';

    if not result then begin
      ShowError(Scanner.Pos, 'Expected "(" character in const declaration');
    end else begin
      Scanner.GotoNextChar;
      StartPos := Scanner.Pos;
      Scanner.SkipCharset(CONST_NAME_CHARSET);
      result := Scanner.c = ')';

      if not result then begin
        ShowError(Scanner.Pos, 'Invalid constant name. Expected [A-Z_] characters');
      end;
    end;

    if result then begin
      ConstName := Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos);
      Scanner.GotoNextChar;
      Scanner.SkipCharset(SAFE_BLANKS);
      result := Scanner.c = '=';

      if not result then begin
        ShowError(Scanner.Pos, 'Expected "=" character and constant value');
      end;
    end;

    if result then begin
      ExistingConstValue := 0;
      result             := not GlobalConsts.GetExistingValue(ConstName, pointer(ExistingConstValue));

      if not result then begin
        ShowError(StartPos, Format('Global constant "%s" is already defined with value %d', [ConstName, ExistingConstValue]));
      end;
    end;

    if result then begin
      Scanner.GotoNextChar;
      Scanner.SkipCharset(SAFE_BLANKS);

      result := Scanner.c in NUMBER_START_CHARS;

      if not result then begin
        ShowError(Scanner.Pos, 'Expected valid integer as constant value');
      end;
    end;

    if result then begin
      StartPos := Scanner.Pos;
      Scanner.GotoNextChar;
      Scanner.SkipCharset(DIGITS);
      result := Scanner.c = ';';

      if not result then begin
        ShowError(Scanner.Pos, 'Expected ";" character as const declaration end marker');
      end;
    end;

    if result then begin
      result := TryStrToInt(Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos), ConstValue);

      if not result then begin
        ShowError(StartPos, 'Expected valid integer as constant value');
      end else begin
        GlobalConsts[ConstName] := Ptr(ConstValue);
      end;
    end;

    // Recover from error
    if not result then begin
      Scanner.FindCharset(CMD_END_CHARSET);
    end;

    MarkPos;
  end; // .function HandleConstDeclaration

  function DetectIdentType (const Ident: string; out IdentType: integer): boolean;
  var
    FirstChar: char;
    CharPos:   integer;

  begin
    result := Ident <> '';

    if result then begin
      FirstChar := Ident[1];

      if FirstChar in ['A'..'Z'] then begin
        if not StrLib.SkipCharsetEx(['A'..'Z', '0'..'9', '_'], Ident, 1, CharPos) then begin
          IdentType := IDENT_TYPE_CONST;
        end else if not StrLib.SkipCharsetEx(['A'..'Z', 'a'..'z', '0'..'9', '_'], Ident, CharPos, CharPos) then begin
          IdentType := IDENT_TYPE_FUNC;
        end else begin
          result := false;
        end;
      end else if FirstChar in ['@', '-'] then begin
        IdentType := IDENT_TYPE_VAR;
      end else if FirstChar in ['a'..'z'] then begin
        if not StrLib.FindChar('_', Ident, CharPos) then begin
          IdentType := IDENT_TYPE_VAR;
        end else if not StrLib.SkipCharsetEx(['A'..'Z', 'a'..'z', '0'..'9', '_'], Ident, 1, CharPos) then begin
          IdentType := IDENT_TYPE_FUNC;
        end else begin
          result := false;
        end;
      end else begin
        result := false;
      end; // .else
    end; // .if
  end; // .function DetectIdentType

  procedure ParseIdent (IsIndirectAddressing: longbool = false);
  CONST
    LITERAL_FILE = integer($454C4946);
    LITERAL_LINE = integer($454E494C);
    LITERAL_CODE = integer($45444F43);

  var
    StartPos:     integer;
    IdentType:    integer;
    ConstValue:   integer;
    FuncId:       integer;
    Ident:        string;
    IdentAsInt:   integer;
    SavedPos:     integer;
    LineStartPos: integer;
    CodeExcerpt:  string;
    c:            char;

  begin
    StartPos := Scanner.Pos;
    Scanner.GotoNextChar;

    if Scanner.ReadToken(IDENT_CHARS, Ident) and Scanner.GetCurrChar(c) then begin
      if c = ')' then begin
        Scanner.GotoNextChar;

        if Ident = '' then begin
          ShowError(StartPos, 'Empty string is not a valid identifier: (nothing inside parantheses)');
          Buf.Add('999999');
        end else if not IsErm2 then begin
          AllocErmFunc(Ident, FuncId);
          Buf.Add(IntToStr(FuncId));
        end else if not DetectIdentType(Ident, IdentType) then begin
          ShowError(StartPos, 'Invalid identifier: (' + Ident + ')');
          Buf.Add('999999');
        end else begin
          case IdentType of
            IDENT_TYPE_VAR: begin
              HandleLocalVar(Ident, StartPos, IsIndirectAddressing);
            end;

            IDENT_TYPE_CONST: begin
              ConstValue := 0;
              IdentAsInt := 0;

              if Length(Ident) = 4 then begin
                IdentAsInt := pinteger(Ident)^;
              end;

              if (IdentAsInt = LITERAL_FILE) or (IdentAsInt = LITERAL_LINE) or (IdentAsInt = LITERAL_CODE) then begin
                if IdentAsInt = LITERAL_FILE then begin
                  if IsInStr then begin
                    Buf.Add(ScriptName);
                  end else begin
                    Buf.Add('^' + ScriptName + '^');
                  end;                  
                end else if IdentAsInt = LITERAL_LINE then begin
                  Buf.Add(SysUtils.IntToStr(Scanner.LineN));
                end else begin
                  SavedPos     := Scanner.Pos;
                  LineStartPos := Scanner.LineStartPos + 1;

                  if Scanner.GotoNextLine() then begin
                    Scanner.GotoPrevChar();
                  end;

                  if Scanner.Pos > LineStartPos then begin
                    CodeExcerpt := EscapeErmLiteralContents(Copy(Scanner.GetSubstrAtPos(LineStartPos, Scanner.Pos - LineStartPos), 1, 100));

                    if IsInStr then begin
                      Buf.Add(CodeExcerpt);
                    end else begin
                      Buf.Add('^' + CodeExcerpt + '^');
                    end;
                  end;
                  
                  Scanner.GotoPos(SavedPos);
                end; // .else
              end else if GlobalConsts.GetExistingValue(Ident, pointer(ConstValue)) then begin
                Buf.Add(SysUtils.IntToStr(ConstValue));
              end else begin
                ShowError(StartPos, 'Unknown global constant name: "' + Ident + '". Assuming 0');
                GlobalConsts[Ident] := Ptr(0);
                Buf.Add('0');
              end;
            end;

            IDENT_TYPE_FUNC: begin
              AllocErmFunc(Ident, FuncId);
              Buf.Add(IntToStr(FuncId));
            end;
          end; // .switch
        end; // .else
      end else begin
        ShowError(Scanner.Pos, 'Unexpected character in identifier name');
        Buf.Add('999999');
      end;
    end else begin
      ShowError(Scanner.Pos, 'Missing closing ")"');
      Buf.Add('999999');
    end; // .else
  end; // .procedure ParseIdent

  procedure ParseCmd (CmdType: TCmdType);
  var
    c:              char;
    NextChar:       char;
    DummyCmdBufPos: integer;

  begin
    Scanner.GotoNextChar;

    if (CmdType = CMD_TYPE_INSTRUCTION) and (Scanner.c = 'D') and (Scanner.CharsRel[1] = 'C') then begin
      HandleConstDeclaration;
    end else begin
      DummyCmdBufPos := -1;

      if (CmdType = CMD_TYPE_INSTRUCTION) and (Scanner.c = 'V') and (Scanner.CharsRel[1] = 'A') then begin
        Scanner.GotoRelPos(-2);
        FlushMarked;
        Scanner.GotoRelPos(+2);
        DummyCmdBufPos := Buf.Count;
      end;

      c := ' ';

      while Scanner.FindCharset(INCMD_SPECIAL_CHARS) and Scanner.GetCurrChar(c) and ((c <> ';') or IsInStr) do begin
        case c of
          '[': begin
            if not IsInStr and Scanner.GetCharAtRelPos(+1, c) and (c <> ':') then begin
              ParseLabel(CMD_SCOPE);
            end else begin
              Scanner.GotoNextChar;
            end;
          end; // .case '['

          '(': begin
            if not IsInStr then begin
              FlushMarked;
              ParseIdent;
              MarkPos;
            end else begin
              Scanner.GotoNextChar;
            end;
          end; // .case '('

          '^': begin
            Scanner.GotoNextChar;
            IsInStr := not IsInStr;
          end; // .case '^'

          '%': begin
            if IsInStr then begin
              NextChar := Scanner.CharsRel[1];

              // Special support for indirect addressing using local variables in interpolated strings
              // Example: %y(artPtr) may be equal to %yx%(@artPtr) and compile to %yx3
              if (NextChar in (['a'..'z', 'A'..'Z'] - ['s', 'S', 'i', 'I', 'T'])) and (Scanner.CharsRel[2] = '(') then begin
                Scanner.GotoRelPos(+2);
                FlushMarked;
                ParseIdent(IS_INDIRECT_ADDRESSING);
                MarkPos;
              end else begin
                case NextChar of
                  '(': begin
                    FlushMarked;
                    Scanner.GotoNextChar;
                    ParseIdent;
                    MarkPos;
                  end;

                  '%': begin
                    Scanner.GotoRelPos(+2);
                  end;
                else
                  Scanner.GotoNextChar;
                end; // .switch
              end; // .else
            end else begin
              Scanner.GotoNextChar;
            end;
          end; // .case '$'

          ';': begin
            Scanner.GotoNextChar;
          end;
        end; // .switch c
      end; // .while

      if c = ';' then begin
        Scanner.GotoNextChar;
        Inc(CmdN);

        // Erase anything, written during dummy command parsing
        if DummyCmdBufPos <> -1 then begin
          Buf.SetCount(DummyCmdBufPos);
          MarkPos;
        end;
      end;

      IsInStr := false;
    end; // .else
  end; // .procedure ParseCmd

begin
  Buf       := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Scanner   := TextScan.TTextScanner.Create;
  Labels    := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  LocalVars := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  // * * * * * //
  Scanner.Connect(Script, #10);
  MarkedPos          := 1;
  CmdN               := 999000; // CmdN must not be used in instructions
  UnresolvedLabelInd := NO_LABEL;
  IsErm2             := (Length(Script) > 5) and (Copy(Script, 1, 5) = ERM2_SIGNATURE);
  IsInStr            := false;

  if IsErm2 then begin
    InitLocalVarsPools;
  end;

  while Scanner.FindCharset(SPECIAL_CHARS) do begin
    Scanner.GetCurrChar(c);

    case c of
      '!': begin
        Scanner.GotoNextChar;

        if Scanner.GetCurrChar(c) then begin
          case c of
            '!': begin
              if Scanner.GetCharAtRelPos(+1, c) and (c = '!') then begin
                FlushMarked;
                Scanner.SkipChars('!');
                MarkPos;
              end else begin
                ParseCmd(CMD_TYPE_RECEIVER);
              end;
            end; // .case '!'

            '?', '$': begin
              if IsErm2 then begin
                FinalizeLocalVarsPools;
                InitLocalVarsPools;
              end;

              ResolveLabels;
              Labels.Clear;
              CmdN := -1;
              ParseCmd(CMD_TYPE_TRIGGER);
            end; // .case '?'

            '#': begin
              ParseCmd(CMD_TYPE_INSTRUCTION);
            end; // .case '!'
          end; // .switch c
        end; // .if
      end; // .case '!'

      '[': begin
        if Scanner.GetCharAtRelPos(+1, c) and (c = ':') then begin
          ParseLabel(GLOBAL_SCOPE);
        end else begin
          Scanner.GotoNextChar;
        end;
      end; // .case '['
    end; // .switch c
  end; // .while

  if IsErm2 then begin
    FinalizeLocalVarsPools;
  end;

  if MarkedPos = 1 then begin
    result := Script;
  end else begin
    FlushMarked;
    ResolveLabels;
    result := Buf.ToText('');
  end;
  // * * * * * //
  SysUtils.FreeAndNil(Buf);
  SysUtils.FreeAndNil(Scanner);
  SysUtils.FreeAndNil(Labels);
  SysUtils.FreeAndNil(LocalVars);
end; // .function PreprocessErm

(* Returns list of files in specified locations, sorted by numeric priorities like '906 file name.erm'.
   The higher priority is, the ealier in the list item will appear. If same files exists ib several
   locations, files from the earlier locations take precedence *)
function GetOrderedPrioritizedFileList (const MaskedPaths: array of string): {O} Lists.TStringList;
const
  PRIORITY_SEPARATOR  = ' ';
  DEFAULT_PRIORITY    = 0;

  FILENAME_NUM_TOKENS = 2;
  PRIORITY_TOKEN      = 0;
  FILENAME_TOKEN      = 1;

var
  FileNameTokens: Utils.TArrayOfStr;
  Priority:       integer;
  TestPriority:   integer;
  ItemInd:        integer;
  i:              integer;
  j:              integer;

begin
  result        := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  result.Sorted := true;

  for i := 0 to High(MaskedPaths) do begin
    with Files.Locate(MaskedPaths[i], Files.ONLY_FILES) do begin
      while FindNext do begin
        FileNameTokens := StrLib.ExplodeEx(FoundName, PRIORITY_SEPARATOR, not StrLib.INCLUDE_DELIM, StrLib.LIMIT_TOKENS, FILENAME_NUM_TOKENS);
        Priority       := DEFAULT_PRIORITY;

        if (Length(FileNameTokens) = FILENAME_NUM_TOKENS) and (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority)) then begin
          Priority := TestPriority;
        end;

        if not result.Find(FoundName, ItemInd) then begin
          result.AddObj(FoundName, Ptr(Priority));
        end;
      end;
    end; // .with
  end; // .for

  result.Sorted := false;

  (* Sort via insertion by Priority *)
  for i := 1 to result.Count - 1 do begin
    Priority := integer(result.Values[i]);
    j        := i - 1;

    while (j >= 0) and (Priority > integer(result.Values[j])) do begin
      Dec(j);
    end;

    result.Move(i, j + 1);
  end;
end; // .function GetOrderedPrioritizedFileList

constructor TScriptMan.Create;
begin
  inherited;
  fScripts := RscLists.TResourceList.Create;
end;

destructor TScriptMan.Destroy;
begin
  SysUtils.FreeAndNil(fScripts);
  inherited;
end;

procedure TScriptMan.ClearScripts;
begin
  EventMan.GetInstance.Fire('OnBeforeClearErmScripts');
  fScripts.Clear;

  if TrackingOpts.Enabled then begin
    EventTracker.Reset;
  end;
end;

procedure TScriptMan.SaveScripts;
begin
  Self.fScripts.Save(ERM_SCRIPTS_SECTION);
end;

function TScriptMan.LoadScript (const ScriptPath: string; ScriptName: string = ''): boolean;
var
  ScriptContents:     string;
  PreprocessedScript: string;

begin
  if ScriptName = '' then begin
    ScriptName := SysUtils.ExtractFileName(ScriptPath);
  end;

  result := not Self.fScripts.ItemExists(ScriptName) and Files.ReadFileContents(ScriptPath, ScriptContents);

  if result then begin
    PreprocessedScript := PreprocessErm(ScriptName, ScriptContents);
    fScripts.Add(TResource.Create(ScriptName, PreprocessedScript, Crypto.AnsiCrc32(ScriptContents)));
    LoadErtFile(ScriptName);
  end;
end;

function CompareGlobalEventsByDayAndPtr (a, b: integer): integer;
begin
  result := Heroes.PGlobalEvent(a).FirstDay - Heroes.PGlobalEvent(b).FirstDay;

  if result = 0 then begin
    result := integer(a) - integer(b);
  end;
end;

procedure TScriptMan.LoadMapInternalScripts;
const
  SCRIPT_START_SIGNATURE = integer($4553565A);

var
{O} EventList:          {U} TList {of Heroes.PGlobalEvent};
{n} GlobalEvent:        Heroes.PGlobalEvent;
    MapDirName:         string;
    ScriptNamePrefix:   string;
    ScriptName:         string;
    PreprocessedScript: string;
    PrevDay:            integer;
    i, j:               integer;


begin
  EventList   := DataLib.NewList(not Utils.OWNS_ITEMS);
  GlobalEvent := GameManagerPtr^.GlobalEvents.First;
  // * * * * * //
  MapDirName       := GameExt.GetMapDirName;
  ScriptNamePrefix := MapDirName +'\_inmap_\';

  while cardinal(GlobalEvent) + cardinal(sizeof(Heroes.TGlobalEvent)) < cardinal(GameManagerPtr^.GlobalEvents.Last) do begin
    if (GlobalEvent.Message.Len > 4) and (pinteger(GlobalEvent.Message.Value)^ = SCRIPT_START_SIGNATURE) then begin
      EventList.Add(GlobalEvent);
    end;

    Inc(GlobalEvent);
  end;

  EventList.CustomSort(CompareGlobalEventsByDayAndPtr);
  PrevDay := -1;
  j       := 0;

  for i := 0 to EventList.Count - 1 do begin
    GlobalEvent := EventList[i];

    if GlobalEvent.FirstDay <> PrevDay then begin
      PrevDay    := GlobalEvent.FirstDay;
      j          := 0;
      ScriptName := ScriptNamePrefix + 'day - ' + IntToStr(GlobalEvent.FirstDay) + '.erm';
    end else begin
      Inc(j);
      ScriptName := ScriptNamePrefix + 'day - ' + IntToStr(GlobalEvent.FirstDay) + ' - ' + IntToStr(j) + '.erm';
    end;

    PreprocessedScript := PreprocessErm(ScriptName, GlobalEvent.Message.ToString);
    fScripts.Add(TResource.Create(ScriptName, PreprocessedScript, Crypto.Crc32(GlobalEvent.Message.Value, GlobalEvent.Message.Len)));
  end; // .for
  // * * * * * //
  SysUtils.FreeAndNil(EventList);
end; // .procedure TScriptMan.LoadMapInternalScripts

procedure TScriptMan.LoadScriptsFromSavedGame;
var
{O} LoadedScripts: RscLists.TResourceList;

begin
  LoadedScripts := RscLists.TResourceList.Create;
  // * * * * * //
  LoadedScripts.LoadFromSavedGame(ERM_SCRIPTS_SECTION);

  if not LoadedScripts.FastCompare(Self.fScripts) then begin
    Utils.Exchange(int(LoadedScripts), int(Self.fScripts));
    ZvsFindErm;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(LoadedScripts);
end;

procedure TScriptMan.LoadScriptsFromDisk (IsFirstLoading: boolean);
const
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';

var
{O} ScriptList:          TStrList;
    ScriptsDir:          string;
    MapDirName:          string;
    ForcedScripts:       Utils.TArrayOfStr;
    LoadFixedScriptsSet: boolean;
    FileContents:        string;
    i:                   integer;

begin
  ForcedScripts := nil;
  ScriptList    := nil;
  // * * * * * //
  Self.ClearScripts;
  ZvsClearErtStrings;
  GlobalConsts.Clear;

  Self.LoadMapInternalScripts;

  ScriptsDir := GameExt.GetMapResourcePath(ERM_SCRIPTS_PATH);
  ScriptList := GetOrderedPrioritizedFileList([ScriptsDir + '\*.erm']);
  MapDirName := GameExt.GetMapDirName;

  for i := 0 to ScriptList.Count - 1 do begin
    Self.LoadScript(ScriptsDir + '\' + ScriptList[i], MapDirName + '\' + ScriptList[i]);
  end;

  SysUtils.FreeAndNil(ScriptList);

  LoadFixedScriptsSet := Files.ReadFileContents(GameExt.GetMapResourcePath(SCRIPTS_LIST_FILEPATH), FileContents);

  // Map maker forces fixed set of scripts
  if LoadFixedScriptsSet then begin
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_WOGIFY] := WOGIFY_ALL;
  end;

  LoadFixedScriptsSet := LoadFixedScriptsSet or Files.ReadFileContents(GameExt.GameDir + '\' + SCRIPTS_LIST_FILEPATH, FileContents);

  if LoadFixedScriptsSet then begin
    ScriptsDir    := GameDir + '\' + ERM_SCRIPTS_PATH;
    ForcedScripts := StrLib.Explode(SysUtils.Trim(FileContents), #13#10);

    for i := 0 to High(ForcedScripts) do begin
      Self.LoadScript(ScriptsDir + '\' + ForcedScripts[i]);
    end;
  end else begin
    ScriptsDir := GameDir + '\' + ERM_SCRIPTS_PATH;
    ScriptList := GetOrderedPrioritizedFileList([ScriptsDir + '\*.erm']);

    for i := 0 to ScriptList.Count - 1 do begin
      Self.LoadScript(ScriptsDir + '\' + ScriptList[i]);
    end;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(ScriptList);
end; // .procedure TScriptMan.LoadScriptsFromDisk

procedure TScriptMan.ReloadScriptsFromDisk;
begin
  if ErmTriggerDepth = 0 then begin
    EventMan.GetInstance.Fire('OnBeforeScriptsReload');
    ErmEnabled^       := false;
    Self.LoadScriptsFromDisk(TScriptMan.IS_RELOADING);
    ErmEnabled^       := true;
    ZvsIsGameLoading^ := true;
    ZvsFindErm;
    EventMan.GetInstance.Fire('OnAfterScriptsReload');
    Heroes.PrintChatMsg('{~white}ERM and language data were reloaded{~}');
  end;
end;

procedure TScriptMan.ExtractScripts;
var
  Error: string;

begin
  Files.DeleteDir(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH);
  Error := '';

  if not Files.ForcePath(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH) then begin
    Error := 'Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"';
  end;

  if Error = '' then begin
    Error := Self.fScripts.Export(GameExt.GameDir + '\' + EXTRACTED_SCRIPTS_PATH);
  end;

  if Error <> '' then begin
    Heroes.PrintChatMsg(Error);
  end;
end; // .procedure TScriptMan.ExtractScripts

function TScriptMan.AddrToScriptNameAndLine ({n} Addr: pchar; var {out} ScriptName: string; out LineN: integer; out LinePos: integer): boolean;
var
{Un} Script: TResource;
     i:      integer;


begin
  Script := nil;
  // * * * * * //
  result := (Addr <> nil) and (fScripts.Count > 0);

  if result then begin
    result := false;

    for i := 0 to Self.fScripts.Count - 1 do begin
      Script := TResource(Self.fScripts[i]);

      if Script.OwnsAddr(Addr) then begin
        ScriptName := Script.Name;
        result     := AddrToLineAndPos(Script.GetPtr, Length(Script.Contents), Addr, LineN, LinePos);
        exit;
      end;
    end;
  end; // .if
end; // .function TScriptMan.AddrToScriptNameAndLine

function TScriptMan.IsMapScript (ScriptInd: integer): boolean;
begin
  result := (ScriptInd >= 0) and (ScriptInd < Self.fScripts.Count) and (System.Pos('\', RscLists.TResource(Self.fScripts[ScriptInd]).Name) > 0);
end;

procedure ReloadErm;
begin
  ScriptMan.ReloadScriptsFromDisk;
end;

procedure ExtractErm;
begin
  ScriptMan.ExtractScripts;
end;

function AddrToScriptNameAndLine (CharPos: pchar; var ScriptName: string; var LineN: integer; var LinePos: integer): boolean;
begin
  result := ScriptMan.AddrToScriptNameAndLine(CharPos, ScriptName, LineN, LinePos);
end;

function FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;
begin
  result := CmdPtr;

  if (result <> nil) and (result^ <> '!') then begin
    while result^ <> '!' do begin
      Dec(result);
    end;

    if result[1] <> '!' then begin
      // ![!]X
      Dec(result);
    end;
  end; // .if
end; // .function FindErmCmdBeginning

function GrabErmCmd ({n} CmdPtr: pchar): string;
var
  StartPos: pchar;
  EndPos:   pchar;

begin
  if CmdPtr <> nil then begin
    StartPos := FindErmCmdBeginning(CmdPtr);
    EndPos   := CmdPtr;

    repeat
      Inc(EndPos);
    until (EndPos^ = ';') or (EndPos^ = #0);

    if EndPos^ = ';' then begin
      Inc(EndPos);
    end;

    result := StrLib.ExtractFromPchar(StartPos, EndPos - StartPos);
  end; // .if
end; // .function GrabErmCmd

function GrabErmCmdContext ({n} CmdPtr: pchar): string;
const
  NEW_LINE_COST        = 40;
  MIN_CHARS_TO_ACCOUNT = 50;
  MAX_CONTEXT_COST     = NEW_LINE_COST * 5;

var
  StartPos: pchar;
  EndPos:   pchar;
  Cost:     integer;
  CurrCost: integer;


begin
  result := '';

  if CmdPtr <> nil then begin
    Cost     := 0;
    CurrCost := 0;
    StartPos := FindErmCmdBeginning(CmdPtr);
    EndPos   := CmdPtr;

    repeat
      Inc(EndPos);

      if EndPos^ = #10 then begin
        Inc(Cost, NEW_LINE_COST);
        CurrCost := 0;
      end else begin
        Inc(CurrCost);

        if CurrCost >= MIN_CHARS_TO_ACCOUNT then begin
          Inc(Cost, CurrCost);
          CurrCost := 0;
        end;
      end;
    until (EndPos^ = #0) or (Cost >= MAX_CONTEXT_COST);

    result := SysUtils.WrapText(StrLib.ExtractFromPchar(StartPos, EndPos - StartPos), #10, [#0..#255], 100);
  end; // .if
end; // .function GrabErmCmdContext

procedure ReportErmError (Error: string; {n} ErrCmd: pchar);
const
  CONTEXT_LEN = 00;

var
  PositionLocated: boolean;
  ScriptName:      string;
  Line:            integer;
  LinePos:         integer;
  Question:        string;

begin
  ErmErrReported  := true;
  PositionLocated := AddrToScriptNameAndLine(ErrCmd, ScriptName, Line, LinePos);

  if Error = '' then begin
    Error := 'Unknown error';
  end;

  Question := '{~FF3333}' + Error + '{~}';

  if PositionLocated then begin
    Question := Format('%s'#10'Location: %s:%d:%d', [Question, ScriptName, Line, LinePos]);
  end;

  Question := Question + #10#10'{~g}' + GrabErmCmdContext(ErrCmd) + '{~}' + #10#10'Save debug information?';

  if Ask(Question) then begin
    ZvsDumpErmVars(pchar(Error), ErrCmd);
  end;

  ErmErrReported := true;
end; // .procedure ReportErmError

function Hook_MError (Context: Core.PHookContext): longbool; stdcall;
begin
  ReportErmError(ppchar(Context.EBP + 16)^, ErmErrCmdPtr^);
  Context.RetAddr := Ptr($712483);
  result          := not Core.EXEC_DEF_CODE;
end;

procedure Hook_ErmMess (OrigFunc: pointer; SubCmd: PErmSubCmd); stdcall;
var
  Code: pchar;
  i:    integer;

begin
  Code := SubCmd.Code.Value;
  // * * * * * //
  if not ErmErrReported then begin
    ReportErmError('', Code);
  end; // .if

  i := SubCmd.Pos;

  while not (Code[i] in [#0, ';']) do begin
    Inc(i);
  end;

  SubCmd.Pos     := i;
  ErmErrReported := false;
end; // .function Hook_ErmMess

function Hook_FindErm_SkipUntil2 (SubCmd: PErmSubCmd): integer; cdecl;
var
  CurrChar: pchar;

begin
  CurrChar := @SubCmd.Code.Value[SubCmd.Pos];

  while (CurrChar^ <> #0) and not ((CurrChar^ = '!') and (CurrChar[1] in ['!', '#', '?', '$', '@'])) do begin
    Inc(CurrChar);
  end;

  if CurrChar^ <> #0 then begin
    ErmErrCmdPtr^ := CurrChar;
    SubCmd.Pos    := integer(CurrChar) - integer(SubCmd.Code.Value) + 1;
    result        := 0;
  end else begin
    result := -1;
  end;
end; // .function Hook_FindErm_SkipUntil2

procedure Hook_RunTimer (OrigFunc: TZvsRunTimer; Owner: integer); stdcall;
begin
  ZvsGmAiFlags^ := ord(not ZvsIsAi(Owner));
  FireErmEvent(TRIGGER_DAILY_TIMER);
  OrigFunc(Owner);
end;

procedure Hook_ZvsStringSet_Clear (); cdecl;
begin
  with DataLib.IterateObjDict(ErtStrings) do begin
    while IterNext do begin
      Heroes.MemFree(pointer(IterValue));
    end;
  end;

  ErtStrings.Clear();
end;

function Hook_ZvsStringSet_Add (Index: integer; {OU} Str: pchar): longbool; cdecl;
begin
  if ErtStrings[Ptr(Index)] <> nil then begin
    ShowMessage('Duplicate ERM string index ' + SysUtils.IntToStr(Index));
    result := true;
  end else begin
    ErtStrings[Ptr(Index)] := Str;
    result                 := false;
  end;
end;

function Hook_ZvsStringSet_GetText (Index: integer): pchar; cdecl;
begin
  result := ErtStrings[Ptr(Index)];

  if result = nil then begin
    result := 'STRING NOT FOUND';
  end;
end;

function Hook_ZvsStringSet_Load (): longbool; cdecl;
begin
  // Strings saving moved to OnSavegameRead event
  result := false;
end;

function Hook_ZvsStringSet_Save (): longbool; cdecl;
begin
  // Strings saving moved to OnSavegameWrite event
  result := false;
end;

procedure ResetErmSubCmdCache;
begin
  System.FillChar(SubCmdCache, sizeof(SubCmdCache), #0);
end;

(* === START: Erm optimization section === *)
type
  TTriggerFastAccessListSorter = class (Alg.TQuickSortAdapter)
   private
    fTriggerList: PTriggerFastAccessList;
    fNumTriggers: integer;
    fPivotItem:   TTriggerFastAccessListItem;

   public
    function  CompareItems (Ind1, Ind2: integer): integer; override;
    procedure SwapItems (Ind1, Ind2: integer); override;
    procedure SavePivotItem (PivotItemInd: integer); override;
    function  CompareToPivot (Ind: integer): integer; override;

    constructor Create (TriggerList: PTriggerFastAccessList; NumTriggers: integer);
  end;

function CompareTriggerFastAccessListItems (var Item1, Item2: TTriggerFastAccessListItem): integer; inline;
begin
  if Item1.Id > Item2.Id then begin
    result := +1;
  end else if Item1.Id < Item2.Id then begin
    result := -1;
  end else begin
    if cardinal(Item1.Trigger) > cardinal(Item2.Trigger) then begin
      result := +1;
    end else if cardinal(Item1.Trigger) < cardinal(Item2.Trigger) then begin
      result := -1;
    end else begin
      result := 0;
    end;
  end; // .else
end; // .function CompareTriggerFastAccessListItems

constructor TTriggerFastAccessListSorter.Create (TriggerList: PTriggerFastAccessList; NumTriggers: integer);
begin
  {!} Assert(TriggerList <> nil);
  {!} Assert(NumTriggers >= 0);
  inherited Create;
  Self.fTriggerList := TriggerList;
  Self.fNumTriggers := NumTriggers;
end;

function TTriggerFastAccessListSorter.CompareItems (Ind1, Ind2: integer): integer;
begin
  result := CompareTriggerFastAccessListItems(Self.fTriggerList[Ind1], Self.fTriggerList[Ind2]);
end;

procedure TTriggerFastAccessListSorter.SwapItems (Ind1, Ind2: integer);
var
  TmpItem: TTriggerFastAccessListItem;

begin
  TmpItem                 := Self.fTriggerList[Ind1];
  Self.fTriggerList[Ind1] := Self.fTriggerList[Ind2];
  Self.fTriggerList[Ind2] := TmpItem;
end;

procedure TTriggerFastAccessListSorter.SavePivotItem (PivotItemInd: integer);
begin
  Self.fPivotItem := Self.fTriggerList[PivotItemInd];
end;

function TTriggerFastAccessListSorter.CompareToPivot (Ind: integer): integer;
begin
  result := CompareTriggerFastAccessListItems(Self.fTriggerList[Ind], Self.fPivotItem);
end;

(* Returns NullTrigger address on failure *)
function FindFirstTrigger (Id: integer): PErmTrigger;
var
  Ind:        integer;
  ListEndInd: integer;

begin
  if not CompiledErmOptimized then begin
    result := ZvsErmHeapPtr^;
    exit;
  end;

  ListEndInd := NumUniqueTriggers;
  result     := NullTrigger;

  if ListEndInd = 0 then begin
    exit;
  end;

  Ind := 0;

  while (Ind < ListEndInd) and (TriggerFastAccessList[Ind].Id <> Id) do begin
    if Id < TriggerFastAccessList[Ind].Id then begin
      Ind := Ind shl 1 + 1;
    end else begin
      Ind := Ind shl 1 + 2;
    end;
  end;

  if Ind < ListEndInd then begin
    result := TriggerFastAccessList[Ind].Trigger;
  end;
end; // .function FindFirstTrigger

(*
  Main optimization is reducing CPU cache load by sorting triggers by (Id, Addr) and providing
  fast search reordered list of triggers, used with cache-friendly binary search algorithm.
  Summary:
  -) Generating ERM event does not loop trough all triggers. Fast binary search + linear pass through same ID triggers instead.
  -) Triggers are located in adjucent memory locations, which is cache friendly.
  -) Additional memory is required O(N) for triggers reodrdering process (once) and for fast access table (constant).
*)
function OptimizeCompiledErm (TriggersStart: PErmTrigger; TriggersSize: integer; FreeBuf: pbyte; FreeBufSize: integer): boolean;
var
  NumTriggers: integer;

  (* Counts ERM triggers and makes unsorted list of (Id, Addr) pairs to enable same ID triggers grouping and triggers fast search *)
  function MakeTriggerFastAccessList: boolean;
  var
  {n} Trigger:            PErmTrigger;
      FastAccessListSize: integer;
      ListItem:           PTriggerFastAccessListItem;

  begin
    Trigger  := TriggersStart;
    ListItem := @TriggerFastAccessList[0];
    // * * * * * //
    result             := true;
    NumTriggers        := 0;
    FastAccessListSize := 0;

    while (Trigger <> nil) and (Trigger.Id <> 0) do begin
      Inc(FastAccessListSize, sizeof(TTriggerFastAccessListItem));
      Inc(NumTriggers);

      if FastAccessListSize > FreeBufSize then begin
        result := false;
        exit;
      end;

      ListItem.Trigger := Trigger;
      ListItem.Id      := Trigger.Id;
      Trigger          := Utils.PtrOfs(Trigger, Trigger.GetSize());
      Inc(ListItem);
    end; // .while
  end; // .function MakeTriggerFastAccessList

  procedure SortTriggerFastAccessList;
  var
  {O} Sorter: TTriggerFastAccessListSorter;

  begin
    Sorter := TTriggerFastAccessListSorter.Create(TriggerFastAccessList, NumTriggers);
    // * * * * * //
    Alg.QuickSortEx(Sorter, 0, NumTriggers - 1);
    // * * * * * //
    SysUtils.FreeAndNil(Sorter);
  end;

  procedure OptimizeFastAccessListAndRelinkTriggers;
  var
    PrevId: integer;
    i, j:   integer;

  begin
    PrevId := 0;
    j      := 0;

    for i := 0 to NumTriggers - 1 do begin
      if TriggerFastAccessList[i].Id <> PrevId then begin
        if PrevId <> 0 then begin
          TriggerFastAccessList[i - 1].Trigger.Next := nil;
        end;

        TriggerFastAccessList[i].Trigger.Next := nil;

        PrevId                   := TriggerFastAccessList[i].Id;
        TriggerFastAccessList[j] := TriggerFastAccessList[i];
        Inc(j);
      end else begin
        TriggerFastAccessList[i - 1].Trigger.Next := TriggerFastAccessList[i].Trigger;
      end; // .else
    end; // .for

    NumUniqueTriggers := j;
  end; // .procedure OptimizeFastAccessListAndRelinkTriggers

  procedure TurnFastAccessListIntoBinaryTree;
  type
    TQueueItem = record
      LeftInd:   integer;
      RightInd:  integer;
      CurrLevel: integer;
    end;

  var
    ListCopy:             array of TTriggerFastAccessListItem;
    TargetItem:           PTriggerFastAccessListItem;
    BinTreeLevel:         integer;
    QueueItem:            TQueueItem;
    NewQueueItem:         TQueueItem;
    MinChildrenForBranch: integer;
    MiddleInd:            integer;
    Queue:                array of TQueueItem;
    QueueReadPos:         integer;
    QueueWritePos:        integer;
    QueueSize:            integer;

    procedure AddToQueue (var QueueItem: TQueueItem);
    begin
      Queue[QueueWritePos] := QueueItem;
      QueueWritePos        := (QueueWritePos + 1) mod Length(Queue);
      Inc(QueueSize);
    end;

    procedure GetFromQueue (var QueueItem: TQueueItem);
    begin
      Dec(QueueSize);
      QueueItem := Queue[QueueReadPos];

      if QueueSize > 0 then begin
        QueueReadPos := (QueueReadPos + 1) mod Length(Queue);
      end else begin
        QueueReadPos  := 0;
        QueueWritePos := 0;
      end;
    end;

  begin
    TargetItem := @TriggerFastAccessList[0];
    // * * * * * //
    if NumUniqueTriggers <= 1 then begin
      exit;
    end;

    // Copy original fast access trigger list
    SetLength(ListCopy, NumUniqueTriggers);
    Utils.CopyMem(NumUniqueTriggers * sizeof(ListCopy[0]), TriggerFastAccessList, pointer(ListCopy));

    (* Initialize fixed size queue (based on circular buffer) *)
    // It can be proved, that queue will be filled with at most N items, where N is number of items at last level of binary tree
    BinTreeLevel := Alg.IntLog2(NumUniqueTriggers + 1);
    SetLength(Queue, 1 shl (BinTreeLevel - 1));

    QueueReadPos  := 0;
    QueueWritePos := 0;
    QueueSize     := 0;

    with QueueItem do begin
      LeftInd   := 0;
      RightInd  := NumUniqueTriggers - 1;
      CurrLevel := BinTreeLevel;
    end;

    AddToQueue(QueueItem);

    // Perform graph breadth-first traversal, building binary tree in list. {See binary heap}
    // Ex. 1 2 3 4 5 6 7 => 4 2 6 1 3 5 7
    // This is structure is more cache friendly and has at least same speed as binary search
    while QueueSize > 0 do begin
      GetFromQueue(QueueItem);

      // Last level - single item without children
      if QueueItem.LeftInd = QueueItem.RightInd then begin
        TargetItem^ := ListCopy[QueueItem.LeftInd];
        Inc(TargetItem);
      end
      // [2, ...] items range
      else begin
        MinChildrenForBranch := 1 shl (QueueItem.CurrLevel - 2) - 1;
        MiddleInd            := QueueItem.LeftInd + Math.Min(QueueItem.RightInd - QueueItem.LeftInd - MinChildrenForBranch, MinChildrenForBranch * 2 + 1);

        TargetItem^ := ListCopy[MiddleInd];
        Inc(TargetItem);

        with NewQueueItem do begin
          LeftInd   := QueueItem.LeftInd;
          RightInd  := MiddleInd - 1;
          CurrLevel := QueueItem.CurrLevel - 1;
        end;

        AddToQueue(NewQueueItem);

        if QueueItem.RightInd > MiddleInd then begin
          with NewQueueItem do begin
            LeftInd   := MiddleInd + 1;
            RightInd  := QueueItem.RightInd;
            CurrLevel := QueueItem.CurrLevel - 1;
          end;

          AddToQueue(NewQueueItem);
        end;
      end; // .else
    end; // .while
  end; // .procedure TurnFastAccessListIntoBinaryTree

begin
   TriggerFastAccessList := pointer(FreeBuf);
   NumTriggers           := 0;
   result                := MakeTriggerFastAccessList;

  if result then begin
    SortTriggerFastAccessList;
    OptimizeFastAccessListAndRelinkTriggers;
    TurnFastAccessListIntoBinaryTree;
    CompiledErmOptimized := true;
  end;
end; // .function OptimizeCompiledErm

function Hook_FindErm_Start (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  ResetErmSubCmdCache;
  CompiledErmOptimized := false;
  result               := true;
end;

function Hook_FindErm_SuccessEnd (Context: ApiJack.PHookContext): longbool; stdcall;
const
  NULL_TRIGGER_SIZE = sizeof(TErmTrigger);

var
{n} LastTrigger:   PErmTrigger;
{n} FreeBuf:       pbyte;
    TriggersStart: PErmTrigger;
    TriggersSize:  integer;
    FreeBufSize:   integer;

begin
  LastTrigger   := ppointer(Context.EBP - $1C)^;
  TriggersStart := ZvsErmHeapPtr^;
  TriggersSize  := 0;

  if LastTrigger <> nil then begin
    TriggersSize := integer(LastTrigger) - integer(TriggersStart) + LastTrigger.GetSize();
  end;

  NullTrigger    := Utils.PtrOfs(TriggersStart, TriggersSize);
  NullTrigger.Id := 0;
  FreeBuf        := Utils.PtrOfs(TriggersStart, Utils.IfThen(LastTrigger = nil, NULL_TRIGGER_SIZE, TriggersSize + NULL_TRIGGER_SIZE));
  FreeBufSize    := ZvsErmHeapSize^ - (integer(FreeBuf) - integer(ZvsErmHeapPtr^));

  if (FreeBufSize <= 0) or not OptimizeCompiledErm(TriggersStart, TriggersSize, FreeBuf, FreeBufSize) then begin
    ErmEnabled^ := false;
    Heroes.ShowMessage(Trans.tr('no_memory_for_erm_optimization', ['limit', IntToStr(ZvsErmHeapSize^ div (1024 * 1024))]));
  end;

  result := true;
end; // .function Hook_FindErm_SuccessEnd
(* === END: Erm optimization section === *)

procedure RegisterErmEventNames;
begin
  NameTrigger(TRIGGER_BA0,  'OnBeforeBattle');
  NameTrigger(TRIGGER_BA1,  'OnAfterBattle');
  NameTrigger(TRIGGER_BR,   'OnBattleRound');
  NameTrigger(TRIGGER_BG0,  'OnBeforeBattleAction');
  NameTrigger(TRIGGER_BG1,  'OnAfterBattleAction');
  NameTrigger(TRIGGER_MW0,  'OnWanderingMonsterReach');
  NameTrigger(TRIGGER_MW1,  'OnWanderingMonsterDeath');
  NameTrigger(TRIGGER_MR0,  'OnMagicBasicResistance');
  NameTrigger(TRIGGER_MR1,  'OnMagicCorrectedResistance');
  NameTrigger(TRIGGER_MR2,  'OnDwarfMagicResistance');
  NameTrigger(TRIGGER_CM0,  'OnAdventureMapRightMouseClick');
  NameTrigger(TRIGGER_CM1,  'OnTownMouseClick');
  NameTrigger(TRIGGER_CM2,  'OnHeroScreenMouseClick');
  NameTrigger(TRIGGER_CM3,  'OnHeroesMeetScreenMouseClick');
  NameTrigger(TRIGGER_CM4,  'OnBattleScreenMouseClick');
  NameTrigger(TRIGGER_CM5,  'OnAdventureMapLeftMouseClick');
  NameTrigger(TRIGGER_AE0,  'OnUnequipArt');
  NameTrigger(TRIGGER_AE1,  'OnEquipArt');
  NameTrigger(TRIGGER_MM0,  'OnBattleMouseHint');
  NameTrigger(TRIGGER_MM1,  'OnTownMouseHint');
  NameTrigger(TRIGGER_MP,   'OnMp3MusicChange');
  NameTrigger(TRIGGER_SN,   'OnSoundPlay');
  NameTrigger(TRIGGER_MG0,  'OnBeforeAdventureMagic');
  NameTrigger(TRIGGER_MG1,  'OnAfterAdventureMagic');
  NameTrigger(TRIGGER_TH0,  'OnEnterTownHall');
  NameTrigger(TRIGGER_TH1,  'OnLeaveTownHall');
  NameTrigger(TRIGGER_IP0,  'OnBeforeBattleBeforeDataSend');
  NameTrigger(TRIGGER_IP1,  'OnBeforeBattleAfterDataReceived');
  NameTrigger(TRIGGER_IP2,  'OnAfterBattleBeforeDataSend');
  NameTrigger(TRIGGER_IP3,  'OnAfterBattleAfterDataReceived');
  NameTrigger(TRIGGER_CO0,  'OnOpenCommanderWindow');
  NameTrigger(TRIGGER_CO1,  'OnCloseCommanderWindow');
  NameTrigger(TRIGGER_CO2,  'OnAfterCommanderBuy');
  NameTrigger(TRIGGER_CO3,  'OnAfterCommanderResurrect');
  NameTrigger(TRIGGER_BA50, 'OnBeforeBattleForThisPcDefender');
  NameTrigger(TRIGGER_BA51, 'OnAfterBattleForThisPcDefender');
  NameTrigger(TRIGGER_BA52, 'OnBeforeBattleUniversal');
  NameTrigger(TRIGGER_BA53, 'OnAfterBattleUniversal');
  NameTrigger(TRIGGER_GM0,  'OnAfterLoadGame');
  NameTrigger(TRIGGER_GM1,  'OnBeforeSaveGame');
  NameTrigger(TRIGGER_PI,   'OnAfterErmInstructions');
  NameTrigger(TRIGGER_DL,   'OnCustomDialogEvent');
  NameTrigger(TRIGGER_HM,   'OnHeroMove');
  NameTrigger(TRIGGER_HL,   'OnHeroGainLevel');
  NameTrigger(TRIGGER_BF,   'OnSetupBattlefield');
  NameTrigger(TRIGGER_MF1,  'OnMonsterPhysicalDamage');
  NameTrigger(TRIGGER_TL0,  'OnEverySecond');
  NameTrigger(TRIGGER_TL1,  'OnEvery2Seconds');
  NameTrigger(TRIGGER_TL2,  'OnEvery5Seconds');
  NameTrigger(TRIGGER_TL3,  'OnEvery10Seconds');
  NameTrigger(TRIGGER_TL4,  'OnEveryMinute');
  NameTrigger(TRIGGER_SAVEGAME_WRITE,               'OnSavegameWrite');
  NameTrigger(TRIGGER_SAVEGAME_READ,                'OnSavegameRead');
  NameTrigger(TRIGGER_KEYPRESS,                     'OnKeyPressed');
  NameTrigger(TRIGGER_OPEN_HEROSCREEN,              'OnOpenHeroScreen');
  NameTrigger(TRIGGER_CLOSE_HEROSCREEN,             'OnCloseHeroScreen');
  NameTrigger(TRIGGER_STACK_OBTAINS_TURN,           'OnBattleStackObtainsTurn');
  NameTrigger(TRIGGER_REGENERATE_PHASE,             'OnBattleRegeneratePhase');
  NameTrigger(TRIGGER_AFTER_SAVE_GAME,              'OnAfterSaveGame');
  NameTrigger(TRIGGER_BEFOREHEROINTERACT,           'OnBeforeHeroInteraction');
  NameTrigger(TRIGGER_AFTERHEROINTERACT,            'OnAfterHeroInteraction');
  NameTrigger(TRIGGER_ONSTACKTOSTACKDAMAGE,         'OnStackToStackDamage');
  NameTrigger(TRIGGER_ONAICALCSTACKATTACKEFFECT,    'OnAICalcStackAttackEffect');
  NameTrigger(TRIGGER_ONCHAT,                       'OnChat');
  NameTrigger(TRIGGER_ONGAMEENTER,                  'OnGameEnter');
  NameTrigger(TRIGGER_ONGAMELEAVE,                  'OnGameLeave');
  NameTrigger(TRIGGER_ONREMOTEEVENT,                'OnRemoteEvent');
  NameTrigger(TRIGGER_DAILY_TIMER,                  'OnEveryDay');
  NameTrigger(TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE, 'OnBeforeBattlefieldVisible');
  NameTrigger(TRIGGER_BATTLEFIELD_VISIBLE,          'OnBattlefieldVisible');
  NameTrigger(TRIGGER_AFTER_TACTICS_PHASE,          'OnAfterTacticsPhase');
  NameTrigger(TRIGGER_COMBAT_ROUND,                 'OnCombatRound');
  NameTrigger(TRIGGER_OPEN_RECRUIT_DLG,             'OnOpenRecruitDlg');
  NameTrigger(TRIGGER_CLOSE_RECRUIT_DLG,            'OnCloseRecruitDlg');
  NameTrigger(TRIGGER_RECRUIT_DLG_MOUSE_CLICK,      'OnRecruitDlgMouseClick');
  NameTrigger(TRIGGER_TOWN_HALL_MOUSE_CLICK,        'OnTownHallMouseClick');
  NameTrigger(TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK, 'OnKingdomOverviewMouseClick');
  NameTrigger(TRIGGER_RECRUIT_DLG_RECALC,           'OnRecruitDlgRecalc');
  NameTrigger(TRIGGER_RECRUIT_DLG_ACTION,           'OnRecruitDlgAction');
  NameTrigger(TRIGGER_LOAD_HERO_SCREEN,             'OnLoadHeroScreen');
  NameTrigger(TRIGGER_BUILD_TOWN_BUILDING,          'OnBuildTownBuilding');
  NameTrigger(TRIGGER_OPEN_TOWN_SCREEN,             'OnOpenTownScreen');
  NameTrigger(TRIGGER_CLOSE_TOWN_SCREEN,            'OnCloseTownScreen');
  NameTrigger(TRIGGER_SWITCH_TOWN_SCREEN,           'OnSwitchTownScreen');
  NameTrigger(TRIGGER_PRE_TOWN_SCREEN,              'OnPreTownScreen');
  NameTrigger(TRIGGER_POST_TOWN_SCREEN,             'OnPostTownScreen');
  NameTrigger(TRIGGER_PRE_HEROSCREEN,               'OnPreHeroScreen');
  NameTrigger(TRIGGER_POST_HEROSCREEN,              'OnPostHeroScreen');
  NameTrigger(TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE, 'OnDetermineMonInfoDlgUpgrade');
  NameTrigger(TRIGGER_ADVMAP_TILE_HINT,             'OnAdvMapTileHint');
  NameTrigger(TRIGGER_BEFORE_STACK_TURN,            'OnBeforeBattleStackTurn');
  NameTrigger(TRIGGER_CALC_TOWN_INCOME,             'OnCalculateTownIncome');
end; // .procedure RegisterErmEventNames

procedure AssignEventParams (const Params: array of integer);
var
  i: integer;

begin
  {!} Assert(Length(Params) <= Length(ArgXVars), 'Cannot fire ERM event with so many arguments: ' + SysUtils.IntToStr(length(Params)));

  for i := 0 to High(Params) do begin
    ArgXVars[i + 1] := Params[i];
  end;
end;

procedure FireErmEventEx (EventId: integer; const Params: array of integer);
begin
  AssignEventParams(Params);
  FireErmEvent(EventId);
end;

function FireMouseEvent (TriggerId: integer; MouseEventInfo: Heroes.PMouseEventInfo): boolean;
var
  PrevMouseEventInfo:    Heroes.TMouseEventInfo;
  PrevEnableDefReaction: longbool;

begin
  {!} Assert(MouseEventInfo <> nil);
  PrevMouseEventInfo        := ZvsMouseEventInfo^;
  PrevEnableDefReaction     := ZvsAllowDefMouseReaction^;
  ZvsMouseEventInfo^        := MouseEventInfo^;
  ZvsAllowDefMouseReaction^ := true;

  FireErmEvent(TriggerId);

  result                    := ZvsAllowDefMouseReaction^;
  ZvsMouseEventInfo^        := PrevMouseEventInfo;
  ZvsAllowDefMouseReaction^ := PrevEnableDefReaction;
end; // .function FireMouseEvent

procedure FireRemoteErmEvent (EventId: integer; Args: array of integer);
begin
  {!} Assert(length(Args) <= 16, 'Cannot fire remote ERM event with more than 16 arguments');

  if length(Args) = 0 then begin
    FireRemoteEventProc(EventId, nil, 0);
  end else begin
    FireRemoteEventProc(EventId, @Args[0], length(Args));
  end;
end;

procedure SetErmCurrHero (NewInd: integer); overload;
begin
  ppointer($27F9970)^ := Heroes.ZvsGetHero(NewInd);
end;

procedure SetErmCurrHero ({n} NewHero: Heroes.PHero); overload;
begin
  ppointer($27F9970)^ := NewHero;
end;

function GetErmCurrHero: {n} Heroes.PHero;
begin
  result := ppointer($27F9970)^;
end;

function GetErmCurrHeroInd: integer; // or -1
var
{n} Hero: Heroes.PHero;

begin
  Hero := GetErmCurrHero;

  if Hero <> nil then begin
    result := Hero.Id;
  end else begin
    result := -1;
  end;
end;

procedure RegisterTriggerLocalObject ({O} Obj: TObject);
begin
  if TriggerLocalObjects = nil then begin
    TriggerLocalObjects := DataLib.NewList(Utils.OWNS_ITEMS);
  end;

  TriggerLocalObjects.Add(Obj);
end;

procedure RegisterCmdLocalObject (ErtIndex: integer);
var
  NewItem: PCmdLocalObject;

begin
  NewItem          := ServiceMemAllocator.Alloc(sizeof(TCmdLocalObject));
  NewItem.ErtIndex := ErtIndex;
  NewItem.Prev     := CmdLocalObjects;
  CmdLocalObjects  := NewItem;
end;

function AllocLocalErtIndex: integer;
begin
  result := LocalErtAutoIndex;
  Inc(LocalErtAutoIndex);

  if LocalErtAutoIndex >= LAST_LOCAL_ERT_INDEX then begin
    LocalErtAutoIndex := FIRST_LOCAL_ERT_INDEX;
  end;
end;

function CreateUnregisteredLocalErt (Str: pchar; StrLen: integer = -1): integer;
var
  Buf: pchar;

begin
  result := AllocLocalErtIndex;

  if StrLen = -1 then begin
    StrLen := SysUtils.StrLen(Str);
  end;

  Buf := ServiceMemAllocator.AllocStr(StrLen);
  Utils.CopyMem(StrLen, Str, Buf);
  ErtStrings[Ptr(result)] := Buf;
end; // .function CreateUnregisteredLocalErt

function CreateCmdLocalErt (Str: pchar; StrLen: integer = -1): integer;
begin
  result := CreateUnregisteredLocalErt(Str, StrLen);
  RegisterCmdLocalObject(result);
end;

function CreateTriggerLocalErt (Str: pchar; StrLen: integer = -1): integer;
var
{O} TriggerLocalStr: TTriggerLocalStr;

begin
  TriggerLocalStr := TTriggerLocalStr.Create(Str, StrLen);
  result          := TriggerLocalStr.zIndex;
  RegisterTriggerLocalObject(TriggerLocalStr);
end;

(* Extract i^...^ or s^...^ variable name. BufPos must point to first name character *)
function ExtractErmStrLiteral (BufPos: pchar): string;
var
  StartPos:  pchar;
  Delimiter: char;

begin
  {!} Assert(BufPos <> nil);
  StartPos := BufPos;

  // Determine delimiter to handle both ^....^ and %s(...)
  if pchar(integer(BufPos) - 1)^ = '^' then begin
    Delimiter := '^';
  end else begin
    Delimiter := ')';
  end;

  while not (BufPos^ in [#0, Delimiter]) do begin
    Inc(BufPos);
  end;

  result := StrLib.ExtractFromPchar(StartPos, integer(BufPos) - integer(StartPos));
end;

function GetInterpolatedErmStrLiteral (BufPos: pchar): pchar;
var
  Delimiter: char;

begin
  {!} Assert(BufPos <> nil);
  result := BufPos;
  
  // Determine delimiter to handle both ^....^ and %s(...)
  if pchar(integer(BufPos) - 1)^ = '^' then begin
    Delimiter := '^';
  end else begin
    Delimiter := ')';
  end;

  while not (BufPos^ in [#0, Delimiter]) do begin
    Inc(BufPos);
  end;

  BufPos^ := #0;
  result  := ZvsInterpolateStr(result);
  BufPos^ := Delimiter;
end;

function GetErmStrLiteralLen (BufPos: pchar): integer;
var
  StartPos: pchar;

begin
  {!} Assert(BufPos <> nil);
  StartPos := BufPos;

  while not (BufPos^ in ['^', #0]) do begin
    Inc(BufPos);
  end;

  result := integer(BufPos) - integer(StartPos);
end;

(* Converts ERM parameter to original string in code *)
function ErmParamToCode (Param: PErmCmdParam): string;
var
  Types: array [0..1] of integer;
  i:     integer;

begin
  result   := '';
  Types[0] := Param.GetType();
  Types[1] := Param.GetIndexedPartType();

  case Param.GetCheckType of
    PARAM_CHECK_GET:           result := result + '?';
    PARAM_CHECK_EQUAL:         result := result + '=';
    PARAM_CHECK_NOT_EQUAL:     result := result + '<>';
    PARAM_CHECK_GREATER:       result := result + '>';
    PARAM_CHECK_LOWER:         result := result + '<';
    PARAM_CHECK_GREATER_EQUAL: result := result + '>=';
    PARAM_CHECK_LOWER_EQUAL:   result := result + '<=';
  end;

  for i := Low(Types) to High(Types) do begin
    case Types[i] of
      PARAM_VARTYPE_QUICK: result := result + chr(ord('f') - Low(QuickVars^) + Param.Value);
      PARAM_VARTYPE_V:     result := result + 'v';
      PARAM_VARTYPE_W:     result := result + 'w';
      PARAM_VARTYPE_X:     result := result + 'x';
      PARAM_VARTYPE_Y:     result := result + 'y';
      PARAM_VARTYPE_Z:     result := result + 'z';
      PARAM_VARTYPE_E:     result := result + 'e';
      PARAM_VARTYPE_I:     result := result + 'i' + pchar(Param.Value - 1)^;
      PARAM_VARTYPE_S:     result := result + 's' + pchar(Param.Value - 1)^;
      PARAM_VARTYPE_STR:   result := result + '^';
    end;
  end;

  if (Types[0] = PARAM_VARTYPE_I) or (Types[1] = PARAM_VARTYPE_I) or (Types[0] = PARAM_VARTYPE_S) or (Types[1] = PARAM_VARTYPE_S) or (Types[0] = PARAM_VARTYPE_STR) or (Types[1] = PARAM_VARTYPE_STR) then begin
    if pchar(Param.Value - 1)^ = '^' then begin
      result := result + ExtractErmStrLiteral(pchar(Param.Value)) + '^';
    end else begin
      result := result + ExtractErmStrLiteral(pchar(Param.Value)) + ')';
    end;
  end else if (Types[0] <> PARAM_VARTYPE_QUICK) and (Types[1] <> PARAM_VARTYPE_QUICK) then begin
    result := result + IntToStr(Param.Value);
  end;
end; // .function ErmParamToCode

function GetErmParamValue (Param: PErmCmdParam; out ResValType: integer; Flags: integer = 0): integer;
const
  IND_INDEX = 0;
  IND_BASE  = 1;

var
{Un} AssocVarValue: AdvErm.TAssocVar;
     AssocVarName:  string;
     ValTypes:      array [0..1] of integer;
     ValType:       integer;
     StrLiteral:    pchar;
     StrLen:        integer;
     i:             integer;

begin
  if Param.CanBeFastIntEvaled() then begin
    result     := FastIntVarAddrs[Param.GetType()][Param.Value];
    ResValType := VALTYPE_INT;
    exit;
  end;

  ValTypes[0] := Param.GetIndexedPartType();
  ValTypes[1] := Param.GetType();
  result      := Param.Value;

  // Treat non-initialized parameters as 0 in X# syntax
  if ValTypes[1] = PARAM_VARTYPE_NONE then begin
    exit;
  end;

  for i := Low(ValTypes) to High(ValTypes) do begin
    ValType := ValTypes[i];

    // If ValType is raw number, it's already stored in result
    if ValType <> PARAM_VARTYPE_NUM then begin
      case ValType of
        PARAM_VARTYPE_Y: begin
          ValType := VALTYPE_INT;

          if result in [Low(y^)..High(y^)] then begin
            result := y[result];
          end else if -result in [Low(ny^)..High(ny^)] then begin
            result := ny[-result];
          end else begin
            ShowErmError(Format('Invalid y-var index: %d. Expected -100..-1, 1..100', [result]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;
        end;

        PARAM_VARTYPE_QUICK: begin
          ValType := VALTYPE_INT;

          if (result < Low(QuickVars^)) or (result > High(QuickVars^)) then begin
            ShowErmError(Format('Invalid quick var %d. Expected %d..%d', [result, Low(QuickVars^), High(QuickVars^)]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          result := QuickVars[result];
        end;

        PARAM_VARTYPE_X: begin
          ValType := VALTYPE_INT;

          if (result < Low(x^)) or (result > High(x^)) then begin
            ShowErmError(Format('Invalid x-var index %d. Expected %d..%d', [result, Low(x^), High(x^)]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          result := x[result];
        end;

        PARAM_VARTYPE_V: begin
          ValType := VALTYPE_INT;

          if (result < Low(v^)) or (result > High(v^)) then begin
            ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [result, Low(v^), High(v^)]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          result := v[result];
        end;

        PARAM_VARTYPE_I: begin
          ValType := VALTYPE_INT;

          if result = 0 then begin
            ShowErmError('Impossible case: named i-var has null address');
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          if Param.NeedsInterpolation() then begin
            AssocVarName := GetInterpolatedErmStrLiteral(pchar(result));
          end else begin
            AssocVarName := ExtractErmStrLiteral(pchar(result));
          end;

          AssocVarValue := AdvErm.AssocMem[AssocVarName];

          if AssocVarValue = nil then begin
            result := 0;
          end else begin
            result := AssocVarValue.IntValue;
          end;
        end;

        PARAM_VARTYPE_STR: begin
          ValType := VALTYPE_STR;

          if result = 0 then begin
            ShowErmError('Impossible case: string literal has null address');
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          if Param.NeedsInterpolation() then begin
            StrLiteral := GetInterpolatedErmStrLiteral(pchar(result));
            StrLen     := Windows.LStrLen(StrLiteral);
          end else begin
            StrLiteral := pchar(result);
            StrLen     := GetErmStrLiteralLen(StrLiteral);
          end;

          if (Flags and FLAG_STR_EVALS_TO_ADDR_NOT_INDEX) <> 0 then begin
            result := integer(ServiceMemAllocator.AllocStr(StrLen));
            Utils.CopyMem(StrLen, StrLiteral, pchar(result));
          end else begin
            result := CreateCmdLocalErt(StrLiteral, StrLen);
          end;
        end; // .case PARAM_VARTYPE_STR

        PARAM_VARTYPE_Z: begin
          ValType := VALTYPE_STR;

          if (Flags and FLAG_STR_EVALS_TO_ADDR_NOT_INDEX) <> 0 then begin
            if (result >= Low(z^)) and (result <= High(z^)) then begin
              result := integer(@z[result]);
            end else if -result in [Low(nz^)..High(nz^)] then begin
              result := integer(@nz[-result]);
            end else if result > High(z^) then begin
              result := integer(GetInterpolatedZVarAddr(result));
            end else begin
              ShowErmError(Format('Invalid z-var index: %d. Expected -10..-1, 1+', [result]));
              ResValType := VALTYPE_ERROR; result := 0; exit;
            end;
          end else begin
            if not ((result >= Low(z^)) or (-result in [Low(nz^)..High(nz^)])) then begin
              ShowErmError(Format('Invalid z-var index: %d. Expected -10..-1, 1+', [result]));
              ResValType := VALTYPE_ERROR; result := 0; exit;
            end;
          end; // .else
        end; // .case PARAM_VARTYPE_Z

        PARAM_VARTYPE_E: begin
          ValType := VALTYPE_FLOAT;

          if result in [Low(e^)..High(e^)] then begin
            result := pinteger(@e[result])^;
          end else if -result in [Low(ne^)..High(ne^)] then begin
            result := pinteger(@ne[-result])^;
          end else begin
            ShowErmError(Format('Invalid e-var index: %d. Expected -100..-1, 1..100', [result]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;
        end;

        PARAM_VARTYPE_FLAG: begin
          ValType := VALTYPE_BOOL;

          if (result < Low(f^)) or (result > High(f^)) then begin
            ShowErmError(Format('Invalid flag index %d. Expected %d..%d', [result, Low(f^), High(f^)]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          result := ord(f[result]);
        end;

        PARAM_VARTYPE_W: begin
          ValType := VALTYPE_INT;

          if (result < Low(w^[0])) or (result > High(w^[0])) then begin
            ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [result, Low(w^[0]), High(w^[0])]));
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          result  := w[ZvsWHero^][result];
        end;

        PARAM_VARTYPE_S: begin
          ValType := VALTYPE_STR;

          if result = 0 then begin
            ShowErmError('Impossible case: named s-var has null address');
            ResValType := VALTYPE_ERROR; result := 0; exit;
          end;

          if Param.NeedsInterpolation() then begin
            AssocVarName := GetInterpolatedErmStrLiteral(pchar(result));
          end else begin
            AssocVarName := ExtractErmStrLiteral(pchar(result));
          end;

          AssocVarValue := AdvErm.AssocMem[AssocVarName];

          if (Flags and FLAG_STR_EVALS_TO_ADDR_NOT_INDEX) <> 0 then begin
            if AssocVarValue = nil then begin
              result := integer(pchar(''));
            end else begin
              result := integer(ServiceMemAllocator.AllocStr(Length(AssocVarValue.StrValue)));
              Utils.CopyMem(Length(AssocVarValue.StrValue), pchar(AssocVarValue.StrValue), pchar(result));
            end;
          end else begin
            if AssocVarValue = nil then begin
              result := CreateCmdLocalErt('', 0);
            end else begin
              result := CreateCmdLocalErt(pchar(AssocVarValue.StrValue), Length(AssocVarValue.StrValue));
            end;
          end; // .else
        end; // .case PARAM_VARTYPE_S
      else
        ShowErmError(Format('Unknown variable type: %d', [ValType]));
        ResValType := VALTYPE_ERROR; result := 0; exit;
      end; // .switch

      if (ValType <> VALTYPE_INT) and (i = IND_INDEX) then begin
        ShowErmError('Cannot use non-integer variables as indexes for other variables');
        ResValType := VALTYPE_ERROR; result := 0; exit;
      end;
    end; // .if
  end; // .for

  if Param.HasCurrDayModifier() then begin
    if ValType = VALTYPE_INT then begin
      Inc(result, ZvsGetCurrDay());
    end else begin
      ShowErmError('"c" modifier can be applied to integers only');
    end;
  end;

  ResValType := ValType;
end; // .function GetErmParamValue

function SetErmParamValue (Param: PErmCmdParam; NewValue: integer; Flags: integer = 0): boolean;
const
  IND_INDEX = 0;
  IND_BASE  = 1;

var
{Un} AssocVarValue: AdvErm.TAssocVar;
     AssocVarName:  string;
     ValTypes:      array [0..1] of integer;
     ValType:       integer;
     Value:         integer;
     i:             integer;

begin
  if Param.CanBeFastIntEvaled() then begin
    FastIntVarAddrs[Param.GetType()][Param.Value] := NewValue;
    result := true;
    exit;
  end;

  ValTypes[0] := Param.GetIndexedPartType();
  ValTypes[1] := Param.GetType();
  result      := true;
  Value       := Param.Value;

  // Ignore non-initialized ERM parameters
  if ValTypes[1] = PARAM_VARTYPE_NONE then begin
    exit;
  end;

  for i := Low(ValTypes) to High(ValTypes) do begin
    ValType := ValTypes[i];

    case ValType of
      PARAM_VARTYPE_NUM: begin
        if i = IND_INDEX then begin
          continue;
        end else begin
          ShowErmError(Format('Cannot use GET syntax with number: ?%d', [Value]));
          result := false; exit;
        end;
      end;

      PARAM_VARTYPE_Y: begin
        ValType := VALTYPE_INT;

        if Value in [Low(y^)..High(y^)] then begin
          Value := integer(@y[Value]);
        end else if -Value in [Low(ny^)..High(ny^)] then begin
          Value := integer(@ny[-Value]);
        end else begin
          ShowErmError(Format('Invalid y-var index: %d. Expected -100..-1, 1..100', [Value]));
          result := false; exit;
        end;
      end;

      PARAM_VARTYPE_QUICK: begin
        ValType := VALTYPE_INT;

        if (Value < Low(QuickVars^)) or (Value > High(QuickVars^)) then begin
          ShowErmError(Format('Invalid quick var %d. Expected %d..%d', [Value, Low(QuickVars^), High(QuickVars^)]));
          result := false; exit;
        end;
        
        Value := integer(@QuickVars[Value]);
      end;

      PARAM_VARTYPE_X: begin
        ValType := VALTYPE_INT;

        if (Value < Low(x^)) or (Value > High(x^)) then begin
          ShowErmError(Format('Invalid x-var index %d. Expected %d..%d', [Value, Low(x^), High(x^)]));
          result := false; exit;
        end;

        Value := integer(@x[Value]);
      end;

      PARAM_VARTYPE_V: begin
        ValType := VALTYPE_INT;

        if (Value < Low(v^)) or (Value > High(v^)) then begin
          ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [Value, Low(v^), High(v^)]));
          result := false; exit;
        end;

        Value := integer(@v[Value]);
      end;

      PARAM_VARTYPE_I: begin
        ValType := VALTYPE_INT;

        if Value = 0 then begin
          ShowErmError('Impossible case: i-var has null address');
          result := false; exit;
        end;

        if Param.NeedsInterpolation() then begin
          AssocVarName := GetInterpolatedErmStrLiteral(pchar(Value));
        end else begin
          AssocVarName := ExtractErmStrLiteral(pchar(Value));
        end;

        AssocVarValue := AdvErm.AssocMem[AssocVarName];

        if AssocVarValue = nil then begin
          AssocVarValue                 := AdvErm.TAssocVar.Create;
          AdvErm.AssocMem[AssocVarName] := AssocVarValue;
        end;

        Value := integer(@AssocVarValue.IntValue);
      end;

      PARAM_VARTYPE_Z: begin
        ValType := VALTYPE_STR;

        if (Flags and FLAG_ASSIGNABLE_STRINGS) <> 0 then begin
          if i = IND_BASE then begin
            if (Value >= Low(z^)) and (Value <= High(z^)) then begin
              SetZVar(@z[Value], pchar(NewValue));
            end else if -Value in [Low(nz^)..High(nz^)] then begin
              SetZVar(@nz[-Value], pchar(NewValue));
            end else begin
              ShowErmError(Format('Invalid z-var index: %d. Expected -10..-1, 1..1000', [Value]));
              result := false; exit;
            end;
          end;
        end else begin
          ShowErmError(Format('SetErmParamValue: Unsupported variable type: %d', [ValType]));
          result := false; exit;
        end; // .else
      end; // .case PARAM_VARTYPE_Z

      PARAM_VARTYPE_E: begin
        ValType := VALTYPE_FLOAT;

        if Value in [Low(e^)..High(e^)] then begin
          Value := integer(@e[Value]);
        end else if -Value in [Low(ne^)..High(ne^)] then begin
          Value := integer(@ne[-Value]);
        end else begin
          ShowErmError(Format('Invalid e-var index: %d. Expected -100..-1, 1..100', [Value]));
          result := false; exit;
        end;
      end;

      PARAM_VARTYPE_W: begin
        ValType := VALTYPE_INT;

        if (Value < Low(w^[0])) or (Value > High(w^[0])) then begin
          ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [Value, Low(w^[0]), High(w^[0])]));
          result := false; exit;
        end;

        Value := integer(@w[ZvsWHero^][Value]);
      end;

      PARAM_VARTYPE_S: begin
        ValType := VALTYPE_STR;

        if (Flags and FLAG_ASSIGNABLE_STRINGS) <> 0 then begin
          if i = IND_BASE then begin
            if Value = 0 then begin
              ShowErmError('Impossible case: named s-var has null address');
              result := false; exit;
            end;

            if Param.NeedsInterpolation() then begin
              AssocVarName := GetInterpolatedErmStrLiteral(pchar(Value));
            end else begin
              AssocVarName := ExtractErmStrLiteral(pchar(Value));
            end;

            AssocVarValue := AdvErm.AssocMem[AssocVarName];

            if AssocVarValue = nil then begin
              AssocVarValue                 := AdvErm.TAssocVar.Create;
              AdvErm.AssocMem[AssocVarName] := AssocVarValue;
            end;

            AssocVarValue.StrValue := pchar(NewValue);
          end; // .if
        end else begin
          ShowErmError(Format('SetErmParamValue: Unsupported variable type: %d', [ValType]));
          result := false; exit;
        end; // .else
      end; // .case PARAM_VARTYPE_S

      PARAM_VARTYPE_FLAG: begin
        ShowErmError(Format('Cannot use GET syntax with flags: ?%d', [Value]));
        result := false; exit;
      end;
    else
      ShowErmError(Format('SetErmParamValue: Unsupported variable type: %d', [ValType]));
      result := false; exit;
    end; // .switch

    if i = IND_INDEX then begin
      if ValType <> VALTYPE_INT then begin
        ShowErmError('Cannot use non-integer variables as indexes for other variables');
        result := false; exit;
      end;

      Value := pinteger(Value)^;
    end;
  end; // .for

  if ValType <> VALTYPE_STR then begin
    pinteger(Value)^ := NewValue;
  end;
end; // .function SetErmParamValue

function ConvertVarTypeCharToId (VarTypeChar: char; var Res: integer): boolean;
begin
  result := true;

  case VarTypeChar of
    'y': Res := PARAM_VARTYPE_Y;
    'x': Res := PARAM_VARTYPE_X;
    'f'..'t': Res := PARAM_VARTYPE_QUICK;
    'z': Res := PARAM_VARTYPE_Z;
    'v': Res := PARAM_VARTYPE_V;
    'e': Res := PARAM_VARTYPE_E;
    'w': Res := PARAM_VARTYPE_W;
    'F': Res := PARAM_VARTYPE_FLAG;
  else
    Res    := PARAM_VARTYPE_NUM;
    result := false;
    ShowErmError('ConvertVarTypeCharToId: invalid argument: ' + VarTypeChar);
  end;
end; // .function ConvertParamTypeCharToId

const
  MAX_INTERPOLATION_LEVEL = 5;

var
  InterpolationBuf:   array [0..999999] of char;
  InterpolationLevel: integer = 0;

(* Interpolates string with ERM placeholders like %VZ3 or %T(json_key). If code is executed in ERM trigger, the result
   will be current receiver or trigger local memory buffer. Otherwise the result is global interpolation buffer. *)
function InterpolateErmStr (Str: pchar): pchar; cdecl;
const
  OPTIONALLY_UPPERCASE_TYPES = ['V', 'Y', 'X', 'Z', 'E', 'W', 'S', 'I'];
  INDEXABLE_PAR_TYPES        = ['v', 'y', 'x', 'z', 'e', 'w', 'F'];
  INDEXING_PAR_TYPES         = ['v', 'y', 'x', 'w', 'f'..'t'];
  NATIVE_PAR_TYPES           = ['v', 'y', 'x', 'z', 'e', 'w', 'f'..'t', 'F'];
  SUPPORTED_PAR_TYPES        = ['v', 'y', 'x', 'z', 'e', 'w', 'f'..'t', 'F', 's', 'i', '$'];

label
  Error;

var
{O} Res:                StrLib.TStrBuilder;
    ResSize:            integer;
    Caret:              pchar;
    ChunkStart:         pchar;
    ChunkSize:          integer;
    c:                  char;
    TokenLen:           integer;
    TokenStart:         pchar;
    TempStr:            pchar;
    ParamValue:         Heroes.TValue;
    BaseTypeChar:       char;
    IndexTypeChar:      char;
    IsIndexed:          longbool;
    BaseVarType:        integer;
    IndexVarType:       integer;
    ValType:            integer;
    NeedsInterpolation: longbool;
    MacroParam:         PErmCmdParam;
    Param:              TErmCmdParam;

begin
  // Do not interpolate last level string, copy instead
  if InterpolationLevel >= MAX_INTERPOLATION_LEVEL then begin
    ResSize := Windows.LStrLen(Str);

    if ErmTriggerDepth > 0 then begin
      result := AdvErm.ServiceMemAllocator.AllocStr(ResSize);
      Utils.CopyMem(ResSize, Str, result);
    end else begin
      result := @InterpolationBuf;
      Utils.CopyMem(Math.Min(sizeof(InterpolationBuf) - 1, ResSize), Str, result);
      result[Math.Min(sizeof(InterpolationBuf) - 1, ResSize)] := #0;
    end;

    exit;
  end; // .if

  Res   := StrLib.TStrBuilder.Create;
  Caret := Str;
  // * * * * * //
  Inc(InterpolationLevel);

  while Caret^ <> #0 do begin
    // Find interpolation marker '%' or buffer end
    ChunkStart := Caret;

    while not (Caret^ in [#0, '%']) do begin
      Inc(Caret);
    end;

    ChunkSize := Caret - ChunkStart;

    // Copy leading regular characters to output buffer
    if ChunkSize > 0 then begin
      Res.AppendBuf(ChunkSize, ChunkStart);
    end;

    if Caret^ = #0 then begin
      break;
    end;

    // Handle value to interpolate
    ChunkStart := Caret;

    if Caret[1] = '%' then begin
      Res.WriteByte(ord('%'));
      Inc(Caret, 2);
    end else if Caret[1] = '\' then begin
      if Caret[2] = ':' then begin
        Res.Append(';');
        Inc(Caret, 3);
      end else if Caret[2] = '"' then begin
        Res.Append('^');
        Inc(Caret, 3);
      end else begin
        Res.Append('%\');
        Inc(Caret, 2);
      end;
    end else begin
      Inc(Caret);
      c := Caret^;

      // Support for old %Z3 syntax instead of %z3
      if c in OPTIONALLY_UPPERCASE_TYPES then begin
        c := chr(ord(c) + (ord('a') - ord('A')));
      end;

      if c = 'D' then begin
        case Caret[1] of
          'd': Res.Append(SysUtils.IntToStr(Heroes.GameDate^.Day));
          'w': Res.Append(SysUtils.IntToStr(Heroes.GameDate^.Week));
          'm': Res.Append(SysUtils.IntToStr(Heroes.GameDate^.Month));
          'a': Res.Append(SysUtils.IntToStr(ZvsGetCurrDay()));
        else
          ShowErmError('*InterpolateErmStr: invalid %Dx syntax');
          goto Error;
        end;

        Inc(Caret, 2);
      end else if (c = 'G') and (Caret[1] = 'c') then begin
        Inc(Caret, 2);
        TempStr := Heroes.ZvsGetTxtValue(62 + Heroes.GetCurrentPlayer(), 0, Heroes.PTxtFile($7C8E3C));

        if TempStr <> nil then begin
          Res.AppendBuf(Windows.LStrLen(TempStr), TempStr);
        end;
      end else if (c = 'T') and (Caret[1] = '(') then begin
        Inc(Caret, 2);
        TokenStart := Caret;

        while not (Caret^ in [')', #0]) do begin
          Inc(Caret);
        end;

        if Caret^ <> ')' then begin
          ShowErmError('*InterpolateErmStr: missing %T closing parenthesis ")"');
          goto Error;
        end;

        Res.Append(Trans.tr(StrLib.ExtractFromPchar(TokenStart, Caret - TokenStart), []));
        Inc(Caret);
      end else if (Caret^ = 'V') and (Caret[1] in ['f'..'t']) then begin
        // Provide support for old %Vi..%Vf syntax
        Res.Append(SysUtils.IntToStr(QuickVars[Low(QuickVars^) + ord(Caret[1]) - ord('f')]));
        Inc(Caret, 2);
      end else if c in SUPPORTED_PAR_TYPES then begin
        Param.Value   := 0;
        Param.ValType := 0;
        IndexVarType  := PARAM_VARTYPE_NUM;
        BaseTypeChar  := c;
        IsIndexed     := BaseTypeChar in INDEXABLE_PAR_TYPES;

        if IsIndexed then begin
          Inc(Caret);
          IndexTypeChar := Caret^;
        end else begin
          IndexTypeChar := c;
        end;        

        if (IndexTypeChar in ['i', 's']) and (Caret[1] = '(') then begin
          Inc(Caret, 2);

          if IndexTypeChar = 'i' then begin
            IndexVarType := PARAM_VARTYPE_I;
          end else begin
            IndexVarType := PARAM_VARTYPE_S;
          end;

          Param.Value        := integer(Caret);
          NeedsInterpolation := false;

          while not (Caret^ in [')', #0]) do begin
            if Caret^ = '%' then begin
              NeedsInterpolation := true;
            end;

            Inc(Caret);
          end;

          if Caret^ <> ')' then begin
            ShowErmError('*InterpolateErmStr: missing s/i-var closing parenthesis ")"');
            goto Error;
          end;

          if NeedsInterpolation then begin
            Param.SetNeedsInterpolation(true);
          end;

          Inc(Caret);
        end else if IndexTypeChar in ['f'..'t'] then begin
          IndexVarType := PARAM_VARTYPE_QUICK;
          Param.Value  := ord(IndexTypeChar) - ord('f') + Low(QuickVars^);
          Inc(Caret);
        end else if IndexTypeChar = '$' then begin
          MacroParam := ZvsGetMacro(ZvsFindMacro2(Caret, 0, TokenLen));

          if MacroParam <> nil then begin
            IndexVarType := MacroParam.GetType();
            Param.Value  := MacroParam.Value;
          end else begin
            ShowErmError('*GetNum: unknown macro name $...$');
            goto Error;
          end;

          Inc(Caret, TokenLen);
        end else begin
          if IndexTypeChar in ['+', '-', '0'..'9'] then begin
            // Ok
          end else if IndexTypeChar in NATIVE_PAR_TYPES then begin
            if not ConvertVarTypeCharToId(IndexTypeChar, IndexVarType) then begin
              goto Error;
            end;

            Inc(Caret);
          end;

          if not StrLib.ParseIntFromPchar(Caret, Param.Value) and (IndexTypeChar in ['+', '-']) then begin
            ShowErmError('*InterpolateErmStr: expected digit after number sign (+/-). Got: ' + Caret^);
            goto Error;
          end;
        end; // .elseif

        if IsIndexed then begin
          ConvertVarTypeCharToId(BaseTypeChar, BaseVarType);
          Param.SetType(BaseVarType);
          Param.SetIndexedPartType(IndexVarType);

          // Optimize known safe int vars like y3, x15 or v600
          if (IndexVarType = PARAM_VARTYPE_NUM) and (BaseTypeChar in FAST_INT_TYPE_CHARS) and
             (Param.Value >= FastIntVarSets[BaseVarType].MinInd) and (Param.Value <= FastIntVarSets[BaseVarType].MaxInd)
          then begin
            Param.SetCanBeFastIntEvaled(true);
          end;
        end else begin
          Param.SetType(IndexVarType);
        end;

        ParamValue.v := GetErmParamValue(@Param, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX);

        if ValType = VALTYPE_INT then begin
          Res.Append(SysUtils.IntToStr(ParamValue.v));
        end else if ValType = VALTYPE_STR then begin
          Res.AppendBuf(Windows.LStrLen(ParamValue.pc), ParamValue.pc);
        end else if ValType = VALTYPE_FLOAT then begin
          Res.Append(Format('%.3f', [ParamValue.f]));
        end else if ValType = VALTYPE_BOOL then begin
          if ParamValue.v <> 0 then begin
            Res.WriteByte(ord('1'));
          end else begin
            Res.WriteByte(ord('0'));
          end;
        end else begin
          Error:
            Res.AppendBuf(Caret - ChunkStart, ChunkStart);
        end; // .else
      end else begin
        Res.WriteByte(ord('%'));
      end; // .else
    end; // .else
  end; // .while

  if ErmTriggerDepth > 0 then begin
    result := AdvErm.ServiceMemAllocator.AllocStr(Res.Size);
    Res.BuildTo(result, Res.Size);
  end else begin
    result := @InterpolationBuf;
    Res.BuildTo(result, sizeof(InterpolationBuf) - 1);
    result[Math.Min(sizeof(InterpolationBuf) - 1, Res.Size)] := #0;
  end;

  Dec(InterpolationLevel);
  // * * * * * //
  SysUtils.FreeAndNil(Res);
end; // .function InterpolateErmStr

function Hook_ERM2String (Str: pchar; IsZStr: integer; var TokenLen: integer): pchar; cdecl;
var
  Caret:   pchar;
  Start:   pchar;
  EndChar: char;

begin
  if IsZStr <> 0 then begin
    // Optimization: do not interpolate z-1..z-10, z1..z1000, temporary ert variables
    if
      AdvErm.ServiceMemAllocator.OwnsPtr(Str)                                                    or
      ((cardinal(Str) >= cardinal(@z[Low(nz^)])) and (cardinal(Str) <= cardinal(@z[High(nz^)]))) or
      ((cardinal(Str) >= cardinal(@z[Low(z^)]))  and (cardinal(Str) <= cardinal(@z[High(z^)])))
    then begin
      result := Str;
    end else begin
      result := InterpolateErmStr(Str);
    end;
  end else begin
    Caret := Str;

    // Find string literal start ....^....^
    while not (Caret^ in [#0, '^']) do begin
      Inc(Caret);
    end;

    if Caret^ = #0 then begin
      result := '';
      exit;
    end;

    Inc(Caret);
    Start := Caret;

    // Find string literal end ....^
    while not (Caret^ in [#0, '^']) do begin
      Inc(Caret);
    end;

    EndChar  := Caret^;
    Caret^   := #0;
    result   := InterpolateErmStr(Start);
    Caret^   := EndChar;
    TokenLen := Caret - Start;
  end; // .else  
end; // .function Hook_ERM2String

function Hook_ERM2String2 (BufInd: integer; Str: pchar): pchar; cdecl;
begin
  // Optimization: do not interpolate z-1..z-10, z1..z1000, temporary ert variables
  if
    AdvErm.ServiceMemAllocator.OwnsPtr(Str)                                                    or
    ((cardinal(Str) >= cardinal(@z[Low(nz^)])) and (cardinal(Str) <= cardinal(@z[High(nz^)]))) or
    ((cardinal(Str) >= cardinal(@z[Low(z^)]))  and (cardinal(Str) <= cardinal(@z[High(z^)])))
  then begin
    result := Str;
  end else begin
    result := InterpolateErmStr(Str);
  end;
end;

function Hook_ZvsGetNum (SubCmd: PErmSubCmd; ParamInd: integer; DoEval: integer): longbool; cdecl;
const
  INDEXABLE_PAR_TYPES = ['v', 'y', 'x', 'z', 'e', 'w'];
  INDEXING_PAR_TYPES  = ['v', 'y', 'x', 'w', 'f'..'t'];
  NATIVE_PAR_TYPES    = ['v', 'y', 'x', 'z', 'e', 'w', 'f'..'t'];

var
  StartPtr:           pchar;
  Caret:              pchar;
  CheckType:          integer;
  Modifier:           integer;
  Param:              PErmCmdParam;
  BaseTypeChar:       char;
  IndexTypeChar:      char;
  IsIndexed:          longbool;
  AddCurrDay:         longbool;
  BaseVarType:        integer;
  IndexVarType:       integer;
  ValType:            integer;
  NeedsInterpolation: longbool;
  MacroParam:         PErmCmdParam;
  PrevCmdPos:         integer;

label
  Error;

begin
  StartPtr      := @SubCmd.Code.Value[SubCmd.Pos];
  Caret         := StartPtr;
  CheckType     := PARAM_CHECK_NONE;
  Modifier      := PARAM_MODIFIER_NONE;
  Param         := @SubCmd.Params[ParamInd];
  Param.Value   := 0;
  Param.ValType := 0;
  IndexVarType  := PARAM_VARTYPE_NUM;
  result        := false;

  while Caret^ in [#1..#32] do begin
    Inc(Caret);
  end;

  case Caret^ of
    '?': begin
      CheckType := PARAM_CHECK_GET;
      Inc(Caret);
    end;

    'd': begin
      Modifier := PARAM_MODIFIER_ADD;
      Inc(Caret);

      case Caret^ of
        '+': begin                                     Inc(Caret); end;
        '-': begin Modifier := PARAM_MODIFIER_SUB;     Inc(Caret); end;
        '*': begin Modifier := PARAM_MODIFIER_MUL;     Inc(Caret); end;
        ':': begin Modifier := PARAM_MODIFIER_DIV;     Inc(Caret); end;
        '%': begin Modifier := PARAM_MODIFIER_MOD;     Inc(Caret); end;
        '|': begin Modifier := PARAM_MODIFIER_OR;      Inc(Caret); end;
        '~': begin Modifier := PARAM_MODIFIER_AND_NOT; Inc(Caret); end;
        '<': begin if Caret[1] = '<' then begin Modifier := PARAM_MODIFIER_SHL; Inc(Caret, 2); end; end;
        '>': begin if Caret[1] = '>' then begin Modifier := PARAM_MODIFIER_SHR; Inc(Caret, 2); end; end;
      end;
    end;

    '=': begin
      Inc(Caret);

      case Caret^ of
        '>': begin CheckType := PARAM_CHECK_GREATER_EQUAL; Inc(Caret); end;
        '<': begin CheckType := PARAM_CHECK_LOWER_EQUAL;   Inc(Caret); end;
      else
        CheckType := PARAM_CHECK_EQUAL;
      end;
    end;

    '<': begin
      Inc(Caret);

      case Caret^ of
        '=': begin CheckType := PARAM_CHECK_LOWER_EQUAL; Inc(Caret); end;
        '>': begin CheckType := PARAM_CHECK_NOT_EQUAL;   Inc(Caret); end;
      else
        CheckType := PARAM_CHECK_LOWER;
      end;
    end;

    '>': begin
      Inc(Caret);

      if Caret^ = '=' then begin
        CheckType := PARAM_CHECK_GREATER_EQUAL;
        Inc(Caret);
      end else begin
        CheckType := PARAM_CHECK_GREATER;
      end;
    end;
  end; // .switch Caret^

  BaseTypeChar := Caret^;
  IsIndexed    := BaseTypeChar in INDEXABLE_PAR_TYPES;
  AddCurrDay   := BaseTypeChar = 'c';

  if IsIndexed then begin
    Inc(Caret);
  end else if AddCurrDay then begin
    if CheckType = PARAM_CHECK_GET then begin
      ShowErmError('*GetNum: GET-syntax is not compatible with "c" modifier');
      goto Error;
    end;

    Param.SetHasCurrDayModifier(true);

    Inc(Caret);
  end;

  IndexTypeChar := Caret^;

  if (IndexTypeChar = '^') or ((IndexTypeChar in ['i', 's']) and (Caret[1] = '^')) then begin
    if IndexTypeChar = '^' then begin
      Inc(Caret);
      IndexVarType := PARAM_VARTYPE_STR;
    end else begin
      Inc(Caret, 2);

      if IndexTypeChar = 'i' then begin
        IndexVarType := PARAM_VARTYPE_I;
      end else begin
        IndexVarType := PARAM_VARTYPE_S;
      end;
    end;

    Param.Value        := integer(Caret);
    NeedsInterpolation := false;

    while not (Caret^ in ['^', #0]) do begin
      if Caret^ = '%' then begin
        NeedsInterpolation := true;
      end;

      Inc(Caret);
    end;

    if Caret^ <> '^' then begin
      ShowErmError('*GetNum: string end marker (^) not found');
      goto Error;
    end;

    if NeedsInterpolation then begin
      Param.SetNeedsInterpolation(true);
    end;

    Inc(Caret);
  end else if IndexTypeChar in ['f'..'t'] then begin
    IndexVarType := PARAM_VARTYPE_QUICK;
    Param.Value  := ord(IndexTypeChar) - ord('f') + Low(QuickVars^);
    Inc(Caret);
  end else if IndexTypeChar = '$' then begin
    PrevCmdPos := SubCmd.Pos;
    Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));
    MacroParam := ZvsGetMacro(ZvsFindMacro(SubCmd, 0));
    Caret      := @SubCmd.Code.Value[SubCmd.Pos];
    SubCmd.Pos := PrevCmdPos;

    if MacroParam <> nil then begin
      IndexVarType := MacroParam.GetType();
      Param.Value  := MacroParam.Value;
    end else begin
      ShowErmError('*GetNum: unknown macro name $...$');
      goto Error;
    end;
  end else begin
    if IndexTypeChar in ['+', '-', '0'..'9'] then begin
      if not IsIndexed and (CheckType = PARAM_CHECK_GET) then begin
        ShowErmError('*GetNum: GET-syntax cannot be applied to constants');
        goto Error;
      end;
    end else if IndexTypeChar in NATIVE_PAR_TYPES then begin
      if not ConvertVarTypeCharToId(IndexTypeChar, IndexVarType) then begin
        goto Error;
      end;

      Inc(Caret);
    end;

    if not StrLib.ParseIntFromPchar(Caret, Param.Value) and (IndexTypeChar in ['+', '-']) then begin
      ShowErmError('*GetNum: expected digit after number sign (+/-). Got: ' + Caret^);
      goto Error;
    end;
  end; // .else

  if IsIndexed then begin
    ConvertVarTypeCharToId(BaseTypeChar, BaseVarType);
    Param.SetType(BaseVarType);
    Param.SetIndexedPartType(IndexVarType);

    // Optimize known safe int vars like y3, x15 or v600
    if (IndexVarType = PARAM_VARTYPE_NUM) and (BaseTypeChar in FAST_INT_TYPE_CHARS) and
       (Param.Value >= FastIntVarSets[BaseVarType].MinInd) and (Param.Value <= FastIntVarSets[BaseVarType].MaxInd)
    then begin
      Param.SetCanBeFastIntEvaled(true);
    end;
  end else begin
    Param.SetType(IndexVarType);
  end;

  Param.SetCheckType(CheckType);
  SubCmd.Modifiers[ParamInd] := Modifier;

  while Caret^ in [#1..#32] do begin
    Inc(Caret);
  end;

  if (DoEval <> 0) and (CheckType <> PARAM_CHECK_GET) then begin
    SubCmd.Nums[ParamInd] := GetErmParamValue(Param, ValType);
  end else begin
    SubCmd.Nums[ParamInd] := Param.Value;
  end;

  Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));

  exit;

Error:
  while not (Caret^ in [';', #0]) do begin
    Inc(Caret);
  end;

  Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));

  result := true;
end; // .function Hook_ZvsGetNum

function CustomGetNumAuto (Cmd: PErmCmd; SubCmd: PErmSubCmd): integer; stdcall;
const
  DONT_EVAL = 0;
  DO_EVAL   = 1;

  CMD_SN = $4E53;
  CMD_MP = $504D;
  CMD_RD = $4452;
  CMD_VR = $5256;
  CMD_FU = $5546;
  CMD_DO = $4F44;

var
  CmdId:          integer;
  ParamsAddrHash: integer;
  PrevSubCmdPos:  integer;
  CacheEntry:     PCachedSubCmdParams;
  Param:          PErmCmdParam;
  ValType:        integer;
  UseCaching:     longbool;
  i:              integer;

label
  Quit;

begin
  CmdId := Cmd.CmdId.Id;

  // Skip Era triggers, which are interpreted separately
  if (CmdId = CMD_SN) or (CmdId = CMD_MP) or (CmdId = CMD_RD) then begin
    result := 1;
    exit;
  end;

  ParamsAddrHash := Crypto.Tm32Encode(integer(@SubCmd.Code.Value[SubCmd.Pos]));
  CacheEntry     := @SubCmdCache[integer(cardinal(ParamsAddrHash) mod cardinal(Length(SubCmdCache)))];
  UseCaching     := not Cmd.IsGenerated;

  // Initialize all subcommand parameters to NONE value to improve ERM stability
  for i := 0 to High(SubCmd.Params) do begin
    SubCmd.Params[i].Value   := 0;
    SubCmd.Params[i].ValType := PARAM_VARTYPE_NONE;
  end;

  // Caching is ON and HIT
  if UseCaching and (CacheEntry.AddrHash = ParamsAddrHash) then begin
    result := CacheEntry.NumParams;

    if result > 0 then begin
      System.Move(CacheEntry.Params, SubCmd.Params, sizeof(SubCmd.Params[0]) * result);
      System.Move(CacheEntry.Modifiers, SubCmd.Modifiers, sizeof(CacheEntry.Modifiers));
    end;

    for i := 0 to result - 1 do begin
      Param := @SubCmd.Params[i];

      if Param.GetCheckType() <> PARAM_CHECK_GET then begin
        if Param.ValType = PARAM_VARTYPE_NUM then begin
          SubCmd.Nums[i] := Param.Value;
        end else if Param.CanBeFastIntEvaled() then begin
          SubCmd.Nums[i] := FastIntVarAddrs[Param.GetType()][Param.Value];
        end else begin
          SubCmd.Nums[i] := GetErmParamValue(Param, ValType);

          if ValType = VALTYPE_ERROR then begin
            result := -1;
            break;
          end;
        end;
      end else begin
        SubCmd.Nums[i] := Param.Value;
      end; // .else
    end; // .for

    SubCmd.Pos := CacheEntry.Pos;

    exit;
  end; // .if

  result := 0;

  while result < Length(SubCmd.Params) do begin
    PrevSubCmdPos := SubCmd.Pos;

    if Hook_ZvsGetNum(SubCmd, result, DO_EVAL) then begin
      result := -1;

      // Do not cache erroreous commands
      if UseCaching then begin
        CacheEntry.AddrHash := 0;
      end;

      exit;
    end else begin
      // Allow FU/DO receivers to handle zero number of parameters
      if (SubCmd.Pos <> PrevSubCmdPos) or ((CmdId <> CMD_FU) and (CmdId <> CMD_DO)) then begin
        Inc(result);
      end;

      // Support old-style IF:Q#^...^ like syntax, when # and ^...^ are no separated as different arguments
      // Treat them as two standalone arguments
      case SubCmd.Code.Value[SubCmd.Pos] of
        '^': continue;
        '/': Inc(SubCmd.Pos);
      else
        goto Quit;
      end;
    end; // .else
  end; // .while

Quit:
  if not UseCaching then begin
    exit;
  end;

  CacheEntry.AddrHash  := ParamsAddrHash;
  CacheEntry.NumParams := result;

  if result > 0 then begin
    System.Move(SubCmd.Params, CacheEntry.Params, sizeof(SubCmd.Params[0]) * result);
    System.Move(SubCmd.Modifiers, CacheEntry.Modifiers, sizeof(CacheEntry.Modifiers));
  end;

  CacheEntry.Pos := SubCmd.Pos;
end; // .function CustomGetNumAuto

procedure PutVal (ValuePtr: pointer; ValueSize, Value, Modifier: integer);
const
  BITS_IN_INT32 = 32;

var
  OrigValue:  integer;
  FinalValue: integer;

begin
  case ValueSize of
    4:  OrigValue := pinteger(ValuePtr)^;
    2:  OrigValue := psmallint(ValuePtr)^;
    1:  OrigValue := pshortint(ValuePtr)^;
    -4: OrigValue := pinteger(ValuePtr)^;
    -2: OrigValue := pword(ValuePtr)^;
    -1: OrigValue := pbyte(ValuePtr)^;
  else
    exit;
  end;

  FinalValue := Value;

  case Modifier of
    PARAM_MODIFIER_NONE:    begin (* already set *) end;
    PARAM_MODIFIER_ADD:     FinalValue := OrigValue + Value;
    PARAM_MODIFIER_SUB:     FinalValue := OrigValue - Value;
    PARAM_MODIFIER_MUL:     FinalValue := OrigValue * Value;
    PARAM_MODIFIER_OR:      FinalValue := OrigValue or Value;
    PARAM_MODIFIER_AND_NOT: FinalValue := OrigValue and not Value;
    PARAM_MODIFIER_SHL:     FinalValue := OrigValue shl Alg.ToRange(Value, 0, BITS_IN_INT32);
    PARAM_MODIFIER_SHR:     FinalValue := OrigValue shr Alg.ToRange(Value, 0, BITS_IN_INT32);

    PARAM_MODIFIER_DIV: begin
      if Value <> 0 then begin
        FinalValue := OrigValue div Value;
      end else begin
        ShowErmError('Division by zero in d-modifier');
      end;
    end;

    PARAM_MODIFIER_MOD: begin
      if Value <> 0 then begin
        FinalValue := OrigValue mod Value;
      end else begin
        ShowErmError('Division by zero in d-modifier');
      end;
    end;
  else
    FinalValue := Value;
  end; // .switch

  if ValueSize < 0 then begin
    ValueSize := -ValueSize;
  end;

  case ValueSize of
    4: pinteger(ValuePtr)^  := FinalValue;
    2: psmallint(ValuePtr)^ := FinalValue;
    1: pshortint(ValuePtr)^ := FinalValue;
  end;
end; // .procedure PutVal

(* Ensures, that value does not belong to NAN/+Inf/-Inf *)
function NormalizeErmFloatValue (Value: single): single;
begin
  result := Value;

  if result <> result then begin
    result := 0;
  end else if result = Infinity then begin
    result := ERM_MAX_FLOAT;
  end else if result = -Infinity then begin
    result := ERM_MIN_FLOAT;
  end;
end;

function ApplyFloatModifier (OrigValue, Value: single; Modifier: integer): single;
begin
  result := Value;

  if Modifier <> PARAM_MODIFIER_NONE then begin
    case Modifier of
      PARAM_MODIFIER_ADD: result := OrigValue + Value;
      PARAM_MODIFIER_SUB: result := OrigValue - Value;
      PARAM_MODIFIER_MUL: result := OrigValue * Value;

      PARAM_MODIFIER_DIV: begin
        if Value <> 0 then begin
          result := OrigValue / Value;
        end else begin
          ShowErmError('Division by zero in d-modifier');
        end;
      end;

      PARAM_MODIFIER_MOD: begin
        if Value <> 0 then begin
          result := frac(OrigValue / Value) * Value;
        end else begin
          ShowErmError('Division by zero in d-modifier');
        end;
      end;
    end; // .switch

    result := NormalizeErmFloatValue(result);
  end; // .if
end; // .function ApplyFloatModifier

function Hook_ZvsApply (ValuePtr: pointer; ValueSize: integer; SubCmd: PErmSubCmd; ParamInd: byte): integer; cdecl;
var
  Param:       PErmCmdParam;
  Value:       integer;
  SecondValue: integer;
  CheckType:   integer;

begin
  Param  := @SubCmd.Params[ParamInd];
  result := 1;

  // Ignore not used parameters at all, improving ERM stability
  if Param.GetType() <> PARAM_VARTYPE_NONE then begin
    CheckType := Param.GetCheckType();

    if CheckType = PARAM_CHECK_NONE then begin
      result := 0;
      PutVal(ValuePtr, ValueSize, SubCmd.Nums[ParamInd], SubCmd.Modifiers[ParamInd]);
    end else begin
      Value := ZvsGetVal(ValuePtr, ValueSize);

      if CheckType = PARAM_CHECK_GET then begin
        if not SetErmParamValue(Param, Value) then begin
          result := -1;
        end;

        exit;
      end else begin
        SecondValue := SubCmd.Nums[ParamInd];

        case CheckType of
          PARAM_CHECK_EQUAL:         f[1] := Value = SecondValue;
          PARAM_CHECK_NOT_EQUAL:     f[1] := Value <> SecondValue;
          PARAM_CHECK_GREATER:       f[1] := Value > SecondValue;
          PARAM_CHECK_LOWER:         f[1] := Value < SecondValue;
          PARAM_CHECK_GREATER_EQUAL: f[1] := Value >= SecondValue;
          PARAM_CHECK_LOWER_EQUAL:   f[1] := Value <= SecondValue;
        end; // switch CheckType
      end; // .else
    end; // .else
  end; // .if
end; // .function Hook_ZvsApply

procedure ProcessErm;
const
  (* Ifs state *)
  STATE_TRUE     = 1;
  STATE_FALSE    = 0;
  STATE_INACTIVE = 2;

  (* ERM commands *)
  CMD_IF = $6669;
  CMD_EL = $6C65;
  CMD_EN = $6E65;
  CMD_RE = $6572;
  CMD_BR = $7262;
  CMD_CO = $6F63;

  (* Flow control operator type *)
  OPER_IF = 0;
  OPER_RE = 1;

type
  PFlowControlOper = ^TFlowControlOper;
  TFlowControlOper = record
    State:    integer;
    OperType: integer;
    LoopVar:  PErmCmdParam;
    Stop:     integer;
    Step:     integer;
    CmdInd:   integer;
  end;

var
{Un} SavedTriggerLocalObjects: {O} TList {of TObject};

  PrevTriggerCmdIndPtr: pinteger;
  NumericEventName:     string;
  HumanEventName:       string;
  EventX:               integer;
  EventY:               integer;
  EventZ:               integer;
  TriggerId:            integer;
  StartTrigger:         PErmTrigger;
  Trigger:              PErmTrigger;
  EventManager:         TEventManager;
  HasEventHandlers:     longbool;
  SavedY:               TErmYVars;
  SavedNY:              TErmNYVars;
  SavedE:               TErmEVars;
  SavedX:               TErmXVars;
  SavedQuickVars:       TErmQuickVars;
  SavedZ:               TErmNZVars;
  SavedF:               array [996..1000] of boolean;
  SavedV:               array [997..1000] of integer;
  SavedNumArgsReceived: integer;
  SavedArgsGetSyntaxFlagsReceived: integer;
  LoopCallback:         TTriggerLoopCallback;
  FlowOpers:            array [0..15] of TFlowControlOper;
  FlowOpersLevel:       integer;
  FlowOper:             PFlowControlOper;
  LoopVarValue:         integer;
  TargetLoopLevel:      integer;
  ParamValType:         integer;
  Cmd:                  PErmCmd;
  CmdId:                TErmCmdId;
  i, j:                 integer;

  procedure SetTriggerQuickVarsAndFlags;
  begin
    f[999] := Heroes.IsThisPcTurn();

    // Really the meaning of ZvsGmAiFlags is overloaded and cannot be trusted without looking at ERM help
    if ZvsGmAiFlags^ >= 0 then begin
      f[1000] := ZvsGmAiFlags^ <> 0;
    end else begin
      f[1000] := not ZvsIsAi(Heroes.GetCurrentPlayer());
    end;

    v[998]  := EventX;
    v[999]  := EventY;
    v[1000] := EventZ;
  end; // .procedure SetTriggerQuickVarsAndFlags

  procedure SaveVars;
  var
    i: integer;

  begin
    SavedY := y^;

    if ErmLegacySupport and ((TriggerId < TRIGGER_FU1) or (TriggerId > TRIGGER_FU29999)) then begin
      SavedNY := ny^;
    end;

    SavedE         := e^;
    SavedX         := x^;
    x^             := ArgXVars;
    SavedQuickVars := QuickVars^;

    SavedNumArgsReceived            := NumFuncArgsReceived;
    NumFuncArgsReceived             := NumFuncArgsPassed;
    SavedArgsGetSyntaxFlagsReceived := FuncArgsGetSyntaxFlagsReceived;
    FuncArgsGetSyntaxFlagsReceived  := FuncArgsGetSyntaxFlagsPassed;

    for i := 1 to High(nz^) do begin
      Utils.SetPcharValue(@SavedZ[i], @nz[i], sizeof(z[1]));
    end;

    for i := Low(SavedF) to High(SavedF) do begin
      SavedF[i] := f[i];
    end;

    for i := Low(SavedV) to High(SavedV) do begin
      SavedV[i] := v[i];
    end;
  end; // .procedure SaveVars

  procedure ResetLocalVars;
  var
    i: integer;

  begin
    FillChar(y^, sizeof(y^), #0);
    FillChar(e^, sizeof(e^), #0);

    if not ErmLegacySupport or (TriggerId < TRIGGER_FU1) or (TriggerId > TRIGGER_FU29999) then begin
      for i := 1 to High(nz^) do begin
        pinteger(@nz[i])^ := 0;
      end;
    end;
  end;

  procedure RestoreVars;
  var
    i: integer;

  begin
    y^ := SavedY;

    if ErmLegacySupport and ((TriggerId < TRIGGER_FU1) or (TriggerId > TRIGGER_FU29999)) then begin
      ny^ := SavedNY;
    end;

    e^         := SavedE;
    RetXVars   := x^;
    x^         := SavedX;
    QuickVars^ := SavedQuickVars;

    NumFuncArgsReceived            := SavedNumArgsReceived;
    FuncArgsGetSyntaxFlagsReceived := SavedArgsGetSyntaxFlagsReceived;

    for i := 1 to High(nz^) do begin
      Utils.SetPcharValue(@nz[i], @SavedZ[i], sizeof(z[1]));
    end;

    for i := Low(SavedF) to High(SavedF) do begin
      f[i] := SavedF[i];
    end;

    for i := Low(SavedV) to High(SavedV) do begin
      v[i] := SavedV[i];
    end;
  end; // .procedure RestoreVars

label
  AfterTriggers, TriggersProcessed;

begin
  StartTrigger             := nil;
  Trigger                  := nil;
  SavedTriggerLocalObjects := nil;
  PrevTriggerCmdIndPtr     := nil;
  EventManager             := EventMan.GetInstance;
  // * * * * * //
  if not ErmEnabled^ then begin
    RetXVars := ArgXVars;
    exit;
  end;

  TriggerId := CurrErmEventId^;

  Inc(ErmTriggerDepth);
  StartTrigger := FindFirstTrigger(TriggerId);

  LoopCallback                := TriggerLoopCallback;
  TriggerLoopCallback.Handler := nil;

  NumericEventName := 'OnTrigger ' + SysUtils.IntToStr(TriggerId);
  HumanEventName   := GetTriggerReadableName(TriggerId);
  HasEventHandlers := (StartTrigger.Id <> 0) or EventManager.HasEventHandlers(NumericEventName) or EventManager.HasEventHandlers(HumanEventName);

  if HasEventHandlers then begin
    SaveVars;
    ResetLocalVars;

    EventX   := ZvsEventX^;
    EventY   := ZvsEventY^;
    EventZ   := ZvsEventZ^;

    SetTriggerQuickVarsAndFlags;

    if TrackingOpts.Enabled then begin
      EventTracker.TrackTrigger(ErmTracking.TRACKEDEVENT_START_TRIGGER, TriggerId);
    end;

    PrevTriggerCmdIndPtr     := CurrentTriggerCmdIndPtr;
    CurrentTriggerCmdIndPtr  := @i;
    SavedTriggerLocalObjects := TriggerLocalObjects;
    TriggerLocalObjects      := nil;

    // Repeat executing all triggers with specified ID, unless TriggerLoopCallback is not set or returns false
    while true do begin
      EventManager.Fire(NumericEventName, @TriggerId, sizeof(TriggerId));
      EventManager.Fire(HumanEventName, @TriggerId, sizeof(TriggerId));

      Trigger := StartTrigger;

      // Loop through all triggers with specified ID / through all triggers in instructions phase
      while (Trigger <> nil) and (Trigger.Id <> 0) do begin
        // Execute only active triggers with commands
        if (Trigger.Id = TriggerId) and (Trigger.NumCmds > 0) and (Trigger.Disabled = 0) then begin
          FlowOpersLevel   := -1;
          ZvsBreakTrigger^ := false;
          QuitTriggerFlag  := false;

          if not ZvsCheckFlags(@Trigger.Conditions) then begin
            // For classic WoG non-function triggers only
            if ErmLegacySupport and ((TriggerId < 0) or ((TriggerId >= TRIGGER_TM1) and (TriggerId <= TRIGGER_TL4)) or (TriggerId >= TRIGGER_OB_POS)) then begin
              FillChar(ny^, sizeof(ny^), #0);
            end;

            i := 0;

            while i < Trigger.NumCmds do begin
              if not ErmEnabled^ then begin
                goto AfterTriggers;
              end;

              Cmd               := Utils.PtrOfs(@Trigger.FirstCmd, i * sizeof(TErmCmd));
              ErmErrCmdPtr^ := Cmd.CmdHeader.Value;
              CmdId             := Cmd.CmdId;

              if CmdId.Id = CMD_IF then begin
                Inc(FlowOpersLevel);

                if FlowOpersLevel > High(FlowOpers) then begin
                  ShowErmError('"if" - too many IF/REs (>16)');
                  goto AfterTriggers;
                end;

                FlowOpers[FlowOpersLevel].OperType := OPER_IF;

                // Active IF
                if (FlowOpersLevel = 0) or (FlowOpers[FlowOpersLevel - 1].State = STATE_TRUE) then begin
                  FlowOpers[FlowOpersLevel].State := ord(not ZvsCheckFlags(@Cmd.Conditions));
                end
                // Inactive IF
                else begin
                  FlowOpers[FlowOpersLevel].State := STATE_INACTIVE;
                end;
              end else if CmdId.Id = CMD_EL then begin
                if (FlowOpersLevel < 0) or (FlowOpers[FlowOpersLevel].OperType <> OPER_IF) then begin
                  ShowErmError('"el" - no IF for ELSE');
                  goto AfterTriggers;
                end;

                if FlowOpers[FlowOpersLevel].State = STATE_TRUE then begin
                  FlowOpers[FlowOpersLevel].State := STATE_INACTIVE;
                end else if FlowOpers[FlowOpersLevel].State = STATE_FALSE then begin
                  FlowOpers[FlowOpersLevel].State := ord(not ZvsCheckFlags(@Cmd.Conditions));
                end;
              end else if CmdId.Id = CMD_EN then begin
                if FlowOpersLevel < 0 then begin
                  ShowErmError('"en" - no IF/RE for ENDIF');
                  goto AfterTriggers;
                end;

                FlowOper := @FlowOpers[FlowOpersLevel];

                if (FlowOper.State <> STATE_TRUE) or (FlowOper.OperType = OPER_IF) then begin
                  Dec(FlowOpersLevel);
                end else if FlowOper.OperType = OPER_RE then begin
                  LoopVarValue := ZvsGetVarVal(FlowOper.LoopVar) + FlowOper.Step;

                  if FlowOper.Step <> 0 then begin
                    ZvsSetVarVal(FlowOper.LoopVar, LoopVarValue);
                  end;

                  if (FlowOper.Step >= 0) and (LoopVarValue > FlowOper.Stop) or (FlowOper.Step < 0) and (LoopVarValue < FlowOper.Stop) then begin
                    Dec(FlowOpersLevel);
                  end else begin
                    i := FlowOper.CmdInd - 1;
                  end;
                end;
              end else if CmdId.Id = CMD_RE then begin
                Inc(FlowOpersLevel);

                if FlowOpersLevel > High(FlowOpers) then begin
                  ShowErmError('"re" - too many IF/REs (>16)');
                  goto AfterTriggers;
                end;

                FlowOper          := @FlowOpers[FlowOpersLevel];
                FlowOper.OperType := OPER_RE;

                // Active RE
                if (FlowOpersLevel = 0) or (FlowOpers[FlowOpersLevel - 1].State = STATE_TRUE) then begin
                  FlowOper.State   := STATE_TRUE;
                  FlowOper.LoopVar := @Cmd.Params[0];
                  FlowOper.Stop    := High(integer);
                  FlowOper.Step    := 1;
                  FlowOper.CmdInd  := i + 1;

                  if Cmd.NumParams >= 2 then begin
                    LoopVarValue := GetErmParamValue(@Cmd.Params[1], ParamValType);
                    ZvsSetVarVal(FlowOper.LoopVar, LoopVarValue);
                  end else begin
                    LoopVarValue := GetErmParamValue(FlowOper.LoopVar, ParamValType);
                  end;

                  if Cmd.NumParams >= 3 then begin
                    FlowOper.Stop := GetErmParamValue(@Cmd.Params[2], ParamValType);
                  end else begin
                    FlowOper.Step := 0;
                  end;

                  if Cmd.NumParams >= 4 then begin
                    FlowOper.Step := GetErmParamValue(@Cmd.Params[3], ParamValType);
                  end;

                  if Cmd.NumParams >= 5 then begin
                    Inc(FlowOper.Stop, GetErmParamValue(@Cmd.Params[4], ParamValType));
                  end;

                  if FlowOper.Step >= 0 then begin
                    if LoopVarValue > FlowOper.Stop then begin
                      FlowOper.State := STATE_INACTIVE;
                    end;
                  end else begin
                    if LoopVarValue < FlowOper.Stop then begin
                      FlowOper.State := STATE_INACTIVE;
                    end;
                  end;
                end
                // Inactive RE
                else begin
                  FlowOper.State := STATE_INACTIVE;
                end;
              end else if (CmdId.Id = CMD_BR) or (CmdId.Id = CMD_CO) then begin
                if ((FlowOpersLevel < 0) or (FlowOpers[FlowOpersLevel].State = STATE_TRUE)) and not ZvsCheckFlags(@Cmd.Conditions) then begin
                  if FlowOpersLevel < 0 then begin
                    ShowErmError('"br/co" - no loop to break/continue');
                    goto AfterTriggers;
                  end;

                  TargetLoopLevel := GetErmParamValue(@Cmd.Params[0], ParamValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX);

                  if ParamValType <> VALTYPE_INT then begin
                    ShowErmError('"br/co" - loop index must be positive number. Given: non-integer');
                  end;

                  if TargetLoopLevel < 0 then begin
                    ShowErmError('"br/co" - loop index must be positive number. Given: ' + IntToStr(TargetLoopLevel));
                    goto AfterTriggers;
                  end else if TargetLoopLevel = 0 then begin
                    TargetLoopLevel := 1;
                  end;

                  j := FlowOpersLevel;

                  while (j >= 0) and (TargetLoopLevel > 0) do begin
                    if FlowOpers[j].OperType <> OPER_RE then begin
                      Dec(j);
                    end else begin
                      Dec(TargetLoopLevel);

                      if TargetLoopLevel > 0 then begin
                        Dec(j);
                      end;
                    end;
                  end;

                  if j < 0 then begin
                    ShowErmError('"br/co" - no loop to break/continue');
                    goto AfterTriggers;
                  end;

                  FlowOpersLevel := j;
                  FlowOper       := @FlowOpers[j];
                  i              := FlowOper.CmdInd - 1;

                  if CmdId.Id = CMD_BR then begin
                    FlowOper.State := STATE_INACTIVE;
                  end else if CmdId.Id = CMD_CO then begin
                    LoopVarValue := ZvsGetVarVal(FlowOper.LoopVar) + FlowOper.Step;

                    if FlowOper.Step <> 0 then begin
                      ZvsSetVarVal(FlowOper.LoopVar, LoopVarValue);
                    end;

                    if (FlowOper.Step >= 0) and (LoopVarValue > FlowOper.Stop) or (FlowOper.Step < 0) and (LoopVarValue < FlowOper.Stop) then begin
                      FlowOper.State := STATE_INACTIVE;
                    end;
                  end; // .else
                end; // .if
              end else if ((FlowOpersLevel < 0) or (FlowOpers[FlowOpersLevel].State = STATE_TRUE)) and not ZvsCheckFlags(@Cmd.Conditions) then begin
                ZvsProcessCmd(Cmd);

                if ZvsBreakTrigger^ then begin
                  ZvsBreakTrigger^ := false;
                  break;
                end else if QuitTriggerFlag then begin
                  QuitTriggerFlag := false;
                  goto TriggersProcessed;
                end;
              end; // .else

              Inc(i);
            end; // .while
          end; // .if
        end; // .if

        if TriggerLocalObjects <> nil then begin
          TriggerLocalObjects.Free;
          TriggerLocalObjects := nil;
        end;

        Trigger := Trigger.Next;
      end; // .while

      TriggersProcessed:

      // Loop handling
      if (@LoopCallback.Handler = nil) or not LoopCallback.Handler(LoopCallback.Data) then begin
        break;
      end;
    end; // .while
  end; // .if HasEventHandlers

  AfterTriggers:

  Dec(ErmTriggerDepth);

  if HasEventHandlers then begin
    if TrackingOpts.Enabled then begin
      EventTracker.TrackTrigger(ErmTracking.TRACKEDEVENT_END_TRIGGER, TriggerId);
    end;

    RestoreVars;
    CurrentTriggerCmdIndPtr := PrevTriggerCmdIndPtr;

    if TriggerLocalObjects <> nil then begin
      TriggerLocalObjects.Free;
    end;

    TriggerLocalObjects := SavedTriggerLocalObjects;
  end else begin
    RetXVars := ArgXVars;
  end;
end; // .procedure ProcessErm

function Hook_ProcessCmd (Context: Core.PHookContext): longbool; stdcall;
const
  PREV_CMD_LOCAL_OBJECTS_OFS = -$4;

begin
  if TrackingOpts.Enabled then begin
    EventTracker.TrackCmd(PErmCmd(ppointer(Context.EBP + 8)^).CmdHeader.Value);
  end;

  ServiceMemAllocator.AllocPage;
  ppointer(Context.EBP + PREV_CMD_LOCAL_OBJECTS_OFS)^ := CmdLocalObjects;
  CmdLocalObjects                                     := nil;

  ErmErrReported := false;
  result         := Core.EXEC_DEF_CODE;
end;

function Hook_ProcessCmd_End (Context: Core.PHookContext): longbool; stdcall;
const
  PREV_CMD_LOCAL_OBJECTS_OFS = -$4;

begin
  while CmdLocalObjects <> nil do begin
    ErtStrings.DeleteItem(Ptr(CmdLocalObjects.ErtIndex));
    CmdLocalObjects := CmdLocalObjects.Prev;
  end;

  CmdLocalObjects := ppointer(Context.EBP + PREV_CMD_LOCAL_OBJECTS_OFS)^;
  ServiceMemAllocator.FreePage;
  result := true;
end;

function Hook_FindErm_BeforeMainLoop (Context: Core.PHookContext): longbool; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;

begin
  // Skip internal map events: GEp_ = GEp1 - [sizeof(_GlbEvent_) = 52]
  pinteger(Context.EBP - $3F4)^ := pinteger(pinteger(Context.EBP - $24)^ + $88)^ - GLOBAL_EVENT_SIZE;
  ErmErrReported                := false;

  EventMan.GetInstance.Fire('OnBeforeErm');

  if not ZvsIsGameLoading^ then begin
    EventMan.GetInstance.Fire('OnBeforeErmInstructions');
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_BeforeMainLoop

function Hook_FindErm_ZeroHeap (Context: Core.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - $354)^ := ZvsErmHeapSize^;
  Windows.VirtualFree(ZvsErmHeapPtr^, ZvsErmHeapSize^, Windows.MEM_DECOMMIT);
  Windows.VirtualAlloc(ZvsErmHeapPtr^, ZvsErmHeapSize^, Windows.MEM_COMMIT, Windows.PAGE_READWRITE);

  Context.RetAddr := Ptr($7499ED);
  result          := not Core.EXEC_DEF_CODE;
end;

var
  _NumMapScripts:    integer;
  _NumGlobalScripts: integer;

function Hook_FindErm_AfterMapScripts (Context: Core.PHookContext): longbool; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;

var
  ScriptIndPtr: pinteger;

begin
  ScriptIndPtr := Ptr(Context.EBP - $18);
  // * * * * * //
  if not ZvsIsGameLoading^ and (ScriptIndPtr^ = 0) then begin
    EventMan.GetInstance.Fire('$OnEraMapStart');
    ZvsResetCommanders;
    AdvErm.ResetMemory;
    FuncNames.Clear;
    FuncAutoId := INITIAL_FUNC_AUTO_ID;
    RegisterErmEventNames;
    ScriptMan.LoadScriptsFromDisk(TScriptMan.IS_FIRST_LOADING);
  end;

  if ScriptIndPtr^ = 0 then begin
    _NumMapScripts    := 0;
    _NumGlobalScripts := 0;
  end;

  if (ScriptIndPtr^ < ScriptMan.Scripts.Count) and (_NumGlobalScripts = 0) then begin
    if ScriptMan.IsMapScript(ScriptIndPtr^) then begin
      Inc(_NumMapScripts);
    end else begin
      Inc(_NumGlobalScripts);
    end;

    if (_NumMapScripts > 0) and (_NumGlobalScripts > 0) then begin
      if (WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_WOGIFY] = DONT_WOGIFY) or
         ((WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_WOGIFY] = WOGIFY_AFTER_ASKING) and Heroes.Ask(Trans.tr('era.global_scripts_vs_map_scripts_warning', [])))
      then begin
        WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_WOGIFY] := DONT_WOGIFY;
        ScriptMan.Scripts.Truncate(ScriptIndPtr^);
      end else begin
        WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_WOGIFY] := WOGIFY_ALL;
      end;
    end;
  end; // .if

  if ScriptIndPtr^ < ScriptMan.Scripts.Count then begin
    // M.m.i = 0
    pinteger(Context.EBP - $318)^ := 0;
    // M.m.s = ErmScript
    ppchar(Context.EBP - $314)^ := ScriptMan.Scripts[ScriptIndPtr^].GetPtr();
    // M.m.l = Length(ErmScript)
    pinteger(Context.EBP - $310)^ := Length(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // GEp_--; Process one more script
    Dec(pinteger(Context.EBP - $3F4)^, GLOBAL_EVENT_SIZE);
    Inc(ScriptIndPtr^);
    // Jump to ERM header processing
    Context.RetAddr := Ptr($74A00C);
  end else begin
    // Jump right after loop end
    Context.RetAddr := Ptr($74C5A7);
  end; // .else

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_AfterMapScripts

(* Loads WoG options from file for current map only (not global) *)
function LoadWoGOptions (FilePath: pchar): boolean; ASSEMBLER;
asm
  PUSH $0FA0
  PUSH $2771920
  PUSH EAX // FilePath
  MOV EAX, $773867
  CALL EAX
  ADD ESP, $0C
  CMP EAX, 0
  JGE @OK // ==>
  xor EAX, EAX
  JMP @Done
@OK:
  xor EAX, EAX
  Inc EAX
@Done:
end; // .function LoadWoGOptions

procedure EnableCommanders;
var
  i: integer;

begin
  ZvsEnableNpc(-1, 1 - ord(WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_COMMANDERS_NEED_HIRING] <> 0));

  for i := 7 to 10 do begin
    ZvsChestsEnabled[i] := 1;
  end;
end;

procedure DisableCommanders;
var
  i: integer;

begin
  ZvsDisableNpc(-1);

  for i := 7 to 10 do begin
    ZvsChestsEnabled[i] := 0;
  end;
end;

function Hook_UN_J3_End (Context: Core.PHookContext): longbool; stdcall;
const
  RESET_OPTIONS_COMMAND = ':clear:';
  USE_SELECTED_RULES    = 2;

var
  WoGOptionsFile: string;
  i:              integer;

begin
  WoGOptionsFile := pchar(Context.ECX);

  if WoGOptionsFile = RESET_OPTIONS_COMMAND then begin
    for i := 0 to High(WoGOptions[CURRENT_WOG_OPTIONS]) do begin
      WoGOptions[CURRENT_WOG_OPTIONS][i] := 0;
    end;

    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_MAP_RULES]                      := USE_SELECTED_RULES;
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_TOWERS_EXP_DISABLED]            := 1;
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_LEAVE_MONS_ON_ADV_MAP_DISABLED] := 1;
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_COMMANDERS_DISABLED]            := 1;
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_TOWN_DESTRUCT_DISABLED]         := 1;
  end else if not LoadWoGOptions(pchar(WoGOptionsFile)) then begin
    ShowMessage('Cannot load file with WoG options: ' + WoGOptionsFile);
  end;

  if WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_COMMANDERS_DISABLED] <> 0 then begin
    DisableCommanders;
  end else begin
    EnableCommanders;
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_UN_J3_End

function Hook_UN_J13 (Context: Core.PHookContext): longbool; stdcall;
const
  SUBCMD_ID = 13;

begin
  if pinteger(Context.EBP - $E4)^ = SUBCMD_ID then begin
    ZvsResetCommanders;
    Context.RetAddr := Ptr($733F2E);
    result          := not Core.EXEC_DEF_CODE;
  end else begin
    result := Core.EXEC_DEF_CODE;
  end;
end;

function Hook_UN_P3 (Context: Core.PHookContext): longbool; stdcall;
begin
  if WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_COMMANDERS_DISABLED] = 0 then begin
    EnableCommanders;
  end else begin
    DisableCommanders;
  end;

  Context.RetAddr := Ptr($732ED1);
  result          := not Core.EXEC_DEF_CODE;
end;

{$W-}
procedure Hook_ErmCastleBuilding; ASSEMBLER;
asm
  MOVZX EDX, byte [ECX + $150]
  MOVZX EAX, byte [ECX + $158]
  or EDX, EAX
  PUSH $70E8A9
  // RET
end;
{$W+}

function Hook_ErmHeroArt (Context: Core.PHookContext): longbool; stdcall;
begin
  result := ((pinteger(Context.EBP - $E8)^ shr 8) and 7) = 0;

  if not result then begin
    Context.RetAddr := Ptr($744B85);
  end;
end;

function Hook_ErmHeroArt_FindFreeSlot (Context: Core.PHookContext): longbool; stdcall;
begin
  f[1]   := false;
  result := Core.EXEC_DEF_CODE;
end;

function Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookContext): longbool; stdcall;
begin
  f[1]   := true;
  result := Core.EXEC_DEF_CODE;
end;

function Hook_ErmHeroArt_DeleteFromBag (Context: Core.PHookContext): longbool; stdcall;
const
  NUM_BAG_ARTS_OFFSET = +$3D4;
  HERO_PTR_OFFSET     = -$380;

var
  Hero: pointer;

begin
  Hero := PPOINTER(Context.EBP + HERO_PTR_OFFSET)^;
  Dec(PBYTE(Utils.PtrOfs(Hero, NUM_BAG_ARTS_OFFSET))^);
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ErmHeroArt_DeleteFromBag

function Hook_HE_P (Context: ApiJack.PHookContext): longbool; stdcall;
var
  NumParams: integer;
  Hero:      Heroes.PHero;
  SubCmd:    PErmSubCmd;
  x:         integer;
  y:         integer;
  z:         integer;

begin
  // OK result
  Context.RetAddr := Ptr($74943B);
  NumParams       := pinteger(Context.EBP - $10)^;
  Hero            := ppointer(Context.EBP - $380)^;
  SubCmd          := pointer(Context.EBP - $300);

  x := Hero.x;
  y := Hero.y;
  z := Hero.l;

  ZvsApply(@x, sizeof(x), SubCmd, 0);
  ZvsApply(@y, sizeof(y), SubCmd, 1);
  ZvsApply(@z, sizeof(z), SubCmd, 2);

  if (x <> Hero.x) or (y <> Hero.y) or (z <> Hero.l) then begin
    // Flag 4 is set and hero belongs to current player - do teleport with sound and redraw
    // If Flag 4 is not specified, for compatibility reasons apply smart auto behavior
    if (Heroes.GetCurrentPlayer = Hero.Owner) and ((NumParams <= 3) or ((NumParams > 3) and (SubCmd.Nums[3] <> 0))) then begin
      PatchApi.Call(CDECL_, Ptr($712008), [Hero, x, y, z, 1]);
    end else begin
      Heroes.HideHero(Hero);
      Hero.x := x;
      Hero.y := y;
      Hero.l := z;
      Heroes.ShowHero(Hero);
    end;
  end;

  result := false;
end; // .function Hook_HE_P

function Hook_HE_C (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ITEM_TYPE_HERO                    = 1;
  OPER_SET_TYPE_AND_NUM             = 5;
  STACK_EXP_MOD_SET_FOR_WHOLE_STACK = 2;
  STACK_EXP_MOD_ADD_FOR_WHOLE_STACK = 3;

var
  NumParams:   integer;
  Hero:        Heroes.PHero;
  SubCmd:      PErmSubCmd;
  Slot:        integer;
  MonType:     integer;
  MonNum:      integer;
  ExpMod:      integer;
  Exp:         integer;
  OrigExp:     integer;
  IsCheckOnly: longbool;

begin
  // OK result
  Context.RetAddr := Ptr($74943B);
  NumParams       := pinteger(Context.EBP - $10)^;
  Hero            := ppointer(Context.EBP - $380)^;
  SubCmd          := pointer(Context.EBP - $300);
  Slot            := SubCmd.Nums[1];
  IsCheckOnly     := true;
  result          := false;

  MonType := Hero.MonTypes[Slot];
  MonNum  := Hero.MonNums[Slot];

  if ZvsApply(@MonType, sizeof(MonType), SubCmd, 2) = 0 then begin
    IsCheckOnly := false;
  end;

  if ZvsApply(@MonNum, sizeof(MonNum), SubCmd, 3) = 0 then begin
    IsCheckOnly := false;
  end;

  // Fast quit for HE:C0/#/?$/?$
  if IsCheckOnly and (NumParams < 5) then begin
    exit;
  end;

  // Normalize creature type/number values
  if (MonType < 0) or (MonNum <= 0) then begin
    MonType := -1;
    MonNum  := 0;
  end;

  // Update hero structure. Get original values to MonType/MonNum
  Utils.Exchange(Hero.MonTypes[Slot], MonType);
  Utils.Exchange(Hero.MonNums[Slot],  MonNum);

  // Fast quit for HE:C0/#/$/$ if slot was not really changed and exp was not specified
  if (NumParams < 5) and (MonType = Hero.MonTypes[Slot]) and (MonNum = Hero.MonNums[Slot]) then begin
    exit;
  end;

  Exp    := 0;
  ExpMod := 0;

  if NumParams >= 6 then begin
    ExpMod := SubCmd.Nums[5];
  end;

  if NumParams >= 5 then begin
    Exp     := ZvsCrExpoSet_GetExpM(ITEM_TYPE_HERO, Hero.Id + Slot * $10000, ExpMod);
    OrigExp := Exp;

    if ZvsApply(@Exp, sizeof(Exp), SubCmd, 4) <> 0 then begin
      Exp := 0;
    end else begin
      IsCheckOnly := false;
    end;
  end;

  // Fast quit if type/num/exp were used with GET-syntax only
  if IsCheckOnly then begin
    exit;
  end;

  ZvsCrExpoSet_Modify(OPER_SET_TYPE_AND_NUM, ITEM_TYPE_HERO, Hero.Id + Slot * $10000, Exp, ExpMod, Hero.MonTypes[Slot], MonNum, Hero.MonNums[Slot]);
end; // .function Hook_HE_C

function Hook_HE_X (Context: ApiJack.PHookContext): longbool; stdcall;
const
  SPEC_UPGRADES = 6;
  SPEC_DRAGONS  = 7;

var
  NumParams:   integer;
  Hero:        Heroes.PHero;
  SubCmd:      PErmSubCmd;
  SpecRecord:  PHeroSpecRecord;
  i:           integer;

begin
  // OK result
  Context.RetAddr := Ptr($74943B);
  NumParams       := pinteger(Context.EBP - $10)^;
  Hero            := ppointer(Context.EBP - $380)^;
  SubCmd          := pointer(Context.EBP - $300);
  SpecRecord      := @HeroSpecsTable[Hero.Id];
  result          := false;

  if (NumParams < 7) and (SubCmd.Params[0].GetCheckType() = PARAM_CHECK_NONE) and (SubCmd.Modifiers[0] = PARAM_MODIFIER_NONE) and
    ((SubCmd.Nums[0] = SPEC_UPGRADES) or (SubCmd.Nums[0] = SPEC_DRAGONS))
  then begin
    if NumParams < 2 then begin
      ShowErmError('HE:X wrong number of parameters');
      result := true;
    end else begin
      SpecRecord.Setup[0] := SubCmd.Nums[0];

      if SubCmd.Nums[0] = SPEC_UPGRADES then begin
        ZvsApply(@SpecRecord.Setup[1], sizeof(SpecRecord.Setup[1]), SubCmd, 1);
        ZvsApply(@SpecRecord.Setup[5], sizeof(SpecRecord.Setup[5]), SubCmd, 2);
        ZvsApply(@SpecRecord.Setup[6], sizeof(SpecRecord.Setup[6]), SubCmd, 3);
      end else if SubCmd.Nums[0] = SPEC_DRAGONS then begin
        ZvsApply(@SpecRecord.Setup[2], sizeof(SpecRecord.Setup[2]), SubCmd, 1);
        ZvsApply(@SpecRecord.Setup[3], sizeof(SpecRecord.Setup[3]), SubCmd, 2);
      end;
    end;
  end else begin
    for i := 0 to Math.Min(NumParams, Length(SpecRecord.Setup)) - 1 do begin
      ZvsApply(@SpecRecord.Setup[i], sizeof(SpecRecord.Setup[i]), SubCmd, i);
    end;
  end; // .else

  if result then begin
    Context.RetAddr := Ptr($7496D9);
  end;
end; // .function Hook_HE_X

function Hook_HE_Z (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd: PErmSubCmd;
  Hero:   Heroes.PHero;

begin
  result := pbyte(Context.EBP - $31D)^ <> ord('Z');

  if not result then begin
    SubCmd          := pointer(Context.EBP - $300);
    Hero            := ppointer(Context.EBP - $380)^;
    ZvsApply(@Hero, sizeof(Hero), SubCmd, 0);
    Context.RetAddr := Ptr($74943B);
  end;
end; // .function Hook_HE_Z

function Hook_BM_Z (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd:      PErmSubCmd;
  BattleStack: pointer;

begin
  result := (pinteger(Context.EBP - $44)^ + $41) <> ord('Z');

  if not result then begin
    SubCmd      := ppointer(Context.EBP + $14)^;
    BattleStack := ppointer(Context.EBP - $10)^;
    ZvsApply(@BattleStack, sizeof(BattleStack), SubCmd, 0);
    Context.RetAddr := Ptr($75F85D);
  end;
end; // .function Hook_BM_Z

function Hook_UN_C (Context: ApiJack.PHookContext): longbool; stdcall;
var
  NumParams:     integer;
  SubCmd:        PErmSubCmd;
  Addr:          integer;
  Offset:        integer;
  Size:          integer;
  ValueParamInd: integer;
  i:             integer;

begin
  result      := false;
  NumParams   := pinteger(Context.EBP + $0C)^;
  SubCmd      := ppointer(Context.EBP + $14)^;
  Context.EAX := ord(NumParams >= 3);

  if Context.EAX = 0 then begin
    ShowErmError('!!UN:C - insufficient parameters');
  end else begin
    for i := 0 to Math.Min(4, NumParams - 2) do begin
      if SubCmd.Params[i].GetCheckType() <> PARAM_CHECK_NONE then begin
        Context.EAX := 0;
        ShowErmError('!!UN:C - GET-syntax is not supported for any parameters, except the last one');
        break;
      end;
    end;
  end;

  Addr          := SubCmd.Nums[0];
  Size          := SubCmd.Nums[1];
  Offset        := 0;
  ValueParamInd := 2;

  if Context.EAX <> 0 then begin
    if NumParams >= 4 then begin
      Offset        := SubCmd.Nums[1];
      Size          := SubCmd.Nums[2];
      ValueParamInd := 3;
    end;

    Context.EAX := ord((Size = 4) or (Size = 1) or (Size = 2));

    if Context.EAX = 0 then begin
      ShowErmError('!!UN:C - wrong Size parameter: ' + SysUtils.IntToStr(Size));
    end;
  end; // .if

  if Context.EAX <> 0 then begin
    ZvsApply(Utils.PtrOfs(GameExt.GetRealAddr(Ptr(Addr)), Offset), Size, SubCmd, ValueParamInd);
    Context.RetAddr := Ptr($733F4D);
  end else begin
    Context.RetAddr := Ptr($733F57);
  end;
end; // .function Hook_UN_C

function Hook_DlgCallback (Context: Core.PHookContext): longbool; stdcall;
const
  NO_CMD = 0;

begin
  ErmDlgCmd^ := NO_CMD;
  result     := Core.EXEC_DEF_CODE;
end;

function Hook_CM3 (Context: Core.PHookContext): longbool; stdcall;
const
  MOUSE_STRUCT_ITEM_OFS = +$8;
  CM3_RES_ADDR          = $A6929C;

var
  SwapManager: integer;
  MouseStruct: integer;

begin
  SwapManager := Context.EBX;
  MouseStruct := Context.EDI;

  asm
    PUSHAD
    PUSH SwapManager
    POP [$27F954C]
    PUSH MouseStruct
    POP [$2773860]
    MOV EAX, $74FB3C
    CALL EAX
    POPAD
  end; // .asm

  pinteger(Context.EDI + MOUSE_STRUCT_ITEM_OFS)^ := pinteger(CM3_RES_ADDR)^;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_CM3

function Hook_MR_N (c: Core.PHookContext): longbool; stdcall;
begin
  c.eax     := Heroes.GetVal(MrMonPtr^, STACK_SIDE).v * Heroes.NUM_BATTLE_STACKS_PER_SIDE + Heroes.GetVal(MrMonPtr^, STACK_IND).v;
  c.RetAddr := Ptr($75DC76);
  result    := not Core.EXEC_DEF_CODE;
end;

function Hook_BM_U6 (Context: Core.PHookContext): longbool; stdcall;
var
  FinalSpeed: integer;

begin
  result := pinteger(Context.EBP - $48)^ <> 5;

  if not result then begin
    FinalSpeed      := PatchApi.Call(THISCALL_, Ptr($4489F0), [pinteger(Context.EBP - $10)^]);
    ZvsApply(@FinalSpeed, sizeof(integer), PErmSubCmd(pinteger(Context.EBP + $14)^), 1);
    Context.RetAddr := Ptr($75F2D1);
  end;
end;

function Hook_IF_M (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd: PErmSubCmd;

begin
  // OK result
  Context.RetAddr := Ptr($74943B);
  SubCmd          := pointer(Context.EBP - $300);
  result          := false;

  ZvsShowMessage(GetInterpolatedZVarAddr(SubCmd.Nums[0]), ord(Heroes.MES_MES));
end; // .function Hook_IF_M

function Hook_IF_N (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd: PErmSubCmd;

begin
  Context.RetAddr := Ptr($74914C);
  SubCmd          := pointer(Context.EBP - $300);
  result          := false;
  
  // txt = @z
  ppointer(Context.EBP - $520)^ := GetInterpolatedZVarAddr(SubCmd.Nums[0]);
end; // .function Hook_IF_N

function Hook_BA_B (Context: ApiJack.PHookContext): longbool; stdcall;
const
  BATTLEFIELD_ID_PTR            = $7A04E4;
  BATTLEFIELD_PIC_NAME_PTR      = $2846908;
  BATTLEFIELD_PIC_NAME_BUF_SIZE = 256;

var
  NumParams:  integer;
  SubCmd:     PErmSubCmd;
  Param:      PErmCmdParam;
  ParamValue: integer;

begin
  result      := false;
  NumParams   := pinteger(Context.EBP + $0C)^;
  SubCmd      := ppointer(Context.EBP + $14)^;
  Context.EAX := ord(NumParams = 1);

  if Context.EAX = 0 then begin
    ShowErmError('!!BA:B - wrong number of parameters');
  end else begin
    Param      := @SubCmd.Params[0];
    ParamValue := SubCmd.Nums[0];

    if Param.GetType() in PARAM_VARTYPES_INTS then begin
      Context.EAX := ord((ParamValue >= -1) and (ParamValue <= 25));

      if Context.EAX <> 0 then begin
        pinteger(BATTLEFIELD_ID_PTR)^ := ParamValue;
      end else begin
        ShowErmError('!!BA:B - battlefield ID must be in -1..25 range. Given: ' + SysUtils.IntToStr(ParamValue));
      end;
    end else if Param.GetType() in PARAM_VARTYPES_STRINGS then begin
      pinteger(BATTLEFIELD_ID_PTR)^ := 0;
      Utils.SetPcharValue(pchar(BATTLEFIELD_PIC_NAME_PTR), GetInterpolatedZVarAddr(ParamValue), BATTLEFIELD_PIC_NAME_BUF_SIZE);
    end else begin
      Context.EAX := 0;
      ShowErmError('!!BA:B - invalid parameter type. Expected integer or string. Got: ' + ErmParamToCode(Param));
    end;
  end; // .else

  Context.RetAddr := Ptr($762595);

  if Context.EAX = 0 then begin
    Context.RetAddr := Ptr($76259F);
  end;
end; // .function Hook_BA_B

function Hook_MM_M (Context: ApiJack.PHookContext): longbool; stdcall;
const
  HINT_BUF = $697428;

var
  NumParams: integer;
  SubCmd:    PErmSubCmd;
  Param:     PErmCmdParam;
  ZVarInd:   integer;

begin
  result      := false;
  NumParams   := pinteger(Context.EBP + $0C)^;
  SubCmd      := ppointer(Context.EBP + $14)^;
  Param       := @SubCmd.Params[0];
  ZVarInd     := SubCmd.Nums[0];
  Context.EAX := ord(NumParams = 1);

  if Context.EAX = 0 then begin
    ShowErmError('!!MM:M - insufficient parameters');
  end else begin
    Context.EAX := ord(Param.GetType() in PARAM_VARTYPES_STRINGS);

    if Context.EAX = 0 then begin
      ShowErmError('!!MM:M - the parameter must be string. Given: ' + ErmParamToCode(Param));
    end else begin
      Context.EAX := ord((Param.GetCheckType() <> PARAM_CHECK_GET) or IsMutableZVarIndex(ZVarInd));

      if Context.EAX = 0 then begin
        ShowErmError('!!MM:M - string variable must be mutable for GET syntax. Given: ' + ErmParamToCode(Param));
      end else if Param.GetCheckType() = PARAM_CHECK_GET then begin
        Context.EAX := ord(SetErmParamValue(Param, HINT_BUF, FLAG_ASSIGNABLE_STRINGS));
      end else begin
        Utils.SetPcharValue(pchar(HINT_BUF), GetZVarAddr(ZVarInd), sizeof(z[1]));
      end;
    end;
  end; // .else

  if Context.EAX <> 0 then begin
    Context.RetAddr := Ptr($75008C);
  end else begin
    Context.RetAddr := Ptr($75008C);
  end;
end; // .function Hook_MM_M

function Hook_DL_A (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd: PErmSubCmd;
  Param:  PErmCmdParam;

begin
  result := false;
  SubCmd := ppointer(Context.EBP + $14)^;
  Param  := @SubCmd.Params[2];

  if Param.GetType() in PARAM_VARTYPES_STRINGS then begin
    ppointer(Context.EBP - $2C)^ := GetInterpolatedZVarAddr(SubCmd.Nums[2]);
    Context.RetAddr := Ptr($72B14A);
  end else begin
    Context.RetAddr := Ptr($72B144);
  end;
end; // .function Hook_DL_A

(* Rounds given value to one of the following directions: -1 for floor, 1 for ceil, 0 for away from zero *)
function RoundFloat32 (Value: single; Direction: integer): integer;
begin
  if Direction = 0 then begin
    result := Trunc(System.Int(Value) + System.Int(Frac(Value) * 2));
  end else if Direction < 0 then begin
    result := Floor(Value);
  end else begin
    result := Ceil(Value);
  end;
end;

function VR_S (NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:       PErmCmdParam;
  VarParamType:   integer;
  ValueParam:     PErmCmdParam;
  ValueParamType: integer;
  Value:          Heroes.TValue;
  SecondValue:    Heroes.TValue;
  ValType:        integer;
  UseRounding:    longbool;

begin
  result         := 1;
  VarParam       := @ErmCmd.Params[0];
  VarParamType   := VarParam.GetType();
  ValueParam     := @SubCmd.Params[0];
  ValueParamType := ValueParam.GetType();
  UseRounding    := NumParams >= 2;

  if ValueParam.GetCheckType() <> PARAM_CHECK_NONE then begin
    ShowErmError('"!!VR:S" - only SET syntax is supported');
    result := 0; exit;
  end;

  if VarParamType in PARAM_VARTYPES_INTS then begin
    // VR(i32):S(i32)
    if ValueParamType in PARAM_VARTYPES_INTS then begin
      if SubCmd.Modifiers[0] = PARAM_MODIFIER_NONE then begin
        result := ord(SetErmParamValue(VarParam, SubCmd.Nums[0]));
      end else begin
        Value.v := GetErmParamValue(VarParam, ValType);
        PutVal(@Value, sizeof(Value), SubCmd.Nums[0], SubCmd.Modifiers[0]);
        result := ord(SetErmParamValue(VarParam, Value.v));
      end;
    end
    // VR(i32):S(f32) or VR(i32):S(f32)/(rounding direction)
    else if ValueParamType in PARAM_VARTYPES_FLOATS then begin
      Value.f       := GetErmParamValue(VarParam, ValType);
      SecondValue.v := SubCmd.Nums[0];
      Value.f       := ApplyFloatModifier(Value.f, SecondValue.f, SubCmd.Modifiers[0]);

      if UseRounding then begin
        Math.SetRoundMode(rmUp);
        Value.v := RoundFloat32(Value.f, SubCmd.Nums[1]);
      end else begin
        Value.v := trunc(Value.f);
      end;

      result := ord(SetErmParamValue(VarParam, Value.v));
    end
    // VR(i32):S(wrong types)
    else begin
      ShowErmError('"!!VR:S" - cannot set integer variable to non-numeric value');
      result := 0; exit;
    end; // .else
  end
  else if VarParamType in PARAM_VARTYPES_FLOATS then begin
    // VR(n32):S(n32)
    if ValueParamType in PARAM_VARTYPES_NUMERIC then begin
      Value.v       := GetErmParamValue(VarParam, ValType);
      SecondValue.v := SubCmd.Nums[0];

      if ValueParamType <> PARAM_VARTYPE_E then begin
        SecondValue.f := SecondValue.v;
      end;

      Value.f := ApplyFloatModifier(Value.f, SecondValue.f, SubCmd.Modifiers[0]);

      result := ord(SetErmParamValue(VarParam, Value.v));
    end
    // VR(f32):S(wrong types)
    else begin
      ShowErmError('"!!VR:S" - cannot set float variable to non-numeric value');
      result := 0; exit;
    end; // .else
  // VarParamType IN PARAM_VARTYPES_STRINGS
  end else begin
    // VR(str):S(str)
    if ValueParamType in PARAM_VARTYPES_STRINGS then begin
      result := ord(SetErmParamValue(VarParam, integer(GetInterpolatedZVarAddr(SubCmd.Nums[0])), FLAG_ASSIGNABLE_STRINGS));
    end else begin
      ShowErmError('"!!VR:S" - cannot set string variable to non-string value');
      result := 0; exit;
    end; // .else
  end; // .else
end; // .function VR_S

function VR_Arithmetic (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:       PErmCmdParam;
  VarParamType:   integer;
  ValueParam:     PErmCmdParam;
  ValueParamType: integer;
  Value:          Heroes.TValue;
  SecondValue:    Heroes.TValue;
  TempValue:      Heroes.TValue;
  ValType:        integer;
  ResIsInt:       longbool;
  SecondIsInt:    longbool;
  ArgsAreFloat:   longbool;
  FirstStrLen:    integer;
  SecondStrLen:   integer;
  ResultStrLen:   integer;

begin
  result         := 1;
  VarParam       := @ErmCmd.Params[0];
  VarParamType   := VarParam.GetType();
  ValueParam     := @SubCmd.Params[0];
  ValueParamType := ValueParam.GetType();
  ResIsInt       := VarParamType    in PARAM_VARTYPES_INTS;
  SecondIsInt    := ValueParamType in PARAM_VARTYPES_INTS;
  ArgsAreFloat   := not ResIsInt or not SecondIsInt;
  Value.v        := GetErmParamValue(VarParam, ValType);
  SecondValue.v  := SubCmd.Nums[0];

  // Handle string concatenations
  if (Cmd = '+') and (VarParamType in PARAM_VARTYPES_STRINGS) then begin
    if not ValueParamType in PARAM_VARTYPES_STRINGS then begin
      ShowErmError('"!!VR" - cannot perform string concatenations with non-string values');
      result := 0; exit;
    end;

    SecondValue.pc := GetInterpolatedZVarAddr(SecondValue.v);

    if VarParamType = PARAM_VARTYPE_Z then begin
      if not IsMutableZVarIndex(Value.v) then begin
        ShowErmError(Format('"!!VR" - cannot modify read-only z-variable with index: %d', [Value.v]));
        result := 0; exit;
      end;

      Value.pc := GetZVarAddr(Value.v);
      StrLib.Concat(Value.pc, sizeof(z^[1]), Value.pc, -1, SecondValue.pc, -1);
    end else begin
      Value.pc     := GetZVarAddr(Value.v);
      FirstStrLen  := Windows.LStrLen(Value.pc);
      SecondStrLen := Windows.LStrLen(SecondValue.pc);
      ResultStrLen := FirstStrLen + SecondStrLen;
      ServiceMemAllocator.AllocPage;
      TempValue.pc := ServiceMemAllocator.AllocStr(ResultStrLen);
      StrLib.Concat(TempValue.pc, ResultStrLen + 1, Value.pc, FirstStrLen, SecondValue.pc, SecondStrLen);
      SetErmParamValue(VarParam, TempValue.v, FLAG_ASSIGNABLE_STRINGS);
      ServiceMemAllocator.FreePage;
    end; // .else

    exit;
  end else if not ((VarParamType in PARAM_VARTYPES_NUMERIC) and (ValueParamType in PARAM_VARTYPES_NUMERIC)) then begin
    ShowErmError('"!!VR" - cannot perform arithmetic operations with non-numeric values');
    result := 0; exit;
  end; // .elseif

  // Convert both arguments to float if any of them is float
  if ArgsAreFloat then begin
    if ResIsInt then begin
      Value.f := Value.v
    end else if SecondIsInt then begin
      SecondValue.f := SecondValue.v;
    end;
  end;

  case Cmd of
    '+': begin
      if ArgsAreFloat then begin
        Value.f := Value.f + SecondValue.f;
      end else begin
        Inc(Value.v, SecondValue.v);
      end;
    end;

    '-': begin
      if ArgsAreFloat then begin
        Value.f := Value.f - SecondValue.f;
      end else begin
        Dec(Value.v, SecondValue.v);
      end;
    end;

    '*': begin
      if ArgsAreFloat then begin
        Value.f := Value.f * SecondValue.f;
      end else begin
        Value.v := Value.v * SecondValue.v;
      end;
    end;

    ':', '%': begin
      if (SecondValue.v = 0) or (ArgsAreFloat and (SecondValue.f = 0.0)) then begin
        ShowErmError('"!!VR" - division by zero');
        result := 0; exit;
      end;

      case Cmd of
        ':': begin
          if ArgsAreFloat then begin
            Value.f := Value.f / SecondValue.f;
          end else begin
            Value.v := Value.v div SecondValue.v;
          end;
        end;

        '%': begin
          if ArgsAreFloat then begin
            Value.f := frac(Value.f / SecondValue.f) * SecondValue.f;
          end else begin
            Value.v := Value.v mod SecondValue.v;
          end;
        end;
      end; // .switch Cmd
    end; // case ':', '%'
  else
    ShowErmError('"!!VR" - impossible case in math operation');
    result := 0; exit;
  end; // .switch Cmd

  if ArgsAreFloat then begin
    Value.f := NormalizeErmFloatValue(Value.f);

    if ResIsInt then begin
      Value.v := trunc(Value.f);
    end;
  end;

  result := ord(SetErmParamValue(VarParam, Value.v));
end; // .function VR_Arithmetic

function VR_Bits (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:    PErmCmdParam;
  ValueParam:  PErmCmdParam;
  Value:       Heroes.TValue;
  SecondValue: Heroes.TValue;
  ValType:     integer;

begin
  result     := 1;
  VarParam   := @ErmCmd.Params[0];
  ValueParam := @SubCmd.Params[0];

  if not((VarParam.GetType() in PARAM_VARTYPES_INTS) and (ValueParam.GetType() in PARAM_VARTYPES_INTS)) then begin
    ShowErmError('"!!VR" - bit operations are supported for integers only');
    result := 0; exit;
  end;
  
  Value.v       := GetErmParamValue(VarParam, ValType);
  SecondValue.v := SubCmd.Nums[0];

  case Cmd of
    '&': begin
      Value.v := Value.v and SecondValue.v;
    end;

    '|': begin
      Value.v := Value.v or SecondValue.v;
    end;

    'X': begin
      Value.v := Value.v xor SecondValue.v;
    end;

    '~': begin
      Value.v := Value.v and not SecondValue.v;
    end; // case ':', '%'
  else
    ShowErmError('"!!VR" - impossible case in bit operation');
    result := 0; exit;
  end; // .switch Cmd

  result := ord(SetErmParamValue(VarParam, Value.v));
end; // .function VR_Bits

function VR_V (NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:        PErmCmdParam;
  VarParamType:    integer;
  ValueParam:     PErmCmdParam;
  ValueParamType: integer;
  SecondValue:    Heroes.TValue;

begin
  result         := 1;
  VarParam        := @ErmCmd.Params[0];
  VarParamType    := VarParam.GetType();
  ValueParam     := @SubCmd.Params[0];
  ValueParamType := ValueParam.GetType();

  if not (VarParamType in PARAM_VARTYPES_NUMERIC) then begin
    ShowErmError('"!!VR:V" - target variable type must be number (integer or float)');
    result := 0; exit;
  end;

  if not (ValueParamType in PARAM_VARTYPES_STRINGS) then begin
    ShowErmError('"!!VR:V" - value to convert to number must be of string type');
    result := 0; exit;
  end;

  SecondValue.pc := GetInterpolatedZVarAddr(SubCmd.Nums[0]);

  if VarParamType = PARAM_VARTYPE_E then begin
    SecondValue.f := Heroes.a2f(SecondValue.pc);
  end else begin
    SecondValue.v := Heroes.a2i(SecondValue.pc);
  end;

  result := ord(SetErmParamValue(VarParam, SecondValue.v));
end; // .function VR_V

function VR_C (NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:     PErmCmdParam;
  VarParamType: integer;
  StartInd:     integer;
  DestVar:      pinteger;
  i:            integer;

  (* Returns nil on invalid index/range *)
  function GetVarArrayAddr (VarType, StartInd, NumItems: integer): {n} pinteger;
  var
    EndInd: integer;

  begin
    result := nil;
    EndInd := StartInd + NumItems - 1;

    if VarType = PARAM_VARTYPE_V then begin
      if (StartInd >= Low(v^)) and (EndInd <= High(v^)) then begin
        result := @v[StartInd];
      end;
    end else if VarType = PARAM_VARTYPE_W then begin
      if (StartInd >= Low(w[1])) and (EndInd <= High(w[1])) then begin
        result := @w[ZvsWHero^][StartInd];
      end;
    end else if VarType = PARAM_VARTYPE_X then begin
      if (StartInd >= Low(x^)) and (EndInd <= High(x^)) then begin
        result := @x[StartInd];
      end;
    end else if VarType = PARAM_VARTYPE_Y then begin
      if (StartInd >= Low(y^)) and (EndInd <= High(y^)) then begin
        result := @y[StartInd];
      end else if (-StartInd >= Low(ny^)) and (-EndInd <= High(ny^)) then begin
        result := @ny[-StartInd];
      end;
    end;
  end; // .function GetVarArrayAddr

begin
  result       := 1;
  VarParam     := @ErmCmd.Params[0];
  VarParamType := VarParam.GetType();

  if not (VarParamType in PARAM_VARTYPES_ARRAYISH_INTS) then begin
    ShowErmError('"!!VR:C" - only x, y, v, w variables are supported for mass assignment');
    result := 0; exit;
  end;
  
  StartInd := ZvsGetVarValIndex(VarParam);
  DestVar  := GetVarArrayAddr(VarParamType, StartInd, NumParams);

  if DestVar = nil then begin
    ShowErmError(Format('"!!VR:C" first/last index is out of range: %d..%d', [StartInd, StartInd + NumParams - 1]));
    result := 0; exit;
  end;

  for i := 0 to NumParams - 1 do begin
    if ZvsApply(DestVar, sizeof(DestVar^), SubCmd, i) = -1 then begin
      result := 0; exit;
    end;

    Inc(DestVar);
  end;
end; // .function VR_C

function VR_Z (NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:       PErmCmdParam;
  VarParamType:   integer;
  ValueParam:     PErmCmdParam;
  ValueParamType: integer;
  Value:          Heroes.TValue;

begin
  result         := 1;
  VarParam       := @ErmCmd.Params[0];
  VarParamType   := VarParam.GetType();
  ValueParam     := @SubCmd.Params[0];
  ValueParamType := ValueParam.GetType();
  Value.v        := SubCmd.Nums[0];

  if not (VarParamType in PARAM_VARTYPES_INTS) then begin
    ShowErmError('"!!VR:Z" - base variable must be integer to store trigger local z-variable index');
    result := 0; exit;
  end;

  if not (ValueParamType in PARAM_VARTYPES_STRINGS) then begin
    ShowErmError('"!!VR:Z" - value must be string');
    result := 0; exit;
  end;

  result := ord(SetErmParamValue(VarParam, CreateTriggerLocalErt(GetInterpolatedZVarAddr(Value.v))));
end; // .function VR_Z

function VR_Random (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam: PErmCmdParam;
  ValType:  integer;

begin
  result   := 1;
  VarParam := @ErmCmd.Params[0];

  if not(VarParam.GetType() in PARAM_VARTYPES_INTS) then begin
    ShowErmError('"!!VR" - random functions can operate on integers only');
    result := 0; exit;
  end;

  case Cmd of
    'R': begin
      if NumParams >= 3 then begin
        result := ord(SetErmParamValue(VarParam, Heroes.ZvsRandom(SubCmd.Nums[1], SubCmd.Nums[2])));
      end else if NumParams >= 2 then begin
        Heroes.SRand(SubCmd.Nums[1]);
      end else begin
        result := ord(SetErmParamValue(VarParam, GetErmParamValue(VarParam, ValType) + Heroes.Rand(0, SubCmd.Nums[0])));
      end;
    end;

    'T': begin
      if NumParams >= 3 then begin
        result := ord(SetErmParamValue(VarParam, RandMt.RandomRangeMt(SubCmd.Nums[1], SubCmd.Nums[2])));
      end else if NumParams >= 2 then begin
        RandMt.InitMt(SubCmd.Nums[1]);
      end else begin
        result := ord(SetErmParamValue(VarParam, GetErmParamValue(VarParam, ValType) + RandMt.RandomRangeMt(0, SubCmd.Nums[0])));
      end;
    end;
  else
    ShowErmError('"!!VR" - impossible case in random operation');
    result := 0; exit;
  end; // .switch Cmd
end; // .function VR_Random

function VrGetNthToken ({n} Str: pchar; TokenInd: integer): string;
const
  DELIM_CHARS = [#1..#32, ',', '.'];
  STOP_CHARS  = [#0] + DELIM_CHARS;

var
  CurrTokenInd: integer;
  Start:        pchar;

begin
  result := '';

  if (Str = nil) or (Str^ = #0) or (TokenInd < 0) then begin
    exit;
  end;

  CurrTokenInd := 0;

  while (Str^ <> #0) and (CurrTokenInd < TokenInd) do begin
    while not (Str^ in STOP_CHARS) do begin
      Inc(Str);
    end;

    while Str^ in DELIM_CHARS do begin
      Inc(Str);
    end;

    Inc(CurrTokenInd);
  end;

  if Str^ = #0 then begin
    exit;
  end;

  Start := Str;

  while not (Str^ in STOP_CHARS) do begin
    Inc(Str);
  end;

  SetLength(result, integer(Str) - integer(Start));
  Utils.CopyMem(Length(result), Start, pointer(result));
end; // .function VrGetNthToken

function VR_Strings (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer;
var
  VarParam:    PErmCmdParam;
  ValType:     integer;
  Value:       Heroes.TValue;
  SecondValue: Heroes.TValue;
  i:           integer;
  TempBuf:     array [0..35] of char;

begin
  result   := 1;
  VarParam := @ErmCmd.Params[0];

  if not(VarParam.GetType() in PARAM_VARTYPES_STRINGS) then begin
    ShowErmError('"!!VR" - string functions work only with string variables');
    result := 0; exit;
  end;

  case Cmd of
    'H': begin
      if (SubCmd.Nums[0] < Low(f^)) or (SubCmd.Nums[0] > High(f^)) then begin
        ShowErmError('"!!VR:H" - invalid flag index: ' + SysUtils.IntToStr(SubCmd.Nums[0]));
        result := 0; exit;
      end;

      f[SubCmd.Nums[0]] := not StrLib.IsEmpty(pchar(GetErmParamValue(VarParam, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX)));
      result            := ord(ValType <> VALTYPE_ERROR);
    end;

    'M': begin
      case SubCmd.Nums[0] of
        // M1/z#1/#2/#3; get a substring
        1: begin
          if NumParams < 4 then begin
            ShowErmError('"!!VR:M1" - insufficient parameters');
            result := 0; exit;
          end;
          
          result := ord(SetErmParamValue(VarParam, integer(pchar(StrLib.Substr(GetInterpolatedZVarAddr(SubCmd.Nums[1]), SubCmd.Nums[2], SubCmd.Nums[3]))), FLAG_ASSIGNABLE_STRINGS));
        end;

        // M2/z#1/#2; get nth word
        2: begin
          if NumParams < 3 then begin
            ShowErmError('"!!VR:M2" - insufficient parameters');
            result := 0; exit;
          end;
          
          result := ord(SetErmParamValue(VarParam, integer(pchar(VrGetNthToken(GetInterpolatedZVarAddr(SubCmd.Nums[1]), SubCmd.Nums[2]))), FLAG_ASSIGNABLE_STRINGS));
        end;

        // M3/#1[/#2]; convert integer to string
        3: begin
          if NumParams < 2 then begin
            ShowErmError('"!!VR:M3" - insufficient parameters');
            result := 0; exit;
          end;

          SecondValue.v := 10;

          if NumParams > 2 then begin
            SecondValue.v := Alg.ToRange(SubCmd.Nums[2], 2, 16);
          end;

          ZvsIntToStr(SubCmd.Nums[1], @TempBuf, SecondValue.v);
          result := ord(SetErmParamValue(VarParam, integer(@TempBuf[0]), FLAG_ASSIGNABLE_STRINGS));
        end;

        // M4/$; get string length
        4: begin
          if NumParams < 2 then begin
            ShowErmError('"!!VR:M4" - insufficient parameters');
            result := 0; exit;
          end;

          SecondValue.v := StrLib.StrLen(pchar(GetErmParamValue(VarParam, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX)));
          
          result := ord(SetErmParamValue(@SubCmd.Params[1], SecondValue.v));
        end;

        // M5/$; get the first non-space character position or -1
        5: begin
          if NumParams < 2 then begin
            ShowErmError('"!!VR:M5" - insufficient parameters');
            result := 0; exit;
          end;

          SecondValue.pc := pchar(GetErmParamValue(VarParam, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX));
          i              := 0;

          while SecondValue.pc^ in [#1..#32] do begin
            Inc(SecondValue.pc);
            Inc(i);
          end;

          if SecondValue.pc^ = #0 then begin
            i := -1;
          end;
          
          result := ord(SetErmParamValue(@SubCmd.Params[1], i));
        end;

        // M6/$; get the last non-space character position or -1
        6: begin
          if NumParams < 2 then begin
            ShowErmError('"!!VR:M6" - insufficient parameters');
            result := 0; exit;
          end;

          Value.pc       := pchar(GetErmParamValue(VarParam, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX));
          SecondValue.pc := Value.pc;
          i              := 0;

          while SecondValue.pc^ <> #0 do begin
            if SecondValue.pc^ in [#1..#32] then begin
              Inc(i);
            end else begin
              i := 0;
            end;

            Inc(SecondValue.pc);
          end;
          
          result := ord(SetErmParamValue(@SubCmd.Params[1], SecondValue.v - Value.v - i - 1));
        end;
      end; // .switch M#
    end; // .case 'M'

    'U': begin
      if not (SubCmd.Params[0].GetType() in PARAM_VARTYPES_STRINGS) then begin
        ShowErmError('"!!VR:U" - expected substring, not a number');
        result := 0; exit;
      end;

      Value.pc       := pchar(GetErmParamValue(VarParam, ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX));
      SecondValue.pc := pchar(GetErmParamValue(@SubCmd.Params[0], ValType, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX));
      
      f[1] := System.Pos(SysUtils.Trim(SysUtils.AnsiLowerCase(SecondValue.pc)), SysUtils.Trim(SysUtils.AnsiLowerCase(Value.pc))) <> 0;
    end;
  else
    ShowErmError('"!!VR" - impossible case in string operation');
    result := 0; exit;
  end; // .switch Cmd
end; // .function VR_Strings

function New_VR_Receiver (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: PErmSubCmd): integer; cdecl;
const
  MUTABLE_TYPES = [PARAM_VARTYPE_QUICK, PARAM_VARTYPE_V, PARAM_VARTYPE_W, PARAM_VARTYPE_X, PARAM_VARTYPE_Y, PARAM_VARTYPE_Z, PARAM_VARTYPE_E, PARAM_VARTYPE_I, PARAM_VARTYPE_S];

begin
  if not (ErmCmd.Params[0].GetType() in MUTABLE_TYPES) then begin
    ShowErmError('!!VR parameter does not belong to mutable types');
    result := 0; exit;
  end;

  case Cmd of
    'S':                     result := VR_S(NumParams, ErmCmd, SubCmd);
    '+', '-', '*', ':', '%': result := VR_Arithmetic(Cmd, NumParams, ErmCmd, SubCmd);
    '&', '|', 'X', '~':      result := VR_Bits(Cmd, NumParams, ErmCmd, SubCmd);
    'V':                     result := VR_V(NumParams, ErmCmd, SubCmd);
    'C':                     result := VR_C(NumParams, ErmCmd, SubCmd);
    'Z':                     result := VR_Z(NumParams, ErmCmd, SubCmd);
    'R', 'T':                result := VR_Random(Cmd, NumParams, ErmCmd, SubCmd);
    'H', 'M', 'U':           result := VR_Strings(Cmd, NumParams, ErmCmd, SubCmd);
  else
    ShowErmError('Unknown ERM command !!VR:' + Cmd);
    result := 0;
  end; // .switch Cmd
end; // .function New_VR_Receiver

procedure ApplyFuncByRefRes (SubCmd: PErmSubCmd; NumParams: integer);
var
  i: integer;

begin
  for i := 0 to NumParams - 1 do begin
    if SubCmd.Params[i].GetCheckType() = PARAM_CHECK_GET then begin
      ZvsApply(@RetXVars[i + 1], sizeof(integer), SubCmd, i);
    end;
  end;
end;

function GetParamFuSyntaxFlags (Param: PErmCmdParam; DFlag: boolean): integer; inline;
begin
  result := 1;

  if DFlag then begin
    result := 2;
  end else if Param.GetCheckType() = PARAM_CHECK_GET then begin
    result := 0;
  end;
end;

function Hook_FU_P (Context: ApiJack.PHookContext): longbool; stdcall;
var
  Cmd:       PErmCmd;
  SubCmd:    PErmSubCmd;
  FuncId:    integer;
  NumParams: integer;
  ValType:   integer;
  i:         integer;

begin
  Cmd       := PErmCmd(ppointer(Context.EBP + $10)^);
  SubCmd    := PErmSubCmd(ppointer(Context.EBP + $14)^);
  FuncId    := ZvsGetParamValue(Cmd.Params[0]);
  NumParams := pinteger(Context.EBP + $0C)^;
  // * * * * * //
  FuncArgsGetSyntaxFlagsPassed := 0;

  for i := 0 to NumParams - 1 do begin
    ArgXVars[i + 1]              := GetErmParamValue(@SubCmd.Params[i], ValType);
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (GetParamFuSyntaxFlags(@SubCmd.Params[i], SubCmd.Modifiers[i] <> PARAM_MODIFIER_NONE) shl (i shl 1));
  end;

  for i := NumParams to High(ArgXVars) - 1 do begin
    ArgXVars[i + 1]              := 0;
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (1 shl (i shl 1));
  end;

  NumFuncArgsPassed := NumParams;
  FireErmEvent(FuncId);
  ApplyFuncByRefRes(SubCmd, NumParams);

  Context.RetAddr := Ptr($72D19E);
  result          := false;
end; // .function Hook_FU_P

function OnFuncCalledRemotely (FuncId: integer; Args: Utils.PEndlessIntArr; NumArgs: integer): integer; cdecl;
var
  i: integer;

begin
  for i := 0 to NumArgs - 1 do begin
    ArgXVars[i + 1] := Args[i];
  end;

  for i := NumArgs to High(ArgXVars) - 1 do begin
    ArgXVars[i + 1] := 0;
  end;

  FuncArgsGetSyntaxFlagsPassed := $55555555;
  NumFuncArgsPassed            := NumArgs;
  FireErmEvent(FuncId);

  result := 1;
end;

type
  TLoopContext = record
    EndValue: integer;
    Step:     integer;
  end;

function DO_P_Callback (var Data: TLoopContext): boolean;
begin
  Inc(x[16], Data.Step);

  result := ((Data.Step >= 0) and (x[16] <= Data.EndValue)) or ((Data.Step < 0) and (x[16] >= Data.EndValue));
end;

function DO_P (NumParams: integer; Cmd: PErmCmd; SubCmd: PErmSubCmd): boolean;
var
  FuncId:      integer;
  LoopContext: TLoopContext;
  ValType:     integer;
  i:           integer;

begin
  FuncId               := ZvsGetParamValue(Cmd.Params[0]);
  ArgXVars[16]         := ZvsGetParamValue(Cmd.Params[1]);
  LoopContext.EndValue := ZvsGetParamValue(Cmd.Params[2]);
  LoopContext.Step     := ZvsGetParamValue(Cmd.Params[3]);
  result               := true;

  if NumParams > 15 then begin
    NumParams := 15;
  end;

  FuncArgsGetSyntaxFlagsPassed := 0;

  // Initialize x-paramaters
  for i := 0 to NumParams - 1 do begin
    ArgXVars[i + 1]              := GetErmParamValue(@SubCmd.Params[i], ValType);
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (GetParamFuSyntaxFlags(@SubCmd.Params[i], SubCmd.Modifiers[i] <> PARAM_MODIFIER_NONE) shl (i shl 1));
  end;

  for i := NumParams to High(ArgXVars) - 2 do begin
    ArgXVars[i + 1]              := 0;
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (1 shl (i shl 1));
  end;

  if ((LoopContext.Step >= 0) and (ArgXVars[16] <= LoopContext.EndValue)) or ((LoopContext.Step < 0) and (ArgXVars[16] >= LoopContext.EndValue)) then begin
    // Install trigger loop callback
    TriggerLoopCallback.Handler := @DO_P_Callback;
    TriggerLoopCallback.Data    := @LoopContext;

    NumFuncArgsPassed := NumParams;
    FireErmEvent(FuncId);
  end;

  ApplyFuncByRefRes(SubCmd, NumParams);
end; // .function DO_P

function Hook_DO_P (CmdChar: char; NumParams: integer; Cmd: PErmCmd; SubCmd: PErmSubCmd): integer; cdecl;
begin
  if CmdChar = 'P' then begin
    result := ord(DO_P(NumParams, Cmd, SubCmd));
  end else begin
    ShowErmError('!!DO - wrong command');
    result := 0;
  end;
end;

function Hook_FU_EXT (Context: ApiJack.PHookContext): longbool; stdcall;
var
  CmdChar:   char;
  SubCmd:    PErmSubCmd;
  NumParams: integer;
  Shift:     integer;
  ResValue:  integer;
  i:         integer;

begin
  CmdChar := chr(Context.ECX + $43);
  result  := not (CmdChar in ['A', 'S']);

  if not result then begin
    SubCmd    := PErmSubCmd(ppointer(Context.EBP + $14)^);
    NumParams := pinteger(Context.EBP + $0C)^;
    // * * * * * //
    if CmdChar = 'A' then begin
      if NumParams = 1 then begin
        if SubCmd.Params[0].GetCheckType() <> PARAM_CHECK_GET then begin
          if NumFuncArgsReceived = 0 then begin
            x[1] := SubCmd.Nums[0];
          end;
        end else begin
          ZvsApply(@NumFuncArgsReceived, 4, SubCmd, 0);
        end;
      end else begin
        for i := NumFuncArgsReceived to NumParams - 1 do begin
          x[i + 1] := SubCmd.Nums[i];
        end;
      end; // .else      
    end else if CmdChar = 'S' then begin
      if (NumParams <> 2) or (SubCmd.Params[0].GetCheckType() = PARAM_CHECK_GET) or (SubCmd.Params[1].GetCheckType() <> PARAM_CHECK_GET) or
         not Math.InRange(SubCmd.Nums[0], Low(x^), High(x^))
      then begin
        ShowErmError('Invalid !!FU:S syntax');
        Context.RetAddr := Ptr($72D19A);
        exit;
      end;

      Shift    := (SubCmd.Nums[0] - 1) shl 1;
      ResValue := (FuncArgsGetSyntaxFlagsReceived and (3 shl Shift)) shr Shift;
      ZvsApply(@ResValue, 4, SubCmd, 1);
    end; // .elseif

    Context.RetAddr := Ptr($72D19E);
  end;
end; // .function Hook_FU_EXT

function IntCompareFast (a, b: integer): integer; inline;
begin
  if a > b then begin
    result := +1;
  end else if a < b then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function FloatCompareFast (a, b: single): integer; inline;
begin
  if a > b then begin
    result := +1;
  end else if a < b then begin
    result := -1;
  end else begin
    result := 0;
  end;
end;

function Hook_ZvsCheckFlags (Conds: PErmCmdConditions): longbool; cdecl;
var
  results:    array [COND_AND..COND_OR] of longbool;
  CheckType:  integer;
  ValType1:   integer;
  Value1:     Heroes.TValue;
  ValType2:   integer;
  Value2:     Heroes.TValue;
  IsFloatRes: longbool;
  CmpRes:     integer;
  i, j:       integer;

label
  ContinueOuterLoop, LoopsEnd;

begin
  results[COND_AND] := Conds[COND_AND][0][LEFT_COND].GetType() <> PARAM_VARTYPE_NUM;

  // Fast exit on no condition
  if not results[COND_AND] and (Conds[COND_OR][0][LEFT_COND].GetType() = PARAM_VARTYPE_NUM) then begin
    result := false;
    exit;
  end;

  results[COND_OR] := false;

  for j := COND_AND to COND_OR do begin
    for i := Low(Conds[j]) to High(Conds[j]) do begin
      if Conds[j][i][LEFT_COND].GetType() = PARAM_VARTYPE_NUM then begin
        goto ContinueOuterLoop;
      end;

      Value1.v := GetErmParamValue(@Conds[j][i][LEFT_COND], ValType1, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX);

      if ValType1 = VALTYPE_BOOL then begin
        case Conds[j][i][LEFT_COND].GetCheckType() of
          PARAM_CHECK_EQUAL:     Value1.v := ord(Value1.v <> 0);
          PARAM_CHECK_NOT_EQUAL: Value1.v := ord(Value1.v = 0);
        else
          ShowErmError(Format('Unknown check type for flag: %d', [Conds[j][i][RIGHT_COND].GetCheckType()]));
          result := true; exit;
        end;
      end else begin
        Value2.v := GetErmParamValue(@Conds[j][i][RIGHT_COND], ValType2, FLAG_STR_EVALS_TO_ADDR_NOT_INDEX);
        CmpRes   := 0;

        // Number comparison
        if (ValType1 in [VALTYPE_INT, VALTYPE_FLOAT]) or (ValType2 in [VALTYPE_INT, VALTYPE_FLOAT]) then begin
          IsFloatRes := (ValType1 = VALTYPE_FLOAT) or (ValType2 = VALTYPE_FLOAT);

          // Float result
          if IsFloatRes then begin
            if ValType1 = VALTYPE_INT then begin
              Value1.f := Value1.v;
            end else if ValType1 <> VALTYPE_FLOAT then begin
              ShowErmError('CheckFlags: Cannot compare float variable to non-numeric value');
              result := true; exit;
            end;

            if ValType2 = VALTYPE_INT then begin
              Value2.f := Value2.v;
            end else if ValType2 <> VALTYPE_FLOAT then begin
              ShowErmError('CheckFlags: Cannot compare float variable to non-numeric value');
              result := true; exit;
            end;

            CmpRes := FloatCompareFast(Value1.f, Value2.f);
          // Integer result
          end else begin
            if ValType1 <> VALTYPE_INT then begin
              ShowErmError('CheckFlags: Cannot compare integer variable to non-numeric value');
              result := true; exit;
            end;

            if ValType2 <> VALTYPE_INT then begin
              ShowErmError('CheckFlags: Cannot compare integer variable to non-numeric value');
              result := true; exit;
            end;

            CmpRes := IntCompareFast(Value1.v, Value2.v);
          end; // .else
        // String comparison
        end else if (ValType1 = VALTYPE_STR) and (ValType2 = VALTYPE_STR) then begin
          CmpRes := StrLib.ComparePchars(Value1.pc, Value2.pc);
        // Wrong comparison
        end else begin
          ShowErmError('CheckFlags: Cannot compare values of incompatible types');
          result := true; exit;
        end; // .else

        case Conds[j][i][RIGHT_COND].GetCheckType() of
          PARAM_CHECK_EQUAL:         Value1.longbool := CmpRes = 0;
          PARAM_CHECK_NOT_EQUAL:     Value1.longbool := CmpRes <> 0;
          PARAM_CHECK_GREATER:       Value1.longbool := CmpRes > 0;
          PARAM_CHECK_LOWER:         Value1.longbool := CmpRes < 0;
          PARAM_CHECK_GREATER_EQUAL: Value1.longbool := CmpRes >= 0;
          PARAM_CHECK_LOWER_EQUAL:   Value1.longbool := CmpRes <= 0;
        else
          ShowErmError(Format('Unknown check type: %d', [Conds[j][i][RIGHT_COND].GetCheckType()]));
          result := true; exit;
        end; // .switch
      end; // .else

      if Value1.v = 0 then begin
        if j = COND_AND then begin
          results[COND_AND] := false;
          goto ContinueOuterLoop;
        end;
      end else if j = COND_OR then begin
        results[COND_OR] := true;
        goto LoopsEnd;
      end;
    end; // .for

    ContinueOuterLoop:
  end; // .for

  LoopsEnd:

  result := not (results[0] or results[1]);
end; // .function Hook_ZvsCheckFlags

procedure InitFastIntOptimizationStructs;
begin
  FastIntVarSets[PARAM_VARTYPE_Y].MinInd     := Low(y^);
  FastIntVarSets[PARAM_VARTYPE_Y].MaxInd     := High(y^);
  FastIntVarAddrs[PARAM_VARTYPE_Y]           := Utils.PtrOfs(y, -sizeof(integer));
  FastIntVarSets[PARAM_VARTYPE_X].MinInd     := Low(x^);
  FastIntVarSets[PARAM_VARTYPE_X].MaxInd     := High(x^);
  FastIntVarAddrs[PARAM_VARTYPE_X]           := Utils.PtrOfs(x, -sizeof(integer));
  FastIntVarSets[PARAM_VARTYPE_V].MinInd     := Low(v^);
  FastIntVarSets[PARAM_VARTYPE_V].MaxInd     := High(v^);
  FastIntVarAddrs[PARAM_VARTYPE_V]           := Utils.PtrOfs(v, -sizeof(integer));
  FastIntVarSets[PARAM_VARTYPE_QUICK].MinInd := Low(QuickVars^);
  FastIntVarSets[PARAM_VARTYPE_QUICK].MaxInd := High(QuickVars^);
  FastIntVarAddrs[PARAM_VARTYPE_QUICK]       := Utils.PtrOfs(QuickVars, -sizeof(integer));
end;

procedure DoSaveErtStrings;
begin
  with Stores.NewRider(ERT_STRINGS_SECTION) do begin
    WriteInt(ErtStrings.ItemCount);

    with DataLib.IterateObjDict(ErtStrings) do begin
      while IterNext do begin
        WriteInt(integer(IterKey));
        WritePchar(pchar(IterValue));
      end;
    end;
  end; // .with
end;

procedure DoLoadErtStrings;
var
  Index:  integer;
  StrLen: integer;
  Buf:    pchar;
  i:      integer;

begin
  ZvsStringSet_Clear();

  with Stores.NewRider(ERT_STRINGS_SECTION) do begin
    for i := 0 to ReadInt - 1 do begin
      Index  := ReadInt;
      StrLen := ReadInt;

      if StrLen >= 0 then begin
        Buf := Heroes.MemAllocFunc(StrLen + 1);
        Read(StrLen, pbyte(Buf));
        Buf[StrLen]            := #0;
        ErtStrings[Ptr(Index)] := Buf;
      end;
    end; // .for
  end; // .with
end; // .procedure DoLoadErtStrings

procedure OnSavegameWrite (Event: PEvent); stdcall;
begin
  DoSaveErtStrings;
end;

procedure OnSavegameRead (Event: PEvent); stdcall;
begin
  DoLoadErtStrings;
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  ExtractErm;

  if TrackingOpts.Enabled then begin
    EventTracker.GenerateReport(GameExt.GameDir + '\' + ERM_TRACKING_REPORT_PATH);
  end;
end;

procedure OnBeforeClearErmScripts (Event: GameExt.PEvent); stdcall;
begin
  ResetErmSubCmdCache;
end;

procedure OnBeforeWoG (Event: GameExt.PEvent); stdcall;
const
  NEW_ERM_HEAP_SIZE = 128 * 1000 * 1000;

var
{On} NewErmHeap: pointer;

begin
  (* Remove WoG CM3 trigger *)
  Core.p.WriteDword(Ptr($78C210), $887668);

  (* Extend ERM memory limit to 128 MB *)
  NewErmHeap := Windows.VirtualAlloc(nil, NEW_ERM_HEAP_SIZE, Windows.MEM_RESERVE or Windows.MEM_COMMIT, Windows.PAGE_READWRITE);
  {!} Assert(NewErmHeap <> nil, 'Failed to allocate 128 MB memory block for new ERM heap');
  Core.p.WriteDataPatch(Ptr($73E1DE), ['%d', integer(NewErmHeap)]);
  Core.p.WriteDataPatch(Ptr($73E1E8), ['%d', integer(NEW_ERM_HEAP_SIZE)]);

  (* Register new code control receivers *)
  AdvErm.RegisterErmReceiver('re', nil, AdvErm.CMD_PARAMS_CONFIG_ONE_TO_FIVE_INTS);
  AdvErm.RegisterErmReceiver('br', nil, AdvErm.CMD_PARAMS_CONFIG_NONE);
  AdvErm.RegisterErmReceiver('co', nil, AdvErm.CMD_PARAMS_CONFIG_NONE);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  // Patch WoG FindErm to allow functions with arbitrary positive IDs
  Core.p.WriteDataPatch(Ptr($74A724), ['EB']);

  (* Disable internal map scripts interpretation *)
  Core.ApiHook(@Hook_FindErm_BeforeMainLoop, Core.HOOKTYPE_BRIDGE, Ptr($749BBA));

  (* Free ERM heap on scripts recompilation *)
  Core.ApiHook(@Hook_FindErm_ZeroHeap, Core.HOOKTYPE_BRIDGE, Ptr($7499A2));

  (* Remove default mechanism of loading [mapname].erm *)
  Core.p.WriteDataPatch(Ptr($72CA8A), ['E90102000090909090']);

  (* Never load [mapname].cmd file *)
  Core.p.WriteDataPatch(Ptr($771CA8), ['E9C2070000']);

  (* Replace all points of wog option 5 (Wogify) access with FreezedWogOptionWogify *)
  Core.p.WriteDword(Ptr($705601 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($72CA2F + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749BFE + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749CAF + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749D91 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749E2D + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($749E9D + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($74C6F5 + 2), integer(@FreezedWogOptionWogify));
  Core.p.WriteDword(Ptr($753F07 + 2), integer(@FreezedWogOptionWogify));

  (* Force all maps to be treated as WoG format *)
  // Replace MOV WoG, 0 with MOV WoG, 1
  Core.p.WriteDataPatch(Ptr($704F48 + 6), ['01']);
  Core.p.WriteDataPatch(Ptr($74C6E1 + 6), ['01']);

  (* New way of iterating scripts in FindErm *)
  Core.ApiHook(@Hook_FindErm_AfterMapScripts, Core.HOOKTYPE_BRIDGE, Ptr($749BF5));

  (* Remove LoadERMTXT calls everywhere *)
  Core.p.WriteDataPatch(Ptr($749932 - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($749C24 - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($74C7DD - 2), ['33C09090909090909090']);
  Core.p.WriteDataPatch(Ptr($7518CC - 2), ['33C09090909090909090']);

  (* Remove call to FindErm from _B1.cpp::LoadManager *)
  Core.p.WriteDataPatch(Ptr($7051A2), ['9090909090']);

  (* Remove saving and loading old ERM scripts array *)
  Core.p.WriteDataPatch(Ptr($75139D), ['EB7D909090']);
  Core.p.WriteDataPatch(Ptr($751EED), ['E99C000000']);

  (* InitErm always sets IsWoG to true *)
  Core.p.WriteDataPatch(Ptr($74C6FC), ['9090']);

  (* Reimplement ProcessErm *)
  Core.ApiHook(@ProcessErm, Core.HOOKTYPE_JUMP, Ptr($74C816));

  (* Fix ERM CA:B3 bug *)
  Core.Hook(@Hook_ErmCastleBuilding, Core.HOOKTYPE_JUMP, 7, Ptr($70E8A2));

  (* Fix HE:A art get syntax bug *)
  Core.Hook(@Hook_ErmHeroArt, Core.HOOKTYPE_BRIDGE, 9, Ptr($744B13));

  (* Fix HE:A# - set flag 1 as success *)
  Core.Hook(@Hook_ErmHeroArt_FindFreeSlot, Core.HOOKTYPE_BRIDGE, 10, Ptr($7454B2));
  Core.Hook(@Hook_ErmHeroArt_FoundFreeSlot, Core.HOOKTYPE_BRIDGE, 6, Ptr($7454EC));

  (* Fix HE:A3 artifacts delete - update art number *)
  Core.ApiHook(@Hook_ErmHeroArt_DeleteFromBag, Core.HOOKTYPE_BRIDGE, Ptr($745051));
  Core.ApiHook(@Hook_ErmHeroArt_DeleteFromBag, Core.HOOKTYPE_BRIDGE, Ptr($7452F3));

  (* Fix HE:P accept any d-modifiers, honor passed flags *)
  ApiJack.HookCode(Ptr($743E2D), @Hook_HE_P);

  (* Fix HE:C0 optimized and accept any d-modifiers. Magic -1/-2 constants are not used anymore *)
  ApiJack.HookCode(Ptr($7442AC), @Hook_HE_C);

  (* Rewrite HE:X to accept any d-modifiers *)
  ApiJack.HookCode(Ptr($743F9F), @Hook_HE_X);

  (* New HE:Z command to get hero structure address *)
  ApiJack.HookCode(Ptr($746EE3), @Hook_HE_Z);

  (* New BM:Z command to get address of battle stack structure *)
  ApiJack.HookCode(Ptr($75F840), @Hook_BM_Z);

  (* Extended UN:C implementation with 4 parameters support *)
  ApiJack.HookCode(Ptr($731FF0), @Hook_UN_C);

  (* Fix DL:C close all dialogs bug *)
  Core.Hook(@Hook_DlgCallback, Core.HOOKTYPE_BRIDGE, 6, Ptr($729774));

  (* Fully rewrite VR command *)
  AdvErm.RegisterErmReceiver('VR', @New_VR_Receiver, CMD_PARAMS_CONFIG_SINGLE_INT);

  (* Fix LoadErtFile to handle any relative pathes *)
  Core.Hook(@Hook_LoadErtFile, Core.HOOKTYPE_BRIDGE, 5, Ptr($72C660));

  (* Replace ERT files storage implementation entirely *)
  Core.ApiHook(@Hook_ZvsStringSet_Clear,   Core.HOOKTYPE_JUMP, @ZvsStringSet_Clear);
  Core.ApiHook(@Hook_ZvsStringSet_Add,     Core.HOOKTYPE_JUMP, @ZvsStringSet_Add);
  Core.ApiHook(@Hook_ZvsStringSet_GetText, Core.HOOKTYPE_JUMP, @ZvsStringSet_GetText);
  Core.ApiHook(@Hook_ZvsStringSet_Load,    Core.HOOKTYPE_JUMP, @ZvsStringSet_Load);
  Core.ApiHook(@Hook_ZvsStringSet_Save,    Core.HOOKTYPE_JUMP, @ZvsStringSet_Save);

  (* Disable connection between script number and option state in WoG options *)
  Core.p.WriteDataPatch(Ptr($777E48), ['E9180100009090909090']);

  (* Load all *.ers files without name/count limits *)
  ApiJack.HookCode(Ptr($77938A), @Hook_LoadErsFiles);
  ApiJack.HookCode(Ptr($77846B), @Hook_ApplyErsOptions);


  (* Fix CM3 trigger allowing to handle all clicks *)
  Core.ApiHook(@Hook_CM3, Core.HOOKTYPE_BRIDGE, Ptr($5B0255));
  Core.p.WriteDataPatch(Ptr($5B02DD), ['8B47088D70FF']);

  (* UN:J3 does not reset commanders or load scripts. New: it can be used to reset wog options *)
  // Turned off because of side effects of NPC reset and not displaying wogification message some authors could rely on.
  Core.ApiHook(@Hook_UN_J3_End, Core.HOOKTYPE_BRIDGE, Ptr($733A85));

  (* Add UN:J13 command: Reset Commanders *)
  ApiJack.HookCode(Ptr($733F11), @Hook_UN_J13);

  (* Fix UN:P3 command: reset/enable commanders must disable/enable commander chests *)
  ApiJack.HookCode(Ptr($732EA5), @Hook_UN_P3);

  (* Fix MR:N in !?MR1 !?MR2 *)
  Core.ApiHook(@Hook_MR_N, Core.HOOKTYPE_BRIDGE, Ptr($75DC67));

  (* Add BM:U6/?$ command to get final stack speed, including slow effect *)
  ApiJack.HookCode(Ptr($75F2B1), @Hook_BM_U6);

  (* Fix IF:M# command: allow any string *)
  ApiJack.HookCode(Ptr($74751A), @Hook_IF_M);

  (* Fix ERM bug: IF:N worked with z1 only *)
  Core.p.WriteDataPatch(Ptr($749093), ['B0']);
  Core.p.WriteDataPatch(Ptr($74909C), ['B0']);
  Core.p.WriteDataPatch(Ptr($7490B0), ['B0']);
  Core.p.WriteDataPatch(Ptr($7490B6), ['B0']);
  Core.p.WriteDataPatch(Ptr($7490CD), ['B0']);

  (* Fix IF:N# to support any string *)
  ApiJack.HookCode(Ptr($749116), @Hook_IF_N);

  (* Fix BA:B to allow both numeric field ID and string as the only argument *)
  ApiJack.HookCode(Ptr($76242B), @Hook_BA_B);
  
  (* Fix MM:M to allow all strings *)
  ApiJack.HookCode(Ptr($74FD94), @Hook_MM_M);

  (* Fix DL:A to allow all strings and assume 0 as the forth parameter value *)
  ApiJack.HookCode(Ptr($72B093), @Hook_DL_A);

  (* Detailed ERM error reporting *)
  // Replace simple message with detailed message with location and context
  Core.ApiHook(@Hook_MError,  Core.HOOKTYPE_BRIDGE, Ptr($71236A));
  // Disallow repeated message, display detailed message with location otherwise
  ApiJack.StdSplice(Ptr($73DE8A), @Hook_ErmMess, ApiJack.CONV_CDECL, 1);
  // Disable double reporting of error location in ProcessCmd
  Core.p.WriteDataPatch(Ptr($749421), ['E9BF0200009090']);
  // Track ERM errors location during FindErm
  Core.ApiHook(@Hook_FindErm_SkipUntil2, Core.HOOKTYPE_CALL, Ptr($74A14A));

  (* Implement universal !?FU(OnEveryDay) event, like !?TM-1 occuring every day for every color before other !?TM triggers *)
  ApiJack.StdSplice(Ptr($74DC74), @Hook_RunTimer, ApiJack.CONV_CDECL, 1);

  (* Disable default tracing of last ERM command *)
  Core.p.WriteDataPatch(Ptr($741E34), ['9090909090909090909090']);

  (* Prepare for ERM parsing *)
  ApiJack.HookCode(Ptr($749974), @Hook_FindErm_Start);

  (* Optimize compiled ERM by storing direct address of command handler in command itself *)
  ApiJack.HookCode(Ptr($74C5A7), @Hook_FindErm_SuccessEnd);

  // Rewrite FU:P implementation
  ApiJack.HookCode(Ptr($72CD1A), @Hook_FU_P);

  // Add FU:A/G commands
  ApiJack.HookCode(Ptr($72D181), @Hook_FU_EXT);

  (* Rewrite ZVS Call_Function / remote function call handling *)
  Core.ApiHook(@OnFuncCalledRemotely, Core.HOOKTYPE_JUMP, Ptr($72D1D1));

  // Rewrite DO:P implementation
  Core.ApiHook(@Hook_DO_P, Core.HOOKTYPE_JUMP, Ptr($72D79C));

  // Replace ZvsCheckFlags with own implementation, free from e-variables issues
  Core.ApiHook(@Hook_ZvsCheckFlags, Core.HOOKTYPE_JUMP, @ZvsCheckFlags);

  // Replace GetNum with own implementation, capable to process named global variables
  Core.ApiHook(@Hook_ZvsGetNum, Core.HOOKTYPE_JUMP, @ZvsGetNum);

  // Replace Apply with own implementation, capable to process named global variables
  Core.ApiHook(@Hook_ZvsApply, Core.HOOKTYPE_JUMP, @ZvsApply);

  (* Skip spaces before commands in ProcessCmd and disable XX:Z subcomand at all *)
  Core.p.WriteDataPatch(Ptr($741E5E), ['8B8D04FDFFFF01D18A013C2077044142EBF63C3B7505E989780000899500FDFFFF8995E4FCFFFF909090890D0C0E84008885' +
                                       'E3FCFFFF42899500FDFFFFC6458C018D9500FDFFFF528B45089090909050E8C537C01190908945F0837DF0007D75E9167800' +
                                       '0090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090' +
                                       '9090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090' +
                                       '90909090909090909090909090']);

  (* Ovewrite GetNumAuto call from upper patch with Era filtering method *)
  Core.ApiHook(@CustomGetNumAuto, Core.HOOKTYPE_CALL, Ptr($741EAE));

  (* Set ProcessCmd enter/leave hooks *)
  Core.ApiHook(@Hook_ProcessCmd, Core.HOOKTYPE_BRIDGE, Ptr($741E3F));
  ApiJack.HookCode(Ptr($749702), @Hook_ProcessCmd_End);

  (* Replace ERM interpolation function *)
  Core.ApiHook(@InterpolateErmStr, Core.HOOKTYPE_JUMP, @ZvsInterpolateStr);

  (* Replace ERM2String and ERM2String2 WoG functions *)
  Core.ApiHook(@Hook_ERM2String,  Core.HOOKTYPE_JUMP, Ptr($73DF05));
  Core.ApiHook(@Hook_ERM2String2, Core.HOOKTYPE_JUMP, Ptr($741D32));

  (* Enable ERM tracking and pre-command initialization *)
  with TrackingOpts do begin
    if Enabled then begin
      EventTracker := ErmTracking.TEventTracker.Create(MaxRecords).SetDumpCommands(DumpCommands).SetIgnoreEmptyTriggers(IgnoreEmptyTriggers).SetIgnoreRealTimeTimers(IgnoreRealTimeTimers);
    end;
  end;
end; // .procedure OnAfterWoG

procedure OnAfterStructRelocations (Event: GameExt.PEvent); stdcall;
begin
  ZvsIsGameLoading           := GameExt.GetRealAddr(ZvsIsGameLoading);
  ZvsTriggerIfs              := GameExt.GetRealAddr(ZvsTriggerIfs);
  ZvsTriggerIfsDepth         := GameExt.GetRealAddr(ZvsTriggerIfsDepth);
  ZvsChestsEnabled           := GameExt.GetRealAddr(ZvsChestsEnabled);
  ZvsGmAiFlags               := GameExt.GetRealAddr(ZvsGmAiFlags);
  IsWoG                      := GameExt.GetRealAddr(IsWoG);
  WoGOptions                 := GameExt.GetRealAddr(WoGOptions);
  ErmEnabled                 := GameExt.GetRealAddr(ErmEnabled);
  ErmErrCmdPtr               := GameExt.GetRealAddr(ErmErrCmdPtr);
  ErmDlgCmd                  := GameExt.GetRealAddr(ErmDlgCmd);
  MrMonPtr                   := GameExt.GetRealAddr(MrMonPtr);
  HeroSpecsTable             := GameExt.GetRealAddr(HeroSpecsTable);
  HeroSpecsTableBack         := GameExt.GetRealAddr(HeroSpecsTableBack);
  HeroSpecSettingsTable      := GameExt.GetRealAddr(HeroSpecSettingsTable);
  SecSkillSettingsTable      := GameExt.GetRealAddr(SecSkillSettingsTable);
  SecSkillNamesBack          := GameExt.GetRealAddr(SecSkillNamesBack);
  SecSkillDescsBack          := GameExt.GetRealAddr(SecSkillDescsBack);
  SecSkillTextsBack          := GameExt.GetRealAddr(SecSkillTextsBack);
  MonNamesSettingsTable      := GameExt.GetRealAddr(MonNamesSettingsTable);
  MonNamesSingularTable      := GameExt.GetRealAddr(MonNamesSingularTable);
  MonNamesPluralTable        := GameExt.GetRealAddr(MonNamesPluralTable);
  MonNamesSpecialtyTable     := GameExt.GetRealAddr(MonNamesSpecialtyTable);
  MonNamesSingularTableBack  := GameExt.GetRealAddr(MonNamesSingularTableBack);
  MonNamesPluralTableBack    := GameExt.GetRealAddr(MonNamesPluralTableBack);
  MonNamesSpecialtyTableBack := GameExt.GetRealAddr(MonNamesSpecialtyTableBack);
  ArtNamesSettingsTable      := GameExt.GetRealAddr(ArtNamesSettingsTable);
  ArtInfosBack               := GameExt.GetRealAddr(ArtInfosBack);
  MonNamesTables[0]          := MonNamesSingularTable;
  MonNamesTables[1]          := MonNamesPluralTable;
  MonNamesTables[2]          := MonNamesSpecialtyTable;
  MonNamesTablesBack[0]      := MonNamesSingularTableBack;
  MonNamesTablesBack[1]      := MonNamesPluralTableBack;
  MonNamesTablesBack[2]      := MonNamesSpecialtyTableBack;
end; // .procedure OnAfterStructRelocations

begin
  LoadedErsFiles  := DataLib.NewList(Utils.OWNS_ITEMS);
  ErtStrings      := AssocArrays.NewObjArr(not Utils.OWNS_ITEMS, not Utils.ITEMS_ARE_OBJECTS, Utils.NO_TYPEGUARD, not Utils.ALLOW_NIL);
  ScriptMan       := TScriptMan.Create;
  FuncNames       := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  GlobalConsts    := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  FuncIdToNameMap := DataLib.NewObjDict(Utils.OWNS_ITEMS);

  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := AssocArrays.NewSimpleAssocArr
  (
    Crypto.AnsiCRC32,
    AssocArrays.NO_KEY_PREPROCESS_FUNC
  );
  IsWoG^      := true;
  ScriptNames := Lists.NewSimpleStrList;

  InitFastIntOptimizationStructs;

  EventMan.GetInstance.On('OnSavegameWrite',          OnSavegameWrite);
  EventMan.GetInstance.On('OnSavegameRead',           OnSavegameRead);
  EventMan.GetInstance.On('OnBeforeWoG',              OnBeforeWoG);
  EventMan.GetInstance.On('OnAfterWoG',               OnAfterWoG);
  EventMan.GetInstance.On('$OnEraSaveScripts',        OnEraSaveScripts);
  EventMan.GetInstance.On('$OnEraLoadScripts',        OnEraLoadScripts);
  EventMan.GetInstance.On('OnBeforeClearErmScripts',  OnBeforeClearErmScripts);
  EventMan.GetInstance.On('OnGenerateDebugInfo',      OnGenerateDebugInfo);
  EventMan.GetInstance.On('OnAfterStructRelocations', OnAfterStructRelocations);
end.
