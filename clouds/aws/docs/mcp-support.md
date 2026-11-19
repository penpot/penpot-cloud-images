# Penpot MCP on AWS

Penpot MCP is optional in the AWS single-node deployment. It is disabled by default and uses the same Penpot release tag as the frontend and backend.

## Enable MCP

Set the CloudFormation parameter `PenpotEnableMcp` to `true` when creating the stack. MCP requires `AccessMode=https-alb` so its OAuth endpoint is served over HTTPS. The configuration then:

- starts `penpotapp/mcp:${PENPOT_VERSION}` using the `mcp` Compose profile;
- enables the `enable-mcp` Penpot flag on frontend and backend;
- derives `PENPOT_MCP_AUTH_URI` from `PENPOT_PUBLIC_URI` as `/api/mcp/oauth`;
- proxies `/mcp/stream` and `/mcp/ws` through the host Nginx to the Penpot frontend.

The MCP container is not published directly to the host. MCP HTTP and WebSocket traffic goes through the same public Penpot endpoint and its HTTPS configuration.

## Optional feedback tool

To expose the MCP `submit_feedback` tool, set `PenpotMcpFeedbackEmail` and enable SMTP with valid settings. CloudFormation rejects a feedback inbox unless both `PenpotEnableMcp` and `PenpotEnableSmtp` are `true`. Without a feedback inbox, the core MCP tools remain available and feedback submission is not configured.

## Existing stacks

The MCP setting is written to the instance environment during bootstrap. Do not assume that changing a CloudFormation parameter alone reconfigures an already running instance; reapply the Penpot configuration and restart the Compose stack using the deployment runbook.

## Manual configuration

For a manually configured host, set `PENPOT_ENABLE_MCP=true` before running `/opt/penpot/bin/configure-penpot.sh`. The script derives the OAuth URI from `PENPOT_PUBLIC_URI`, enables the Compose profile, and configures the Penpot feature flag. Set `PENPOT_MCP_FEEDBACK_EMAIL` only when SMTP is configured and the feedback tool is intended to be available.
