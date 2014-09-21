unit H32GameFunction;
interface
uses
  SysUtils,windows,Dialogs,TextOut;

  procedure MyTextOut_New;stdcall;
  procedure MyCutWidth;stdcall;
  procedure MyWordWarp;stdcall;
  procedure MyDialog;stdcall;
  procedure EngTextOut(hfont,assic,surface,x,y,color:integer);stdcall;

implementation
uses
  Main;
procedure MyTextOut_New;stdcall;
asm
  pushad
  push dword ptr [ebp+$28]  //通常为-1
  push ecx                  //hfont
  push dword ptr [ebp+$24]  //对齐方式，5为居中
  push dword ptr [ebp+$20]  //ColorA
  push dword ptr [ebp+$1c]  //height
  push dword ptr [ebp+$18]  //width
  push dword ptr [ebp+$14]  //y
  push dword ptr [ebp+$10]  //x
  push dword ptr [ebp+$0c]  //surface
  push dword ptr [ebp+$08]  //pansichar
  call DoMyTextOut_New
  popad
  mov esi,$004b54ef
  jmp esi
end;
procedure MyCutWidth;stdcall;
asm
  cmp     al,$0A0
  ja      @@1
  mov     edx, dword ptr [ebp-$20]
  and     eax, $0FF
  jmp CutTemp1
  @@1:
  mov     edx, dword ptr [ebp-$20]
  mov     eax, $e
  add     esi, eax
  add     ecx, 2
  mov     dword ptr [ebp-$14], esi
  mov     dword ptr [ebp-$18], ecx
  jmp     CutTemp2
end;
procedure MyWordWarp;stdcall;
asm
  cmp     dl,$a0
  ja      @@1
  and     edx,$0FF
  add     edx,5
  jmp     WordWarp1
@@1:
  add     esi,2
  jmp     WordWarp2
end;
procedure MyDialog;stdcall;
asm
  pushad
  mov ebp,esp
  push ebp+$24
  push ebp+$28
  push ecx
  call DoMyDialog
  mov esp,ebp
  popad
  mov eax,DialogResult
  ret 8
end;
procedure EngTextOut(hfont,assic,surface,x,y,color:integer);stdcall;
asm
  push color
  push y
  push x
  push surface
  push assic
  mov ecx,hfont
  mov eax,$004b4f00
  call eax
end;
end.

