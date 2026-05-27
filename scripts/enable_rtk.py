import yaml

CFG = "/opt/data/config.yaml"

with open(CFG) as f:
    data = yaml.safe_load(f) or {}

if "plugins" not in data:
    data["plugins"] = {}
if "enabled" not in data["plugins"]:
    data["plugins"]["enabled"] = []
if "rtk-rewrite" not in data["plugins"]["enabled"]:
    data["plugins"]["enabled"].append("rtk-rewrite")

with open(CFG, "w") as f:
    yaml.dump(data, f, default_flow_style=False)

print("rtk-rewrite enabled")
