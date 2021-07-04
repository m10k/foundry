#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	return 0
}

foundry_msg_signrequest_new() {
	local tid="$1"
	local artifact_data=("${@:2}")

	local artifacts_array
	local artifacts
	local signrequest
	local i

	if ! (( $# & 1 )); then
		# Invalid number of arguments
		return 1
	fi

	artifacts=()

	for (( i = 0; (i + 1) < $#; i += 2 )); do
		local artifact

		if ! artifact=$(foundry_msg_artifact_new "${artifact_data[$i]}" \
							 "${artifact_data[$((i+1))]}"); then
			continue
		fi

		artifacts+=("$artifact")
	done

	if ! artifacts_array=$(json_array "${artifacts[@]}"); then
		return 1
	fi

	if ! signrequest=$(json_object "tid"       "$tid"            \
				       "artifacts" "$artifacts_array"); then
		return 1
	fi

	echo "$signrequest"
	return 0
}

foundry_msg_signrequest_get_tid() {
	local signrequest="$1"

	local tid

	if ! tid=$(json_object_get "$signrequest" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_signrequest_get_artifacts() {
	local signrequest="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(json_object_get "$signrequest" "$query"); then
		return 1
	fi

	while read -r checksum uri; do
		local artifact

		if ! artifact=$(foundry_msg_artifact_new "$uri" "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done <<< "$raw_artifacts"

	array_to_lines "${artifacts[@]}"
	return 0
}
