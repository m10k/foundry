#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_merge_msgtype="merge"

	return 0
}

foundry_msg_merge_new() {
	local context="$1"
	local repository="$2"
	local srcbranch="$3"
	local dstbranch="$4"
	local status="$5"
	local log="$6"

	local json
	local msg

	if ! json=$(json_object "context"    "$context"    \
				"repository" "$repository" \
				"srcbranch"  "$srcbranch"  \
				"dstbranch"  "$dstbranch"  \
				"status"     "$status"     \
				"log"        "$log"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_merge_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_merge_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_merge_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_merge_get_source_branch() {
	local msg="$1"

	local srcbranch

	if ! srcbranch=$(foundry_msg_get_data_field "$msg" "srcbranch"); then
		return 1
	fi

	echo "$srcbranch"
	return 0
}

foundry_msg_merge_get_destination_branch() {
	local msg="$1"

	local dstbranch

	if ! dstbranch=$(foundry_msg_get_data_field "$msg" "dstbranch"); then
		return 1
	fi

	echo "$dstbranch"
	return 0
}

foundry_msg_merge_get_status() {
	local msg="$1"

	local status

	if ! status=$(foundry_msg_get_data_field "$msg" "status"); then
		return 1
	fi

	echo "$status"
	return 0
}

foundry_msg_merge_get_log() {
	local msg="$1"

	local log

	if ! log=$(foundry_msg_get_data_field "$msg" "log"); then
		return 1
	fi

	echo "$log"
	return 0
}
