unit WogEvo;
(*
  WoG evolution/enhancement code, moving WoG parts to API.
*)


(***)  interface  (***)

uses
  SysUtils,

  Heroes;

type
  TIsCommanderIdFunc       = function (MonId: integer): boolean stdcall;
  TIsElixirOfLifeStackFunc = function (Stack: Heroes.PBattleStack): boolean stdcall;


function IsCommanderId (MonId: integer): boolean; stdcall;
function SetIsCommanderIdFunc (NewImpl: TIsCommanderIdFunc): {n} TIsCommanderIdFunc; stdcall;
function IsElixirOfLifeStack (Stack: Heroes.PBattleStack): boolean; stdcall;
function SetIsElixirOfLifeStackFunc (NewImpl: TIsElixirOfLifeStackFunc): {n} TIsElixirOfLifeStackFunc; stdcall;


(***)  implementation  (***)


var
  IsCommanderIdFunc:       TIsCommanderIdFunc;
  IsElixirOfLifeStackFunc: TIsElixirOfLifeStackFunc;


function IsCommanderId (MonId: integer): boolean; stdcall;
begin
  result := IsCommanderIdFunc(MonId);
end;

function SetIsCommanderIdFunc (NewImpl: TIsCommanderIdFunc): {n} TIsCommanderIdFunc; stdcall;
begin
  result            := @IsCommanderIdFunc;
  IsCommanderIdFunc := @NewImpl;
end;

function ImplIsCommanderId (MonId: integer): boolean; stdcall;
begin
  result := (MonId >= Heroes.MON_COMMANDER_FIRST_A) and (MonId <= Heroes.MON_COMMANDER_LAST_D);
end;

function IsElixirOfLifeStack (Stack: Heroes.PBattleStack): boolean; stdcall;
begin
  result := IsElixirOfLifeStackFunc(Stack);
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
  SetIsCommanderIdFunc(IsCommanderIdFunc);
end.