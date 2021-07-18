#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	declare -gxr __foundry_msg_build_msgtype="build"

	return 0
}

foundry_msg_build_new() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local commit="$4"
	local result="$5"
	local -n __foundry_msg_build_new_logs="$6"
	local -n __foundry_msg_build_new_artifacts="$7"

	local artifact_array
	local log_array
	local json
	local msg

	if ! artifact_array=$(json_array "${__foundry_msg_build_new_artifacts[@]}"); then
		return 1
	fi

	if ! log_array=$(json_array "${__foundry_msg_build_new_logs[@]}"); then
		return 1
	fi

	if ! json=$(json_object "context"    "$context"       \
				"repository" "$repository"    \
				"branch"     "$branch"        \
				"commit"     "$commit"        \
				"result"     "$result"        \
				"logs"       "$log_array"     \
				"artifacts"  "$artifact_array"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_build_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_build_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_build_get_repository() {
	local msg="$1"

        local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_build_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_build_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(foundry_msg_get_data_field "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}

foundry_msg_build_get_result() {
	local msg="$1"

	local result

	if ! result=$(foundry_msg_get_data_field "$msg" "result"); then
		return 1
	fi

	echo "$result"
	return 0
}

foundry_msg_build_get_logs() {
	local msg="$1"

	local logs

	if ! logs=$(foundry_msg_get_data_field "$msg" "logs[]"); then
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
