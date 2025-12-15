set dotenv-load

image := "ghcr.io/gregmuellegger/claudo:latest"

build:
    docker build --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") -t {{image}} .

push: build
    docker push {{image}}

update-readme:
    uvx --from cogapp cog -r README.md

update-demo:
    asciinema rec --overwrite --cols 90 --rows 8 -c "./demo/record.sh" demo/demo.cast
    agg demo/demo.cast demo/demo.gif
