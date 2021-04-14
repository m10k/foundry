#!/bin/bash

sem="buildbot"

build_packages() {
	local sourcetree="$1"
	local gpgkey="$2"

	local output
	local package
	local npkgs

	npkgs=0

	if ! output=(cd "$sourcetree" && dpkg-buildpackage --sign-key="$gpgkey"); then
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

queue_put_package() {
	local queue="$1"

	local lock
	local sem

	lock="$queue/lock"
	sem="$queue/sem"

	if ! mutex_lock "$lock"; then
		log_error "Could not acquire lock on $queue"
		return 1
	fi

	log_info "Moving $package to $queue"
	if ! mv "$package" "$queue/queue"; then
		log_error "Could not move $package"
	else
		if ! sem_post "$sem"; then
			log_error "Could not post semaphore $sem"
		fi
	fi

	mutex_unlock "$lock"

	return 0
}

move_packages() {
	local queue="$1"

	local lock
	local sem

	lock="$resultdir/lock"
	sem="$resultdir/queued"

	while read -r package; do
		queue_put_package "$queue" "$package"
	done

	return 0
}

build_repository() {
	local repository="$1"
	local gpgkey="$2"
	local resultdir="$3"

	local buildroot
	local packages
	local err

	err=1

	if ! buildroot=$(mktemp -d); then
		log_error "Could not create buildroot"
		return 1
	fi

	if ! git clone "$repository" "$buildroot/source" &>/dev/null; then
		log_error "Could not checkout source"
	elif ! packages=$(build_packages "$buildroot/source" "$gpgkey"); then
		log_error "Could not build package"
	elif ! move_packages "$resultdir" <<< "$packages"; then
		log_error "Could not move packages"
	else
		log_info "Build succeeded: $repository"
		err=0
	fi

	if ! rm -rf "$buildroot"; then
		log_error "Could not clean up $buildroot"
	fi

	return "$err"
}


main() {
	opt_add_arg "k" "gpgkey"     "yes" "" "The GPG key id to use"
	opt_add_arg "q" "queue"      "yes" "" "The queue where new packages should be placed"
	opt_add_arg "r" "repository" "yes" "" "The repository to watch"

	if ! opt_parse "$@"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "conf" "sem"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
