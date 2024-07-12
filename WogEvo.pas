unit WogEvo;
(*
  WoG evolution/enhancement code, moving WoG parts to API.
*)


(***)  interface  (***)

uses
  SysUtils,

  Heroes;

type
  TIsCommanderIdFunc       = function (MonId: integer): TInt32Bool stdcall;
  TIsElixirOfLifeStackFunc = function (Stack: Heroes.PBattleStack): TInt32Bool stdcall;


function IsCommanderId (MonId: integer): TInt32Bool; stdcall;
function SetIsCommanderIdFunc (NewImpl: TIsCommanderIdFunc): {n} TIsCommanderIdFunc; stdcall;
function IsElixirOfLifeStack (Stack: Heroes.PBattleStack): TInt32Bool; stdcall;
function SetIsElixirOfLifeStackFunc (NewImpl: TIsElixirOfLifeStackFunc): {n} TIsElixirOfLifeStackFunc; stdcall;


(***)  implementation  (***)


var
  IsCommanderIdFunc:       TIsCommanderIdFunc;
  IsElixirOfLifeStackFunc: TIsElixirOfLifeStackFunc;


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

exports
  IsCommanderId,
  IsElixirOfLifeStack,
  SetIsCommanderIdFunc,
  SetIsElixirOfLifeStackFunc;

begin
  SetIsCommanderIdFunc(@ImplIsCommanderId);
  SetIsElixirOfLifeStackFunc(@StubIsElixirOfLifeStack);
end.