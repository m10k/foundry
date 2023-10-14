#!/bin/bash

# orderbot.sh - Build scheduler for RHEL-based distributions
# Copyright (C) 2023 Cybertrust Japan Co., Ltd.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

handle_sourceref() {
	local -a sourceref=("$1")
	local endpoint="$2"
	local -a architectures=("${@:3}")

	local topic
	local distribution
	local message

	topic=$(opt_get "output-topic")
	distribution=$(opt_get "distribution")

	if ! message=$(foundry_msgv2_new "foundry.msg.build.request"    \
	                                 "sources"       sourceref      \
                                         "architectures" architectures  \
	                                 "distribution"  "$distribution"); then
		return 1
	fi

	ipc_endpoint_publish "$endpoint" "$topic" "$message"
	return 0
}

handle_unexpected() {
	local endpoint="$1"
	local message="$2"

	jq -r '.' <<< "$message" | log_highlight "Unhandled message" | log_info

	return 0
}

handle_sourcepub() {
	local endpoint="$1"
	local message="$2"
	local architectures=("${@:3}")

	local sourcepub

	if ! sourcepub=$(foundry_msgv2_get_sourcepub "$message"); then
		log_error "Could not get SourcePub from source.new message"
		return 1
	fi

	foundry_sourcepub_foreach_sourceref "$sourcepub" handle_sourceref "$endpoint" "${architectures[@]}"
	return 0
}

handle_message() {
	local endpoint="$1"
	local message="$2"
	local architectures=("${@:3}")

	local -A handlers
	local msgtype

	if ! msgtype=$(foundry_msgv2_get_type "$message"); then
		msgtype="unexpected"
	fi

	handlers["$msgtype"]=handle_unexpected
	handlers["foundry.msg.source.new"]=handle_sourcepub

	"${handlers[$msgtype]}" "$endpoint" "$message" "${architectures[@]}"
	return "$?"
}

orderbot_run() {
	local input_topic="$1"
	local architectures=("${@:2}")

	local endpoint

	if ! endpoint=$(foundry_common_make_anon_endpoint "$input_topic"); then
		return 1
	fi

	while inst_running; do
		local msg
		local data

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		data=$(ipc_msg_get_data "$msg")
		handle_message "$endpoint" "$data" "${architectures[@]}"
	done

	return 0
}

main() {
	local input_topic
	local architectures
	local protocol

	opt_add_arg "I" "input-topic"         "v"   "foundry.source.new"     "The topic to receive source notifications from"
	opt_add_arg "O" "output-topic"        "v"   "foundry.build.requests" "The topic to send build requests to"
	opt_add_arg "E" "error-topic"         "v"   "foundry.errors"         "The topic to send error messages to"
	opt_add_arg "U" "undeliverable-topic" "v"   "foundry.undeliverable"  "The topic to send undeliverable messages to"
	opt_add_arg "d" "distribution"        "rv"  ""                       "The distribution to request builds for"
	opt_add_arg "a" "architecture"        "arv" architectures            "The architecture to request builds for"
	opt_add_arg "p" "protocol"            "v"   "uipc"                   "The IPC flavor to use"                          '^(ipc|uipc)$'

	if ! opt_parse "$@"; then
		return 1
	fi

	input_topic=$(opt_get "input-topic")
	protocol=$(opt_get "protocol")

	if ! include "$protocol"; then
		return 1
	fi

	inst_start orderbot_run "$input_topic" "${architectures[@]}"
	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "inst" "foundry/common" "foundry/msgv2"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
