#!/bin/bash

build_packages() {
	local buildid="$1"
	local sourcetree="$2"
	local gpgkey="$3"

	local output
	local package
	local npkgs

	npkgs=0

	if ! output=$(cd "$sourcetree" 2>&1 && dpkg-buildpackage "-k$gpgkey" 2>&1); then
		log_error "[#$buildid] Could not build $sourcetree"
		echo "$output" | log_highlight "[#$buildid] dpkg-buildpackage" | log_error

		return 1
	fi

	while read -r package; do
		if ! output=$(dpkg-sig --sign builder -k "$gpgkey" "$package"); then
			log_error "[#$buildid] Could not sign $package"
			echo "output" | log_highlight "dpkg-sig" | log_error
			return 1
		fi

		if ! realpath "$package"; then
			log_error "[#$buildid] Could not normalize path $package"
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
	local buildid="$1"
	local repository="$2"
	local branch="$3"
	local gpgkey="$4"
	local workdir="$5"

	local buildroot
	local packages
	local err

	err=1

	buildroot="$workdir/buildroot"
	log_info "[#$buildid] Building $repository#$branch in $buildroot"

	if ! mkdir -p "$buildroot"; then
		log_error "[#$buildid] Could not create buildroot"
		return 1
	fi

	if ! git clone "$repository" -b "$branch" "$buildroot" &>/dev/null; then
		log_error "[#$buildid] Could not clone $repository#$branch to $buildroot"
	elif ! packages=$(build_packages "$buildid" "$buildroot" "$gpgkey"); then
		log_error "[#$buildid] Could not build package"
	else
		log_info "[#$buildid] Build succeeded: $repository#$branch"
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
		local buildid
		local repository
		local branch
		local workitem
		local workdir
		local package
		local result

		if ! workdir=$(mktemp -d); then
			log_error "Could not create workdir"
			return 1
		fi

		if ! workitem=$(queue_get "$taskq"); then
			continue
		fi

		read -r buildid repository branch <<< "$workitem"
		if [[ -z "$buildid" ]] || [[ -z "$repository" ]] || [[ -z "$branch" ]]; then
			log_error "Could not parse workitem: $workitem"
			continue
		fi

		if ! result=$(build_repository "$buildid" "$repository" "$branch" \
					       "$gpgkey" "$workdir"); then
			continue
		fi

		while read -r package; do
			while ! queue_put_file "$doneq" "$package" "$buildid"; do
				log_error "[#$buildid] Could not put $package in queue. Trying again in a bit."
				log_error "[#$buildid] This usually means the disk with the queue is full, or permissions have been changed."
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
