UNIT Erm;
{
DESCRIPTION:  Native ERM support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, StrUtils, Math,
  Utils, Alg, Crypto, StrLib, Lists, DataLib, AssocArrays, TextScan,
  CFiles, Files, FilesEx, Ini,
  Core, PatchApi, Heroes, GameExt;

CONST
  ERM_SCRIPTS_SECTION     = 'Era.ErmScripts';
  ERM_SCRIPTS_PATH        = 'Data\s';
  EXTRACTED_SCRIPTS_PATH  = 'Data\ExtractedScripts';

  (* Erm command conditions *)
  LEFT_COND   = 0;
  RIGHT_COND  = 1;
  COND_AND    = 0;
  COND_OR     = 1;

  ERM_CMD_MAX_PARAMS_NUM = 16;
  MIN_ERM_SCRIPT_SIZE    = LENGTH('ZVSE'#13#10);
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
  TRIGGER_OB_POS    = INTEGER($10000000);
  TRIGGER_LE_POS    = INTEGER($20000000);
  TRIGGER_OB_LEAVE  = INTEGER($08000000);
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


TYPE
  (* IMPORT *)
  TAssocArray = AssocArrays.TAssocArray;
  TList       = DataLib.TList;
  TStrList    = DataLib.TStrList;
  TObjDict    = DataLib.TObjDict;

  TErmValType   = (ValNum, ValF, ValQuick, ValV, ValW, ValX, ValY, ValZ);
  TErmCheckType = (NO_CHECK, CHECK_GET, CHECK_EQUAL, CHECK_NOTEQUAL, CHECK_MORE, CHECK_LESS, 
                   CHECK_MOREEUQAL, CHECK_LESSEQUAL);

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
    Value: PCHAR;
    Len:   INTEGER;
  END; // .RECORD TErmString
  
  PErmCmdConditions = ^TErmCmdConditions;
  TErmCmdConditions = ARRAY [COND_AND..COND_OR, 0..15, LEFT_COND..RIGHT_COND] OF TErmCmdParam;

  PErmCmdParams = ^TErmCmdParams;
  TErmCmdParams = ARRAY [0..ERM_CMD_MAX_PARAMS_NUM - 1] OF TErmCmdParam;

  TErmCmdId = PACKED RECORD
    CASE BOOLEAN OF
      TRUE:  (Name: ARRAY [0..1] OF CHAR);
      FALSE: (Id: WORD);
  END; // .RECORD TErmCmdId
  
  PErmCmd = ^TErmCmd;
  TErmCmd = PACKED RECORD
    CmdId:        TErmCmdId;
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
  PWVars    = ^TWVars;
  TWVars    = ARRAY [0..255, 1..200] OF INTEGER;
  TErmZVar  = ARRAY [0..511] OF CHAR;
  PErmZVars = ^TErmZVars;
  TErmZVars = ARRAY [1..1000] OF TErmZVar;
  PErmNZVars = ^TErmNZVars;
  TErmNZVars = ARRAY [1..10] OF TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = ARRAY [1..100] OF INTEGER;
  PErmNYVars = ^TErmNYVars;
  TErmNYVars = ARRAY [1..100] OF INTEGER;
  PErmXVars = ^TErmXVars;
  TErmXVars = ARRAY [1..16] OF INTEGER;
  PErmFlags = ^TErmFlags;
  TErmFlags = ARRAY [1..1000] OF BOOLEAN;
  PErmEVars = ^TErmEVars;
  TErmEVars = ARRAY [1..100] OF SINGLE;
  PErmNEVars = ^TErmNEVars;
  TErmNEVars = ARRAY [1..100] OF SINGLE;
  PErmQuickVars = ^TErmQuickVars;
  TErmQuickVars = ARRAY [0..14] OF INTEGER;

  TZvsLoadErtFile = FUNCTION (Dummy, FileName: PCHAR): INTEGER; CDECL;
  TZvsShowMessage = FUNCTION (Mes: PCHAR; MesType: INTEGER; DummyZero: INTEGER): INTEGER; CDECL;
  TFireErmEvent   = FUNCTION (EventId: INTEGER): INTEGER; CDECL;
  TZvsDumpErmVars = PROCEDURE (Error, {n} ErmCmdPtr: PCHAR); CDECL;
  
  POnBeforeTriggerArgs = ^TOnBeforeTriggerArgs;
  TOnBeforeTriggerArgs = PACKED RECORD
    TriggerID:         INTEGER;
    BlockErmExecution: LONGBOOL;
  END; // .RECORD TOnBeforeTriggerArgs
  
  TYVars = CLASS
    Value: Utils.TArrayOfInteger;
  END; // .CLASS TYVars
  
  TWoGOptions = ARRAY [CURRENT_WOG_OPTIONS..GLOBAL_WOG_OPTIONS, 0..NUM_WOG_OPTIONS - 1] OF INTEGER;
  
  TMesType  =
  (
    MES_MES         = 1,
    MES_QUESTION    = 2,
    MES_RMB_HINT    = 4,
    MES_CHOOSE      = 7,
    MES_MAY_CHOOSE  = 10
  );
  
  TTextLineBounds = RECORD
    StartPos: INTEGER; // Starts from 1
    EndPos:   INTEGER;
  END; // .RECORD TTextLineBounds
  
  TErmScript = CLASS
   PRIVATE
        fFileName:    STRING;
        fContents:    STRING;
        fCrc32:       INTEGER;
    {n} fLineNumbers: ARRAY OF TTextLineBounds; // Loaded on demand

    PROCEDURE Init (CONST aFileName, aScriptContents: STRING; aCrc32: INTEGER);
    PROCEDURE UpdateLineNumbers;

   PUBLIC
    CONSTRUCTOR Create (CONST aFileName, aScriptContents: STRING; aCrc32: INTEGER); OVERLOAD;
    CONSTRUCTOR Create (CONST aFileName, aScriptContents: STRING); OVERLOAD;
    // Note: Uses hash checking instead of comparing contents of scripts
    FUNCTION  IsEqual (OtherScript: TErmScript): BOOLEAN;
    FUNCTION  StartAddr: {n} PCHAR;
    FUNCTION  EndAddr: {n} PCHAR;
    FUNCTION  AddrToLineNumber ({n} Addr: PCHAR; OUT LineNumber: INTEGER): BOOLEAN;
    
    PROPERTY FileName: STRING READ fFileName;
    PROPERTY Contents: STRING READ fContents;
    PROPERTY Crc32:    INTEGER READ fCrc32;
  END; // .CLASS TErmScript

  // Sorts list of Name => Priority: INTEGER
  TSortStrListByPriority = CLASS (Alg.TQuickSortAdapter)
    CONSTRUCTOR Create (aList: TStrList);
    FUNCTION  CompareItems (Ind1, Ind2: INTEGER): INTEGER; OVERRIDE;
    PROCEDURE SwapItems (Ind1, Ind2: INTEGER); OVERRIDE;
    PROCEDURE SavePivotItem (PivotItemInd: INTEGER); OVERRIDE;
    FUNCTION  CompareToPivot (Ind: INTEGER): INTEGER; OVERRIDE;
    PROCEDURE Sort;
    
   PRIVATE
    {U} List:      TStrList;
        PivotItem: INTEGER;
  END; // .CLASS TSortStrListByPriority

  TScriptAddrBounds = RECORD
        ScriptInd: INTEGER;
    {n} StartAddr: PCHAR; // First script byte or NIL
    {n} EndAddr:   PCHAR; // Last script byte or NIL
  END; // .RECORD TScriptAddrBounds
  
  TScriptsAddrBounds = ARRAY OF TScriptAddrBounds;
  
  // Sorts array of TScriptAddrBounds
  TSortScriptsAddrBounds = CLASS (Alg.TQuickSortAdapter)
    CONSTRUCTOR Create ({n} aArr: TScriptsAddrBounds);
    FUNCTION  CompareItems (Ind1, Ind2: INTEGER): INTEGER; OVERRIDE;
    PROCEDURE SwapItems (Ind1, Ind2: INTEGER); OVERRIDE;
    PROCEDURE SavePivotItem (PivotItemInd: INTEGER); OVERRIDE;
    FUNCTION  CompareToPivot (Ind: INTEGER): INTEGER; OVERRIDE;
    PROCEDURE Sort;
    
   PRIVATE
    {Un} fArr:      TScriptsAddrBounds;
         PivotItem: TScriptAddrBounds;
  END; // .CLASS TSortScriptsAddrBounds
  
  TScriptMan = CLASS
   PRIVATE
    {O} fScripts:           {O} TList {OF TErmScript};
    {O} fScriptIsLoaded:    {U} TDict {OF FileName => Ptr(BOOLEAN)};
    {n} fScriptsAddrBounds: TScriptsAddrBounds; // Loaded on demands
    
    FUNCTION  GetScriptCount: INTEGER;
    FUNCTION  GetScript (Ind: INTEGER): TErmScript;
    PROCEDURE UpdateScriptAddrBounds;
   
   PUBLIC
    CONSTRUCTOR Create;
    DESTRUCTOR  Destroy; OVERRIDE;
   
    PROCEDURE ClearScripts;
    PROCEDURE SaveScripts;
    FUNCTION  IsScriptLoaded (CONST ScriptName: STRING): BOOLEAN;
    FUNCTION  LoadScript (CONST ScriptName: STRING): BOOLEAN;
    PROCEDURE LoadScriptsFromSavedGame;
    PROCEDURE LoadScriptsFromDisk;
    PROCEDURE ReloadScriptsFromDisk;
    PROCEDURE ExtractScripts;
    FUNCTION  AddrToScriptNameAndLine ({n} Addr: PCHAR; OUT ScriptName: STRING; OUT Line: INTEGER)
                                      : BOOLEAN;

    PROPERTY ScriptCount: INTEGER READ GetScriptCount;
    PROPERTY Scripts[Ind: INTEGER]: TErmScript READ GetScript;
  END; // .CLASS TScriptMan

  
CONST
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
  IsWoG:            PLONGBOOL     = Ptr($803288);
  ErmEnabled:       PLONGBOOL     = Ptr($27F995C);
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


VAR
{O} ScriptMan:            TScriptMan;
    IgnoreInvalidCmdsOpt: BOOLEAN;
  
  
PROCEDURE ZvsProcessCmd (Cmd: PErmCmd);
PROCEDURE PrintChatMsg (CONST Msg: STRING);
FUNCTION  Msg
(
  CONST Mes:          STRING;
        MesType:      TMesType  = MES_MES;
        Pic1Type:     INTEGER   = NO_PIC_TYPE;
        Pic1SubType:  INTEGER   = 0;
        Pic2Type:     INTEGER   = NO_PIC_TYPE;
        Pic2SubType:  INTEGER   = 0;
        Pic3Type:     INTEGER   = NO_PIC_TYPE;
        Pic3SubType:  INTEGER   = 0
): INTEGER;
PROCEDURE ShowMessage (CONST Mes: STRING);
PROCEDURE ExecErmCmd (CONST CmdStr: STRING);
PROCEDURE ReloadErm; STDCALL;
PROCEDURE ExtractErm; STDCALL;
PROCEDURE FireErmEventEx (EventId: INTEGER; Params: ARRAY OF INTEGER);
FUNCTION  IsEraTrigger (TrigId: INTEGER): BOOLEAN;
FUNCTION  FindErmCmdBeginning ({n} CmdPtr: PCHAR): {n} PCHAR;
FUNCTION  GrabErmCmd ({n} CmdPtr: PCHAR): STRING;
FUNCTION  ErmCurrHero: {n} POINTER;
FUNCTION  ErmCurrHeroInd: INTEGER; // Or -1


(***) IMPLEMENTATION (***)
USES Stores;

CONST
  ERM_CMD_CACH_LIMIT = 16384;


VAR
{O} ErmScanner:       TextScan.TTextScanner;
{O} ErmCmdCache:      {O} TAssocArray {OF PErmCmd};
{O} SavedYVars:       {O} Lists.TList {OF TYVars};
    ErmTriggerDepth:  INTEGER = 0;
    ErmErrReported:   BOOLEAN = FALSE;
    
  FreezedWogOptionWogify: INTEGER = WOGIFY_ALL;


PROCEDURE PrintChatMsg (CONST Msg: STRING);
VAR
  PtrMsg: PCHAR;

BEGIN
  PtrMsg := PCHAR(Msg);
  // * * * * * //
  ASM
    PUSH PtrMsg
    PUSH $69D800
    MOV EAX, $553C40
    CALL EAX
    ADD ESP, $8
  END; // .ASM
END; // .PROCEDURE PrintChatMsg

FUNCTION Msg
(
  CONST Mes:          STRING;
        MesType:      TMesType  = MES_MES;
        Pic1Type:     INTEGER   = NO_PIC_TYPE;
        Pic1SubType:  INTEGER   = 0;
        Pic2Type:     INTEGER   = NO_PIC_TYPE;
        Pic2SubType:  INTEGER   = 0;
        Pic3Type:     INTEGER   = NO_PIC_TYPE;
        Pic3SubType:  INTEGER   = 0
): INTEGER;

VAR
  MesStr:     PCHAR;
  MesTypeInt: INTEGER;
  Res:        INTEGER;
  
BEGIN
  MesStr     := PCHAR(Mes);
  MesTypeInt := ORD(MesType);

  ASM
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
  END; // .ASM
  
  RESULT := MSG_RES_OK;
  
  IF MesType = MES_QUESTION THEN BEGIN
    IF Res = 30726 THEN BEGIN
      RESULT := MSG_RES_CANCEL;
    END // .IF
  END // .IF
  ELSE IF MesType IN [MES_CHOOSE, MES_MAY_CHOOSE] THEN BEGIN
    CASE Res OF 
      30729: RESULT := MSG_RES_LEFTPIC;
      30730: RESULT := MSG_RES_RIGHTPIC;
    ELSE
      RESULT := MSG_RES_CANCEL;
    END; // .SWITCH Res
  END; // .ELSEIF
END; // .FUNCTION Msg  
  
PROCEDURE ShowMessage (CONST Mes: STRING);
BEGIN
  Msg(Mes);
END; // .PROCEDURE ShowMessage
    
FUNCTION Ask (CONST Question: STRING): BOOLEAN;
BEGIN
  RESULT := Msg(Question, MES_QUESTION) = MSG_RES_OK;
END; // .FUNCTION Ask
    
FUNCTION GetErmValType (c: CHAR; OUT ValType: TErmValType): BOOLEAN;
BEGIN
  RESULT := TRUE;
  
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
    RESULT := FALSE;
    ShowMessage('Invalid ERM value type: "' + c + '"');
  END; // .SWITCH c
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
  // RET
END; // .PROCEDURE ZvsProcessCmd

PROCEDURE ClearErmCmdCache;
BEGIN
  WITH DataLib.IterateDict(ErmCmdCache) DO BEGIN
    WHILE IterNext DO BEGIN
      FreeMem(PErmCmd(IterValue).CmdHeader.Value);
      DISPOSE(PErmCmd(IterValue));
    END; // .WHILE
  END; // .WITH 

  ErmCmdCache.Clear;
END; // .PROCEDURE ClearErmCmdCache

PROCEDURE ExecSingleErmCmd (CONST CmdStr: STRING);
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
    RESULT := ErmScanner.GetCurrChar(c) AND (c IN NUMBER);

    IF RESULT THEN BEGIN
      IF c IN SIGNS THEN BEGIN
        StartPos := ErmScanner.Pos;
        ErmScanner.GotoNextChar;
        ErmScanner.SkipCharset(DIGITS);
        Token := ErmScanner.GetSubstrAtPos(StartPos, ErmScanner.Pos - StartPos);
      END // .IF
      ELSE BEGIN
        ErmScanner.ReadToken(DIGITS, Token);
      END; // .ELSE
      
      RESULT := SysUtils.TryStrToInt(Token, Num) AND ErmScanner.GetCurrChar(c) AND (c IN DELIMS);
    END; // .IF
  END; // .FUNCTION ReadNum
  
  FUNCTION ReadArg (OUT Arg: TErmCmdParam): BOOLEAN;
  VAR
    ValType: TErmValType;
    IndType: TErmValType;
  
  BEGIN
    RESULT := ErmScanner.GetCurrChar(c) AND GetErmValType(c, ValType);
    
    IF RESULT THEN BEGIN
      IndType := ValNum;
      
      IF ValType <> ValNum THEN BEGIN
        RESULT := ErmScanner.GotoNextChar AND ErmScanner.GetCurrChar(c) AND
                  GetErmValType(c, IndType);

        IF RESULT AND (IndType <> ValNum) THEN BEGIN
          ErmScanner.GotoNextChar;
        END; // .IF
      END; // .IF
      
      IF RESULT THEN BEGIN
        RESULT := ReadNum(Arg.Value);
        
        IF RESULT THEN BEGIN
          Arg.ValType := ORD(IndType) SHL 4 + ORD(ValType);
        END; // .IF
      END; // .IF
    END; // .IF
  END; // .FUNCTION ReadArg
  
BEGIN
  Cmd := ErmCmdCache[CmdStr];
  // * * * * * //
  Res := TRUE;
  
  IF Cmd = NIL THEN BEGIN
    NEW(Cmd);
    FillChar(Cmd^, SIZEOF(Cmd^), 0);
    ErmScanner.Connect(CmdStr, LINE_END_MARKER);
    Res     := ErmScanner.ReadToken(LETTERS, CmdName) AND (LENGTH(CmdName) = 2);
    NumArgs := 0;
    
    WHILE Res AND ErmScanner.GetCurrChar(c) AND (c <> ':') AND (NumArgs < ERM_CMD_MAX_PARAMS_NUM)
    DO BEGIN
      Res := ReadArg(Cmd.Params[NumArgs]) AND ErmScanner.GetCurrChar(c);

      IF Res THEN BEGIN
        INC(NumArgs);

        IF c = '/' THEN BEGIN
          ErmScanner.GotoNextChar;
        END; // .IF
      END; // .IF
    END; // .WHILE

    Res := Res AND ErmScanner.GotoNextChar;

    IF Res THEN BEGIN
      // Allocate memory, because ERM engine changes command contents during execution
      GetMem(Cmd.CmdHeader.Value, LENGTH(CmdStr) + 1);
      Utils.CopyMem(LENGTH(CmdStr) + 1, POINTER(CmdStr), Cmd.CmdHeader.Value);
      
      Cmd.CmdBody.Value := Utils.PtrOfs(Cmd.CmdHeader.Value, ErmScanner.Pos - 1);
      Cmd.CmdId.Name[0] := CmdName[1];
      Cmd.CmdId.Name[1] := CmdName[2];
      Cmd.NumParams     := NumArgs;
      Cmd.CmdHeader.Len := ErmScanner.Pos - 1;
      Cmd.CmdBody.Len   := LENGTH(CmdStr) - ErmScanner.Pos + 1;
      
      IF ErmCmdCache.ItemCount = ERM_CMD_CACH_LIMIT THEN BEGIN
        ClearErmCmdCache;
      END; // .IF
      
      ErmCmdCache[CmdStr] := Cmd;
    END; // .IF
  END; // .IF
  
  IF NOT Res THEN BEGIN
    ShowMessage('ExecErmCmd: Invalid command "' + CmdStr + '"');
  END // .IF
  ELSE BEGIN
    ZvsProcessCmd(Cmd);
  END; // .ELSE
END; // .PROCEDURE ExecSingleErmCmd

PROCEDURE ExecErmCmd (CONST CmdStr: STRING);
VAR
  Commands: Utils.TArrayOfString;
  i:        INTEGER;
   
BEGIN
  Commands := StrLib.ExplodeEx(CmdStr, ';', StrLib.INCLUDE_DELIM, NOT StrLib.LIMIT_TOKENS, 0);

  FOR i := 0 TO HIGH(Commands) - 1 DO BEGIN
    ExecSingleErmCmd(Commands[i]);
  END; // .FOR
END; // .PROCEDURE ExecErmCmd

PROCEDURE TErmScript.Init (CONST aFileName, aScriptContents: STRING; aCrc32: INTEGER);
BEGIN
  fFileName    := aFileName;
  fContents    := aScriptContents;
  fCrc32       := aCrc32;
  fLineNumbers := NIL;
END; // .PROCEDURE TErmScript.Init

CONSTRUCTOR TErmScript.Create (CONST aFileName, aScriptContents: STRING; aCrc32: INTEGER);
BEGIN
  Init(aFileName, aScriptContents, aCrc32);
END; // .CONSTRUCTOR TErmScript.Create

CONSTRUCTOR TErmScript.Create (CONST aFileName, aScriptContents: STRING);
BEGIN
  Init(aFileName, aScriptContents, Crypto.AnsiCRC32(aScriptContents));
END; // .CONSTRUCTOR TErmScript.Create

PROCEDURE TErmScript.UpdateLineNumbers;
VAR
  NumLines: INTEGER;
  i:        INTEGER;
   
BEGIN
  fLineNumbers := NIL;

  IF fContents <> '' THEN BEGIN
    ErmScanner.Connect(fContents, LINE_END_MARKER);
    ErmScanner.GotoLine(MAXLONGINT);
    NumLines := ErmScanner.LineN;
    SetLength(fLineNumbers, NumLines);
    ErmScanner.Connect(fContents, LINE_END_MARKER);

    FOR i := 0 TO NumLines - 1 DO BEGIN
      fLineNumbers[i].StartPos := ErmScanner.Pos;
      ErmScanner.GotoNextLine;
      fLineNumbers[i].EndPos   := ErmScanner.Pos - 1;
    END; // .FOR
  END; // .IF
END; // .PROCEDURE TErmScript.UpdateLineNumbers

FUNCTION TErmScript.IsEqual (OtherScript: TErmScript): BOOLEAN;
BEGIN
  {!} ASSERT(OtherScript <> NIL);
  RESULT := (Self = OtherScript) OR ((fFileName         = OtherScript.FileName)          AND
                                     (LENGTH(fContents) = LENGTH(OtherScript.fContents)) AND
                                     (fCrc32            = OtherScript.fCrc32));
END; // .FUNCTION TErmScript.IsEqual

FUNCTION TErmScript.StartAddr: {n} PCHAR;
BEGIN
  IF fContents = '' THEN BEGIN
    RESULT := NIL;
  END // .IF
  ELSE BEGIN
    RESULT := POINTER(fContents);
  END; // .ELSE
END; // .FUNCTION TErmScript.StartAddr

FUNCTION TErmScript.EndAddr: {n} PCHAR;
BEGIN
  IF fContents = '' THEN BEGIN
    RESULT := NIL;
  END // .IF
  ELSE BEGIN
    RESULT := Utils.PtrOfs(POINTER(fContents), LENGTH(fContents) - 1);
  END; // .ELSE
END; // .FUNCTION TErmScript.EndAddr

FUNCTION TErmScript.AddrToLineNumber ({n} Addr: PCHAR; OUT LineNumber: INTEGER): BOOLEAN;
VAR
  TargetPos:  INTEGER; // Starts from 1
  (* Binary search vars *)
  Left:       INTEGER;
  Right:      INTEGER;
  Middle:     INTEGER;

BEGIN
  RESULT := (fContents <> '') AND (Math.InRange(INT(Addr), INT(fContents),
                                                INT(fContents) + LENGTH(fContents) - 1));
  
  IF RESULT THEN BEGIN
    IF fLineNumbers = NIL THEN BEGIN
      UpdateLineNumbers;
    END; // .IF
    
    RESULT    := FALSE;
    TargetPos := INT(Addr) - INT(fContents) + 1;
    Left      := 0;
    Right     := HIGH(fLineNumbers);
    
    WHILE NOT RESULT AND (Left <= Right) DO BEGIN
      Middle := Left + (Right - Left) DIV 2;
      
      IF TargetPos < fLineNumbers[Middle].StartPos THEN BEGIN
        Right := Middle - 1;
      END // .IF
      ELSE IF TargetPos > fLineNumbers[Middle].EndPos THEN BEGIN
        Left := Middle + 1;
      END // .ELSEIF
      ELSE BEGIN
        // Add 1, because line number starts from 1
        LineNumber := Middle + 1;
        RESULT     := TRUE;
      END; // .ELSE
    END; // .WHILE
    
    {!} ASSERT(RESULT);
  END; // .IF
END; // .FUNCTION TErmScript.AddrToLineNumber

CONSTRUCTOR TSortStrListByPriority.Create (aList: TStrList);
BEGIN
  Self.List := aList;
END; // .CONSTRUCTOR TSortStrListByPriority.Create

FUNCTION TSortStrListByPriority.CompareItems (Ind1, Ind2: INTEGER): INTEGER;
BEGIN
  RESULT := Alg.IntCompare(INT(List.Values[Ind1]), INT(List.Values[Ind2]));
END; // .FUNCTION TSortStrListByPriority.CompareItems

PROCEDURE TSortStrListByPriority.SwapItems (Ind1, Ind2: INTEGER);
VAR
  TransferKey:   STRING;
  TransferValue: POINTER;
   
BEGIN
  // Transfer   := List[Ind1]
  TransferKey       := List[Ind1];
  TransferValue     := List.Values[Ind1];
  // List[Ind1] := List[Ind2]
  List[Ind1]        := List[Ind2];
  List.Values[Ind1] := List.Values[Ind2];
  // List[Ind2] := Transfer
  List[Ind2]        := TransferKey;
  List.Values[Ind2] := TransferValue;
END; // .PROCEDURE TSortStrListByPriority.SwapItems

PROCEDURE TSortStrListByPriority.SavePivotItem (PivotItemInd: INTEGER);
BEGIN
  PivotItem := INT(List.Values[PivotItemInd]);
END; // .PROCEDURE TSortStrListByPriority.SavePivotItem

FUNCTION TSortStrListByPriority.CompareToPivot (Ind: INTEGER): INTEGER;
BEGIN
  RESULT := Alg.IntCompare(INT(List.Values[Ind]), PivotItem);
END; // .FUNCTION TSortStrListByPriority.CompareToPivot

PROCEDURE TSortStrListByPriority.Sort;
BEGIN
  Alg.QuickSortEx(Self, 0, List.Count - 1);
END; // .PROCEDURE TSortStrListByPriority.Sort

CONSTRUCTOR TSortScriptsAddrBounds.Create ({n} aArr: TScriptsAddrBounds);
BEGIN
  Self.fArr := aArr;
END; // .CONSTRUCTOR TSortScriptsAddrBounds.Create

FUNCTION TSortScriptsAddrBounds.CompareItems (Ind1, Ind2: INTEGER): INTEGER;
BEGIN
  RESULT := Alg.PtrCompare(fArr[Ind1].StartAddr, fArr[Ind2].StartAddr);
END; // .FUNCTION TSortScriptsAddrBounds.CompareItems

PROCEDURE TSortScriptsAddrBounds.SwapItems (Ind1, Ind2: INTEGER);
VAR
  TransferItem: TScriptAddrBounds;
   
BEGIN
  TransferItem := fArr[Ind1];
  fArr[Ind1]   := fArr[Ind2];
  fArr[Ind2]   := TransferItem;
END; // .PROCEDURE TSortScriptsAddrBounds.SwapItems

PROCEDURE TSortScriptsAddrBounds.SavePivotItem (PivotItemInd: INTEGER);
BEGIN
  PivotItem := fArr[PivotItemInd];
END; // .PROCEDURE TSortScriptsAddrBounds.SavePivotItem

FUNCTION TSortScriptsAddrBounds.CompareToPivot (Ind: INTEGER): INTEGER;
BEGIN
  RESULT := Alg.PtrCompare(fArr[Ind].StartAddr, PivotItem.StartAddr);
END; // .FUNCTION TSortScriptsAddrBounds.CompareToPivot

PROCEDURE TSortScriptsAddrBounds.Sort;
BEGIN
  Alg.QuickSortEx(Self, 0, HIGH(fArr));
END; // .PROCEDURE TSortScriptsAddrBounds.Sort

FUNCTION IsEraTrigger (TrigId: INTEGER): BOOLEAN;
BEGIN
  RESULT := Math.InRange(TrigId, FIRST_ERA_TRIGGER, LAST_ERA_TRIGGER);
END; // .FUNCTION IsEraTrigger

FUNCTION LoadMapRscFile (CONST ResourcePath: STRING; OUT FileContents: STRING): BOOLEAN;
BEGIN
  RESULT := Files.ReadFileContents(GameExt.GetMapResourcePath(ResourcePath), FileContents);
END; // .FUNCTION LoadMapRscFile

CONSTRUCTOR TScriptMan.Create;
BEGIN
  fScripts        := DataLib.NewList(Utils.OWNS_ITEMS);
  fScriptIsLoaded := DataLib.NewDict(NOT Utils.OWNS_ITEMS, NOT DataLib.CASE_SENSITIVE);
END; // .CONSTRUCTOR TScriptMan.Create
  
DESTRUCTOR TScriptMan.Destroy;
BEGIN
  SysUtils.FreeAndNil(fScripts);
  SysUtils.FreeAndNil(fScriptIsLoaded);
  INHERITED;
END; // .DESTRUCTOR TScriptMan.Destroy
  
PROCEDURE TScriptMan.ClearScripts;
BEGIN
  GameExt.FireEvent('OnBeforeClearErmScripts', GameExt.NO_EVENT_DATA, 0);
  fScripts.Clear;
  fScriptIsLoaded.Clear;
  fScriptsAddrBounds := NIL;
END; // .PROCEDURE TScriptMan.ClearScripts

PROCEDURE TScriptMan.SaveScripts;
VAR
{U} Script: TErmScript;
    i:      INTEGER;
  
BEGIN
  Script := NIL;
  // * * * * * //
  WITH Stores.NewRider(ERM_SCRIPTS_SECTION) DO BEGIN
    WriteInt(fScripts.Count);

    FOR i := 0 TO fScripts.Count - 1 DO BEGIN
      Script := TErmScript(fScripts[i]);
      WriteStr(Script.FileName);
      WriteInt(Script.Crc32);
      WriteStr(Script.Contents);
    END; // .FOR
  END; // .WITH 
END; // .PROCEDURE TScriptMan.SaveScripts

PROCEDURE LoadErtFile (CONST ErmScriptName: STRING);
VAR
  ErtFilePath:        STRING;
  FilePathForZvsFunc: STRING;
   
BEGIN
  ErtFilePath := GameExt.GetMapResourcePath(ERM_SCRIPTS_PATH + '\'
                                            + SysUtils.ChangeFileExt(ErmScriptName, '.ert'));

  IF SysUtils.FileExists(ErtFilePath) THEN BEGIN
    FilePathForZvsFunc := '..\' + ErtFilePath;
    ZvsLoadErtFile('', PCHAR(FilePathForZvsFunc));
  END; // .IF
END; // .PROCEDURE LoadErtFile

FUNCTION TScriptMan.IsScriptLoaded (CONST ScriptName: STRING): BOOLEAN;
BEGIN
  RESULT := fScriptIsLoaded[ScriptName] <> NIL;
END; // .FUNCTION TScriptMan.IsScriptLoaded

FUNCTION TScriptMan.LoadScript (CONST ScriptName: STRING): BOOLEAN;
VAR
  ScriptContents: STRING;

BEGIN
  RESULT := (fScriptIsLoaded[ScriptName] = NIL) AND
            (LoadMapRscFile(ERM_SCRIPTS_PATH + '\' + ScriptName, ScriptContents));

  IF RESULT THEN BEGIN
    fScriptIsLoaded[ScriptName] := Ptr(1);
    fScripts.Add(TErmScript.Create(ScriptName, ScriptContents));
    LoadErtFile(ScriptName);
  END; // .IF
END; // .FUNCTION TScriptMan.LoadScript

PROCEDURE TScriptMan.LoadScriptsFromSavedGame;
VAR
{O} LoadedScripts:      {O} TList {OF TErmScript};
    NumScripts:         INTEGER;
    ScriptContents:     STRING;
    ScriptFileName:     STRING;
    ScriptCrc32:        INTEGER;
    ScriptSetsAreEqual: BOOLEAN;
    i:                  INTEGER;
  
BEGIN
  LoadedScripts := DataLib.NewList(Utils.OWNS_ITEMS);
  // * * * * * //
  WITH Stores.NewRider(ERM_SCRIPTS_SECTION) DO BEGIN
    NumScripts := ReadInt;

    FOR i := 1 TO NumScripts DO BEGIN
      ScriptFileName := ReadStr;
      ScriptCrc32    := ReadInt;
      ScriptContents := ReadStr;
      LoadedScripts.Add(TErmScript.Create(ScriptFileName, ScriptContents, ScriptCrc32));
    END; // .FOR
  END; // .WITH Stores.NewRider
  
  ScriptSetsAreEqual := fScripts.Count = LoadedScripts.Count;
  
  IF ScriptSetsAreEqual THEN BEGIN
    i := 0;
  
    WHILE (i < fScripts.Count) AND TErmScript(fScripts[i]).IsEqual(TErmScript(LoadedScripts[i]))
    DO BEGIN
      INC(i);
    END; // .WHILE
    
    ScriptSetsAreEqual := i = fScripts.Count;
  END; // .IF
  
  IF NOT ScriptSetsAreEqual THEN BEGIN
    Utils.Exchange(INT(fScripts), INT(LoadedScripts));
    ZvsFindErm;
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(LoadedScripts);
END; // .PROCEDURE TScriptMan.LoadScriptsFromSavedGame

PROCEDURE TScriptMan.LoadScriptsFromDisk;
CONST
  SCRIPTS_LIST_FILEPATH = ERM_SCRIPTS_PATH + '\load only these scripts.txt';
  SYSTEM_SCRIPTS_MASK   = '*.sys.erm';
  
VAR
(* Lists OF Priority: INTEGER *)
{O} FinalScriptList:        TStrList;
{O} ForcedScriptList:       TStrList;
{O} MapSystemScriptList:    TStrList;
{O} CommonSystemScriptList: TStrList;
{O} MapScriptList:          TStrList;
{O} CommonScriptList:       TStrList;

{O} ScriptListSorter: TSortStrListByPriority;
    FileContents:     STRING;
    i:                INTEGER;
    
  PROCEDURE GetPrioritiesFromScriptNames (List: TStrList);
  CONST
    PRIORITY_SEPARATOR = ' ';
    DEFAULT_PRIORITY   = 0;

    FILENAME_NUM_TOKENS = 2;
    PRIORITY_TOKEN      = 0;
    FILENAME_TOKEN      = 1;
  
  VAR
    FileNameTokens: Utils.TArrayOfString;
    Priority:       INTEGER;
    TestPriority:   INTEGER;
    i:              INTEGER;
     
  BEGIN
    FOR i := 0 TO List.Count - 1 DO BEGIN
      FileNameTokens := StrLib.ExplodeEx
      (
        List[i],
        PRIORITY_SEPARATOR,
        NOT StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        FILENAME_NUM_TOKENS
      );

      Priority := DEFAULT_PRIORITY;
      
      IF
        (LENGTH(FileNameTokens) = FILENAME_NUM_TOKENS) AND
        (SysUtils.TryStrToInt(FileNameTokens[PRIORITY_TOKEN], TestPriority))
      THEN BEGIN
        Priority := TestPriority;
      END; // .IF
      
      List.Values[i] := Ptr(Priority);
    END; // .FOR
  END; // .PROCEDURE GetPrioritiesFromScriptNames
   
BEGIN
  FinalScriptList         := DataLib.NewStrList(NOT Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  ForcedScriptList        := NIL;
  MapSystemScriptList     := NIL;
  CommonSystemScriptList  := NIL;
  MapScriptList           := NIL;
  CommonScriptList        := NIL;
  ScriptListSorter        := NIL;
  // * * * * * //
  ClearScripts;
  ZvsClearErtStrings;

  IF LoadMapRscFile(SCRIPTS_LIST_FILEPATH, FileContents) THEN BEGIN
    ForcedScriptList        := DataLib.NewStrListFromStrArr
    (
      StrLib.Explode(SysUtils.Trim(FileContents), #13#10),
      NOT Utils.OWNS_ITEMS,
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
  END // .IF
  ELSE BEGIN
    MapScriptList := FilesEx.GetFileList
    (
      GameExt.GetMapFolder + '\' + ERM_SCRIPTS_PATH + '\*.erm',
      Files.ONLY_FILES
    );
    CommonScriptList := FilesEx.GetFileList(ERM_SCRIPTS_PATH + '\*.erm', Files.ONLY_FILES);
    FilesEx.MergeFileLists(FinalScriptList, MapScriptList);
    FilesEx.MergeFileLists(FinalScriptList, CommonScriptList);
  END; // .ELSE
  
  GetPrioritiesFromScriptNames(FinalScriptList);
  ScriptListSorter := TSortStrListByPriority.Create(FinalScriptList);
  ScriptListSorter.Sort;
  
  FOR i := FinalScriptList.Count - 1 DOWNTO 0 DO BEGIN
    LoadScript(FinalScriptList[i]);
  END; // .FOR
  // * * * * * //
  SysUtils.FreeAndNil(FinalScriptList);
  SysUtils.FreeAndNil(ForcedScriptList);
  SysUtils.FreeAndNil(MapSystemScriptList);
  SysUtils.FreeAndNil(CommonSystemScriptList);
  SysUtils.FreeAndNil(MapScriptList);
  SysUtils.FreeAndNil(CommonScriptList);
  SysUtils.FreeAndNil(ScriptListSorter);
END; // .PROCEDURE TScriptMan.LoadScriptsFromDisk

(*FUNCTION PreprocessErm (CONST Script: STRING): STRING;
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
END; // .FUNCTION PreprocessErm*)

PROCEDURE TScriptMan.ReloadScriptsFromDisk;
CONST
  SUCCESS_MES: STRING = '{~white}ERM is updated{~}';

BEGIN
  IF ErmTriggerDepth = 0 THEN BEGIN
    ScriptMan.LoadScriptsFromDisk;
    ZvsIsGameLoading^ := TRUE;
    ZvsFindErm;
    Utils.CopyMem(LENGTH(SUCCESS_MES) + 1, POINTER(SUCCESS_MES), @z[1]);
    ExecErmCmd('IF:Lz1;');
  END; // .IF
END; // .PROCEDURE TScriptMan.ReloadScriptsFromDisk

PROCEDURE ReloadErm;
BEGIN
  ScriptMan.ReloadScriptsFromDisk;
END; // .PROCEDURE ReloadErm

PROCEDURE TScriptMan.ExtractScripts;
VAR
  Res:        BOOLEAN;
  Mes:        STRING;
  ScriptPath: STRING;
  i:          INTEGER;
  
BEGIN
  Files.DeleteDir(EXTRACTED_SCRIPTS_PATH);
  Res := SysUtils.CreateDir(EXTRACTED_SCRIPTS_PATH);
  
  IF NOT Res THEN BEGIN
    Mes :=  '{~red}Cannot recreate directory "' + EXTRACTED_SCRIPTS_PATH + '"{~}';
  END // .IF
  ELSE BEGIN
    i := 0;
    
    WHILE Res AND (i < fScripts.Count) DO BEGIN
      ScriptPath := EXTRACTED_SCRIPTS_PATH + '\' + TErmScript(fScripts[i]).FileName;
      Res        := Files.WriteFileContents(TErmScript(fScripts[i]).Contents, ScriptPath);
      
      IF NOT Res THEN BEGIN
        Mes := '{~red}Error writing to file "' + ScriptPath + '"{~}';
      END; // .IF
    
      INC(i);
    END; // .WHILE
  END; // .ELSE
  
  IF Res THEN BEGIN
    Mes := '{~white}Scripts were successfully extracted{~}';
  END; // .IF
  
  Utils.SetPcharValue(@z[1], Mes, SIZEOF(z[1]));
  ExecErmCmd('IF:Lz1;');
END; // .PROCEDURE TScriptMan.ExtractScripts

PROCEDURE ExtractErm;
BEGIN
  ScriptMan.ExtractScripts;
END; // .PROCEDURE ExtractErm

FUNCTION TScriptMan.GetScriptCount: INTEGER;
BEGIN
  RESULT := fScripts.Count;
END; // .FUNCTION TScriptMan.GetScriptCoun

FUNCTION TScriptMan.GetScript (Ind: INTEGER): TErmScript;
BEGIN
  {!} ASSERT(Math.InRange(Ind, 0, fScripts.Count - 1));
  RESULT := fScripts[Ind];
END; // .FUNCTION TScriptMan.GetScript

PROCEDURE TScriptMan.UpdateScriptAddrBounds;
VAR
{O} Sorter: TSortScriptsAddrBounds;
{U} Script: TErmScript;
    i:      INTEGER;
   
BEGIN
  Sorter := NIL;
  Script := NIL;
  // * * * * * //
  fScriptsAddrBounds := NIL;
  
  IF fScripts.Count > 0 THEN BEGIN
    SetLength(fScriptsAddrBounds, fScripts.Count);
    
    FOR i := 0 TO fScripts.Count - 1 DO BEGIN
      Script := TErmScript(fScripts[i]);
      fScriptsAddrBounds[i].ScriptInd := i;
      fScriptsAddrBounds[i].StartAddr := Script.StartAddr;
      fScriptsAddrBounds[i].EndAddr   := Script.EndAddr;
    END; // .FOR
    
    Sorter := TSortScriptsAddrBounds.Create(fScriptsAddrBounds);
    Sorter.Sort;
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(Sorter);
END; // .PROCEDURE TScriptMan.UpdateScriptAddrBounds

FUNCTION TScriptMan.AddrToScriptNameAndLine ({n} Addr: PCHAR; OUT ScriptName: STRING;
                                             OUT Line: INTEGER): BOOLEAN;
VAR
  ScriptInd: INTEGER;
  (* Binary search vars *)
  Left:      INTEGER;
  Right:     INTEGER;
  Middle:    INTEGER;

BEGIN
  RESULT := (Addr <> NIL) AND (fScripts.Count > 0);
  
  IF RESULT THEN BEGIN
    IF fScriptsAddrBounds = NIL THEN BEGIN
      UpdateScriptAddrBounds;
    END; // .IF
    
    RESULT := FALSE;
    Left   := 0;
    Right  := HIGH(fScriptsAddrBounds);
    
    WHILE NOT RESULT AND (Left <= Right) DO BEGIN
      Middle := Left + (Right - Left) DIV 2;
      
      IF CARDINAL(Addr) < CARDINAL(fScriptsAddrBounds[Middle].StartAddr) THEN BEGIN
        Right := Middle - 1;
      END // .IF
      ELSE IF CARDINAL(Addr) > CARDINAL(fScriptsAddrBounds[Middle].EndAddr) THEN BEGIN
        Left := Middle + 1;
      END // .ELSEIF
      ELSE BEGIN
        ScriptInd  := fScriptsAddrBounds[Middle].ScriptInd;
        {!} ASSERT(Math.InRange(ScriptInd, 0, fScripts.Count - 1));
        ScriptName := TErmScript(fScripts[ScriptInd]).FileName;
        RESULT     := TErmScript(fScripts[ScriptInd]).AddrToLineNumber(Addr, Line);
        {!} ASSERT(RESULT);
      END; // .ELSE
    END; // .WHILE
  END; // .IF
END; // .FUNCTION TScriptMan.AddrToScriptNameAndLine

PROCEDURE FireErmEventEx (EventId: INTEGER; Params: ARRAY OF INTEGER);
VAR
  i: INTEGER;

BEGIN
  {!} ASSERT(LENGTH(Params) <= LENGTH(GameExt.EraEventParams^));
  GameExt.EraSaveEventParams;
  
  FOR i := 0 TO HIGH(Params) DO BEGIN
    EraEventParams[i] := Params[i];
  END; // .FOR
  
  Erm.FireErmEvent(EventId);
  GameExt.EraRestoreEventParams;
END; // .PROCEDURE FireErmEventEx

FUNCTION FindErmCmdBeginning ({n} CmdPtr: PCHAR): {n} PCHAR;
BEGIN
  RESULT := CmdPtr;
  
  IF RESULT <> NIL THEN BEGIN
    DEC(RESULT);
    
    WHILE RESULT^ <> '!' DO BEGIN
      DEC(RESULT);
    END; // .WHILE
    
    INC(RESULT);
    
    IF RESULT^ = '#' THEN BEGIN
      // [!]#
      DEC(RESULT);
    END // .IF
    ELSE BEGIN
      // ![!]
      DEC(RESULT, 2);
    END; // .ELSE
  END; // .IF
END; // .FUNCTION FindErmCmdBeginning

FUNCTION GrabErmCmd ({n} CmdPtr: PCHAR): STRING;
VAR
  StartPos: PCHAR;
  EndPos:   PCHAR;

BEGIN
  IF CmdPtr <> NIL THEN BEGIN
    StartPos := FindErmCmdBeginning(CmdPtr);
    EndPos   := CmdPtr;
    
    REPEAT
      INC(EndPos);
    UNTIL (EndPos^ = ';') OR (EndPos^ = #0);
    
    IF EndPos^ = ';' THEN BEGIN
      INC(EndPos);
    END; // .IF
    
    RESULT := StrLib.ExtractFromPchar(StartPos, EndPos - StartPos);
  END; // .IF
END; // .FUNCTION GrabErmCmd

FUNCTION ErmCurrHero: {n} POINTER;
BEGIN
  RESULT := PPOINTER($27F9970)^;
END; // .FUNCTION ErmCurrHero

FUNCTION ErmCurrHeroInd: INTEGER; // Or -1
BEGIN
  IF ErmCurrHero <> NIL THEN BEGIN
    RESULT := PINTEGER(Utils.PtrOfs(ErmCurrHero, $1A))^;
  END // .IF
  ELSE BEGIN
    RESULT := -1;
  END; // .ELSE
END; // .FUNCTION 

FUNCTION Hook_ProcessErm (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
{O} YVars:     TYVars;
    EventArgs: TOnBeforeTriggerArgs;

BEGIN
  YVars := TYVars.Create;
  // * * * * * //
  IF CurrErmEventID^ >= Erm.TRIGGER_FU30000 THEN BEGIN
    SetLength(YVars.Value, LENGTH(y^));
    Utils.CopyMem(SIZEOF(y^), @y[1], @YVars.Value[0]);
  END; // .IF
  
  SavedYVars.Add(YVars); YVars := NIL;
  
  (* ProcessErm - initializing v996..v1000 variables *)
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
  EventArgs.TriggerID         := CurrErmEventID^;
  EventArgs.BlockErmExecution := FALSE;
  GameExt.FireEvent('OnBeforeTrigger', @EventArgs, SIZEOF(EventArgs));
  
  IF EventArgs.BlockErmExecution THEN BEGIN
    CurrErmEventID^ := TRIGGER_INVALID;
  END; // .IF
  
  RESULT := Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(YVars);
END; // .FUNCTION Hook_ProcessErm

FUNCTION Hook_FindErm_BeforeMainLoop (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  GLOBAL_EVENT_SIZE = 52;
  
VAR
  ResetEra: Utils.TProcedure;

BEGIN
  // Skip internal map events: GEp_ = GEp1 - [sizeof(_GlbEvent_) = 52]
  PINTEGER(Context.EBP - $3F4)^ := PINTEGER(PINTEGER(Context.EBP - $24)^ + $88)^
                                   - GLOBAL_EVENT_SIZE;
  ErmErrReported := FALSE;
  ResetEra       := Windows.GetProcAddress(GameExt.hAngel, 'ResetEra');
  {!} ASSERT(@ResetEra <> NIL);
  ResetEra;
  GameExt.FireEvent('OnBeforeErm', GameExt.NO_EVENT_DATA, 0);

  IF NOT ZvsIsGameLoading^ THEN BEGIN
    GameExt.FireEvent('OnBeforeErmInstructions', GameExt.NO_EVENT_DATA, 0);
  END; // .IF
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_FindErm_BeforeMainLoop

FUNCTION LoadWoGOptions (FilePath: PCHAR): BOOLEAN; ASSEMBLER;
ASM
  PUSH $0FA0
  PUSH $2771920
  PUSH EAX // FilePath
  MOV EAX, $773867
  CALL EAX
  ADD ESP, $0C
  CMP EAX, 0
  JGE @OK // ==>
  XOR EAX, EAX
  JMP @Done
@OK:
  XOR EAX, EAX
  INC EAX
@Done:
END; // .FUNCTION LoadWoGOptions

FUNCTION Hook_UN_J3_End (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  RESET_OPTIONS_COMMAND = ':clear:';
  WOG_OPTION_MAP_RULES  = 101;
  USE_SELECTED_RULES    = 2;

VAR
  WoGOptionsFile: STRING;
  i:              INTEGER;

BEGIN
  WoGOptionsFile := PCHAR(Context.ECX);

  IF WoGOptionsFile = RESET_OPTIONS_COMMAND THEN BEGIN
    FOR i := 0 TO High(WoGOptions[CURRENT_WOG_OPTIONS]) DO BEGIN
      WoGOptions[CURRENT_WOG_OPTIONS][i] := 0;
    END; // .FOR
    
    WoGOptions[CURRENT_WOG_OPTIONS][WOG_OPTION_MAP_RULES] := USE_SELECTED_RULES;
  END // .IF
  ELSE IF NOT LoadWoGOptions(PCHAR(WoGOptionsFile)) THEN BEGIN
    ShowMessage('Cannot load file with WoG options: ' + WoGOptionsFile);
  END; // .ELSEIF
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_UN_J3_End

FUNCTION Hook_FindErm_AfterMapScripts (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  GLOBAL_EVENT_SIZE = 52;

VAR
  ScriptIndPtr: PINTEGER;
  
BEGIN
  ScriptIndPtr := Ptr(Context.EBP - $18);
  // * * * * * //
  IF NOT ZvsIsGameLoading^ AND (ScriptIndPtr^ = 0) THEN BEGIN
    ZvsResetCommanders;
    ScriptMan.LoadScriptsFromDisk;
  END; // .IF
  
  IF ScriptIndPtr^ < ScriptMan.ScriptCount THEN BEGIN
    // M.m.i = 0
    PINTEGER(Context.EBP - $318)^ := 0;
    // M.m.s = ErmScript
    PPCHAR(Context.EBP - $314)^ := PCHAR(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // M.m.l = LENGTH(ErmScript)
    PINTEGER(Context.EBP - $310)^ := LENGTH(ScriptMan.Scripts[ScriptIndPtr^].Contents);
    // GEp_--; Process one more script
    DEC(PINTEGER(Context.EBP - $3F4)^, GLOBAL_EVENT_SIZE);
    INC(ScriptIndPtr^);
    // Jump to ERM header processing
    Context.RetAddr := Ptr($74A00C);
  END // .IF
  ELSE BEGIN
    // Jimp right after loop end
    Context.RetAddr := Ptr($74C5A7);
  END; // .ELSE
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_FindErm_AfterMapScripts

FUNCTION Hook_ProcessErm_End (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
{O} YVars: TYVars;

BEGIN
  YVars := SavedYVars.Pop;
  // * * * * * //
  GameExt.FireEvent('OnAfterTrigger', CurrErmEventID, SIZEOF(CurrErmEventID^));
  
  IF YVars.Value <> NIL THEN BEGIN
    Utils.CopyMem(SIZEOF(y^), @YVars.Value[0], @y[1]);
  END; // .IF
  
  DEC(ErmTriggerDepth);
  RESULT := Core.EXEC_DEF_CODE;
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

FUNCTION Hook_ErmHeroArt (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  RESULT := ((PINTEGER(Context.EBP - $E8)^ SHR 8) AND 7) = 0;
  
  IF NOT RESULT THEN BEGIN
    Context.RetAddr := Ptr($744B85);
  END; // .IF
END; // .FUNCTION Hook_ErmHeroArt

FUNCTION Hook_ErmHeroArt_FindFreeSlot (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  f[1]   := FALSE;
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_FindFreeSlot

FUNCTION Hook_ErmHeroArt_FoundFreeSlot (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  f[1]   := TRUE;
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_FoundFreeSlot

FUNCTION Hook_ErmHeroArt_DeleteFromBag (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  NUM_BAG_ARTS_OFFSET = +$3D4;
  HERO_PTR_OFFSET     = -$380;
  
VAR
  Hero: POINTER;

BEGIN
  Hero := PPOINTER(Context.EBP + HERO_PTR_OFFSET)^;
  DEC(PBYTE(Utils.PtrOfs(Hero, NUM_BAG_ARTS_OFFSET))^);
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmHeroArt_DeleteFromBag

FUNCTION Hook_DlgCallback (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  NO_CMD = 0;

BEGIN
  ErmDlgCmd^ := NO_CMD;
  RESULT     := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_DlgCallback

FUNCTION Hook_CM3 (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  MOUSE_STRUCT_ITEM_OFS = +$8;
  CM3_RES_ADDR          = $A6929C;

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
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_CM3

FUNCTION Hook_InvalidReceiver (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  MAX_CONTEXT_SIZE = 512;
  CMD_SIZE         = 4;

VAR
  CmdPtr:          PCHAR;
  CmdOffset:       INTEGER;
  Receiver:        STRING;
  CmdContext:      STRING;
  ScriptName:      STRING;
  Line:            INTEGER;
  PositionLocated: BOOLEAN;
    
BEGIN
  IF NOT IgnoreInvalidCmdsOpt THEN BEGIN
    CmdOffset       := PINTEGER(Context.EBP - $318)^;
    CmdPtr          := PCHAR(PINTEGER(Context.EBP - $314)^ + CmdOffset - CMD_SIZE);
    Receiver        := StrLib.ExtractFromPchar(CmdPtr, CMD_SIZE);
    CmdContext      := StrLib.ExtractFromPchar(CmdPtr, MAX_CONTEXT_SIZE);
    PositionLocated := ScriptMan.AddrToScriptNameAndLine(CmdPtr, ScriptName, Line);
    {!} ASSERT(PositionLocated);

    ShowMessage('{~red}Invalid receiver: {~gold}' + Receiver + '{~}{~}'#10'File: '
                + ScriptName + '. Line: ' + SysUtils.IntToStr(Line) + #10'Context:'#10#10 
                + CmdContext);
  END; // .IF
  
  Context.RetAddr := Ptr($74C550);
  RESULT          := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_InvalidReceiver

PROCEDURE OnEraSaveScripts (Event: GameExt.PEvent); STDCALL;
BEGIN
  ScriptMan.SaveScripts;
END; // .PROCEDURE OnEraSaveScripts

PROCEDURE OnEraLoadScripts (Event: GameExt.PEvent); STDCALL;
BEGIN
  ScriptMan.LoadScriptsFromSavedGame;
END; // .PROCEDURE OnEraLoadScripts

FUNCTION Hook_LoadErtFile (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  ARG_FILENAME = 2;

VAR
  FileName: PCHAR;
  
BEGIN
  FileName := PCHAR(PINTEGER(Context.EBP + 12)^);
  Utils.CopyMem(SysUtils.StrLen(FileName) + 1, FileName, Ptr(Context.EBP - $410));
  
  Context.RetAddr := Ptr($72C760);
  RESULT          := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_LoadErtFile

PROCEDURE ReportErmError (Error: STRING; {n} ErrCmd: PCHAR);
CONST
  CONTEXT_LEN = 00;

VAR
  PositionLocated: BOOLEAN;
  ScriptName:      STRING;
  Line:            INTEGER;
  Question:        STRING;
  
  
BEGIN
  ErmErrReported  := TRUE;
  PositionLocated := ScriptMan.AddrToScriptNameAndLine(ErrCmd, ScriptName, Line);
  
  IF Error = '' THEN BEGIN
    Error := 'Unknown error';
  END; // .IF
  
  Question := '{~r}' + Error + '{~}';
  
  IF PositionLocated THEN BEGIN
    Question := Question + #10'File: ' + ScriptName + '. Line: ' + IntToStr(Line);
  END; // .IF
  
  Question := Question + #10#10'{~g}' + GrabErmCmd(ErrCmd) + '{~}'
              + #10#10'Continue without saving ERM memory dump?';
  
  IF NOT Ask(Question) THEN BEGIN
    ZvsDumpErmVars(PCHAR(Error), ErrCmd);
  END; // .IF
END; // .PROCEDURE ReportErmError

FUNCTION Hook_MError (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  ReportErmError(PPCHAR(Context.EBP + 16)^, ErmErrCmdPtr^);
  Context.RetAddr := Ptr($712483);
  RESULT          := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_MError

FUNCTION Hook_ProcessErm_Start (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
  DisableExecution: BOOLEAN;

BEGIN
  PINTEGER(Context.EBP - $300)^ := 0; // M.i = 0, default code
  DisableExecution := FALSE;
  ErmErrReported   := FALSE;
  
  IF DisableExecution THEN BEGIN
    Context.RetAddr := Ptr($749702);
  END // .IF
  ELSE BEGIN
    Context.RetAddr := Ptr($741E58);
  END; // .ELSE
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ProcessErm_Start

FUNCTION Hook_ErmMess (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  IF NOT ErmErrReported THEN BEGIN
    // ERM cmd pos is m->m.s
    ReportErmError('', PPCHAR(PINTEGER(Context.EBP + 8)^ + 4)^);
  END; // .IF
  
  (* The command below was deactivated, because it leaded to multiple ERM messages *)
  // ++m->i;
  //INC(PINTEGER(PINTEGER(Context.EBP + 8)^)^);
  ErmErrReported  := FALSE;
  Context.RetAddr := Ptr($73DF03);
  RESULT          := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ErmMess

FUNCTION Hook_MR_N (c: Core.PContext): longbool; stdcall;
begin
  c.eax     := Heroes.GetStackIdByPos(Heroes.GetVal(MrMonPtr^, STACK_POS).v);
  c.RetAddr := Ptr($75DC76);
  result    := not Core.EXEC_DEF_CODE;
end; // .function Hook_MR_N

PROCEDURE OnBeforeWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  (* Remove WoG CM3 trigger *)
  Core.p.WriteDword($78C210, $887668);
END; // .PROCEDURE OnBeforeWoG

PROCEDURE OnAfterWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  (* Disable internal map scripts interpretation *)
  Core.ApiHook(@Hook_FindErm_BeforeMainLoop, Core.HOOKTYPE_BRIDGE, Ptr($749BBA));
  
  (* Remove default mechanism of loading [mapname].erm *)
  Core.p.WriteDataPatch($72CA8A, ['E90102000090909090']);
  
  (* Replace all points of wog option 5 (Wogify) access with FreezedWogOptionWogify *)
  Core.p.WriteDword($705601 + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($72CA2F + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($749BFE + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($749CAF + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($749D91 + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($749E2D + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($749E9D + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($74C6F5 + 2, INTEGER(@FreezedWogOptionWogify));
  Core.p.WriteDword($753F07 + 2, INTEGER(@FreezedWogOptionWogify));

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
END; // .PROCEDURE OnAfterWoG

BEGIN
  ScriptMan   := TScriptMan.Create;
  ErmScanner  := TextScan.TTextScanner.Create;
  ErmCmdCache := DataLib.NewDict(NOT Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  IsWoG^      := TRUE;
  ErmEnabled^ := TRUE;
  SavedYVars  := Lists.NewStrictList(TYVars);

  GameExt.RegisterHandler(OnBeforeWoG,      'OnBeforeWoG');
  GameExt.RegisterHandler(OnAfterWoG,       'OnAfterWoG');
  GameExt.RegisterHandler(OnEraSaveScripts, '$OnEraSaveScripts');
  GameExt.RegisterHandler(OnEraLoadScripts, '$OnEraLoadScripts');
END.
