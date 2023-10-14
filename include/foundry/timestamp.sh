#!/bin/bash

# foundry/timestamp - Foundry timestamp module for toolbox
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
	return 0
}

foundry_timestamp_now() {
	date --iso-8601=seconds
	return "$?"
}

foundry_timestamp_to_unix() {
	local timestamp="$1"

	date --date="$timestamp" +"%s"
	return "$?"
}

foundry_timestamp_from_unix() {
	local unix="$1"

	date --date="@$unix" --iso-8601=seconds
	return "$?"
}
