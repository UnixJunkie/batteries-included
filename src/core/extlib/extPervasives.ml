(*
 * ExtPervasives - Additional functions
 * Copyright (C) 1996 Xavier Leroy
 *               2003 Nicolas Cannasse
 *               2007 Zheng Li
 *               2008 David Teller
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version,
 * with the special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

open Sexplib
TYPE_CONV_PATH "Batteries" (*For Sexplib, Bin-prot...*)

open ExtUTF8
open ExtInt
open ExtInt32
open ExtInt64
open ExtNativeint
open ExtString
open ExtBool
open ExtList
open ExtArray
open ExtFloat
open ExtPrintexc

module Pervasives = struct
  include Pervasives
  include Std
  open Enum

  (** {6 I/O}*)
  let print_guess   = Std.print
  let prerr_guess v = prerr_endline (dump v)

  let stdin             = IO.stdin
  let stdout            = IO.stdout
  let stderr            = IO.stderr
  let stdnull           = IO.stdnull

  let open_out          = File.open_out
  let open_out_bin name = 
    IO.output_channel ~cleanup:true (open_out_bin name)
  let open_out_gen mode perm name = 
    IO.output_channel ~cleanup:true (open_out_gen mode perm name)

  let flush             = IO.flush
  let flush_all         = IO.flush_all
  let close_all         = IO.close_all
  
  let output_char       = ExtChar.Char.print
  let output_string     = ExtString.String.print
  let output_rope       = Rope.print
  let output oc buf pos len = 
    ignore (IO.output oc buf pos len)
  let output_byte       = IO.write_byte
  let output_binary_int = IO.write_i32
  let output_value out v= ExtMarshal.Marshal.output out v
  let close_out         = IO.close_out
  let close_out_noerr out = 
    try IO.close_out out
    with _ -> ()

  let open_in           = File.open_in
  let open_in_bin name  = IO.input_channel ~cleanup:true (open_in_bin name)
  let open_in_gen mode perm filename = 
    IO.input_channel ~cleanup:true (open_in_gen mode perm filename)

  let input_char        = IO.read
  let input_line        = IO.read_line
  let input             = IO.input
  let really_input inp buf pos len = 
    ignore (IO.really_input inp buf pos len)
  let input_byte        = IO.read_byte
  let input_binary_int  = IO.read_i32
  let close_in          = IO.close_in
  let close_in_noerr inp=
    try IO.close_in inp
    with _ -> ()
  let input_value       = ExtMarshal.Marshal.input

  let print_rope rope   = Rope.print stdout rope
  let prerr_rope rope   = Rope.print stderr rope
  let print_ropeln rope = print_rope rope; print_newline ()
  let prerr_ropeln rope = prerr_rope rope; prerr_newline ()
  let print_all inp     = IO.copy inp IO.stdout
  let prerr_all inp     = IO.copy inp IO.stderr

  (**{6 Importing Enum}*)

  let foreach e f       = iter f e
  let exists            = exists
  let for_all           = for_all
  let fold              = fold
  let reduce            = reduce
  let find              = find
  let peek              = peek
  let push              = push
  let junk              = junk
  let map               = map
  let filter            = filter
  let concat            = concat
  let ( -- )            = ( -- )
  let ( --. )           = ( --. )
  let ( --- )           = ( --- )
  let ( --~ )           = ( --~ )
  let ( // )            = ( // )
  let ( /@ ) e f        = map f e
  let ( @/ )            = map
  let print             = print
  let get               = get
  let iter              = iter
  let scanl             = scanl

  (** {6 Concurrency}*)

  let unique_value  = ref 0
  let lock          = ref Concurrent.nolock
  let unique ()     =
    Concurrent.sync !lock Ref.post_incr unique_value

  (** {6 Operators}*)

  let first f (x, y) = (f x, y)
  let second f (x, y)= (x, f y)
  let ( **> )        = ( <| )
  let undefined ?(message="Undefined") = failwith message

  (** {6 String operations}*)

  let lowercase = String.lowercase
  let uppercase = String.uppercase

  (** {6 Directives} *)

  type printer_flags = {
    pf_width : int option;
    pf_padding_char : char;
    pf_justify : [ `right | `left ];
    pf_positive_prefix : char option;
  }

  let default_printer_flags = {
    pf_justify = `right;
    pf_width = None;
    pf_padding_char = ' ';
    pf_positive_prefix = None;
  }

  let printer_a k f x = k (fun oc -> f oc x)
  let printer_t k f = k (fun oc -> f oc)
  let printer_B k x = k (fun oc -> IO.nwrite oc (string_of_bool x))
  let printer_c k x = k (fun oc -> IO.write oc x)
  let printer_C k x = k (fun oc ->
                           IO.write oc '\'';
                           IO.nwrite oc (Char.escaped x);
                           IO.write oc '\'')

  let printer_s ?(flags=default_printer_flags) k x =
    match flags.pf_width with
      | None ->
          k (fun oc -> IO.nwrite oc x)
      | Some n ->
          let len = String.length x in
          if len >= n then
            k (fun oc -> IO.nwrite oc x)
          else
            match flags.pf_justify with
              | `right ->
                  k (fun oc ->
                       for i = len + 1 to n do
                         IO.write oc flags.pf_padding_char
                       done;
                       IO.nwrite oc x)
              | `left ->
                  k (fun oc ->
                       IO.nwrite oc x;
                       for i = len + 1 to n do
                         IO.write oc flags.pf_padding_char
                       done)

  let printer_sc ?(flags=default_printer_flags) k x =
    match flags.pf_width with
      | None ->
          k (fun oc -> String.Cap.print oc x)
      | Some n ->
          let len = String.Cap.length x in
          if len >= n then
            k (fun oc -> String.Cap.print oc x)
          else
            match flags.pf_justify with
              | `right ->
                  k (fun oc ->
                       for i = len + 1 to n do
                         IO.write oc flags.pf_padding_char
                       done;
                       String.Cap.print oc x)
              | `left ->
                  k (fun oc ->
                       String.Cap.print oc x;
                       for i = len + 1 to n do
                         IO.write oc flags.pf_padding_char
                       done)

  let printer_S ?flags k x =
    printer_s ?flags k (String.quote x)

  let printer_Sc ?flags k x =
    printer_s ?flags k (String.Cap.quote x)


    

  open Number

  let digits mk_digit base op n =
    let rec aux acc n =
      if op.compare n op.zero = 0 then
        acc
      else
        aux (mk_digit (op.to_int (op.modulo n base)) :: acc) (op.div n base)
    in
    if op.compare n op.zero = 0 then
      ['0']
    else
      aux [] n

  let printer_unum mk_digit base op ?flags k x =
    printer_s ?flags k (String.implode (digits mk_digit base op x))

  let printer_snum mk_digit base op ?(flags=default_printer_flags) k x =
    let l = digits mk_digit base op x in
    let l =
      if op.compare x op.zero < 0 then
        '-' :: l
      else
        match flags.pf_positive_prefix with
          | None ->
              l
          | Some c ->
              c :: l
    in
    printer_s ~flags k (String.implode l)

  let dec_digit x =
    char_of_int (int_of_char '0' + x)

  let oct_digit = dec_digit

  let lhex_digit x =
    if x < 10 then
      dec_digit x
    else
      char_of_int (int_of_char 'a' + x - 10)

  let uhex_digit x =
    if x < 10 then
      dec_digit x
    else
      char_of_int (int_of_char 'A' + x - 10)

  let printer_d ?flags k x = printer_snum dec_digit 10 Int.operations ?flags k x
  let printer_i ?flags k x = printer_snum dec_digit 10 Int.operations ?flags k x
  let printer_u ?flags k x = printer_unum dec_digit 10 Int.operations ?flags k x
  let printer_x ?flags k x = printer_unum lhex_digit 16 Int.operations ?flags k x
  let printer_X ?flags k x = printer_unum uhex_digit 16 Int.operations ?flags k x
  let printer_o ?flags k x = printer_unum oct_digit 8 Int.operations ?flags k x

  let printer_ld ?flags k x = printer_snum dec_digit 10l Int32.operations ?flags k x
  let printer_li ?flags k x = printer_snum dec_digit 10l Int32.operations ?flags k x
  let printer_lu ?flags k x = printer_unum dec_digit 10l Int32.operations ?flags k x
  let printer_lx ?flags k x = printer_unum lhex_digit 16l Int32.operations ?flags k x
  let printer_lX ?flags k x = printer_unum uhex_digit 16l Int32.operations ?flags k x
  let printer_lo ?flags k x = printer_unum oct_digit 8l Int32.operations ?flags k x

  let printer_Ld ?flags k x = printer_snum dec_digit 10L Int64.operations ?flags k x
  let printer_Li ?flags k x = printer_snum dec_digit 10L Int64.operations ?flags k x
  let printer_Lu ?flags k x = printer_unum dec_digit 10L Int64.operations ?flags k x
  let printer_Lx ?flags k x = printer_unum lhex_digit 16L Int64.operations ?flags k x
  let printer_LX ?flags k x = printer_unum uhex_digit 16L Int64.operations ?flags k x
  let printer_Lo ?flags k x = printer_unum oct_digit 8L Int64.operations ?flags k x

  let printer_nd ?flags k x = printer_snum dec_digit 10n Native_int.operations ?flags k x
  let printer_ni ?flags k x = printer_snum dec_digit 10n Native_int.operations ?flags k x
  let printer_nu ?flags k x = printer_unum dec_digit 10n Native_int.operations ?flags k x
  let printer_nx ?flags k x = printer_unum lhex_digit 16n Native_int.operations ?flags k x
  let printer_nX ?flags k x = printer_unum uhex_digit 16n Native_int.operations ?flags k x
  let printer_no ?flags k x = printer_unum oct_digit 8n Native_int.operations ?flags k x

  let printer_f k x = k (fun oc -> IO.nwrite oc (Printf.sprintf "%f" x))
  let printer_F k x = k (fun oc -> IO.nwrite oc (Printf.sprintf "%F" x))

  let printer_format k fmt = fmt.Print.printer fmt.Print.pattern k

  let printer_rope k x = k (fun oc -> Rope.print oc x)
  let printer_utf8 k x = k (fun oc -> UTF8.print oc x)
  let printer_obj k x = k x#print
  let printer_exn k x = k (fun oc -> ExtPrintexc.Printexc.print oc x)

  let printer_int  = printer_i
  let printer_uint = printer_u
  let printer_hex  = printer_x
  let printer_HEX  = printer_X
  let printer_oct  = printer_o

  (** {6 Value printers} *)

  let bool_printer = Bool.t_printer
  let int_printer = Int.t_printer
  let int32_printer = Int32.t_printer
  let int64_printer = Int64.t_printer
  let nativeint_printer = Native_int.t_printer
  let float_printer = Float.t_printer
  let string_printer = String.t_printer
  let list_printer = List.t_printer
  let array_printer = Array.t_printer
  let option_printer = Option.t_printer
  let maybe_printer = Option.maybe_printer
  let exn_printer paren out x =
    if paren then IO.write out '(';
    Printexc.print out x;
    if paren then IO.write out ')'

  (** {6 Clean-up}*)

  let _ = at_exit close_all; (*Called second*)
          at_exit flush_all  (*Called first*)
end