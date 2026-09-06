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
    string length -V -- $spwd | read -g _tide_pwd_len
    echo -ns (set_color $tide_pwd_color_dirs) (
        string replace -r -- '([^/]+)$' (set_color -o $tide_pwd_color_anchors)'$1' $spwd
    ) (set_color normal -b $tide_pwd_bg_color) (set_color $tide_pwd_color_dirs)
end
