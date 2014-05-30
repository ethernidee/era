UNIT TextsExt;
{
DESCRIPTION:  Allows to extend heroes 3 *.txt files on the fly
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Utils, AssocArrays, TypeWrappers,
  Core, Heroes, GameExt;

TYPE
  (* IMPORT *)
  TString = TypeWrappers.TString;


(***) IMPLEMENTATION (***)


VAR
{O} AddTexts: {O} AssocArrays.TAssocArray {OF TString};
    TxtSize:  INTEGER; {UNSAFE, used in gapped function}


PROCEDURE AddLinesToText (CONST FileName, Lines: STRING);
VAR
{U} AddText:  TString;
   
BEGIN
  AddText :=  AddTexts[FileName];
  // * * * * * //
  IF AddText = NIL THEN BEGIN
    AddText[FileName] :=  TString.Create(Lines);
  END // .IF
  ELSE BEGIN
    AddText.Value :=  AddText.Value + Lines;
  END; // .ELSE
END; // .PROCEDURE AddLinesToText

FUNCTION ExtendText (CONST TextName: STRING; VAR TxtSize: INTEGER): POINTER;
VAR
{U} AddText:  TString;

BEGIN
  AddText :=  AddTexts[FileName];
  RESULT  :=  NIL;
  // * * * * * //
  IF AddText <> NIL THEN BEGIN
    TxtSize :=  TxtSize + LENGTH(AddText.Value);
    RESULT  :=  Heroes.MAlloc(TxtSize);
    Utils.CopyMem(LENGTH(AddText.Value), POINTER(AddText.Value), Utils.PtrOfs(RESULT, TxtSize));
  END // .IF
  ELSE BEGIN
    RESULT  :=  Heroes.MAlloc(TxtSize);
  END; // .ELSE
END; // .FUNCTION ExtendText

FUNCTION Hook_LoadTextFromFile_BeforeLoad (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  TxtSize         :=  Context.EDI;
  Context.EAX     :=  ExtendText(Ptr(Context.EBX), TxtSize);
  Context.RetAddr :=  Ptr($55C110);
  RESULT          :=  NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_LoadTextFromFile_BeforeLoad

FUNCTION Hook_LoadTextFromFile_AfterLoad (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  TxtSize         :=  Context.EDI;
  Context.EAX     :=  ExtendText(Ptr(Context.EBX), TxtSize);
  Context.RetAddr :=  Ptr($55C110);
  RESULT          :=  NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_LoadTextFromFile_AfterLoad

PROCEDURE OnAfterWoG (Event: GameExt.PEvent);
BEGIN
  Core.ApiHook(@Hook_LoadTextFromFile, Core.HOOKTYPE_BRIDGE, Ptr($55C106));
END; // .PROCEDURE OnAfterWoG

BEGIN
  AddTexts  :=  AssocArrays.NewStrictAssocArr(TString);
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
END.
