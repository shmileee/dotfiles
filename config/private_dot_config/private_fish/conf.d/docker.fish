status is-interactive; or return

function dstop --description="Stop all containers"
    set --local containers (docker ps -a -q)
    test (count $containers) -gt 0; or begin
        printf "No containers to stop.\n"
        return 0
    end
    docker stop $containers
end

function drm --description="Remove all containers"
    set --local containers (docker ps -a -q)
    test (count $containers) -gt 0; or begin
        printf "No containers to remove.\n"
        return 0
    end
    docker rm $containers
end

function drmf --description="Stop and Remove all containers"
    set --local containers (docker ps -a -q)
    test (count $containers) -gt 0; or begin
        printf "No containers to remove.\n"
        return 0
    end
    docker stop $containers && docker rm $containers
end

function drmi --description="Remove all images"
    set --local images (docker images -q)
    test (count $images) -gt 0; or begin
        printf "No images to remove.\n"
        return 0
    end
    docker rmi $images
end

function dbash --description="Bash into running container"
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
