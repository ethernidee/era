UNIT TypeWrappers;
{
DESCRIPTION:  Wrappers for primitive types into objects suitable for storing in containers
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Utils;

TYPE
  TString = CLASS (Utils.TCloneable)
    Value:  STRING;
    
    CONSTRUCTOR Create (CONST Value: STRING);
    PROCEDURE Assign (Source: Utils.TCloneable); OVERRIDE;
  END; // .CLASS TString

  TEventHandler = CLASS (Utils.TCloneable)
    Handler:  Utils.TEventHandler;
    
    CONSTRUCTOR Create (Handler: Utils.TEventHandler);
    PROCEDURE Assign (Source: Utils.TCloneable); OVERRIDE;
  END; // .CLASS TEventHandler
  

(***) IMPLEMENTATION (***)


CONSTRUCTOR TString.Create (CONST Value: STRING);
BEGIN
  Self.Value  :=  Value;
END; // .CONSTRUCTOR TString.Create

PROCEDURE TString.Assign (Source: Utils.TCloneable);
BEGIN
  Self.Value  :=  (Source AS TString).Value;
END; // .PROCEDURE TString.Assign

CONSTRUCTOR TEventHandler.Create (Handler: Utils.TEventHandler);
BEGIN
  Self.Handler  :=  Handler;
END; // .CONSTRUCTOR TEventHandler.Create

PROCEDURE TEventHandler.Assign (Source: Utils.TCloneable);
BEGIN
  Self.Handler  :=  (Source AS TEventHandler).Handler;
END; // .PROCEDURE TEventHandler.Assign

END.
