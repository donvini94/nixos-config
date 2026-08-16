# The only automatic Hermes -> n8n path.
#
# Hermes has no n8n administration credential and no general web tool. This
# command posts to exactly one reviewed webhook, with a schema the receiving
# workflow validates again. The persisted n8n execution is the delivery record:
# there is deliberately no local queue, retry store, or path building here.
{
  writeShellApplication,
  curl,
  jq,
}:

writeShellApplication {
  name = "hermes-n8n-handoff";
  runtimeInputs = [
    curl
    jq
  ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: hermes-n8n-handoff --correlation-id ID --kind artifact|event --payload JSON

      --correlation-id  [A-Za-z0-9_-]{1,64}, chosen by the caller
      --kind            artifact | event
      --payload         a JSON object

    Posts one message to the reviewed n8n inbox webhook and prints n8n's
    acknowledgment. Requires N8N_WEBHOOK_TOKEN in the environment.
    EOF
      exit 2
    }

    correlation_id=""
    kind=""
    payload=""

    while (( $# )); do
      case "$1" in
        --correlation-id) correlation_id="''${2:-}"; shift 2 ;;
        --kind)           kind="''${2:-}"; shift 2 ;;
        --payload)        payload="''${2:-}"; shift 2 ;;
        -h|--help)        usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
      esac
    done

    # Validate here as well as in the workflow: a bad call should fail at the
    # agent, not consume an execution and return a 400 the agent has to parse.
    [[ "$correlation_id" =~ ^[A-Za-z0-9_-]{1,64}$ ]] ||
      { echo "invalid --correlation-id (expected [A-Za-z0-9_-]{1,64})" >&2; exit 2; }
    [[ "$kind" == "artifact" || "$kind" == "event" ]] ||
      { echo "invalid --kind (expected artifact or event)" >&2; exit 2; }
    jq -e 'type == "object"' >/dev/null 2>&1 <<<"$payload" ||
      { echo "invalid --payload (expected a JSON object)" >&2; exit 2; }

    : "''${N8N_WEBHOOK_TOKEN:?N8N_WEBHOOK_TOKEN is not set in the Hermes environment}"

    body="$(jq -nc \
      --arg correlation_id "$correlation_id" \
      --arg kind "$kind" \
      --argjson payload "$payload" \
      '{ correlation_id: $correlation_id, kind: $kind, payload: $payload }')"

    # --fail-with-body: keep n8n's validation message instead of swallowing it,
    # and still exit non-zero so the agent sees the failure.
    exec curl --silent --show-error --fail-with-body \
      --max-time 30 \
      --header "X-Startup-Token: $N8N_WEBHOOK_TOKEN" \
      --header 'Content-Type: application/json' \
      --data "$body" \
      http://127.0.0.1:5678/webhook/startup/hermes-inbox
  '';

  meta = {
    description = "Post one reviewed handoff message from Hermes to n8n";
    mainProgram = "hermes-n8n-handoff";
  };
}
