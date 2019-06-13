unit EraButtons;
{
DESCRIPTION:  Adds custom buttons support using modified Buttons plugin by MoP 
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Crypto, StrLib, Files, AssocArrays, DlgMes,
  Core, GameExt, Trans, EventMan;

const
  BUTTONS_PATH  = 'Data\Buttons';
  
  NUM_BUTTON_COLUMNS  = 10;
  
  (* Columns *)
  COL_TYPE      = 0;
  COL_NAME      = 1;
  COL_DEF       = 2;
  COL_X         = 3;
  COL_Y         = 4;
  COL_WIDTH     = 5;
  COL_HEIGHT    = 6;
  COL_LONGHINT  = 7;
  COL_SHORTHINT = 8;
  COL_HOTKEY    = 9;
  
  (* Button screen *)
  TYPENAME_ADVMAP = 'advmap';
  TYPENAME_TOWN   = 'town';
  TYPENAME_HERO   = 'hero';
  TYPENAME_HEROES = 'heroes';
  TYPENAME_BATTLE = 'battle';
  TYPENAME_DUMMY  = 'dummy';  // Button is not shown
  
  TYPE_ADVMAP = '0';
  TYPE_TOWN   = '1';
  TYPE_HERO   = '2';
  TYPE_HEROES = '3';
  TYPE_BATTLE = '4';
  TYPE_DUMMY  = '9';
  

function GetButtonID (const ButtonName: string): integer; stdcall;
  
  
(***) implementation (***)


const
  BUTTONS_DLL_NAME          = 'buttons.era';
  BUTTONS_TABLE_GROWTH_STEP = 16;


type
  TButtonsTable = array of StrLib.TArrayOfStr;
  
  
var
{O} ButtonNames:  AssocArrays.TAssocArray {OF INTEGER};

  hButtons: integer;
  
  ExtButtonsTable:  PPOINTER;
  ExtNumButtons:    PINTEGER;
  
  ButtonsTable: TButtonsTable;
  ButtonID:     integer = 400;
  NumButtons:   integer;


procedure LoadButtons;
var
  FileContents: string;
  Lines:        StrLib.TArrayOfStr;
  Line:         StrLib.TArrayOfStr;
  NumLines:     integer;
  ButtonName:   string;
  i:            integer;
  y:            integer;
   
begin 
  with Files.Locate(GameExt.GameDir + '\' + BUTTONS_PATH + '\*.btn', Files.ONLY_FILES) do begin
    while FindNext do begin
      if FoundRec.Rec.Size > 0 then begin
        {!} Assert(Files.ReadFileContents(FoundPath, FileContents), Format('Failed to load button config file at "%s"', [FoundPath]));
        Lines    := StrLib.Explode(SysUtils.Trim(FileContents), #13#10);
        NumLines := Length(Lines);
        
        for i := 0 to NumLines - 1 do begin
          Line := StrLib.Explode(SysUtils.Trim(Lines[i]), ';');
          
          if Length(Line) < NUM_BUTTON_COLUMNS then begin
            Core.NotifyError(Format('Invalid number of columns (%d) on line (%d) in file "%s".'#13#10'Expected %d columns', [Length(Line), i + 1, FoundPath, NUM_BUTTON_COLUMNS]));
          end else begin
            Line[COL_TYPE] := SysUtils.AnsiLowerCase(Line[COL_TYPE]);
          
            for y := 0 to NUM_BUTTON_COLUMNS - 1 do begin
              if Line[y] = '' then begin
                Line[y] := #0;
              end;
            end;
            
            if Line[COL_TYPE] = TYPENAME_ADVMAP then begin
              Line[COL_TYPE] := TYPE_ADVMAP;
            end else if Line[COL_TYPE] = TYPENAME_TOWN then begin
              Line[COL_TYPE] := TYPE_TOWN;
            end else if Line[COL_TYPE] = TYPENAME_HERO then begin
              Line[COL_TYPE] := TYPE_HERO;
            end else if Line[COL_TYPE] = TYPENAME_HEROES then begin
              Line[COL_TYPE] := TYPE_HEROES;
            end else if Line[COL_TYPE] = TYPENAME_BATTLE then begin
              Line[COL_TYPE] := TYPE_BATTLE;
            end else if Line[COL_TYPE] = TYPENAME_DUMMY then begin
              Line[COL_TYPE] := TYPE_DUMMY;
            end else begin
              Core.NotifyError(Format('Unknown button type ("%s") on line %d in file "%s"', [Line[COL_TYPE], i + 1, FoundPath]));
            end; // .else
            
            ButtonName := Line[COL_NAME];
            
            if ButtonNames[ButtonName] <> nil then begin
              Core.NotifyError(Format('Duplicate button name ("%s") on line %d in file "%s"', [ButtonName, i + 1, FoundPath]));
            end else begin
              Line[COL_SHORTHINT]     := Trans.tr(Line[COL_SHORTHINT], []);
              Line[COL_LONGHINT]      := Trans.tr(Line[COL_LONGHINT], []);
              ButtonNames[ButtonName] := Ptr(ButtonID);
              Line[COL_NAME]          := SysUtils.IntToStr(ButtonID);
              Inc(ButtonID);

              if NumButtons + 1 >= Length(ButtonsTable) then begin
                SetLength(ButtonsTable, NumButtons + BUTTONS_TABLE_GROWTH_STEP);
              end;
              
              ButtonsTable[NumButtons] := Line;
              Inc(NumButtons);
            end; // .else
          end; // .else
        end; // .for
      end; // .if
    end; // .while
  end; // .with
  
  ExtButtonsTable^ := pointer(ButtonsTable);
  ExtNumButtons^   := NumButtons;
end; // .procedure LoadButtons 

function GetButtonID (const ButtonName: string): integer; stdcall;
begin
  result := integer(ButtonNames[ButtonName]);
  
  if result = 0 then begin
    result := -1;
  end;
end;

procedure OnAfterWoG (Event: PEvent); stdcall;
begin
  (* Connect to Buttons plugin *)
  hButtons := Windows.GetModuleHandle(BUTTONS_DLL_NAME);
  {!} Assert(hButtons <> 0, 'Obligatory plugin "' + BUTTONS_DLL_NAME + '" is not loaded');
  ExtButtonsTable := GetProcAddress(hButtons, 'ButtonsTable');
  ExtNumButtons   := GetProcAddress(hButtons, 'NumButtons');
  {!} Assert(ExtButtonsTable <> nil);
  {!} Assert(ExtNumButtons <> nil);
  
  LoadButtons;
end; // .procedure OnAfterWoG

begin
  NumButtons  := 0;
  SetLength(ButtonsTable, BUTTONS_TABLE_GROWTH_STEP);
  ButtonNames := AssocArrays.NewSimpleAssocArr(Crypto.AnsiCRC32, SysUtils.AnsiLowerCase);

  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
