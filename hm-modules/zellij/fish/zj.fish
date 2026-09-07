set -l name $argv[1]
test -z "$name"; and set name (basename $PWD)
set -l layout $argv[2]

# list-sessions includes EXITED sessions, and attaching to one
# resurrects it — which is exactly what we want here.
if contains -- $name (zellij list-sessions --short --no-formatting 2>/dev/null)
    zellij attach $name
else if test -n "$layout"
    # -n, not --layout: with --session, --layout means "add these tabs to a session
    # that already exists" and errors out when it does not.
    zellij --session $name --new-session-with-layout $layout
else
    zellij --session $name
end
