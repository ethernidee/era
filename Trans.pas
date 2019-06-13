unit Trans;
{
DESCRIPTION:  Game localization support.
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils, DataLib, TypeWrappers,
  Files, StrLib, Json, Core, GameExt, EventMan;


type
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;


const
  LANG_DIR   = 'Lang';
  TEMPL_CHAR = '@';


var
  {O} LangMap: TDict {O} {OF TString};


function  tr (const Key: string; const Params: array of string): string;
procedure ClearLangData;
procedure LoadLangFiles;
procedure ReloadLangFiles;
procedure LoadLangFile (const FilePath: string);


(***) implementation (***)


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

procedure ClearLangData;
begin
  LangMap.Clear();
end;

procedure LoadLangFiles;
begin
  with Files.Locate(LANG_DIR + '\*.json', Files.ONLY_FILES) do begin
    while FindNext do begin
      LoadLangFile(LANG_DIR + '\' + FoundName);
    end;
  end;
end;

procedure ReloadLangFiles;
begin
  ClearLangData;
  LoadLangFiles;
end;

procedure LoadLangFile (const FilePath: string);
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
        if LangMap[Key] = nil then begin
          LangMap[Key] := TString.Create(Tree.GetString(i));
        end;
      end else if not IsInvalidFile then begin
        IsInvalidFile := true;
        Core.NotifyError('Invalid language json file: "' + FilePath + '". Erroneous key: ' + Key);
      end;
    end; // .for
  end; // .procedure ProcessTree

begin
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

procedure OnReloadLangData (Event: GameExt.PEvent); stdcall;
begin
  ReloadLangFiles;
end;

begin
  LangMap := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  EventMan.GetInstance.On('OnAfterWoG', OnReloadLangData);
  EventMan.GetInstance.On('OnBeforeScriptsReload', OnReloadLangData);
end.
