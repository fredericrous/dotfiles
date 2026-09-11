# `chezmoi re-add` copies the RENDERED destination file back over its source.
# On a template that would replace every {{ directive }} with its rendered
# value -- and here that value is a private hostname -- so chezmoi refuses.
# It refuses in silence, though: no message, exit 0, and `chezmoi status`
# keeps showing ' M' as if nothing happened. Name what was skipped and where
# the edit actually belongs.
function chezmoi --wraps chezmoi --description 'chezmoi, but re-add names the templates it skips'
    if test (count $argv) -ge 1; and test "$argv[1]" = re-add
        set -l targets
        for a in $argv[2..]
            string match -q -- '-*' $a; or set -a targets $a
        end
        # No targets means "every modified file" -- ask status which those are.
        if test (count $targets) -eq 0
            set targets (command chezmoi status --path-style absolute 2>/dev/null | string match -r --groups-only '^.M (.+)$')
        end
        set -l skipped
        for t in $targets
            set -l src (command chezmoi source-path -- $t 2>/dev/null); or continue
            string match -q -- '*.tmpl' $src; and set -a skipped "$t"\n"      -> $src"
        end
        if test (count $skipped) -gt 0
            echo "chezmoi re-add: these are TEMPLATES and will not be re-added (their {{ }} would be lost):" >&2
            printf '  %s\n' $skipped >&2
            echo "  edit the .tmpl instead -- chezmoi edit <target> -- then chezmoi apply" >&2
        end
    end
    command chezmoi $argv
end
