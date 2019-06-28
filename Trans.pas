unit Trans;
{
DESCRIPTION:  Game localization support.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils, DataLib, TypeWrappers,
  Files, StrLib, Json, Core, GameExt, Stores, EventMan;


type
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

const
  LANG_DIR   = 'Lang';
  TEMPL_CHAR = '@';

  MAP_LANG_DATA_SECTION = 'Era.MapLangData';

  OVERRIDE_KEYS      = true;
  DONT_OVERRIDE_KEYS = false;


function  tr (const Key: string; const Params: array of string): string;


(***) implementation (***)


type
  TLangMap = {O} TDict {of TString};

var
{O} LangMap:                 TLangMap;
{O} LangMapForMap:           TLangMap;
    LangMapForMapSerialized: string = '';
    LangMapForMapHadItems:   boolean = false;
  
  MixedLangMapData: boolean = false;


function tr (const Key: string; const Params: array of string): string;
var
{Un} Translation: TString;

begin
  Translation := LangMap[Key];
  // * * * * * //
  if Translation <> nil then begin
    result := StrLib.BuildStr(Translation.Value, Params, TEMPL_CHAR);
  end else begin
    result := Key;
  end;
end; // .function tr

procedure SerializeMapItem ({Un} Data: pointer; Writer: StrLib.IStrBuilder);
begin
  Writer.WriteInt(Length(TString(Data).Value));
  Writer.Append(TString(Data).Value);
end;

function UnserializeMapItem (ByteMapper: StrLib.IByteMapper): {UOn} pointer;
begin
  result := TString.Create(ByteMapper.ReadStrWithLenField(sizeof(integer)));
end;

procedure LoadLangFile (const FilePath: string; Map: TLangMap; OverrideExistingKeys: boolean);
var
{O} LangData:         TlkJsonObject;
    LangFileContents: string;
    IsInvalidFile:    boolean;

  procedure ProcessTree (Tree: TlkJsonObject; const KeyPrefix: string);
  var
    Key:   string;
    Value: Json.TlkJsonBase;
    i:     integer;

  begin
    for i := 0 to Tree.Count - 1 do begin
      if KeyPrefix <> '' then begin
        Key := KeyPrefix + Tree.NameOf[i];
      end else begin
        Key := Tree.NameOf[i];
      end;

      Value := Tree.FieldByIndex[i];

      if Value is Json.TlkJsonObject then begin
        ProcessTree(Json.TlkJsonObject(Value), Key + '.');
      end else if Value is Json.TlkJsonString then begin
        if OverrideExistingKeys or (Map[Key] = nil) then begin
          Map[Key] := TString.Create(Tree.GetString(i));
        end;
      end else if not IsInvalidFile then begin
        IsInvalidFile := true;
        Core.NotifyError('Invalid language json file: "' + FilePath + '". Erroneous key: ' + Key);
      end;
    end; // .for
  end; // .procedure ProcessTree

begin
  {!} Assert(Map <> nil);
  LangData := nil;
  // * * * * * //
  IsInvalidFile := false;

  if Files.ReadFileContents(FilePath, LangFileContents) then begin
    Utils.CastOrFree(TlkJson.ParseText(LangFileContents), Json.TlkJsonObject, LangData);
    
    if LangData <> nil then begin
      ProcessTree(LangData, '');
    end else begin
      Core.NotifyError('Invalid language json file: "' + FilePath + '"');
    end;
  end; // .if
  // * * * * * //
  FreeAndNil(LangData);
end; // .procedure LoadLangFile

procedure LoadLangFiles (const Dir: string; Map: TLangMap; OverrideKeys: boolean);
begin
  {!} Assert(Map <> nil);
  with Files.Locate(SysUtils.ExcludeTrailingPathDelimiter(Dir) + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      LoadLangFile(FoundPath, Map, OverrideKeys);
    end;
  end;
end;

procedure LoadGlobalLangFiles;
begin
  LangMap.Clear;
  LoadLangFiles(GameExt.GameDir + '\' + LANG_DIR, LangMap, DONT_OVERRIDE_KEYS);
end;

procedure LoadMapLangFiles;
begin
  LangMapForMap.Clear;
  LoadLangFiles(GameExt.GetMapResourcePath(LANG_DIR, GameExt.DONT_FALLBACK_TO_ORIGINAL), LangMapForMap, DONT_OVERRIDE_KEYS);
  LangMapForMapSerialized := DataLib.SerializeDict(LangMapForMap, SerializeMapItem);
  LangMapForMapHadItems   := LangMapForMap.ItemCount > 0;
end;

procedure MoveMapDataToGlobal;
var
{On} Value: TString;

begin
  Value := nil;
  // * * * * * //
  with DataLib.IterateDict(LangMapForMap) do begin
    while IterNext do begin
      LangMapForMap.TakeValue(IterKey, pointer(Value));
      LangMap[IterKey] := Value; Value := nil;
    end;
  end;
  // * * * * * //
  SysUtils.FreeAndNil(Value);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  LoadGlobalLangFiles;
end;

сохранять в сейве оригиналы json?

procedure OnBeforeScriptsReload (Event: GameExt.PEvent); stdcall;
begin
  LoadGlobalLangFiles;
  LoadMapLangFiles;
  MoveMapDataToGlobal;
end;

procedure OnEraMapStart (Event: GameExt.PEvent); stdcall;
var
  PrevLangMapForMapHadItems: boolean;

begin
  PrevLangMapForMapHadItems := LangMapForMapHadItems;
  LoadMapLangFiles;

  if PrevLangMapForMapHadItems or LangMapForMapHadItems then begin
    LoadGlobalLangFiles;
    MoveMapDataToGlobal;
  end;
end;

procedure OnEraSaveScripts (Event: GameExt.PEvent); stdcall;
begin
  with Stores.NewRider(MAP_LANG_DATA_SECTION) do begin
    WriteStr(LangMapForMapSerialized);
  end;
end;

procedure OnEraLoadScripts (Event: GameExt.PEvent); stdcall;
var
{On} LoadedMap: TLangMap;

begin
  LoadedMap := nil;
  // * * * * * //
  with Stores.NewRider(MAP_LANG_DATA_SECTION) do begin
    LangMapForMapSerialized := ReadStr;
    LangMapForMap.Clear;

    if LangMapForMapSerialized <> '' then begin
      LoadedMap := DataLib.UnserializeDict(LangMapForMapSerialized, Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE, UnserializeMapItem);
      Utils.Exchange(int(LangMapForMap), int(LoadedMap));
    end;

    if LangMapForMapHadItems or (LangMapForMap.ItemCount > 0) then begin
      LoadGlobalLangFiles;
      MoveMapDataToGlobal;
    end;

    LangMapForMapHadItems := LangMapForMap.ItemCount > 0;
  end; // .with
  // * * * * * //
  SysUtils.FreeAndNil(LoadedMap);
end;

begin
  LangMap       := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  LangMapForMap := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnBeforeScriptsReload', OnBeforeScriptsReload);
  EventMan.GetInstance.On('$OnEraMapStart', OnEraMapStart);
  EventMan.GetInstance.On('$OnEraSaveScripts', OnEraSaveScripts);
  EventMan.GetInstance.On('$OnEraLoadScripts', OnEraLoadScripts);
end.
