if test (count $argv) -lt 1
    echo "usage: zjls <ssh-host>" >&2
    return 2
end
ssh $argv[1] -- zellij list-sessions --no-formatting
