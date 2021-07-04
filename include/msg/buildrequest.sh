#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_buildrequest_new() {
	local tid="$1"
	local repository="$2"
	local branch="$3"
	local commit="$4"

	local json

	if ! json=$(json_object "tid" "$tid"               \
				"repository" "$repository" \
				"branch"     "$branch"     \
				"commit"     "$commit"); then
		return 1
	fi

	echo "$json"
	return 0
}

foundry_msg_buildrequest_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(json_object_get "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_buildrequest_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(json_object_get "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_buildrequest_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(json_object_get "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_buildrequest_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(json_object_get "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}
