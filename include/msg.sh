#!/bin/bash

__init() {
	local submodules
	local deps

	submodules=("foundry/msg/artifact"
		    "foundry/msg/buildrequest"
		    "foundry/msg/build"
		    "foundry/msg/commit"
		    "foundry/msg/distrequest"
		    "foundry/msg/dist"
		    "foundry/msg/mergerequest"
		    "foundry/msg/merge"
		    "foundry/msg/signrequest"
		    "foundry/msg/sign"
		    "foundry/msg/testrequest"
		    "foundry/msg/test")

	deps=("ipc"
	      "json")

	if ! include "${submodules[@]}" "${deps[@]}"; then
		return 1
	fi

	declare -gxir __foundry_msg_version=1

	declare -gxir __foundry_msg_type_build=1
	declare -gxir __foundry_msg_type_buildrequest=2
	declare -gxir __foundry_msg_type_commit=3
	declare -gxir __foundry_msg_type_dist=4
	declare -gxir __foundry_msg_type_distrequest=5
	declare -gxir __foundry_msg_type_merge=6
	declare -gxir __foundry_msg_type_mergerequest=7
	declare -gxir __foundry_msg_type_sign=8
	declare -gxir __foundry_msg_type_signrequest=9
	declare -gxir __foundry_msg_type_test=10
	declare -gxir __foundry_msg_type_testrequest=11

	declare -gxA __foundry_msg_typemap

	__foundry_msg_typemap["build"]="$__foundry_msg_type_build"
	__foundry_msg_typemap["buildrequest"]="$__foundry_msg_type_buildrequest"
	__foundry_msg_typemap["commit"]="$__foundry_msg_type_commit"
	__foundry_msg_typemap["dist"]="$__foundry_msg_type_dist"
	__foundry_msg_typemap["distrequest"]="$__foundry_msg_type_distrequest"
	__foundry_msg_typemap["merge"]="$__foundry_msg_type_merge"
	__foundry_msg_typemap["mergerequest"]="$__foundry_msg_type_mergerequest"
	__foundry_msg_typemap["sign"]="$__foundry_msg_type_sign"
	__foundry_msg_typemap["signrequest"]="$__foundry_msg_type_signrequest"
	__foundry_msg_typemap["test"]="$__foundry_msg_type_test"
	__foundry_msg_typemap["testrequest"]="$__foundry_msg_type_testrequest"

	return 0
}

foundry_msg_get_version() {
	local msg="$1"

	local version

	if ! version=$(json_object_get "$msg" "version"); then
		return 1
	fi

	echo "$version"
	return 0
}

foundry_msg_get_type() {
	local msg="$1"

	local type

	if ! type=$(json_object_get "$msg" "type"); then
		return 1
	fi

	echo "$type"
	return 0
}

foundry_msg_get_data() {
	local msg="$1"

	local data

	if ! data=$(json_object_get "$msg" "data"); then
		return 1
	fi

	echo "$data"
	return 0
}

foundry_msg_get_data_field() {
	local msg="$1"
	local field="$2"

	local value

	if ! value=$(json_object_get "$msg" "data.$field"); then
		return 1
	fi

	echo "$value"
	return 0
}

_foundry_msg_version_supported() {
	local basemsg="$1"

	local version

	if ! version=$(foundry_msg_get_version "$basemsg"); then
		return 1
	fi

	if (( version != __foundry_msg_version )); then
		return 1
	fi

	return 0
}

foundry_msg_from_ipc_msg() {
	local ipc_msg="$1"

	local basemsg
	local type
	local typeno
	local data

	if ! basemsg=$(ipc_msg_get_data "$ipc_msg"); then
		return 255
	fi

	if ! _foundry_msg_version_supported "$basemsg"; then
		return 255
	fi

	if ! type=$(foundry_msg_get_type "$basemsg") ||
	   ! data=$(foundry_msg_get_data "$basemsg"); then
		return 255
	fi

	if ! array_contains "$type" "${!__foundry_msg_typemap[@]}"; then
		return 255
	fi

	typeno="${__foundry_msg_typemap[$type]}"

	echo "$data"
	return "$typeno"
}

foundry_msg_new() {
	local type="$1"
	local data="$2"

	local msg

	if ! msg=$(json_object "version" "i:$__foundry_msg_version" \
			       "type" "s:$type"                     \
			       "data" "o:$data"); then
		return 1
	fi

	echo "$msg"
	return 0
}
