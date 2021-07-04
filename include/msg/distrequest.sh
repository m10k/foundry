#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_distrequest_new() {
	local tid="$1"
	local artifact_data=("${@:2}")

	local artifacts_array
	local artifacts
	local distrequest
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

	if ! distrequest=$(json_object "tid"       "$tid"            \
				       "artifacts" "$artifacts_array"); then
		return 1
	fi

	echo "$distrequest"
	return 0
}

foundry_msg_distrequest_get_tid() {
	local distrequest="$1"

	local tid

	if ! tid=$(json_object_get "$distrequest" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_distrequest_get_artifacts() {
	local distrequest="$1"

	local raw_artifacts
	local artifacts
	local artifact
	local checksum
	local uri

	if ! raw_artifacts=$(json_object_get "$distrequest" 'artifacts[] | "\(.checksum) \(.uri)"'); then
		return 1
	fi

	while read -r checksum uri; do
		if ! artifact=$(json_object "uri" "$uri" \
					    "checksum" "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done <<< "$raw_artifacts"

	for artifact in "${artifacts[@]}"; do
		echo "$artifact"
	done

	return 0
}
