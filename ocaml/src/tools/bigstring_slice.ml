(*
Copyright 2015 Open vStorage NV

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*)

type t = {
  bs : Lwt_bytes.t;
  offset : int;
  length : int;
}

let from_bigstring bs offset length =
  { bs; offset; length; }

let wrap_bigstring bs =
  from_bigstring bs 0 (Lwt_bytes.length bs)

let create length =
  wrap_bigstring (Lwt_bytes.create length)

let ptr_start t =
  let open Ctypes in
  bigarray_start array1 t.bs +@ t.offset

let extract_to_bigstring t =
  Lwt_bytes.extract t.bs t.offset t.length

let extract t offset length =
  let bs = Lwt_bytes.extract t.bs (t.offset + offset) length in
  wrap_bigstring bs

let length t = t.length