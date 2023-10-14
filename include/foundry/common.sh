#!/bin/bash

# foundry/common - Functions common to all foundry components
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

__init() {
	if ! include "log"; then
		return 1
	fi

	return 0
}

foundry_common_get_rootdir() {
        local caller_path

        if ! caller_path=$(realpath "${BASH_SOURCE[-1]}"); then
                log_error "Could not determine script path"
                return 1
        fi

        echo "${caller_path%/*/*}"
        return 0
}

foundry_common_get_data_schema() {
        local foundry_root

        if ! foundry_root=$(foundry_common_get_rootdir); then
                return 1
        fi

        echo "$foundry_root/spec/msgv2.schema.json"
        return 0
}

foundry_common_make_named_endpoint() {
	local endpoint_name="$1"
	local topics=("${@:2}")

	foundry_common_make_endpoint "$endpoint_name" "${topics[@]}"
	return "$?"
}

foundry_common_make_anon_endpoint() {
	local topics=("$@")

	foundry_common_make_endpoint "" "${topics[@]}"
	return "$?"
}

foundry_common_make_endpoint() {
	local endpoint_name="$1"
	local topics=("${@:2}")

	local schema
	local endpoint
	local -i err

	err=0

	if ! schema=$(foundry_common_get_data_schema); then
		log_error "Could not get path to foundry data schema"
		return 1
	fi

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open IPC endpoint $endpoint_name"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "${topics[@]}"; then
		log_error "Could not subscribe $endpoint to some of the topics in ${topics[*]}"
		err=1
	fi

	if (( err != 0 )) &&
	   [[ -n "$endpoint_name" ]]; then
		# Close endpoint if it doesn't have a name (i.e. it isn't part of a team)
		ipc_endpoint_close "$endpoint"
	fi

	echo "$endpoint"
	return "$err"
}
