unit FpuUtils;
(*
  FPU low-level manipulation tools.
*)


(***)  interface  (***)


type
  TFpuState = array [0..108 - 1] of byte;


procedure SaveFpu (var FpuState: TFpuState);
procedure LoadFpu (var FpuState: TFpuState);
procedure ClearFpuStack;


(***)  implementation  (***)


procedure SaveFpu (var FpuState: TFpuState);
asm
  fnsave [eax]
  frstor [eax]
  fwait
end;

procedure LoadFpu (var FpuState: TFpuState);
asm
  frstor [eax]
  fwait
end;

procedure ClearFpuStack;
asm
  // FFREEP ST(4) 4 times
  db $DF, $C4;
  db $DF, $C4;
  db $DF, $C4;
  db $DF, $C4;
  fwait
end;

end.