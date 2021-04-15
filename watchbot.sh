#!/bin/bash

watch_repos() {
	local queue="$1"
	local watches=("${@:2}")

	local nwatches
	local heads
	local i

	heads=()
	nwatches="${#watches[@]}"

	for (( i = 0; i < nwatches; i++ )); do
		heads["$i"]=$(<"${watches[$i]}")
	done

	while inst_running; do
		log_debug "Watching $nwatches files: ${watches[*]}"
		if ! inotifywait -qq -t 15 "${watches[@]}"; then
			continue
		fi

		for (( i = 0; i < nwatches; i++ )); do
			local cur_head

			if ! cur_head=$(<"${watches[$i]}"); then
				log_error "Could not read ${watches[$i]}"
				continue
			fi

			log_debug "${watches[$i]}: ${heads[$i]} -> $cur_head"

			if [[ "$cur_head" != "${heads[$i]}" ]]; then
				if ! queue_put "$queue" "${watches[$i]}"; then
					log_error "Could not place item in queue"
					continue
				fi

				heads["$i"]="$cur_head"
			fi
		done
	done

	return 0
}

watchlist_add() {
	local opt="$1"
	local repo="$2"

	log_debug "$opt: $repo"
	watchlist+=("$repo")

	return 0
}

watch_to_head() {
	local watch="$1"

	local repo
	local branch
	local head

	if [[ "$watch" == *"#"* ]]; then
		repo="${watch%#*}"
		branch="${watch##*#}"
	else
		repo="$watch"
		branch="master"
	fi

	if [ -d "$repo/.git" ]; then
		head="$repo/.git/refs/heads/$branch"
	else
		head="$repo/refs/heads/$branch"
	fi

	if ! [ -e "$head" ]; then
		return 1
	fi

	log_debug "Resolved $watch to $head"

	echo "$head"
	return 0
}

main() {
	declare -ag watchlist # will be gone once forked to the background
	local watches
	local queue
	local watch

	opt_add_arg "r" "repo"    "yes" "" "Repository to watch (format: /repo/path[#branch])" watchlist_add
	opt_add_arg "q" "queue"   "yes" "" "Queue used to distribute work"

	if ! opt_parse "$@"; then
		return 1
	fi

	queue=$(opt_get "queue")

	if [ -z "$queue" ]; then
		log_error "Need a queue"
		return 1
	fi

	watches=()

	for watch in "${watchlist[@]}"; do
		local head

		if ! head=$(watch_to_head "$watch"); then
			log_error "Cannot resolve $watch"
			return 1
		fi

		watches+=("$head")
	done

	if (( ${#watches[@]} == 0 )); then
		log_error "Nothing to watch"
		return 1
	fi

	inst_start watch_repos "$queue" "${watches[@]}"

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "queue" "inst"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
