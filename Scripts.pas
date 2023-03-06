unit Scripts;
{
DESCRIPTION:  Lua scripting support.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)

uses
  SysUtils, StrUtils, Utils, DlgMes, Core, Log, Files, FilesEx, DataLib,
  GameExt, EventMan, Lua;


const
  SCRIPTS_DIR  = 'Data\Lua';
  ENTRY_SCRIPT = 'init.lua';

type
  (* Import *)
  TStrList = DataLib.TStrList;

var
{O} L: PLua_State;


(***)  implementation  (***)


function OnLuaError (L: PLua_State): integer; cdecl;
var
  Error: string;

begin
  Error := lua_tostring(L, -1);
  Log.Write('Lua', 'Execution', Error);
  Core.FatalError(Error);
  result := 0;
end;

function OnLuaCallError (L: PLua_State): integer; cdecl;
begin
  result := 1;

  if not lua_isstring(L, 1) then begin
    exit;
  end;

  lua_getfield(L, TLUA_GLOBALSINDEX, 'debug');

  if not lua_istable(L, -1) then begin
    lua_pop(L, 1);
    exit;
  end;

  lua_getfield(L, -1, 'traceback');

  if not lua_isfunction(L, -1) then begin
    lua_pop(L, 2);
    exit;
  end;

  lua_pushvalue(L, 1);   (* pass error message *)
  lua_pushinteger(L, 2); (* skip this function and traceback *)
  lua_call(L, 2, 1);     (* call debug.traceback *)
end; // .function OnLuaCallError

procedure InitLua;
begin
  // Initialize Lua engine and setup error handler
  L := luaL_newstate();
  {!} Assert(L <> nil, 'Failed to initialize Lua engine');
  lua_atpanic(L, OnLuaError);
  luaL_openlibs(L);

  // Setup package search paths
  lua_getglobal(L, 'package');
  lua_pushstring(L, GameExt.GameDir + '\' + SCRIPTS_DIR + '\lib\?.lua');
  lua_setfield(L, -2, 'path');
  lua_pop(L, 1);

  lua_getglobal(L, 'package');
  lua_pushstring(L, GameExt.GameDir + '\' + SCRIPTS_DIR + '\dll\?.dll');
  lua_setfield(L, -2, 'cpath');
  lua_pop(L, 1);
end; // .procedure InitLua

procedure ExecuteLuaScript (const FilePath: string);
var
  Error:   string;
  ErrCode: integer;

begin
  lua_pushcfunction(L, OnLuaCallError);

  if luaL_loadfile(L, pchar(FilePath)) <> 0 then begin
    Core.FatalError('Failed to load and compile Lua script.'#13#10 + lua_tostring(L, -1));
  end;

  ErrCode := lua_pcall(L, 0, 0, 1);
  Error   := 'Out of memory error occured during execution of Lua script "' + FilePath + '"';

  if ErrCode = TLUA_ERRMEM then begin
    // Leave error message as is
  end else if ErrCode = TLUA_ERRERR then begin
    if (lua_isstring(L, -1)) and (lua_tostring(L, -1) = 'error in error handling') then begin
      Error := 'Stack overflow during Lua handler execution';
    end else begin
      Error := 'Error occured during Lua error handler execution';
    end;
  end else if ErrCode <> 0 then begin
    if lua_isstring(L, -1) then begin
      Error := 'Lua script error occured.'#13#10 + lua_tostring(L, -1);
    end else begin
      Error := 'Error occured during execution of Lua script "' + FilePath + '"';
    end;
  end; // .elseif

  if ErrCode <> 0 then begin
    Log.Write('Lua', 'Execution', Error);
    Core.FatalError(Error);
  end;

  lua_pop(L, 1);
end; // .procedure ExecuteLuaScript

procedure OnAfterLoadEraPlugins (Event: GameExt.PEvent); stdcall;
var
  EntryScriptPath: string;

begin
  EntryScriptPath := GameExt.GameDir + '\' + SCRIPTS_DIR + '\' + ENTRY_SCRIPT;

  if Files.FileExists(EntryScriptPath) then begin
    InitLua;
    ExecuteLuaScript(EntryScriptPath);
  end;

end;

begin
  EventMan.GetInstance.On('$OnAfterLoadEraPlugins', OnAfterLoadEraPlugins);
end.