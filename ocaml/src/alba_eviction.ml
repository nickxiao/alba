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

open Prelude
open Lwt.Infix

let do_eviction
      (alba_client : Alba_client.alba_client)
      ~prefixes =
  Lwt_list.map_p
    (fun prefix ->
     alba_client # mgr_access # list_all_namespaces_with_prefix prefix)
    prefixes >>= fun namespaces ->
  let namespaces =
    List.fold_left
      (fun acc (_, namespaces) ->
       List.rev_append namespaces acc)
      []
      namespaces
  in
  Lwt_list.map_p
    (fun (name, namespace) ->
     alba_client # get_base_client # with_nsm_client
                 ~namespace:name
                 (fun nsm_client ->
                  nsm_client # get_stats >>= fun stats ->
                  Lwt.return (name, namespace.Albamgr_protocol.Protocol.Namespace.id, stats)
                 )
    )
    namespaces
  >>= fun r ->
  let (obj_cnt_total, namespaces_with_objects, namespaces, empty_namespaces) =
    List.fold_left
      (fun (obj_cnt_total, namespaces_with_objects, namespaces, empty_namespaces)
           (namespace_name, namespace_id, stats) ->
       let obj_cnt =
         List.fold_left
           (fun acc (_, cnt) ->
            Int64.add acc cnt)
           0L
           (snd stats.Nsm_model.NamespaceStats.bucket_count)
       in
       let has_objects = obj_cnt > 0L in
       Int64.add obj_cnt obj_cnt_total,
       namespaces_with_objects + (if has_objects then 1 else 0),
       (if has_objects then namespace_id::namespaces else namespaces),
       (if has_objects then empty_namespaces else namespace_name :: empty_namespaces))
      (0L, 0, [], [])
      r
  in
  let victims_per_namespace =
    (* remove 1% of all objects, divided equally among all namespaces *)
    Int64.to_float (Int64.div obj_cnt_total 100L) /. float namespaces_with_objects
    |> ceil |> int_of_float
  in
  let delete_objects () =
    Lwt_list.iter_p
      (fun namespace_id ->
       alba_client # get_base_client # with_nsm_client'
                   ~namespace_id
                   (fun nsm_client ->
                    let first, last, reverse = make_first_last_reverse () in
                    let rec inner = function
                      | 0 -> Lwt.return ()
                      | todo ->
                         nsm_client # list_objects_by_id
                                    ~first ~finc:true
                                    ~last ~reverse
                                    ~max:todo >>= fun ((cnt, objs), has_more) ->
                         Lwt_list.iter_s
                           (fun manifest ->
                            nsm_client # delete_object
                                       ~object_name:manifest.Nsm_model.Manifest.name
                                       ~allow_overwrite:Nsm_model.AnyPrevious
                            >|= ignore)
                           objs >>= fun () ->
                         if has_more
                         then inner (todo - cnt)
                         else Lwt.return ()
                    in
                    inner victims_per_namespace
                   )
      )
      namespaces
  in
  let delete_empty_namespaces () =
    Lwt_list.iter_p
      (fun namespace -> alba_client # delete_namespace ~namespace)
      empty_namespaces
  in
  Lwt.join
    [ delete_objects ();
      delete_empty_namespaces ();
    ]

let alba_eviction
      (alba_client : Alba_client.alba_client)
      ~prefixes
      ~presets
  =
  Lwt.ignore_result (alba_client # osd_access # populate_osds_info_cache);

  let coordinator =
    Maintenance_coordination.make_maintenance_coordinator
      (alba_client # mgr_access)
      ~lease_name:"cache_eviction"
      ~lease_timeout:20.
      ~registration_prefix:"cache_eviction"
  in
  let () = coordinator # init in

  Lwt_extra2.run_forever
    "alba eviction"
    (fun () ->

     if coordinator # is_master
     then
       begin

         (* TODO maybe use some info from the involved presets to decide when 
          * to remove items from the cache ...
          * decided for now to use a simpler way to make that decision (see below) *)
         (* Lwt_list.map_p *)
         (*   (fun preset_name -> *)
         (*    alba_client # get_base_client # get_preset_info ~preset_name) *)
         (*   presets *)
         (* >>= fun presets -> *)

         let cnt_total, cnt_full, _ =
           Hashtbl.fold
             (fun osd_id (osd_info, osd_state)
                  (cnt_total, cnt_full, acc) ->
              let open Nsm_model in
              let used = Int64.to_float osd_info.OsdInfo.used in
              let total = Int64.to_float osd_info.OsdInfo.total in
              let fill_ratio = used /. total in
              (cnt_total + 1,
               cnt_full + (if fill_ratio > 0.9 then 1 else 0),
               (osd_id,
                used, total,
                fill_ratio)
               :: acc))
             (alba_client # osd_access # osds_info_cache)
             (0, 0, [])
         in

         if float cnt_total /. float cnt_full < 2.
         then
           (* more than half of the disks are >90% filled,
            * so let's do some cleanup *)
           do_eviction alba_client ~prefixes
         else
           Lwt.return ()
       end
     else
       Lwt.return ())
    60.
