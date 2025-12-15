set dotenv-load

image := "ghcr.io/gregmuellegger/claudo:latest"

build:
    docker build -t {{image}} .

push: build
    docker push {{image}}

update-readme:
    uvx --from cogapp cog -r README.md
