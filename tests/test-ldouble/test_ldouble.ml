(*
 * Copyright (c) 2016 Andy Ray.
 *
 * This file is distributed under the terms of the MIT License.
 * See the file LICENSE for details.
 *)

open OUnit2
open Ctypes

let flts = 
  [
    1.1234;
    -94.1239823897423;
    0.000000000000012;
    0.12130981239081238973249872349871346123873264876324;
    -3.92
  ]

let op1 f a = Ldouble.(to_float (f (of_float a)))
let op2 f a b = Ldouble.(to_float (f (of_float a) (of_float b)))

let chk_float x y = 
  match classify_float x, classify_float y with
  | FP_normal, FP_normal 
  | FP_subnormal, FP_subnormal 
  | FP_zero, FP_normal
  | FP_zero, FP_subnormal
  | FP_normal, FP_zero
  | FP_subnormal, FP_zero -> abs_float (x -. y) < 1e-12
  | x, y when x=y -> true (* infinite, zero, nan *)
  | _ -> false

let chk1 fop lop a = 
  let x = fop a in
  let y = op1 lop a in
  chk_float x y
  
let chk2 fop lop a b = 
  let x = fop a b in
  let y = op2 lop a b in
  chk_float x y

let test_op2 _ = 
  let assert_chk2 n f l = 
    List.iter (fun a -> List.iter (fun b -> assert_bool n @@ chk2 f l a b) flts) flts 
  in
  assert_chk2 "add" (+.) Ldouble.add;
  assert_chk2 "sub" (-.) Ldouble.sub;
  assert_chk2 "mul" ( *. ) Ldouble.mul;
  assert_chk2 "div" ( /. ) Ldouble.div;
  assert_chk2 "pow" ( ** ) Ldouble.pow;
  assert_chk2 "atan2" atan2 Ldouble.atan2;
  assert_chk2 "hypot" hypot Ldouble.hypot;
  (*assert_chk2 "rem" ??? Ldouble.rem;*)
  assert_chk2 "copysign" copysign Ldouble.copysign

let test_op1 _ = 
  let assert_chk1 n f l = 
    List.iter (fun a -> assert_bool n @@ chk1 f l a) flts
  in
  assert_chk1 "neg" (fun x -> -. x) Ldouble.neg;
  assert_chk1 "sqrt" sqrt Ldouble.sqrt;
  assert_chk1 "exp" exp Ldouble.exp;
  assert_chk1 "log" log Ldouble.log;
  assert_chk1 "log10" log10 Ldouble.log10;
  assert_chk1 "expm1" expm1 Ldouble.expm1;
  assert_chk1 "log1p" log1p Ldouble.log1p;
  assert_chk1 "cos" cos Ldouble.cos;
  assert_chk1 "sin" sin Ldouble.sin;
  assert_chk1 "tan" tan Ldouble.tan;
  assert_chk1 "acos" acos Ldouble.acos;
  assert_chk1 "asin" asin Ldouble.asin;
  assert_chk1 "atan" atan Ldouble.atan;
  assert_chk1 "cosh" cosh Ldouble.cosh;
  assert_chk1 "sinh" sinh Ldouble.sinh;
  assert_chk1 "tanh" tanh Ldouble.tanh;
  (*assert_chk1 "acosh" acosh Ldouble.acosh;
  assert_chk1 "asinh" asinh Ldouble.asinh;
  assert_chk1 "atanh" atanh Ldouble.atanh;*)
  assert_chk1 "ceil" ceil Ldouble.ceil;
  assert_chk1 "floor" floor Ldouble.floor

let test_opw _ = 
  let chk_frexp a = 
    let x, i = frexp a in
    let y, j = Ldouble.(frexp (of_float a)) in
    let y = Ldouble.to_float y in
    assert_bool "frexp" (chk_float x y && i=j)
  in
  let chk_modf a = 
    let w,x = modf a in
    let y,z = Ldouble.(modf (of_float a)) in
    let y,z = Ldouble.(to_float y, to_float z) in
    assert_bool "modf" (chk_float w y && chk_float x z)
  in
  let chk_ldexp a b = 
    let x = ldexp a b in
    let y = Ldouble.(to_float (ldexp (of_float a) b)) in
    assert_bool "ldexp" (chk_float x y)
  in
  List.iter chk_frexp flts;
  (* XXX work around bug.  see comment for LDouble.modf *)
  (if not Sys.win32 then List.iter chk_modf flts);
  List.iter (fun a -> List.iter (fun b -> chk_ldexp a b) [2;5;8]) flts

let test_classify _ = 
  assert_bool "min" Ldouble.(classify min_float = FP_normal);
  assert_bool "max" Ldouble.(classify max_float = FP_normal);
  assert_bool "epsilon" Ldouble.(classify max_float = FP_normal);
  assert_bool "nan" Ldouble.(classify nan = FP_nan);
  assert_bool "inf" Ldouble.(classify infinity = FP_infinite);
  assert_bool "-inf" Ldouble.(classify neg_infinity = FP_infinite)

let test_conv _ = 
  List.iter (fun a -> assert_bool "to/of_float" (a = Ldouble.(to_float (of_float a)))) flts;
  assert_bool "to_int" (3 = Ldouble.(to_int (of_float 3.45)));
  assert_bool "to_int" (-34 = Ldouble.(to_int (of_float (-34.999))));
  assert_bool "of_string" (3.5 = Ldouble.(to_float (of_string "3.5")));
  assert_bool "to_string" ("3.500000" = Ldouble.(to_string (of_float 3.5)))

let test_complex _ = 
  let module C = Complex in
  let cplx = 
    [
      { C.re = 2.9;    im = 4.26 };
      { C.re = 0.32;   im = -7.6 };
      { C.re = -35.1;  im = 12.3 };
      { C.re = -0.002; im = -9.1 };
    ]
  in
  let chk_complex ?(prec=1e-12) x y = C.norm (C.sub x y) < prec in
  let assert_chk2 ?prec name opc opl = 
    List.iter (fun a -> List.iter (fun b -> 
      let open Ldouble.Complex in
      assert_bool name (chk_complex ?prec (opc a b) (to_complex (opl (of_complex a) (of_complex b))))
    ) cplx) cplx
  in
  let assert_chk1 ?prec name opc opl = 
    List.iter (fun a -> 
      let open Ldouble.Complex in
      assert_bool name (chk_complex ?prec (opc a) (to_complex (opl (of_complex a))))
    ) cplx
  in
  let assert_chkf ?prec name opc opl = 
    List.iter (fun a -> 
      let open Ldouble.Complex in
      assert_bool name (chk_float (opc a) (Ldouble.to_float (opl (of_complex a))))
    ) cplx
  in
  let assert_polar () = 
    let open Ldouble.Complex in
    assert_bool "polar" 
      (chk_complex (C.polar 3.4 1.2) 
         (to_complex (polar (Ldouble.of_float 3.4) (Ldouble.of_float 1.2))))
  in

  assert_chk2 "add" C.add Ldouble.Complex.add;
  assert_chk2 "sub" C.sub Ldouble.Complex.sub;
  assert_chk2 "mul" C.mul Ldouble.Complex.mul;
  assert_chk2 "div" C.div Ldouble.Complex.div;
  (* fairly large accrue here, so reduce precision *)
  assert_chk2 "pow" ~prec:1e-3 C.pow Ldouble.Complex.pow;
  assert_chk1 "neg" C.neg Ldouble.Complex.neg;
  assert_chk1 "conj" C.conj Ldouble.Complex.conj;
  assert_chk1 "inv" C.inv Ldouble.Complex.inv;
  assert_chk1 "sqrt" C.sqrt Ldouble.Complex.sqrt;
  assert_chk1 "exp" C.exp Ldouble.Complex.exp;
  assert_chk1 "log" C.log Ldouble.Complex.log;
  assert_chkf "norm2" C.norm2 Ldouble.Complex.norm2;
  assert_chkf "norm" C.norm Ldouble.Complex.norm;
  assert_chkf "arg" C.arg Ldouble.Complex.arg;
  assert_polar ()

let test_marshal _ = 
  let assert_ldouble x = 
    let x = "foo", Ldouble.of_float x, 1 in
    let s = Marshal.to_string x [] in
    let y : string * Ldouble.t * int = Marshal.from_string s 0 in
    assert_bool "marshal ldouble" (x=y)
  in
  let assert_complex x = 
    let x = "f00", Ldouble.Complex.of_complex x, 1 in
    let s = Marshal.to_string x [] in
    let y : string * Ldouble.complex * int = Marshal.from_string s 0 in
    assert_bool "marshal ldouble complex" (x=y)
  in
  assert_ldouble 23.11234;
  assert_ldouble (-23.9345);
  assert_complex { Complex.re = 11.23; im = -46.7764 };
  assert_complex { Complex.re = 0.00037; im = 881.222314 }

let suite = "Ldouble tests" >:::
  [
    "test functions with 2 args" >:: test_op2;
    "test functions with 1 args" >:: test_op1;
    "test functions with weird args" >:: test_opw;
    "test classify" >:: test_classify;
    "test conversion" >:: test_conv;
    "test complex api" >:: test_complex;
    "test marshal" >:: test_marshal;
  ]

let _ = run_test_tt_main suite

