#!/bin/bash

__init() {
	if ! include "json" "foundry/checksum"; then
		return 1
	fi

	return 0
}

foundry_file_new() {
	local path="$1"

	local checksum

	if ! checksum=$(foundry_checksum_new_from_file "sha256" "$path"); then
		return 1
	fi

	json_object "name"     "s:${path##*/}" \
	            "checksum" "$checksum"
	return "$?"
}

foundry_file_get_name() {
	local file="$1"

	jq -r -e '.name' <<< "$file"
	return "$?"
}

foundry_file_get_checksum() {
	local file="$2"

	jq -r -e '.checksum' <<< "$file"
	return "$?"
}
