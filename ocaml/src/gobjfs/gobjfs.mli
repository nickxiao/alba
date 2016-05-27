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

module GMemPool : sig
  type t
  val init  : int -> unit
  val alloc : int -> t
  val free  : t -> unit
end

module Fragment : sig
  type t
  val show : t -> string
  type completion_id = int64
  val make : completion_id -> int -> int -> GMemPool.t -> t
  val get_bytes : t -> Lwt_bytes.t
  val get_completion_id : t -> completion_id
  val get_offset : t -> int
  val get_size : t -> int

  val free_bytes : t -> unit
end

module Batch : sig
  type t
  val make : Fragment.t list -> t
  val show : t -> string
end

module Ser : sig
  val get64_prim' : Lwt_bytes.t -> int -> int64
  val get32_prim' : Lwt_bytes.t -> int -> int32

end

module IOExecFile : sig
  val init : string -> unit
  val destroy: unit -> unit


  type handle
  val show_handle: handle -> string

  type event_channel

  val file_open: string -> Unix.open_flag list -> handle Lwt.t

  val file_write: handle -> Batch.t -> event_channel -> unit Lwt.t
  val file_read:  handle -> Batch.t -> event_channel -> unit Lwt.t
  val file_delete: string -> Fragment.completion_id  -> event_channel -> unit Lwt.t

  val file_close: handle -> unit Lwt.t

  val open_event_channel  : unit -> event_channel
  val close_event_channel : event_channel -> unit Lwt.t

  type status
  val show_status : status -> string

  val get_completion_id : status -> Fragment.completion_id
  val get_error_code : status -> int32

  val get_reap_fd : event_channel -> Lwt_unix.file_descr
  val reap : Lwt_unix.file_descr -> Lwt_bytes.t -> (int * status list) Lwt.t

end
