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
    Title:             pchar;                 // Top dialog title
    InputFieldLabel:   pchar;                 // If specified, user will be able to enter arbitrary text in input field
    ButtonsGroupLabel: pchar;                 // If specified, right buttons group will be displayed
    InputBuf:          pchar;                 // OUT. Field to write a pointer to a temporary buffer with user input. Copy this text to safe location immediately
    SelectedItem:      integer;               // OUT. Field to write selected item index to (0-3 for buttons, -1 for Cancel)
    ImagePaths:        array [0..3] of pchar; // All paths are relative to game root directory or custom absolute paths
    ImageHints:        array [0..3] of pchar;
    ButtonTexts:       array [0..3] of pchar;
    ButtonHints:       array [0..3] of pchar;
    ShowCancelBtn:     TInt32Bool;
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
  Setup.InputBuf     := '';
  result             := -1;
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