#!/command/with-contenv sh
# AionUI WebUI startup
# Hermes gateway auto-starts via s6 service (main-hermes)
set -e

# Auto-configure Hermes model/provider from env vars (runs once)
if [ -n "$HERMES_DEFAULT_MODEL" ]; then
  CURRENT_MODEL=$(hermes config get model 2>/dev/null || echo "")
  if [ "$CURRENT_MODEL" != "$HERMES_DEFAULT_MODEL" ]; then
    hermes config set model "$HERMES_DEFAULT_MODEL"
  fi
fi

if [ -n "$HERMES_DEFAULT_PROVIDER" ]; then
  CURRENT_PROV=$(hermes config get provider 2>/dev/null || echo "")
  if [ "$CURRENT_PROV" != "$HERMES_DEFAULT_PROVIDER" ]; then
    hermes config set provider "$HERMES_DEFAULT_PROVIDER"
  fi
fi

cd /opt/aionui
exec ./aionui-web
