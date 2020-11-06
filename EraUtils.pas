unit EraUtils;
(*
  Miscellaneous useful functions, used by other modules.
*)


(***)  interface  (***)

uses
  SysUtils, Utils,
  Trans;


(* Converts integer to string, separating each three digit group by ThousandSeparator characer.
   Specify IgnoreSmallNumbers to leave values <= 9999 as is. Uses game locale settings.
   Example: 2138945 => "2 138 945" *)
function DecorateInt (Value: integer; IgnoreSmallNumbers: boolean = false): string;


(***)  implementation  (***)


function DecorateInt (Value: integer; IgnoreSmallNumbers: boolean = false): string;
const
  GROUP_LEN = 3;

var
  StrLen:      integer;
  IsNegative:  boolean;
  NumDelims:   integer;
  FinalStrLen: integer;
  i, j:        integer;

begin
  result := SysUtils.IntToStr(Value);

  if (Value >= 1000) or (Value < -1000) then begin
    IsNegative  := Value < 0;
    StrLen      := Length(result);
    NumDelims   := (StrLen - 1 - ord(IsNegative)) div GROUP_LEN;
    FinalStrLen := StrLen + NumDelims;
    SetLength(result, FinalStrLen);
    
    j := FinalStrLen;

    for i := 0 to StrLen - 1 - ord(IsNegative) do begin
      if (i > 0) and (i mod 3 = 0) then begin
        result[j] := Trans.LocalThousandSeparator;
        Dec(j);
      end;

      result[j] := result[StrLen - i];
      Dec(j);
    end;    
  end; // .if
end; // .function DecorateInt

end.