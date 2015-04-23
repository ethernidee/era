UNIT Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  SysUtils, Utils, Crypto, TextScan, AssocArrays, CFiles, Files, Ini,
  Lists, StrLib, Math, Windows,
  Core, Heroes, GameExt;

CONST
  SCRIPT_NAMES_SECTION  = 'Era.ScriptNames';
  ERM_SCRIPTS_PATH      = 'Data\s';

  (* Erm command conditions *)
  LEFT_COND   = 0;
  RIGHT_COND  = 1;
  COND_AND    = 0;
  COND_OR     = 1;

  ERM_CMD_MAX_PARAMS_NUM  = 16;
  MAX_ERM_SCRIPTS_NUM     = 100;
  MIN_ERM_SCRIPT_SIZE     = LENGTH('ZVSE'#13#10);

  (* Erm script state*)
  SCRIPT_NOT_USED = 0;
  SCRIPT_IS_USED  = 1;
  SCRIPT_IN_MAP   = 2;

  EXTRACTED_SCRIPTS_PATH  = 'Data\ExtractedScripts';

  AltScriptsPath: PCHAR     = Ptr($2730F68);
  CurrErmEventID: PINTEGER  = Ptr($27C1950);

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
  TRIGGER_OB_POS    = INTEGER($10000000);
  TRIGGER_LE_POS    = INTEGER($20000000);
  TRIGGER_OB_LEAVE  = INTEGER($08000000);
  TRIGGER_INVALID   = -1;
  
  (* Era Triggers *)
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
  
  ZvsProcessErm:  Utils.TProcedure  = Ptr($74C816);


TYPE
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

  TErmCmdParam = PACKED RECORD
    Value:    INTEGER;
    {
    [4 bits]  Type:             TErmValType;  // ex: y5;  y5 - type
    [4 bits]  IndexedPartType:  TErmValType;  // ex: vy5; y5 - indexed part;
    [3 bits]  CheckType:        TErmCheckType;
    }
    ValType:  INTEGER;
  END; // .RECORD TErmCmdParam

  TErmString = PACKED RECORD
    Value:  PCHAR;
    Len:    INTEGER;
  END; // .RECORD TErmString
  
  TGameString = PACKED RECORD
    Value:  PCHAR;
    Len:    INTEGER;
    Dummy:  INTEGER;
  END; // .RECORD TGameString
  
  TErmScriptInfo  = PACKED RECORD
    State:  INTEGER;
    Size:   INTEGER;
  END; // .RECORD TErmScriptInfo

  PErmScriptsInfo = ^TErmScriptsInfo;
  TErmScriptsInfo = ARRAY [0..MAX_ERM_SCRIPTS_NUM - 1] OF TErmScriptInfo;
  
  PScriptsPointers  = ^TScriptsPointers;
  TScriptsPointers  = ARRAY [0..MAX_ERM_SCRIPTS_NUM - 1] OF PCHAR;
  
  PErmCmdConditions = ^TErmCmdConditions;
  TErmCmdConditions = ARRAY [COND_AND..COND_OR, 0..15, LEFT_COND..RIGHT_COND] OF TErmCmdParam;

  PErmCmdParams = ^TErmCmdParams;
  TErmCmdParams = ARRAY [0..ERM_CMD_MAX_PARAMS_NUM - 1] OF TErmCmdParam;

  PErmCmd = ^TErmCmd;
  TErmCmd = PACKED RECORD
    Name:         ARRAY [0..1] OF CHAR;
    Disabled:     BOOLEAN;
    PrevDisabled: BOOLEAN;
    Conditions:   TErmCmdConditions;
    Structure:    POINTER;
    Params:       TErmCmdParams;
    NumParams:    INTEGER;
    CmdHeader:    TErmString; // ##:...
    CmdBody:      TErmString; // #^...^/...
  END; // .RECORD TErmCmd
  
  PErmVVars = ^TErmVVars;
  TErmVVars = ARRAY [1..10000] OF INTEGER;
  TErmZVar  = ARRAY [0..511] OF CHAR;
  PErmZVars = ^TErmZVars;
  TErmZVars = ARRAY [1..1000] OF TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = ARRAY [1..100] OF INTEGER;
  PErmXVars = ^TErmXVars;
  TErmXVars = ARRAY [1..16] OF INTEGER;
  PErmFlags = ^TErmFlags;
  TErmFlags = ARRAY [1..1000] OF BOOLEAN;
  PErmEVars = ^TErmEVars;
  TErmEVars = ARRAY [1..100] OF SINGLE;

  TZvsLoadErmScript = FUNCTION (ScriptId: INTEGER): INTEGER; CDECL;
  TZvsLoadErmTxt    = FUNCTION (IsNewLoad: INTEGER): INTEGER; CDECL;
  TZvsLoadErtFile   = FUNCTION (Dummy, FileName: PCHAR): INTEGER; CDECL;
  TZvsShowMessage   = FUNCTION (Mes: PCHAR; MesType: INTEGER; DummyZero: INTEGER): INTEGER; CDECL;
  TFireErmEvent     = FUNCTION (EventId: INTEGER): INTEGER; CDECL;
  
  POnBeforeTriggerArgs  = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs  = PACKED RECORD
    TriggerID:          INTEGER;
    BlockErmExecution:  LONGBOOL;
  END; // .RECORD TOnBeforeTriggerArgs
  
  TYVars = CLASS
    Value: Utils.TArrayOfInt;
  END; // .CLASS TYVars


CONST
  (* WoG vars *)
  v:  PErmVVars = Ptr($887668);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);

  ZvsIsGameLoading: PBOOLEAN          = Ptr($A46BC0);
  ErmScriptsInfo:   PErmScriptsInfo   = Ptr($A49270);
  ErmScripts:       PScriptsPointers  = Ptr($A468A0);
  IsWoG:            PLONGBOOL         = Ptr($803288);
  ErmDlgCmd:        PINTEGER          = Ptr($887658);

  (* WoG funcs *)
  ZvsFindErm:         Utils.TProcedure  = Ptr($749955);
  ZvsClearErtStrings: Utils.TProcedure  = Ptr($7764F2);
  ZvsClearErmScripts: Utils.TProcedure  = Ptr($750191);
  ZvsLoadErmScript:   TZvsLoadErmScript = Ptr($72C297);
  ZvsLoadErmTxt:      TZvsLoadErmTxt    = Ptr($72C8B1);
  ZvsLoadErtFile:     TZvsLoadErtFile   = Ptr($72C641);
  ZvsShowMessage:     TZvsShowMessage   = Ptr($70FB63);
  FireErmEvent:       TFireErmEvent     = Ptr($74CE30);


PROCEDURE ZvsProcessCmd (Cmd: PErmCmd);
PROCEDURE ShowMessage (CONST Mes: STRING);
PROCEDURE ExecErmCmd (CONST CmdStr: STRING); STDCALL;
PROCEDURE ReloadErm; STDCALL;
PROCEDURE ExtractErm; STDCALL;
  
  
(***) IMPLEMENTATION (***)
USES Stores;


CONST
  ERM_CMD_CACH_LIMIT  = 16384;


VAR
{O} ScriptNames:      Lists.TStringList;
{O} ErmScanner:       TextScan.TTextScanner;
{O} ErmCmdCach:       {O} TAssocArray {OF PErmCmd};
{O} SavedYVars:       {O} Lists.TList {OF TYVars};
    ErmTriggerDepth:  INTEGER = 0;


PROCEDURE ShowMessage (CONST Mes: STRING);
CONST
  MSG_OK  = 1;

BEGIN
  ZvsShowMessage(PCHAR(Mes), MSG_OK, 0);
END; // .PROCEDURE ShowMessage
    
FUNCTION GetErmValType (c: CHAR; OUT ValType: TErmValType): BOOLEAN;
BEGIN
  RESULT  :=  TRUE;
  
  CASE c OF
    '+', '-': ValType :=  ValNum;
    '0'..'9': ValType :=  ValNum;
    'f'..'t': ValType :=  ValQuick;
    'v':      ValType :=  ValV;
    'w':      ValType :=  ValW;
    'x':      ValType :=  ValX;
    'y':      ValType :=  ValY;
    'z':      ValType :=  ValZ;
  ELSE
    RESULT  :=  FALSE;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  END; // .SWITCH
END; // .FUNCTION GetErmValType

PROCEDURE ZvsProcessCmd (Cmd: PErmCmd); ASSEMBLER;
ASM
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
END; // .PROCEDURE ZvsProcessCmd

PROCEDURE ClearErmCmdCach;
VAR
{U} Cmd:  PErmCmd;
    Key:  STRING;
  
BEGIN
  Cmd :=  NIL;
  // * * * * * //
  ErmCmdCach.BeginIterate;
  
  WHILE ErmCmdCach.IterateNext(Key, POINTER(Cmd)) DO BEGIN
    FreeMem(Cmd.CmdHeader.Value);
    DISPOSE(Cmd); Cmd :=  NIL;
  END; // .WHILE
  
  ErmCmdCach.EndIterate;

  ErmCmdCach.Clear;
END; // .PROCEDURE ClearErmCmdCach

PROCEDURE ExecErmCmd (CONST CmdStr: STRING);
CONST
  LETTERS = ['A'..'Z'];
  DIGITS  = ['0'..'9'];
  SIGNS   = ['+', '-'];
  NUMBER  = DIGITS + SIGNS;
  DELIMS  = ['/', ':'];

VAR
{U} Cmd:      PErmCmd;
    CmdName:  STRING;
    NumArgs:  INTEGER;
    Res:      BOOLEAN;
    c:        CHAR;
    
  FUNCTION ReadNum (OUT Num: INTEGER): BOOLEAN;
  VAR
    StartPos: INTEGER;
    Token:    STRING;
    c:        CHAR;
  
  BEGIN
    RESULT  :=  ErmScanner.GetCurrChar(c) AND (c IN NUMBER);
    
    IF RESULT THEN BEGIN
      IF c IN SIGNS THEN BEGIN
        StartPos  :=  ErmScanner.Pos;
        ErmScanner.GotoNextChar;
        ErmScanner.SkipCharset(DIGITS);
        Token :=  ErmScanner.GetSubstrAtPos(StartPos, ErmScanner.Pos - StartPos);
      END // .IF
      ELSE BEGIN
        ErmScanner.ReadToken(DIGITS, Token);
      END; // .ELSE
      
      RESULT  :=
        SysUtils.TryStrToInt(Token, Num)  AND
        ErmScanner.GetCurrChar(c)         AND
        (c IN DELIMS);
    END; // .IF
  END; // .FUNCTION ReadNum
  
  FUNCTION ReadArg (OUT Arg: TErmCmdParam): BOOLEAN;
  VAR
    ValType:  TErmValType;
    IndType:  TErmValType;
  
  BEGIN
    RESULT  :=  ErmScanner.GetCurrChar(c) AND GetErmValType(c, ValType);
    
    IF RESULT THEN BEGIN
      IndType :=  ValNum;
      
      IF ValType <> ValNum THEN BEGIN
        RESULT  :=
          ErmScanner.GotoNextChar   AND
          ErmScanner.GetCurrChar(c) AND
          GetErmValType(c, IndType);
        
        IF RESULT AND (IndType <> ValNum) THEN BEGIN
          ErmScanner.GotoNextChar;
        END; // .IF
      END; // .IF
      IF RESULT THEN BEGIN
        RESULT  :=  ReadNum(Arg.Value);
        
        IF RESULT THEN BEGIN
          Arg.ValType :=  ORD(IndType) SHL 4 + ORD(ValType);
        END; // .IF
      END; // .IF
    END; // .IF
  END; // .FUNCTION ReadArg
  
BEGIN
  Cmd :=  ErmCmdCach[CmdStr];
  // * * * * * //
  Res :=  TRUE;
  
  IF Cmd = NIL THEN BEGIN
    NEW(Cmd);
    FillChar(Cmd^, SIZEOF(Cmd^), 0);
    ErmScanner.Connect(CmdStr, #10);
    Res     :=  ErmScanner.ReadToken(LETTERS, CmdName) AND (LENGTH(CmdName) = 2);
    NumArgs :=  0;
    
    WHILE
      Res                                 AND
      ErmScanner.GetCurrChar(c)           AND
      (c <> ':')                          AND
      (NumArgs < ERM_CMD_MAX_PARAMS_NUM)
    DO BEGIN
      Res :=  ReadArg(Cmd.Params[NumArgs]) AND ErmScanner.GetCurrChar(c);
      
      IF Res THEN BEGIN
        INC(NumArgs);
        
        IF c = '/' THEN BEGIN
          ErmScanner.GotoNextChar;
        END; // .IF
      END; // .IF
    END; // .WHILE
    
    Res :=  Res AND ErmScanner.GotoNextChar;
    
    IF Res THEN BEGIN
      GetMem(Cmd.CmdHeader.Value, LENGTH(CmdStr) + 1);
      Utils.CopyMem(LENGTH(CmdStr) + 1, POINTER(CmdStr), Cmd.CmdHeader.Value);
      
      Cmd.CmdBody.Value   :=  Utils.PtrOfs(Cmd.CmdHeader.Value, ErmScanner.Pos - 1);
      Cmd.Name[0]         :=  CmdName[1];
      Cmd.Name[1]         :=  CmdName[2];
      Cmd.NumParams       :=  NumArgs;
      Cmd.CmdHeader.Len   :=  ErmScanner.Pos - 1;
      Cmd.CmdBody.Len     :=  LENGTH(CmdStr) - ErmScanner.Pos + 1;
      
      IF ErmCmdCach.ItemCount = ERM_CMD_CACH_LIMIT THEN BEGIN
        ClearErmCmdCach;
      END; // .IF
      
      ErmCmdCach[CmdStr]  :=  Cmd;
    END; // .IF
  END; // .IF
  
  IF NOT Res THEN BEGIN
    ShowMessage('Invalid erm command "' + CmdStr + '"');
  END // .IF
  ELSE BEGIN
    ZvsProcessCmd(Cmd);
  END; // .ELSE
END; // .PROCEDURE ExecErmCmd

PROCEDURE LoadScriptFromMemory (CONST ScriptName, ScriptContents: STRING);
VAR
  ScriptInd:  INTEGER;
  ScriptSize: INTEGER;
  ScriptBuf:  PCHAR;

BEGIN
  ScriptInd   :=  ScriptNames.Count;
  {!} ASSERT(ScriptInd < MAX_ERM_SCRIPTS_NUM);
  ScriptSize  :=  LENGTH(ScriptContents);
  
  IF ScriptSize > MIN_ERM_SCRIPT_SIZE THEN BEGIN
    ErmScriptsInfo[ScriptInd].State :=  SCRIPT_IS_USED;
    ErmScriptsInfo[ScriptInd].Size  :=  ScriptSize;
    ScriptBuf                       :=  Heroes.MAlloc(ScriptSize - 1);      
    ErmScripts[ScriptInd]           :=  ScriptBuf;
    Utils.CopyMem(ScriptSize - 2, POINTER(ScriptContents), ScriptBuf);
    PBYTE(Utils.PtrOfs(ScriptBuf, ScriptSize - 2))^ :=  0;
    ScriptNames.Add(ScriptName);
  END; // .IF
END; // .PROCEDURE LoadScriptFromMemory

PROCEDURE LoadErtFile (CONST ErmScriptName: STRING);
VAR
  ErtFilePath:  STRING;
   
BEGIN
  ErtFilePath :=  ERM_SCRIPTS_PATH + '\' + SysUtils.ChangeFileExt(ErmScriptName, '.ert');
    
  IF SysUtils.FileExists(ErtFilePath) THEN BEGIN
    ZvsLoadErtFile('', PCHAR('..\' + ErtFilePath));
  END; // .IF
END; // .PROCEDURE LoadErtFile

FUNCTION PreprocessErm (CONST Script: STRING): STRING;
VAR
{O} StrBuilder: StrLib.TStrBuilder;
{O} Scanner:    TextScan.TTextScanner;
    StartPos:   INTEGER;
    c:          CHAR;

BEGIN
  StrBuilder  :=  StrLib.TStrBuilder.Create;
  Scanner     :=  TextScan.TTextScanner.Create;
  // * * * * * //
  Scanner.Connect(Script, #10);
  StartPos  :=  1;
  
  WHILE Scanner.FindChar('!') DO BEGIN
    IF
      Scanner.GetCharAtRelPos(+1, c) AND (c = '!') AND
      Scanner.GetCharAtRelPos(+2, c) AND (c = '!')
    THEN BEGIN
      StrBuilder.Append(Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos));
      Scanner.SkipChars('!');
      StartPos  :=  Scanner.Pos;
    END // .IF
    ELSE BEGIN
      Scanner.GotoRelPos(+2);
    END; // .ELSE
  END; // .WHILE
  
  IF StartPos = 1 THEN BEGIN
    RESULT  :=  Script;
  END // .IF
  ELSE BEGIN
    StrBuilder.Append(Scanner.GetSubstrAtPos(StartPos, Scanner.Pos - StartPos));
    RESULT  :=  StrBuilder.BuildStr;
  END; // .ELSE
  // * * * * * //
  SysUtils.FreeAndNil(StrBuilder);
  SysUtils.FreeAndNil(Scanner);
END; // .FUNCTION PreprocessErm

FUNCTION LoadScript (CONST ScriptName: STRING): BOOLEAN;
VAR
  ScriptContents: STRING;

BEGIN
  RESULT  :=  Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ScriptName, ScriptContents);
  
  IF RESULT THEN BEGIN
    LoadScriptFromMemory(ScriptName, PreprocessErm(ScriptContents));
    LoadErtFile(ScriptName);
  END; // .IF
END; // .FUNCTION LoadScript

FUNCTION GetFileList (CONST Dir, FileExt: STRING): {O} Lists.TStringList;
CONST
  PRIORITY_SEPARATOR  = ' ';
  DEFAULT_PRIORITY    = 0;

  FILENAME_NUM_TOKENS = 2;
  PRIORITY_TOKEN      = 0;
  FILENAME_TOKEN      = 1;

VAR
{O} Locator:        Files.TFileLocator;
{O} FileInfo:       Files.TFileItemInfo;
    FileName:       STRING;
    FileNameTokens: Utils.TArrayOfStr;
    Priority:       INTEGER;
    TestPriority:   INTEGER;
    i:              INTEGER;
    j:              INTEGER;

BEGIN
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  NIL;
  // * * * * * //
  RESULT  :=  Lists.NewSimpleStrList;
  
  Locator.DirPath :=  Dir;
  Locator.InitSearch('*' + FileExt);
  
  WHILE Locator.NotEnd DO BEGIN
    FileName :=  Locator.GetNextItem(Files.TItemInfo(FileInfo));

    IF
      (SysUtils.AnsiLowerCase(SysUtils.ExtractFileExt(FileName)) = FileExt) AND
      NOT FileInfo.IsDir
    THEN BEGIN
      FileNameTokens :=  StrLib.ExplodeEx
      (
        FileName,
        PRIORITY_SEPARATOR,
        NOT StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        FILENAME_NUM_TOKENS
      );

      Priority  :=  DEFAULT_PRIORITY;
      
      IF
        (LENGTH(FileNameTokens) = FILENAME_NUM_TOKENS)  AND
        (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority))
      THEN BEGIN
        Priority  :=  TestPriority;
      END; // .IF

      RESULT.AddObj(FileName, Ptr(Priority));
    END; // .IF

    SysUtils.FreeAndNil(FileInfo);
  END; // .WHILE
  
  Locator.FinitSearch;

  (* Sort via insertion by Priority *)
  FOR i := 1 TO RESULT.Count - 1 DO BEGIN
    Priority  :=  INTEGER(RESULT.Values[i]);
    j         :=  i - 1;

    WHILE (j >= 0) AND (Priority > INTEGER(RESULT.Values[j])) DO BEGIN
      DEC(j);
    END; // .WHILE

    RESULT.Move(i, j + 1);
  END; // .FOR
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .FUNCTION GetFileList

PROCEDURE LoadErmScripts;
CONST
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';
  JOINT_SCRIPT_NAME     = 'others.erm';

VAR
{O} ScriptBuilder:  StrLib.TStrBuilder;
{O} ScriptList:     Lists.TStringList;
    
    FileContents:   STRING;
    ForcedScripts:  Utils.TArrayOfStr;
    
    i:              INTEGER;
  
BEGIN
  ScriptBuilder :=  StrLib.TStrBuilder.Create;
  ScriptList    :=  NIL;
  // * * * * * //
  ScriptNames.Clear;
  
  FOR i := 0 TO MAX_ERM_SCRIPTS_NUM - 1 DO BEGIN
    ErmScriptsInfo[i].State :=  SCRIPT_NOT_USED;
  END; // .FOR
  
  IF Files.ReadFileContents(SCRIPTS_LIST_FILEPATH, FileContents) THEN BEGIN
    ForcedScripts :=  StrLib.Explode(SysUtils.Trim(FileContents), #13#10);
    
    FOR i := 0 TO Math.Min(HIGH(ForcedScripts), MAX_ERM_SCRIPTS_NUM - 2) DO BEGIN
      LoadScript(SysUtils.AnsiLowerCase(ForcedScripts[i]));
    END; // .FOR
    
    FOR i := MAX_ERM_SCRIPTS_NUM - 1 TO HIGH(ForcedScripts) DO BEGIN
      IF Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ForcedScripts[i], FileContents) THEN BEGIN
        LoadErtFile(ForcedScripts[i]);
        
        IF LENGTH(FileContents) > MIN_ERM_SCRIPT_SIZE THEN BEGIN
          FileContents  :=  PreprocessErm(FileContents);
          ScriptBuilder.AppendBuf(LENGTH(FileContents) - 2, POINTER(FileContents));
          ScriptBuilder.Append(#10);
        END; // .IF
      END; // .IF
    END; // .FOR
  END // .IF
  ELSE BEGIN
    ScriptList  :=  GetFileList(ERM_SCRIPTS_PATH, '.erm');
    
    FOR i := 0 TO Math.Min(ScriptList.Count - 1, MAX_ERM_SCRIPTS_NUM - 2) DO BEGIN
      LoadScript(SysUtils.AnsiLowerCase(ScriptList[i]));
    END; // .FOR
    
    FOR i := MAX_ERM_SCRIPTS_NUM - 1 TO ScriptList.Count - 1 DO BEGIN
      IF Files.ReadFileContents(ERM_SCRIPTS_PATH + '\' + ScriptList[i], FileContents) THEN BEGIN
        LoadErtFile(ScriptList[i]);
        
        IF LENGTH(FileContents) > MIN_ERM_SCRIPT_SIZE THEN BEGIN
          ScriptBuilder.AppendBuf(LENGTH(FileContents) - 2, POINTER(FileContents));
          ScriptBuilder.Append(#10);
        END; // .IF
      END; // .IF
    END; // .FOR
  END; // .ELSE
  
  ScriptBuilder.Append(#10#13);
  FileContents  :=  ScriptBuilder.BuildStr;
  
  IF LENGTH(FileContents) > MIN_ERM_SCRIPT_SIZE THEN BEGIN
    LoadScriptFromMemory(JOINT_SCRIPT_NAME, FileContents);
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(ScriptBuilder);
  SysUtils.FreeAndNil(ScriptList);
END; // .PROCEDURE LoadErmScripts

PROCEDURE ReloadErm;
CONST
  SUCCESS_MES:  STRING  = '{~white}ERM is updated{~}';

BEGIN
  IF ErmTriggerDepth = 0 THEN BEGIN
    ZvsClearErtStrings;
    ZvsClearErmScripts;  
    LoadErmScripts;
    
    ZvsIsGameLoading^ :=  TRUE;
    ZvsFindErm;
    Utils.CopyMem(LENGTH(SUCCESS_MES) + 1, POINTER(SUCCESS_MES), @z[1]);
    ExecErmCmd('IF:Lz1;');
  END; // .IF
END; // .PROCEDURE ReloadErm

PROCEDURE ExtractErm;
VAR
  Res:        BOOLEAN;
  Mes:        STRING;
  ScriptPath: STRING;
  i:          INTEGER;
  
BEGIN
  Files.DeleteDir(EXTRACTED_SCRIPTS_PATH);
  Res :=  SysUtils.CreateDir(EXTRACTED_SCRIPTS_PATH);
  
  IF NOT Res THEN BEGIN
    Mes :=  '{~red}Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"{~}';
  END // .IF
  ELSE BEGIN
    i :=  0;
    
    WHILE Res AND (i < MAX_ERM_SCRIPTS_NUM) DO BEGIN
      IF ErmScripts[i] <> NIL THEN BEGIN
        ScriptPath  :=  EXTRACTED_SCRIPTS_PATH + '\' + ScriptNames[i];
        Res         :=  Files.WriteFileContents(ErmScripts[i] + #10#13, ScriptPath);
        IF NOT Res THEN BEGIN
          Mes :=  '{~red}Error writing to file "' + ScriptPath + '"{~}';
        END; // .IF
      END; // .IF
      
      INC(i);
    END; // .WHILE
  END; // .ELSE
  
  IF Res THEN BEGIN
    Mes :=  '{~white}Scripts were successfully extracted{~}';
  END; // .IF
  
  Utils.CopyMem(LENGTH(Mes) + 1, POINTER(Mes), @z[1]);
  ExecErmCmd('IF:Lz1;');
END; // .PROCEDURE ExtractErm

FUNCTION Hook_ProcessErm (Context: Core.PHookContext): LONGBOOL; STDCALL;
VAR
{O} YVars:      TYVars;
    EventArgs:  TOnBeforeTriggerArgs;

BEGIN
  YVars :=  TYVars.Create;
  // * * * * * //
  
  IF CurrErmEventID^ >= Erm.TRIGGER_FU30000 THEN BEGIN
    SetLength(YVars.Value, LENGTH(y^));
    Utils.CopyMem(SIZEOF(y^), @y[1], @YVars.Value[0]);
  END; // .IF
  
  SavedYVars.Add(YVars); YVars  :=  NIL;
  
  (*  ProcessErm - initializing v996..v1000 variables  *)
  ASM
    CMP DWORD [$793C80], 0
    JL @L005
    MOV CL, BYTE [$793C80]
    MOV BYTE [$91F6C7], CL
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
    INC AL
    MOV BYTE [$91F6C7], AL
  @L013:
    MOV EAX, $710FD3
    CALL EAX
    PUSH EAX
    MOV EAX, $7118A3
    CALL EAX
    ADD ESP,4
    MOV BYTE [$91F6C6], AL
    MOV EDX, DWORD [$27F9964]
    MOV DWORD [$8885FC], EDX
    MOV EAX, DWORD [$27F9968]
    MOV DWORD [$888600], EAX
    MOV ECX, DWORD [$27F996C]
    MOV DWORD [$888604], ECX
  END; // .ASM
  
  INC(ErmTriggerDepth);
  EventArgs.TriggerID         :=  CurrErmEventID^;
  EventArgs.BlockErmExecution :=  FALSE;
  GameExt.FireEvent('OnBeforeTrigger', @EventArgs, SIZEOF(EventArgs));
  
  IF EventArgs.BlockErmExecution THEN BEGIN
    CurrErmEventID^ :=  TRIGGER_INVALID;
  END; // .IF
  
  RESULT  :=  Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
END; // .FUNCTION Hook_ProcessErm_End

FUNCTION Hook_ProcessErm_End (Context: Core.PHookContext): LONGBOOL; STDCALL;
VAR
{O} YVars:  TYVars;

BEGIN
  YVars :=  SavedYVars.Pop;
  // * * * * * //
  GameExt.FireEvent('OnAfterTrigger', CurrErmEventID, SIZEOF(CurrErmEventID^));
  
  IF YVars.Value <> NIL THEN BEGIN
    Utils.CopyMem(SIZEOF(y^), @YVars.Value[0], @y[1]);
  END; // .IF
  
  DEC(ErmTriggerDepth);
  RESULT  :=  Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
END; // .FUNCTION Hook_ProcessErm_End

{$W-}
PROCEDURE Hook_ErmCastleBuilding; ASSEMBLER;
ASM
  MOVZX EDX, BYTE [ECX + $150]
  MOVZX EAX, BYTE [ECX + $158]
  OR EDX, EAX
  PUSH $70E8A9
  // RET
END; // .PROCEDURE Hook_ErmCastleBuilding
{$W+}

FUNCTION Hook_ErmHeroArt (Context: Core.PHookContext): LONGBOOL; STDCALL;
BEGIN
  RESULT  :=  ((PINTEGER(Context.EBP - $E8)^ SHR 8) AND 7) = 0;
  
  IF NOT RESULT THEN BEGIN
    Context.RetAddr :=  Ptr($744B85);
  END; // .IF
END; // .FUNCTION Hook_ErmHeroArt

FUNCTION Hook_ErmHeroArt_FindFreeSlot (Context: Core.PHookContext): LONGBOOL; STDCALL;
BEGIN
  f[1]    :=  FALSE;
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_FindFreeSlot

FUNCTION Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookContext): LONGBOOL; STDCALL;
BEGIN
  f[1]    :=  TRUE;
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_FoundFreeSlot

FUNCTION Hook_ErmHeroArt_DeleteFromBag (Context: Core.PHookContext): LONGBOOL; STDCALL;
CONST
  NUM_BAG_ARTS_OFFSET = +$3D4;
  HERO_PTR_OFFSET     = -$380;
  
VAR
  Hero: POINTER;

BEGIN
  Hero  :=  PPOINTER(Context.EBP + HERO_PTR_OFFSET)^;
  DEC(PBYTE(Utils.PtrOfs(Hero, NUM_BAG_ARTS_OFFSET))^);
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_DeleteFromBag

FUNCTION Hook_DlgCallback (Context: Core.PHookContext): LONGBOOL; STDCALL;
CONST
  NO_CMD  = 0;

BEGIN
  ErmDlgCmd^  :=  NO_CMD;
  RESULT      :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_DlgCallback

FUNCTION Hook_CM3 (Context: Core.PHookContext): LONGBOOL; STDCALL;
CONST
  MOUSE_STRUCT_ITEM_OFS = +$8;
  CM3_RES_ADDR = $A6929C;

VAR
  SwapManager: INTEGER;
  MouseStruct: INTEGER;

BEGIN
  SwapManager := Context.EBX;
  MouseStruct := Context.EDI;
  
  ASM
    PUSHAD
    PUSH SwapManager
    POP [$27F954C]
    PUSH MouseStruct
    POP [$2773860]
    MOV EAX, $74FB3C
    CALL EAX
    POPAD
  END; // .ASM
  
  PINTEGER(Context.EDI + MOUSE_STRUCT_ITEM_OFS)^ := PINTEGER(CM3_RES_ADDR)^;
  RESULT :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_CM3

PROCEDURE OnSavegameWrite (Event: GameExt.PEvent); STDCALL;
VAR
  NumScripts:     INTEGER;
  ScriptName:     STRING;
  ScriptNameLen:  INTEGER;
  i:              INTEGER;
   
BEGIN
  NumScripts  :=  ScriptNames.Count;
  Stores.WriteSavegameSection(SIZEOF(NumScripts), @NumScripts, SCRIPT_NAMES_SECTION);
  
  FOR i := 0 TO NumScripts - 1 DO BEGIN
    ScriptName    :=  ScriptNames[i];
    ScriptNameLen :=  LENGTH(ScriptName);
    Stores.WriteSavegameSection(SIZEOF(ScriptNameLen), @ScriptNameLen, SCRIPT_NAMES_SECTION);
    
    IF ScriptNameLen > 0 THEN BEGIN
      Stores.WriteSavegameSection(ScriptNameLen, POINTER(ScriptName), SCRIPT_NAMES_SECTION);
    END; // .IF
  END; // .FOR
END; // .PROCEDURE OnSavegameWrite

PROCEDURE OnSavegameRead (Event: GameExt.PEvent); STDCALL;
VAR
  NumScripts:     INTEGER;
  ScriptName:     STRING;
  ScriptNameLen:  INTEGER;
  i:              INTEGER;
   
BEGIN
  ScriptNames.Clear;
  NumScripts  :=  0;
  Stores.ReadSavegameSection(SIZEOF(NumScripts), @NumScripts, SCRIPT_NAMES_SECTION);
  
  FOR i := 0 TO NumScripts - 1 DO BEGIN
    Stores.ReadSavegameSection(SIZEOF(ScriptNameLen), @ScriptNameLen, SCRIPT_NAMES_SECTION);
    SetLength(ScriptName, ScriptNameLen);
    
    IF ScriptNameLen > 0 THEN BEGIN
      Stores.ReadSavegameSection(ScriptNameLen, POINTER(ScriptName), SCRIPT_NAMES_SECTION);
    END; // .IF
    
    ScriptNames.Add(ScriptName);
  END; // .FOR
END; // .PROCEDURE OnSavegameRead

FUNCTION Hook_LoadErmScripts (Context: Core.PHookContext): LONGBOOL; STDCALL;
BEGIN
  LoadErmScripts;
  
  Context.RetAddr :=  Ptr($72CA82);
  RESULT          :=  NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_LoadErmScripts

FUNCTION Hook_LoadErtFile (Context: Core.PHookContext): LONGBOOL; STDCALL;
CONST
  ARG_FILENAME  = 2;

VAR
  FileName: PCHAR;
  
BEGIN
  FileName  :=  PCHAR(PINTEGER(Context.EBP + 12)^);
  Utils.CopyMem(SysUtils.StrLen(FileName) + 1, FileName, Ptr(Context.EBP - $410));
  
  Context.RetAddr :=  Ptr($72C760);
  RESULT          :=  NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_LoadErtFile

PROCEDURE OnBeforeErm (Event: GameExt.PEvent); STDCALL;
VAR
  ResetEra: Utils.TProcedure;

BEGIN
  ResetEra  :=  Windows.GetProcAddress(GameExt.hAngel, 'ResetEra');
  {!} ASSERT(@ResetEra <> NIL);
  ResetEra;
END; // .PROCEDURE OnBeforeErm

PROCEDURE OnBeforeWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  (* Remove WoG CM3 trigger *)
  PINTEGER($78C210)^ := $887668;
END; // .PROCEDURE OnBeforeWoG

PROCEDURE OnAfterWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
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
  PINTEGER($777E48    )^  :=  $000118E9;
  PINTEGER($777E48 + 4)^  :=  INTEGER($90909000);
  PWORD   ($777E48 + 8)^  :=  $9090;
  
  (* Fix CM3 trigger allowing to handle all clicks *)
  Core.ApiHook(@Hook_CM3, Core.HOOKTYPE_BRIDGE, Ptr($5B0255));
  PINTEGER($5B02DD)^ := INTEGER($8D08478B);
  PWORD($5B02DD + 4)^ := WORD($FF70);
END; // .PROCEDURE OnAfterWoG

BEGIN
  ErmScanner  :=  TextScan.TTextScanner.Create;
  ErmCmdCach  :=  AssocArrays.NewSimpleAssocArr
  (
    Crypto.AnsiCRC32,
    AssocArrays.NO_KEY_PREPROCESS_FUNC
  );
  IsWoG^      :=  TRUE;
  ScriptNames :=  Lists.NewSimpleStrList;
  SavedYVars  :=  Lists.NewStrictList(TYVars);
  
  GameExt.RegisterHandler(OnBeforeWoG, 'OnBeforeWoG');
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
  GameExt.RegisterHandler(OnSavegameWrite, 'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead, 'OnSavegameRead');
  GameExt.RegisterHandler(OnBeforeErm, 'OnBeforeErm');
END.
