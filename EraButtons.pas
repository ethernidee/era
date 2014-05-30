UNIT EraButtons;
{
DESCRIPTION:  Adds custom buttons support using modified Buttons plugin by MoP 
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Crypto, StrLib, Files, AssocArrays, DlgMes,
  Core, GameExt;

CONST
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
  

FUNCTION  GetButtonID (CONST ButtonName: STRING): INTEGER; STDCALL;
  
  
(***) IMPLEMENTATION (***)


CONST
  BUTTONS_DLL_NAME  = 'buttons.dll';


TYPE
  TButtonsTable = ARRAY OF StrLib.TArrayOfString;
  
  
VAR
{O} ButtonNames:  AssocArrays.TAssocArray {OF INTEGER};

  hButtons: INTEGER;
  
  ExtButtonsTable:  PPOINTER;
  ExtNumButtons:    PINTEGER;
  
  ButtonsTable: TButtonsTable;
  ButtonID:     INTEGER = 400;
  NumButtons:   INTEGER;


PROCEDURE LoadButtons;
VAR
{O} Locator:      Files.TFileLocator;
{O} ItemInfo:     Files.TFileItemInfo;
    FileName:     STRING;
    FileContents: STRING;
    Lines:        StrLib.TArrayOfString;
    Line:         StrLib.TArrayOfString;
    NumLines:     INTEGER;
    ButtonName:   STRING;
    i:            INTEGER;
    y:            INTEGER;
   
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  NIL;
  // * * * * * //
  Locator.DirPath :=  BUTTONS_PATH;
  Locator.InitSearch('*.btn');
  
  WHILE Locator.NotEnd DO BEGIN
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(ItemInfo)));
    
    IF
      NOT ItemInfo.IsDir                            AND
      (SysUtils.ExtractFileExt(FileName) = '.btn')  AND
      ItemInfo.HasKnownSize                         AND
      (ItemInfo.FileSize > 0)
    THEN BEGIN
      {!} ASSERT(Files.ReadFileContents(BUTTONS_PATH + '\' + FileName, FileContents));
      Lines     :=  StrLib.Explode(SysUtils.Trim(FileContents), #13#10);
      NumLines  :=  LENGTH(Lines);
      
      FOR i := 0 TO NumLines - 1 DO BEGIN
        Line  :=  StrLib.Explode(SysUtils.Trim(Lines[i]), ';');
        
        IF LENGTH(Line) < NUM_BUTTON_COLUMNS THEN BEGIN
          DlgMes.Msg
          (
            'Invalid number of columns (' + SysUtils.IntToStr(LENGTH(Line)) +
            ') on line ' + SysUtils.IntToStr(i + 1) +
            ' in file "' + FileName + '".'#13#10 +
            'Expected ' + SysUtils.IntToStr(NUM_BUTTON_COLUMNS) + ' columns'
          );
        END // .IF
        ELSE BEGIN
          Line[COL_TYPE]  :=  SysUtils.AnsiLowerCase(Line[COL_TYPE]);
        
          FOR y := 0 TO NUM_BUTTON_COLUMNS - 1 DO BEGIN
            IF Line[y] = '' THEN BEGIN
              Line[y] :=  #0;
            END; // .IF
          END; // .FOR
          
          IF Line[COL_TYPE] = TYPENAME_ADVMAP THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_ADVMAP;
          END // .IF
          ELSE IF Line[COL_TYPE] = TYPENAME_TOWN THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_TOWN;
          END // .ELSEIF
          ELSE IF Line[COL_TYPE] = TYPENAME_HERO THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_HERO;
          END // .ELSEIF
          ELSE IF Line[COL_TYPE] = TYPENAME_HEROES THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_HEROES;
          END // .ELSEIF
          ELSE IF Line[COL_TYPE] = TYPENAME_BATTLE THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_BATTLE;
          END // .ELSEIF
          ELSE IF Line[COL_TYPE] = TYPENAME_DUMMY THEN BEGIN
            Line[COL_TYPE]  :=  TYPE_DUMMY;
          END // .ELSEIF
          ELSE BEGIN
            {!} ASSERT(FALSE);
          END; // .ELSE
          
          ButtonName  :=  Line[COL_NAME];
          
          IF ButtonNames[ButtonName] <> NIL THEN BEGIN
            DlgMes.Msg
            (
              'Duplicate button name ("' + ButtonName + '") on line ' + SysUtils.IntToStr(i + 1) +
              ' in file "' + FileName + '"'
            );
          END // .IF
          ELSE BEGIN
            ButtonNames[ButtonName] :=  Ptr(ButtonID);
            Line[COL_NAME]          :=  SysUtils.IntToStr(ButtonID);
            INC(ButtonID);
            
            SetLength(ButtonsTable, NumButtons + 1);
            ButtonsTable[NumButtons]  :=  Line;
            INC(NumButtons);
          END; // .ELSE
        END; // .ELSE
      END; // .FOR
    END; // .IF
    
    SysUtils.FreeAndNil(ItemInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  
  ExtButtonsTable^  :=  POINTER(ButtonsTable);
  ExtNumButtons^    :=  NumButtons;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .PROCEDURE LoadButtons 

FUNCTION GetButtonID (CONST ButtonName: STRING): INTEGER; STDCALL;
BEGIN
  RESULT  :=  INTEGER(ButtonNames[ButtonName]);
  
  IF RESULT = 0 THEN BEGIN
    RESULT  :=  -1;
  END; // .IF
END; // .FUNCTION GetButtonID

PROCEDURE OnAfterWoG (Event: PEvent); STDCALL;
BEGIN
  (* Connect to Buttons.dll *)
  hButtons  :=  Windows.LoadLibrary(BUTTONS_DLL_NAME);
  {!} ASSERT(hButtons <> 0);
  ExtButtonsTable :=  GetProcAddress(hButtons, 'ButtonsTable');
  ExtNumButtons   :=  GetProcAddress(hButtons, 'NumButtons');
  {!} ASSERT(ExtButtonsTable <> NIL);
  {!} ASSERT(ExtNumButtons <> NIL);
  
  LoadButtons;
END; // .PROCEDURE OnAfterWoG

BEGIN
  NumButtons  :=  0;
  ButtonNames :=  AssocArrays.NewSimpleAssocArr(Crypto.AnsiCRC32, SysUtils.AnsiLowerCase);

  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
END.
