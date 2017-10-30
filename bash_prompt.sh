# Roland's Sophisticated Bash Prompt
#
#        Author: Roland Hopferwieser <develop -AT- int0x80.at>
#        Source: https://github.com/rhopfer/bash-prompt
# Last modified: October 30, 2017
#
# Environment Variables
# ---------------------
# PROMPT_REPOS (boolean or string)
#     Show repository. Set it to 0 to disable it.
#     Set it to one or more of 'git', 'svn', 'hg' or 'bzr' to enable only these.
#
# PROMPT_HOST (boolean)
#     Show hostname in prompt. Normally shown on remote host. 
#
# PROMPT_USER (boolean)
#     Show username in prompt. Normally shown when root.
#
# PROMPT_IGNORE (string)
#     Colon separated string of sub-shells to ignore.
#
# PROMPT_DIRTRIM (integer)
#     Number of trailing path components shown (Default: 2)
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
#         root          user if the effective UID is 0
#         path          the path
#         jobs          the background jobs
#         at            the @ before hostname
#         display       the @ if X11 support available
#         symlink       if path is not the real path
#         sign          the prompt sign, $ for user, # for root
#         errsign       the sign if the recent command terminated with an error
#         errno         the error number (if not 0)
#         readonly      the trailing slash shown if the path is readonly
#         unsafe        the trailing slash shown if the path is world writeable
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
# PROMPT_FORCEBOL (boolean, string)
#     Force prompt to start on begin of line. On default it prints a gray '↵'.
#

function setprompt {
	local retval=$?
	local yes="(1|true|yes|always)"
	local no="(0|false|no|never)"
	local nocolor="\[\e[0m\]"
	local strike="\[\e[9m\]"
	local nostrike="\[\e[29m\]"

	# Force start of line
	local nlsign="\e[1;30m↵\e[0m"
	local col
	if [[ ! "$PROMPT_FORCEBOL" =~ $no || "$PROMPT_FORCEBOL" =~ "[" ]]; then
		if [[ "$PROMPT_FORCEBOL" =~ $yes && ! "$PROMPT_FORCEBOL" =~ "[" ]]; then
			nlsign=""
		elif [[ -n "$PROMPT_FORCEBOL" ]]; then
			nlsign=$PROMPT_FORCEBOL
		fi
		# read cursor position
		read -s -dR -p $'\e[6n' col
		col=${col#*;}
		if [[ $col -gt 1 ]]; then
			echo -e $nlsign
		fi
	fi

	declare -A colors
	if [[ $(tput colors 2> /dev/null) -gt 8 ]]; then
		# 256 color terminal
		colors[host]="0;38;5;33"
		colors[user]="0;38;5;33"
		colors[root]="1;38;5;160"
		colors[path]="0;1"
		colors[jobs]="0;38;5;136"
		colors[at]="0;38;5;245"
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
		colors[at]="1;30"         # gray
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

	# Determine information from parent processes
	local ppid=$PPID
	local user_switched=0
	local subsh=
	local remote=0
	local shlvl=0
	if [[ $ppid -eq 0 && -r /proc/self/stat ]]; then
		# for chroot using unshare like arch-chroot does
		local stat=$(</proc/self/stat)
		ppid=$(echo $stat | awk '{print $4; }')
	fi
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
	if [[ ! "$PROMPT_HOST" =~ $no ]]; then
		if [[ $remote -eq 1 ]]; then
			host="\H"
		fi
	fi
	if [[ -n "$host" ]]; then
		if [[ -n "$DISPLAY" ]]; then
			# Green '@' with X11 support
			host="${colors[display]}@${colors[host]}${host}${nocolor}"
		else
			host="${colors[at]}@${colors[host]}${host}${nocolor}"
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

	# Path
	local path="$PWD"
	local pwd base basebath root skip
	# Resolve relative PWD (happend if inside deleted directory)
	while [[ -n $path ]]; do
		local dir=${path##*/}
		if [[ "$dir" == '..' ]]; then
			let skip=$skip+1
		elif [[ $skip -gt 0 ]]; then
			let skip=$skip-1
		else
			pwd="/${dir}${pwd}"
		fi
		path=${path%/*}
	done
	path="$pwd"

	local home="${HOME%%/}"
	while read basepath name; do
		basepath="${basepath/#\~/$home}"
		basepath="${basepath%/}"
		if [[ -n "$basepath" && "$path" == "$basepath"* ]]; then
			path=${path/#$basepath/}
			root="${basepath%/}"
			base="${colors[base]}${name}${nocolor}"
			break
		fi
	done < <(<<<$PROMPT_BASES awk -F= '{print $2,$1}' RS=':|\n')
	if [[ -z "$base" && "$path" == "$home"* ]]; then
		path="${path/$home/}"
		base="${colors[path]}~${nocolor}"
	fi

	local realpath=$( readlink -f . )
	local dirs symlink deleted
	local dirtrim=${PROMPT_DIRTRIM:-2}
	if [[ "$realpath" == '' ]]; then
		deleted=1
	elif [[ "$realpath" != "$pwd" ]]; then
		symlink=1
	fi

	while [[ -n "$path" ]]; do
		local elem="${path##*/}"
		local count=$((count + 1))
		dirs="${elem}/${dirs}"

		if [[ $deleted -eq 1 ]]; then
			realpath=$( readlink -f "${root}${path}" )
			if [[ "$realpath" != '' ]]; then
				dirs="${strike}$dirs"
				deleted=0
				[[ "$realpath" != "${root}${path}" ]] && symlink=1
			fi
		elif [[ $symlink -eq 1 && -L "${root}${path}" ]]; then
			dirs="${colors[symlink]}$dirs"
			symlink=0
		fi
		path="${path%/*}"
		if [[ $dirtrim -gt 0 && $count -eq $dirtrim ]]; then
			break
		fi
	done
	[[ -n $dirs && $deleted -eq 1 ]] && dirs="${strike}$dirs"
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
	path="${base}${colors[path]}${path}"
	[[ -n $deleted ]] && path="${path}${nostrike}"

	# Show extra '/' if path is not or world writeable
	if [[ ! -w "$pwd" ]]; then
		path="${path%%/}${colors[readonly]}/"
	elif [[ ! -k "$pwd" && $((`stat -Lc "0%a" "$pwd"` & 0002)) != 0 ]]; then
		path="${path%%/}${colors[unsafe]}/"
	fi
	if [[ -n "${user}" || -n "${host}" ]]; then
		# separate path from user/host
		path=" $path"
	fi
	path="${path}${nocolor}"

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

	# Repositories
	local repos=""
	local git svn hg bzr owncloud
	if [[ -n "$PROMPT_REPOS" && ! $PROMPT_REPOS =~ $yes ]]; then
		[[ $PROMPT_REPOS =~ $no || ! $PROMPT_REPOS == *git* ]] && git=0
		[[ $PROMPT_REPOS =~ $no || ! $PROMPT_REPOS == *svn* ]] && svn=0
		[[ $PROMPT_REPOS =~ $no || ! $PROMPT_REPOS == *hg* ]] && hg=0
		[[ $PROMPT_REPOS =~ $no || ! $PROMPT_REPOS == *bzr* ]] && bzr=0
		[[ $PROMPT_REPOS =~ $no || ! $PROMPT_REPOS == *owncloud* ]] && owncloud=0
	fi
	local dir=$( readlink -f "$pwd" )
	[[ -n "$GIT_DIR" ]] && git=1
	while [[ -n "$dir" ]]; do
		[[ -z "$git" && -d "$dir/.git" ]] && git=1
		[[ -z "$svn" && -d "$dir/.svn" ]] && svn=1
		[[ -z "$hg" && -d "$dir/.hg" ]] && hg=1
		[[ -z "$bzr" && -d "$dir/.bzr" ]] && bzr=1
		mountpoint -q -- "$dir" && break
		dir="${dir%/*}"
	done
	if [[ $git -eq 1 && -x /usr/bin/git ]]; then
		local git_info=$(/usr/bin/git name-rev HEAD 2>/dev/null | sed -nre 's/HEAD (.*)/\1/p')
		if [[ -n ${git_info} ]]; then
			if [[ $(/usr/bin/git status -s 2>/dev/null | grep -E '^ ?([MARD]+) ') ]]; then
				git_info="${git_info}${colors[changes]}*${colors[repos]}"
			fi
			repos="${colors[repos]}{${git_info}}"
		fi
	fi
	if [[ $svn -eq 1 && -x /usr/bin/svnversion ]]; then
		local svn_stat=$(/usr/bin/svnversion 2>/dev/null)
		local svn_rev=$(echo $svn_stat | sed -nre 's/([0-9]+:?[0-9]+).*/\1/p')
		if [[ -n $svn_rev ]]; then
			if [[ $svn_stat =~ M$ ]]; then
				svn_rev="${svn_rev}${colors[changes]}*${colors[repos]}"
			fi
			repos="${repos}${colors[repos]}{r${svn_rev}}"
		fi
	fi
	if [[ $hg -eq 1 && -x /usr/bin/hg ]]; then
		local hg_info=$(/usr/bin/hg branch 2>/dev/null)
		if [[ -n ${hg_info} ]]; then
			if [[ $(/usr/bin/hg status -q 2>/dev/null | grep -E '^[MAR]+ ') ]]; then
				hg_info="${hg_info}${colors[changes]}*${colors[repos]}"
			fi
			repos="${repos}${colors[repos]}{${hg_info}}"
		fi
	fi
	if [[ $bzr -eq 1 && -x /usr/bin/bzr ]]; then
		local bzr_info=$(/usr/bin/bzr version-info --check-clean --custom --template='{branch_nick} {revno} {clean}' 2> /dev/null)
		if [[ -n ${bzr_info} ]]; then
			local bzr_branch bzr_rev bzr_clean
			read bzr_branch bzr_rev bzr_clean <<<"$bzr_info"
			bzr_info="$bzr_branch/$bzr_rev"
			if [[ $bzr_clean -eq 0 ]]; then
				bzr_info="${bzr_info}${colors[changes]}*${colors[repos]}"
			fi
			repos="${repos}${colors[repos]}{${bzr_info}}"
		fi
	fi

	# Owncloud
	local dir=$( readlink -f "$pwd" )
	local cloud_info
	while [[ -n "$dir" ]]; do
		if [[ -e "$dir/.owncloudsync.log" ]]; then
			grep -q "localPath=$dir" "$HOME/.local/share/data/ownCloud/owncloud.cfg" 2> /dev/null
			(( $? != 0 )) && break
			if pidof owncloud > /dev/null; then
				cloud_info="owncloud"
			else
				cloud_info="${strike}owncloud${nostrike}"
			fi
			repos="${repos}${colors[repos]}{${cloud_info}}"
			break
		fi
		mountpoint -q -- "$dir" && break
		dir="${dir%/*}"
	done

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

	PS1="${nocolor}${subsh}${user}${host}${path}${repos}${jobs} ${sign} "
}

PROMPT_COMMAND=setprompt

