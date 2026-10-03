# Deployment preference only; Requesty supplies the organization-approved catalog.
{
  # Clients on the tailnet reach alucard's ingress; alucard itself uses loopback.
  endpoint =
    viaTailnet:
    if viaTailnet then "http://alucard.tailf117a1.ts.net:28080/v1" else "http://127.0.0.1:8080/v1";
  defaultModel = "deepseek/deepseek-v4.1-flash";
}
