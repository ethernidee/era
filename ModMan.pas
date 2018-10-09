unit ModMan;
(*
  Peforms mod list bulding, sets up VFS, includes debugging facilities, etc.
*)


(***)  interface  (***)

uses
  SysUtils, Utils, DataLib;

type
  TModManager = class
   private
    {O} fModList

   public
    constructor Create;
  end; // .class TModManager


(***)  implementation  (***)
uses VFS;


const
  (* Command line arguments *)
  CMDLINE_ARG_MODLIST = 'modlist';



end.