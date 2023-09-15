# foundry/buildrequest - Foundry build request module for toolbox
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
	if ! include "json" "foundry/vargs"; then
		return 1
	fi

	return 0
}

foundry_buildrequest_new() {
	local args=("$@")

	local -a allowed_args
	local -a required_args
	local -A parsed_args
	local -n ___sourcerefs
	local -n ___architectures
	local sourcerefs_json
	local architectures_json

	allowed_args=(
		"architectures"
		"distribution"
		"sources"
	)
	required_args=(
		"architectures"
		"sources"
	)

	if ! foundry_vargs_parse args allowed_args required_args parsed_args; then
		return 1
	fi

	___sourcerefs="${parsed_args[sources]}"
	___architectures="${parsed_args[architectures]}"

	sourcerefs_json=$(json_array "${___sourcerefs[@]}")
	architectures_json=$(json_array "${___architectures[@]}")

	json_object "sources"       "$sourcerefs_json"             \
		    "architectures" "$architectures_json"          \
		    "distribution"  "${parsed_args[distribution]}"
	return "$?"
}

foundry_buildrequest_foreach_sourceref() {
	local buildrequest="$1"
	local userfunc="$2"
	local userdata=("${@:3}")

	local -i num_sourcerefs
	local -i idx

	if ! num_sourcerefs=$(jq -r -e '.sources | length' \
				 <<< "$buildrequest"); then
		return 1
	fi

	for (( idx = 0; idx < num_sourcerefs; idx++ )); do
		local sourceref
		local -i ret_val

		if ! sourceref=$(jq -r -e ".sources[$idx]" \
				    <<< "$buildrequest"); then
			return 2
		fi

		"$userfunc" "$sourceref" "${userdata[@]}"
		ret_val="$?"

		if (( ret_val != 0 )); then
			return "$ret_val"
		fi
	done

	return 0
}

foundry_buildrequest_get_distribution() {
	local buildrequest="$1"

	if ! jq -e -r '.distribution' <<< "$buildrequest"; then
		return 1
	fi

	return 0
}

foundry_buildrequest_get_architectures() {
	local buildrequest="$1"

	if ! jq -e -r '.architectures[]' <<< "$buildrequest"; then
		return 1
	fi

	return 0
}
