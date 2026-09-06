function dbash --description "Bash into running container"
    if test (count $argv) -lt 1; or test $argv[1] = --help
        printf "Need a container name to bash into.\n" >&2
        return 1
    else if test (count $argv) -eq 1
        set --local container (docker ps -aqf "name=$argv[1]")
        if test -z "$container"
            printf "No container matches '%s'.\n" "$argv[1]" >&2
            return 1
        end
        docker exec -it $container bash
    end
end
