#!/bin/bash

# watchbot.sh - Foundry git repository monitor bot
# Copyright (C) 2021-2022 Matthias Kruk
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

_add_to_watchlist() {
	# local name="$1" # unused
	local value="$2"

	# assume master if user didn't specify a branch
	if [[ "$value" != *"#"* ]]; then
		value+="#master"
	fi

	# this is the `watchlist' array from main()
	watchlist+=("$value")
	return 0
}

watch_to_repository() {
	local watch="$1"

	if [[ "$watch" == *"#"* ]]; then
		echo "${watch%#*}"
	else
		echo "$watch"
	fi

	return 0
}

watch_to_branch() {
	local watch="$1"

	if [[ "$watch" == *"#"* ]]; then
		echo "${watch##*#}"
	else
		echo "master"
	fi

	return 0
}

fetch_head_smart_http() {
	local watch="$1"

	local repository
	local branch
	local url
	local re
	local data
	local ref

	repository=$(watch_to_repository "$watch")
	branch=$(watch_to_branch "$watch")

	re="00[0-9a-f]{2}\\K[0-9a-f]{40} refs/heads/$branch"
	url="$repository/info/refs?service=git-upload-pack"

	if ! data=$(curl --get --silent --location "$url" 2>/dev/null |
			    grep -oP "$re" --binary-files=text); then
		return 1
	fi

	ref="${data%% *}"
	echo "$ref"
	return 0
}

fetch_head_dumb_http() {
	local watch="$1"

	local repository
	local branch
	local info
	local line
	local re

	repository=$(watch_to_repository "$watch")
	branch=$(watch_to_branch "$watch")

	# I don't know what it is that git puts between the hash
	# and the "refs/heads" part, but it's not whitespaces
	re="^([0-9a-fA-F]+).*refs/heads/$branch"

	if ! info=$(curl --get --silent --location "$repository/info/refs" 2>/dev/null); then
		return 1
	fi

	if ! line=$(grep -m 1 "refs/heads/$branch$" <<< "$info"); then
		return 1
	fi

	if ! [[ "$line" =~ $re ]]; then
		return 1
	fi

	echo "${BASH_REMATCH[1]}"
	return 0
}

fetch_head_remote() {
	local watch="$1"

	local head

	if ! head=$(fetch_head_smart_http "$watch"); then
		if ! head=$(fetch_head_dumb_http "$watch"); then
			return 1
		fi
	fi

	echo "$head"
	return 0
}

fetch_head_local() {
	local watch="$1"

	local repository
	local branch
	local head

	repository=$(watch_to_repository "$watch")
	branch=$(watch_to_branch "$watch")

	if [ -d "$repository/.git" ]; then
		# "normal" repository
		if ! head=$(< "$repository/.git/refs/heads/$branch"); then
			return 1
		fi
	else
		# bare repository
		if ! head=$(< "$repository/refs/heads/$branch"); then
			return 1
		fi
	fi

	echo "$head"
	return 0
}

fetch_head() {
	local url="$1"

	local repository
	local branch

	local head
	local fetch

	case "$url" in
		"http://"*|"https://"*|"ftp://"*)
			fetch=fetch_head_remote
			;;

		*)
			fetch=fetch_head_local
			;;
	esac

	if ! head=$("$fetch" "$url"); then
		return 1
	fi

	echo "$head"
	return 0
}

fetch_heads() {
	declare -n dst="$1"
	local watchlist=("${@:2}")

	local watch
	local -i err

	err=0

	for watch in "${watchlist[@]}"; do
		if ! dst["$watch"]=$(fetch_head "$watch"); then
			log_debug "Could not fetch HEAD of $watch"
			err=1
		fi
	done

	return "$err"
}

send_notification() {
	local endpoint="$1"
	local topic="$2"
	local watch="$3"
	local ref="$4"

	local repository
	local branch
	local msg

	repository=$(watch_to_repository "$watch")
	branch=$(watch_to_branch "$watch")
	msg=$(foundry_msg_commit_new "$repository" "$branch" "$ref")

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$msg"; then
		return 1
	fi

	return 0
}

_watch() {
	local topic="$1"
	local interval="$2"
	local watchlist=("${@:3}")

	local endpoint
	declare -A old_heads
	declare -A new_heads

	if ! endpoint=$(ipc_endpoint_open); then
		return 1
	fi

	while inst_running; do
		local watch

		inst_set_status "Checking ${#watchlist[@]} repositories for updates"
		log_info "Checking ${#watchlist[@]} repositories for updates"

		fetch_heads new_heads "${watchlist[@]}"

		for watch in "${watchlist[@]}"; do
			local old_head
			local new_head

			old_head="${old_heads[$watch]}"
			new_head="${new_heads[$watch]}"

			if [[ -z "$new_head" ]]; then
				# Failed to fetch head for this watch
				continue
			fi

			if [[ "$old_head" != "$new_head" ]]; then
			        log_info "HEAD has changed on $watch"

				if send_notification "$endpoint" "$topic" \
						     "$watch" "$new_head"; then
					old_heads["$watch"]="$new_head"
				else
					log_warn "Could not publish to $topic"
				fi
			fi
		done

		inst_set_status "Sleeping for $interval seconds"
		sleep "$interval"
	done

	ipc_endpoint_close "$endpoint"

	return 0
}

main() {
	local watchlist
	local interval
	local publish_to

	opt_add_arg "r" "repository" "rv" ""          \
		    "Repository to watch for updates" \
		    "" _add_to_watchlist
	opt_add_arg "p" "publish-to" "v"  "commits"   \
		    "Topic to publish notifications"
	opt_add_arg "i" "interval"   "v"  30          \
		    "Update check interval" "^[0-9]+$"

	if ! opt_parse "$@"; then
		return 1
	fi

	publish_to=$(opt_get "publish-to")
	interval=$(opt_get "interval")

	inst_start _watch "$publish_to" "$interval" "${watchlist[@]}"

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "ipc" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
