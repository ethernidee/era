UNIT CmdApp;
{
DESCRIPTION:  Provides new-style command line handling and some inter-process functions
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(*
New style command line: ArgName=ArgValue "Arg Name"="Arg Value"
Simple "ArgName" means ArgName:1.
Argument names are case-insensitive.
Duplicate arguments override the previous ones.
*)

(***)  INTERFACE  (***)
USES Windows, SysUtils, Utils, TypeWrappers, Crypto, TextScan, AssocArrays, Lists;

CONST
  (* RunProcess *)
  WAIT_PROCESS_END  = TRUE;


TYPE
  (* IMPORT *)
  TString = TypeWrappers.TString;


FUNCTION  ArgExists (CONST ArgName: STRING): BOOLEAN;
FUNCTION  GetArg (CONST ArgName: STRING): STRING;
PROCEDURE SetArg (CONST ArgName, NewArgValue: STRING);
FUNCTION  RunProcess (CONST ExeFilePath, ExeArgs, ExeCurrentDir: STRING; WaitEnd: BOOLEAN): BOOLEAN;


VAR
{O} Args:     {O} AssocArrays.TAssocArray {OF TString};
{O} ArgsList: Lists.TStringList;
    AppPath:  STRING;


(***)  IMPLEMENTATION  (***)


FUNCTION ArgExists (CONST ArgName: STRING): BOOLEAN;
BEGIN
  RESULT  :=  Args[ArgName] <> NIL;
END; // .FUNCTION ArgExists

FUNCTION GetArg (CONST ArgName: STRING): STRING;
VAR
{U} ArgValue: TString;

BEGIN
  ArgValue  :=  Args[ArgName];
  // * * * * * //
  IF ArgValue <> NIL THEN BEGIN
    RESULT  :=  ArgValue.Value;
  END // .IF
  ELSE BEGIN
    RESULT  :=  '';
  END; // .ELSE
END; // .FUNCTION GetArg

PROCEDURE SetArg (CONST ArgName, NewArgValue: STRING);
VAR
{U} ArgValue: TString;
  
BEGIN
  ArgValue  :=  Args[ArgName];
  // * * * * * //
  IF ArgValue <> NIL THEN BEGIN
    ArgValue.Value  :=  NewArgValue;
  END // .IF
  ELSE BEGIN
    Args[ArgName] :=  TString.Create(NewArgValue);
  END; // .ELSE
END; // .PROCEDURE SetArg

PROCEDURE ProcessArgs;
CONST
  BLANKS    = [#0..#32];
  ARGDELIM  = BLANKS + ['='];

VAR
{O} Scanner:  TextScan.TTextScanner;
    CmdLine:  STRING;
    ArgName:  STRING;
    ArgValue: STRING;
    SavedPos: INTEGER;
    c:        CHAR;

  FUNCTION ReadToken (CONST ArgDelimCharset: Utils.TCharSet): STRING;
  BEGIN
    {!} ASSERT(Scanner.GetCurrChar(c));
    
    IF c = '"' THEN BEGIN
      Scanner.GotoNextChar;
      Scanner.ReadTokenTillDelim(['"'], RESULT);
      Scanner.GotoNextChar;
    END // .IF
    ELSE BEGIN
      Scanner.ReadTokenTillDelim(ArgDelimCharset, RESULT);
    END; // .ELSE
  END; // .FUNCTION ReadToken

BEGIN
  Scanner :=  TextScan.TTextScanner.Create;
  // * * * * * //
  CmdLine   :=  System.CmdLine;
  Args      :=  AssocArrays.NewStrictAssocArr(TString);
  ArgsList  :=  Lists.NewSimpleStrList;
  Scanner.Connect(CmdLine, #10);
  
  IF Scanner.SkipCharset(BLANKS) THEN BEGIN
    AppPath :=  ReadToken(BLANKS);
  END; // .IF
  
  WHILE Scanner.SkipCharset(BLANKS) DO BEGIN
    SavedPos  :=  Scanner.Pos;
    ArgsList.Add(ReadToken(BLANKS));
    Scanner.GotoPos(SavedPos);
    ArgName :=  ReadToken(ARGDELIM);
    
    IF Scanner.GetCurrChar(c) THEN BEGIN
      IF c = '=' THEN BEGIN
        Scanner.GotoNextChar;
        ArgValue  :=  ReadToken(BLANKS);
      END // .IF
      ELSE BEGIN
        ArgValue  :=  '1';
      END; // .ELSE
    END // .IF
    ELSE BEGIN
      ArgValue  :=  '1';
    END; // .ELSE
    
    Args[ArgName] :=  TString.Create(ArgValue);
  END; // .WHILE
  // * * * * * //
  SysUtils.FreeAndNil(Scanner);
END; // .PROCEDURE ProcessArgs

FUNCTION RunProcess (CONST ExeFilePath, ExeArgs, ExeCurrentDir: STRING; WaitEnd: BOOLEAN): BOOLEAN;
CONST
  NO_APPLICATION_NAME         = NIL;
  DEFAULT_PROCESS_ATTRIBUTES  = NIL;
  DEFAULT_THREAD_ATTRIBUTES   = NIL;
  INHERIT_HANDLES             = TRUE;
  NO_CREATION_FLAGS           = 0;
  INHERIT_ENVIROMENT          = NIL;

VAR
  StartupInfo:  Windows.TStartupInfo;
  ProcessInfo:  Windows.TProcessInformation;
  
BEGIN
  FillChar(StartupInfo, SIZEOF(StartupInfo), #0);
  StartupInfo.cb  :=  SIZEOF(StartupInfo);
  RESULT          :=  Windows.CreateProcess
  (
    NO_APPLICATION_NAME,
    PCHAR('"' + ExeFilePath + '" ' + ExeArgs),
    DEFAULT_PROCESS_ATTRIBUTES,
    DEFAULT_THREAD_ATTRIBUTES,
    NOT INHERIT_HANDLES,
    NO_CREATION_FLAGS,
    INHERIT_ENVIROMENT,
    POINTER(ExeCurrentDir),
    StartupInfo,
    ProcessInfo
  );
  
  IF RESULT AND WaitEnd THEN BEGIN
    Windows.WaitForSingleObject(ProcessInfo.hProcess, Windows.INFINITE);
  END; // .IF
END; // .FUNCTION RunProcess

BEGIN
  ProcessArgs;
END.
