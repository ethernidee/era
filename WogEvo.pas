unit WogEvo;
(*
  WoG evolution/enhancement code, moving WoG parts to API.
*)


(***)  interface  (***)

uses
  SysUtils,

  Heroes;

type
  (* Import *)
  TInt32Bool = Heroes.TInt32Bool;

  TIsCommanderIdFunc       = function (MonId: integer): TInt32Bool stdcall;
  TIsElixirOfLifeStackFunc = function (Stack: Heroes.PBattleStack): TInt32Bool stdcall;

  (*
    All pointers may be null. All fields must be writable by dialog processing routines and must be considered "dirty" after dialog processing.
  *)
  PMultiPurposeDlgSetup = ^TMultiPurposeDlgSetup;
  TMultiPurposeDlgSetup = packed record
    Title:            pchar;
    LeftSideCaption:  pchar;
    RightSideCaption: pchar;
    InputBuf:         pchar;   // External buffer to write user input string to or null
    InputBufSize:     integer; // Size of buffer to hold user input in bytes
    SelectedItem:     integer; // Field to write selected item index to (0-3 for buttons, -1 for Cancel)
    Pic1Path:         pchar;
    Pic2Path:         pchar;
    Pic3Path:         pchar;
    Pic4Path:         pchar;
    Pic1Hint:         pchar;
    Pic2Hint:         pchar;
    Pic3Hint:         pchar;
    Pic4Hint:         pchar;
    Btn1Text:         pchar;
    Btn2Text:         pchar;
    Btn3Text:         pchar;
    Btn4Text:         pchar;
    Btn1Hint:         pchar;
    Btn2Hint:         pchar;
    Btn3Hint:         pchar;
    Btn4Hint:         pchar;
    ShowCancelBtn:    TInt32Bool;
  end;

  TShowMultiPurposeDlgFunc = function (Setup: PMultiPurposeDlgSetup): integer; stdcall;


function IsCommanderId (MonId: integer): TInt32Bool; stdcall;
function SetIsCommanderIdFunc (NewImpl: TIsCommanderIdFunc): {n} TIsCommanderIdFunc; stdcall;
function IsElixirOfLifeStack (Stack: Heroes.PBattleStack): TInt32Bool; stdcall;
function SetIsElixirOfLifeStackFunc (NewImpl: TIsElixirOfLifeStackFunc): {n} TIsElixirOfLifeStackFunc; stdcall;
function ShowMultiPurposeDlg (Setup: PMultiPurposeDlgSetup): integer; stdcall;
function SetMultiPurposeDlgHandler (NewImpl: TShowMultiPurposeDlgFunc): {n} TShowMultiPurposeDlgFunc; stdcall;


(***)  implementation  (***)


var
  IsCommanderIdFunc:       TIsCommanderIdFunc;
  IsElixirOfLifeStackFunc: TIsElixirOfLifeStackFunc;
  ShowMultiPurposeDlgFunc: TShowMultiPurposeDlgFunc;


function IsCommanderId (MonId: integer): TInt32Bool; stdcall;
begin
  result := IsCommanderIdFunc(MonId);
end;

function SetIsCommanderIdFunc (NewImpl: TIsCommanderIdFunc): {n} TIsCommanderIdFunc; stdcall;
begin
  result            := @IsCommanderIdFunc;
  IsCommanderIdFunc := @NewImpl;
end;

function ImplIsCommanderId (MonId: integer): TInt32Bool; stdcall;
begin
  result := ord((MonId >= Heroes.MON_COMMANDER_FIRST_A) and (MonId <= Heroes.MON_COMMANDER_LAST_D));
end;

function IsElixirOfLifeStack (Stack: Heroes.PBattleStack): TInt32Bool; stdcall;
begin
  result := IsElixirOfLifeStackFunc(Stack);
end;

function StubIsElixirOfLifeStack (Stack: Heroes.PBattleStack): TInt32Bool; stdcall;
begin
  result := ord(false);
end;

function SetIsElixirOfLifeStackFunc (NewImpl: TIsElixirOfLifeStackFunc): {n} TIsElixirOfLifeStackFunc; stdcall;
begin
  result                  := @IsElixirOfLifeStackFunc;
  IsElixirOfLifeStackFunc := @NewImpl;
end;

function ShowMultiPurposeDlg (Setup: PMultiPurposeDlgSetup): integer; stdcall;
begin
  result := ShowMultiPurposeDlgFunc(Setup);
end;

function StubShowMultiPurposeDlg (Setup: PMultiPurposeDlgSetup): integer; stdcall;
begin
  Setup.SelectedItem := -1;

  if (Setup.InputBuf <> nil) and (Setup.InputBufSize > 0) then begin
    Setup.InputBuf^ := #0;
  end;

  result := -1;
end;

function SetMultiPurposeDlgHandler (NewImpl: TShowMultiPurposeDlgFunc): {n} TShowMultiPurposeDlgFunc; stdcall;
begin
  result                  := @ShowMultiPurposeDlgFunc;
  ShowMultiPurposeDlgFunc := @NewImpl;
end;

exports
  IsCommanderId,
  IsElixirOfLifeStack,
  SetIsCommanderIdFunc,
  SetIsElixirOfLifeStackFunc,
  SetMultiPurposeDlgHandler,
  ShowMultiPurposeDlg;

begin
  SetIsCommanderIdFunc(@ImplIsCommanderId);
  SetIsElixirOfLifeStackFunc(@StubIsElixirOfLifeStack);
  SetMultiPurposeDlgHandler(@StubShowMultiPurposeDlg);
end.