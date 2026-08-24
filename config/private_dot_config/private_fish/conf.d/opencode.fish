set -l opencode_corp_config "$HOME/.config/opencode/opencode.corp.json"

if test -f "$opencode_corp_config"
    set -gx OPENCODE_CONFIG "$opencode_corp_config"
end
