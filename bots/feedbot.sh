#!/bin/bash

# feedbot.sh - Foundry Atom feed bot
# Copyright (C) 2026 Matthias Kruk
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

update_feed() {
	local feed="$1"
	local output="$2"

	local feed_xml

	log_info "Generating XML for feed $feed"
	if ! feed_xml=$(atom_feed_to_xml "$feed"); then
		log_error "Could not get XML for feed $feed"
		return 1
	fi

	log_info "Writing XML to $output"
	if ! printf '%s\n' "$feed_xml" > "$output"; then
		log_error "Could not write to $output"
		return 1
	fi

	return 0
}

handle_commit() {
	local msg="$1"
	local feed="$2"
	local output="$3"

	local repository
	local branch
	local ref
	local summary
	local title
	local entry

	if ! repository=$(foundry_msg_commit_get_repository "$msg"); then
		log_warn "Ignoring commit message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_commit_get_branch "$msg"); then
		log_warn "Ignoring commit message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_commit_get_ref "$msg"); then
		log_warn "Ignoring commit message without ref"
		return 1
	fi

	summary="
# Commit detected

Repository: $repository
Branch:     $branch
Ref:        $ref
"
	title="New commit on $repository#$branch: $ref"

	entry=$(atom_feed_add_entry "$feed")

	atom_entry_add_category "$entry" "event"
	atom_entry_add_category "$entry" "commit"

	atom_entry_add_link "$entry" "related" "$repository#$ref" "source repository"
	atom_entry_set_title "$entry" "$title"
	atom_entry_set_summary "$entry" "$summary"
	atom_entry_set_content "$entry" "$summary"

	atom_entry_set_date "$entry" "published"
	atom_entry_set_date "$entry" "updated"

	update_feed "$feed" "$output"
}

handle_build() {
	local msg="$1"
	local feed="$2"
	local output="$3"

	local repository
	local name
	local context
	local branch
	local ref
	local artifact
	local -i result
	local status

	local title
	local summary
	local entry

	if ! repository=$(foundry_msg_build_get_repository "$msg"); then
		log_warn "Ignoring build message without repository"
		return 1
	fi

	if ! context=$(foundry_msg_build_get_context "$msg"); then
		log_warn "Ignoring build message without context"
		return 1
	fi

	if ! branch=$(foundry_msg_build_get_branch "$msg"); then
		log_warn "Ignoring build message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_build_get_ref "$msg"); then
		log_warn "Ignoring build message without ref"
		return 1
	fi

	if ! result=$(foundry_msg_build_get_result "$msg"); then
		log_warn "Ignoring build message without result"
		return 1
	fi

	entry=$(atom_feed_add_entry "$feed")
	name="${repository##*/}"

	if (( result == 0 )); then
		status="succeeded"
	else
		status="failed"
	fi

	title="Build $status: $name [#$ref]"
	summary="# Build $status: $repository#$branch

 Context:    $context
 Repository: $repository
 Branch:     $branch
 Ref:        $ref
 Status:     $result

 Artifacts:
"

	while read -r artifact; do
		local uri
		local checksum

		uri=$(foundry_msg_artifact_get_uri "$artifact")
		checksum=$(foundry_msg_artifact_get_checksum "$artifact")

		summary+=$(printf ' - %s [%s]\n' "$uri" "$checksum")
	done < <(foundry_msg_build_get_artifacts "$msg")

	atom_entry_add_category "$entry" "event"
	atom_entry_add_category "$entry" "build"

	atom_entry_add_link "$entry" "related" "$repository#$ref" "source repository"
	atom_entry_set_title "$entry" "$title"
	atom_entry_set_summary "$entry" "$summary"
	atom_entry_set_content "$entry" "$summary"

	atom_entry_set_date "$entry" "published"
	atom_entry_set_date "$entry" "updated"

	update_feed "$feed" "$output"
}

handle_sign() {
	local msg="$1"
	local feed="$2"
	local output="$3"

	local context
	local key
	local repository
	local branch
	local ref
	local artifact
	local entry
	local name
	local title
	local summary

	if ! context=$(foundry_msg_sign_get_context "$msg"); then
		log_warn "Ignoring sign message without context"
		return 1
	fi

	if ! key=$(foundry_msg_sign_get_key "$msg"); then
		log_warn "Ignoring sign message without key"
		return 1
	fi

	if ! repository=$(foundry_msg_sign_get_repository "$msg"); then
		log_warn "Ignoring sign message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_sign_get_branch "$msg"); then
		log_warn "Ignoring sign message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_sign_get_ref "$msg"); then
		log_warn "Ignoring sign message without ref"
	        return 1
	fi

	if (( result == 0 )); then
		status="succeeded"
	else
		status="failed"
	fi

	name="${repository##*/}"
	title="Signed package: $name [#$ref]"
	summary="# Signed package: $name [#$ref]

 Context:    $context
 Repository: $repository
 Branch:     $branch
 Ref:        $ref
 Key:        $key

 Artifacts:
"

	while read -r artifact; do
		local uri
		local checksum

		if ! uri=$(foundry_msg_artifact_get_uri "$artifact"); then
			uri="(invalid uri)"
		fi

		if ! checksum=$(foundry_msg_artifact_get_checksum "$artifact"); then
			checksum="(invalid checksum)"
		fi

		summary+=$(printf ' - %s [%s]\n' "$uri" "$checksum")
	done < <(foundry_msg_sign_get_artifacts "$msg")

	entry=$(atom_feed_add_entry "$feed")

	atom_entry_add_category "$entry" "event"
	atom_entry_add_category "$entry" "sign"

	atom_entry_add_link "$entry" "related" "$repository#$ref" "source repository"
	atom_entry_set_title "$entry" "$title"
	atom_entry_set_summary "$entry" "$summary"
	atom_entry_set_content "$entry" "$summary"

	atom_entry_set_date "$entry" "published"
	atom_entry_set_date "$entry" "updated"

	update_feed "$feed" "$output"
}

handle_dist() {
	local msg="$1"
	local feed="$2"
	local output="$3"

	local repository
	local branch
	local ref
	local distribution
	local artifact

	local name
	local title
	local summary
	local entry

	if ! repository=$(foundry_msg_dist_get_repository "$msg"); then
		log_warn "Ignoring dist message without distribution"
		return 1
	fi

	if ! branch=$(foundry_msg_dist_get_branch "$msg"); then
		log_warn "Ignoring dist message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_dist_get_ref "$msg"); then
		log_warn "Ignoring dist message without ref"
		return 1
	fi

	if ! distribution=$(foundry_msg_dist_get_distribution "$msg"); then
		log_warn "Ignoring dist message without distribution"
		return 1
	fi

	name="${repository##*/}"
	title="Published package: $name [#$ref]"
	summary="# Published package: $name [#$ref]

 Repository:   $repository
 Branch:       $branch
 Ref:          $ref
 Distribution: $distribution

 Artifacts:
"

	while read -r artifact; do
		local uri
		local checksum

		if ! uri=$(foundry_msg_artifact_get_uri "$artifact"); then
			uri="(invalid uri)"
		fi

		if ! checksum=$(foundry_msg_artifact_get_checksum "$artifact"); then
			checksum="(invalid checksum)"
		fi

		summary+=$(printf ' - %s [%s]\n' "$uri" "$checksum")
	done < <(foundry_msg_dist_get_artifacts "$msg")

	entry=$(atom_feed_add_entry "$feed")

	atom_entry_add_category "$entry" "event"
	atom_entry_add_category "$entry" "dist"

	atom_entry_add_link "$entry" "related" "$repository#$ref" "source repository"
	atom_entry_set_title "$entry" "$title"
	atom_entry_set_summary "$entry" "$summary"
	atom_entry_set_content "$entry" "$summary"

	atom_entry_set_date "$entry" "published"
	atom_entry_set_date "$entry" "updated"

	update_feed "$feed" "$output"
}

handle_message() {
	local msg="$1"
	local output="$2"
	local feed="$3"

	local data
	local type
	local -i err
	local -A handlers

	handlers["commit"]=handle_commit
	handlers["build"]=handle_build
	handlers["sign"]=handle_sign
	handlers["dist"]=handle_dist

	err=1

	if ! data=$(ipc_msg_get_data "$msg"); then
		log_warn "Ignoring message without data"
		return 1
	fi

	if type=$(foundry_msg_get_type "$data"); then
		if array_contains "$type" "${!handlers[@]}"; then
			log_info "Received a $type message"
			if "${handlers["$type"]}" "$data" "$feed" "$output"; then
				err=0
			fi
		else
			log_info "Unhandled $type message"
		fi
	else
		log_info "Could not determine message type of message"
	fi

	return "$err"
}

main() {
	local output
	local owner_name
	local author_name
	local author_email
	local feed_name
	local feed
	local -a topics
	local topic

	topics=(
		"commits"
		"builds"
		"signs"
		"dists"
	)

	opt_add_arg "N" "owner-name"   "rv" ""         "Name of the feed owner"
	opt_add_arg "n" "author-name"  "rv" ""        "Name of the feed author"
	opt_add_arg "e" "author-email" "rv" ""        "Email address of the feed author"
	opt_add_arg "f" "feed"         "v"  "foundry" "Name of the feed"
	opt_add_arg "o" "output"       "rv" ""        "The path to write the feed to"
	opt_add_arg "t" "topic"        "av" topics    "Topic to subscribe to"

	if ! opt_parse "$@"; then
		return 1
	fi

	output=$(opt_get "output")
	feed_name=$(opt_get "feed")
	author_name=$(opt_get "author-name")
	author_email=$(opt_get "author-email")
	owner_name=$(opt_get "owner-name")

	if ! feed=$(atom_feed_new "$feed_name"); then
		log_error "Could not open feed $feed_name"
		return 1
	fi

	atom_feed_set_title "$feed" "$feed_name feed"
	atom_feed_set_rights "$feed" "Copyright (C) $owner_name"
	atom_feed_set_date "$feed"
	atom_feed_add_author "$feed" "$author_name" "$author_email"

	for topic in "${topics[@]}"; do
		if ! foundry_bot_register_handler handle_message "$topic" "$output" "$feed"; then
			return 2
		fi
	done

	if ! foundry_bot_run; then
		return 3
	fi

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "uipc" "atom" "foundry/msg" "foundry/bot"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
