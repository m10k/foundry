#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_mergerequest_msgtype="mergerequest"

	return 0
}

foundry_msg_mergerequest_new() {
	local context="$1"
	local repository="$2"
	local srcbranch="$3"
	local dstbranch="$4"

	local json
	local msg

	if ! json=$(json_object "context"            "$context"    \
				"repository"         "$repository" \
				"source_branch"      "$srcbranch"  \
				"destination_branch" "$dstbranch"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_mergerequest_msgtype" \
				   "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_mergerequest_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_mergerequest_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_mergerequest_get_source_branch() {
	local msg="$1"

	local srcbranch

	if ! srcbranch=$(foundry_msg_get_data_field "$msg" "source_branch"); then
		return 1
	fi

	echo "$srcbranch"
	return 0
}

foundry_msg_mergerequest_get_destination_branch() {
	local msg="$1"

	local dstbranch

	if ! dstbranch=$(foundry_msg_get_data_field "$msg" "destination_branch"); then
		return 1
	fi

	echo "$dstbranch"
	return 0
}
