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

open Prelude
open Slice
open Lwt.Infix

let recent_enough target = function
  | [] -> false
  | timestamp :: _ -> timestamp > target

let periodic_load_osds
      (alba_client : Alba_base_client.client)
      maintenance_config osds =
  let past_date =
    Unix.gettimeofday () -.
      (maintenance_config.Maintenance_config.auto_repair_timeout_seconds
       /. 2.) in
  let open Albamgr_protocol.Protocol.Osd in
  let do_one (osd_id, osd_info) =
        alba_client # osd_access # get_osd_info ~osd_id
        >>= fun (_, osd_state) ->

        (if not (recent_enough past_date osd_info.write)
         then
           begin
             Lwt.catch
               (fun () ->
                Lwt_log.debug_f "Write load on %li" osd_id >>= fun () ->
                alba_client # with_osd
                            ~osd_id
                            (fun osd ->
                             osd # apply_sequence
                                 Osd.Low
                                 []
                                 [ Osd.Update.set_string
                                     Osd_keys.test_key
                                     (Lazy.force Osd_access.large_value)
                                     Checksum.Checksum.NoChecksum
                                     false ])
                >>= function
                | Osd.Ok ->
                   Osd_state.add_write osd_state;
                   Lwt.return ()
                | Osd.Exn _ ->
                   Lwt.return ())
               (fun exn ->
                Lwt.return ())
           end
         else
           Lwt.return ())
        >>= fun () ->
        (if not (recent_enough past_date osd_info.read)
         then
           begin
             Lwt.catch
               (fun () ->
                Lwt_log.debug_f "Read load on %li" osd_id >>= fun () ->
                alba_client # with_osd
                            ~osd_id
                            (fun osd ->
                             osd # multi_get
                                 Osd.Low
                                 [ Slice.wrap_string Osd_keys.test_key; ])
                >>= function
                | [ Some _ ] ->
                   Osd_state.add_read osd_state;
                   Lwt.return ()
                | _ -> Lwt.return ())
               (fun exn ->
                Lwt.return ())
           end
         else
           Lwt.return ())
  in
  Lwt_list.iter_p
    (fun o ->
     Lwt_extra2.ignore_errors
       (fun () -> do_one o))
    osds