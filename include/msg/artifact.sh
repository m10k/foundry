#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_artifact_new() {
	local uri="$1"
	local checksum="$2"

	local artifact

	if ! artifact=$(json_object "uri"      "$uri" \
				    "checksum" "$checksum"); then
		return 1
	fi

	echo "$artifact"
	return 0
}

foundry_msg_artifact_get_uri() {
	local artifact="$1"

	local uri

	if ! uri=$(jq -e -r ".uri" <<< "$artifact"); then
		return 1
	fi

	echo "$uri"
	return 0
}

foundry_msg_artifact_get_checksum() {
	local artifact="$1"

	local checksum

	if ! checksum=$(jq -e -e ".checksum" <<< "$artifact"); then
		return 1
	fi

	echo "$checksum"
	return 0
}
