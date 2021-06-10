UNIT DataLib;
{
DESCRIPTION:  Convinient and widely used data structures
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  SysUtils,
  Utils, Crypto, Lists, AssocArrays;

CONST
  CASE_SENSITIVE    = FALSE; 
  CASE_INSENSITIVE  = NOT CASE_SENSITIVE;


TYPE
  TDict     = AssocArrays.TAssocArray {OF TObject};
  TObjDict  = AssocArrays.TObjArray {OF TObject};
  TList     = Lists.TList {OF TObject};
  TStrList  = Lists.TStringList {OF TObject};

  (*  Combines access speed of TDist and order of TStrList  *)
  THashedList = CLASS ABSTRACT
    PROTECTED
      FUNCTION  GetItem (CONST Key: STRING): {Un} TObject; VIRTUAL; ABSTRACT;
      FUNCTION  GetKey (Ind: INTEGER): STRING; VIRTUAL; ABSTRACT;
      FUNCTION  GetValue (Ind: INTEGER): {Un} TObject; VIRTUAL; ABSTRACT;
      PROCEDURE SetValue (Ind: INTEGER; {OUn} NewValue: TObject); VIRTUAL; ABSTRACT;
      FUNCTION  GetCount: INTEGER; VIRTUAL; ABSTRACT;
      
    PUBLIC
      FUNCTION  LinearFind (CONST Key: STRING; OUT Ind: INTEGER): BOOLEAN; VIRTUAL; ABSTRACT;
      PROCEDURE InsertBefore
      (
              CONST Key:        STRING;
        {OUn}       Value:      TObject;
                    BeforeInd:  INTEGER
      ); VIRTUAL; ABSTRACT;

      FUNCTION  Take (Ind: INTEGER): {OUn} TObject; VIRTUAL; ABSTRACT;
      PROCEDURE Delete (Ind: INTEGER); VIRTUAL; ABSTRACT;
      PROCEDURE Clear; VIRTUAL; ABSTRACT;
      PROCEDURE  Add (CONST Key: STRING; {OUn} Value: TObject);

      PROPERTY Count: INTEGER READ GetCount;
      
      PROPERTY Items  [CONST Key: STRING]:  {n} TObject READ GetItem; DEFAULT;
      PROPERTY Keys   [Ind: INTEGER]:       STRING READ GetKey;
      PROPERTY Values [Ind: INTEGER]:       {n} TObject READ GetValue WRITE SetValue;
  END; // .CLASS THashedList
  
  IDictIterator = INTERFACE
    PROCEDURE BeginIterate ({U} Dict: TDict);
    FUNCTION  IterNext: BOOLEAN;
    PROCEDURE EndIterate;
    FUNCTION  GetIterKey: STRING;
    FUNCTION  GetIterValue: {Un} TObject;
    
    PROPERTY IterKey:   STRING READ GetIterKey;
    PROPERTY IterValue: {n} TObject READ GetIterValue;
  END; // .INTERFACE IDictIterator


FUNCTION  NewDict (OwnsItems, CaseInsensitive: BOOLEAN): {O} TDict;
FUNCTION  NewObjDict (OwnsItems: BOOLEAN): {O} TObjDict;
FUNCTION  NewList (OwnsItems: BOOLEAN): {O} TList;
FUNCTION  NewStrList (OwnsItems: BOOLEAN; CaseInsensitive: BOOLEAN): {O} TStrList;
FUNCTION  NewHashedList (OwnsItems, CaseInsensitive: BOOLEAN): {O} THashedList;
FUNCTION  IterateDict ({U} Dict: TDict): IDictIterator;


(***) IMPLEMENTATION (***)


TYPE
  TStdHashedList = CLASS (THashedList)
    PROTECTED
      {O} fItemList:  {OU} TStrList;
      {O} fItems:     {U}  TDict;

      FUNCTION  GetItem (CONST Key: STRING): {Un} TObject; OVERRIDE;
      FUNCTION  GetKey (Ind: INTEGER): STRING; OVERRIDE;
      FUNCTION  GetValue (Ind: INTEGER): {Un} TObject; OVERRIDE;
      PROCEDURE SetValue (Ind: INTEGER; {OUn} NewValue: TObject); OVERRIDE;
      FUNCTION  GetCount: INTEGER; OVERRIDE;

    PUBLIC
      CONSTRUCTOR Create (OwnsItems, CaseInsensitive: BOOLEAN);
      DESTRUCTOR  Destroy; OVERRIDE;

      FUNCTION  LinearFind (CONST Key: STRING; OUT Ind: INTEGER): BOOLEAN; OVERRIDE;
      PROCEDURE InsertBefore
      (
              CONST Key:        STRING;
        {OUn}       Value:      TObject;
                    BeforeInd:  INTEGER
      ); OVERRIDE;

      FUNCTION  Take (Ind: INTEGER): {OUn} TObject; OVERRIDE;
      PROCEDURE Delete (Ind: INTEGER); OVERRIDE;
      PROCEDURE Clear; OVERRIDE;
  END; // .CLASS TStdHashedList
  
  TDictIterator = CLASS (TInterfacedObject, IDictIterator)
    PROTECTED
      {U}   fDict:      TDict;
      {Un}  fIterValue: TObject;
            fIterKey:   STRING;
            fIterating: BOOLEAN;
            
    PUBLIC
      PROCEDURE BeginIterate ({U} Dict: TDict);
      FUNCTION  IterNext: BOOLEAN;
      PROCEDURE EndIterate;
      FUNCTION  GetIterKey: STRING;
      FUNCTION  GetIterValue: {Un} TObject;
  END; // .CLASS TDictIterator


FUNCTION NewDict (OwnsItems, CaseInsensitive: BOOLEAN): {O} TDict;
VAR
  KeyPreprocessFunc:  AssocArrays.TKeyPreprocessFunc;

BEGIN
  IF CaseInsensitive THEN BEGIN
    KeyPreprocessFunc :=  SysUtils.AnsiLowerCase;
  END // .IF
  ELSE BEGIN
    KeyPreprocessFunc :=  NIL;
  END; // .ELSE

  RESULT  :=  AssocArrays.NewAssocArr
  (
    Crypto.AnsiCRC32,
    KeyPreprocessFunc,
    OwnsItems,
    Utils.ITEMS_ARE_OBJECTS AND OwnsItems,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );
END; // .FUNCTION NewDict

FUNCTION NewObjDict (OwnsItems: BOOLEAN): {O} TObjDict;
BEGIN
  RESULT  :=  AssocArrays.NewObjArr
  (
    OwnsItems,
    Utils.ITEMS_ARE_OBJECTS AND OwnsItems,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );
END; // .FUNCTION NewObjDict

FUNCTION NewList (OwnsItems: BOOLEAN): {O} TList;
BEGIN
  RESULT  :=  Lists.NewList
  (
    OwnsItems,
    Utils.ITEMS_ARE_OBJECTS AND OwnsItems,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );
END; // .FUNCTION NewList

FUNCTION NewStrList (OwnsItems: BOOLEAN; CaseInsensitive: BOOLEAN): {O} TStrList;
BEGIN
  RESULT := Lists.NewStrList
  (
    OwnsItems,
    Utils.ITEMS_ARE_OBJECTS AND OwnsItems,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );
  
  RESULT.CaseInsensitive := CaseInsensitive;
END; // .FUNCTION NewStrList

FUNCTION NewHashedList (OwnsItems, CaseInsensitive: BOOLEAN): {O} THashedList;
BEGIN
  RESULT  :=  TStdHashedList.Create(OwnsItems, CaseInsensitive);
END; // .FUNCTION NewHashedList

PROCEDURE THashedList.Add (CONST Key: STRING; {OUn} Value: TObject);
BEGIN
  Self.InsertBefore(Key, Value, Self.Count);
END; // .PROCEDURE THashedList.Add

CONSTRUCTOR TStdHashedList.Create (OwnsItems, CaseInsensitive: BOOLEAN);
BEGIN
  Self.fItemList  :=  NewStrList(OwnsItems, CaseInsensitive);
  Self.fItems     :=  NewDict(NOT Utils.OWNS_ITEMS, CaseInsensitive);
END; // .CONSTRUCTOR TStdHashedList.Create

DESTRUCTOR TStdHashedList.Destroy;
BEGIN
  SysUtils.FreeAndNil(Self.fItems);
  SysUtils.FreeAndNil(Self.fItemList);
END; // .DESTRUCTOR TStdHashedList.Destroy

FUNCTION TStdHashedList.GetItem (CONST Key: STRING): {Un} TObject;
BEGIN
  RESULT  :=  Self.fItems[Key];
END; // .FUNCTION TStdHashedList.GetItem

FUNCTION TStdHashedList.GetKey (Ind: INTEGER): STRING;
BEGIN
  RESULT  :=  Self.fItemList.Keys[Ind];
END; // .FUNCTION TStdHashedList.GetKey

FUNCTION TStdHashedList.GetValue (Ind: INTEGER): {Un} TObject;
BEGIN
  RESULT  :=  Self.fItemList.Values[Ind];
END; // .FUNCTION TStdHashedList.GetValue

PROCEDURE TStdHashedList.SetValue (Ind: INTEGER; {OUn} NewValue: TObject);
BEGIN
  Self.fItemList.Values[Ind]        :=  NewValue;
  Self.fItems[Self.fItemList[Ind]]  :=  NewValue;
END; // .PROCEDURE TStdHashedList.SetValue

FUNCTION TStdHashedList.GetCount: INTEGER;
BEGIN
  RESULT  :=  Self.fItemList.Count;
END; // .FUNCTION TStdHashedList.GetCount

FUNCTION TStdHashedList.LinearFind (CONST Key: STRING; OUT Ind: INTEGER): BOOLEAN;
BEGIN
  RESULT  :=  Self.fItemList.Find(Key, Ind);
END; // .FUNCTION TStdHashedList.LinearFind 

PROCEDURE TStdHashedList.InsertBefore
(
        CONST Key:        STRING;
  {OUn}       Value:      TObject;
              BeforeInd:  INTEGER
);

VAR
{U} OldValue: TObject;

BEGIN
  OldValue  :=  NIL;
  // * * * * * //
  {!} ASSERT(NOT Self.fItems.GetExistingValue(Key, POINTER(OldValue)));
  Self.fItemList.InsertObj(Key, Value, BeforeInd);
  Self.fItems[Key]  :=  Value;
END; // .PROCEDURE TStdHashedList.InsertBefore

PROCEDURE TStdHashedList.Delete (Ind: INTEGER);  
BEGIN
  Self.fItems.DeleteItem(Self.fItemList[Ind]);
  Self.fItemList.Delete(Ind);
END; // .PROCEDURE TStdHashedList.Delete

FUNCTION TStdHashedList.Take (Ind: INTEGER): {OUn} TObject;
BEGIN
  RESULT  :=  NIL;
  Self.fItems.TakeValue(Self.fItemList[Ind], POINTER(RESULT));
  Self.fItemList.TakeValue(Ind);
END; // .FUNCTION TStdHashedList.Take

PROCEDURE TStdHashedList.Clear;
BEGIN
  Self.fItemList.Clear;
  Self.fItems.Clear;
END; // .PROCEDURE TStdHashedList.Clear

PROCEDURE TDictIterator.BeginIterate ({U} Dict: TDict);
BEGIN
  {!} ASSERT(Dict <> NIL);
  {!} ASSERT(NOT Dict.Locked);
  Self.fDict      :=  Dict;
  Self.fIterating :=  TRUE;
  Dict.BeginIterate;
END; // .PROCEDURE TDictIterator.BeginIterate

FUNCTION TDictIterator.IterNext: BOOLEAN;
BEGIN
  {!} ASSERT(Self.fIterating);
  Self.fIterValue :=  NIL;
  RESULT          :=  Self.fDict.IterateNext(Self.fIterKey, POINTER(Self.fIterValue));
  
  IF NOT RESULT THEN BEGIN
    Self.EndIterate;
  END; // .IF
END; // .FUNCTION TDictIterator.IterNext

PROCEDURE TDictIterator.EndIterate;
BEGIN
  IF Self.fIterating THEN BEGIN
    Self.fDict.EndIterate;
    Self.fDict      :=  NIL;
    Self.fIterating :=  FALSE;
  END; // .IF
END; // .PROCEDURE TDictIterator.EndIterate

FUNCTION TDictIterator.GetIterKey: STRING;
BEGIN
  {!} ASSERT(Self.fIterating);
  RESULT  :=  Self.fIterKey;
END; // .FUNCTION TDictIterator.GetIterKey

FUNCTION TDictIterator.GetIterValue: {Un} TObject;
BEGIN
  {!} ASSERT(Self.fIterating);
  RESULT  :=  Self.fIterValue;
END; // .FUNCTION TDictIterator.GetIterValue

FUNCTION IterateDict ({U} Dict: TDict): IDictIterator;
VAR
{O} DictIterator: TDictIterator;

BEGIN
  {!} ASSERT(Dict <> NIL);
  DictIterator  :=  TDictIterator.Create;
  // * * * * * //
  DictIterator.BeginIterate(Dict);
  RESULT  :=  DictIterator; DictIterator  :=  NIL;
END; // .FUNCTION IterateDict

END.
