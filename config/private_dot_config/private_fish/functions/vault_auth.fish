function vault_auth --description="Authenticate to a Vault environment"
    if test (count $argv) -ne 1
        printf "Usage: vault_auth ENVIRONMENT\n" >&2
        return 1
    end

    set --local env "$argv[1]"
    set -gx VAULT_ADDR "https://$env.vault.tuadm.net:8200"
    set -gx TF_VAR_vault_token_$env (vault login -method=oidc -path=okta role=admin -format=json 2>/dev/null | jq '.auth.client_token' -r)
end
