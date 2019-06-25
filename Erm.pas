unit Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, StrUtils, Math,
  Utils, Alg, Crypto, StrLib, Lists, DataLib, AssocArrays, TextScan,
  CFiles, Files, FilesEx, Ini,
  Core, PatchApi, Heroes, GameExt;

const
  ERM_SCRIPTS_SECTION     = 'Era.ErmScripts';
  ERM_SCRIPTS_PATH        = 'Data\s';
  EXTRACTED_SCRIPTS_PATH  = GameExt.DEBUG_DIR + '\Scripts';

  (* Erm command conditions *)
  LEFT_COND   = 0;
  RIGHT_COND  = 1;
  COND_AND    = 0;
  COND_OR     = 1;

  ERM_CMD_MAX_PARAMS_NUM = 16;
  MIN_ERM_SCRIPT_SIZE    = Length('ZVSE'#13#10);
  LINE_END_MARKER        = #10;

  CurrErmEventID: PINTEGER = Ptr($27C1950);

  (* Erm triggers *)
  TRIGGER_FU1       = 0;
  TRIGGER_FU30000   = 29999;
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
  FIRST_ERA_TRIGGER                 = 77000;
  TRIGGER_BEFORE_SAVE_GAME          = 77000;  // DEPRECATED;
  TRIGGER_SAVEGAME_WRITE            = 77001;
  TRIGGER_SAVEGAME_READ             = 77002;
  TRIGGER_KEYPRESS                  = 77003;
  TRIGGER_OPEN_HEROSCREEN           = 77004;
  TRIGGER_CLOSE_HEROSCREEN          = 77005;
  TRIGGER_STACK_OBTAINS_TURN        = 77006;
  TRIGGER_REGENERATE_PHASE          = 77007;
  TRIGGER_AFTER_SAVE_GAME           = 77008;
  TRIGGER_SKEY_SAVEDIALOG           = 77009;  // DEPRECATED;
  TRIGGER_HEROESMEET                = 77010;  // DEPRECATED;
  TRIGGER_BEFOREHEROINTERACT        = 77010;
  TRIGGER_AFTERHEROINTERACT         = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE      = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT = 77013;
  TRIGGER_ONCHAT                    = 77014;
  TRIGGER_ONGAMEENTER               = 77015;
  TRIGGER_ONGAMELEAVE               = 77016;
  {!} LAST_ERA_TRIGGER              = TRIGGER_ONGAMELEAVE;
  
  ZvsProcessErm: Utils.TProcedure = Ptr($74C816);

  (* WoG Options *)
  NUM_WOG_OPTIONS           = 1000;
  CURRENT_WOG_OPTIONS       = 0;
  GLOBAL_WOG_OPTIONS        = 1;
  WOG_OPTION_ERROR          = 905;
  WOG_OPTION_DISABLE_ERRORS = 904;
  DONT_WOGIFY               = 0;
  WOGIFY_ALL                = 2;
  
  (*  Msg result  *)
  MSG_RES_OK        = 0;
  MSG_RES_CANCEL    = 2;
  MSG_RES_LEFTPIC   = 0;
  MSG_RES_RIGHTPIC  = 1;
  
  (*  Dialog Pictures Types and Subtypes  *)
  NO_PIC_TYPE = -1;


type
  (* IMPORT *)
  TAssocArray = AssocArrays.TAssocArray;
  TList       = DataLib.TList;
  TStrList    = DataLib.TStrList;
  TObjDict    = DataLib.TObjDict;

  TErmValType   = (ValNum, ValF, ValQuick, ValV, ValW, ValX, ValY, ValZ);
  TErmCheckType = (NO_CHECK, CHECK_GET, CHECK_EQUAL, CHECK_NOTEQUAL, CHECK_MORE, CHECK_LESS, 
                   CHECK_MOREEUQAL, CHECK_LESSEQUAL);

  TErmCmdParam = packed record
    Value:    integer;
    {
    [4 bits]  Type:             TErmValType;  // ex: y5;  y5 - type
    [4 bits]  IndexedPartType:  TErmValType;  // ex: vy5; y5 - indexed part;
    [3 bits]  CheckType:        TErmCheckType;
    }
    ValType:  integer;
  end; // .record TErmCmdParam

  TErmString = packed record
    Value: pchar;
    Len:   integer;
  end; // .record TErmString
  
  PErmCmdConditions = ^TErmCmdConditions;
  TErmCmdConditions = array [COND_AND..COND_OR, 0..15, LEFT_COND..RIGHT_COND] of TErmCmdParam;

  PErmCmdParams = ^TErmCmdParams;
  TErmCmdParams = array [0..ERM_CMD_MAX_PARAMS_NUM - 1] of TErmCmdParam;

  TErmCmdId = packed record
    case boolean of
      TRUE:  (Name: array [0..1] of char);
      FALSE: (Id: word);
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
  
  PErmVVars = ^TErmVVars;
  TErmVVars = array [1..10000] of integer;
  PWVars    = ^TWVars;
  TWVars    = array [0..255, 1..200] of integer;
  TErmZVar  = array [0..511] of char;
  PErmZVars = ^TErmZVars;
  TErmZVars = array [1..1000] of TErmZVar;
  PErmNZVars = ^TErmNZVars;
  TErmNZVars = array [1..10] of TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = array [1..100] of integer;
  PErmNYVars = ^TErmNYVars;
  TErmNYVars = array [1..100] of integer;
  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;
  PErmFlags = ^TErmFlags;
  TErmFlags = array [1..1000] of boolean;
  PErmEVars = ^TErmEVars;
  TErmEVars = array [1..100] of single;
  PErmNEVars = ^TErmNEVars;
  TErmNEVars = array [1..100] of single;
  PErmQuickVars = ^TErmQuickVars;
  TErmQuickVars = array [0..14] of integer;

  TZvsLoadErtFile = function (Dummy, FileName: pchar): integer; cdecl;
  TZvsShowMessage = function (Mes: pchar; MesType: integer; DummyZero: integer): integer; cdecl;
  TFireErmEvent   = function (EventId: integer): integer; cdecl;
  TZvsDumpErmVars = procedure (Error, {n} ErmCmdPtr: pchar); cdecl;
  
  POnBeforeTriggerArgs = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs = packed record
    TriggerID:         integer;
    BlockErmExecution: LONGBOOL;
  end; // .record TOnBeforeTriggerArgs
  
  TYVars = class
    Value: Utils.TArrayOfInt;
  end; // .class TYVars
  
  TWoGOptions = array [CURRENT_WOG_OPTIONS..GLOBAL_WOG_OPTIONS, 0..NUM_WOG_OPTIONS - 1] of integer;
  
  TMesType  =
  (
    MES_MES         = 1,
    MES_QUESTION    = 2,
    MES_RMB_HINT    = 4,
    MES_CHOOSE      = 7,
    MES_MAY_CHOOSE  = 10
  );
  
  TTextLineBounds = record
    StartPos: integer; // Starts from 1
    EndPos:   integer;
  end; // .record TTextLineBounds
  
  TErmScript = class
   private
        fFileName:    string;
        fContents:    string;
        fCrc32:       integer;
    {n} fLineNumbers: array of TTextLineBounds; // Loaded on demand

    procedure Init (const aFileName, aScriptContents: string; aCrc32: integer);
    procedure UpdateLineNumbers;

   public
    constructor Create (const aFileName, aScriptContents: string; aCrc32: integer); overload;
    constructor Create (const aFileName, aScriptContents: string); overload;
    // Note: uses hash checking instead of comparing contents of scripts
    function  IsEqual (OtherScript: TErmScript): boolean;
    function  StartAddr: {n} pchar;
    function  EndAddr: {n} pchar;
    function  AddrToLineNumber ({n} Addr: pchar; out LineNumber: integer): boolean;
    
    property FileName: string read fFileName;
    property Contents: string read fContents;
    property Crc32:    integer read fCrc32;
  end; // .class TErmScript

  // Sorts list of Name => Priority: integer
  TSortStrListByPriority = class (Alg.TQuickSortAdapter)
    constructor Create (aList: TStrList);
    function  CompareItems (Ind1, Ind2: integer): integer; override;
    procedure SwapItems (Ind1, Ind2: integer); override;
    procedure SavePivotItem (PivotItemInd: integer); override;
    function  CompareToPivot (Ind: integer): integer; override;
    procedure Sort;
    
   private
    {U} List:      TStrList;
        PivotItem: integer;
  end; // .class TSortStrListByPriority

  TScriptAddrBounds = record
        ScriptInd: integer;
    {n} StartAddr: pchar; // First script byte or nil
    {n} EndAddr:   pchar; // Last script byte or nil
  end; // .record TScriptAddrBounds
  
  TScriptsAddrBounds = array of TScriptAddrBounds;
  
  // Sorts array of TScriptAddrBounds
  TSortScriptsAddrBounds = class (Alg.TQuickSortAdapter)
    constructor Create ({n} aArr: TScriptsAddrBounds);
    function  CompareItems (Ind1, Ind2: integer): integer; override;
    procedure SwapItems (Ind1, Ind2: integer); override;
    procedure SavePivotItem (PivotItemInd: integer); override;
    function  CompareToPivot (Ind: integer): integer; override;
    procedure Sort;
    
   private
    {Un} fArr:      TScriptsAddrBounds;
         PivotItem: TScriptAddrBounds;
  end; // .class TSortScriptsAddrBounds
  
  TScriptMan = class
   private
    {O} fScripts:           {O} TList {OF TErmScript};
    {O} fScriptIsLoaded:    {U} TDict {OF FileName => Ptr(BOOLEAN)};
    {n} fScriptsAddrBounds: TScriptsAddrBounds; // Loaded on demands
    
    function  GetScriptCount: integer;
    function  GetScript (Ind: integer): TErmScript;
    procedure UpdateScriptAddrBounds;
   
   public
    constructor Create;
    destructor  Destroy; override;
   
    procedure ClearScripts;
    procedure SaveScripts;
    function  IsScriptLoaded (const ScriptName: string): boolean;
    function  LoadScript (const ScriptName: string): boolean;
    procedure LoadScriptsFromSavedGame;
    procedure LoadScriptsFromDisk;
    procedure ReloadScriptsFromDisk;
    procedure ExtractScripts;
    function  AddrToScriptNameAndLine ({n} Addr: pchar; out ScriptName: string; out Line: integer)
                                      : boolean;

    property ScriptCount: integer read GetScriptCount;
    property Scripts[Ind: integer]: TErmScript read GetScript;
  end; // .class TScriptMan

  
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

  ZvsIsGameLoading: PBOOLEAN      = Ptr($A46BC0);
  IsWoG:            plongbool     = Ptr($803288);
  ErmEnabled:       plongbool     = Ptr($27F995C);
  ErmDlgCmd:        PINTEGER      = Ptr($887658);
  WoGOptions:       ^TWoGOptions  = Ptr($2771920);
  ErmErrCmdPtr:     PPCHAR        = Ptr($840E0C);
  MrMonPtr:         PPOINTER      = Ptr($2846884); // MB_Mon

  (* WoG funcs *)
  ZvsFindErm:         Utils.TProcedure  = Ptr($749955);
  ZvsClearErtStrings: Utils.TProcedure  = Ptr($7764F2);
  ZvsLoadErtFile:     TZvsLoadErtFile   = Ptr($72C641);
  ZvsShowMessage:     TZvsShowMessage   = Ptr($70FB63);
  ZvsResetCommanders: Utils.TProcedure  = Ptr($770B25);
  FireErmEvent:       TFireErmEvent     = Ptr($74CE30);
  ZvsDumpErmVars:     TZvsDumpErmVars   = Ptr($72B8C0);


var
{O} ScriptMan:            TScriptMan;
    IgnoreInvalidCmdsOpt: boolean;
  
  
procedure ZvsProcessCmd (Cmd: PErmCmd);
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
procedure ExecErmCmd (const CmdStr: string);
procedure ReloadErm; stdcall;
procedure ExtractErm; stdcall;
procedure FireErmEventEx (EventId: integer; Params: array of integer);
function  IsEraTrigger (TrigId: integer): boolean;
function  FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;
function  GrabErmCmd ({n} CmdPtr: pchar): string;
function  ErmCurrHero: {n} pointer;
function  ErmCurrHeroInd: integer; // or -1


(***) implementation (***)
uses Stores;

const
  ERM_CMD_CACH_LIMIT = 16384;


var
{O} ErmScanner:       TextScan.TTextScanner;
{O} ErmCmdCache:      {O} TAssocArray {OF PErmCmd};
{O} SavedYVars:       {O} Lists.TList {OF TYVars};
    ErmTriggerDepth:  integer = 0;
    ErmErrReported:   boolean = FALSE;
    
  FreezedWogOptionWogify: integer = WOGIFY_ALL;


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
    MOV EAX, [Heroes.HERO_WND_MANAGER]
    MOV EAX, [EAX + $38]
    MOV Res, EAX
  end; // .asm
  
  result := MSG_RES_OK;
  
  if MesType = MES_QUESTION then begin
    if Res = 30726 then begin
      result := MSG_RES_CANCEL;
    end // .if
  end // .if
  else if MesType in [MES_CHOOSE, MES_MAY_CHOOSE] then begin
    case Res of 
      30729: result := MSG_RES_LEFTPIC;
      30730: result := MSG_RES_RIGHTPIC;
    else
      result := MSG_RES_CANCEL;
    end; // .SWITCH Res
  end; // .ELSEIF
end; // .function Msg  
  
procedure ShowMessage (const Mes: string);
begin
  Msg(Mes);
end; // .procedure ShowMessage
    
function Ask (const Question: string): boolean;
begin
  result := Msg(Question, MES_QUESTION) = MSG_RES_OK;
end; // .function Ask
    
function GetErmValType (c: char; out ValType: TErmValType): boolean;
begin
  result := TRUE;
  
  case c of
    '+', '-': ValType :=  ValNum;
    '0'..'9': ValType :=  ValNum;
    'f'..'t': ValType :=  ValQuick;
    'v':      ValType :=  ValV;
    'w':      ValType :=  ValW;
    'x':      ValType :=  ValX;
    'y':      ValType :=  ValY;
    'z':      ValType :=  ValZ;
  else
    result := FALSE;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  end; // .SWITCH c
end; // .function GetErmValType

procedure ZvsProcessCmd (Cmd: PErmCmd); ASSEMBLER;
asm
  // Push parameters
  MOV EAX, Cmd
  PUSH 0
  PUSH 0
  PUSH EAX
  // Push return address
  LEA EAX, @@Ret
  PUSH EAX
  // Execute initial function code
  PUSH EBP
  MOV EBP, ESP
  SUB ESP, $544
  PUSH EBX
  PUSH ESI
  PUSH EDI
  MOV EAX, [EBP + $8]
  MOV CX, [EAX]
  MOV [EBP - $314], CX
  MOV EDX, [EBP + $8]
  MOV EAX, [EDX + $294]
  MOV [EBP - $2FC], EAX
  // Give control to code after logging area
  PUSH $741E3F
  RET
  @@Ret:
  ADD ESP, $0C
  // RET
end; // .procedure ZvsProcessCmd

procedure ClearErmCmdCache;
begin
  with DataLib.IterateDict(ErmCmdCache) do begin
    while IterNext do begin
      FreeMem(PErmCmd(IterValue).CmdHeader.Value);
      Dispose(PErmCmd(IterValue));
    end; // .while
  end; // .with 

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
      end // .if
      else begin
        ErmScanner.ReadToken(DIGITS, Token);
      end; // .else
      
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
        end; // .if
      end; // .if
      
      if result then begin
        result := ReadNum(Arg.Value);
        
        if result then begin
          Arg.ValType := ORD(IndType) shl 4 + ORD(ValType);
        end; // .if
      end; // .if
    end; // .if
  end; // .function ReadArg
  
begin
  Cmd := ErmCmdCache[CmdStr];
  // * * * * * //
  Res := TRUE;
  
  if Cmd = nil then begin
    New(Cmd);
    FillChar(Cmd^, sizeof(Cmd^), 0);
    ErmScanner.Connect(CmdStr, LINE_END_MARKER);
    Res     := ErmScanner.ReadToken(LETTERS, CmdName) and (Length(CmdName) = 2);
    NumArgs := 0;
    
    while Res and ErmScanner.GetCurrChar(c) and (c <> ':') and (NumArgs < ERM_CMD_MAX_PARAMS_NUM)
    do begin
      Res := ReadArg(Cmd.Params[NumArgs]) and ErmScanner.GetCurrChar(c);

      if Res then begin
        Inc(NumArgs);

        if c = '/' then begin
          ErmScanner.GotoNextChar;
        end; // .if
      end; // .if
    end; // .while

    Res := Res and ErmScanner.GotoNextChar;

    if Res then begin
      // Allocate memory, because ERM engine changes command contents during execution
      GetMem(Cmd.CmdHeader.Value, Length(CmdStr) + 1);
      Utils.CopyMem(Length(CmdStr) + 1, pointer(CmdStr), Cmd.CmdHeader.Value);
      
      Cmd.CmdBody.Value := Utils.PtrOfs(Cmd.CmdHeader.Value, ErmScanner.Pos - 1);
      Cmd.CmdId.Name[0] := CmdName[1];
      Cmd.CmdId.Name[1] := CmdName[2];
      Cmd.NumParams     := NumArgs;
      Cmd.CmdHeader.Len := ErmScanner.Pos - 1;
      Cmd.CmdBody.Len   := Length(CmdStr) - ErmScanner.Pos + 1;
      
      if ErmCmdCache.ItemCount = ERM_CMD_CACH_LIMIT then begin
        ClearErmCmdCache;
      end; // .if
      
      ErmCmdCache[CmdStr] := Cmd;
    end; // .if
  end; // .if
  
  if not Res then begin
    ShowMessage('ExecErmCmd: Invalid command "' + CmdStr + '"');
  end // .if
  else begin
    ZvsProcessCmd(Cmd);
  end; // .else
end; // .procedure ExecSingleErmCmd

procedure ExecErmCmd (const CmdStr: string);
var
  Commands: Utils.TArrayOfStr;
  i:        integer;
   
begin
  Commands := StrLib.ExplodeEx(CmdStr, ';', StrLib.INCLUDE_DELIM, not StrLib.LIMIT_TOKENS, 0);

  for i := 0 to High(Commands) - 1 do begin
    ExecSingleErmCmd(Commands[i]);
  end; // .for
end; // .procedure ExecErmCmd

procedure TErmScript.Init (const aFileName, aScriptContents: string; aCrc32: integer);
begin
  fFileName    := aFileName;
  fContents    := aScriptContents;
  fCrc32       := aCrc32;
  fLineNumbers := nil;
end; // .procedure TErmScript.Init

constructor TErmScript.Create (const aFileName, aScriptContents: string; aCrc32: integer);
begin
  Init(aFileName, aScriptContents, aCrc32);
end; // .constructor TErmScript.Create

constructor TErmScript.Create (const aFileName, aScriptContents: string);
begin
  Init(aFileName, aScriptContents, Crypto.AnsiCRC32(aScriptContents));
end; // .constructor TErmScript.Create

procedure TErmScript.UpdateLineNumbers;
var
  NumLines: integer;
  i:        integer;
   
begin
  fLineNumbers := nil;

  if fContents <> '' then begin
    ErmScanner.Connect(fContents, LINE_END_MARKER);
    ErmScanner.GotoLine(MAXLONGINT);
    NumLines := ErmScanner.LineN;
    SetLength(fLineNumbers, NumLines);
    ErmScanner.Connect(fContents, LINE_END_MARKER);

    for i := 0 to NumLines - 1 do begin
      fLineNumbers[i].StartPos := ErmScanner.Pos;
      ErmScanner.GotoNextLine;
      fLineNumbers[i].EndPos   := ErmScanner.Pos - 1;
    end; // .for
  end; // .if
end; // .procedure TErmScript.UpdateLineNumbers

function TErmScript.IsEqual (OtherScript: TErmScript): boolean;
begin
  {!} Assert(OtherScript <> nil);
  result := (Self = OtherScript) or ((fFileName         = OtherScript.FileName)          and
                                     (Length(fContents) = Length(OtherScript.fContents)) and
                                     (fCrc32            = OtherScript.fCrc32));
end; // .function TErmScript.IsEqual

function TErmScript.StartAddr: {n} pchar;
begin
  if fContents = '' then begin
    result := nil;
  end // .if
  else begin
    result := pointer(fContents);
  end; // .else
end; // .function TErmScript.StartAddr

function TErmScript.EndAddr: {n} pchar;
begin
  if fContents = '' then begin
    result := nil;
  end // .if
  else begin
    result := Utils.PtrOfs(pointer(fContents), Length(fContents) - 1);
  end; // .else
end; // .function TErmScript.EndAddr

function TErmScript.AddrToLineNumber ({n} Addr: pchar; out LineNumber: integer): boolean;
var
  TargetPos:  integer; // Starts from 1
  (* Binary search vars *)
  Left:       integer;
  Right:      integer;
  Middle:     integer;

begin
  result := (fContents <> '') and (Math.InRange(int(Addr), int(fContents),
                                                int(fContents) + Length(fContents) - 1));
  
  if result then begin
    if fLineNumbers = nil then begin
      UpdateLineNumbers;
    end; // .if
    
    result    := FALSE;
    TargetPos := int(Addr) - int(fContents) + 1;
    Left      := 0;
    Right     := High(fLineNumbers);
    
    while not result and (Left <= Right) do begin
      Middle := Left + (Right - Left) div 2;
      
      if TargetPos < fLineNumbers[Middle].StartPos then begin
        Right := Middle - 1;
      end // .if
      else if TargetPos > fLineNumbers[Middle].EndPos then begin
        Left := Middle + 1;
      end // .ELSEIF
      else begin
        // Add 1, because line number starts from 1
        LineNumber := Middle + 1;
        result     := TRUE;
      end; // .else
    end; // .while
    
    {!} Assert(result);
  end; // .if
end; // .function TErmScript.AddrToLineNumber

constructor TSortStrListByPriority.Create (aList: TStrList);
begin
  Self.List := aList;
end; // .constructor TSortStrListByPriority.Create

function TSortStrListByPriority.CompareItems (Ind1, Ind2: integer): integer;
begin
  result := Alg.IntCompare(int(List.Values[Ind1]), int(List.Values[Ind2]));
end; // .function TSortStrListByPriority.CompareItems

procedure TSortStrListByPriority.SwapItems (Ind1, Ind2: integer);
var
  TransferKey:   string;
  TransferValue: pointer;
   
begin
  // Transfer   := List[Ind1]
  TransferKey       := List[Ind1];
  TransferValue     := List.Values[Ind1];
  // List[Ind1] := List[Ind2]
  List[Ind1]        := List[Ind2];
  List.Values[Ind1] := List.Values[Ind2];
  // List[Ind2] := Transfer
  List[Ind2]        := TransferKey;
  List.Values[Ind2] := TransferValue;
end; // .procedure TSortStrListByPriority.SwapItems

procedure TSortStrListByPriority.SavePivotItem (PivotItemInd: integer);
begin
  PivotItem := int(List.Values[PivotItemInd]);
end; // .procedure TSortStrListByPriority.SavePivotItem

function TSortStrListByPriority.CompareToPivot (Ind: integer): integer;
begin
  result := Alg.IntCompare(int(List.Values[Ind]), PivotItem);
end; // .function TSortStrListByPriority.CompareToPivot

procedure TSortStrListByPriority.Sort;
begin
  Alg.QuickSortEx(Self, 0, List.Count - 1);
end; // .procedure TSortStrListByPriority.Sort

constructor TSortScriptsAddrBounds.Create ({n} aArr: TScriptsAddrBounds);
begin
  Self.fArr := aArr;
end; // .constructor TSortScriptsAddrBounds.Create

function TSortScriptsAddrBounds.CompareItems (Ind1, Ind2: integer): integer;
begin
  result := Alg.PtrCompare(fArr[Ind1].StartAddr, fArr[Ind2].StartAddr);
end; // .function TSortScriptsAddrBounds.CompareItems

procedure TSortScriptsAddrBounds.SwapItems (Ind1, Ind2: integer);
var
  TransferItem: TScriptAddrBounds;
   
begin
  TransferItem := fArr[Ind1];
  fArr[Ind1]   := fArr[Ind2];
  fArr[Ind2]   := TransferItem;
end; // .procedure TSortScriptsAddrBounds.SwapItems

procedure TSortScriptsAddrBounds.SavePivotItem (PivotItemInd: integer);
begin
  PivotItem := fArr[PivotItemInd];
end; // .procedure TSortScriptsAddrBounds.SavePivotItem

function TSortScriptsAddrBounds.CompareToPivot (Ind: integer): integer;
begin
  result := Alg.PtrCompare(fArr[Ind].StartAddr, PivotItem.StartAddr);
end; // .function TSortScriptsAddrBounds.CompareToPivot

procedure TSortScriptsAddrBounds.Sort;
begin
  Alg.QuickSortEx(Self, 0, High(fArr));
end; // .procedure TSortScriptsAddrBounds.Sort

function IsEraTrigger (TrigId: integer): boolean;
begin
  result := Math.InRange(TrigId, FIRST_ERA_TRIGGER, LAST_ERA_TRIGGER);
end; // .function IsEraTrigger

function LoadMapRscFile (const ResourcePath: string; out FileContents: string): boolean;
begin
  result := Files.ReadFileContents(GameExt.GetMapResourcePath(ResourcePath), FileContents);
end; // .function LoadMapRscFile

constructor TScriptMan.Create;
begin
  fScripts        := DataLib.NewList(Utils.OWNS_ITEMS);
  fScriptIsLoaded := DataLib.NewDict(not Utils.OWNS_ITEMS, not DataLib.CASE_SENSITIVE);
end; // .constructor TScriptMan.Create
  
destructor TScriptMan.Destroy;
begin
  SysUtils.FreeAndNil(fScripts);
  SysUtils.FreeAndNil(fScriptIsLoaded);
  inherited;
end; // .destructor TScriptMan.Destroy
  
procedure TScriptMan.ClearScripts;
begin
  GameExt.FireEvent('OnBeforeClearErmScripts', GameExt.NO_EVENT_DATA, 0);
  fScripts.Clear;
  fScriptIsLoaded.Clear;
  fScriptsAddrBounds := nil;
end; // .procedure TScriptMan.ClearScripts

procedure TScriptMan.SaveScripts;
var
{U} Script: TErmScript;
    i:      integer;
  
begin
  Script := nil;
  // * * * * * //
  with Stores.NewRider(ERM_SCRIPTS_SECTION) do begin
    WriteInt(fScripts.Count);

    for i := 0 to fScripts.Count - 1 do begin
      Script := TErmScript(fScripts[i]);
      WriteStr(Script.FileName);
      WriteInt(Script.Crc32);
      WriteStr(Script.Contents);
    end; // .for
  end; // .with 
end; // .procedure TScriptMan.SaveScripts

procedure LoadErtFile (const ErmScriptName: string);
var
  ErtFilePath:        string;
  FilePathForZvsFunc: string;
   
begin
  ErtFilePath := GameExt.GetMapResourcePath(ERM_SCRIPTS_PATH + '\'
                                            + SysUtils.ChangeFileExt(ErmScriptName, '.ert'));

  if SysUtils.FileExists(ErtFilePath) then begin
    FilePathForZvsFunc := '..\' + ErtFilePath;
    ZvsLoadErtFile('', pchar(FilePathForZvsFunc));
  end; // .if
end; // .procedure LoadErtFile

function TScriptMan.IsScriptLoaded (const ScriptName: string): boolean;
begin
  result := fScriptIsLoaded[ScriptName] <> nil;
end; // .function TScriptMan.IsScriptLoaded

function TScriptMan.LoadScript (const ScriptName: string): boolean;
var
  ScriptContents: string;

begin
  result := (fScriptIsLoaded[ScriptName] = nil) and
            (LoadMapRscFile(ERM_SCRIPTS_PATH + '\' + ScriptName, ScriptContents));

  if result then begin
    fScriptIsLoaded[ScriptName] := Ptr(1);
    fScripts.Add(TErmScript.Create(ScriptName, ScriptContents));
    LoadErtFile(ScriptName);
  end; // .if
end; // .function TScriptMan.LoadScript

procedure TScriptMan.LoadScriptsFromSavedGame;
var
{O} LoadedScripts:      {O} TList {OF TErmScript};
    NumScripts:         integer;
    ScriptContents:     string;
    ScriptFileName:     string;
    ScriptCrc32:        integer;
    ScriptSetsAreEqual: boolean;
    i:                  integer;
  
begin
  LoadedScripts := DataLib.NewList(Utils.OWNS_ITEMS);
  // * * * * * //
  with Stores.NewRider(ERM_SCRIPTS_SECTION) do begin
    NumScripts := ReadInt;

    for i := 1 to NumScripts do begin
      ScriptFileName := ReadStr;
      ScriptCrc32    := ReadInt;
      ScriptContents := ReadStr;
      LoadedScripts.Add(TErmScript.Create(ScriptFileName, ScriptContents, ScriptCrc32));
    end; // .for
  end; // .with Stores.NewRider
  
  ScriptSetsAreEqual := fScripts.Count = LoadedScripts.Count;
  
  if ScriptSetsAreEqual then begin
    i := 0;
  
    while (i < fScripts.Count) and TErmScript(fScripts[i]).IsEqual(TErmScript(LoadedScripts[i]))
    do begin
      Inc(i);
    end; // .while
    
    ScriptSetsAreEqual := i = fScripts.Count;
  end; // .if
  
  if not ScriptSetsAreEqual then begin
    Utils.Exchange(int(fScripts), int(LoadedScripts));
    ZvsFindErm;
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(LoadedScripts);
end; // .procedure TScriptMan.LoadScriptsFromSavedGame

procedure TScriptMan.LoadScriptsFromDisk;
const
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';
  SYSTEM_SCRIPTS_MASK   = '*.sys.erm';
  
var
(* Lists of Priority: integer *)
{O} FinalScriptList:        TStrList;
{O} ForcedScriptList:       TStrList;
{O} MapSystemScriptList:    TStrList;
{O} CommonSystemScriptList: TStrList;
{O} MapScriptList:          TStrList;
{O} CommonScriptList:       TStrList;

{O} ScriptListSorter: TSortStrListByPriority;
    FileContents:     string;
    i:                integer;
    
  procedure GetPrioritiesFromScriptNames (List: TStrList);
  const
    PRIORITY_SEPARATOR = ' ';
    DEFAULT_PRIORITY   = 0;

    FILENAME_NUM_TOKENS = 2;
    PRIORITY_TOKEN      = 0;
    FILENAME_TOKEN      = 1;
  
  var
    FileNameTokens: Utils.TArrayOfStr;
    Priority:       integer;
    TestPriority:   integer;
    i:              integer;
     
  begin
    for i := 0 to List.Count - 1 do begin
      FileNameTokens := StrLib.ExplodeEx
      (
        List[i],
        PRIORITY_SEPARATOR,
        not StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        FILENAME_NUM_TOKENS
      );

      Priority := DEFAULT_PRIORITY;
      
      if
        (Length(FileNameTokens) = FILENAME_NUM_TOKENS) and
        (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority))
      then begin
        Priority := TestPriority;
      end; // .if
      
      List.Values[i] := Ptr(Priority);
    end; // .for
  end; // .procedure GetPrioritiesFromScriptNames
   
begin
  FinalScriptList         := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  ForcedScriptList        := nil;
  MapSystemScriptList     := nil;
  CommonSystemScriptList  := nil;
  MapScriptList           := nil;
  CommonScriptList        := nil;
  ScriptListSorter        := nil;
  // * * * * * //
  ClearScripts;
  ZvsClearErtStrings;

  if LoadMapRscFile(SCRIPTS_LIST_FILEPATH, FileContents) then begin
    ForcedScriptList        := DataLib.NewStrListFromStrArr
    (
      StrLib.Explode(SysUtils.Trim(FileContents), #13#10),
      not Utils.OWNS_ITEMS,
      DataLib.CASE_INSENSITIVE
    );
    MapSystemScriptList     := FilesEx.GetFileList
    (
      GameExt.GetMapFolder + '\' + ERM_SCRIPTS_PATH + '\' + SYSTEM_SCRIPTS_MASK,
      Files.ONLY_FILES
    );
    CommonSystemScriptList  := FilesEx.GetFileList
    (
      ERM_SCRIPTS_PATH + '\' + SYSTEM_SCRIPTS_MASK,
      Files.ONLY_FILES
    );
    FilesEx.MergeFileLists(FinalScriptList, ForcedScriptList);
    FilesEx.MergeFileLists(FinalScriptList, MapSystemScriptList);
    FilesEx.MergeFileLists(FinalScriptList, CommonSystemScriptList);
  end // .if
  else begin
    MapScriptList := FilesEx.GetFileList
    (
      GameExt.GetMapFolder + '\' + ERM_SCRIPTS_PATH + '\*.erm',
      Files.ONLY_FILES
    );
    CommonScriptList := FilesEx.GetFileList(ERM_SCRIPTS_PATH + '\*.erm', Files.ONLY_FILES);
    FilesEx.MergeFileLists(FinalScriptList, MapScriptList);
    FilesEx.MergeFileLists(FinalScriptList, CommonScriptList);
  end; // .else
  
  GetPrioritiesFromScriptNames(FinalScriptList);
  ScriptListSorter := TSortStrListByPriority.Create(FinalScriptList);
  ScriptListSorter.Sort;
  
  for i := FinalScriptList.Count - 1 downto 0 do begin
    LoadScript(FinalScriptList[i]);
  end; // .for
  // * * * * * //
  SysUtils.FreeAndNil(FinalScriptList);
  SysUtils.FreeAndNil(ForcedScriptList);
  SysUtils.FreeAndNil(MapSystemScriptList);
  SysUtils.FreeAndNil(CommonSystemScriptList);
  SysUtils.FreeAndNil(MapScriptList);
  SysUtils.FreeAndNil(CommonScriptList);
  SysUtils.FreeAndNil(ScriptListSorter);
end; // .procedure TScriptMan.LoadScriptsFromDisk

(*function PreprocessErm (const Script: string): string;
var
{O} StrBuilder: StrLib.TStrBuilder;
{O} Scanner:    TextScan.TTextScanner;
    StartPos:   integer;
    c:          char;

begin
  StrBuilder  :=  StrLib.TStrBuilder.Create;
  Scanner     :=  TextScan.TTextScanner.Create;
  // * * * * * //
  Scanner.Connect(Script, #10);
  StartPos  :=  1;
  
  while Scanner.FindChar('!') do begin
    if
      Scanner.GetCharAtRelPos(+1, c) and (c = '!') and
      Scanner.GetCharAtRelPos(+2, c) and (c = '!')
    then begin
      StrBuilder.Append(Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos));
      Scanner.SkipChars('!');
      StartPos  :=  Scanner.Pos;
    end // .if
    else begin
      Scanner.GotoRelPos(+2);
    end; // .else
  end; // .while
  
  if StartPos = 1 then begin
    result  :=  Script;
  end // .if
  else begin
    StrBuilder.Append(Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos));
    result  :=  StrBuilder.BuildStr;
  end; // .else
  // * * * * * //
  SysUtils.FreeAndNil(StrBuilder);
  SysUtils.FreeAndNil(Scanner);
end; // .function PreprocessErm*)

procedure TScriptMan.ReloadScriptsFromDisk;
const
  SUCCESS_MES: string = '';

begin
  if ErmTriggerDepth = 0 then begin
    ScriptMan.LoadScriptsFromDisk;
    ZvsIsGameLoading^ := TRUE;
    ZvsFindErm;
    PrintChatMsg('{~white}ERM is updated{~}');
  end; // .if
end; // .procedure TScriptMan.ReloadScriptsFromDisk

procedure ReloadErm;
begin
  ScriptMan.ReloadScriptsFromDisk;
end; // .procedure ReloadErm

procedure TScriptMan.ExtractScripts;
var
  Res:        boolean;
  Mes:        string;
  ScriptPath: string;
  i:          integer;
  
begin
  Files.DeleteDir(EXTRACTED_SCRIPTS_PATH);
  Res := SysUtils.CreateDir(EXTRACTED_SCRIPTS_PATH);
  Mes := '';
  
  if not Res then begin
    Mes :=  '{~red}Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"{~}';
  end // .if
  else begin
    i := 0;
    
    while Res and (i < fScripts.Count) do begin
      ScriptPath := EXTRACTED_SCRIPTS_PATH + '\' + TErmScript(fScripts[i]).FileName;
      Res        := Files.WriteFileContents(TErmScript(fScripts[i]).Contents, ScriptPath);
      
      if not Res then begin
        Mes := '{~red}Error writing to file "' + ScriptPath + '"{~}';
      end; // .if
    
      Inc(i);
    end; // .while
  end; // .else
  
  if not Res then begin
    PrintChatMsg(Mes);
  end; // .if
end; // .procedure TScriptMan.ExtractScripts

procedure ExtractErm;
begin
  ScriptMan.ExtractScripts;
end; // .procedure ExtractErm

function TScriptMan.GetScriptCount: integer;
begin
  result := fScripts.Count;
end; // .function TScriptMan.GetScriptCoun

function TScriptMan.GetScript (Ind: integer): TErmScript;
begin
  {!} Assert(Math.InRange(Ind, 0, fScripts.Count - 1));
  result := fScripts[Ind];
end; // .function TScriptMan.GetScript

procedure TScriptMan.UpdateScriptAddrBounds;
var
{O} Sorter: TSortScriptsAddrBounds;
{U} Script: TErmScript;
    i:      integer;
   
begin
  Sorter := nil;
  Script := nil;
  // * * * * * //
  fScriptsAddrBounds := nil;
  
  if fScripts.Count > 0 then begin
    SetLength(fScriptsAddrBounds, fScripts.Count);
    
    for i := 0 to fScripts.Count - 1 do begin
      Script := TErmScript(fScripts[i]);
      fScriptsAddrBounds[i].ScriptInd := i;
      fScriptsAddrBounds[i].StartAddr := Script.StartAddr;
      fScriptsAddrBounds[i].EndAddr   := Script.EndAddr;
    end; // .for
    
    Sorter := TSortScriptsAddrBounds.Create(fScriptsAddrBounds);
    Sorter.Sort;
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(Sorter);
end; // .procedure TScriptMan.UpdateScriptAddrBounds

function TScriptMan.AddrToScriptNameAndLine ({n} Addr: pchar; out ScriptName: string;
                                             out Line: integer): boolean;
var
  ScriptInd: integer;
  (* Binary search vars *)
  Left:      integer;
  Right:     integer;
  Middle:    integer;

begin
  result := (Addr <> nil) and (fScripts.Count > 0);
  
  if result then begin
    if fScriptsAddrBounds = nil then begin
      UpdateScriptAddrBounds;
    end; // .if
    
    result := FALSE;
    Left   := 0;
    Right  := High(fScriptsAddrBounds);
    
    while not result and (Left <= Right) do begin
      Middle := Left + (Right - Left) div 2;
      
      if cardinal(Addr) < cardinal(fScriptsAddrBounds[Middle].StartAddr) then begin
        Right := Middle - 1;
      end // .if
      else if cardinal(Addr) > cardinal(fScriptsAddrBounds[Middle].EndAddr) then begin
        Left := Middle + 1;
      end // .ELSEIF
      else begin
        ScriptInd  := fScriptsAddrBounds[Middle].ScriptInd;
        {!} Assert(Math.InRange(ScriptInd, 0, fScripts.Count - 1));
        ScriptName := TErmScript(fScripts[ScriptInd]).FileName;
        result     := TErmScript(fScripts[ScriptInd]).AddrToLineNumber(Addr, Line);
        {!} Assert(result);
      end; // .else
    end; // .while
  end; // .if
end; // .function TScriptMan.AddrToScriptNameAndLine

procedure FireErmEventEx (EventId: integer; Params: array of integer);
var
  i: integer;

begin
  {!} Assert(Length(Params) <= Length(GameExt.EraEventParams^));
  GameExt.EraSaveEventParams;
  
  for i := 0 to High(Params) do begin
    EraEventParams[i] := Params[i];
  end; // .for
  
  Erm.FireErmEvent(EventId);
  GameExt.EraRestoreEventParams;
end; // .procedure FireErmEventEx

function FindErmCmdBeginning ({n} CmdPtr: pchar): {n} pchar;
begin
  result := CmdPtr;
  
  if result <> nil then begin
    Dec(result);
    
    while result^ <> '!' do begin
      Dec(result);
    end; // .while
    
    Inc(result);
    
    if result^ = '#' then begin
      // [!]#
      Dec(result);
    end // .if
    else begin
      // ![!]
      Dec(result, 2);
    end; // .else
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
    end; // .if
    
    result := StrLib.ExtractFromPchar(StartPos, EndPos - StartPos);
  end; // .if
end; // .function GrabErmCmd

function ErmCurrHero: {n} pointer;
begin
  result := PPOINTER($27F9970)^;
end; // .function ErmCurrHero

function ErmCurrHeroInd: integer; // or -1
begin
  if ErmCurrHero <> nil then begin
    result := PINTEGER(Utils.PtrOfs(ErmCurrHero, $1A))^;
  end // .if
  else begin
    result := -1;
  end; // .else
end; // .function 

function Hook_ProcessErm (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{O} YVars:     TYVars;
    EventArgs: TOnBeforeTriggerArgs;

begin
  YVars := TYVars.Create;
  // * * * * * //
  if CurrErmEventID^ >= Erm.TRIGGER_FU30000 then begin
    SetLength(YVars.Value, Length(y^));
    Utils.CopyMem(sizeof(y^), @y[1], @YVars.Value[0]);
  end; // .if
  
  SavedYVars.Add(YVars); YVars := nil;
  
  (* ProcessErm - initializing v996..v1000 variables *)
  asm
    CMP DWORD [$793C80], 0
    JL @L005
    MOV CL, byte [$793C80]
    MOV byte [$91F6C7], CL
    JMP @L013
  @L005:
    MOV EAX, $710FD3
    CALL EAX
    PUSH EAX
    MOV EAX, $711828
    CALL EAX
    ADD ESP, 4
    NEG EAX
    SBB AL, AL
    Inc AL
    MOV byte [$91F6C7], AL
  @L013:
    MOV EAX, $710FD3
    CALL EAX
    PUSH EAX
    MOV EAX, $7118A3
    CALL EAX
    ADD ESP,4
    MOV byte [$91F6C6], AL
    MOV EDX, DWORD [$27F9964]
    MOV DWORD [$8885FC], EDX
    MOV EAX, DWORD [$27F9968]
    MOV DWORD [$888600], EAX
    MOV ECX, DWORD [$27F996C]
    MOV DWORD [$888604], ECX
  end; // .asm
  
  Inc(ErmTriggerDepth);
  EventArgs.TriggerID         := CurrErmEventID^;
  EventArgs.BlockErmExecution := FALSE;
  GameExt.FireEvent('OnBeforeTrigger', @EventArgs, sizeof(EventArgs));
  
  if EventArgs.BlockErmExecution then begin
    CurrErmEventID^ := TRIGGER_INVALID;
  end; // .if
  
  result := Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
end; // .function Hook_ProcessErm

function Hook_FindErm_BeforeMainLoop (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;
  
var
  ResetEra: Utils.TProcedure;

begin
  // Skip internal map events: GEp_ = GEp1 - [sizeof(_GlbEvent_) = 52]
  PINTEGER(Context.EBP - $3F4)^ := PINTEGER(PINTEGER(Context.EBP - $24)^ + $88)^
                                   - GLOBAL_EVENT_SIZE;
  ErmErrReported := FALSE;
  ResetEra       := Windows.GetProcAddress(GameExt.hAngel, 'ResetEra');
  {!} Assert(@ResetEra <> nil);
  ResetEra;
  GameExt.FireEvent('OnBeforeErm', GameExt.NO_EVENT_DATA, 0);

  if not ZvsIsGameLoading^ then begin
    GameExt.FireEvent('OnBeforeErmInstructions', GameExt.NO_EVENT_DATA, 0);
  end; // .if
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_BeforeMainLoop

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

function Hook_UN_J3_End (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  RESET_OPTIONS_COMMAND = ':clear:';
  WOG_OPTION_MAP_RULES  = 101;
  USE_SELECTED_RULES    = 2;

var
  WoGOptionsFile: string;
  i:              integer;

begin
  WoGOptionsFile := pchar(Context.ECX);

  if WoGOptionsFile = RESET_OPTIONS_COMMAND then begin
    for i := 0 to High(WoGOptions[CURRENT_WOG_OPTIONS]) do begin
      WoGOptions[CURRENT_WOG_OPTIONS][i] := 0;
    end; // .for
    
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_MAP_RULES] := USE_SELECTED_RULES;
  end // .if
  else if not LoadWoGOptions(pchar(WoGOptionsFile)) then begin
    ShowMessage('Cannot load file with WoG options: ' + WoGOptionsFile);
  end; // .ELSEIF
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_UN_J3_End

function Hook_FindErm_AfterMapScripts (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  GLOBAL_EVENT_SIZE = 52;

var
  ScriptIndPtr: PINTEGER;
  
begin
  ScriptIndPtr := Ptr(Context.EBP - $18);
  // * * * * * //
  if not ZvsIsGameLoading^ and (ScriptIndPtr^ = 0) then begin
    ZvsResetCommanders;
    ScriptMan.LoadScriptsFromDisk;
  end; // .if
  
  if ScriptIndPtr^ < ScriptMan.ScriptCount then begin
    // M.m.i = 0
    PINTEGER(Context.EBP - $318)^ := 0;
    // M.m.s = ErmScript
    PPCHAR(Context.EBP - $314)^ := pchar(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // M.m.l = Length(ErmScript)
    PINTEGER(Context.EBP - $310)^ := Length(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // GEp_--; Process one more script
    Dec(PINTEGER(Context.EBP - $3F4)^, GLOBAL_EVENT_SIZE);
    Inc(ScriptIndPtr^);
    // Jump to ERM header processing
    Context.RetAddr := Ptr($74A00C);
  end // .if
  else begin
    // Jimp right after loop end
    Context.RetAddr := Ptr($74C5A7);
  end; // .else
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_FindErm_AfterMapScripts

function Hook_ProcessErm_End (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{O} YVars: TYVars;

begin
  YVars := SavedYVars.Pop;
  // * * * * * //
  GameExt.FireEvent('OnAfterTrigger', CurrErmEventID, sizeof(CurrErmEventID^));
  
  if YVars.Value <> nil then begin
    Utils.CopyMem(sizeof(y^), @YVars.Value[0], @y[1]);
  end; // .if
  
  Dec(ErmTriggerDepth);
  result := Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
end; // .function Hook_ProcessErm_End

{$W-}
procedure Hook_ErmCastleBuilding; ASSEMBLER;
asm
  MOVZX EDX, byte [ECX + $150]
  MOVZX EAX, byte [ECX + $158]
  or EDX, EAX
  PUSH $70E8A9
  // RET
end; // .procedure Hook_ErmCastleBuilding
{$W+}

function Hook_ErmHeroArt (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  result := ((PINTEGER(Context.EBP - $E8)^ shr 8) and 7) = 0;
  
  if not result then begin
    Context.RetAddr := Ptr($744B85);
  end; // .if
end; // .function Hook_ErmHeroArt

function Hook_ErmHeroArt_FindFreeSlot (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  f[1]   := FALSE;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ErmHeroArt_FindFreeSlot

function Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  f[1]   := TRUE;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ErmHeroArt_FoundFreeSlot

function Hook_ErmHeroArt_DeleteFromBag (Context: Core.PHookContext): LONGBOOL; stdcall;
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

function Hook_DlgCallback (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  NO_CMD = 0;

begin
  ErmDlgCmd^ := NO_CMD;
  result     := Core.EXEC_DEF_CODE;
end; // .function Hook_DlgCallback

function Hook_CM3 (Context: Core.PHookContext): LONGBOOL; stdcall;
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
  
  PINTEGER(Context.EDI + MOUSE_STRUCT_ITEM_OFS)^ := PINTEGER(CM3_RES_ADDR)^;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_CM3

function Hook_InvalidReceiver (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  MAX_CONTEXT_SIZE = 512;
  CMD_SIZE         = 4;

var
  CmdPtr:          pchar;
  CmdOffset:       integer;
  Receiver:        string;
  CmdContext:      string;
  ScriptName:      string;
  Line:            integer;
  PositionLocated: boolean;
    
begin
  if not IgnoreInvalidCmdsOpt then begin
    CmdOffset       := PINTEGER(Context.EBP - $318)^;
    CmdPtr          := pchar(PINTEGER(Context.EBP - $314)^ + CmdOffset - CMD_SIZE);
    Receiver        := StrLib.ExtractFromPchar(CmdPtr, CMD_SIZE);
    CmdContext      := StrLib.ExtractFromPchar(CmdPtr, MAX_CONTEXT_SIZE);
    PositionLocated := ScriptMan.AddrToScriptNameAndLine(CmdPtr, ScriptName, Line);
    {!} Assert(PositionLocated);

    ShowMessage('{~red}Invalid receiver: {~gold}' + Receiver + '{~}{~}'#10'File: '
                + ScriptName + '. Line: ' + SysUtils.IntToStr(Line) + #10'Context:'#10#10 
                + CmdContext);
  end; // .if
  
  Context.RetAddr := Ptr($74C550);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_InvalidReceiver

procedure OnEraSaveScripts (Event: GameExt.PEvent); stdcall;
begin
  ScriptMan.SaveScripts;
end; // .procedure OnEraSaveScripts

procedure OnEraLoadScripts (Event: GameExt.PEvent); stdcall;
begin
  ScriptMan.LoadScriptsFromSavedGame;
end; // .procedure OnEraLoadScripts

function Hook_LoadErtFile (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  ARG_FILENAME = 2;

var
  FileName: pchar;
  
begin
  FileName := pchar(PINTEGER(Context.EBP + 12)^);
  Utils.CopyMem(SysUtils.StrLen(FileName) + 1, FileName, Ptr(Context.EBP - $410));
  
  Context.RetAddr := Ptr($72C760);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_LoadErtFile

procedure ReportErmError (Error: string; {n} ErrCmd: pchar);
const
  CONTEXT_LEN = 00;

var
  PositionLocated: boolean;
  ScriptName:      string;
  Line:            integer;
  Question:        string;
  
  
begin
  ErmErrReported  := TRUE;
  PositionLocated := ScriptMan.AddrToScriptNameAndLine(ErrCmd, ScriptName, Line);
  
  if Error = '' then begin
    Error := 'Unknown error';
  end; // .if
  
  Question := '{~r}' + Error + '{~}';
  
  if PositionLocated then begin
    Question := Question + #10'File: ' + ScriptName + '. Line: ' + IntToStr(Line);
  end; // .if
  
  Question := Question + #10#10'{~g}' + GrabErmCmd(ErrCmd) + '{~}'
              + #10#10'Continue without saving ERM memory dump?';
  
  if not Ask(Question) then begin
    ZvsDumpErmVars(pchar(Error), ErrCmd);
  end; // .if
end; // .procedure ReportErmError

function Hook_MError (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  ReportErmError(PPCHAR(Context.EBP + 16)^, ErmErrCmdPtr^);
  Context.RetAddr := Ptr($712483);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_MError

function Hook_ProcessErm_Start (Context: Core.PHookContext): LONGBOOL; stdcall;
var
  DisableExecution: boolean;

begin
  PINTEGER(Context.EBP - $300)^ := 0; // M.i = 0, default code
  DisableExecution := FALSE;
  ErmErrReported   := FALSE;
  
  if DisableExecution then begin
    Context.RetAddr := Ptr($749702);
  end // .if
  else begin
    Context.RetAddr := Ptr($741E58);
  end; // .else
  
  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_ProcessErm_Start

function Hook_ErmMess (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  if not ErmErrReported then begin
    // ERM cmd pos is m->m.s
    ReportErmError('', PPCHAR(PINTEGER(Context.EBP + 8)^ + 4)^);
  end; // .if
  
  (* The command below was deactivated, because it leaded to multiple ERM messages *)
  // ++m->i;
  //Inc(PINTEGER(PINTEGER(Context.EBP + 8)^)^);
  ErmErrReported  := FALSE;
  Context.RetAddr := Ptr($73DF03);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_ErmMess

function Hook_MR_N (c: Core.PHookContext): longbool; stdcall;
begin
  c.eax     := Heroes.GetStackIdByPos(Heroes.GetVal(MrMonPtr^, STACK_POS).v);
  c.RetAddr := Ptr($75DC76);
  result    := not Core.EXEC_DEF_CODE;
end; // .function Hook_MR_N

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  ExtractErm;
end; // .procedure OnGenerateDebugInfo

procedure OnBeforeWoG (Event: GameExt.PEvent); stdcall;
begin
  (* Remove WoG CM3 trigger *)
  Core.p.WriteDword($78C210, $887668);
end; // .procedure OnBeforeWoG

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  (* Disable internal map scripts interpretation *)
  Core.ApiHook(@Hook_FindErm_BeforeMainLoop, Core.HOOKTYPE_BRIDGE, Ptr($749BBA));
  
  (* Remove default mechanism of loading [mapname].erm *)
  Core.p.WriteDataPatch($72CA8A, ['E90102000090909090']);
  
  (* Replace all points of wog option 5 (Wogify) access with FreezedWogOptionWogify *)
  Core.p.WriteDword($705601 + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($72CA2F + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($749BFE + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($749CAF + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($749D91 + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($749E2D + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($749E9D + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($74C6F5 + 2, integer(@FreezedWogOptionWogify));
  Core.p.WriteDword($753F07 + 2, integer(@FreezedWogOptionWogify));

  (* Never load [mapname].cmd file *)
  Core.p.WriteDataPatch($771CA8, ['E9C2070000']);
  
  (* Force all maps to be treated as WoG format *)
  // Replace MOV WoG, 0 with MOV WoG, 1
  Core.p.WriteDataPatch($704F48 + 6, ['01']);
  Core.p.WriteDataPatch($74C6E1 + 6, ['01']);
  
  (* UN:J3 does not reset commanders or load scripts. New: it can be used to reset wog options *)
  Core.ApiHook(@Hook_UN_J3_End, Core.HOOKTYPE_BRIDGE, Ptr($733A85));
  
  (* New way of iterating scripts in FindErm *)
  Core.ApiHook(@Hook_FindErm_AfterMapScripts, Core.HOOKTYPE_BRIDGE, Ptr($749BF5));  
  
  (* Remove LoadERMTXT calls everywhere *)
  Core.p.WriteDataPatch($749932 - 2, ['33C09090909090909090']);
  Core.p.WriteDataPatch($749C24 - 2, ['33C09090909090909090']);
  Core.p.WriteDataPatch($74C7DD - 2, ['33C09090909090909090']);
  Core.p.WriteDataPatch($7518CC - 2, ['33C09090909090909090']);
  
  (* Remove call to FindErm from _B1.cpp::LoadManager *)
  Core.p.WriteDataPatch($7051A2, ['9090909090']);
  
  (* Remove saving and loading old ERM scripts array *)
  Core.p.WriteDataPatch($75139D, ['EB7D909090']);
  Core.p.WriteDataPatch($751EED, ['E99C000000']);
  
  (* InitErm always sets IsWoG to true *)
  Core.p.WriteDataPatch($74C6FC, ['9090']);

  (* ERM OnAnyTrigger *)
  Core.Hook(@Hook_ProcessErm, Core.HOOKTYPE_BRIDGE, 6, Ptr($74C819));
  Core.Hook(@Hook_ProcessErm_End, Core.HOOKTYPE_BRIDGE, 5, Ptr($74CE2A));
  
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
  Core.p.WriteDataPatch($777E48, ['E9180100009090909090']);
  
  (* Fix CM3 trigger allowing to handle all clicks *)
  Core.ApiHook(@Hook_CM3, Core.HOOKTYPE_BRIDGE, Ptr($5B0255));
  Core.p.WriteDataPatch($5B02DD, ['8B47088D70FF']);
  
  (* Option to ignore invalid ERM reveivers: !!XX *)
  Core.ApiHook(@Hook_InvalidReceiver, Core.HOOKTYPE_BRIDGE, Ptr($74BCBA));
  
  (* Detailed ERM error reporting *)
  Core.ApiHook(@Hook_MError, Core.HOOKTYPE_BRIDGE, Ptr($71236A));
  
  (* Remove double ERM error reporting *)
  Core.p.WriteDataPatch($749430, ['909090909090909090']);
  
  (* Disable default tracing of last ERM command *)
  Core.p.WriteDataPatch($741E34, ['9090909090909090909090']);
  
  (* ERM command tracking and handling *)
  Core.ApiHook(@Hook_ProcessErm_Start, Core.HOOKTYPE_BRIDGE, Ptr($741E4E));
  
  (* Detailed ERM error reporting *)
  Core.ApiHook(@Hook_ErmMess, Core.HOOKTYPE_BRIDGE, Ptr($73DE8D));

  (* Fix MR:N in !?MR1 !?MR2 *)
  Core.ApiHook(@Hook_MR_N, Core.HOOKTYPE_BRIDGE, Ptr($75DC67));
  Core.p.WriteDataPatch($439840, ['8B4D08909090']);
  Core.p.WriteDataPatch($439857, ['8B4D08909090']);
end; // .procedure OnAfterWoG

begin
  ScriptMan   := TScriptMan.Create;
  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  IsWoG^      := TRUE;
  ErmEnabled^ := TRUE;
  SavedYVars  := Lists.NewStrictList(TYVars);

  GameExt.RegisterHandler(OnBeforeWoG,         'OnBeforeWoG');
  GameExt.RegisterHandler(OnAfterWoG,          'OnAfterWoG');
  GameExt.RegisterHandler(OnEraSaveScripts,    '$OnEraSaveScripts');
  GameExt.RegisterHandler(OnEraLoadScripts,    '$OnEraLoadScripts');
  GameExt.RegisterHandler(OnGenerateDebugInfo, 'OnGenerateDebugInfo');
end.
