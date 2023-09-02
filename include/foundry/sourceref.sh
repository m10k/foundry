# foundry/sourceref - Foundry sourceref module for toolbox
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
	if ! include "log" "json" "foundry/vargs"; then
		return 1
	fi

	return 0
}

foundry_sourceref_new() {
	local type="$1"
	local props=("${@:2}")

	local -A constructors

	constructors["$type"]=false
	constructors["git"]=foundry_sourceref_git_new
	constructors["srpm"]=foundry_sourceref_srpm_new

	"${constructors[$type]}" "${props[@]}"
	return "$?"
}

foundry_sourceref_git_new() {
	local props=("$@")

	local allowed_props
	local required_props

	allowed_props=(
		"repository"
		"branch"
		"commit"
		"uri"
		"distribution"
	)
	required_props=(
		"uri"
	)

	if ! foundry_vargs_parse props allowed_props required_props; then
		return 1
	fi

	json_object "type" "git" "${props[@]}"
	return "$?"
}

foundry_sourceref_srpm_new() {
	local props=("$@")

	local allowed_props
	local required_props

	allowed_props=(
		"uri"
		"distribution"
		"checksum"
	)
	required_props=(
		"uri"
	)

	if ! foundry_vargs_parse props allowed_props required_props; then
		return 1
	fi

	json_object "type" "srpm" "${props[@]}"
	return "$?"
}

foundry_sourceref_get_uri() {
	local sourceref="$1"

	if ! jq -e -r '.uri' <<< "$sourceref"; then
		return 1
	fi

	return 0
}

foundry_sourceref_get_checksum() {
	local sourceref="$1"

	if ! jq -e -r '.checksum' <<< "$sourceref"; then
		return 1
	fi

	return 0
}
