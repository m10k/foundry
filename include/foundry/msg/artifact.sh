#!/bin/bash

# foundry/msg/artifact - Foundry artifact module for toolbox
# Copyright (C) 2021-2022 Matthias Kruk
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

	if ! checksum=$(jq -e -e ".checksum" <<< "$artifact"); then
		return 1
	fi

	echo "$checksum"
	return 0
}
