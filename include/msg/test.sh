#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_test_msgtype="test"

	return 0
}

foundry_msg_test_new() {
	local tid="$1"
	local repository="$2"
	local branch="$3"
	local commit="$4"
	local result="$5"
	local logs=("${@:6}")

	local logs_json
	local json
	local msg

	if ! logs_json=$(json_array "${logs[@]}"); then
		return 1
	fi

	if ! json=$(json_object "tid"        "$tid"        \
				"repository" "$repository" \
				"branch"     "$branch"     \
				"commit"     "$commit"     \
				"result"     "$result"     \
				"logs"       "$logs_json"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_test_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_test_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(foundry_msg_get_data_field "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_test_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_test_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_test_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(foundry_msg_get_data_field "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}

foundry_msg_test_get_result() {
	local msg="$1"

	local result

	if ! result=$(foundry_msg_get_data_field "$msg" "result"); then
		return 1
	fi

	echo "$result"
	return 0
}

foundry_msg_test_get_logs() {
	local msg="$1"

	local logs

	if ! logs=$(foundry_msg_get_data_field "$msg" "logs[]"); then
		return 1
	fi

	echo "$logs"
	return 0
}
