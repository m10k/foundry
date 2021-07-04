#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_merge_new() {
	local tid="$1"
	local repository="$2"
	local srcbranch="$3"
	local dstbranch="$4"
	local status="$5"
	local log="$6"

	local json

	if ! json=$(json_object "tid"        "$tid"        \
				"repository" "$repository" \
				"srcbranch"  "$srcbranch"  \
				"dstbranch"  "$dstbranch"  \
				"status"     "$status"     \
				"log"        "$log"); then
		return 1
	fi

	echo "$json"
	return 0
}

foundry_msg_merge_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(json_object_get "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_merge_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(json_object_get "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_merge_get_source_branch() {
	local msg="$1"

	local srcbranch

	if ! srcbranch=$(json_object_get "$msg" "source_branch"); then
		return 1
	fi

	echo "$srcbranch"
	return 0
}

foundry_msg_merge_get_destination_branch() {
	local msg="$1"

	local dstbranch

	if ! dstbranch=$(json_object_get "$msg" "destination_branch"); then
		return 1
	fi

	echo "$dstbranch"
	return 0
}

foundry_msg_merge_get_status() {
	local msg="$1"

	local status

	if ! status=$(json_object_get "$msg" "status"); then
		return 1
	fi

	echo "$status"
	return 0
}

foundry_msg_merge_get_log() {
	local msg="$1"

	local log

	if ! log=$(json_object_get "$msg" "log"); then
		return 1
	fi

	echo "$log"
	return 0
}
