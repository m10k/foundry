# foundry/msgv2 - Foundry msgv2 module for toolbox
# Copyright (C) 2023 Matthias Kruk
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
	if ! include "log" "json" "foundry/sourcepub" "foundry/sourcemod"; then
		return 1
	fi

	declare -gxri __foundry_msgv2_version=2

	return 0
}

foundry_msgv2_get() {
	local message="$1"
	local field="$2"

	if ! jq -r -e ".$field" <<< "$message"; then
		return 1
	fi

	return 0
}

foundry_msgv2_get_type() {
	local message="$1"

	foundry_msgv2_get "$message" "type"
	return "$?"
}

foundry_msgv2_is_type() {
	local message="$1"
	local expected_type="$2"

	local actual_type

	if ! actual_type=$(foundry_msgv2_get_type "$message"); then
		return 2
	fi

	if [[ "$actual_type" != "$expected_type" ]]; then
		return 1
	fi

	return 0
}

foundry_msgv2_get_buildrequest() {
	local message="$1"

	if ! foundry_msgv2_is_type "$message" "foundry.msg.build.request"; then
		return 2
	fi

	foundry_msgv2_get "$message" "message"
	return "$?"
}

foundry_msgv2_get_sourcepub() {
	local message="$1"

	if ! foundry_msgv2_is_type "$message" "foundry.msg.source.new"; then
		return 2
	fi

	foundry_msgv2_get "$message" "message"
	return "$?"
}

foundry_msgv2_new() {
	local type="$1"
	local args=("${@:2}")

	local -A constructors
	local message

	constructors["$type"]=foundry_msgv2_invalid
	constructors["foundry.msg.source.new"]=foundry_msgv2_source_new_new
	constructors["foundry.msg.source.modified"]=foundry_msgv2_source_modified_new

	if ! message=$("${constructors[$type]}" "${args[@]}"); then
		return 1
	fi

	json_object "type"    "$type"                    \
	            "version" "$__foundry_msgv2_version" \
	            "message" "$message"
	return "$?"
}

foundry_msgv2_invalid() {
	log_error "Invalid message type"
	return 1
}

foundry_msgv2_source_new_new() {
	local args=("$@")

	foundry_sourcepub_new "${args[@]}"
	return "$?"
}

foundry_msgv2_source_modified_new() {
	local args=("$@")

	foundry_sourcemod_new "${args[@]}"
	return "$?"
}
