unit Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Math, Windows,
  Utils, Crypto, TextScan, AssocArrays, DataLib, CFiles, Files, Ini, TypeWrappers, ApiJack,
  Lists, StrLib, Alg,
  Core, Heroes, GameExt, Trans, RscLists, EventMan;

type
  (* Import *)
  TAssocArray = AssocArrays.TAssocArray;
  TStrList    = DataLib.TStrList;
  TDict       = DataLib.TDict;
  TString     = TypeWrappers.TString;
  TResource   = RscLists.TResource;

const
  ERM_SCRIPTS_SECTION      = 'Era.ErmScripts';
  FUNC_NAMES_SECTION       = 'Era.FuncNames';
  ERM_SCRIPTS_PATH         = 'Data\s';
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

  (* Normalized ERM parameter value types *)
  VALTYPE_INT   = 0;
  VALTYPE_FLOAT = 1;
  VALTYPE_BOOL  = 2;
  VALTYPE_STR   = 3;

  ERM_CMD_MAX_PARAMS_NUM = 16;
  MIN_ERM_SCRIPT_SIZE    = Length('ZVSE'#13#10);
  LINE_END_MARKER        = #10;

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
  FIRST_ERA_TRIGGER                    = 77001;
  TRIGGER_SAVEGAME_WRITE               = 77001;
  TRIGGER_SAVEGAME_READ                = 77002;
  TRIGGER_KEYPRESS                     = 77003;
  TRIGGER_OPEN_HEROSCREEN              = 77004;
  TRIGGER_CLOSE_HEROSCREEN             = 77005;
  TRIGGER_STACK_OBTAINS_TURN           = 77006;
  TRIGGER_REGENERATE_PHASE             = 77007;
  TRIGGER_AFTER_SAVE_GAME              = 77008;
  TRIGGER_BEFOREHEROINTERACT           = 77010;
  TRIGGER_AFTERHEROINTERACT            = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE         = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT    = 77013;
  TRIGGER_ONCHAT                       = 77014;
  TRIGGER_ONGAMEENTER                  = 77015;
  TRIGGER_ONGAMELEAVE                  = 77016;
  TRIGGER_ONREMOTEEVENT                = 77017;
  TRIGGER_DAILY_TIMER                  = 77018;
  TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE = 77019;
  TRIGGER_BATTLEFIELD_VISIBLE          = 77020;
  TRIGGER_AFTER_TACTICS_PHASE          = 77021;
  TRIGGER_COMBAT_ROUND                 = 77022;
  TRIGGER_OPEN_RECRUIT_DLG             = 77023;
  TRIGGER_CLOSE_RECRUIT_DLG            = 77024;
  TRIGGER_RECRUIT_DLG_MOUSE_CLICK      = 77025;
  TRIGGER_TOWN_HALL_MOUSE_CLICK        = 77026;
  TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK = 77027;
  TRIGGER_RECRUIT_DLG_RECALC           = 77028;
  TRIGGER_RECRUIT_DLG_ACTION           = 77029;
  TRIGGER_LOAD_HERO_SCREEN             = 77030;
  TRIGGER_BUILD_TOWN_BUILDING          = 77031;
  TRIGGER_OPEN_TOWN_SCREEN             = 77032;
  TRIGGER_CLOSE_TOWN_SCREEN            = 77033;
  TRIGGER_SWITCH_TOWN_SCREEN           = 77034;
  TRIGGER_PRE_TOWN_SCREEN              = 77035;
  TRIGGER_POST_TOWN_SCREEN             = 77036;
  TRIGGER_PRE_HEROSCREEN               = 77037;
  TRIGGER_POST_HEROSCREEN              = 77038;
  {!} LAST_ERA_TRIGGER                 = TRIGGER_POST_HEROSCREEN;
  
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
    }
    ValType:  integer;

    function  GetType: integer; inline;
    function  GetIndexedPartType: integer; inline;
    function  GetCheckType: integer; inline;
    procedure SetType (NewType: integer); inline;
    procedure SetIndexedPartType (NewType: integer); inline;
    procedure SetCheckType (NewCheckType: integer); inline;
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
  end; // .record TErmCmd

  PErmSubCmd = ^TErmSubCmd;
  TErmSubCmd = packed record
    Pos:        integer;
    Code:       TErmString;
    Conditions: TErmCmdConditions;
    Params:     TErmCmdParams;
    Chars:      array [0..15] of char;
    DFlags:     array [0..15] of boolean;
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
  TZvsShowMessage   = function (Mes: pchar; MesType: integer; DummyZero: integer): integer; cdecl;
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

  THeroSpecRecord = packed record
    Setup:       array [0..6] of integer;

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

  TFireRemoteEventProc = procedure (EventId: integer; Data: pinteger; NumInts: integer); cdecl;
  TZvsPlaceMapObject   = function (x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain: integer): integer; cdecl;
  TZvsCheckEnabled     = array [0..19] of integer;

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
  ZvsGetCurrDay:      function: integer cdecl = Ptr($7103D2);
  ZvsVnCopy:          procedure ({n} Src, Dst: PErmCmdParam) cdecl = Ptr($73E83B);
  ZvsFindMacro:       function (SubCmd: PErmSubCmd; IsSet: integer): {n} pchar cdecl = Ptr($734072);
  ZvsGetMacro:        function ({n} Macro: pchar): {n} PErmCmdParam cdecl = Ptr($7343E4);
  FireErmEvent:       TFireErmEvent     = Ptr($74CE30);
  ZvsDumpErmVars:     TZvsDumpErmVars   = Ptr($72B8C0);
  ZvsResetCommanders: Utils.TProcedure  = Ptr($770B25);
  ZvsEnableNpc:       procedure (HeroId: integer; AutoHired: integer) cdecl = Ptr($76B541);
  ZvsDisableNpc:      procedure (HeroId: integer) cdecl = Ptr($76B5D6);
  ZvsIsAi:            function (Owner: integer): boolean cdecl = Ptr($711828);
  ZvsGetErtStr:       function (StrInd: integer): pchar cdecl = Ptr($776620);
  ZvsInterpolateStr:  function (Str: pchar): pchar cdecl = Ptr($73D4CD);
  ZvsApply:           function (Dest: pinteger; Size: integer; Cmd: PErmSubCmd; ParamInd: integer): longbool cdecl = Ptr($74195D);
  ZvsGetVarValIndex:  function (Param: PErmCmdParam): integer cdecl = Ptr($72DCB0);
  ZvsGetVarVal:       function (Param: PErmCmdParam): integer cdecl = Ptr($72DEA5);
  ZvsSetVarVal:       function (Param: PErmCmdParam; NewValue: integer): integer cdecl = Ptr($72E301);
  ZvsGetParamValue:   function (var Param: TErmCmdParam): integer cdecl = Ptr($72DEA5);
  ZvsReparseParam:    function (var Param: TErmCmdParam): integer cdecl = Ptr($72D573);

  FireRemoteEventProc: TFireRemoteEventProc = Ptr($76863A);
  ZvsPlaceMapObject:   TZvsPlaceMapObject   = Ptr($71299E);


var
{O} ScriptMan:       TScriptMan;
    ErmTriggerDepth: integer = 0;

    FreezedWogOptionWogify: integer = WOGIFY_ALL;

    MonNamesTables:     array [0..2] of Utils.PEndlessPcharArr;
    MonNamesTablesBack: array [0..2] of Utils.PEndlessPcharArr;

    ErmCmdOptimizer:         procedure (Cmd: PErmCmd) = nil;
    CurrentTriggerCmdIndPtr: pinteger = nil;
    QuitTriggerFlag:         boolean = false;
    TriggerLoopCallback:     TTriggerLoopCallback;

    // Each trigger saves x-vars to RetXVars before restoring previous values on exit.
    // ArgXVars are copied to x on trigger start after saving previous x-values.
    ArgXVars:    TErmXVars;
    RetXVars:    TErmXVars;
    
    // May be set by function caller to signal, how many arguments are initialized
    NumFuncArgsPassed: integer = 0;
    
    // Value, accessable via !!FU:A
    NumFuncArgsReceived: integer = 0;

    // Single flag per each function argument, representing GET-syntax usage by caller
    FuncArgsGetSyntaxFlagsPassed:   integer = 0;
    FuncArgsGetSyntaxFlagsReceived: integer = 0;

  
  (* ERM tracking options *)
  TrackingOpts: record
    Enabled:              boolean;
    MaxRecords:           integer;
    DumpCommands:         boolean;
    IgnoreEmptyTriggers:  boolean;
    IgnoreRealTimeTimers: boolean;
  end;

  ErmLegacySupport: boolean = false;


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

var
{O} FuncNames:       DataLib.TDict {OF FuncId: integer};
{O} FuncIdToNameMap: DataLib.TObjDict {O} {OF TString};
    FuncAutoId:      integer;
{O} ScriptNames:     Lists.TStringList;
{O} ErmScanner:      TextScan.TTextScanner;
{O} ErmCmdCache:     {O} TAssocArray {OF PErmCmd};
{O} EventTracker:    ErmTracking.TEventTracker;
    ErmErrReported:  boolean = false;

    (* Binary tree in array. Fast search for first trigger with given ID *)
    TriggerFastAccessList: PTriggerFastAccessList = nil;
    NullTrigger:           PErmTrigger            = nil;
    NumUniqueTriggers:     integer                = 0;
    CompiledErmOptimized:  boolean                = false;


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

function TErmTrigger.GetSize: integer;
begin
  result := sizeof(Self) + Self.NumCmds * sizeof(TErmCmd);
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
    {*} Erm.TRIGGER_FU1..Erm.TRIGGER_FU29999:
      result := 'OnErmFunction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_FU1 + 1); 
    {*} Erm.TRIGGER_TM1..Erm.TRIGGER_TM100:
      result := 'OnErmTimer ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_TM1 + 1); 
    {*} Erm.TRIGGER_HE0..Erm.TRIGGER_HE198:
      result := 'OnHeroInteraction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HE0);
    {*} Erm.TRIGGER_BA0:      result :=  'OnBeforeBattle';
    {*} Erm.TRIGGER_BA1:      result :=  'OnAfterBattle';
    {*} Erm.TRIGGER_BR:       result :=  'OnBattleRound';
    {*} Erm.TRIGGER_BG0:      result :=  'OnBeforeBattleAction';
    {*} Erm.TRIGGER_BG1:      result :=  'OnAfterBattleAction';
    {*} Erm.TRIGGER_MW0:      result :=  'OnWanderingMonsterReach';
    {*} Erm.TRIGGER_MW1:      result :=  'OnWanderingMonsterDeath';
    {*} Erm.TRIGGER_MR0:      result :=  'OnMagicBasicResistance';
    {*} Erm.TRIGGER_MR1:      result :=  'OnMagicCorrectedResistance';
    {*} Erm.TRIGGER_MR2:      result :=  'OnDwarfMagicResistance';
    {*} Erm.TRIGGER_CM0:      result :=  'OnAdventureMapRightMouseClick';
    {*} Erm.TRIGGER_CM1:      result :=  'OnTownMouseClick';
    {*} Erm.TRIGGER_CM2:      result :=  'OnHeroScreenMouseClick';
    {*} Erm.TRIGGER_CM3:      result :=  'OnHeroesMeetScreenMouseClick';
    {*} Erm.TRIGGER_CM4:      result :=  'OnBattleScreenMouseClick';
    {*} Erm.TRIGGER_CM5:      result :=  'OnAdventureMapLeftMouseClick';
    {*} Erm.TRIGGER_AE0:      result :=  'OnUnequipArt';
    {*} Erm.TRIGGER_AE1:      result :=  'OnEquipArt';
    {*} Erm.TRIGGER_MM0:      result :=  'OnBattleMouseHint';
    {*} Erm.TRIGGER_MM1:      result :=  'OnTownMouseHint';
    {*} Erm.TRIGGER_MP:       result :=  'OnMp3MusicChange';
    {*} Erm.TRIGGER_SN:       result :=  'OnSoundPlay';
    {*} Erm.TRIGGER_MG0:      result :=  'OnBeforeAdventureMagic';
    {*} Erm.TRIGGER_MG1:      result :=  'OnAfterAdventureMagic';
    {*} Erm.TRIGGER_TH0:      result :=  'OnEnterTownHall';
    {*} Erm.TRIGGER_TH1:      result :=  'OnLeaveTownHall';
    {*} Erm.TRIGGER_IP0:      result :=  'OnBeforeBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP1:      result :=  'OnBeforeBattleAfterDataReceived';
    {*} Erm.TRIGGER_IP2:      result :=  'OnAfterBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP3:      result :=  'OnAfterBattleAfterDataReceived';
    {*} Erm.TRIGGER_CO0:      result :=  'OnOpenCommanderWindow';
    {*} Erm.TRIGGER_CO1:      result :=  'OnCloseCommanderWindow';
    {*} Erm.TRIGGER_CO2:      result :=  'OnAfterCommanderBuy';
    {*} Erm.TRIGGER_CO3:      result :=  'OnAfterCommanderResurrect';
    {*} Erm.TRIGGER_BA50:     result :=  'OnBeforeBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA51:     result :=  'OnAfterBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA52:     result :=  'OnBeforeBattleUniversal';
    {*} Erm.TRIGGER_BA53:     result :=  'OnAfterBattleUniversal';
    {*} Erm.TRIGGER_GM0:      result :=  'OnAfterLoadGame';
    {*} Erm.TRIGGER_GM1:      result :=  'OnBeforeSaveGame';
    {*} Erm.TRIGGER_PI:       result :=  'OnAfterErmInstructions';
    {*} Erm.TRIGGER_DL:       result :=  'OnCustomDialogEvent';
    {*} Erm.TRIGGER_HM:       result :=  'OnHeroMove';
    {*} Erm.TRIGGER_HM0..Erm.TRIGGER_HM198:
      result := 'OnHeroMove ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HM0);
    {*} Erm.TRIGGER_HL:   result :=  'OnHeroGainLevel';
    {*} Erm.TRIGGER_HL0..Erm.TRIGGER_HL198:
      result := 'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HL0);
    {*} Erm.TRIGGER_BF:       result :=  'OnSetupBattlefield';
    {*} Erm.TRIGGER_MF1:      result :=  'OnMonsterPhysicalDamage';
    {*} Erm.TRIGGER_TL0:      result :=  'OnEverySecond';
    {*} Erm.TRIGGER_TL1:      result :=  'OnEvery2Seconds';
    {*} Erm.TRIGGER_TL2:      result :=  'OnEvery5Seconds';
    {*} Erm.TRIGGER_TL3:      result :=  'OnEvery10Seconds';
    {*} Erm.TRIGGER_TL4:      result :=  'OnEveryMinute';
    (* Era Triggers *)
    {*} Erm.TRIGGER_SAVEGAME_WRITE:               result := 'OnSavegameWrite';
    {*} Erm.TRIGGER_SAVEGAME_READ:                result := 'OnSavegameRead';
    {*} Erm.TRIGGER_KEYPRESS:                     result := 'OnKeyPressed';
    {*} Erm.TRIGGER_OPEN_HEROSCREEN:              result := 'OnOpenHeroScreen';
    {*} Erm.TRIGGER_CLOSE_HEROSCREEN:             result := 'OnCloseHeroScreen';
    {*} Erm.TRIGGER_STACK_OBTAINS_TURN:           result := 'OnBattleStackObtainsTurn';
    {*} Erm.TRIGGER_REGENERATE_PHASE:             result := 'OnBattleRegeneratePhase';
    {*} Erm.TRIGGER_AFTER_SAVE_GAME:              result := 'OnAfterSaveGame';
    {*} Erm.TRIGGER_BEFOREHEROINTERACT:           result := 'OnBeforeHeroInteraction';
    {*} Erm.TRIGGER_AFTERHEROINTERACT:            result := 'OnAfterHeroInteraction';
    {*} Erm.TRIGGER_ONSTACKTOSTACKDAMAGE:         result := 'OnStackToStackDamage';
    {*} Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT:    result := 'OnAICalcStackAttackEffect';
    {*} Erm.TRIGGER_ONCHAT:                       result := 'OnChat';
    {*} Erm.TRIGGER_ONGAMEENTER:                  result := 'OnGameEnter';
    {*} Erm.TRIGGER_ONGAMELEAVE:                  result := 'OnGameLeave';
    {*} Erm.TRIGGER_ONREMOTEEVENT:                result := 'OnRemoteEvent';
    {*} Erm.TRIGGER_DAILY_TIMER:                  result := 'OnEveryDay';
    {*} Erm.TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE: result := 'OnBeforeBattlefieldVisible';
    {*} Erm.TRIGGER_BATTLEFIELD_VISIBLE:          result := 'OnBattlefieldVisible';
    {*} Erm.TRIGGER_AFTER_TACTICS_PHASE:          result := 'OnAfterTacticsPhase';
    {*} Erm.TRIGGER_COMBAT_ROUND:                 result := 'OnCombatRound';
    {*} Erm.TRIGGER_OPEN_RECRUIT_DLG:             result := 'OnOpenRecruitDlg';
    {*} Erm.TRIGGER_CLOSE_RECRUIT_DLG:            result := 'OnCloseRecruitDlg';
    {*} Erm.TRIGGER_RECRUIT_DLG_MOUSE_CLICK:      result := 'OnRecruitDlgMouseClick';
    {*} Erm.TRIGGER_TOWN_HALL_MOUSE_CLICK:        result := 'OnTownHallMouseClick';
    {*} Erm.TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK: result := 'OnKingdomOverviewMouseClick';
    {*} Erm.TRIGGER_RECRUIT_DLG_RECALC:           result := 'OnRecruitDlgRecalc';
    {*} Erm.TRIGGER_RECRUIT_DLG_ACTION:           result := 'OnRecruitDlgAction';
    {*} Erm.TRIGGER_LOAD_HERO_SCREEN:             result := 'OnLoadHeroScreen';
    {*} Erm.TRIGGER_BUILD_TOWN_BUILDING:          result := 'OnBuildTownBuilding';
    {*} Erm.TRIGGER_OPEN_TOWN_SCREEN:             result := 'OnOpenTownScreen';
    {*} Erm.TRIGGER_CLOSE_TOWN_SCREEN:            result := 'OnCloseTownScreen';
    {*} Erm.TRIGGER_SWITCH_TOWN_SCREEN:           result := 'OnSwitchTownScreen';
    {*} Erm.TRIGGER_PRE_TOWN_SCREEN:              result := 'OnPreTownScreen';
    {*} Erm.TRIGGER_POST_TOWN_SCREEN:             result := 'OnPostTownScreen';
    {*} Erm.TRIGGER_PRE_HEROSCREEN:               result := 'OnPreHeroScreen';
    {*} Erm.TRIGGER_POST_HEROSCREEN:              result := 'OnPostHeroScreen';
    (* END Era Triggers *)
  else
    if EventID >= Erm.TRIGGER_OB_POS then begin
      if ((EventID and Erm.TRIGGER_OB_POS) or (EventID and Erm.TRIGGER_LE_POS)) <> 0 then begin
        x := EventID and 1023;
        y := (EventID shr 16) and 1023;
        z := (EventID shr 26) and 1;
        
        if (EventID and Erm.TRIGGER_LE_POS) <> 0 then begin
          BaseEventName := 'OnLocalEvent ';
        end else begin
          if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
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
        
        if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
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

  ANY_CHAR            = [#0..#255];
  FUNCNAME_CHARS      = ANY_CHAR - [')', #10, #13];
  LABEL_CHARS         = ANY_CHAR - [']', #10, #13];
  SPECIAL_CHARS       = ['[', '!', '$', '@'];
  INCMD_SPECIAL_CHARS = ['[', '(', '^', ';', '$', '@'];
  VAR_END_CHARSET     = ['$', '@', ';', '^', #10, #13, '('];

  SUPPORTED_LOCAL_VAR_TYPES = ['x', 'y', 'v', 'e', 'z'];
  LOCAL_VAR_TYPE_ID_Y = 0;
  LOCAL_VAR_TYPE_ID_X = 1;
  LOCAL_VAR_TYPE_ID_Z = 2;
  LOCAL_VAR_TYPE_ID_E = 3;
  LOCAL_VAR_TYPE_ID_V = 4;

  NO_LABEL = -1;

type
  TScope = (GLOBAL_SCOPE, CMD_SCOPE);

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
{U} LocalVar:           TErmLocalVar;
    LocalVarsPools:     array [LOCAL_VAR_TYPE_ID_Y..LOCAL_VAR_TYPE_ID_V] of TLocalVarsPool;
    UnresolvedLabelInd: integer; // index of last unresolved label or NO_LABEL
    CmdN:               integer; // index of next command
    MarkedPos:          integer;
    IsInStr:            longbool;
    IsErm2:             longbool;
    VarPos:             integer;
    VarName:            string;
    ArrIndex:           integer;
    VarIndex:           integer;
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

  procedure ParseFuncName;
  var
    FuncId:   integer;
    FuncName: string;
    c:        char;

  begin
    FlushMarked;
    Scanner.GotoNextChar;

    if Scanner.ReadToken(FUNCNAME_CHARS, FuncName) and Scanner.GetCurrChar(c) then begin
      if c = ')' then begin
        Scanner.GotoNextChar;
        AllocErmFunc(FuncName, FuncId);
        Buf.Add(IntToStr(FuncId));
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in function name');
        Buf.Add('999999');
      end;
    end else begin
      ShowError(Scanner.Pos, 'Missing closing ")"');
      Buf.Add('999999');
    end; // .else

    MarkPos;
  end; // .procedure ParseFuncName

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

    with LocalVarsPools[LOCAL_VAR_TYPE_ID_V] do begin
      StartIndex := 2;
      Count      := 9;
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
      'v': result := LOCAL_VAR_TYPE_ID_V;
    else
      Assert(false, 'LocalVarCharToId: unknown variable type: ' + c);
      result := 0;
    end;
  end;

  function ParseLocalVar (VarName: pchar; out IsFreeing: boolean; out VarType: char; out VarBaseName: string; out VarIndex: integer): boolean;
  var
    StartPtr: pchar;

  begin
    IsFreeing := VarName^ = '-';

    if IsFreeing then begin
      Inc(VarName);     
    end;

    StartPtr := VarName;
    VarType  := VarName^;

    while not (VarName^ in ['[', #0]) do begin
      Inc(VarName);
    end;

    VarBaseName := StrLib.ExtractFromPchar(StartPtr, integer(VarName) - integer(StartPtr));
    VarIndex    := 0;
    result      := true;

    if VarName^ = '[' then begin
      Inc(VarName);
      StartPtr := VarName;

      while not (VarName^ in [']', #0]) do begin
        Inc(VarName);
      end;

      result := (VarName^ = ']') and SysUtils.TryStrToInt(StrLib.ExtractFromPchar(StartPtr, integer(VarName) - integer(StartPtr)), VarIndex);

      if result then begin
        Inc(VarName);
        result := VarName^ = #0;
      end;

      if not result then begin
        ShowError(VarPos, 'Invalid local ERM array variable subscription');
      end;
    end; // .if
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
      VarsPool := @LocalVarsPools[LocalVarCharToId(VarName[1])];

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

  function GetLocalVar (const VarName: string; out {Un} LocalVar: TErmLocalVar; out ArrIndex: integer): boolean;
  var
    IsFreeing:   boolean;
    VarType:     char;
    BaseVarName: string;

  begin
    result := ParseLocalVar(pointer(VarName), IsFreeing, VarType, BaseVarName, ArrIndex);

    if result then begin
      result := VarType in SUPPORTED_LOCAL_VAR_TYPES;

      if not result then begin
        ShowError(VarPos, 'Unsupported local ERM variable type: ' + VarType);
      end else if IsFreeing then begin
        FreeLocalVar(BaseVarName);
        LocalVar := nil;
      end else begin
        LocalVar := LocalVars[BaseVarName];

        if LocalVar = nil then begin
          result := AllocLocalVar(BaseVarName, VarType, ArrIndex, LocalVar);
        end else begin
          if ArrIndex < 0 then begin
            ArrIndex := LocalVar.Count + ArrIndex;
          end;

          result := (ArrIndex >= 0) and (ArrIndex < LocalVar.Count);
          
          if not result then begin
            ShowError(VarPos, Format('Local ERM array index %d is out of range: 0..%d', [ArrIndex, LocalVar.Count - 1]));
          end;
        end;
      end; // .else
    end; // .if
  end; // .unction GetLocalVar

  procedure HandleLocalVar (c: char);
  begin
    FlushMarked;
    VarPos := Scanner.Pos;
    Scanner.GotoNextChar;

    if Scanner.ReadTokenTillDelim(VAR_END_CHARSET, VarName) then begin
      if Scanner.c <> c then begin
        ShowError(VarPos, 'Expected local variable end delimiter ' + c);
        Buf.Add('___');
      end else if VarName = '' then begin
        Scanner.GotoNextChar;
        Buf.Add(c);
      end else if not GetLocalVar(VarName, LocalVar, ArrIndex) then begin
        Scanner.GotoNextChar;
        Buf.Add('___');
      end else begin
        Scanner.GotoNextChar;
        
        if LocalVar <> nil then begin
          VarIndex := LocalVar.StartIndex + ArrIndex;
          
          if LocalVar.IsNegative then begin
            VarIndex := -VarIndex;
          end;

          if c = '$' then begin
            if IsInStr then begin
              Buf.Add('%' + UpCase(LocalVar.VarType) + IntToStr(VarIndex));
            end else begin
              Buf.Add(LocalVar.VarType + IntToStr(VarIndex));
            end;
          end else begin
            Buf.Add(IntToStr(VarIndex));
          end;
        end;
      end; // .else
    end; // .if

    MarkPos;
  end; // .procedure HandleLocalVar

  procedure ParseCmd;
  var
    c: char;

  begin
    Scanner.GotoNextChar;
    c := ' ';

    while Scanner.FindCharset(INCMD_SPECIAL_CHARS) and Scanner.GetCurrChar(c) and (c <> ';') do begin
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
            ParseFuncName;
          end else begin
            Scanner.GotoNextChar;
          end;          
        end; // .case '('

        '^': begin
          Scanner.GotoNextChar;
          IsInStr := not IsInStr;
        end; // .case '^'

        '$', '@': begin
          if IsErm2 then begin
            HandleLocalVar(c);
          end else begin
            Scanner.GotoNextChar;
          end;
        end;
      end; // .switch c
    end; // .while

    if c = ';' then begin
      Scanner.GotoNextChar;
      Inc(CmdN);
    end;

    IsInStr := false;
  end; // .procedure ParseCmd

begin
  Buf       := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Scanner   := TextScan.TTextScanner.Create;
  Labels    := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  LocalVars := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  LocalVar  := nil;
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
                ParseCmd;
              end;
            end; // .case '!'

            '?': begin
              if IsErm2 then begin
                FinalizeLocalVarsPools;
                InitLocalVarsPools;
              end;

              ResolveLabels;
              Labels.Clear;
              CmdN := -1;
              ParseCmd;
            end; // .case '?'

            '#': begin
              ParseCmd;
            end; // .case '!'
          end; // .switch c
        end; // .if
      end; // .case '!'

      '$', '@': begin
        if IsErm2 then begin
          HandleLocalVar(c);
        end else begin
          Scanner.GotoNextChar;
        end;
      end;

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
  
  Question := Question + #10#10'{~g}' + GrabErmCmdContext(ErrCmd) + '{~}' + #10#10'Save ERM memory dump?';
  
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
  //ShowMessage(Format('Id: %d. ListEndInd = %d', [Id, ListEndInd]));
  
  if ListEndInd = 0 then begin
    exit;
  end;

  Ind := 0;

  while (Ind < ListEndInd) and (TriggerFastAccessList[Ind].Id <> Id) do begin
    //ShowMessage(Format('Compare event %d to %d', [Id, TriggerFastAccessList[Ind].Id]));
    if Id < TriggerFastAccessList[Ind].Id then begin
      Ind := Ind shl 1 + 1;
    end else begin
      Ind := Ind shl 1 + 2;
    end;
  end;

  if Ind < ListEndInd then begin
    //ShowMessage(Format('Found event %d', [Id]));
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
  NameTrigger(Erm.TRIGGER_BA0,  'OnBeforeBattle');
  NameTrigger(Erm.TRIGGER_BA1,  'OnAfterBattle');
  NameTrigger(Erm.TRIGGER_BR,   'OnBattleRound');
  NameTrigger(Erm.TRIGGER_BG0,  'OnBeforeBattleAction');
  NameTrigger(Erm.TRIGGER_BG1,  'OnAfterBattleAction');
  NameTrigger(Erm.TRIGGER_MW0,  'OnWanderingMonsterReach');
  NameTrigger(Erm.TRIGGER_MW1,  'OnWanderingMonsterDeath');
  NameTrigger(Erm.TRIGGER_MR0,  'OnMagicBasicResistance');
  NameTrigger(Erm.TRIGGER_MR1,  'OnMagicCorrectedResistance');
  NameTrigger(Erm.TRIGGER_MR2,  'OnDwarfMagicResistance');
  NameTrigger(Erm.TRIGGER_CM0,  'OnAdventureMapRightMouseClick');
  NameTrigger(Erm.TRIGGER_CM1,  'OnTownMouseClick');
  NameTrigger(Erm.TRIGGER_CM2,  'OnHeroScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM3,  'OnHeroesMeetScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM4,  'OnBattleScreenMouseClick');
  NameTrigger(Erm.TRIGGER_CM5,  'OnAdventureMapLeftMouseClick');
  NameTrigger(Erm.TRIGGER_AE0,  'OnUnequipArt');
  NameTrigger(Erm.TRIGGER_AE1,  'OnEquipArt');
  NameTrigger(Erm.TRIGGER_MM0,  'OnBattleMouseHint');
  NameTrigger(Erm.TRIGGER_MM1,  'OnTownMouseHint');
  NameTrigger(Erm.TRIGGER_MP,   'OnMp3MusicChange');
  NameTrigger(Erm.TRIGGER_SN,   'OnSoundPlay');
  NameTrigger(Erm.TRIGGER_MG0,  'OnBeforeAdventureMagic');
  NameTrigger(Erm.TRIGGER_MG1,  'OnAfterAdventureMagic');
  NameTrigger(Erm.TRIGGER_TH0,  'OnEnterTownHall');
  NameTrigger(Erm.TRIGGER_TH1,  'OnLeaveTownHall');
  NameTrigger(Erm.TRIGGER_IP0,  'OnBeforeBattleBeforeDataSend');
  NameTrigger(Erm.TRIGGER_IP1,  'OnBeforeBattleAfterDataReceived');
  NameTrigger(Erm.TRIGGER_IP2,  'OnAfterBattleBeforeDataSend');
  NameTrigger(Erm.TRIGGER_IP3,  'OnAfterBattleAfterDataReceived');
  NameTrigger(Erm.TRIGGER_CO0,  'OnOpenCommanderWindow');
  NameTrigger(Erm.TRIGGER_CO1,  'OnCloseCommanderWindow');
  NameTrigger(Erm.TRIGGER_CO2,  'OnAfterCommanderBuy');
  NameTrigger(Erm.TRIGGER_CO3,  'OnAfterCommanderResurrect');
  NameTrigger(Erm.TRIGGER_BA50, 'OnBeforeBattleForThisPcDefender');
  NameTrigger(Erm.TRIGGER_BA51, 'OnAfterBattleForThisPcDefender');
  NameTrigger(Erm.TRIGGER_BA52, 'OnBeforeBattleUniversal');
  NameTrigger(Erm.TRIGGER_BA53, 'OnAfterBattleUniversal');
  NameTrigger(Erm.TRIGGER_GM0,  'OnAfterLoadGame');
  NameTrigger(Erm.TRIGGER_GM1,  'OnBeforeSaveGame');
  NameTrigger(Erm.TRIGGER_PI,   'OnAfterErmInstructions');
  NameTrigger(Erm.TRIGGER_DL,   'OnCustomDialogEvent');
  NameTrigger(Erm.TRIGGER_HM,   'OnHeroMove');
  NameTrigger(Erm.TRIGGER_HL,   'OnHeroGainLevel');
  NameTrigger(Erm.TRIGGER_BF,   'OnSetupBattlefield');
  NameTrigger(Erm.TRIGGER_MF1,  'OnMonsterPhysicalDamage');
  NameTrigger(Erm.TRIGGER_TL0,  'OnEverySecond');
  NameTrigger(Erm.TRIGGER_TL1,  'OnEvery2Seconds');
  NameTrigger(Erm.TRIGGER_TL2,  'OnEvery5Seconds');
  NameTrigger(Erm.TRIGGER_TL3,  'OnEvery10Seconds');
  NameTrigger(Erm.TRIGGER_TL4,  'OnEveryMinute');
  NameTrigger(Erm.TRIGGER_SAVEGAME_WRITE,               'OnSavegameWrite');
  NameTrigger(Erm.TRIGGER_SAVEGAME_READ,                'OnSavegameRead');
  NameTrigger(Erm.TRIGGER_KEYPRESS,                     'OnKeyPressed');
  NameTrigger(Erm.TRIGGER_OPEN_HEROSCREEN,              'OnOpenHeroScreen');
  NameTrigger(Erm.TRIGGER_CLOSE_HEROSCREEN,             'OnCloseHeroScreen');
  NameTrigger(Erm.TRIGGER_STACK_OBTAINS_TURN,           'OnBattleStackObtainsTurn');
  NameTrigger(Erm.TRIGGER_REGENERATE_PHASE,             'OnBattleRegeneratePhase');
  NameTrigger(Erm.TRIGGER_AFTER_SAVE_GAME,              'OnAfterSaveGame');
  NameTrigger(Erm.TRIGGER_BEFOREHEROINTERACT,           'OnBeforeHeroInteraction');
  NameTrigger(Erm.TRIGGER_AFTERHEROINTERACT,            'OnAfterHeroInteraction');
  NameTrigger(Erm.TRIGGER_ONSTACKTOSTACKDAMAGE,         'OnStackToStackDamage');
  NameTrigger(Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT,    'OnAICalcStackAttackEffect');
  NameTrigger(Erm.TRIGGER_ONCHAT,                       'OnChat');
  NameTrigger(Erm.TRIGGER_ONGAMEENTER,                  'OnGameEnter');
  NameTrigger(Erm.TRIGGER_ONGAMELEAVE,                  'OnGameLeave');
  NameTrigger(Erm.TRIGGER_ONREMOTEEVENT,                'OnRemoteEvent');
  NameTrigger(Erm.TRIGGER_DAILY_TIMER,                  'OnEveryDay');
  NameTrigger(Erm.TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE, 'OnBeforeBattlefieldVisible');
  NameTrigger(Erm.TRIGGER_BATTLEFIELD_VISIBLE,          'OnBattlefieldVisible');
  NameTrigger(Erm.TRIGGER_AFTER_TACTICS_PHASE,          'OnAfterTacticsPhase');
  NameTrigger(Erm.TRIGGER_COMBAT_ROUND,                 'OnCombatRound');
  NameTrigger(Erm.TRIGGER_OPEN_RECRUIT_DLG,             'OnOpenRecruitDlg');
  NameTrigger(Erm.TRIGGER_CLOSE_RECRUIT_DLG,            'OnCloseRecruitDlg');
  NameTrigger(Erm.TRIGGER_RECRUIT_DLG_MOUSE_CLICK,      'OnRecruitDlgMouseClick');
  NameTrigger(Erm.TRIGGER_TOWN_HALL_MOUSE_CLICK,        'OnTownHallMouseClick');
  NameTrigger(Erm.TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK, 'OnKingdomOverviewMouseClick');
  NameTrigger(Erm.TRIGGER_RECRUIT_DLG_RECALC,           'OnRecruitDlgRecalc');
  NameTrigger(Erm.TRIGGER_RECRUIT_DLG_ACTION,           'OnRecruitDlgAction');
  NameTrigger(Erm.TRIGGER_LOAD_HERO_SCREEN,             'OnLoadHeroScreen');
  NameTrigger(Erm.TRIGGER_BUILD_TOWN_BUILDING,          'OnBuildTownBuilding');
  NameTrigger(Erm.TRIGGER_OPEN_TOWN_SCREEN,             'OnOpenTownScreen');
  NameTrigger(Erm.TRIGGER_CLOSE_TOWN_SCREEN,            'OnCloseTownScreen');
  NameTrigger(Erm.TRIGGER_SWITCH_TOWN_SCREEN,           'OnSwitchTownScreen');
  NameTrigger(Erm.TRIGGER_PRE_TOWN_SCREEN,              'OnPreTownScreen');
  NameTrigger(Erm.TRIGGER_POST_TOWN_SCREEN,             'OnPostTownScreen');
  NameTrigger(Erm.TRIGGER_PRE_HEROSCREEN,               'OnPreHeroScreen');
  NameTrigger(Erm.TRIGGER_POST_HEROSCREEN,              'OnPostHeroScreen');
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

  Erm.FireErmEvent(TriggerId);

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

(* Extract i^...^ or s^...^ variable name. BufPos must point to first name character *)
function ExtractGlobalNamedVarName (BufPos: pchar): string;
var
  StartPos: pchar;

begin
  {!} Assert(BufPos <> nil);
  StartPos := BufPos;

  while not (BufPos^ in ['^', ';', #0]) do begin
    Inc(BufPos);
  end;

  result := StrLib.ExtractFromPchar(StartPos, integer(BufPos) - integer(StartPos));
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
      PARAM_VARTYPE_I:     result := result + 'i^';
    end;
  end;

  if (Types[0] = PARAM_VARTYPE_I) or (Types[1] = PARAM_VARTYPE_I) then begin
    result := result + ExtractGlobalNamedVarName(pchar(Param.Value)) + '^';
  end else if (Types[0] <> PARAM_VARTYPE_QUICK) and (Types[1] <> PARAM_VARTYPE_QUICK) then begin
    result := result + IntToStr(Param.Value);
  end;
end; // .function ErmParamToCode

function GetErmParamValue (Param: PErmCmdParam; out ResValType: integer): integer;
const
  IND_INDEX = 0;
  IND_BASE  = 1;

var
{Un} AssocVarValue: AdvErm.TAssocVar;
     ValTypes:      array [0..1] of integer;
     ValType:       integer;
     i:             integer;

begin
  ValTypes[0] := Param.GetIndexedPartType();
  ValTypes[1] := Param.GetType();
  result      := Param.Value;

  for i := Low(ValTypes) to High(ValTypes) do begin
    ValType := ValTypes[i];

    // If ValType is raw number, it's already stored in result
    if ValType <> PARAM_VARTYPE_NUM then begin
      case ValType of
        PARAM_VARTYPE_FLAG: begin
          if (result < Low(f^)) or (result > High(f^)) then begin
            ShowErmError(Format('Invalid flag index %d. Expected %d..%d', [result, Low(f^), High(f^)]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;
          
          ValType := VALTYPE_BOOL;
          result  := ord(f[result]);
        end;

        PARAM_VARTYPE_QUICK: begin
          if (result < Low(QuickVars^)) or (result > High(QuickVars^)) then begin
            ShowErmError(Format('Invalid quick var %d. Expected %d..%d', [result, Low(QuickVars^), High(QuickVars^)]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;
          
          ValType := VALTYPE_INT;
          result  := QuickVars[result];
        end;

        PARAM_VARTYPE_V: begin
          if (result < Low(v^)) or (result > High(v^)) then begin
            ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [result, Low(v^), High(v^)]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;
          
          ValType := VALTYPE_INT;
          result  := v[result];
        end;

        PARAM_VARTYPE_X: begin
          if (result < Low(x^)) or (result > High(x^)) then begin
            ShowErmError(Format('Invalid x-var index %d. Expected %d..%d', [result, Low(x^), High(x^)]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;
          
          ValType := VALTYPE_INT;
          result  := x[result];
        end;

        PARAM_VARTYPE_Y: begin
          if result in [Low(y^)..High(y^)] then begin
            result := y[result];
          end else if -result in [Low(ny^)..High(ny^)] then begin
            result := ny[-result];
          end else begin
            ShowErmError(Format('Invalid y-var index: %d. Expected -100..-1, 1..100', [result]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;

          ValType := VALTYPE_INT;
        end;

        PARAM_VARTYPE_I: begin
          if result = 0 then begin
            ShowErmError('Impossible case: i-var has null address');
            ResValType := VALTYPE_INT; result := 0; exit;
          end;
          
          ValType       := VALTYPE_INT;
          AssocVarValue := AdvErm.AssocMem[ExtractGlobalNamedVarName(pchar(result))];

          if AssocVarValue = nil then begin
            result := 0;
          end else begin
            result := AssocVarValue.IntValue;
          end;
        end;

        PARAM_VARTYPE_Z: begin
          if (result >= Low(z^)) and (result <= High(z^)) then begin
            result := integer(@z[result]);
          end else if -result in [Low(nz^)..High(nz^)] then begin
            result := integer(@nz[-result]);
          end else if result > High(z^) then begin
            result := integer(ZvsGetErtStr(result));
          end else begin
            ShowErmError(Format('Invalid z-var index: %d. Expected -10..-1, 1+', [result]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;

          ValType := VALTYPE_STR;
        end;

        PARAM_VARTYPE_E: begin
          if result in [Low(e^)..High(e^)] then begin
            result := pinteger(@e[result])^;
          end else if -result in [Low(ne^)..High(ne^)] then begin
            result := pinteger(@ne[-result])^;
          end else begin
            ShowErmError(Format('Invalid e-var index: %d. Expected -100..-1, 1..100', [result]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;

          ValType := VALTYPE_FLOAT;
        end;

        PARAM_VARTYPE_W: begin
          if (result < Low(w^[0])) or (result > High(w^[0])) then begin
            ShowErmError(Format('Invalid v-var index %d. Expected %d..%d', [result, Low(w^[0]), High(w^[0])]));
            ResValType := VALTYPE_INT; result := 0; exit;
          end;

          ValType := VALTYPE_INT;
          result  := w[ZvsWHero^][result];
        end;
      else
        ShowErmError(Format('Unknown variable type: %d', [ValType]));
        ResValType := VALTYPE_INT; result := 0; exit;
      end; // .switch 

      if (ValType <> VALTYPE_INT) and (i = IND_INDEX) then begin
        ShowErmError('Cannot use non-integer variables as indexex for other variables');
        ResValType := VALTYPE_INT; result := 0; exit;
      end;
    end; // .if
  end; // .for

  ResValType := ValType;
end; // .function GetErmParamValue

function Hook_ZvsGetNum (SubCmd: PErmSubCmd; ParamInd: integer; DoEval: integer): longbool; cdecl;
const
  INDEXABLE_PAR_TYPES = ['v', 'y', 'x', 'z', 'e', 'w'];
  INDEXING_PAR_TYPES  = ['v', 'y', 'x', 'w', 'f'..'t'];
  NATIVE_PAR_TYPES    = ['v', 'y', 'x', 'z', 'e', 'w', 'f'..'t'];

var
  StartPtr:      pchar;
  Caret:         pchar;
  CheckType:     integer;
  IsMod:         longbool;
  Param:         PErmCmdParam;
  BaseTypeChar:  char;
  IndexTypeChar: char;
  IsIndexed:     longbool;
  AddCurrDay:    longbool;
  BaseVarType:   integer;
  IndexVarType:  integer;
  ValType:       integer;
  MacroParam:    PErmCmdParam;
  PrevCmdPos:    integer;

label
  Error;

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
    else
      Res    := PARAM_VARTYPE_NUM;
      result := false;
      ShowErmError('ConvertVarTypeCharToId: invalid argument: ' + VarTypeChar);
    end;
  end; // .function ConvertParamTypeCharToId

begin
  StartPtr      := @SubCmd.Code.Value[SubCmd.Pos];
  Caret         := StartPtr;
  CheckType     := PARAM_CHECK_NONE;
  IsMod         := false;
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
      IsMod := true;
      Inc(Caret);
    end;

    '=': begin
      CheckType := PARAM_CHECK_EQUAL;
      Inc(Caret);
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

    Inc(Caret);
  end;

  IndexTypeChar := Caret^;

  if (IndexTypeChar = 'i') and (Caret[1] = '^') then begin
    Inc(Caret, 2);
    IndexVarType := PARAM_VARTYPE_I;
    Param.Value  := integer(Caret);

    while not (Caret^ in ['^', #0]) do begin
      Inc(Caret);
    end;

    if Caret^ <> '^' then begin
      ShowErmError('*GetNum: associative variable name end marker (^) not found');
      goto Error;
    end;

    Inc(Caret);
  end else if IndexTypeChar in ['f'..'t'] then begin
    IndexVarType := PARAM_VARTYPE_QUICK;
    Param.Value  := ord(IndexTypeChar) - ord('f') + Low(Erm.QuickVars^);
    Inc(Caret);
  end else if IndexTypeChar = '$' then begin
    PrevCmdPos := SubCmd.Pos;
    Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));
    MacroParam := ZvsGetMacro(ZvsFindMacro(SubCmd, 0));

    if MacroParam <> nil then begin
      IndexVarType := MacroParam.GetType();
      Param.Value  := MacroParam.Value;
    end;
    
    Caret      := @SubCmd.Code.Value[SubCmd.Pos];
    SubCmd.Pos := PrevCmdPos;
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
  end else begin
    Param.SetType(IndexVarType);
  end;

  Param.SetCheckType(CheckType);
  SubCmd.DFlags[ParamInd] := IsMod;

  while Caret^ in [#1..#32] do begin
    Inc(Caret);
  end;

  if (DoEval <> 0) and (CheckType <> PARAM_CHECK_GET) then begin
    SubCmd.Nums[ParamInd] := GetErmParamValue(Param, ValType);
  end else begin
    SubCmd.Nums[ParamInd] := Param.Value;
  end;

  if AddCurrDay then begin
    Inc(SubCmd.Nums[ParamInd], ZvsGetCurrDay());
  end;

  if FALSE then ShowMessage(Format('Parsed {%s} AS {%s}', [Copy(pchar(@SubCmd.Code.Value[SubCmd.Pos]), 0, 20), ErmParamToCode(Param)]));

  Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));

  if FALSE then ShowMessage(Format('Ended on {%s}', [Copy(pchar(@SubCmd.Code.Value[SubCmd.Pos]), 0, 20)]));

  exit;

Error:
  while not (Caret^ in [';', #0]) do begin
    Inc(Caret);
  end;

  Inc(SubCmd.Pos, integer(Caret) - integer(StartPtr));
end; // .function Hook_ZvsGetNum

function CustomGetNumAuto (CmdId: integer; SubCmd: PErmSubCmd): integer; stdcall;
const
  DO_EVAL = 1;

  CMD_SN = $4E53;
  CMD_MP = $504D;
  CMD_RD = $4452;

begin
  // Skip Era triggers, which are interpreted separately
  if (CmdId = CMD_SN) or (CmdId = CMD_MP) or (CmdId = CMD_RD) then begin
    result := 1;
    exit;
  end;

  result := 0;

  while result < 16 do begin
    SubCmd.Params[result].Value := 0;

    if Hook_ZvsGetNum(SubCmd, result, DO_EVAL) then begin
      result := 0;
      exit;
    end else begin
      Inc(result);

      if SubCmd.Code.Value[SubCmd.Pos] <> '/' then begin
        exit;
      end;

      Inc(SubCmd.Pos);
    end; // .else
  end; // .while
end; // .function CustomGetNumAuto

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

    SavedE := e^;
    SavedX := x^;
    x^     := ArgXVars;

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

    e^       := SavedE;
    RetXVars := x^;
    x^       := SavedX;

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
  StartTrigger := nil;
  Trigger      := nil;
  EventManager := EventMan.GetInstance;
  // * * * * * //
  if not ErmEnabled^ then begin
    exit;
  end;

  TriggerId := CurrErmEventId^;

  Inc(ErmTriggerDepth);
  StartTrigger := FindFirstTrigger(TriggerId);

  LoopCallback                := TriggerLoopCallback;
  TriggerLoopCallback.Handler := nil;

  NumericEventName := 'OnTrigger ' + SysUtils.IntToStr(TriggerId);
  HumanEventName   := Erm.GetTriggerReadableName(TriggerId);
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

    PrevTriggerCmdIndPtr    := CurrentTriggerCmdIndPtr;
    CurrentTriggerCmdIndPtr := @i;

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
              Erm.ErmErrCmdPtr^ := Cmd.CmdHeader.Value;
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
                    LoopVarValue := ZvsGetVarVal(@Cmd.Params[1]);
                    ZvsSetVarVal(FlowOper.LoopVar, LoopVarValue);
                  end else begin
                    LoopVarValue := ZvsGetVarVal(FlowOper.LoopVar);
                  end;

                  if Cmd.NumParams >= 3 then begin
                    FlowOper.Stop := ZvsGetVarVal(@Cmd.Params[2]);
                  end else begin
                    FlowOper.Step := 0;
                  end;

                  if Cmd.NumParams >= 4 then begin
                    FlowOper.Step := ZvsGetVarVal(@Cmd.Params[3]);
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

                  TargetLoopLevel := GetErmParamValue(@Cmd.Params[0], ParamValType);

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

        Trigger := Trigger.Next;
      end; // .while

      TriggersProcessed:

      // Loop handling
      if (@LoopCallback.Handler = nil) or not LoopCallback.Handler(LoopCallback.Data) then begin
        break;
      end;
    end; // .while

    CurrentTriggerCmdIndPtr := PrevTriggerCmdIndPtr;
  end; // .if HasEventHandlers

  AfterTriggers:
  
  Dec(ErmTriggerDepth);

  if HasEventHandlers then begin
    if TrackingOpts.Enabled then begin
      EventTracker.TrackTrigger(ErmTracking.TRACKEDEVENT_END_TRIGGER, TriggerId);
    end;

    RestoreVars;
  end else begin
    RetXVars := ArgXVars;
  end;
end; // .procedure ProcessErm

function Hook_ProcessCmd (Context: Core.PHookContext): longbool; stdcall;
begin
  if TrackingOpts.Enabled then begin
    EventTracker.TrackCmd(PErmCmd(ppointer(Context.EBP + 8)^).CmdHeader.Value);
  end;

  ErmErrReported := false;  
  result         := Core.EXEC_DEF_CODE;
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
  c.eax     := Heroes.GetVal(MrMonPtr^, STACK_SIDE).v * Heroes.NUM_BATTLE_STACKS_PER_SIDE + Heroes.GetVal(MrMonPtr^, STACK_ID).v;
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
  i:         integer;

begin
  Cmd       := PErmCmd(ppointer(Context.EBP + $10)^);
  SubCmd    := PErmSubCmd(ppointer(Context.EBP + $14)^);
  FuncId    := ZvsGetParamValue(Cmd.Params[0]);
  NumParams := pinteger(Context.EBP + $0C)^;
  // * * * * * //
  FuncArgsGetSyntaxFlagsPassed := 0;

  for i := 0 to NumParams - 1 do begin
    ArgXVars[i + 1]              := SubCmd.Nums[i];
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (GetParamFuSyntaxFlags(@SubCmd.Params[i], SubCmd.DFlags[i]) shl (i shl 1));
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
    ArgXVars[i + 1]              := SubCmd.Nums[i];
    FuncArgsGetSyntaxFlagsPassed := FuncArgsGetSyntaxFlagsPassed or (GetParamFuSyntaxFlags(@SubCmd.Params[i], SubCmd.DFlags[i]) shl (i shl 1));
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

begin
  CmdChar := chr(Context.ECX + $43);
  result  := not (CmdChar in ['A', 'S']);

  if not result then begin
    SubCmd    := PErmSubCmd(ppointer(Context.EBP + $14)^);
    NumParams := pinteger(Context.EBP + $0C)^;
    // * * * * * //
    if CmdChar = 'A' then begin
      if (NumParams <> 1) or (SubCmd.Params[0].GetCheckType() <> PARAM_CHECK_GET) then begin
        ShowErmError('Invalid !!FU:A syntax');
        Context.RetAddr := Ptr($72D19A);
        exit;
      end;

      ZvsApply(@NumFuncArgsReceived, 4, SubCmd, 0);
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

function Hook_VR_C (Context: ApiJack.PHookContext): longbool; stdcall;
var
  SubCmd:    PErmSubCmd;
  VarParam:  PErmCmdParam;
  NumParams: integer;
  StartInd:  integer;
  DestVar:   pinteger;
  i:         integer;

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
  result := not (Context.ECX in [3..6]);

  if not result then begin
    SubCmd    := PErmSubCmd(ppointer(Context.EBP + $14)^);
    NumParams := pinteger(Context.EBP + $0C)^;
    VarParam  := PErmCmdParam(ppointer(Context.EBP - $8)^);
    // * * * * * //
    StartInd := ZvsGetVarValIndex(VarParam);
    DestVar  := GetVarArrayAddr(Context.ECX, StartInd, NumParams);

    if DestVar = nil then begin
      ShowErmError(Format('!!VR:C first/last index is out of range: %d..%d', [StartInd, StartInd + NumParams - 1]));
      Context.RetAddr := Ptr($7355FB);
      exit;
    end;

    for i := 0 to NumParams - 1 do begin
      ZvsApply(DestVar, sizeof(DestVar^), SubCmd, i);
      Inc(DestVar);
    end;

    Context.RetAddr := Ptr($735F06);
  end;
end; // .function Hook_VR_C

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
      
      Value1.v := GetErmParamValue(@Conds[j][i][LEFT_COND], ValType1);

      if ValType1 = VALTYPE_BOOL then begin
        case Conds[j][i][LEFT_COND].GetCheckType() of
          PARAM_CHECK_EQUAL:     Value1.v := ord(Value1.v <> 0);
          PARAM_CHECK_NOT_EQUAL: Value1.v := ord(Value1.v = 0);
        else
          ShowErmError(Format('Unknown check type for flag: %d', [Conds[j][i][RIGHT_COND].GetCheckType()]));
          result := true; exit;
        end;
      end else begin
        Value2.v := GetErmParamValue(@Conds[j][i][RIGHT_COND], ValType2);
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

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  ExtractErm;

  if TrackingOpts.Enabled then begin
    EventTracker.GenerateReport(GameExt.GameDir + '\' + ERM_TRACKING_REPORT_PATH);
  end;
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

  (* Disable internal map scripts interpretation *)
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
  
  (* Fix DL:C close all dialogs bug *)
  Core.Hook(@Hook_DlgCallback, Core.HOOKTYPE_BRIDGE, 6, Ptr($729774));
  
  (* Fix LoadErtFile to handle any relative pathes *)
  Core.Hook(@Hook_LoadErtFile, Core.HOOKTYPE_BRIDGE, 5, Ptr($72C660));

  (* Disable connection between script number and option state in WoG options *)
  Core.p.WriteDataPatch(Ptr($777E48), ['E9180100009090909090']);
  
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

  // Allow VR:C command to handle v, x, w and y-variables
  ApiJack.HookCode(Ptr($7355B7), @Hook_VR_C);

  (* Rewrite ZVS Call_Function / remote function call handling *)
  Core.ApiHook(@OnFuncCalledRemotely, Core.HOOKTYPE_JUMP, Ptr($72D1D1));

  // Rewrite DO:P implementation
  Core.ApiHook(@Hook_DO_P, Core.HOOKTYPE_JUMP, Ptr($72D79C));

  // Replace ZvsCheckFlags with own implementation, free from e-variables issues
  Core.ApiHook(@Hook_ZvsCheckFlags, Core.HOOKTYPE_JUMP, @ZvsCheckFlags);

  // Replace GetNum with own implementation, capable to process named global variables
  Core.ApiHook(@Hook_ZvsGetNum, Core.HOOKTYPE_JUMP, @ZvsGetNum);

  (* Skip spaces before commands in ProcessCmd and disable XX:Z subcomand at all *)
  Core.p.WriteDataPatch(Ptr($741E5E), ['8B8D04FDFFFF01D18A013C2077044142EBF63C3B7505E989780000899500FDFFFF8995E4FCFFFF8955FC890D0C0E84008885' +
                                       'E3FCFFFF42899500FDFFFFC6458C018D9500FDFFFF520FB685ECFCFFFF50E8C537C01190908945F0837DF0007575E9167800' +
                                       '0090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090' +
                                       '9090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090' +
                                       '90909090909090909090909090']);

  (* Ovewrite GetNumAuto call from upper patch with Era filtering method *)
  Core.ApiHook(@CustomGetNumAuto, Core.HOOKTYPE_CALL, Ptr($741EAE));

  (* Enable ERM tracking and pre-command initialization *)
  with TrackingOpts do begin
    if Enabled then begin
      EventTracker := ErmTracking.TEventTracker.Create(MaxRecords).SetDumpCommands(DumpCommands).SetIgnoreEmptyTriggers(IgnoreEmptyTriggers).SetIgnoreRealTimeTimers(IgnoreRealTimeTimers);
    end;

    Core.ApiHook(@Hook_ProcessCmd, Core.HOOKTYPE_BRIDGE, Ptr($741E3F));
  end;
end; // .procedure OnAfterWoG

procedure OnAfterStructRelocations (Event: GameExt.PEvent); stdcall;
begin
  ZvsIsGameLoading            := GameExt.GetRealAddr(ZvsIsGameLoading);
  ZvsTriggerIfs               := GameExt.GetRealAddr(ZvsTriggerIfs);
  ZvsTriggerIfsDepth          := GameExt.GetRealAddr(ZvsTriggerIfsDepth);
  ZvsChestsEnabled            := GameExt.GetRealAddr(ZvsChestsEnabled);
  ZvsGmAiFlags                := GameExt.GetRealAddr(ZvsGmAiFlags);
  IsWoG                       := GameExt.GetRealAddr(IsWoG);
  WoGOptions                  := GameExt.GetRealAddr(WoGOptions);
  ErmEnabled                  := GameExt.GetRealAddr(ErmEnabled);
  ErmErrCmdPtr                := GameExt.GetRealAddr(ErmErrCmdPtr);
  ErmDlgCmd                   := GameExt.GetRealAddr(ErmDlgCmd);
  MrMonPtr                    := GameExt.GetRealAddr(MrMonPtr);
  HeroSpecsTable              := GameExt.GetRealAddr(HeroSpecsTable);
  HeroSpecsTableBack          := GameExt.GetRealAddr(HeroSpecsTableBack);
  HeroSpecSettingsTable       := GameExt.GetRealAddr(HeroSpecSettingsTable);
  SecSkillSettingsTable       := GameExt.GetRealAddr(SecSkillSettingsTable);
  SecSkillNamesBack           := GameExt.GetRealAddr(SecSkillNamesBack);
  SecSkillDescsBack           := GameExt.GetRealAddr(SecSkillDescsBack);
  SecSkillTextsBack           := GameExt.GetRealAddr(SecSkillTextsBack);
  MonNamesSettingsTable       := GameExt.GetRealAddr(MonNamesSettingsTable);
  MonNamesSingularTable       := GameExt.GetRealAddr(MonNamesSingularTable);
  MonNamesPluralTable         := GameExt.GetRealAddr(MonNamesPluralTable);
  MonNamesSpecialtyTable      := GameExt.GetRealAddr(MonNamesSpecialtyTable);
  MonNamesSingularTableBack   := GameExt.GetRealAddr(MonNamesSingularTableBack);
  MonNamesPluralTableBack     := GameExt.GetRealAddr(MonNamesPluralTableBack);
  MonNamesSpecialtyTableBack  := GameExt.GetRealAddr(MonNamesSpecialtyTableBack);
  MonNamesTables[0]           := MonNamesSingularTable;
  MonNamesTables[1]           := MonNamesPluralTable;
  MonNamesTables[2]           := MonNamesSpecialtyTable;
  MonNamesTablesBack[0]       := MonNamesSingularTableBack;
  MonNamesTablesBack[1]       := MonNamesPluralTableBack;
  MonNamesTablesBack[2]       := MonNamesSpecialtyTableBack;
end; // .procedure OnAfterStructRelocations

begin
  ScriptMan       := TScriptMan.Create;
  FuncNames       := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  FuncIdToNameMap := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  
  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := AssocArrays.NewSimpleAssocArr
  (
    Crypto.AnsiCRC32,
    AssocArrays.NO_KEY_PREPROCESS_FUNC
  );
  IsWoG^      :=  true;
  ScriptNames :=  Lists.NewSimpleStrList;
  
  EventMan.GetInstance.On('OnBeforeWoG',              OnBeforeWoG);
  EventMan.GetInstance.On('OnAfterWoG',               OnAfterWoG);
  EventMan.GetInstance.On('$OnEraSaveScripts',        OnEraSaveScripts);
  EventMan.GetInstance.On('$OnEraLoadScripts',        OnEraLoadScripts);
  EventMan.GetInstance.On('OnGenerateDebugInfo',      OnGenerateDebugInfo);
  EventMan.GetInstance.On('OnAfterStructRelocations', OnAfterStructRelocations);
end.
