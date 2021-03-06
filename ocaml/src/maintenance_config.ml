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

type t = {
    enable_auto_repair : bool;
    auto_repair_timeout_seconds : float;
    auto_repair_disabled_nodes : string list;

    enable_rebalance : bool;
  } [@@deriving show, yojson]

let from_buffer buf =
  let ser_version = Llio.int8_from buf in
  assert (ser_version = 1);
  let enable_auto_repair = Llio.bool_from buf in
  let auto_repair_timeout_seconds = Llio.float_from buf in
  let auto_repair_disabled_nodes = Llio.list_from Llio.string_from buf in
  let enable_rebalance = Llio.bool_from buf in
  { enable_auto_repair;
    auto_repair_timeout_seconds;
    auto_repair_disabled_nodes;
    enable_rebalance;
  }

let to_buffer buf { enable_auto_repair;
                    auto_repair_timeout_seconds;
                    auto_repair_disabled_nodes;
                    enable_rebalance; } =
  Llio.int8_to buf 1;
  Llio.bool_to buf enable_auto_repair;
  Llio.float_to buf auto_repair_timeout_seconds;
  Llio.list_to Llio.string_to buf auto_repair_disabled_nodes;
  Llio.bool_to buf enable_rebalance

module Update = struct
    type t = {
        enable_auto_repair' : bool option;
        auto_repair_timeout_seconds' : float option;
        auto_repair_add_disabled_nodes : string list;
        auto_repair_remove_disabled_nodes : string list;

        enable_rebalance' : bool option;
      }

    let from_buffer buf =
      let ser_version = Llio.int8_from buf in
      assert (ser_version = 1);
      let enable_auto_repair' = Llio.option_from Llio.bool_from buf in
      let auto_repair_timeout_seconds' = Llio.option_from Llio.float_from buf in
      let auto_repair_remove_disabled_nodes =
        Llio.list_from Llio.string_from buf in
      let auto_repair_add_disabled_nodes =
        Llio.list_from Llio.string_from buf in
      let enable_rebalance' = Llio.option_from Llio.bool_from buf in
      { enable_auto_repair';
        auto_repair_timeout_seconds';
        auto_repair_remove_disabled_nodes;
        auto_repair_add_disabled_nodes;
        enable_rebalance';
      }

    let to_buffer buf { enable_auto_repair';
                        auto_repair_timeout_seconds';
                        auto_repair_remove_disabled_nodes;
                        auto_repair_add_disabled_nodes;
                        enable_rebalance'; } =
      Llio.int8_to buf 1;
      Llio.option_to Llio.bool_to buf enable_auto_repair';
      Llio.option_to Llio.float_to buf auto_repair_timeout_seconds';
      Llio.list_to Llio.string_to buf auto_repair_remove_disabled_nodes;
      Llio.list_to Llio.string_to buf auto_repair_add_disabled_nodes;
      Llio.option_to Llio.bool_to buf enable_rebalance'

    let apply { enable_auto_repair;
                auto_repair_timeout_seconds;
                auto_repair_disabled_nodes;
                enable_rebalance; }
              { enable_auto_repair';
                auto_repair_timeout_seconds';
                auto_repair_remove_disabled_nodes;
                auto_repair_add_disabled_nodes;
                enable_rebalance'; }
      =
      { enable_auto_repair = Option.get_some_default
                               enable_auto_repair
                               enable_auto_repair';
        auto_repair_timeout_seconds = Option.get_some_default
                                        auto_repair_timeout_seconds
                                        auto_repair_timeout_seconds';
        auto_repair_disabled_nodes =
          List.filter
            (fun node ->
             not (List.mem node auto_repair_remove_disabled_nodes))
            (List.rev_append
               auto_repair_add_disabled_nodes
               auto_repair_disabled_nodes);
        enable_rebalance = Option.get_some_default
                             enable_rebalance
                             enable_rebalance'; }
  end
