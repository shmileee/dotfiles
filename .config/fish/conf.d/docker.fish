function dstop --description="Stop all containers"
    docker stop (docker ps -a -q)
end

function drm --description="Remove all containers"
    docker rm (docker ps -a -q)
end

function drmf --description="Stop and Remove all containers"
    docker stop (docker ps -a -q) && docker rm (docker ps -a -q)
end

function drmi --description="Remove all images"
    docker rmi (docker images -q)
end

function dbash --description="Bash into running container"
    if test (count $argv) -lt 1; or test $argv[1] = --help
        printf "Need a container name to bash into."
    else if test (count $argv) -eq 1
        docker exec -it (docker ps -aqf "name=$argv[1]") bash
    end
end
