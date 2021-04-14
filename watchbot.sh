#!/bin/bash

sem="watchbot"

watch_repos() {
	local queue="$1"
	local watches=("${@:2}")

	local nwatches
	local heads
	local i

	heads=()
	nwatches="${#watches[@]}"

	if ! sem_init "$sem" 0; then
		log_info "Another instance is already running"
		return 1
	fi

	for (( i = 0; i < nwatches; i++ )); do
		heads["$i"]=$(<"${watches[$i]}")
	done

	while ! sem_trywait "$sem"; do
		log_debug "Watching $nwatches files: ${watches[@]}"
		if ! inotifywait -qq -t 15 "${watches[@]}"; then
			continue
		fi

		for (( i = 0; i < nwatches; i++ )); do
			local cur_head

			cur_head=$(<"${watches[$i]}")

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

	if ! sem_destroy "$sem"; then
		log_error "Could not clean up semaphore $sem"
	fi

	return 0
}

stop() {
	if ! sem_post "$sem"; then
		log_info "Looks like no instances are running"
		return 1
	fi

	return 0
}

watchlist_add() {
	local opt="$1"
	local repo="$2"

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

verbosity_increase() {
	local verbosity

	verbosity=$(log_get_verbosity)
	((verbosity++))
	log_set_verbosity "$verbosity"
	return 0
}

verbosity_decrease() {
	local verbosity

	verbosity=$(log_get_verbosity)
	((verbosity--))
	log_set_verbosity "$verbosity"
	return 0
}

main() {
	declare -ag watchlist # will be gone once forked to the background
	local watches
	local queue
	local watch

	opt_add_arg "r" "repo"    "yes" "" "Repository to watch (format: /repo/path[#branch])" watchlist_add
	opt_add_arg "q" "queue"   "yes" "" "Queue used to distribute work"
	opt_add_arg "s" "stop"    "no"  0  "Stop a running instance"
	opt_add_arg "v" "verbose" "no"  0  "Be more verbose"                                   verbosity_increase
	opt_add_arg "w" "shush"   "no"  0  "Be less verbose"                                   verbosity_decrease

	if ! opt_parse "$@"; then
		return 1
	fi

	if (( $(opt_get "stop") > 0 )); then
		if ! stop; then
			return 1
		fi

		return 0
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

	start "$queue" "${watches[@]}" </dev/null &>/dev/null &
	disown

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "sem" "queue"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
