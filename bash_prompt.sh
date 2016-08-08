#!/bin/bash
#
# Roland's Sophisticated Bash Prompt
#
#        Author: Roland Hopferwieser
# Last modified: August 2, 2016
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
#     Show hostname in prompt. Normaly shown on remote host (SSH_TTY). 
#
# PROMPT_USER (boolean)
#     Show username in prompt. Normaly shown when root.
#
# PROMPT_SHLVL (integer)
#     Show the shell level if $SHLVL greater than this value (and not a special subshell).
#
# PROMPT_COLORS (string)
#     Define custom colors. The variable has the form
#        keyword1=color1:keyword2=color2 ...
#
#     Keywords:
#         host			the hostname
#         user			the username
#         root			if the effective UID is 0
#         path			the path
#         jobs			the jobs in the background
#         display		if X11 support available
#         symlink		if path is not the real path
#         sign			the prompt sign, $ for user, # for root
#         errsign		the sign if the recent command terminated with an error
#         errno			the error number (if not 0)
#         readonly		the colon shown if the path is readonly
#         repos			the repository
#         changes		the sign for a repository with modifications
#         term			the subshell
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
		colors[root]="0;38;5;160"
		colors[path]="0;1"
		colors[jobs]="0;38;5;136"
		colors[display]="0;38;5;40"
		colors[symlink]="1;38;5;245"
		colors[sign]="0;38;5;40"
		colors[errsign]="0;38;5;160"
		colors[errno]="0;38;5;245"
		colors[readonly]="1;38;5;160"
		colors[changes]="0"
		colors[repos]="0;38;5;37"
		colors[term]="0;38;5;125"
	else
		# 16 color terminal
		colors[host]="0;34"       # cyan
		colors[user]="1;34"       # bright blue
		colors[root]="0;31"       # red
		colors[path]="0;1"        # reset
		colors[jobs]="0;33"       # bright yellow
		colors[display]="0;32"    # green
		colors[symlink]="1;30"    # gray
		colors[sign]="0;32"       # green
		colors[errsign]="0;31"    # red
		colors[errno]="1;30"      # gray
		colors[readonly]="0;31"   # red
		colors[changes]="0"       # reset
		colors[repos]="1;36"      # bright blue
		colors[term]="0;35"       # magenta
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
	local path="\w"
	if [[ $PROMPT_DIRTRIM -gt 0 ]]; then
		path=${PWD/$HOME/\~}
		local ellipsis
		if [[ $CHARMAP == UTF-8 || $LC_CTYPE =~ UTF || $(locale -k charmap) =~ UTF ]]; then
			ellipsis='…'
		else
			ellipsis='...'
		fi

		local OIFS="$IFS"
		local IFS='/'
		local elements=( $path )

		local count="${#elements[*]}"

		# First element: ~ or ''
		if [[ $(( count - 1 )) -gt $PROMPT_DIRTRIM ]]; then
			local offset=$((count-PROMPT_DIRTRIM))
			path="${colors[path]}${ellipsis}${colors[path]}/${elements[*]:offset:PROMPT_DIRTRIM}"
			[[ "${elements[0]}" == '~' ]] && path="~/$path"
		fi
		IFS="$OIFS"
	fi

	# Change path color if on symbolik path
	if [[ $(readlink -f .) != "$PWD" ]]; then
		path="${colors[symlink]}${path}${nocolor}"
	else
		path="${colors[path]}${path}${nocolor}"
	fi

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

	# Hostname
	local host=""
	local host_str="${colors[host]}@\H"
	if [[ ! "$PROMPT_HOST" =~ $no ]]; then
		# Green '@' with X11 support
		if [[ -n "$DISPLAY" ]]; then
			host_str="${colors[display]}@${colors[host]}\H"
		fi


		if [[ "$PROMPT_HOST" =~ $yes ]]; then
			host="$host_str"
		elif [ -n "$SSH_TTY" ]; then
			host="$host_str"
		else
			local ppid=$PPID
			while [[ $ppid -ne 1 ]]; do
				grep -q ssh /proc/$ppid/comm
				if [ $? -eq 0 ]; then
					host="$host_str"
					break
				fi
				ppid=`awk '{ print $4 }' /proc/$ppid/stat`
			done
		fi
	fi

	# Username
	local user=""
	if [[ "$PROMPT_USER" =~ $yes ]]; then
		user="\u"
	elif [[ "$PROMPT_USER" =~ $no ]]; then
		: # do nothing
	else
		if [[ ${EUID} == 0 ]] ; then
			user="\u"
		fi
	fi
	if [[ -n "$user" ]]; then
		if [[ ${EUID} == 0 ]] ; then
			user="${colors[root]}${user}"
		else
			user="${colors[user]}${user}"
		fi
		if [[ -z "$host" ]]; then
			user="${user}"
		fi
	fi

	# Show red ':' if path not writeable
	if [[ ! -w "$PWD" ]]; then
		colon="${colors[readonly]}:"
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
	local term=""
	local shlvloff=${PROMPT_SHLVL:-1}
	if [ -n "$VCSH_REPO_NAME" ]; then
		term="(vcsh:$VCSH_REPO_NAME) "
	elif [[ ${EUID} == 0 && "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]]; then
		term="(chroot)"
	elif [ -n "$TMUX" ]; then
		term="(tmux) "
	elif [[ $TERM =~ screen ]]; then
		term=screen
		if [ -n $WINDOW ]; then
			term=$term:$WINDOW
		fi
		term="($term) "
	elif [[ -n ${PROMPT_SHLVL} && $SHLVL -gt $shlvloff ]]; then
		local shlvl=$((SHLVL-shlvloff))
		term="($shlvl) "
	fi
	term="${colors[term]}${term}${nocolor}"

	PS1="${term}${user}${host}${colon}${path}${repos}${jobs} ${sign} ${nocolor}"
}
PROMPT_COMMAND=setprompt

