#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_mergerequest_new() {
	local tid="$1"
	local repository="$2"
	local srcbranch="$3"
	local dstbranch="$4"

	local json

	if ! json=$(json_object "tid" "$tid"                     \
				"repository" "$repository"       \
				"source_branch" "$srcbranch"     \
				"destination_branch" "$dstbranch"); then
		return 1
	fi

	echo "$json"
	return 0
}

foundry_msg_mergerequest_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(json_object_get "$msg" "tid"); then
		return 1
	fi

	return 0
}

foundry_msg_mergerequest_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(json_object_get "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_mergerequest_get_source_branch() {
	local msg="$1"

	local srcbranch

	if ! srcbranch=$(json_object_get "$msg" "source_branch"); then
		return 1
	fi

	echo "$srcbranch"
	return 0
}

foundry_msg_mergerequest_get_destination_branch() {
	local msg="$1"

	local dstbranch

	if ! dstbranch=$(json_object_get "$msg" "destination_branch"); then
		return 1
	fi

	echo "$dstbranch"
	return 0
}
