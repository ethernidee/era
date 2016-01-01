unit Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Utils, Crypto, TextScan, AssocArrays, DataLib, CFiles, Files, Ini,
  Lists, StrLib, Math, Windows,
  Core, Heroes, GameExt;

type
  TStrList = DataLib.TStrList;
  TDict    = DataLib.TDict;

const
  SCRIPT_NAMES_SECTION = 'Era.ScriptNames';
  ERM_SCRIPTS_PATH     = 'Data\s';

  (* Erm command conditions *)
  LEFT_COND   = 0;
  RIGHT_COND  = 1;
  COND_AND    = 0;
  COND_OR     = 1;

  ERM_CMD_MAX_PARAMS_NUM  = 16;
  MAX_ERM_SCRIPTS_NUM     = 100;
  MIN_ERM_SCRIPT_SIZE     = Length('ZVSE'#13#10);
  LINE_END_MARKER         = #10;

  (* Erm script state*)
  SCRIPT_NOT_USED = 0;
  SCRIPT_IS_USED  = 1;
  SCRIPT_IN_MAP   = 2;

  EXTRACTED_SCRIPTS_PATH  = 'Data\ExtractedScripts';

  AltScriptsPath: pchar     = Ptr($2730F68);
  CurrErmEventID: PINTEGER  = Ptr($27C1950);

  (* Trigger if-else-then *)
  ZVS_TRIGGER_IF_TRUE     = 1;
  ZVS_TRIGGER_IF_FALSE    = 0;
  ZVS_TRIGGER_IF_INACTIVE = -1;

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
  
  FUNC_AUTO_ID = 95000;

  ZvsProcessErm:  Utils.TProcedure  = Ptr($74C816);

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

  NUM_WOG_HEROES = 156;


type
  (* IMPORT *)
  TAssocArray = AssocArrays.TAssocArray;

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
    Value:  pchar;
    Len:    integer;
  end; // .record TErmString
  
  TGameString = packed record
    Value:  pchar;
    Len:    integer;
    Dummy:  integer;
  end; // .record TGameString
  
  TErmScriptInfo  = packed record
    State:  integer;
    Size:   integer;
  end; // .record TErmScriptInfo

  PErmScriptsInfo = ^TErmScriptsInfo;
  TErmScriptsInfo = array [0..MAX_ERM_SCRIPTS_NUM - 1] of TErmScriptInfo;
  
  PScriptsPointers  = ^TScriptsPointers;
  TScriptsPointers  = array [0..MAX_ERM_SCRIPTS_NUM - 1] of pchar;
  
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

  PZvsTriggerIfs = ^TZvsTriggerIfs;
  TZvsTriggerIfs = array [0..9] of shortint;
  
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

  TZvsLoadErmScript = function (ScriptId: integer): integer; cdecl;
  TZvsLoadErmTxt    = function (IsNewLoad: integer): integer; cdecl;
  TZvsLoadErtFile   = function (Dummy, FileName: pchar): integer; cdecl;
  TZvsShowMessage   = function (Mes: pchar; MesType: integer; DummyZero: integer): integer; cdecl;
  TZvsCheckFlags    = function (Flags: PErmCmdConditions): longbool; cdecl;
  TFireErmEvent     = function (EventId: integer): integer; cdecl;
  
  POnBeforeTriggerArgs  = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs  = packed record
    TriggerID:          integer;
    BlockErmExecution:  LONGBOOL;
  end; // .record TOnBeforeTriggerArgs
  
  TYVars = class
    Value: Utils.TArrayOfInt;
  end; // .class TYVars

  TWoGOptions = array [CURRENT_WOG_OPTIONS..GLOBAL_WOG_OPTIONS, 0..NUM_WOG_OPTIONS - 1] of integer;
  
  TMesType =
  (
    MES_MES         = 1,
    MES_QUESTION    = 2,
    MES_RMB_HINT    = 4,
    MES_CHOOSE      = 7,
    MES_MAY_CHOOSE  = 10
  );

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

  ZvsIsGameLoading:   PBOOLEAN          = Ptr($A46BC0);
  ZvsTriggerIfs:      PZvsTriggerIfs    = Ptr($A46D18);
  ZvsTriggerIfsDepth: pbyte             = Ptr($A46D22);
  ErmScriptsInfo:     PErmScriptsInfo   = Ptr($A49270);
  ErmScripts:         PScriptsPointers  = Ptr($A468A0);
  IsWoG:              plongbool         = Ptr($803288);
  WoGOptions:         ^TWoGOptions      = Ptr($2771920);
  ErmDlgCmd:          PINTEGER          = Ptr($887658);
  MrMonPtr:           PPOINTER          = Ptr($2846884); // MB_Mon
  HeroSpecsTable:     PHeroSpecsTable   = Ptr($7B4C40);
  HeroSpecsTableBack: PHeroSpecsTable   = Ptr($91DA78);
  HeroSpecSettingsTable: PHeroSpecSettingsTable = Ptr($A49BC0);

  (* WoG funcs *)
  ZvsFindErm:         Utils.TProcedure  = Ptr($749955);
  ZvsClearErtStrings: Utils.TProcedure  = Ptr($7764F2);
  ZvsClearErmScripts: Utils.TProcedure  = Ptr($750191);
  ZvsLoadErmScript:   TZvsLoadErmScript = Ptr($72C297);
  ZvsLoadErmTxt:      TZvsLoadErmTxt    = Ptr($72C8B1);
  ZvsLoadErtFile:     TZvsLoadErtFile   = Ptr($72C641);
  ZvsShowMessage:     TZvsShowMessage   = Ptr($70FB63);
  ZvsCheckFlags:      TZvsCheckFlags    = Ptr($740DF1);
  FireErmEvent:       TFireErmEvent     = Ptr($74CE30);


procedure ZvsProcessCmd (Cmd: PErmCmd);
procedure ShowMessage (const Mes: string);
procedure ExecErmCmd (const CmdStr: string);
procedure ReloadErm; stdcall;
procedure ExtractErm; stdcall;
procedure FireErmEventEx (EventId: integer; Params: array of integer);  


(***) implementation (***)
uses Stores, AdvErm;


const
  ERM_CMD_CACH_LIMIT  = 16384;


var
{O} ScriptNames:      Lists.TStringList;
{O} ErmScanner:       TextScan.TTextScanner;
{O} ErmCmdCache:      {O} TAssocArray {OF PErmCmd};
{O} SavedYVars:       {O} Lists.TList {OF TYVars};
    ErmTriggerDepth:  integer = 0;


procedure ShowMessage (const Mes: string);
const
  MSG_OK  = 1;

begin
  ZvsShowMessage(pchar(Mes), MSG_OK, 0);
end; // .procedure ShowMessage
    
function GetErmValType (c: char; out ValType: TErmValType): boolean;
begin
  result  :=  true;
  
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
    result := false;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  end; // .switch
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
  Res := true;
  
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
  Command:  string;
  i:        integer;
   
begin
  Commands := StrLib.ExplodeEx(CmdStr, ';', StrLib.INCLUDE_DELIM, not StrLib.LIMIT_TOKENS, 0);

  for i := 0 to High(Commands) do begin
    Command := SysUtils.Trim(Commands[i]);

    if Command <> '' then begin
      if (i = High(Commands)) and (Command[Length(Command)] <> ';') then begin
        Command := Command + ';';
      end; // .if

      ExecSingleErmCmd(Command);
    end; // .if
  end; // .for
end; // .procedure ExecErmCmd

procedure LoadScriptFromMemory (const ScriptName, ScriptContents: string);
var
  ScriptInd:  integer;
  ScriptSize: integer;
  ScriptBuf:  pchar;

begin
  ScriptInd   :=  ScriptNames.Count;
  {!} Assert(ScriptInd < MAX_ERM_SCRIPTS_NUM);
  ScriptSize  :=  Length(ScriptContents);
  
  if ScriptSize > MIN_ERM_SCRIPT_SIZE then begin
    ErmScriptsInfo[ScriptInd].State :=  SCRIPT_IS_USED;
    ErmScriptsInfo[ScriptInd].Size  :=  ScriptSize;
    ScriptBuf                       :=  Heroes.MAlloc(ScriptSize - 1);      
    ErmScripts[ScriptInd]           :=  ScriptBuf;
    Utils.CopyMem(ScriptSize - 2, pointer(ScriptContents), ScriptBuf);
    PBYTE(Utils.PtrOfs(ScriptBuf, ScriptSize - 2))^ :=  0;
    ScriptNames.Add(ScriptName);
  end; // .if
end; // .procedure LoadScriptFromMemory

procedure LoadErtFile (const ErmScriptName: string);
var
  ErtFilePath:  string;
   
begin
  ErtFilePath :=  ERM_SCRIPTS_PATH + '\' + SysUtils.ChangeFileExt(ErmScriptName, '.ert');
    
  if SysUtils.FileExists(ErtFilePath) then begin
    ZvsLoadErtFile('', pchar('..\' + ErtFilePath));
  end; // .if
end; // .procedure LoadErtFile

function PreprocessErm (const ScriptName, Script: string): string;
const
  ANY_CHAR            = [#0..#255];
  FUNCNAME_CHARS      = ANY_CHAR - [')', #10, #13];
  LABEL_CHARS         = ANY_CHAR - [']', #10, #13];
  SPECIAL_CHARS       = ['[', '!'];
  INCMD_SPECIAL_CHARS = ['[', '(', '^', ';'];

  NO_LABEL = -1;

type
  TScope = (GLOBAL_SCOPE, CMD_SCOPE);

var
{
  For unresolved labels value for key is index of previous unresolved label in Buf.
  Zero indexes are ignored.
}
{O} Buf:                TStrList {of integer};
{O} Scanner:            TextScan.TTextScanner;
{O} Labels:             TDict {of CmdN + 1};
{U} FuncAutoId:         AdvErm.TAssocVar;
    UnresolvedLabelInd: integer; // index of last unresolved label or NO_LABEL
    CmdN:               integer; // index of next command
    MarkedPos:          integer;
    c:                  char;

  procedure ShowError (ErrPos: integer; const Error: string);
  var
    LineN:   integer;
    LinePos: integer;

  begin
    if not Scanner.PosToLine(ErrPos, LineN, LinePos) then begin
      LineN   := -1;
      LinePos := -1;
    end; // .if
    
    ShowMessage(Format('{~gold}Error in "%s".'#10'Line: %d. Position: %d.{~}'#10 +
                       '%s.'#10#10'Context:'#10#10'%s',
                       [ScriptName, LineN, LinePos, Error,
                        Scanner.GetSubstrAtPos(ErrPos - 20, 20) + ' <<< ' +
                        Scanner.GetSubstrAtPos(ErrPos + 0,  100)]));
  end; // .procedure ShowError

  procedure MarkPos;
  begin
    MarkedPos := Scanner.Pos;
  end; // .procedure MarkPos

  procedure FlushMarked;
  begin
    if Scanner.Pos > MarkedPos then begin
      Buf.Add(Scanner.GetSubstrAtPos(MarkedPos, Scanner.Pos - MarkedPos));
      MarkedPos := Scanner.Pos;
    end; // .if
  end; // .procedure FlushMarked

  procedure ParseFuncName;
  var
  {U} FuncVar:  AdvErm.TAssocVar;
      FuncName: string;
      c:        char;

  begin
    FuncVar := nil;
    // * * * * * //
    FlushMarked;
    Scanner.GotoNextChar;

    if Scanner.ReadToken(FUNCNAME_CHARS, FuncName) and Scanner.GetCurrChar(c) then begin
      if c = ')' then begin
        Scanner.GotoNextChar;
        FuncVar := AdvErm.GetOrCreateAssocVar(FuncName);

        if FuncVar.IntValue = 0 then begin
          FuncVar.IntValue := FuncAutoId.IntValue;
          Inc(FuncAutoId.IntValue);
        end; // .if

        Buf.Add(IntToStr(FuncVar.IntValue));
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in function name');
        Buf.Add('999999');
      end; // .else
    end else begin
      ShowError(Scanner.Pos, 'Missing closing ")"');
      Buf.Add('999999');
    end; // .else

    MarkPos;
  end; // .procedure ParseFuncName

  procedure DeclareLabel (const LabelName: string);
  begin
    if Labels[LabelName] = nil then begin
      Labels[LabelName] := Ptr(CmdN + 1);
    end else begin
      ShowError(Scanner.Pos, 'Duplicate label "' + LabelName + '"');
    end; // .else
  end; // .procedure DeclareLabel

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
    end; // .if
    
    if Scanner.ReadToken(LABEL_CHARS, LabelName) and Scanner.GetCurrChar(c) then begin
      if c = ']' then begin
        Scanner.GotoNextChar;

        if IsDeclaration then begin
          if Scope = GLOBAL_SCOPE then begin
            DeclareLabel(LabelName);
          end else begin
            ShowError(Scanner.Pos, 'Label declaration inside command is prohibited');
          end; // .else
        end else begin
          if Scope = CMD_SCOPE then begin
            LabelValue := integer(Labels[LabelName]);

            if LabelValue = 0 then begin
              UnresolvedLabelInd := Buf.AddObj(LabelName, Ptr(UnresolvedLabelInd));
            end else begin
              Buf.Add(IntToStr(LabelValue - 1));
            end; // .else
          end else begin
            FlushMarked;
          end; // .else
        end; // .else
      end else begin
        ShowError(Scanner.Pos, 'Unexpected line end in label name');

        if not IsDeclaration then begin
          Buf.Add('999999');
        end; // .if
      end; // .else
    end else begin
      ShowError(Scanner.Pos, 'Missing closing "]"');

      if not IsDeclaration then begin
        Buf.Add('999999');
      end; // .if
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
      end; // .else

      i := integer(Buf.Values[i]);
    end; // .while

    UnresolvedLabelInd := NO_LABEL;
  end; // .procedure ResolveLabels

  procedure ParseCmd;
  var
    c: char;

  begin
    Scanner.GotoNextChar;
    c := ' ';

    while Scanner.FindCharset(INCMD_SPECIAL_CHARS) and Scanner.GetCurrChar(c) and (c <> ';') do begin
      case c of
        '[': begin
          if Scanner.GetCharAtRelPos(+1, c) and (c <> ':') then begin
            ParseLabel(CMD_SCOPE);
          end else begin
            Scanner.GotoNextChar;
          end; // .else
        end; // .case '['

        '(': begin
          ParseFuncName;
        end; // .case '('

        '^': begin
          Scanner.GotoNextChar;
          Scanner.FindChar('^');
          Scanner.GotoNextChar;
        end; // .case '^'
      end; // .switch c
    end; // .while

    if c = ';' then begin
      Scanner.GotoNextChar;
      Inc(CmdN);
    end; // .if
  end; // .procedure ParseCmd

begin
  Buf        := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  Scanner    := TextScan.TTextScanner.Create;
  Labels     := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  FuncAutoId := AdvErm.GetOrCreateAssocVar('Era.FuncAutoId');
  // * * * * * //
  Scanner.Connect(Script, #10);
  MarkedPos          := 1;
  CmdN               := 999000; // CmdN must not be used in instructions
  UnresolvedLabelInd := NO_LABEL;
  
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
              end; // .else
            end; // .case '!'

            '?': begin
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

      '[': begin
        if Scanner.GetCharAtRelPos(+1, c) and (c = ':') then begin
          ParseLabel(GLOBAL_SCOPE);
        end else begin
          Scanner.GotoNextChar;
        end; // .else
      end; // .case '['
    end; // .switch c
  end; // .while

  if MarkedPos = 1 then begin
    result := Script;
  end // .if
  else begin
    FlushMarked;
    ResolveLabels;
    result := Buf.ToText('');
  end; // .else
  // * * * * * //
  SysUtils.FreeAndNil(Buf);
  SysUtils.FreeAndNil(Scanner);
  SysUtils.FreeAndNil(Labels);
end; // .function PreprocessErm

function LoadScript (const ScriptName: string): boolean;
var
  ScriptContents: string;

begin
  result  :=  Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ScriptName, ScriptContents);
  
  if result then begin
    LoadScriptFromMemory(ScriptName, PreprocessErm(ScriptName, ScriptContents));
    LoadErtFile(ScriptName);
  end; // .if
end; // .function LoadScript

function GetFileList (const Dir, FileExt: string): {O} Lists.TStringList;
const
  PRIORITY_SEPARATOR  = ' ';
  DEFAULT_PRIORITY    = 0;

  FILENAME_NUM_TOKENS = 2;
  PRIORITY_TOKEN      = 0;
  FILENAME_TOKEN      = 1;

var
{O} Locator:        Files.TFileLocator;
{O} FileInfo:       Files.TFileItemInfo;
    FileName:       string;
    FileNameTokens: Utils.TArrayOfStr;
    Priority:       integer;
    TestPriority:   integer;
    i:              integer;
    j:              integer;

begin
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  result  :=  Lists.NewSimpleStrList;
  
  Locator.DirPath :=  Dir;
  Locator.InitSearch('*' + FileExt);
  
  while Locator.NotEnd do begin
    FileName :=  Locator.GetNextItem(Files.TItemInfo(FileInfo));

    if
      (SysUtils.AnsiLowerCase(SysUtils.ExtractFileExt(FileName)) = FileExt) and
      not FileInfo.IsDir
    then begin
      FileNameTokens :=  StrLib.ExplodeEx
      (
        FileName,
        PRIORITY_SEPARATOR,
        not StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        FILENAME_NUM_TOKENS
      );

      Priority  :=  DEFAULT_PRIORITY;
      
      if
        (Length(FileNameTokens) = FILENAME_NUM_TOKENS)  and
        (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority))
      then begin
        Priority  :=  TestPriority;
      end; // .if

      result.AddObj(FileName, Ptr(Priority));
    end; // .if

    SysUtils.FreeAndNil(FileInfo);
  end; // .while
  
  Locator.FinitSearch;

  (* Sort via insertion by Priority *)
  for i := 1 to result.Count - 1 do begin
    Priority  :=  integer(result.Values[i]);
    j         :=  i - 1;

    while (j >= 0) and (Priority > integer(result.Values[j])) do begin
      Dec(j);
    end; // .while

    result.Move(i, j + 1);
  end; // .for
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .function GetFileList

procedure RegisterErmEventNames;
begin
  AdvErm.GetOrCreateAssocVar('OnBeforeBattle').IntValue                  := Erm.TRIGGER_BA0;
  AdvErm.GetOrCreateAssocVar('OnAfterBattle').IntValue                   := Erm.TRIGGER_BA1;
  AdvErm.GetOrCreateAssocVar('OnBattleRound').IntValue                   := Erm.TRIGGER_BR;
  AdvErm.GetOrCreateAssocVar('OnBeforeBattleAction').IntValue            := Erm.TRIGGER_BG0;
  AdvErm.GetOrCreateAssocVar('OnAfterBattleAction').IntValue             := Erm.TRIGGER_BG1;
  AdvErm.GetOrCreateAssocVar('OnWanderingMonsterReach').IntValue         := Erm.TRIGGER_MW0;
  AdvErm.GetOrCreateAssocVar('OnWanderingMonsterDeath').IntValue         := Erm.TRIGGER_MW1;
  AdvErm.GetOrCreateAssocVar('OnMagicBasicResistance').IntValue          := Erm.TRIGGER_MR0;
  AdvErm.GetOrCreateAssocVar('OnMagicCorrectedResistance').IntValue      := Erm.TRIGGER_MR1;
  AdvErm.GetOrCreateAssocVar('OnDwarfMagicResistance').IntValue          := Erm.TRIGGER_MR2;
  AdvErm.GetOrCreateAssocVar('OnAdventureMapRightMouseClick').IntValue   := Erm.TRIGGER_CM0;
  AdvErm.GetOrCreateAssocVar('OnTownMouseClick').IntValue                := Erm.TRIGGER_CM1;
  AdvErm.GetOrCreateAssocVar('OnHeroScreenMouseClick').IntValue          := Erm.TRIGGER_CM2;
  AdvErm.GetOrCreateAssocVar('OnHeroesMeetScreenMouseClick').IntValue    := Erm.TRIGGER_CM3;
  AdvErm.GetOrCreateAssocVar('OnBattleScreenMouseClick').IntValue        := Erm.TRIGGER_CM4;
  AdvErm.GetOrCreateAssocVar('OnAdventureMapLeftMouseClick').IntValue    := Erm.TRIGGER_CM5;
  AdvErm.GetOrCreateAssocVar('OnEquipArt').IntValue                      := Erm.TRIGGER_AE0;
  AdvErm.GetOrCreateAssocVar('OnUnequipArt').IntValue                    := Erm.TRIGGER_AE1;
  AdvErm.GetOrCreateAssocVar('OnBattleMouseHint').IntValue               := Erm.TRIGGER_MM0;
  AdvErm.GetOrCreateAssocVar('OnTownMouseHint').IntValue                 := Erm.TRIGGER_MM1;
  AdvErm.GetOrCreateAssocVar('OnMp3MusicChange').IntValue                := Erm.TRIGGER_MP;
  AdvErm.GetOrCreateAssocVar('OnSoundPlay').IntValue                     := Erm.TRIGGER_SN;
  AdvErm.GetOrCreateAssocVar('OnBeforeAdventureMagic').IntValue          := Erm.TRIGGER_MG0;
  AdvErm.GetOrCreateAssocVar('OnAfterAdventureMagic').IntValue           := Erm.TRIGGER_MG1;
  AdvErm.GetOrCreateAssocVar('OnEnterTown').IntValue                     := Erm.TRIGGER_TH0;
  AdvErm.GetOrCreateAssocVar('OnLeaveTown').IntValue                     := Erm.TRIGGER_TH1;
  AdvErm.GetOrCreateAssocVar('OnBeforeBattleBeforeDataSend').IntValue    := Erm.TRIGGER_IP0;
  AdvErm.GetOrCreateAssocVar('OnBeforeBattleAfterDataReceived').IntValue := Erm.TRIGGER_IP1;
  AdvErm.GetOrCreateAssocVar('OnAfterBattleBeforeDataSend').IntValue     := Erm.TRIGGER_IP2;
  AdvErm.GetOrCreateAssocVar('OnAfterBattleAfterDataReceived').IntValue  := Erm.TRIGGER_IP3;
  AdvErm.GetOrCreateAssocVar('OnOpenCommanderWindow').IntValue           := Erm.TRIGGER_CO0;
  AdvErm.GetOrCreateAssocVar('OnCloseCommanderWindow').IntValue          := Erm.TRIGGER_CO1;
  AdvErm.GetOrCreateAssocVar('OnAfterCommanderBuy').IntValue             := Erm.TRIGGER_CO2;
  AdvErm.GetOrCreateAssocVar('OnAfterCommanderResurrect').IntValue       := Erm.TRIGGER_CO3;
  AdvErm.GetOrCreateAssocVar('OnBeforeBattleForThisPcDefender').IntValue := Erm.TRIGGER_BA50;
  AdvErm.GetOrCreateAssocVar('OnAfterBattleForThisPcDefender').IntValue  := Erm.TRIGGER_BA51;
  AdvErm.GetOrCreateAssocVar('OnBeforeBattleUniversal').IntValue         := Erm.TRIGGER_BA52;
  AdvErm.GetOrCreateAssocVar('OnAfterBattleUniversal').IntValue          := Erm.TRIGGER_BA53;
  AdvErm.GetOrCreateAssocVar('OnAfterLoadGame').IntValue                 := Erm.TRIGGER_GM0;
  AdvErm.GetOrCreateAssocVar('OnBeforeSaveGame').IntValue                := Erm.TRIGGER_GM1;
  AdvErm.GetOrCreateAssocVar('OnAfterErmInstructions').IntValue          := Erm.TRIGGER_PI;
  AdvErm.GetOrCreateAssocVar('OnCustomDialogEvent').IntValue             := Erm.TRIGGER_DL;
  AdvErm.GetOrCreateAssocVar('OnHeroMove').IntValue                      := Erm.TRIGGER_HM;
  AdvErm.GetOrCreateAssocVar('OnHeroGainLevel').IntValue                 := Erm.TRIGGER_HL;
  AdvErm.GetOrCreateAssocVar('OnSetupBattlefield').IntValue              := Erm.TRIGGER_BF;
  AdvErm.GetOrCreateAssocVar('OnMonsterPhysicalDamage').IntValue         := Erm.TRIGGER_MF1;
  AdvErm.GetOrCreateAssocVar('OnEverySecond').IntValue                   := Erm.TRIGGER_TL0;
  AdvErm.GetOrCreateAssocVar('OnEvery2Seconds').IntValue                 := Erm.TRIGGER_TL1;
  AdvErm.GetOrCreateAssocVar('OnEvery5Seconds').IntValue                 := Erm.TRIGGER_TL2;
  AdvErm.GetOrCreateAssocVar('OnEvery10Seconds').IntValue                := Erm.TRIGGER_TL3;
  AdvErm.GetOrCreateAssocVar('OnEveryMinute').IntValue                   := Erm.TRIGGER_TL4;
  AdvErm.GetOrCreateAssocVar('OnSavegameWrite').IntValue                 := Erm.TRIGGER_SAVEGAME_WRITE;
  AdvErm.GetOrCreateAssocVar('OnSavegameRead').IntValue                  := Erm.TRIGGER_SAVEGAME_READ;
  AdvErm.GetOrCreateAssocVar('OnKeyPressed').IntValue                    := Erm.TRIGGER_KEYPRESS;
  AdvErm.GetOrCreateAssocVar('OnOpenHeroScreen').IntValue                := Erm.TRIGGER_OPEN_HEROSCREEN;
  AdvErm.GetOrCreateAssocVar('OnCloseHeroScreen').IntValue               := Erm.TRIGGER_CLOSE_HEROSCREEN;
  AdvErm.GetOrCreateAssocVar('OnBattleStackObtainsTurn').IntValue        := Erm.TRIGGER_STACK_OBTAINS_TURN;
  AdvErm.GetOrCreateAssocVar('OnBattleRegeneratePhase').IntValue         := Erm.TRIGGER_REGENERATE_PHASE;
  AdvErm.GetOrCreateAssocVar('OnAfterSaveGame').IntValue                 := Erm.TRIGGER_AFTER_SAVE_GAME;
  AdvErm.GetOrCreateAssocVar('OnBeforeHeroInteraction').IntValue         := Erm.TRIGGER_BEFOREHEROINTERACT;
  AdvErm.GetOrCreateAssocVar('OnAfterHeroInteraction').IntValue          := Erm.TRIGGER_AFTERHEROINTERACT;
  AdvErm.GetOrCreateAssocVar('OnStackToStackDamage').IntValue            := Erm.TRIGGER_ONSTACKTOSTACKDAMAGE;
  AdvErm.GetOrCreateAssocVar('OnAICalcStackAttackEffect').IntValue       := Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT;
  AdvErm.GetOrCreateAssocVar('OnChat').IntValue                          := Erm.TRIGGER_ONCHAT;
  AdvErm.GetOrCreateAssocVar('OnGameEnter').IntValue                     := Erm.TRIGGER_ONGAMEENTER;
  AdvErm.GetOrCreateAssocVar('OnGameLeave').IntValue                     := Erm.TRIGGER_ONGAMELEAVE;
end; // .procedure RegisterErmEventNames

procedure LoadErmScripts;
const
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';
  JOINT_SCRIPT_NAME     = 'others.erm';

var
{O} ScriptBuilder:  StrLib.TStrBuilder;
{O} ScriptList:     Lists.TStringList;
    
    FileContents:   string;
    ForcedScripts:  Utils.TArrayOfStr;
    
    i:              integer;
  
begin
  ScriptBuilder :=  StrLib.TStrBuilder.Create;
  ScriptList    :=  nil;
  // * * * * * //
  (* Because Associative Memory from AdvErm is used more widely, we need to manually init it
     on game start. Tha lack of generic "GameStart" event leads us to solution of initiating
     memory here *)
  if not Erm.ZvsIsGameLoading^ then begin
    AdvErm.ResetMemory;
    AdvErm.GetOrCreateAssocVar('Era.FuncAutoId').IntValue := FUNC_AUTO_ID;
  end; // .if

  RegisterErmEventNames;  
  ScriptNames.Clear;
  
  for i := 0 to MAX_ERM_SCRIPTS_NUM - 1 do begin
    ErmScriptsInfo[i].State :=  SCRIPT_NOT_USED;
  end; // .for
  
  if Files.ReadFileContents(SCRIPTS_LIST_FILEPATH, FileContents) then begin
    ForcedScripts :=  StrLib.Explode(SysUtils.Trim(FileContents), #13#10);
    
    for i := 0 to Math.Min(High(ForcedScripts), MAX_ERM_SCRIPTS_NUM - 2) do begin
      LoadScript(SysUtils.AnsiLowerCase(ForcedScripts[i]));
    end; // .for
    
    for i := MAX_ERM_SCRIPTS_NUM - 1 to High(ForcedScripts) do begin
      if Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ForcedScripts[i], FileContents) then begin
        LoadErtFile(ForcedScripts[i]);
        
        if Length(FileContents) > MIN_ERM_SCRIPT_SIZE then begin
          FileContents  :=  PreprocessErm(ForcedScripts[i], FileContents);
          ScriptBuilder.AppendBuf(Length(FileContents) - 2, pointer(FileContents));
          ScriptBuilder.Append(#10);
        end; // .if
      end; // .if
    end; // .for
  end // .if
  else begin
    ScriptList  :=  GetFileList(ERM_SCRIPTS_PATH, '.erm');
    
    for i := 0 to Math.Min(ScriptList.Count - 1, MAX_ERM_SCRIPTS_NUM - 2) do begin
      LoadScript(SysUtils.AnsiLowerCase(ScriptList[i]));
    end; // .for
    
    for i := MAX_ERM_SCRIPTS_NUM - 1 to ScriptList.Count - 1 do begin
      if Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ScriptList[i], FileContents) then begin
        LoadErtFile(ScriptList[i]);
        
        if Length(FileContents) > MIN_ERM_SCRIPT_SIZE then begin
          ScriptBuilder.AppendBuf(Length(FileContents) - 2, pointer(FileContents));
          ScriptBuilder.Append(#10);
        end; // .if
      end; // .if
    end; // .for
  end; // .else
  
  ScriptBuilder.Append(#10#13);
  FileContents  :=  ScriptBuilder.BuildStr;
  
  if Length(FileContents) > MIN_ERM_SCRIPT_SIZE then begin
    LoadScriptFromMemory(JOINT_SCRIPT_NAME, FileContents);
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(ScriptBuilder);
  SysUtils.FreeAndNil(ScriptList);
end; // .procedure LoadErmScripts

procedure ReloadErm;
const
  SUCCESS_MES:  string  = '{~white}ERM is updated{~}';

begin
  if ErmTriggerDepth = 0 then begin
    ZvsClearErtStrings;
    ZvsClearErmScripts;
    ZvsIsGameLoading^ := true;
    LoadErmScripts;
    ZvsFindErm;
    Utils.CopyMem(Length(SUCCESS_MES) + 1, pointer(SUCCESS_MES), @z[1]);
    ExecErmCmd('IF:Lz1;');
  end; // .if
end; // .procedure ReloadErm

procedure ExtractErm;
var
  Res:        boolean;
  Mes:        string;
  ScriptPath: string;
  i:          integer;
  
begin
  Files.DeleteDir(EXTRACTED_SCRIPTS_PATH);
  Res :=  SysUtils.CreateDir(EXTRACTED_SCRIPTS_PATH);
  
  if not Res then begin
    Mes :=  '{~red}Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"{~}';
  end // .if
  else begin
    i :=  0;
    
    while Res and (i < MAX_ERM_SCRIPTS_NUM) do begin
      if ErmScripts[i] <> nil then begin
        ScriptPath  :=  EXTRACTED_SCRIPTS_PATH + '\' + ScriptNames[i];
        Res         :=  Files.WriteFileContents(ErmScripts[i] + #10#13, ScriptPath);
        if not Res then begin
          Mes :=  '{~red}Error writing to file "' + ScriptPath + '"{~}';
        end; // .if
      end; // .if
      
      Inc(i);
    end; // .while
  end; // .else
  
  if Res then begin
    Mes :=  '{~white}Scripts were successfully extracted{~}';
  end; // .if
  
  Utils.CopyMem(Length(Mes) + 1, pointer(Mes), @z[1]);
  ExecErmCmd('IF:Lz1;');
end; // .procedure ExtractErm

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
  EventArgs.BlockErmExecution := false;
  GameExt.FireEvent('OnBeforeTrigger', @EventArgs, sizeof(EventArgs));
  
  if EventArgs.BlockErmExecution then begin
    CurrErmEventID^ := TRIGGER_INVALID;
  end; // .if
  
  result := Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
end; // .function Hook_ProcessErm

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
  f[1]   := false;
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_ErmHeroArt_FindFreeSlot

function Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  f[1]   := true;
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

procedure OnSavegameWrite (Event: GameExt.PEvent); stdcall;
var
  NumScripts:     integer;
  ScriptName:     string;
  ScriptNameLen:  integer;
  i:              integer;
   
begin
  NumScripts  :=  ScriptNames.Count;
  Stores.WriteSavegameSection(sizeof(NumScripts), @NumScripts, SCRIPT_NAMES_SECTION);
  
  for i := 0 to NumScripts - 1 do begin
    ScriptName    :=  ScriptNames[i];
    ScriptNameLen :=  Length(ScriptName);
    Stores.WriteSavegameSection(sizeof(ScriptNameLen), @ScriptNameLen, SCRIPT_NAMES_SECTION);
    
    if ScriptNameLen > 0 then begin
      Stores.WriteSavegameSection(ScriptNameLen, pointer(ScriptName), SCRIPT_NAMES_SECTION);
    end; // .if
  end; // .for
end; // .procedure OnSavegameWrite

procedure OnSavegameRead (Event: GameExt.PEvent); stdcall;
var
  NumScripts:     integer;
  ScriptName:     string;
  ScriptNameLen:  integer;
  i:              integer;
   
begin
  ScriptNames.Clear;
  NumScripts  :=  0;
  Stores.ReadSavegameSection(sizeof(NumScripts), @NumScripts, SCRIPT_NAMES_SECTION);
  
  for i := 0 to NumScripts - 1 do begin
    Stores.ReadSavegameSection(sizeof(ScriptNameLen), @ScriptNameLen, SCRIPT_NAMES_SECTION);
    SetLength(ScriptName, ScriptNameLen);
    
    if ScriptNameLen > 0 then begin
      Stores.ReadSavegameSection(ScriptNameLen, pointer(ScriptName), SCRIPT_NAMES_SECTION);
    end; // .if
    
    ScriptNames.Add(ScriptName);
  end; // .for
end; // .procedure OnSavegameRead

function Hook_LoadErmScripts (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  LoadErmScripts;
  
  Context.RetAddr :=  Ptr($72CA82);
  result          :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_LoadErmScripts

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

function Hook_MR_N (c: Core.PHookContext): longbool; stdcall;
begin
  c.eax     := Heroes.GetStackIdByPos(Heroes.GetVal(MrMonPtr^, STACK_POS).v);
  c.RetAddr := Ptr($75DC76);
  result    := not Core.EXEC_DEF_CODE;
end; // .function Hook_MR_N

function Hook_CmdElse (Context: Core.PHookContext): longbool; stdcall;
var
  CmdFlags: PErmCmdConditions;
  
begin
  if ZvsTriggerIfs[ZvsTriggerIfsDepth^] = ZVS_TRIGGER_IF_TRUE then begin
    ZvsTriggerIfs[ZvsTriggerIfsDepth^] := ZVS_TRIGGER_IF_INACTIVE;
  end else if ZvsTriggerIfs[ZvsTriggerIfsDepth^] = ZVS_TRIGGER_IF_FALSE then begin
    CmdFlags := Ptr(pinteger(Context.EBP - $19C)^ * $29C + $212 + pinteger(Context.EBP - 4)^);
    ZvsTriggerIfs[ZvsTriggerIfsDepth^] := 1 - integer(ZvsCheckFlags(CmdFlags));
  end; // .elseif
  
  Context.RetAddr := Ptr($74CA64);
  result          := not Core.EXEC_DEF_CODE;
end; // .function Hook_CmdElse

function Hook_FU_P_RetValue (C: Core.PHookContext): longbool; stdcall;
var
{U} OldXVars: PErmXVars;
    Transfer: integer;
    i:        integer;
  
begin
  OldXVars := Ptr(C.EBP - $15E0);
  
  for i := Low(x^) to High(x^) do begin
    Transfer    := x[i];
    x[i]        := OldXVars[i];
    OldXVars[i] := Transfer;
  end; // .for

  C.RetAddr := Ptr($74CA64);
  result    := Core.EXEC_DEF_CODE;
end; // .function Hook_FU_P_RetValue

procedure OnBeforeErm (Event: GameExt.PEvent); stdcall;
var
  ResetEra: Utils.TProcedure;

begin
  ResetEra := Windows.GetProcAddress(GameExt.hAngel, 'ResetEra');
  {!} Assert(@ResetEra <> nil);
  ResetEra;
end; // .procedure OnBeforeErm

procedure OnBeforeWoG (Event: GameExt.PEvent); stdcall;
begin
  (* Remove WoG CM3 trigger *)
  Core.p.WriteDword($78C210, $887668);
end; // .procedure OnBeforeWoG

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
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
  
  (* New method of scripts loading *)
  Core.Hook(@Hook_LoadErmScripts, Core.HOOKTYPE_BRIDGE, 7, Ptr($72CA5E));
  Core.Hook(@Hook_LoadErtFile, Core.HOOKTYPE_BRIDGE, 5, Ptr($72C660));
  
  (* Disable connection between script number and option state in WoG options *)
  Core.p.WriteDataPatch($777E48, ['E9180100009090909090']);
  
  (* Fix CM3 trigger allowing to handle all clicks *)
  Core.ApiHook(@Hook_CM3, Core.HOOKTYPE_BRIDGE, Ptr($5B0255));
  Core.p.WriteDataPatch($5B02DD, ['8B47088D70FF']);

  (* !!el&[condition] support *)
  Core.ApiHook(@Hook_CmdElse, Core.HOOKTYPE_BRIDGE, Ptr($74CC0D));

  (* UN:J3 does not reset commanders or load scripts. New: it can be used to reset wog options *)
  Core.ApiHook(@Hook_UN_J3_End, Core.HOOKTYPE_BRIDGE, Ptr($733A85));

  (* Fix MR:N in !?MR1 !?MR2 *)
  Core.ApiHook(@Hook_MR_N, Core.HOOKTYPE_BRIDGE, Ptr($75DC67));
  Core.p.WriteDataPatch($439840, ['8B4D08909090']);
  Core.p.WriteDataPatch($439857, ['8B4D08909090']);

  (* Allow !!FU:P?x[n] syntax. *)
  Core.ApiHook(@Hook_FU_P_RetValue, Core.HOOKTYPE_BRIDGE, Ptr($72D04A));
  Core.p.WriteDataPatch($72D0A0, ['8D849520EAFFFF']);
  Core.p.WriteDataPatch($72D0B2, ['E9E70000009090909090']);
end; // .procedure OnAfterWoG

begin
  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := AssocArrays.NewSimpleAssocArr
  (
    Crypto.AnsiCRC32,
    AssocArrays.NO_KEY_PREPROCESS_FUNC
  );
  IsWoG^      :=  true;
  ScriptNames :=  Lists.NewSimpleStrList;
  SavedYVars  :=  Lists.NewStrictList(TYVars);
  
  GameExt.RegisterHandler(OnBeforeWoG,     'OnBeforeWoG');
  GameExt.RegisterHandler(OnAfterWoG,      'OnAfterWoG');
  GameExt.RegisterHandler(OnSavegameWrite, 'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead,  'OnSavegameRead');
  GameExt.RegisterHandler(OnBeforeErm,     'OnBeforeErm');
end.
