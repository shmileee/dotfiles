# Overrides tide's internal _tide_pwd for an always-short path: fish_prompt
# substitutes the baked @PWD@ placeholder through it and positions the right
# side using the $_tide_pwd_len this function reports. Tide re-sources the
# defining file when fish_prompt loads, so this file must stay a bare function
# definition. The internal-API dependency is pinned in fish_plugins.
function _tide_pwd
    set -l spwd (prompt_pwd --dir-length=1 --full-length-dirs=1)
    string length -V -- $spwd | read -l len

    # $dist_btwn_sides is fish_prompt's remaining column budget for the pwd (an
    # exported local, unset when _tide_pwd runs outside the prompt). Without
    # this shrink loop fish left-truncates the whole prompt line to '…', branch
    # included. Each step applies only while over budget and only if it strictly
    # shortens, so a path that already fits is never touched.
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
