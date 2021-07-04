alias cat='bat -p'
alias ls='lsd'
alias top='btm'
alias diff='delta'
alias fd='fd -H'
alias ping='prettyping'
alias ssh='mosh'

function code2img --argument-names language 
    silicon --from-clipboard -l $language --to-clipboard
end
