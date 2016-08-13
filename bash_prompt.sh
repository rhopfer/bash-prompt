#!/bin/bash
#
# Roland's Sophisticated Bash Prompt
#
#        Author: Roland Hopferwieser
# Last modified: August 13, 2016
#
# Environment Variables
# ---------------------
# PROMPT_GIT (boolean)
#     Show GIT branch in repositories. (Default: no)
#
# PROMPT_SVN (boolean)
#     Show Subversion revision in repositories. (Default: no)
#
# PROMPT_HOST (boolean)
#     Show hostname in prompt. Normaly shown on remote host. 
#
# PROMPT_USER (boolean)
#     Show username in prompt. Normaly shown when root.
#
# PROMPT_IGNORE (string)
#     Colon separated string of sub-shells to ignore.
#
# PROMPT_BASES (string)
#     Pathes that should be reduced to a name. The string has the form
#         name1=path1:name2=path2 ...
#
#     Example:
#         PATH_PROMPT="linux=/usr/src/linux"
#
# PROMPT_COLORS (string)
#     Define custom colors. The variable has the form
#         keyword1=color1:keyword2=color2 ...
#
#     Keywords:
#         host          the hostname
#         user          the username
#         root          if the effective UID is 0
#         path          the path
#         jobs          the jobs in the background
#         display       if X11 support available
#         symlink       if path is not the real path
#         sign          the prompt sign, $ for user, # for root
#         errsign       the sign if the recent command terminated with an error
#         errno         the error number (if not 0)
#         readonly      the colon shown if the path is readonly
#         unsafe        the colon shown if the path is world writeable
#         repos         the repository
#         changes       the sign for a repository with modifications
#         term          the subshell
#
#     Colors:
#         A ANSI color sequence (see https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
#
#     Example:
#         PROMPT_COLORS="path=1;30:sign=1;33"
#

function setprompt {
	local retval=$?
	local colon=""
	local yes="1|true|yes|always"
	local no="0|false|no|never"

	local nocolor="\[\e[0m\]"
	declare -A colors
	if [[ $(tput colors) -gt 8 ]]; then
		# 256 color terminal
		colors[host]="0;38;5;33"
		colors[user]="0;38;5;33"
		colors[root]="1;38;5;160"
		colors[path]="0;1"
		colors[jobs]="0;38;5;136"
		colors[display]="0;38;5;40"
		colors[symlink]="1;38;5;245"
		colors[sign]="0;38;5;40"
		colors[errsign]="0;38;5;160"
		colors[errno]="0;38;5;245"
		colors[readonly]="1;38;5;160"
		colors[unsafe]="1;38;5;136"
		colors[changes]="0"
		colors[repos]="0;38;5;37"
		colors[term]="0;38;5;125"
		colors[base]="4"
	else
		# 16 color terminal
		colors[host]="0;34"       # cyan
		colors[user]="1;34"       # bright blue
		colors[root]="1;31"       # bright red
		colors[path]="0;1"        # default
		colors[jobs]="0;33"       # yellow
		colors[display]="0;32"    # green
		colors[symlink]="1;30"    # gray
		colors[sign]="0;32"       # green
		colors[errsign]="0;31"    # red
		colors[errno]="1;30"      # gray
		colors[readonly]="0;31"   # red
		colors[unsafe]="1;33"     # bright yellow
		colors[changes]="0"       # bold
		colors[repos]="1;36"      # bright blue
		colors[term]="0;35"       # magenta
		colors[base]="4"          # underlined
	fi

	# Load custom colors
	declare -A custom_colors
	if [[ -n "$PROMPT_COLORS" ]]; then
		while read k v; do
			custom_colors[$k]=$v
		done < <(<<<"$PROMPT_COLORS" awk -F= '{print $1,$2}' RS=':|\n')
	fi
	for c in "${!colors[@]}"; do
		if [[ -n "${custom_colors[$c]}" ]]; then
			colors[$c]="${custom_colors[$c]}"
		fi
		colors[$c]="\[\e[${colors[$c]}m\]"
	done

	# Path
	local path="$PWD"
	local base
	local root
	while read basepath name; do
		basepath="${basepath/#\~/$HOME}"
		basepath="${basepath%/}"
		if [[ -n "$basepath" && ( $path == "$basepath" || "$path" =~ ^"$basepath/" ) ]]; then
			path=${path/#$basepath/}
			root="${basepath%/}"
			base="${colors[base]}${name}${nocolor}"
			break
		fi
	done < <(<<<$PROMPT_BASES awk -F= '{print $2,$1}' RS=':|\n')
	if [[ -z "$base" && ( $path == "$HOME" || "$path" =~ "$HOME" ) ]]; then
		path="${path/$HOME/}"
		base="${colors[path]}~${nocolor}"
	fi

	[[ $( readlink -f . ) != "$PWD" ]] && local symlink=1
	local dirs
	while [[ -n "$path" ]]; do
		local elem="${path##*/}"
		dirs="${elem}/${dirs}"
		if [[ $symlink -ne 0 && -L "${root}${path}" ]]; then
			dirs="${colors[symlink]}$dirs"
			symlink=0
		fi
		path="${path%/*}"
		local count=$((count + 1))
		if [[ $PROMPT_DIRTRIM -gt 0 && $count -eq $PROMPT_DIRTRIM ]]; then
			break
		fi
	done
	[[ -n $dirs && $symlink -eq 1 ]] && dirs="${colors[symlink]}$dirs"
	if [[ -n $path ]]; then
		local ellipsis='...'
		if [[ $CHARMAP == UTF-8 || $LC_CTYPE =~ UTF || $(locale -k charmap) =~ UTF ]]; then
			ellipsis='…'
		fi
		dirs="${ellipsis}/$dirs"
	elif [[ ( -z $base ) ]]; then
		dirs="/$dirs"
	fi
	[[ ( -n "$base" && -n "$dirs" ) ]] && dirs="/$dirs"
	path="${dirs%/}"
	path="${base}${colors[path]}${path}${nocolor}"


	# Close sign
	local sign="\\\$"
	if [[ $retval -eq 0 ]]; then
		sign="${colors[sign]}${sign}"
	else
		sign="${colors[errno]}${retval}${colors[errsign]}${sign}"
	fi
	sign="${sign}${nocolor}"

	# Jobs
	local jobs=""
	if [ $(jobs -p | wc -l) -gt 0 ]; then
		jobs="${colors[jobs]}[\j]${nocolor}"
	fi

	# Determine information from parent processes
	local ppid=$PPID
	local user_switched=0
	local subsh=
	local remote=0
	local shlvl=0
	while [[ $ppid -ne 1 ]]; do
		[ -r /proc/$ppid/comm ] || break
		local comm=$(</proc/$ppid/comm)

		# Check for user switching
		if [[ $remote -eq 0 && "$comm" =~ bash|su ]]; then
			local uid=$(awk '/Uid:/ { print $2; }' /proc/$ppid/status)
			if [[ $uid -ne $EUID ]]; then
				user_switched=1
			fi
		fi

		if [[ ${EUID} == 0 && "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]]; then
			subsh=chroot
		fi

		if [[ -z "$subsh" ]]; then
			if [[ "$comm" == bash && $user_switched -eq 0 ]]; then
				shlvl=$((shlvl+1))
			elif [[ $shlvl -gt 0 && ! "$PROMPT_IGNORE" =~ bash ]]; then
				subsh=bash
			elif [[ "$comm" =~ script|screen|tmux|vcsh && ! "$PROMPT_IGNORE" =~ "$comm" ]]; then
				subsh=$comm
			fi
		fi
		if [[ "$comm" =~ ssh ]]; then
			remote=1
		fi

		ppid=`awk '{ print $4 }' /proc/$ppid/stat`
	done

	# Hostname
	local host=""
	if [[ "$PROMPT_HOST" =~ $yes || $remote -eq 1 ]]; then
		host="\H"
	elif [[ "$PROMPT_HOST" =~ $no ]]; then
		: # do nothing
	fi
	if [[ -n "$host" ]]; then
		if [[ -n "$DISPLAY" ]]; then
			# Green '@' with X11 support
			host="${colors[display]}@${colors[host]}${host}${nocolor}"
		else
			host="${colors[host]}@${host}${nocolor}"
		fi
	fi

	# Username
	local user=""
	if [[ "$PROMPT_USER" =~ $yes || ${EUID} -eq 0 || $user_switched -eq 1 ]]; then
		user="\u"
	elif [[ "$PROMPT_USER" =~ $no ]]; then
		: # do nothing
	fi
	if [[ -n "$user" ]]; then
		if [[ ${EUID} -eq 0 ]] ; then
			user="${colors[root]}${user}"
		else
			user="${colors[user]}${user}"
		fi
		if [[ -z "$host" ]]; then
			user="${user}"
		fi
	fi

	# Show ':' if path is not or world writeable
	if [[ ! -w "$PWD" ]]; then
		colon="${colors[readonly]}:${nocolor}"
	elif [[ ! -k "$PWD" && $((`stat -Lc "0%a" $PWD` & 0002)) != 0 ]]; then
		colon="${colors[unsafe]}:${nocolor}"
	elif [[ -n "${user}" || "${host}" ]]; then
		colon=" "
	fi

	# Repositories
	local repos=""
	if [[ -x /usr/bin/git && $PROMPT_GIT =~ $yes ]]; then
		local git_info=$(/usr/bin/git name-rev HEAD 2>/dev/null | sed -nre 's/HEAD (.*)/{\1/p')
		if [[ -n ${git_info} ]]; then
			if [[ $(/usr/bin/git status -s 2>/dev/null | grep -E '^ ?([MARD]+) ') ]]; then
				git_info="${git_info}${colors[changes]}*${colors[repos]}"
			fi
			git_info="${git_info}}"
		fi
		repos="${colors[repos]}${git_info}"
	fi
	if [[ -x /usr/bin/svnversion && $PROMPT_SVN =~ $yes ]]; then
		local svn_stat=$(/usr/bin/svnversion 2>/dev/null)
		local svn_rev=$(echo $svn_stat | sed -nre 's/([0-9]+:?[0-9]+).*/\1/p')
		local svn_info=""
		if [[ -n $svn_rev ]]; then
			if [[ $svn_stat =~ M$ ]]; then
				svn_rev="${svn_rev}${colors[changes]}*${colors[repos]}"
			fi
			svn_info="{r${svn_rev}}"
		fi
		repos="${repos}${colors[repos]}${svn_info}"
	fi
		
	# Subshell
	if [[ "$subsh" == bash ]]; then
		subsh="$shlvl"
	elif [[ "$subsh" == vcsh && -n "$VCSH_REPO_NAME" ]]; then
		subsh="$subsh:$VCSH_REPO_NAME"
	elif [[ "$subsh" == screen && -n $WINDOW ]]; then
		subsh=$subsh:$WINDOW
	fi
	if [[ -n "$subsh" ]]; then
		subsh="${colors[term]}(${subsh})${nocolor} "
	fi

	PS1="${subsh}${user}${host}${colon}${path}${repos}${jobs} ${sign} "
}
PROMPT_COMMAND=setprompt

