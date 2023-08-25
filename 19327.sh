#!/bin/sh

local=local.json
remote=remote.json

# ask for sudo rights before the subshell
sudo -v
(
    cd docker-compose || exit 1
    ./run.sh &
)

# wait for Buildbarn to spawn
sleep 10

bazelisk version
echo ""

bazelisk build \
    --build_event_json_file="$local" \
    //:foo

bazelisk build \
    --config=remote-ubuntu-22-04 \
    --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 \
    --build_event_json_file="$remote" \
    //:foo

echo "You can now compare $local and $remote"

(
    cd docker-compose || exit 1
    docker-compose down
)
