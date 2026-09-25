# Path to Oh My Zsh installation.
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
export ZSH="$HOME/.oh-my-zsh"

SPACESHIP_GIT_SHOW=true
SPACESHIP_GIT_BRANCH_SHOW=true
SPACESHIP_GIT_BRANCH_COLOR="yellow"
SPACESHIP_GIT_STATUS_SHOW=false
SPACESHIP_GIT_BRANCH_PREFIX=""

SPACESHIP_DIR_PREFIX=""

SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_PROMPT_ORDER=(
  dir
  git
  exec_time
  char
)

SPACESHIP_CHAR_SYMBOL="> "
SPACESHIP_CHAR_COLOR_SUCCESS="green"
SPACESHIP_CHAR_COLOR_FAILURE="red"

ZSH_THEME="spaceship"

zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 13

COMPLETION_WAITING_DOTS="true"
COMPLETION_WAITING_DOTS="%F{yellow}...%f"

plugins=(git fzf-tab)

source $ZSH/oh-my-zsh.sh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:batcat*' fzf-preview 'batcat --color=always $realpath'
zstyle ':fzf-tab:complete:nano*' fzf-preview 'batcat --color=always $realpath'
zstyle ':fzf-tab:complete:nvim*' fzf-preview 'batcat --color=always $realpath'
zstyle ':fzf-tab:complete:cat*' fzf-preview 'cat $realpath'

alias nanoi='nano $(fzf --preview "batcat --color=always {}")'
alias nvimi='nvim $(fzf --preview "batcat --color=always {}")'
alias open='xdg-open $(fzf --preview "batcat --color=always {}")'
alias codei='code $(fzf --preview "batcat --color=always {}")'

# ROS2 setup with DOMAIN ID (guarded so the shell still starts without ROS)
[ -f /opt/ros/humble/setup.zsh ] && source /opt/ros/humble/setup.zsh
[ -f $HOME/abopt_ws/install/setup.zsh ] && source $HOME/abopt_ws/install/setup.zsh

export ROS_DOMAIN_ID=31

# Added for autocompletion of ros commands.
# Re-armed on every prompt: sourcing a workspace can reset _comps and drop the
# ros2 completer, so a precmd hook reinstalls it whenever it goes missing.
autoload -U +X bashcompinit && bashcompinit
_ros2_fix_completion() {
  [[ -n ${_comps[ros2]} ]] || eval "$(register-python-argcomplete3 ros2)"
}
if command -v register-python-argcomplete3 >/dev/null 2>&1; then
  autoload -U add-zsh-hook
  add-zsh-hook precmd _ros2_fix_completion
  _ros2_fix_completion
fi

# Alias
export EDITOR=code
export VISUAL=code
alias bs='colcon build && source install/setup.zsh'
alias s='source install/setup.zsh'

export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export DRI_NAME=card1
export NVIDIA_VISIBLE_DEVICES=all
export NVIDIA_DRIVER_CAPABILITIES=all
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
