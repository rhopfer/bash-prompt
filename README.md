## Look
At `$HOME`:

![~ $](images/base.png)

With return code &ne; 0:

![~ 1$](images/errno.png)

With background jobs:

![~[1] $](images/bg.png)

In a read-only directory:

![:/usr/src $](images/ro.png)

If `PROMPT_DIRTRIM=n` is set, only the `n` trailing path components are shown:

![Dirtrim](images/path.png)

In a GIT repository it shows the current branch and a star if there are uncommited changes.
Only visible if the environment variable `PROMPT_GIT=1` is set.

![~/dev/bash-prompt{master} $](images/git.png)

Analog in a SVN repository it shows the current revision if `PROMPT_SVN=1` is set.

If the current bash is running inside one of screen, tmux, script(1), chroot(1), [vcsh](https://github.com/RichiH/vcsh/), or another bash:

![Subshell](images/subshell.png)

The user name is only visible if root, but can be forced by setting `PROMPT_USER=1`.

![User](images/user.png)

The host name is only visible on remote hosts, but can be forced by setting `PROMPT_HOST=1`.

![Host](images/host.png)

If `DISPLAY` variable is set, it will be shown by a green `@` on the host part.

![Display](images/display.png)

With all features:

![Full prompt](images/full.png)

Also good readable with light background:

![White background](images/white.png)

## Use
Copy `bash_prompt.sh` to e.g. `~/.bash_prompt` and source it with
```
source ~/.bash_prompt
```

If you want to use it in all new shells, add it to your `.bashrc`, e.g.
```
[ -f ~/.bash_prompt ] && source ~/.bash_prompt
```

If you want to install it for all users on the system, copy it to
* `/etc/bash/bashrc.d/` (e.g. on Gentoo)
* `/etc/profile.d/` (e.g. on Debian and Ubuntu)

## Color scheme
The script contains a color sheme for 256 color terminals as well as a fallback scheme for terminals which support just 16 colors. 
To enable 256 color capabilities on your terminal, add following to your `.bashrc`:
```
case "$TERM" in
  'xterm') TERM=xterm-256color;;
  'screen') TERM=screen-256color;;
  'Eterm') TERM=Eterm-256color;;
esac
export TERM

if [ -n "$TERMCAP" ] && [ "$TERM" = "screen-256color" ]; then
  TERMCAP=$(echo "$TERMCAP" | sed -e 's/Co#8/Co#256/g')
  export TERMCAP
fi
```
To get the color numbers of your actual TERM, use the following:
```
$ tput colors
256
```
See https://fedoraproject.org/wiki/Features/256_Color_Terminals

### Customization
The color scheme can be customized by the `PROMPT_COLORS` environment variable. The variable has the form
```
PROMPT_COLORS="keyword1=color1:keyword2=color2:..."
```
Valid keywords are:
```
host user root path jobs display symlink sign errsign errno readonly repos changes term
```
Colors are defined by [ANSI color sequences](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors).

Example:
```
export PROMPT_COLORS="path=1;30:sign=1;33"
```

## Alternatives

* [Liquid prompt](https://github.com/nojhan/liquidprompt)
* [Powerline](https://github.com/powerline/powerline)
