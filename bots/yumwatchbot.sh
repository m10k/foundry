#!/bin/bash

# yumwatchbot - Foundry bot for monitoring YUM repositories
# Copyright (C) 2023 Matthias Kruk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

make_source_new_message() {
	local package="$1"
	local checksum_data="$2"

	local sourceref_props
	local sourceref
	local checksum
	local message

	if ! checksum=$(foundry_checksum_new "algorithm" "sha256"        \
	                                     "data"      "$checksum_data"); then
		log_warn "Could not make checksum object with checksum \"$checksum_data\""
		return 1
	fi

	sourceref_props=(
		"uri"      "$package"
		"checksum" "$checksum"
	)

	if ! sourceref=$(foundry_sourceref_new "srpm" "${sourceref_props[@]}"); then
		return 2
	fi

	foundry_msgv2_new "foundry.msg.source.new" "$sourceref"
	return "$?"
}

make_source_modified_message() {
	local package="$1"
	local old_checksum="$2"
	local new_checksum="$3"

	local old_checksum_obj
	local new_checksum_obj
	local old_sourceref_props
	local new_sourceref_props
	local old_sourceref
	local new_sourceref

	if ! old_checksum_obj=$(foundry_checksum_new "algorithm" "sha256"  \
	                                             "data"      "$old_checksum") ||
	   ! new_checksum_obj=$(foundry_checksum_new "algorithm" "sha256"  \
	                                             "data"      "$new_checksum"); then
		return 1
	fi

	old_sourceref_props=(
		"uri"      "$package"
		"checksum" "$old_checksum_obj"
	)
	new_sourceref_props=(
		"uri"      "$package"
		"checksum" "$new_checksum_obj"
	)

	if ! old_sourceref=$(foundry_sourceref_new "srpm" "${old_sourceref_props[@]}") ||
	   ! new_sourceref=$(foundry_sourceref_new "srpm" "${new_sourceref_props[@]}"); then
		return 2
	fi

	foundry_msgv2_new "foundry.msg.source.modified" "$new_sourceref" "$old_sourceref"
	return "$?"
}

notify_new_package() {
	local endpoint="$1"
	local topic="$2"
	local package="$3"
	local checksum="$4"

	local message

	if ! message=$(make_source_new_message "$package" "$checksum"); then
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$message"; then
		log_error "Could not send message on $endpoint to $topic"
		return 1
	fi

	return 0
}

notify_changed_package() {
	local endpoint="$1"
	local topic="$2"
	local package="$3"
	local old_checksum="$4"
	local new_checksum="$5"

	local message

	if ! message=$(make_source_modified_message "$package"      \
	                                            "$old_checksum" \
	                                            "$new_checksum"); then
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$message"; then
		log_error "Could not send message on $endpoint to $topic"
		return 1
	fi

	return 0
}

yumrepo_open() {
	local repository="$1"

	local repomd_url
	local repomd

	repomd_url="$repository/repodata/repomd.xml"

	if ! repomd=$(curl --get --silent --location "$repomd_url"); then
		return 1
	fi

	printf '%s|%s\n' "$repository" "$repomd" | tr -d '\n'
	return 0
}

yumrepo_get_md_checksum() {
	local yumrepo="$1"
	local mdtype="$2"

	local data
	local re

	re='<checksum type="sha256">[\s]*([0-9a-f]+)'
	data=$(sed -e 's/<data/\n<data/g' <<< "$yumrepo" | grep -e "^<data type=\"$mdtype\">")

	if [[ "$data" =~ $re ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi

	return 1
}

yumrepo_get_md_location() {
	local yumrepo="$1"
	local mdtype="$2"

	local data
	local re

	re='<location href="([^"]+)'
	data=$(sed -e 's/<data/\n<data/g' <<< "$yumrepo" | grep -e "^<data type=\"$mdtype\">")

	if [[ "$data" =~ $re ]]; then
		echo "${yumrepo%%|*}/${BASH_REMATCH[1]}"
		return 0
	fi

	return 1
}

yumrepo_get_md() {
	local yumrepo="$1"
	local mdtype="$2"

	local mdlocation
	local -A decompressors
	local decompressor
	local compression

	decompressors["xml"]="cat"
	decompressors["gz"]="zcat"
	decompressors["xz"]="xzcat"
	decompressors["bzip2"]="bzcat"

	if ! mdlocation=$(yumrepo_get_md_location "$yumrepo" "$mdtype"); then
		return 1
	fi

	compression="${mdlocation##*.}"
	decompressor="${decompressors[$compression]}"

	if [[ -z "$decompressor" ]]; then
		log_error "Unknown metadata compressor: $decompressor"
		return 1
	fi

	if ! curl --get --silent --location "$mdlocation" | "$decompressor"; then
		return 1
	fi

	return 0
}

yumrepo_get_contents() {
	local yumrepo="$1"

	local re_checksum
	local re_location
	local baseurl
	local package

	re_checksum='<checksum[^>]*type="sha256"[^>]*>([0-9a-f]+)'
	re_location='<location href="([^"]+)'
	baseurl="${yumrepo%%|*}"

	while read -r package; do
		local checksum
		local location

		if ! [[ "$package" =~ $re_checksum ]]; then
			continue
		fi

		checksum="${BASH_REMATCH[1]}"

		if ! [[ "$package" =~ $re_location ]]; then
			continue
		fi

		location="${BASH_REMATCH[1]}"

		printf '%s %s\n' "$checksum" "$baseurl/$location"
	done < <(yumrepo_get_md "$yumrepo" "primary" | tr -d '\n' | sed -e 's/<package /\n<package /g' | grep -e '^<package ')

	return 0
}

load_state() {
	local -n state_table="$1"

	local re
	local statefile
	local line

	re='^([^ ]+)\s*=\s*([a-fA-F0-9]+)'
	statefile=$(opt_get "statefile")

	while read -r line; do
		if [[ "$line" =~ $re ]]; then
			local key
			local value

			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"

			state_table["$key"]="$value"
		fi
	done < "$statefile"
}

save_state() {
	local -n state_table="$1"

	local statefile
	local statefile_new
	local key

	statefile=$(opt_get "statefile")
	statefile_new="$statefile.$EPOCHSECONDS"

	if ! :> "$statefile_new"; then
		log_error "Cannot write to $statefile_new"
		return 1
	fi

	for key in "${!state_table[@]}"; do
		if ! printf '%s = %s\n' "$key" "${state_table[$key]}" >> "$statefile_new"; then
			log_error "Could not save state to $statefile_new"
			return 1
		fi
	done

	if ! mv "$statefile_new" "$statefile"; then
		log_error "Could not replace $statefile with $statefile_new"
		return 1
	fi

	return 0
}

check_repository_for_new_packages() {
	local repository="$1"
	local state_ref="$2"
	local endpoint="$3"

	local -n state
	local yumrepo
	local yumrepo_checksum
	local checksum
	local package
	local topic

	state="$state_ref"
	topic=$(opt_get "output-topic")

	if ! yumrepo=$(yumrepo_open "$repository") ||
	   ! yumrepo_checksum=$(yumrepo_get_md_checksum "$yumrepo" "primary"); then
		log_error "Could not get metadata for $repository"
		return 1
	fi

	if [[ "${state[$repository]}" == "$yumrepo_checksum" ]]; then
		log_info "No changes in $repository"
		return 0
	fi

	while read -r checksum package; do
		local prev_checksum

		prev_checksum="${state[$package]}"

		log_info "$package [$prev_checksum] -> $checksum"

		if [[ -z "$prev_checksum" ]]; then
			notify_new_package "$endpoint" "$topic" "$package" "$checksum"
		elif [[ "$prev_checksum" != "$checksum" ]]; then
			notify_changed_package "$endpoint" "$topic" "$package" "$prev_checksum" "$checksum"
		else
			continue
		fi

		state["$package"]="$checksum"
	done < <(yumrepo_get_contents "$yumrepo")

	state["$repository"]="$yumrepo_checksum"

	save_state "$state_ref"

	return 0
}

watch_repositories() {
	local repositories=("$@")

	local endpoint
	local -i interval
	local -A repository_state

	interval=$(opt_get "interval")

	if ! endpoint=$(ipc_endpoint_open); then
		return 1
	fi

	load_state repository_state

	while inst_running; do
		local repository

		for repository in "${repositories[@]}"; do
			check_repository_for_new_packages "$repository"    \
			                                  repository_state \
		                                          "$endpoint"
		done

		sleep "$interval"
	done

	return 0
}

main() {
	local argv=("$@")

	local -a watched_repositories
	local protocol

	opt_add_arg "r" "repository"   "arv" watched_repositories    \
		    "Repository to be watched for new packages"
	opt_add_arg "i" "interval"     "v"   30                      \
	            "Time between repository updates"
	opt_add_arg "O" "output-topic" "v"   "foundry.srpm.detected" \
	            "The topic to announce detected packages to"
	opt_add_arg "p" "protocol"     "v"   "uipc"                  \
	            "The IPC flavor to use"
	opt_add_arg "S" "statefile"    "v"   "$HOME/.yumwatchbot"    \
		    "Path to store state information at"

	if ! opt_parse "${argv[@]}"; then
		return 1
	fi

	protocol=$(opt_get "protocol")

	if ! include "$protocol"; then
		return 1
	fi

	inst_start watch_repositories "${watched_repositories[@]}"

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "inst"  \
	             "foundry/checksum"  \
	             "foundry/sourceref" \
	             "foundry/msgv2"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
