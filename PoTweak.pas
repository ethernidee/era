UNIT PoTweak;
{
DESCRIPTION:  Fixing Erm PO command to support maps of any size
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Core, GameExt, Heroes, Stores;

CONST
  FILE_SECTION_NAME = 'Era.PO';
  MAX_MAP_SIZE = 256;

TYPE
  PSquare = ^TSquare;
  TSquare = INTEGER;

  PSquare2  = ^TSquare2;
  TSquare2  = PACKED ARRAY [0..15] OF BYTE;

CONST
  ErmSquare:  ^PSquare  = Ptr($27C9678);
  ErmSquare2: ^PSquare2 = Ptr($9A48A0);

VAR
  Squares:  array [0..MAX_MAP_SIZE * MAX_MAP_SIZE * 2 - 1] of TSquare;
  Squares2: array [0..MAX_MAP_SIZE * MAX_MAP_SIZE * 2 - 1] of TSquare2;

implementation

var
  SquaresSize:  INTEGER;
  Squares2Size: INTEGER;

PROCEDURE PatchSquaresRefs;
var
  MapSize:        INTEGER;
  BasicPoSize:    INTEGER;
  SecondDimSize:  INTEGER;
  SecondDimSize2: INTEGER;

BEGIN
  MapSize         :=  Heroes.GetMapSize;
  BasicPoSize     :=  MapSize * MapSize * 2;
  SquaresSize     :=  BasicPoSize * SIZEOF(TSquare);
  Squares2Size    :=  BasicPoSize * SIZEOF(TSquare2);
  SecondDimSize   :=  MapSize * 2 * SIZEOF(TSquare);
  SecondDimSize2  :=  MapSize * 2 * SIZEOF(TSquare2);
  
  // Patch Squares
  PPOINTER($73644C)^  :=  @Squares[0];
  PPOINTER($73BB32)^  :=  @Squares[0];
  PPOINTER($73BE35)^  :=  @Squares[0];
  PPOINTER($75118F)^  :=  @Squares[0];
  PPOINTER($751975)^  :=  @Squares[0];
  PPOINTER($752B68)^  :=  @Squares[0];
  PPOINTER($752B87)^  :=  @Squares[0];
  PPOINTER($752BA0)^  :=  @Squares[0];
  PPOINTER($752BBF)^  :=  @Squares[0];
  PPOINTER($752BD8)^  :=  @Squares[0];
  PPOINTER($752BF6)^  :=  @Squares[0];
  PPOINTER($752C0F)^  :=  @Squares[0];
  PPOINTER($752C2E)^  :=  @Squares[0];
  PPOINTER($752C47)^  :=  @Squares[0];
  PPOINTER($752C66)^  :=  @Squares[0];
  
  // Patch Squares2
  PPOINTER($73BB51)^  :=  @Squares2[0];
  PPOINTER($751582)^  :=  @Squares2[0];
  PPOINTER($752472)^  :=  @Squares2[0];
  PPOINTER($752FA4)^  :=  @Squares2[0];
  
  // Patch calculating Squares addresses
  PINTEGER($736442)^  :=  SecondDimSize;
  PINTEGER($73BB28)^  :=  SecondDimSize;
  PINTEGER($73BE2B)^  :=  SecondDimSize;
  PINTEGER($752B5E)^  :=  SecondDimSize;
  PINTEGER($752B7D)^  :=  SecondDimSize;
  PINTEGER($752B96)^  :=  SecondDimSize;
  PINTEGER($752BB5)^  :=  SecondDimSize;
  PINTEGER($752BCE)^  :=  SecondDimSize;
  PINTEGER($752BEC)^  :=  SecondDimSize;
  PINTEGER($752C05)^  :=  SecondDimSize;
  PINTEGER($752C24)^  :=  SecondDimSize;
  PINTEGER($752C3D)^  :=  SecondDimSize;
  PINTEGER($752C5C)^  :=  SecondDimSize;
  
  // Patch calculating Squares2 addresses
  PINTEGER($73BB44)^  :=  SecondDimSize2;
  PINTEGER($752FBD)^  :=  Squares2Size;
  
  // Fix cycles
  PINTEGER($752B14)^  :=  MapSize;
  PINTEGER($752B33)^  :=  MapSize;
END; // .PROCEDURE PatchSquaresRefs

FUNCTION Hook_BeforeResetErmFunc (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  GameExt.FireEvent('$OnBeforeResetErmFunc', nil, 0);
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_BeforeResetErmFunc

PROCEDURE OnSavegameWrite (Event: GameExt.PEvent); STDCALL;
BEGIN
  Stores.WriteSavegameSection(SquaresSize, @Squares[0], FILE_SECTION_NAME);
  Stores.WriteSavegameSection(Squares2Size, @Squares2[0], FILE_SECTION_NAME);
END; // .PROCEDURE OnSavegameWrite

PROCEDURE OnSavegameRead (Event: GameExt.PEvent); STDCALL;
BEGIN
  PatchSquaresRefs;
  Stores.ReadSavegameSection(SquaresSize, @Squares[0], FILE_SECTION_NAME);
  Stores.ReadSavegameSection(Squares2Size, @Squares2[0], FILE_SECTION_NAME);
END; // .PROCEDURE OnSavegameRead

PROCEDURE OnBeforeResetErmFunc (Event: GameExt.PEvent); STDCALL;
BEGIN
  PatchSquaresRefs;
END; // .PROCEDURE OnBeforeResetErmFunc

PROCEDURE OnAfterWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  // Disable Squares Save/Load
  PINTEGER($751189)^  :=  INTEGER($909023EB);
  PBYTE($75118D)^     :=  BYTE($90);
  PINTEGER($75196F)^  :=  INTEGER($909023EB);
  PBYTE($751973)^     :=  BYTE($90);
  
  // Disable Squares2 Save/Load
  PINTEGER($75157C)^  :=  INTEGER($909020EB);
  PBYTE($751580)^     :=  BYTE($90);
  PINTEGER($75246C)^  :=  INTEGER($909023EB);
  PBYTE($752470)^     :=  BYTE($90);

  // $OnBeforeResetErmFunc event for patching PO code before being inited by ERM
  Core.ApiHook(@Hook_BeforeResetErmFunc, Core.HOOKTYPE_BRIDGE, Ptr($75259E));
END; // .PROCEDURE OnAfterWoG

BEGIN
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
  GameExt.RegisterHandler(OnSavegameWrite, 'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead, 'OnSavegameRead');
  GameExt.RegisterHandler(OnBeforeResetErmFunc, '$OnBeforeResetErmFunc');
END.
