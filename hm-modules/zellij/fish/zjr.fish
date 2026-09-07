if test (count $argv) -lt 1
    echo "usage: zjr <ssh-host> [session]" >&2
    return 2
end
set -l host $argv[1]
set -l name $argv[2]
test -z "$name"; and set name main

# -t forces a remote TTY; the keepalives make a dead link fail fast instead of
# hanging on a half-open socket.
ssh -t -o ServerAliveInterval=30 -o ServerAliveCountMax=3 $host -- \
    zellij attach --create $name
