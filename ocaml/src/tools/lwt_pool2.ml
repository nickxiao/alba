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

type 'a t = {
  factory : unit -> 'a Lwt.t;
  cleanup : 'a -> unit Lwt.t;
  check : 'a -> exn -> bool;
  max_size : int;
  mutable count : int;
  available_items : 'a Queue.t;
  waiters : unit Lwt.u Queue.t;
  mutable finalizing : bool;
}

let create max_size ~check ~factory ~cleanup =
  { factory; cleanup;
    check; max_size;
    count = 0; available_items = Queue.create ();
    waiters = Queue.create ();
    finalizing = false;
  }

let rec acquire t =
  if Queue.is_empty t.available_items
  then begin
    if t.count < t.max_size
    then begin
      (* create one extra *)
      t.count <- t.count + 1;
      Lwt.catch
        (fun () -> t.factory ())
        (fun exn ->
           t.count <- t.count - 1;
           Lwt.fail exn)
    end else begin
      (* wait for a member to become available *)
      let t', u = Lwt.wait () in
      Queue.push u t.waiters;
      t' >>= fun () ->
      acquire t
    end
  end else
    (* take an available member *)
    let a = Queue.pop t.available_items in
    Lwt.return a

let use t f =
  if t.finalizing
  then Lwt.fail_with "attempting to use a resource from a pool which is being finalized"
  else begin
    Lwt.finalize
      (fun () ->
         acquire t >>= fun a ->
         Lwt.catch
           (fun () ->
              f a >>= fun r ->
              (if t.finalizing
               then begin
                 t.count <- t.count - 1;
                 t.cleanup a
               end else begin
                 Queue.push a t.available_items;
                 Lwt.return ()
               end) >>= fun () ->
              Lwt.return r)
           (fun exn ->
              if t.check a exn
              then
                begin
                  Queue.push a t.available_items;
                  Lwt.fail exn
                end
              else
                begin
                  t.count <- t.count - 1;
                  t.cleanup a >>= fun () ->
                  Lwt.fail exn
                end))
      (fun () ->
         (* wake up the first waiter *)
         (try Lwt.wakeup (Queue.pop t.waiters) ()
          with Queue.Empty -> ());
         Lwt.return ())
  end

let finalize t =
  t.finalizing <- true;
  let ts =
    Queue.fold
      (fun acc item ->
         t.cleanup item :: acc)
      []
      t.available_items in
  Lwt.join ts
