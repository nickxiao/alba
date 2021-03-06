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

open Cmdliner
open Cli_common
open Cli_bench_common
open Prelude


let slice_size default =
  let doc = "partial reads phaze will use slices of size $(docv)" in
  Arg.(value
       & opt int default
       & info ["slice-size"] ~docv:"SLICE_SIZE"  ~doc
  )

let scenarios =
  let scns = [ "writes", `Writes;
               "reads", `Reads;
               "partial-reads", `Partial_reads;
               "deletes", `Deletes;
               "get_version", `GetVersion;
             ] in
  Arg.(value
       & opt_all
           (enum scns)
           []
       & info [ "scenario" ]
              ~doc:(Printf.sprintf
                      "choose which scenario to run, valid values are %s"
                      ([%show : string list] (List.map fst scns))))

let robust =
  Arg.(value
       & flag
       & info ["robust"] ~docv:"robust writes (with retry loop)")

let map_scenarios scenarios robust =
  let open Proxy_bench in
  List.map
    (function
      | `Writes -> do_writes ~robust
      | `Reads  -> do_reads
      | `Partial_reads -> do_partial_reads
      | `Deletes -> do_deletes
      | `GetVersion -> do_get_version)
    (if scenarios = []
     then [ `Writes;
            `Reads;
            `Partial_reads;
            `Deletes;
            `GetVersion;
          ]
     else scenarios)

let proxy_bench host port transport
                n_clients (n:int) file_names (power:int)
                prefix (slice_size:int) namespace_name
                scenarios robust
  =
  lwt_cmd_line
    ~to_json:false ~verbose:false
    (fun () ->
     Proxy_bench.do_scenarios
       host port transport
       n_clients n
       file_names power prefix slice_size namespace_name
       (map_scenarios scenarios robust))

let files =
  Arg.(value
       & opt_all non_dir_file []
       & info ["file"] ~doc:"file to upload, may be specified multiple times")

let proxy_bench_cmd =
  Term.(pure proxy_bench
        $ host $ port 10000 $ transport
        $ n_clients 1
        $ n 10000
        $ files
        $ power 4
        $ prefix ""
        $ slice_size 4096
        $ namespace 0
        $ scenarios
        $ robust
  ),
  Term.info "proxy-bench" ~doc:"simple proxy benchmark"

let alba_bench alba_cfg_url tls_config
               n_clients n file_name power
               prefix slice_size namespace
               scenarios robust
  =
  lwt_cmd_line
    ~to_json:false ~verbose:false
    (fun () ->
     let open Lwt.Infix in
     Alba_arakoon.config_from_url alba_cfg_url >>= fun cfg ->
     Alba_bench.do_scenarios
       (ref cfg)
       ~tls_config
       n_clients n
       file_name power prefix slice_size namespace
       (map_scenarios scenarios robust))

let alba_bench_cmd =
  Term.(pure alba_bench
        $ alba_cfg_url
        $ tls_config
        $ n_clients 1
        $ n 10000
        $ files
        $ power 4
        $ prefix ""
        $ slice_size 4096
        $ namespace 0
        $ scenarios
        $ robust),
  Term.info "alba-bench" ~doc:"simple alba benchmark"

let cmds = [
    proxy_bench_cmd;
    alba_bench_cmd;
  ]
