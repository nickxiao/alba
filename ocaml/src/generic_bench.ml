(*
Copyright (C) 2016 iNuron NV

This file is part of Open vStorage Open Source Edition (OSE), as available from


    http://www.openvstorage.org and
    http://www.openvstorage.com.

This file is free software; you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License v3 (GNU AGPLv3)
as published by the Free Software Foundation, in version 3 as it comes
in the <LICENSE.txt> file of the Open vStorage OSE distribution.

Open vStorage is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY of any kind.
*)

open Lwt.Infix

let report name (d,speed, latency, min_d, max_d) =
  Lwt_io.printlf "\n%s" name >>= fun () ->
  Lwt_io.printlf "\ttook: %fs or (%f /s)" d speed >>= fun () ->
  Lwt_io.printlf "\tlatency: %fms" (latency *. 1000.0) >>= fun () ->
  Lwt_io.printlf "\tmin: %fms" (min_d *. 1000.0) >>= fun () ->
  Lwt_io.printlf "\tmax: %fms" (max_d *. 1000.0)

let make_progress step =
  let cnt = ref 0 in
  let row = 10 * step in
  let t0 = Unix.gettimeofday () in
  fun () ->
  incr cnt;
  let i = !cnt in
  if i mod step = 0
  then
    Lwt_io.printf "%16i" i >>= fun () ->
    if (i mod row = 0 )
    then
      let t1 = Unix.gettimeofday() in
      let dt = t1 -. t0 in
      let speed = (float i) /. dt in
      Lwt_io.printlf " (%8.2fs;%6.2f/s)" dt speed
    else Lwt.return ()
  else Lwt.return ()

let measured_loop progress f n =
  let t0 = Unix.gettimeofday () in
  let rec loop min_d max_d i =
    if i = n
    then Lwt.return (min_d, max_d)
    else
      let t1 = Unix.gettimeofday() in
      f i >>= fun () ->
      let t2 = Unix.gettimeofday() in
      progress () >>= fun () ->
      let d = t2 -. t1 in
      let min_d' = min d min_d
      and max_d' = max d max_d
      in
      loop min_d' max_d' (i+1)
  in
  loop max_float 0. 0 >>= fun (min_d, max_d) ->
  let t1 = Unix.gettimeofday () in
  let d = t1 -. t0 in
  let nf = float n in
  let speed = nf /. d in
  let latency = d /. nf in
  Lwt.return (d,speed, latency, min_d, max_d)

let final_key prefix i =
  Printf.sprintf "%s%s_%016i" Osd_keys.bench_prefix prefix i

let _make_key period prefix =
  (* math:
         X_{n+1} = (aX_{n} + c) mod m
         if a = 21, c = 3 and m = 10^ x
         then this one is of full period
   *)
  let _x = ref 42 in
  fun () ->
  begin
    let i = !_x in
    let x' = (21 * !_x + 3) mod period in
    let () = _x := x'  in
    final_key prefix i
  end



let period_of_power power =
  assert (power >= 0);
  let rec loop acc = function
    | 0 -> acc
    | i -> loop (10 * acc) (i-1)
  in
  loop 1 power

let make_key period prefix = _make_key period prefix
