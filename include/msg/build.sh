#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	return 0
}

foundry_msg_build_new() {
	local tid="$1"
	local repository="$2"
	local branch="$3"
	local commit="$4"
	local result="$5"
	local -n __foundry_msg_build_new_logs="$6"
	local -n __foundry_msg_build_new_artifacts="$7"

	local artifact_array
	local log_array
	local json

	if ! artifact_array=$(json_array "${__foundry_msg_build_new_artifacts[@]}"); then
		return 1
	fi

	if ! log_array=$(json_array "${__foundry_msg_build_new_logs[@]}"); then
		return 1
	fi

	if ! json=$(json_object "tid"        "$tid"           \
				"repository" "$repository"    \
				"branch"     "$branch"        \
				"commit"     "$commit"        \
				"result"     "$result"        \
				"logs"       "$log_array"     \
				"artifacts"  "$artifact_array"); then
		return 1
	fi

	echo "$json"
	return 0
}

foundry_msg_build_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(json_object_get "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_build_get_repository() {
	local msg="$1"

        local repository

	if ! repository=$(json_object_get "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_build_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(json_object_get "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_build_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(json_object_get "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}

foundry_msg_build_get_result() {
	local msg="$1"

	local result

	if ! result=$(json_object_get "$msg" "result"); then
		return 1
	fi

	echo "$result"
	return 0
}

foundry_msg_build_get_logs() {
	local msg="$1"

	local logs

	if ! logs=$(json_object_get "$msg" "logs[]"); then
		return 1
	fi

	echo "$logs"
	return 0
}

foundry_msg_build_get_artifacts() {
	local msg="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(json_object_get "$msg" "$query"); then
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
