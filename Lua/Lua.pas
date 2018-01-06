{
  This are the pascal headers for LuaJIT, based on 
  
  'luajit.h',
  'lua.h',
  'lualib.h' and
  'lauxlib.h'.
   
  LuaJIT commit: cb886b58176dc5cd969f512d1a633f06d7120941
   
  Partially used the original FPC Headers by Lavergne Thomas and others.
}
{
  Original license for LuaJIT:
}
{*
** LuaJIT -- a Just-In-Time Compiler for Lua. http://luajit.org/
**
** Copyright (C) 2005-2014 Mike Pall. All rights reserved.
**
** Permission is hereby granted, free of charge, to any person obtaining
** a copy of this software and associated documentation files (the
** 'Software'), to deal in the Software without restriction, including
** without limitation the rights to use, copy, modify, merge, publish,
** distribute, sublicense, and/or sell copies of the Software, and to
** permit persons to whom the Software is furnished to do so, subject to
** the following conditions:
**
** The above copyright notice and this permission notice shall be
** included in all copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
** MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
** CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
** SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**
** [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
*}
{
  Original license for lua.h, lualib.h and lauxlib.h:
}
{******************************************************************************
* Copyright (C) 1994-2008 Lua.org, PUC-Rio.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* 'Software'), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************}
unit lua;

{$H+}

interface

uses
  SysUtils;

const
  LUAJIT_LibName = 'lua51.dll';

type
  size_t  = cardinal;
  Psize_t = ^size_t;

{ Lua }

const
  TLUA_VERSION     = 'Lua 5.1';
  TLUA_RELEASE     = 'Lua 5.1.4';
  TLUA_VERSION_NUM = 501;
  TLUA_COPYRIGHT   = 'Copyright (C) 1994-2008 Lua.org, PUC-Rio';
  TLUA_AUTHORS     = 'R. Ierusalimschy, L. H. de Figueiredo & W. Celes';

  {* mark for precompiled code (`<esc>Lua') *}
  TLUA_SIGNATURE   = '\033Lua';

  {* option for multiple returns in `lua_pcall' and `lua_call' *}
  TLUA_MULTRET     = (-1);

{*
** pseudo-indices
*}
const
  TLUA_REGISTRYINDEX = (-10000);
  TLUA_ENVIRONINDEX  = (-10001);
  TLUA_GLOBALSINDEX  = (-10002);
  
function lua_upvalueindex(i: Integer): Integer; inline;

const
{* thread status; 0 is OK *}
  TLUA_YIELD     = 1;
  TLUA_ERRRUN    = 2;
  TLUA_ERRSYNTAX = 3;
  TLUA_ERRMEM    = 4;
  TLUA_ERRERR    = 5;

type
  TLua_State = record
  end;
  PLua_State = ^TLua_State;
  TLua_CFunction = function(L: Plua_State): Integer; cdecl;
  PLua_CFunction = ^TLua_CFunction;

{*
** functions that read/write blocks when loading/dumping Lua chunks
*}
type
  TLua_Reader = function(L: Plua_State; ud: Pointer; sz: Psize_t): PChar; cdecl;
  TLua_Writer = function(L: Plua_State; const p: Pointer; sz: size_t; ud: Pointer): Integer; cdecl;

{*
** prototype for memory-allocation functions
*}
  TLua_Alloc = function(ud, ptr: Pointer; osize, nsize: size_t): Pointer; cdecl;

{*
** basic types
*}
const
  TLUA_TNONE          = (-1);

  TLUA_TNIL           = 0;
  TLUA_TBOOLEAN       = 1;
  TLUA_TLIGHTUSERDATA = 2;
  TLUA_TNUMBER        = 3;
  TLUA_TSTRING        = 4;
  TLUA_TTABLE         = 5;
  TLUA_TFUNCTION      = 6;
  TLUA_TUSERDATA      = 7;
  TLUA_TTHREAD        = 8;

{* minimum Lua stack available to a C function *}
  TLUA_MINSTACK       = 20;

type
{* Type of Numbers in Lua *}
  TLua_Number  = Double;
  TLua_Integer = integer;

{*
** state manipulation
*}
function lua_newstate(f: TLua_Alloc; ud: Pointer): Plua_state; cdecl; external LUAJIT_LIBNAME;
procedure lua_close(L: Plua_State); cdecl; external LUAJIT_LIBNAME;
function lua_newthread(L: Plua_State): Plua_State; cdecl; external LUAJIT_LIBNAME;

function lua_atpanic(L: Plua_State; panicf: TLua_CFunction): TLua_CFunction; cdecl; external LUAJIT_LIBNAME; 

{*
** basic stack manipulation
*}
function lua_gettop(L: Plua_State): Integer; cdecl; external LUAJIT_LIBNAME; 
procedure lua_settop(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME; 
procedure lua_pushvalue(L: Plua_State; Idx: Integer); cdecl; external LUAJIT_LIBNAME; 
procedure lua_remove(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME; 
procedure lua_insert(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME; 
procedure lua_replace(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME; 
function lua_checkstack(L: Plua_State; sz: Integer): LongBool; cdecl; external LUAJIT_LIBNAME; 

procedure lua_xmove(from, to_: Plua_State; n: Integer); cdecl; external LUAJIT_LIBNAME;            

{*
** access functions (stack -> C)
*}
  
function lua_isnumber(L: Plua_State; idx: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_isstring(L: Plua_State; idx: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_iscfunction(L: Plua_State; idx: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_isuserdata(L: Plua_State; idx: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_type(L: Plua_State; idx: Integer): Integer; cdecl; external LUAJIT_LIBNAME;            
function lua_typename(L: Plua_State; tp: Integer): PChar; cdecl; external LUAJIT_LIBNAME;            

function lua_equal(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_rawequal(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_lessthan(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            

function lua_tonumber(L: Plua_State; idx: Integer): TLua_Number; cdecl; external LUAJIT_LIBNAME;            
function lua_tointeger(L: Plua_State; idx: Integer): TLua_Integer; cdecl; external LUAJIT_LIBNAME;            
function lua_toboolean(L: Plua_State; idx: Integer): LongBool; cdecl; external LUAJIT_LIBNAME;            
function lua_tolstring(L: Plua_State; idx: Integer; len: Psize_t): PChar; cdecl; external LUAJIT_LIBNAME;            
function lua_objlen(L: Plua_State; idx: Integer): size_t; cdecl; external LUAJIT_LIBNAME;            
function lua_tocfunction(L: Plua_State; idx: Integer): TLua_CFunction; cdecl; external LUAJIT_LIBNAME;            
function lua_touserdata(L: Plua_State; idx: Integer): Pointer; cdecl; external LUAJIT_LIBNAME;            
function lua_tothread(L: Plua_State; idx: Integer): Plua_State; cdecl; external LUAJIT_LIBNAME;            
function lua_topointer(L: Plua_State; idx: Integer): Pointer; cdecl; external LUAJIT_LIBNAME;               


{*
** push functions (C -> stack)
*}
procedure lua_pushnil(L: Plua_State); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushnumber(L: Plua_State; n: TLua_Number); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushinteger(L: Plua_State; n: TLua_Integer); cdecl; external LUAJIT_LIBNAME; overload;               
procedure lua_pushlstring(L: Plua_State; const s: PChar; l_: size_t); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushstring(L: Plua_State; const s: PChar); cdecl; external LUAJIT_LIBNAME; overload;               
function lua_pushvfstring(L: Plua_State; const fmt: PChar; argp: Pointer): PChar; cdecl; external LUAJIT_LIBNAME;               
function lua_pushfstring(L: Plua_State; const fmt: PChar): PChar; cdecl; varargs; external LUAJIT_LIBNAME;               
procedure lua_pushcclosure(L: Plua_State; fn: TLua_CFunction; n: Integer); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushboolean(L: Plua_State; b: LongBool); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushlightuserdata(L: Plua_State; p: Pointer); cdecl; external LUAJIT_LIBNAME;               
procedure lua_pushthread(L: Plua_State); cdecl; external LUAJIT_LIBNAME;                 

{*
** get functions (Lua -> stack)
*}
procedure lua_gettable(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_getfield(L: Plua_state; idx: Integer; k: PChar); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_rawget(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_rawgeti(L: Plua_State; idx, n: Integer); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_createtable(L: Plua_State; narr, nrec: Integer); cdecl; external LUAJIT_LIBNAME;                 
function lua_newuserdata(L: Plua_State; sz: size_t): Pointer; cdecl; external LUAJIT_LIBNAME;                 
function lua_getmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                 
procedure lua_getfenv(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME;                 
                 
{*
** set functions (stack -> Lua)
*}
procedure lua_settable(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_setfield(L: Plua_State; idx: Integer; const k: PChar); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_rawset(L: Plua_State; idx: Integer); cdecl; external LUAJIT_LIBNAME;                 
procedure lua_rawseti(L: Plua_State; idx, n: Integer); cdecl; external LUAJIT_LIBNAME;                 
function lua_setmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                 
function lua_setfenv(L: Plua_State; idx: Integer): Integer; cdecl;  external LUAJIT_LIBNAME;                 

{*
** `load' and `call' functions (load and run Lua code)
*}
procedure lua_call(L: Plua_State; nargs, nresults: Integer); cdecl; external LUAJIT_LIBNAME;                 
function lua_pcall(L: Plua_State; nargs, nresults, errf: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                 
function lua_cpcall(L: Plua_State; func: TLua_CFunction; ud: Pointer): Integer; cdecl; external LUAJIT_LIBNAME;                 
function lua_load(L: Plua_State; reader: TLua_Reader; dt: Pointer; const chunkname: PChar): Integer; cdecl; external LUAJIT_LIBNAME;                 

function lua_dump(L: Plua_State; writer: TLua_Writer; data: Pointer): Integer; cdecl; external LUAJIT_LIBNAME;                         

{*
** coroutine functions
*}
function lua_yield(L: Plua_State; nresults: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                         
function lua_resume(L: Plua_State; narg: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                         
function lua_status(L: Plua_State): Integer; cdecl; external LUAJIT_LIBNAME;                         

{*
** garbage-collection function and options
*}
const
  TLUA_GCSTOP       = 0;
  TLUA_GCRESTART    = 1;
  TLUA_GCCOLLECT    = 2;
  TLUA_GCCOUNT      = 3;
  TLUA_GCCOUNTB     = 4;
  TLUA_GCSTEP       = 5;
  TLUA_GCSETPAUSE   = 6;
  TLUA_GCSETSTEPMUL = 7;

function lua_gc(L: Plua_State; what, data: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                          

{*
** miscellaneous functions
*}
function lua_error(L: Plua_State): Integer; cdecl; external LUAJIT_LIBNAME;                         

function lua_next(L: Plua_State; idx: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                         

procedure lua_concat(L: Plua_State; n: Integer); cdecl; external LUAJIT_LIBNAME;                         

function lua_getallocf(L: Plua_State; ud: PPointer): TLua_Alloc; cdecl; external LUAJIT_LIBNAME;                         
procedure lua_setallocf(L: Plua_State; f: TLua_Alloc; ud: Pointer); cdecl; external LUAJIT_LIBNAME;                            

{*
** ===============================================================
** some useful macros
** ===============================================================
*}
procedure lua_pop(L: Plua_State; n: Integer); inline;

procedure lua_newtable(L: Plua_state); inline;

procedure lua_register(L: Plua_State; const n: PAnsiChar; f: TLua_CFunction); inline;
procedure lua_pushcfunction(L: Plua_State; f: TLua_CFunction); inline;

function lua_strlen(L: Plua_state; i: Integer): size_t; inline;

function lua_isfunction(L: Plua_State; n: Integer): Boolean; inline;
function lua_istable(L: Plua_State; n: Integer): Boolean; inline;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnil(L: Plua_State; n: Integer): Boolean; inline;
function lua_isboolean(L: Plua_State; n: Integer): Boolean; inline;
function lua_isthread(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnone(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean; inline;

procedure lua_pushliteral(L: Plua_State; s: PAnsiChar); inline;

procedure lua_setglobal(L: Plua_State; const s: PAnsiChar); inline;
procedure lua_getglobal(L: Plua_State; const s: PAnsiChar); inline;

function lua_tostring(L: Plua_State; i: Integer): PAnsiChar; inline;

{*
** compatibility macros and functions
*}

procedure lua_getregistry(L: Plua_State); inline;

function lua_getgccount(L: Plua_State): Integer; inline;

type
  TLua_ChunkReader = TLua_Reader;
  TLua_ChunkWriter = TLua_Writer;
                    
{* hack *}
procedure lua_setlevel(from: Plua_state; to_: Plua_state); cdecl; external LUAJIT_LIBNAME;

{*
** =======================================================================
** Debug API
** =======================================================================
*}

{*
** Event codes
*}
const
  TLUA_HOOKCALL    = 0;
  TLUA_HOOKRET     = 1;
  TLUA_HOOKLINE    = 2;
  TLUA_HOOKCOUNT   = 3;
  TLUA_HOOKTAILRET = 4;

{*
** Event masks
*}
const
  TLUA_MASKCALL  = 1 shl Ord(TLUA_HOOKCALL);
  TLUA_MASKRET   = 1 shl Ord(TLUA_HOOKRET);
  TLUA_MASKLINE  = 1 shl Ord(TLUA_HOOKLINE);
  TLUA_MASKCOUNT = 1 shl Ord(TLUA_HOOKCOUNT);

const
  TLUA_IDSIZE = 60;   

type
  TLua_Debug = record           {* activation record *}
    event: Integer;
    name: PAnsiChar;               {* (n) *}
    namewhat: PAnsiChar;           {* (n) `global', `local', `field', `method' *}
    what: PAnsiChar;               {* (S) `Lua', `C', `main', `tail'*}
    source: PAnsiChar;             {* (S) *}
    currentline: Integer;      {* (l) *}
    nups: Integer;             {* (u) number of upvalues *}
    linedefined: Integer;      {* (S) *}
    lastlinedefined: Integer;  {* (S) *}
    short_src: array[0..TLUA_IDSIZE - 1] of Char; {* (S) *}
    {* private part *}
    i_ci: Integer;              {* active function *}
  end;
  PLua_Debug = ^TLua_Debug;

{* Functions to be called by the debuger in specific events *}
  TLua_Hook = procedure(L: Plua_State; ar: Plua_Debug); cdecl;
           
function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl; external LUAJIT_LIBNAME;                             
function lua_getinfo(L: Plua_State; const what: PAnsiChar; ar: Plua_Debug): Integer; cdecl; external LUAJIT_LIBNAME;                             
function lua_getlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                             
function lua_setlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                             
function lua_getupvalue(L: Plua_State; funcindex: Integer; n: Integer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                             
function lua_setupvalue(L: Plua_State; funcindex: Integer; n: Integer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                             

function lua_sethook(L: Plua_State; func: TLua_Hook; mask: Integer; count: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                             
function lua_gethook(L: Plua_State): TLua_Hook; cdecl; external LUAJIT_LIBNAME;                             
function lua_gethookmask(L: Plua_State): Integer; cdecl; external LUAJIT_LIBNAME;                             
function lua_gethookcount(L: Plua_State): Integer; cdecl; external LUAJIT_LIBNAME;                                

{* From Lua 5.2. *}
function lua_upvalueid(L: Plua_State; idx: Integer; n: Integer): Pointer; cdecl; external LUAJIT_LIBNAME;                                
procedure lua_upvaluejoin(L: Plua_State; idx1, n1, idx2, n2: Integer); cdecl; external LUAJIT_LIBNAME;                                
function lua_loadx(L: Plua_State; reader: TLua_Reader; dt: Pointer; const chunkname: PAnsiChar; const mode: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                

{ lauxlib }

// functions added for Pascal
procedure lua_pushstring(L: Plua_State; const s: String); overload; 

// compatibilty macros
function luaL_getn(L: Plua_State; n: Integer): Integer; // calls lua_objlen
procedure luaL_setn(L: Plua_State; t, n: Integer); // does nothing!
                           
{* extra error code for `luaL_load' *}
const
  TLUA_ERRFILE = (TLUA_ERRERR+1);
  
type
  TluaL_reg = record
    name: PAnsiChar;
    func: TLua_CFunction;
  end;
  PluaL_reg = ^TluaL_reg;

procedure luaL_openlib(L: Plua_State; const libname: PAnsiChar; const lr: PluaL_reg; nup: Integer); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_register(L: Plua_State; const libname: PAnsiChar; const lr: PluaL_reg); cdecl; external LUAJIT_LIBNAME;                                
function luaL_getmetafield(L: Plua_State; obj: Integer; const e: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_callmeta(L: Plua_State; obj: Integer; const e: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_typerror(L: Plua_State; narg: Integer; const tname: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_argerror(L: Plua_State; numarg: Integer; const extramsg: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_checklstring(L: Plua_State; numArg: Integer; l_: Psize_t): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                                
function luaL_optlstring(L: Plua_State; numArg: Integer; const def: PAnsiChar; l_: Psize_t): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                                
function luaL_checknumber(L: Plua_State; numArg: Integer): TLua_Number; cdecl; external LUAJIT_LIBNAME;                                
function luaL_optnumber(L: Plua_State; nArg: Integer; def: TLua_Number): TLua_Number; cdecl; external LUAJIT_LIBNAME;                                
function luaL_checkinteger(L: Plua_State; numArg: Integer): TLua_Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_optinteger(L: Plua_State; nArg: Integer; def: TLua_Integer): TLua_Integer; cdecl; external LUAJIT_LIBNAME;                                

procedure luaL_checkstack(L: Plua_State; sz: Integer; const msg: PAnsiChar); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_checktype(L: Plua_State; narg, t: Integer); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl; external LUAJIT_LIBNAME;                                

function luaL_newmetatable(L: Plua_State; const tname: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_checkudata(L: Plua_State; ud: Integer; const tname: PAnsiChar): Pointer; cdecl; external LUAJIT_LIBNAME;                                

procedure luaL_where(L: Plua_State; lvl: Integer); cdecl; external LUAJIT_LIBNAME;                                
{$IFNDEF DELPHI}
function luaL_error(L: Plua_State; const fmt: PAnsiChar; args: array of const): Integer; cdecl; external LUAJIT_LIBNAME; // note: C's ... to array of const conversion is not portable to Delphi
{$ENDIF}

function luaL_checkoption(L: Plua_State; narg: Integer; def: PAnsiChar; lst: PPAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                

function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl; external LUAJIT_LIBNAME;                                

function luaL_loadfile(L: Plua_State; const filename: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_loadbuffer(L: Plua_State; const buff: PAnsiChar; size: size_t; const name: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_loadstring(L: Plua_State; const s: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                

function luaL_newstate: Plua_State; cdecl; external LUAJIT_LIBNAME;                                
function lua_open: Plua_State; // compatibility; moved from unit lua to lauxlib because it needs luaL_newstate

function luaL_gsub(L: Plua_State; const s, p, r: PAnsiChar): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                                
function luaL_findtable(L: Plua_State; idx: Integer; const fname: PAnsiChar; szhint: Integer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                                
                
{* From Lua 5.2. *}
function luaL_fileresult(L: Plua_State; stat: Integer; const fname: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_execresult(L: Plua_State; state: Integer): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_loadfilex(L: Plua_State; const filename: PAnsiChar; const mode: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
function luaL_loadbufferx(L: Plua_State; const buff: PAnsiChar; sz: size_t; const name: PAnsiChar; const mode: PAnsiChar): Integer; cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_traceback(L, L1: Plua_State; const msg: PAnsiChar; level: Integer); cdecl; external LUAJIT_LIBNAME;                                

{*
** ===============================================================
** some useful macros
** ===============================================================
*}
procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar); inline;
function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar; inline;
function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar; inline;
function luaL_checkint(L: Plua_State; n: Integer): Integer; inline;
function luaL_checklong(L: Plua_State; n: Integer): LongInt; inline;
function luaL_optint(L: Plua_State; n: Integer; d: Double): Integer; inline;
function luaL_optlong(L: Plua_State; n: Integer; d: Double): LongInt; inline;

function luaL_typename(L: Plua_State; i: Integer): PAnsiChar; inline;

function lua_dofile(L: Plua_State; const filename: PAnsiChar): Integer; inline;
function lua_dostring(L: Plua_State; const str: PAnsiChar): Integer; inline;

procedure lua_Lgetmetatable(L: Plua_State; tname: PAnsiChar); inline;
         
//luaL_opt(L,f,n,d)	(lua_isnoneornil(L,(n)) ? (d) : f(L,(n)))

{*
** =======================================================
** Generic Buffer manipulation
** =======================================================
*}

const
  // note: this is just arbitrary, as it related to the BUFSIZ defined in stdio.h ...
  TLUAL_BUFFERSIZE = 4096;  
  
type
  luaL_Buffer = record
    p: PAnsiChar;       (* current position in buffer *)
    lvl: Integer;   (* number of strings in the stack (level) *)
    L: Plua_State;
    buffer: array [0..TLUAL_BUFFERSIZE - 1] of Char; // warning: see note above about LUAL_BUFFERSIZE
  end;
  PluaL_Buffer = ^luaL_Buffer;       
  
procedure luaL_addchar(B: PluaL_Buffer; c: Char); inline; // warning: see note above about LUAL_BUFFERSIZE

(* compatibility only (alias for luaL_addchar) *)
procedure luaL_putchar(B: PluaL_Buffer; c: Char); inline; // warning: see note above about LUAL_BUFFERSIZE

procedure luaL_addsize(B: PluaL_Buffer; n: Integer); inline;

procedure luaL_buffinit(L: Plua_State; B: PluaL_Buffer); cdecl; external LUAJIT_LIBNAME;                                
function luaL_prepbuffer(B: PluaL_Buffer): PAnsiChar; cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_addlstring(B: PluaL_Buffer; const s: PAnsiChar; l: size_t); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_addstring(B: PluaL_Buffer; const s: PAnsiChar); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_addvalue(B: PluaL_Buffer); cdecl; external LUAJIT_LIBNAME;                                
procedure luaL_pushresult(B: PluaL_Buffer); cdecl; external LUAJIT_LIBNAME;                                

{* compatibility with ref system *}

{* pre-defined references *}
const
  LUA_NOREF  = -2;
  LUA_REFNIL = -1;       

  {lua_ref(L,lock) ((lock) ? luaL_ref(L, LUA_REGISTRYINDEX) : \
      (lua_pushstring(L, 'unlocked references are obsolete'), lua_error(L), 0))}

procedure lua_unref(L: Plua_State; ref: Integer); inline;
procedure lua_getref(L: Plua_State; ref: Integer); inline;
                
{ LuaLib }

const
  LUA_FILEHANDLE  = 'FILE*';

  LUA_COLIBNAME   = 'coroutine';
  LUA_TABLIBNAME  = 'table';
  LUA_IOLIBNAME   = 'io';
  LUA_OSLIBNAME   = 'os';
  LUA_STRLINAME   = 'string';
  LUA_MATHLIBNAME = 'math';
  LUA_DBLIBNAME   = 'debug';
  LUA_LOADLIBNAME = 'package'; 

function luaopen_base(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME;                                  
function luaopen_math(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_string(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME;    
function luaopen_table(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME;  
function luaopen_io(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_os(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_package(L: Plua_State): LongBool; cdecl;external LUAJIT_LIBNAME;  
function luaopen_debug(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_bit(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_jit(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 
function luaopen_ffi(L: Plua_State): LongBool; cdecl; external LUAJIT_LIBNAME; 

procedure luaL_openlibs(L: Plua_State); cdecl; external LUAJIT_LIBNAME; 

{ LuaJIT }

const
  LUAJIT_VERSION     = 'LuaJIT 2.0.3';
  LUAJIT_VERSION_NUM = 20003;  {* Version 2.0.3 = 02.00.03. *}
  //LUAJIT_VERSION_SYM = luaJIT_version_2_0_3
  LUAJIT_COPYRIGHT   = 'Copyright (C) 2005-2014 Mike Pall';
  LUAJIT_URL         = 'http://luajit.org/';

  {* Modes for luaJIT_setmode. *}
  TLUAJIT_MODE_MASK   = $00ff;

const
  TLUAJIT_MODE_ENGINE     = 0;   {* Set mode for whole JIT engine. *}
  TLUAJIT_MODE_DEBUG      = 1;   {* Set debug mode (idx = level). *}

  TLUAJIT_MODE_FUNC       = 2;   {* Change mode for a function. *}
  TLUAJIT_MODE_ALLFUNC    = 3;   {* Recurse into subroutine protos. *}
  TLUAJIT_MODE_ALLSUBFUNC = 4;   {* Change only the subroutines. *}

  TLUAJIT_MODE_TRACE      = 5;   {* Flush a compiled trace. *}

  TLUAJIT_MODE_WRAPCFUNC  = $10; {* Set wrapper mode for C function calls. *}

const
  {* Flags or'ed in to the mode. *}
  TLUAJIT_MODE_OFF   = $0000;	{* Turn feature off. *}
  TLUAJIT_MODE_ON    = $0100;	{* Turn feature on. *}
  TLUAJIT_MODE_FLUSH = $0200;	{* Flush JIT-compiled code. *}

{* LuaJIT public C API. *}

{* Control the JIT engine. *}
function luaJIT_setmode(L: PLua_State; idx: Integer; mode: Integer): Integer; cdecl; external LUAJIT_LIBNAME;

{* Enforce (dynamic) linker error for version mismatches. Call from main. *}
//procedure LUAJIT_VERSION_SYM();

implementation

function lua_upvalueindex(i: Integer): Integer;
begin
  Result := TLUA_GLOBALSINDEX - i;
end;

procedure lua_pop(L: Plua_State; n: Integer);
begin
  lua_settop(L, -n - 1);
end;

procedure lua_newtable(L: Plua_State);
begin
  lua_createtable(L, 0, 0);
end;

procedure lua_register(L: Plua_State; const n: PAnsiChar; f: TLua_CFunction);
begin
  lua_pushcfunction(L, f);
  lua_setglobal(L, n);
end;

procedure lua_pushcfunction(L: Plua_State; f: TLua_CFunction);
begin
  lua_pushcclosure(L, f, 0);
end;

function lua_strlen(L: Plua_State; i: Integer): size_t;
begin
  Result := lua_objlen(L, i);
end;

function lua_isfunction(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TFUNCTION;
end;

function lua_istable(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TTABLE;
end;

function lua_islightuserdata(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TLIGHTUSERDATA;
end;

function lua_isnil(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TNIL;
end;

function lua_isboolean(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TBOOLEAN;
end;

function lua_isthread(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TTHREAD;
end;

function lua_isnone(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = TLUA_TNONE;
end;

function lua_isnoneornil(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) <= 0;
end;

procedure lua_pushliteral(L: Plua_State; s: PAnsiChar);
begin
  lua_pushlstring(L, s, Length(s));
end;

procedure lua_setglobal(L: Plua_State; const s: PAnsiChar);
begin
  lua_setfield(L, TLUA_GLOBALSINDEX, s);
end;

procedure lua_getglobal(L: Plua_State; const s: PAnsiChar);
begin
  lua_getfield(L, TLUA_GLOBALSINDEX, s);
end;

function lua_tostring(L: Plua_State; i: Integer): PAnsiChar;
begin
  Result := lua_tolstring(L, i, nil);
end;         

procedure lua_getregistry(L: Plua_State);
begin
  lua_pushvalue(L, TLUA_REGISTRYINDEX);
end;

function lua_getgccount(L: Plua_State): Integer;
begin
  Result := lua_gc(L, TLUA_GCCOUNT, 0);
end;         

procedure lua_pushstring(L: Plua_State; const s: string);
begin
  lua_pushlstring(L, PAnsiChar(s), Length(s));
end;

function luaL_getn(L: Plua_State; n: Integer): Integer;
begin
  Result := lua_objlen(L, n);
end;

procedure luaL_setn(L: Plua_State; t, n: Integer);
begin
  // does nothing as this operation is deprecated
end;        

function lua_open: Plua_State;
begin
  Result := luaL_newstate;
end;

procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar);
begin
  if not cond then
    luaL_argerror(L, numarg, extramsg)
end;

function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar;
begin
  Result := luaL_checklstring(L, n, nil)
end;

function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar;
begin
  Result := luaL_optlstring(L, n, d, nil)
end;

function luaL_checkint(L: Plua_State; n: Integer): Integer;
begin
  Result := Integer(Trunc(luaL_checknumber(L, n)))
end;

function luaL_checklong(L: Plua_State; n: Integer): LongInt;
begin
  Result := LongInt(Trunc(luaL_checknumber(L, n)))
end;

function luaL_optint(L: Plua_State; n: Integer; d: Double): Integer;
begin
  Result := Integer(Trunc(luaL_optnumber(L, n, d)))
end;

function luaL_optlong(L: Plua_State; n: Integer; d: Double): LongInt;
begin
  Result := LongInt(Trunc(luaL_optnumber(L, n, d)))
end;           

function luaL_typename(L: Plua_State; i: Integer): PAnsiChar;
begin
  Result := lua_typename(L, lua_type(L, i));
end;  

function lua_dofile(L: Plua_State; const filename: PAnsiChar): Integer;
begin
  Result := luaL_loadfile(L, filename);
  if Result = 0 then
    Result := lua_pcall(L, 0, TLUA_MULTRET, 0);
end;

function lua_dostring(L: Plua_State; const str: PAnsiChar): Integer;
begin
  Result := luaL_loadstring(L, str);
  if Result = 0 then
    Result := lua_pcall(L, 0, TLUA_MULTRET, 0);
end;   

procedure lua_Lgetmetatable(L: Plua_State; tname: PAnsiChar);
begin
  lua_getfield(L, TLUA_REGISTRYINDEX, tname);
end;        

procedure luaL_addchar(B: PluaL_Buffer; c: Char);
begin
  if Cardinal(@(B^.p)) < (Cardinal(@(B^.buffer[0])) + TLUAL_BUFFERSIZE) then
    luaL_prepbuffer(B);
  B^.p[1] := c;
  B^.p := B^.p + 1;
end;

procedure luaL_putchar(B: PluaL_Buffer; c: Char);
begin
  luaL_addchar(B, c);
end;

procedure luaL_addsize(B: PluaL_Buffer; n: Integer);
begin
  B^.p := B^.p + n;
end;             

procedure lua_unref(L: Plua_State; ref: Integer);
begin
  luaL_unref(L, TLUA_REGISTRYINDEX, ref);
end;

procedure lua_getref(L: Plua_State; ref: Integer);
begin
  lua_rawgeti(L, TLUA_REGISTRYINDEX, ref);
end;     

end.

