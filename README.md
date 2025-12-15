# claudo

**claudo** = **claud**e in **do**cker

Run Claude Code inside a Docker container for isolation, mounting the current
directory for easy access to your project.

The idea: It is so effective to run claude with `--dangerously-skip-permissions`, but also dangerous. Claude might go wild and [delete your home directory](https://www.reddit.com/r/ClaudeAI/comments/1pgxckk/claude_cli_deleted_my_entire_home_directory_wiped/).
It might be attacked by a prompt injection.

To develop with claude code, I would usually setup a devcontainer environment to isolate the project - but in quick and dirty cases where I just need AI help with filesystem access, I would not bother to do the 2 minute setup. I just want a quick command like `claude` on the CLI which gives me the AI powers.

`claudo` does that, but runs `claude --dangerously-skip-permissions` in a docker container.

![claudo demo](demo/demo.gif)

## Features

- Mounts the current directory into `/workspaces/`
- Mounts `~/.claude` for authentication persistence (no re-login required)
- Docker-in-Docker support (`--dind`)
- Git config mounting for commits inside container (`--git`)
- Named persistent containers (`-n`)
- Security hardening with `--no-sudo` or `--no-privileges`
- Isolated mode without directory mount (`--tmp`)
- Custom image support (`-i` or `$CLAUDO_IMAGE`)

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
  --dind          Mount Docker socket for Docker-in-Docker commands
  -e KEY=VALUE    Set environment variable in container (can be used multiple times)
  --git           Mount git config (~/.gitconfig and credentials) for committing
  --host          Use host network mode
  -i, --image IMG Use specified Docker image (default: $CLAUDO_IMAGE or built-in)
  -n, --name NAME Create a named container 'claudo-NAME' that persists after exit
  --no-sudo       Disable sudo (adds no-new-privileges restriction)
  --no-privileges Drop all capabilities (most restrictive)
  --tmp           Run isolated (no directory mount, workdir /workspaces/tmp)
  -v, --verbose   Display docker command before executing
  -h, --help      Show this help message

Arguments after -- are passed directly as the container command.

Examples:
  claudo                          Run claude --dangerously-skip-permissions (default)
  claudo -e API_KEY=xxx           Start with environment variable
  claudo --host                   Start with host networking
  claudo -n myproject             Start named persistent container
  claudo --no-sudo                Start without sudo privileges
  claudo --no-privileges          Start with all caps dropped
  claudo -- claude --help         Run claude with arguments
  claudo --dind                   Enable docker commands from inside container
  claudo --git                    Enable git commits from inside container
  claudo -i claudo-base:latest    Use a different image
  claudo -n dev -e DEBUG=1 -- claude
                                  Combined options with command

The current directory is mounted at /workspaces/<dirname>.
~/.claude is mounted for authentication persistence.
```
<!--[[[end]]]-->
