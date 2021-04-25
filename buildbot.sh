#!/bin/bash

build_packages() {
	local sourcetree="$1"
	local gpgkey="$2"

	local output
	local package
	local npkgs

	npkgs=0

	if ! output=$(cd "$sourcetree" && dpkg-buildpackage "-k$gpgkey"); then
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

	while inst_running; do
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

	return 0
}

main() {
	local gpgkey
	local iqueue
	local oqueue

	opt_add_arg "k" "gpgkey" "rv" "" "The GPG key id to use"
	opt_add_arg "i" "input"  "rv" "" "The queue from where build tasks will be taken"
	opt_add_arg "o" "output" "rv" "" "The queue where build artifacts will be placed"

	if ! opt_parse "$@"; then
		return 1
	fi

	gpgkey=$(opt_get "gpgkey")
	iqueue=$(opt_get "input")
	oqueue=$(opt_get "output")

	inst_start dispatch_tasks "$gpgkey" "$iqueue" "$oqueue"

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
