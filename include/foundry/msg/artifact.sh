#!/bin/bash

# foundry/msg/artifact - Foundry artifact module for toolbox
# Copyright (C) 2021-2026 Matthias Kruk
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
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_artifact_new() {
	local uri="$1"
	local checksum="$2"

	local artifact

	if ! artifact=$(json_object "uri"      "$uri" \
				    "checksum" "$checksum"); then
		return 1
	fi

	echo "$artifact"
	return 0
}

foundry_msg_artifact_new_from_path() {
	local uri="$1"

	local output

	if ! output=$(sha512sum "$uri"); then
		return 1
	fi

	if ! [[ "$output" =~ ^([0-9a-fA-F]{128}) ]]; then
		return 1
	fi

	foundry_msg_artifact_new "$uri" "${BASH_REMATCH[1]}"
}

foundry_msg_artifact_array_new_from_path() {
	local uris=("$@")

	local uri
	local -a objs

	objs=()

	for uri in "${uris[@]}"; do
		local obj

		if ! obj=$(foundry_msg_artifact_new_from_path "$uri"); then
			return 1
		fi

		objs+=("$obj")
	done

	json_array "${objs[@]}"
}

foundry_msg_artifact_get_uri() {
	local artifact="$1"

	local uri

	if ! uri=$(jq -e -r ".uri" <<< "$artifact"); then
		return 1
	fi

	echo "$uri"
	return 0
}

foundry_msg_artifact_get_checksum() {
	local artifact="$1"

	local checksum

	if ! checksum=$(jq -e -r ".checksum" <<< "$artifact"); then
		return 1
	fi

	echo "$checksum"
	return 0
}
