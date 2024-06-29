unit TextsExt;
{
DESCRIPTION:  Allows to extend heroes 3 *.txt files on the fly
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Utils, AssocArrays, TypeWrappers,
  Core, Heroes, GameExt, EventMan;

type
  (* IMPORT *)
  TString = TypeWrappers.TString;


(***) implementation (***)


var
{O} AddTexts: {O} AssocArrays.TAssocArray {OF TString};
    TxtSize:  integer; {UNSAFE, used in gapped function}


procedure AddLinesToText (const FileName, Lines: string);
var
{U} AddText:  TString;

begin
  AddText :=  AddTexts[FileName];
  // * * * * * //
  if AddText = nil then begin
    AddText[FileName] :=  TString.Create(Lines);
  end else begin
    AddText.Value :=  AddText.Value + Lines;
  end;
end; // .procedure AddLinesToText

function ExtendText (const TextName: string; var TxtSize: integer): pointer;
var
{U} AddText:  TString;

begin
  AddText :=  AddTexts[FileName];
  result  :=  nil;
  // * * * * * //
  if AddText <> nil then begin
    TxtSize :=  TxtSize + Length(AddText.Value);
    result  :=  Heroes.MAlloc(TxtSize);
    Utils.CopyMem(Length(AddText.Value), pointer(AddText.Value), Utils.PtrOfs(result, TxtSize));
  end else begin
    result  :=  Heroes.MAlloc(TxtSize);
  end;
end; // .function ExtendText

function Hook_LoadTextFromFile_BeforeLoad (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  TxtSize         :=  Context.EDI;
  Context.EAX     :=  ExtendText(Ptr(Context.EBX), TxtSize);
  Context.RetAddr :=  Ptr($55C110);
  result          :=  not Core.EXEC_DEF_CODE;
end;

function Hook_LoadTextFromFile_AfterLoad (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  TxtSize         :=  Context.EDI;
  Context.EAX     :=  ExtendText(Ptr(Context.EBX), TxtSize);
  Context.RetAddr :=  Ptr($55C110);
  result          :=  not Core.EXEC_DEF_CODE;
end;

procedure OnAfterWoG (Event: GameExt.PEvent);
begin
  Core.Hook(Ptr($55C106), Core.HOOKTYPE_BRIDGE, @Hook_LoadTextFromFile);
end;

begin
  AddTexts := AssocArrays.NewStrictAssocArr(TString);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
