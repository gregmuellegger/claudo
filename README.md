# claudo

**claudo** = **claud**e in **do**cker

Run Claude Code inside a Docker container for isolation, mounting the current
directory for easy access to your project.

The idea: It is so effective to run claude with `--dangerously-skip-permissions`, but also dangerous. Claude might go wild and [delete your home directory](https://www.reddit.com/r/ClaudeAI/comments/1pgxckk/claude_cli_deleted_my_entire_home_directory_wiped/).
It might be attacked by a prompt injection.

To develop with claude code, I would usually setup a devcontainer environment to isolate the project - but in quick and dirty cases where I just need AI help with filesystem access, I would not bother to do the 2 minute setup. I just want a quick command like `claude` on the CLI which gives me the AI powers.

`claudo` does that, by running `claude --dangerously-skip-permissions` in a docker container.

At its core `claudo` is a shortcut that translates into this (plus a few more additional features, see below):

```bash
docker run -it --rm --hostname claudo \
    -v $HOME/.claude:/home/claudo/.claude \
    -v $PWD:/workspaces/$(basename $PWD) \
    -w /workspaces/$(basename $PWD) \
    ghcr.io/gregmuellegger/claudo:latest \
    claude --dangerously-skip-permissions
```

![claudo demo](demo/demo.gif)

## Features

- Mounts the current directory into `/workspaces/`
- Mounts `~/.claude` for authentication persistence (no re-login required)
- Docker-in-Docker support (`--dind`) with isolated daemon
- Host Docker socket mounting (`--docker-socket`) for sibling containers
- Git config mounting for commits inside container (`--git`)
- Named persistent containers (`-n`)
- Security hardening with `--no-sudo` or `--no-privileges`
- Isolated mode without directory mount (`--tmp`)
- Custom image support (`-i` or `$CLAUDO_IMAGE`)
- See the `docker run` command without executing it so you can inspect how it works under the hood (`--dry-run`)

## Usecases

A few things I do regularly with `claudo`:

### Exploring code bases

Exploring a code base. Agents are exceptionally good at exploring code bases quickly. So if you have a question about an undocumented feature, just ask claude to clone the repo and work with it.

E.g.:

1. start `claudo --tmp`
2. Prompt with something like `Clone https://github.com/leeoniya/uPlot Give me an architectural overview of the library.`

### Chore on your local files

Have a bunch of scanned files with strange filenames?

Ask claudo to rename them appropriately:

```bash
claudo -p 'This directory contains a set of scanned sheet music. Please read them, find the composer name and the title of the song and rename the files appropriatelly in the format: "<SONG TITLE>, <COMPOSER>, <YEAR> (<MUSICAL KEY>).pdf Skip the year if nothing is mentioned in the PDF.'
```

### Create one-of scripts

I had the need to geocode a few images. I just asked claude to create a script for this, but since I don't want it to have access to all my images I just placed a `.jpg` for it to work on in a directory and then prompted it to create a bash script to use a free geocoding API.

Boom, worked. Without exposing all my private images to Claude.

I then could use the generated script on all my images without privacy concerns.

This is how these scripts were created: https://gist.github.com/gregmuellegger/3699d8ffb26ea39fb617c6e153f1775f

## Security Considerations

`claudo` runs inside a docker container. This safeguards from the most obvious attacks. However keep in mind that the code still runs on your local computer, so any security vulnerability in docker might be exploited. Also there are a few specifics about `claudo` that you should be aware of:

- **`~/.claude` is mounted read-write** for authentication persistence. Code running in the container can modify Claude's configuration and credentials.
- **using `--dind` will run docker in privileged mode.** Required for running Docker daemon inside the container. Provides near-host-level access.
- **`--docker-socket` grants host root equivalent access.** The Docker socket allows full control of the host via Docker. Only use when you trust the code running inside.

The default image used is `ghcr.io/gregmuellegger/claudo:latest`. It is based on Ubuntu 24.04 with Claude Code pre-installed. Includes common dev tools: git, neovim, ripgrep, fd, fzf, jq, tmux, zsh (with oh-my-zsh), uv, and docker-cli.

The image is updated weekly to incorporate latest Ubuntu security patches (using `apt upgrade`). But you need to `claudo --pull` yourself to get the updates.

## Installation

Requires Docker.

Install by placing the `claudo` script in your `~/.local/bin` directory. Make sure it is on `$PATH`.

```bash
curl -fsSL https://raw.githubusercontent.com/gregmuellegger/claudo/main/claudo -o ~/.local/bin/claudo && chmod +x ~/.local/bin/claudo
```

## Examples

```bash
claudo                        # run claude interactively
claudo -- zsh                 # open zsh shell
claudo -- claude --help       # run claude with args
echo "fix the bug" | claudo   # pipe prompt to claude
claudo --dind                 # Docker-in-Docker (isolated daemon)
claudo --docker-socket        # use host Docker socket (sibling containers)
claudo --dind -- docker ps    # run docker ps with isolated daemon
```

## Usage

<!--[[[cog
import cog
import subprocess
result = subprocess.run(['./claudo', '--help'], capture_output=True, text=True)
cog.outl('```')
cog.out(result.stdout)
cog.outl('```')
]]]-->
```
claudo - Run Claude Code in a Docker container

Usage: claudo [OPTIONS] [--] [COMMAND...]

Options:
  -e KEY=VALUE    Set environment variable in container (can be used multiple times)
  -p, --prompt PROMPT  Run claude with -p (prompt mode)
  -i, --image IMG Use specified Docker image (default: $CLAUDO_IMAGE or built-in)
  --host          Use host network mode
  --no-sudo       Disable sudo (adds no-new-privileges restriction)
  --no-privileges Drop all capabilities (most restrictive)
  --dind          Docker-in-Docker (runs dockerd inside container, requires privileged)
  --docker-socket Mount host Docker socket (sibling containers, host root equivalent)
  --git           Mount git config (~/.gitconfig and credentials) for committing
  --pull          Always pull the latest image before running
  -n, --name NAME Create a named container 'claudo-NAME' that persists after exit
  --tmp           Run isolated (no directory mount, workdir /workspaces/tmp)
  -v, --verbose   Display docker command before executing
  --dry-run       Show docker command without executing (implies --verbose)
  --docker-opts OPTS  Pass additional options to docker run
  -h, --help      Show this help message

Arguments after -- are passed directly as the container command.

Examples:
  claudo                          Run claude --dangerously-skip-permissions (default)
  claudo -e API_KEY=xxx           Start with environment variable
  claudo -i claudo-base:latest    Use a different image
  claudo --host                   Start with host networking
  claudo --no-sudo                Start without sudo privileges
  claudo --no-privileges          Start with all caps dropped
  claudo --dind                   Docker-in-Docker (isolated daemon)
  claudo --docker-socket          Use host Docker socket (sibling containers)
  claudo --git                    Enable git commits from inside container
  claudo -n myproject             Start named persistent container
  claudo -- claude --help         Run claude with arguments
  claudo -n dev -e DEBUG=1 -- claude
                                  Combined options with command

The current directory is mounted at /workspaces/<dirname>.
~/.claude is mounted for authentication persistence.
```
<!--[[[end]]]-->
