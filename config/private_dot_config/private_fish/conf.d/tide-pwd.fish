# Compact pwd for Tide (~/g/p/s/dotfiles): no folder icon, last dir bolded
# like tide's anchors. Overrides tide's internal _tide_pwd — the narrowest
# seam for an always-short path with correct right-prompt alignment: tide's
# fish_prompt substitutes the baked @PWD@ placeholder via _tide_pwd and
# positions the right side using the $_tide_pwd_len this function reports.
# Tide re-sources the file defining _tide_pwd when fish_prompt loads, so this
# file must stay a bare function definition. Internal-API dependency is
# defended by the exact tide version pin in fish_plugins.
function _tide_pwd
    set -l spwd (prompt_pwd --dir-length=1 --full-length-dirs=1)
    string length -V -- $spwd | read -l len

    # $dist_btwn_sides is the column budget fish_prompt has left for the pwd
    # once both prompt sides are laid out (exported local, so visible here;
    # unset when _tide_pwd is called outside the prompt). Tide's stock
    # _tide_pwd shrinks parent dirs while the pwd exceeds it — a feedback loop
    # this override otherwise drops, leaving fish to left-truncate the entire
    # prompt line to '…' and take the branch down with the path. The dirs are
    # already one character each, so unlike tide there is no shortest-unique-
    # prefix search left to do: drop the parents, then the last dir too, ending
    # at a bare '…' that honestly reads as "no room" instead of the path
    # fragment fish's own truncation would leave behind. Every step applies
    # only while still over budget and only when it strictly shortens, so a
    # path that already fits is never touched and `~` is never rewritten (no
    # step beats one character). Under a hostile budget even a short path can
    # collapse to `…`, because fitting beats staying informative.
    if set -q dist_btwn_sides
        set -l ladder (string replace -r -- '^.*/' '…/' $spwd) \
            (string replace -r -- '^.*/' '' $spwd) …
        for shorter in $ladder
            test $len -le $dist_btwn_sides && break
            test -n "$shorter" || continue
            string length -V -- $shorter | read -l shorter_len
            test $shorter_len -lt $len || continue
            set spwd $shorter
            set len $shorter_len
        end
    end

    set -g _tide_pwd_len $len
    echo -ns (set_color $tide_pwd_color_dirs) (
        string replace -r -- '([^/]+)$' (set_color -o $tide_pwd_color_anchors)'$1' $spwd
    ) (set_color normal -b $tide_pwd_bg_color) (set_color $tide_pwd_color_dirs)
end
