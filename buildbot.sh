#!/bin/bash

sem="buildbot"

build_packages() {
	local sourcetree="$1"
	local gpgkey="$2"

	local output
	local package
	local npkgs

	npkgs=0

	if ! output=$(cd "$sourcetree" && dpkg-buildpackage --sign-key="$gpgkey"); then
		log_error "Could not build $sourcetree"
		echo "$output" | log_highlight "dpkg-buildpackage" | log_error

		return 1
	fi

	while read -r package; do
		if ! output=$(dpkg-sig --sign builder -k "$gpgkey" "$package"); then
			log_error "Could not sign $package"
			echo "output" | log_highlight "dpkg-sig" | log_error
			return 1
		fi

		if ! realpath "$package"; then
			log_error "Could not normalize path $package"
			return 1
		fi

		((npkgs++))
	done < <(find "$sourcetree/.." -mindepth 1 -maxdepth 1 -type f -iname "*.deb")

	if (( npkgs == 0 )); then
		return 1
	fi

	return 0
}

build_repository() {
	local target="$1"
	local gpgkey="$2"
	local workdir="$3"

	local repository
	local branch
	local buildroot
	local packages
	local err

	err=1

	# $target points to refs/heads/<branch>, so we need to mangle it a bit
	repository="${target%/refs/heads*}" # repository might be bare
	repository="${repository%/.git}"    # or not bare
	branch="${target##*/}"

	log_info "Going to build $repository#$branch"

	buildroot="$workdir/buildroot"

	if ! mkdir -p "$buildroot"; then
		log_error "Could not create buildroot"
		return 1
	fi

	if ! git clone "$repository" -b "$branch" "$buildroot" &>/dev/null; then
		log_error "Could not clone $repository#$branch to $buildroot"
	elif ! packages=$(build_packages "$buildroot" "$gpgkey"); then
		log_error "Could not build package"
	else
		log_info "Build succeeded: $repository"
		echo "$packages"
		err=0
	fi

	return "$err"
}

dispatch_tasks() {
	local gpgkey="$1"
	local taskq="$2"
	local doneq="$3"

	if ! sem_init "$sem" 0; then
		log_error "Another instance is already running"
		return 1
	fi

	while ! sem_trywait "$sem"; do
		local workitem
		local workdir
		local package
		local result

		if ! workdir=$(mktemp -d); then
			log_error "Could not create workdir"
			return 1
		fi

		workitem=$(queue_get "$taskq")

		log_info "Starting build of $workitem"

		if ! result=$(build_repository "$workitem" "$gpgkey" "$workdir"); then
			log_error "Build of $workitem failed"
			continue
		fi

		while read -r package; do
			while ! queue_put_file "$doneq" "$package"; do
				log_error "Could not put $package in queue. Trying again in a bit."
				log_error "This usually means the disk with the queue is full, or permissions have been changed."
				sleep 60
			done
		done <<< "$result"

		if ! rm -rf "$workdir"; then
			log_error "Could not remove workdir $workdir"
		fi
	done

	if ! sem_destroy "$sem"; then
		log_error "Could not clean up semaphore $sem"
	fi

	return 0
}

stop() {
	if ! sem_post "$sem"; then
		log_error "Looks like no other instances are running"
		return 1
	fi

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
	local gpgkey
	local tqueue
	local dqueue

	opt_add_arg "k" "gpgkey"     "yes" "" "The GPG key id to use"
	opt_add_arg "t" "task-queue" "yes" "" "The queue to watch for tasks"
	opt_add_arg "d" "done-queue" "yes" "" "The queue to place build artifacts"
	opt_add_arg "v" "verbose"    "no" 0 "Be more verbose"                      verbosity_increase
	opt_add_arg "w" "shush"      "no" 0 "Be less verbose"                      verbosity_decrease
	opt_add_arg "s" "stop"       "no" 0 "Stop the running instance"

	if ! opt_parse "$@"; then
		return 1
	fi

	if (( $(opt_get "stop") > 0 )); then
		if ! stop; then
			return 1
		fi

		return 0
	fi

	gpgkey=$(opt_get "gpgkey")
	tqueue=$(opt_get "task-queue")
	dqueue=$(opt_get "done-queue")

	dispatch_tasks "$gpgkey" "$tqueue" "$dqueue" </dev/null &>/dev/null &
	disown

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "queue"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
