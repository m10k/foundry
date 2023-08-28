# foundry/vargs - Foundry variable argument list module for toolbox
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
	if ! include "log" "array"; then
		return 1
	fi

	return 0
}

foundry_vargs_parse() {
	local -n ___vargs="$1"
	local -n ___allowed_args="$2"
	local -n ___required_args="$3"
	local destination="$4"

	local arg
	local -A argnames
	local -i i
	local -i err

	argnames=()
	err=0

	for (( i = 0; i < ${#___vargs[@]}; i += 2 )); do
		argnames["${___vargs[$i]}"]="${___vargs[$i]}"
	done

	for arg in "${___required_args[@]}"; do
		if [[ -z "${argnames[$arg]}" ]]; then
			log_error "Missing required argument \"$arg\""
			err=1
		fi
	done

	for arg in "${!argnames[@]}"; do
		if ! array_contains "$arg" "${___allowed_args[@]}"; then
			log_error "Invalid argument \"$arg\""
			err=1
		fi
	done

	if (( err == 0 )) && [[ -n "$destination" ]]; then
		local -n ___parsed

		___parsed="$destination"

		for (( i = 0; i < ${#___vargs[@]}; i++ )); do
			arg="${___vargs[$i]}"
			((i++))
			___parsed["$arg"]="${___vargs[$i]}"
		done
	fi

	return "$err"
}
