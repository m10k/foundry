#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	declare -gxr __foundry_msg_dist_msgtype="dist"

	return 0
}

foundry_msg_dist_new() {
	local tid="$1"
	local repository="$2"
	local artifacts=("${@:3}")

	local artifacts_json
	local json
	local msg

	if ! artifacts_json=$(json_array "${artifacts[@]}"); then
		return 1
	fi

        if ! json=$(json_object "tid"        "$tid"           \
				"repository" "$repository"    \
				"artifacts"  "$artifacts_json"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_dist_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_dist_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(foundry_msg_get_data_field "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_dist_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_dist_get_artifacts() {
	local msg="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(foundry_msg_get_data_field "$msg" "$query"); then
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
