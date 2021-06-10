UNIT Alg;
{
DESCRIPTION:  Additional math/algorithmic functions
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Utils, Math;

TYPE
  TCompareFunc  = FUNCTION (Value1, Value2: INTEGER): INTEGER;


FUNCTION  IntLog2 (Num: INTEGER): INTEGER; {=> Ceil(Log2(N)), N > 0}
FUNCTION  IntCompare (Int1, Int2: INTEGER): INTEGER;
FUNCTION  Int64To32 (Value: INT64): INTEGER; {No overflow, bounds to LOW(INT32)..HIGH(IN32)}
PROCEDURE QuickSort (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: INTEGER);
PROCEDURE CustomQuickSort
(
  Arr:          Utils.PEndlessIntArr;
  MinInd:       INTEGER;
  MaxInd:       INTEGER;
  CompareItems: TCompareFunc
);


(***)  IMPLEMENTATION  (***)


FUNCTION IntLog2 (Num: INTEGER): INTEGER;
VAR
  TestValue:  CARDINAL;
  
BEGIN
  {!} ASSERT(Num > 0);
  RESULT    :=  0;
  TestValue :=  1;
  
  WHILE TestValue < CARDINAL(Num) DO BEGIN
    INC(RESULT);
    TestValue :=  TestValue SHL 1;
  END; // .WHILE
END; // .FUNCTION IntLog2

FUNCTION IntCompare (Int1, Int2: INTEGER): INTEGER;
BEGIN
  IF Int1 > Int2 THEN BEGIN
    RESULT  :=  +1;
  END // .IF
  ELSE IF Int1 < Int2 THEN BEGIN
    RESULT  :=  -1;
  END // .ELSEIF
  ELSE BEGIN
    RESULT  :=  0;
  END; // .ELSE
END; // .FUNCTION IntCompare

FUNCTION Int64To32 (Value: INT64): INTEGER;
BEGIN
  IF Value > HIGH(INTEGER) THEN BEGIN
    RESULT  :=  HIGH(INTEGER);
  END // .IF
  ELSE IF Value < LOW(INTEGER) THEN BEGIN
    RESULT  :=  LOW(INTEGER);
  END // .ELSEIF
  ELSE BEGIN
    RESULT  :=  Value;
  END; // .ELSE
END; // .FUNCTION Int64To32

PROCEDURE QuickSort (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: INTEGER);
BEGIN
  CustomQuickSort(Arr, MinInd, MaxInd, IntCompare);
END; // .PROCEDURE QuickSort

PROCEDURE CustomQuickSort
(
  Arr:          Utils.PEndlessIntArr;
  MinInd:       INTEGER;
  MaxInd:       INTEGER;
  CompareItems: TCompareFunc
);

VAR
  LeftInd:    INTEGER;
  RightInd:   INTEGER;
  PivotItem:  INTEGER;
  
  PROCEDURE ExchangeItems (Ind1, Ind2: INTEGER);
  VAR
    TransfValue:  INTEGER;
     
  BEGIN
    TransfValue :=  Arr[Ind1];
    Arr[Ind1]   :=  Arr[Ind2];
    Arr[Ind2]   :=  TransfValue;
  END; // .PROCEDURE ExchangeItems
  
BEGIN
  {!} ASSERT(Arr <> NIL);
  {!} ASSERT(MinInd >= 0);
  {!} ASSERT(MaxInd >= MinInd);
  
  WHILE MinInd < MaxInd DO BEGIN
    LeftInd   :=  MinInd;
    RightInd  :=  MaxInd;
    PivotItem :=  Arr[MinInd + (MaxInd - MinInd) DIV 2];
    
    WHILE LeftInd <= RightInd DO BEGIN
      WHILE CompareItems(Arr[LeftInd], PivotItem) < 0 DO BEGIN
        INC(LeftInd);
      END; // .WHILE
      
      WHILE CompareItems(Arr[RightInd], PivotItem) > 0 DO BEGIN
        DEC(RightInd);
      END; // .WHILE
      
      IF LeftInd <= RightInd THEN BEGIN
        IF CompareItems(Arr[LeftInd], Arr[RightInd]) > 0 THEN BEGIN
          ExchangeItems(LeftInd, RightInd);
        END; // .IF
        
        INC(LeftInd);
        DEC(RightInd);
      END; // .IF
    END; // .WHILE
    
    (* MIN__RIGHT|{PIVOT}|LEFT__MAX *)
    
    IF (RightInd - MinInd) < (MaxInd - LeftInd) THEN BEGIN
      IF RightInd > MinInd THEN BEGIN
        CustomQuickSort(Arr, MinInd, RightInd, CompareItems);
      END; // .IF
      
      MinInd :=  LeftInd;
    END // .IF
    ELSE BEGIN
      IF MaxInd > LeftInd THEN BEGIN
        CustomQuickSort(Arr, LeftInd, MaxInd, CompareItems);
      END; // .IF
      
      MaxInd  :=  RightInd;
    END; // .ELSE
  END; // .WHILE
END; // .PROCEDURE CustomQuickSort

END.
