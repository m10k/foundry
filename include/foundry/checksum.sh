# foundry/checksum - Foundry checksum module for toolbox
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
	declare -gxAr __foundry_checksum_generators=(
		["sha256"]=sha256sum
		["sha512"]=sha512sum
	)

	return 0
}

foundry_checksum_new_from_file() {
	local algorithm="$1"
	local file="$2"

	local generator
	local checksum

	generator="${__foundry_checksum_generators[$algorithm]}"

	if [[ -z "$generator" ]]; then
		return 1
	fi

	checksum=$("$generator" "$file" | cut -d ' ' -f 1)

	json_object "algorithm" "$algorithm" \
	            "data"      "$checksum"
	return "$?"
}

foundry_checksum_new() {
	local props=("$@")

	local allowed_props
	local required_props

	allowed_props=(
		"algorithm"
		"data"
	)
	required_props=(
		"algorithm"
		"data"
	)

	if ! foundry_vargs_parse props allowed_props required_props; then
		return 1
	fi

	json_object "${props[@]}"
	return "$?"
}

foundry_checksum_get_algorithm() {
	local checksum="$1"

	jq -r -e '.algorithm' <<< "$checksum"
	return "$?"
}

foundry_checksum_get_data() {
	local checksum="$1"

	jq -r -e '.data' <<< "$checksum"
	return "$?"
}

foundry_checksum_validate() {
	local checksum_obj="$1"
	local file="$2"

	local algorithm
	local generator
	local checksum_want
	local checksum_have

	if ! algorithm=$(foundry_checksum_get_algorithm "$checksum_obj") ||
	   ! checksum_want=$(foundry_checksum_get_data "$checksum_obj"); then
		return 1
	fi

	generator="${__foundry_checksum_generators[$algorithm]}"

	if [[ -z "$generator" ]]; then
		return 2
	fi

	if ! checksum_have=$("$generator" "$file"); then
		return 3
	fi

	checksum_have="${checksum_have%% *}"

	if [[ "$checksum_want" != "$checksum_have" ]]; then
		return 4
	fi

	return 0
}
