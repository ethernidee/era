unit VfsApiDigger;
(*
  Description: Provides means for detecting real WinAPI functions addresses, bypassing proxy dlls and
               other low level code routines.
*)


(***)  interface  (***)

uses
  SysUtils, Windows, Math,
  Utils, AssocArrays;


(* Determines real exported API addresses for all specified DLL handles. If DLL imports function
   with the same name, as the exported one, then imported one is treated as real function.
   Example: kernel32.ReadProcessMemory can be a bridge to imported kernelbase.ReadProcessMemory.
   If DLL handle was processed earlier, it's skipped *)
procedure FindOutRealSystemApiAddrs (const DllHandles: array of integer);

(* Returns real code address, bypassing possibly nested simple redirection stubs like JMP [...] or JMP XXX. *)
function GetRealAddress (CodeOrRedirStub: pointer): {n} pointer;

(* Enhanced version of kernel32.GetProcAddress, traversing bridge chains and using info, gained by FindOutRealSystemApiAddrs earlier *)
function GetRealProcAddress (DllHandle: integer; const ProcName: string): {n} pointer;


(***)  implementation  (***)


const
  (* Assembler opcodes and instructions *)
  OPCODE_NOP              = $90;
  OPCODE_INT3             = $CC;
  OPCODE_JMP_CONST32      = $E9;
  OPCODE_JE_CONST32       = $840F;
  OPCODE_JNE_CONST32      = $850F;
  OPCODE_JA_CONST32       = $870F;
  OPCODE_JAE_CONST32      = $830F;
  OPCODE_JB_CONST32       = $820F;
  OPCODE_JBE_CONST32      = $860F;
  OPCODE_JG_CONST32       = $8F0F;
  OPCODE_JGE_CONST32      = $8D0F;
  OPCODE_JL_CONST32       = $8C0F;
  OPCODE_JLE_CONST32      = $8E0F;
  OPCODE_JO_CONST32       = $800F;
  OPCODE_JNO_CONST32      = $810F;
  OPCODE_JS_CONST32       = $880F;
  OPCODE_JNS_CONST32      = $890F;
  OPCODE_JP_CONST32       = $8A0F;
  OPCODE_JNP_CONST32      = $8B0F;
  OPCODE_JMP_SHORT_CONST8 = $EB;
  OPCODE_JE_SHORT_CONST8  = $74;
  OPCODE_JNE_SHORT_CONST8 = $75;
  OPCODE_JA_SHORT_CONST8  = $77;
  OPCODE_JAE_SHORT_CONST8 = $73;
  OPCODE_JB_SHORT_CONST8  = $72;
  OPCODE_JBE_SHORT_CONST8 = $76;
  OPCODE_JG_SHORT_CONST8  = $7F;
  OPCODE_JGE_SHORT_CONST8 = $7D;
  OPCODE_JL_SHORT_CONST8  = $7C;
  OPCODE_JLE_SHORT_CONST8 = $7E;
  OPCODE_JO_SHORT_CONST8  = $70;
  OPCODE_JNO_SHORT_CONST8 = $71;
  OPCODE_JS_SHORT_CONST8  = $78;
  OPCODE_JNS_SHORT_CONST8 = $79;
  OPCODE_JP_SHORT_CONST8  = $7A;
  OPCODE_JNP_SHORT_CONST8 = $7B;
  OPCODE_CALL_CONST32     = $E8;
  OPCODE_PUSH_CONST32     = $68;
  OPCODE_MOV_EAX_CONST32  = $B8;
  OPCODE_RET              = $C3;
  OPCODE_RET_CONST16      = $C2;
  OPCODE_JMP_PTR_CONST32  = $25FF;

  INSTR_JMP_EAX                = $E0FF;
  INSTR_TEST_EAX_EAX           = $C085;
  INSTR_SUB_ESP_4              = $04EC83;
  INSTR_PUSH_PTR_ESP           = $E434FF;
  INSTR_MOV_ESP_PLUS_4_CONST32 = integer($04E444C7);
  INSTR_MOV_ESP_MIN_4_CONST32  = integer($FCE444C7);
  INSTR_JUMP_PTR_ESP_MIN_4     = integer($FCE464FF);
  INSTR_CALL_PTR_ESP_MIN_4     = integer($FCE454FF);

type
  (* Unconditional jump/call OFFSET 32 instruction *)
  PJumpCall32Rec = ^TJumpCall32Rec;
  TJumpCall32Rec = packed record
    Opcode: byte;
    Offset: integer;
  end;

  TJumpType = (JMP, JE, JNE, JA, JAE, JB, JBE, JG, JGE, JL, JLE, JO, JNO, JS, JNS, JP, JNP,
               JMP_SHORT, JE_SHORT, JNE_SHORT, JA_SHORT, JAE_SHORT, JB_SHORT, JBE_SHORT, JG_SHORT, JGE_SHORT, JL_SHORT, JLE_SHORT, JO_SHORT, JNO_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT);

const
  (* Map of the first Opcode byte => short jump type (ensure, that higher bytes are zero) *)
  ShortCondJumpDecodeMap: array [$70..$7F] of TJumpType = (
    JO_SHORT, JNO_SHORT, JB_SHORT, JAE_SHORT, JE_SHORT, JNE_SHORT, JBE_SHORT, JA_SHORT, JS_SHORT, JNS_SHORT, JP_SHORT, JNP_SHORT, JL_SHORT, JGE_SHORT, JLE_SHORT, JG_SHORT
  );

  (* Map of the second Opcode byte => near jump type (the first opcode byte MUST BE $0F) *)
  NearCondJumpDecodeMap: array [$80..$8F] of TJumpType = (JO, JNO, JB, JAE, JE, JNE, JBE, JA, JS, JNS, JP, JNP, JL, JGE, JLE, JG);

var
(* Map of DLL handle => API name => Real api address *)
{O} DllRealApiAddrs: {O} AssocArrays.TObjArray {OF AssocArrays.TAssocArray};


function IsShortJumpConst8Opcode (Opcode: integer): boolean;
begin
  result := (Opcode = $EB) or Math.InRange(Opcode, low(ShortCondJumpDecodeMap), high(ShortCondJumpDecodeMap));
end;

function IsNearJumpConst32Opcode (Opcode: integer): boolean;
begin
  result := (Opcode = $E9) or (((Opcode and $FF) = $0F) and Math.InRange(Opcode shr 8, low(NearCondJumpDecodeMap), high(NearCondJumpDecodeMap)));
end;

procedure FindOutRealSystemApiAddrs (const DllHandles: array of integer);
const
  PE_SIGNATURE_LEN = 4;

type
  PImageImportDirectory = ^TImageImportDirectory;
  TImageImportDirectory = packed record
    RvaImportLookupTable:  integer;
    TimeDateStamp:         integer;
    ForwarderChain:        integer;
    RvaModuleName:         integer;
    RvaImportAddressTable: integer;
  end;

  PHintName = ^THintName;
  THintName = packed record
    Hint: word;
    Name: array [0..MAXLONGINT - 5] of char;
  end;

var
  ImportDirInfo:     PImageDataDirectory;
  ImportDir:         PImageImportDirectory;
  ImportLookupTable: Utils.PEndlessIntArr;
  ImportAddrTable:   Utils.PEndlessIntArr;
  DllApiRedirs:      {U} AssocArrays.TAssocArray {of pointer};
  DllHandle:         integer;
  i, j:              integer;

begin
  ImportDirInfo     := nil;
  ImportDir         := nil;
  ImportLookupTable := nil;
  ImportAddrTable   := nil;
  DllApiRedirs      := nil;
  // * * * * * //
  for i := 0 to high(DllHandles) do begin
    DllHandle     := DllHandles[i];
    ImportDirInfo := @PImageOptionalHeader(DllHandle + PImageDosHeader(DllHandle)._lfanew + PE_SIGNATURE_LEN + sizeof(TImageFileHeader)).DataDirectory[1];
    DllApiRedirs  := DllRealApiAddrs[Ptr(DllHandle)];

    if DllApiRedirs = nil then begin
      DllApiRedirs                    := AssocArrays.NewStrictAssocArr(Utils.NO_TYPEGUARD, not Utils.OWNS_ITEMS);
      DllRealApiAddrs[Ptr(DllHandle)] := DllApiRedirs;

      // Found valid import directory in Win32 PE
      if ((ImportDirInfo.Size > 0) and (ImportDirInfo.VirtualAddress <> 0)) then begin
        ImportDir := pointer(DllHandle + integer(ImportDirInfo.VirtualAddress));

        while ImportDir.RvaImportLookupTable <> 0 do begin
          ImportLookupTable := pointer(DllHandle + ImportDir.RvaImportLookupTable);
          ImportAddrTable   := pointer(DllHandle + ImportDir.RvaImportAddressTable);

          j := 0;

          while (j >= 0) and (ImportLookupTable[j] <> 0) do begin
            if ImportLookupTable[j] > 0 then begin
              DllApiRedirs[pchar(@PHintName(DllHandle + ImportLookupTable[j]).Name)] := Ptr(ImportAddrTable[j]);
            end;

            Inc(j);
          end;

          Inc(ImportDir);
        end; // .while
      end; // .if
    end; // .if
  end; // .for
end; // .procedure FindOutRealSystemApiAddrs

function GetRealAddress (CodeOrRedirStub: pointer): {n} pointer;
const
 MAX_DEPTH = 100;

var
  Depth: integer;

begin
  {!} Assert(CodeOrRedirStub <> nil);
  result := CodeOrRedirStub;
  Depth  := 0;

  while Depth < MAX_DEPTH do begin
    // JMP DWORD [PTR]
    if pword(result)^ = OPCODE_JMP_PTR_CONST32 then begin
      result := ppointer(integer(result) + sizeof(word))^;
    // JXX SHORT CONST8
    end else if IsShortJumpConst8Opcode(pbyte(result)^) then begin
      result := pointer(integer(result) + sizeof(byte) + pshortint(integer(result) + sizeof(byte))^);
    // JMP NEAR CONST32
    end else if pbyte(result)^ = OPCODE_JMP_CONST32 then begin
      result := pointer(integer(result) + sizeof(TJumpCall32Rec) + pinteger(integer(result) + sizeof(byte))^);
    // JXX (conditional) NEAR CONST32
    end else if IsNearJumpConst32Opcode(pword(result)^) then begin
      result := pointer(integer(result) + sizeof(word) + sizeof(integer) + pinteger(integer(result) + sizeof(word))^);
    // Regular code
    end else begin
      break;
    end; // .else

    Inc(Depth);
  end; // .while
end; // .function GetRealAddress

function GetRealProcAddress (DllHandle: integer; const ProcName: string): {n} pointer;
var
{Un} DllApiRedirs: {U} AssocArrays.TAssocArray {OF pointer};

begin
  DllApiRedirs := DllRealApiAddrs[Ptr(DllHandle)];
  result       := nil;
  // * * * * * //

  if DllApiRedirs <> nil then begin
    result := DllApiRedirs[ProcName];
  end;

  if result = nil then begin
    result := Windows.GetProcAddress(DllHandle, pchar(ProcName));
  end;

  if result <> nil then begin
    result := GetRealAddress(result);
  end;
end; // .function GetRealProcAddress

begin
  DllRealApiAddrs := AssocArrays.NewStrictObjArr(Utils.NO_TYPEGUARD, Utils.OWNS_ITEMS);
end.