alias ls='eza -ahlF --color=always --icons=always --git --total-size --no-user --no-time --no-permissions '
alias ll='ls -lahF'
alias la='ls -alh'
alias dif="git diff --no-index"
alias tmuxk='tmux kill-session -t'
alias tmuxa='tmux attach -t'
alias tmuxl='tmux list-sessions'
alias vim="nvim_env"
alias nvim="nvim_env"
alias v="nvim_env"
alias create_project='create_project_function'
alias oc='opencode_setup'
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index
# moved out of .zprivate (it is an alias, not a secret)
alias sagemaker-who='_sagemaker_who() { aws sagemaker list-tags --resource-arn $(aws sagemaker describe-training-job --training-job-name "$1" --query "TrainingJobArn" --output text) --query "Tags[?Key==\`sagemaker:user-profile-arn\`].Value" --output text | awk -F"/" "{print \$NF}"; }; _sagemaker_who'
