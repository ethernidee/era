unit TextOut;

(* ERA notes
 * Chinese character code > 160
 * If next character code <= 160, it becomes 161
 * Example [170][32] => [170][161]
 * GB2312/GBK
 *)

interface
uses
  Dialogs, Windows, SysUtils, Math;
  
  procedure DoMyTextOut_New (str:pAnsiChar; Surface, x, y, BoxWidth, BoxHeight, ColorA, Mode, hfont, unknow:integer); stdcall;
  procedure DoMyDialog (hfont, MaxWidth: integer; s: pAnsiChar); stdcall;

implementation

uses
  H32GameFunction,Main;

const
  Font24Width:  integer = 28;
  Font24Height: integer = 25;

  Font12Width:  integer = 14;
  Font12Height: integer = 16;

  FontTinyWidth:  integer = 11;
  FontTinyHeight: integer = 11;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

type
  PChars12 = ^TChars12;
  TChars12 = packed array [0..11] of char;

  {$ALIGN OFF}
  PBinaryTreeItem = ^TBinaryTreeItem;
  TBinaryTreeItem = object
   public
    VTable:   ppointer;
    Name:     TChars12;
    NameEnd:  integer;
    ItemType: integer;
    RefCount: integer;
  end; // .object TBinaryTreeItem
  {$ALIGN ON}

  PFontCharInfo = ^TFontCharInfo;
  TFontCharInfo = packed record
    SpaceBefore: integer;
    Width:       integer;
    SpaceAfter:  integer;
  end;

  {$ALIGN OFF}
  PFontItem = ^TFontItem;
  TFontItem = object (TBinaryTreeItem)
   public
    FirstChar: char; // ???
    LastChar:  char; // ???
    Depth:     byte; // ???
    XSpace:    byte; // ???
    YSpace:    byte; // ???
    Height:    byte; // ???
    Unk1:      array [1..26] of byte;
    CharInfos: array [#0..#255] of TFontCharInfo;
  end; // .object TFontItem
  {$ALIGN ON}

var
  BytesPerPixel: integer = 2;
  TextColorMode: pword   = Ptr($694DB0);
  Color16To32:   function (Color16: integer): integer;

procedure UpdateBytesPerPixel;
begin
  BytesPerPixel := pbyte($5FA228 + 3)^;
end;

function Color16To32Func (Color16: integer): integer;
var
  Red:   integer;
  Green: integer;
  Blue:  integer;

begin
  Red   := ((Color16 shr 11) and $1F) shl 3;
  Green := ((Color16 shr 5) and $3F) shl 2;
  Blue  := (Color16 and $1F) shl 3;

  result := (Red shl 16) or (Green shl 8) or Blue;
end;

function Color15To32Func (Color15: integer): integer;
var
  Red:   integer;
  Green: integer;
  Blue:  integer;

begin
  Red   := ((Color15 shr 10) and $1F) shl 3;
  Green := ((Color15 shr 5) and $1F) shl 3;
  Blue  := (Color15 and $1F) shl 3;

  result := (Red shl 16) or (Green shl 8) or Blue;
end;

//返回一个汉字的区位码
procedure GetQWCode(HZ:pAnsiChar;var Q,W:word);stdcall;
begin
  Q := byte(HZ[0]) - 160;

  if byte(HZ[1]) > 160 then begin
    W := byte(HZ[1]) - 160;
  end else begin
    W := 1;
  end;
end;

procedure MakeChar12(StartY,StartX,Surface:integer;HZ:pAnsiChar;Color:word);stdcall;
var
  OffSet:integer;
  GetStr:array [0..23] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScreenWidth:integer;

begin
  ScreenWidth:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*24;
  F12.Position:=OffSet;
  F12.Read(GetStr,sizeof(GetStr));
  
  x:=0;
  y:=0;
  i:=0;
  
  while(i<=23) do
  begin
    temp:=GetStr[i];
    for j:=0 to 7 do begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy:=(StartY+x)*ScreenWidth+(y+StartX)*BytesPerPixel;
        
        if BytesPerPixel = 2 then begin
          pWord(pInteger(Surface+$30)^+xy)^:=Color;
        end else begin
          pinteger(pInteger(Surface+$30)^+xy)^:=Color16To32(Color);
        end;
      end;
      Inc(x);
      if x>15 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

procedure MakeChar10(StartY,StartX,Surface:integer;HZ:pAnsiChar;Color:word);stdcall;
var
  OffSet:integer;
  GetStr:array[0..19] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScreenWidth:integer;
begin
  ScreenWidth:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*20;
  F10.Position:=OffSet;
  F10.Read(GetStr,sizeof(GetStr));
  x:=0;
  y:=0;
  i:=0;
  while(i<=19) do
  begin
    temp:=getstr[i];
    for j:=0 to 7 do
    begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy:=(StartY+y)*ScreenWidth+(x+StartX)*BytesPerPixel;
        
        if BytesPerPixel = 2 then begin
          pWord(pInteger(surface+$30)^+xy)^:=Color;
        end else begin
          pinteger(pInteger(surface+$30)^+xy)^:=Color16To32(Color);
        end;
      end;
      Inc(x);
      if x>15 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

procedure MakeChar24(StartY,StartX,Surface:integer;HZ:pAnsiChar;Color:word);stdcall;
var
  OffSet:integer;
  GetStr:array[0..71] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScreenWidth:integer;
begin
  ScreenWidth:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*72;
  F24.Position:=OffSet;
  F24.Read(GetStr,sizeof(GetStr));
  x:=0;
  y:=0;
  i:=0;
  while(i<=71) do
  begin
    temp:=getstr[i];
    for j:=0 to 7 do
    begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy:=(StartY+y)*ScreenWidth+(x+StartX)*BytesPerPixel;
        
        if BytesPerPixel = 2 then begin
          pWord(pInteger(surface+$30)^+xy)^:=Color;
        end else begin
          pinteger(pInteger(surface+$30)^+xy)^:=Color16To32(Color);
        end;
      end;
      Inc(x);
      if x>23 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

function GetEngCharWidth (Assic:byte;hfont:dword):integer;stdcall;
var
  temp:integer;
begin
  temp:=assic*$c+$3c+hfont;
  result:=pInteger(temp)^+pInteger(temp+4)^+pInteger(temp+8)^;
end;

function GetColor(ColorA: integer): word; stdcall;
begin
  if ColorA < 256 then result := ColorA + 9
  else result := ColorA - 256;
end;

procedure SetFont (hfont: integer; var Width, Height: integer); stdcall;
begin
  if pInteger(hfont + 4)^ = 1718053218 then begin
    Width  := Font24Width;
    Height := Font24Height;
  end else if pInteger(hfont + 4)^ = 2037279092 then begin
    Width  := FontTinyWidth;
    Height := FontTinyHeight;
  end else begin
    Width  := Font12Width;
    Height := Font12Height;
  end;
end;

//得到文字一共要占几行
function GetStrRowCount(str:pAnsiChar;hfont,RowWidth:integer):integer;stdcall;
var
  i,Length,Row,FontWidth,FontHeight:integer;
begin
  if str[0]=#0 then
  begin
    result:=0;
    exit;
  end;
  SetFont(hfont,FontWidth,FontHeight);
  i:=0;
  Length:=0;
  Row:=1;
  while (str[i]<>#0) do
  begin
    if (str[i] = '{') or (str[i] = '}') then
    begin
      Inc(i);
    end else
    if (str[i] = #10) then
    begin
      Inc(i);
      Length:=0;
      if str[i]<>#0 then row:=row+1;
    end else
    if (str[i] > #160) and (str[i+1] > #160) then
    begin
      Length:=Length+FontWidth;
      i:=i+2;
      if Length>RowWidth then
      begin
        Length:=0;
        if str[i]<>#0 then row:=row+1;
      end;
    end else
    begin
      Length:=Length+GetEngCharWidth(byte(str[i]),hfont);
      Inc(i);
      if Length>RowWidth then
      begin
        Length:=0;
        if str[i]<>#0 then row:=row+1;
      end;
    end;
  end;
  result:=Row;
end;

procedure DoMyDialog(hfont,MaxWidth:integer;s:pAnsiChar);stdcall;
begin
  DialogResult:=GetStrRowCount(s,hfont,MaxWidth);
end;

//输出一行文字,其中CharLength为字符个数
procedure DrawLineToPcx16 (str: pAnsiChar; StrLen, ColorA, hfont, y, x: integer; Surface: integer); stdcall;
const 
  DEF_COLOR = -1;

var
  FontWidth, FontHeight, i, cy, cx: integer;
  ColorB, ColorSel: word;
  Color: integer;

begin
  SetFont(hfont, FontWidth, FontHeight);

  i        := 0;
  cy       := y;
  cx       := x;
  ColorB   := GetColor(ColorA);
  ColorSel := 0;
  
  while (i < StrLen) and not (Str[i] in [#0, #10]) do begin
    if Str[i] > ' ' then begin
      ChineseGotoNextChar;
    end;
  
    if Str[i] = '{' then begin
      ColorSel := 1;
    end else if Str[i] = '}' then begin
      ColorSel := 0;
    end else begin
      Color := ChineseGetCharColor;

      if Color = DEF_COLOR then begin
        Color := pWord(hfont+(ColorB + ColorSel) * 2 + $1058)^;
      end;

      if (str[i] > #160) and (str[i + 1] > #160) then begin
        if FontWidth = Font12Width   then MakeChar12(cy, cx, Surface, @str[i], Color);
        if FontWidth = FontTinyWidth then MakeChar10(cy, cx, Surface, @str[i], Color);
        if FontWidth = Font24Width   then MakeChar24(cy, cx, Surface, @str[i], Color);
        
        cx := cx + FontWidth;
        Inc(i);
      end else begin
        EngTextOut(hfont, byte(str[i]), Surface, cx, cy, ColorB);
        cx := cx + GetEngCharWidth(byte(str[i]), hfont);
      end;
    end; // .else
    
    Inc(i);
  end; // .while
end; // .procedure DrawLineToPcx16

procedure DoMyTextOut_New (str:pAnsiChar; Surface, x, y, BoxWidth, BoxHeight, ColorA, Mode, hfont, unknow: integer); stdcall;
var
  MaxRow, FontWidth, FontHeight, posStart, posEnd, l, i, row, startX, startY, space, spacerow, j:integer;

begin 
  UpdateBytesPerPixel;

  if TextColorMode^ = TEXTMODE_15BITS then begin
    Color16To32 := Color15To32Func;
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color16To32 := Color16To32Func;
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;

  //先计算一下总共要用的行数
  MaxRow := GetStrRowCount(str, hfont, BoxWidth);
  SetFont(hfont, FontWidth, FontHeight);

  //PosStart:=0;
  PosEnd   := 0;
  Row      := -1;
  SpaceRow := -1;
  Space    := -1;
  
  while Str[PosEnd] <> #0 do begin
    Row      := Row + 1;
    PosStart := PosEnd;
    i        := posEnd;
    l        := 0;
    
    while str[i] <> #0 do begin
      if str[i] = #10 then begin
        i := i + 1;
        break;
      end else if (str[i] = '{') or (str[i] = '}') then begin
        Inc(i);
      end else if (str[i] > #160) and (str[i + 1] > #160) then begin
        Space    := i + 2;
        SpaceRow := Row;
        l        := l + FontWidth;
        i        := i + 2;
        
        if l>BoxWidth then begin
          //目前没有对标点符号进行处理
          //if byte(str[i])>160 True then
          i:=i-2;
          l:=l-FontWidth;
          break;
        end;
      end else begin
        if str[i] = ' ' then begin
          Space    := i+1;
          SpaceRow := Row;
        end;
        
        l := l + GetEngCharWidth(byte(str[i]), hfont);
        
        Inc(i);
        
        if l>BoxWidth then begin
          //英文必须以单词为单位，整个单词换行，以SPACE记录上个空格或汉字位置，以SPACEROW记录上个空格所在行
          if (SpaceRow=Row)and (Space>-1) then
          begin
            for j:=Space to i-1 do
              l:=l-GetEngCharWidth(byte(str[j]),hfont);
            i:=Space;
            break;
          end else
          begin
            l:=l-GetEngCharWidth(byte(str[i]),hfont);
            i:=i-1;
            break;
          end;
        end;
      end;
    end;
    
    posEnd:=i;
    startX:=x;
    startY:=y+FontHeight*Row;
    
    case mode of
      0,4,8 :startX:=x;
      1,5,9 :startX:=x+((BoxWidth-l) div 2);
      2,6,10:startX:=x+BoxWidth-l;
    end;
    
    case mode of
      0,1,2,3:startY:=y+(FontHeight)*Row;
      4,5,6,7:begin
                  if BoxHeight < MaxRow*(FontHeight) then
                  begin
                    if BoxHeight < (FontHeight+FontHeight) then
                      StartY:=y+(FontHeight*Row)+(BoxHeight - FontHeight)div 2
                    else startY:=y+(FontHeight)*Row;
                  end                else startY:=y+(FontHeight)*Row+(BoxHeight - MaxRow*(FontHeight))div 2;
              end;
      8,9,10,11:begin
                  if BoxHeight < MaxRow*(FontHeight) then
                  begin
                    if BoxHeight < (FontHeight+FontHeight) then
                      StartY:=y+(FontHeight*Row)+(BoxHeight - FontHeight)
                    else startY:=y+(FontHeight)*Row;
                  end
                  else startY:=y+(FontHeight)*Row+BoxHeight - MaxRow*(FontHeight);
                end;
    end;
    //如果超出显示范围，则退出
    //if StartX+l>x+BoxWidth then exit;

    if (StartY + FontHeight > y + BoxHeight) and (Row > 0) then begin
      exit
    end;

    if PosEnd - PosStart > 0 then begin
      DrawLineToPcx16(@str[PosStart], PosEnd-PosStart, ColorA, hfont, StartY, StartX, Surface);
    end;
  end;
end;
end.
