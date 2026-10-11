#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "egg-andline.json")
data = json.loads(path.read_text(encoding="utf-8"))

errors = []
def need(cond, msg):
    if not cond:
        errors.append(msg)

need(data.get("meta", {}).get("version") == "PTDL_v2", "meta.version must be PTDL_v2")
need(isinstance(data.get("name"), str) and data["name"], "name is required")
need(isinstance(data.get("author"), str) and re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", data["author"]) is not None, "author must be an email")
need(isinstance(data.get("docker_images"), dict) and len(data["docker_images"]) > 0, "docker_images must be a non-empty object")
need(isinstance(data.get("startup"), str), "startup must be a string")
need(data.get("file_denylist") is None or isinstance(data.get("file_denylist"), list), "file_denylist must be null or an array")

config = data.get("config")
need(isinstance(config, dict), "config must be an object")
if isinstance(config, dict):
    for key in ("files", "startup", "logs"):
        value = config.get(key)
        need(isinstance(value, str), f"config.{key} must be a JSON string")
        if isinstance(value, str):
            try:
                json.loads(value)
            except Exception as exc:
                errors.append(f"config.{key} is not valid JSON: {exc}")
    need(config.get("stop") is None or isinstance(config.get("stop"), str), "config.stop must be null or string")

install = data.get("scripts", {}).get("installation", {})
for key in ("script", "container", "entrypoint"):
    need(isinstance(install.get(key), str), f"scripts.installation.{key} must be a string")

reserved = {
    "SERVER_MEMORY","SERVER_IP","SERVER_PORT","ENV","HOME","USER","STARTUP","SERVER_UUID","UUID"
}
seen = set()
for i, variable in enumerate(data.get("variables") or []):
    prefix = f"variables[{i}]"
    for key in ("name","description","env_variable","default_value","rules","field_type"):
        need(isinstance(variable.get(key), str), f"{prefix}.{key} must be a string")
    env = variable.get("env_variable", "")
    need(re.fullmatch(r"\w{1,191}", env) is not None, f"{prefix}.env_variable is invalid")
    need(env not in reserved, f"{prefix}.env_variable uses a Pterodactyl reserved name")
    need(env not in seen, f"{prefix}.env_variable is duplicated")
    seen.add(env)
    need(isinstance(variable.get("user_viewable"), bool), f"{prefix}.user_viewable must be boolean")
    need(isinstance(variable.get("user_editable"), bool), f"{prefix}.user_editable must be boolean")

# ANDLINE runtime contract: only one public Socket.IO path, one private
# Engine.IO path, and no obsolete aliases exported from the panel.
required = {
    "ANDLINE_AGENT_ENABLED", "ANDLINE_AGENT_GATEWAY_PORT",
    "ANDLINE_AGENT_GATEWAY_SECRET", "ANDLINE_AGENT_GATEWAY_PATH",
    "ANDLINE_AGENT_PLUGIN_IO_PATH", "ANDLINE_AGENT_SITE_PATH",
    "TIMESCALE_ENABLED", "TIMESCALE_PORT",
}
need(required.issubset(seen), "missing required canonical Andline variables: " + ", ".join(sorted(required - seen)))
obsolete = {
    "WS_ENABLED", "TIMESCALE_DB_PORT",
    "ANDLINE_AGENT_ADMIN_PATH", "ANDLINE_AGENT_PLAYER_PATH",
    "ANDLINE_AGENT_ADMIN_WS_URL", "ANDLINE_AGENT_SITE_WS_URL",
    "ANDLINE_AGENT_PLAYER_WS_URL", "COMPOSER_PATH_FALLBACK",
    "ROOT_BUILD_COMMAND", "ADMIN_BUILD_COMMAND",
}
need(not obsolete.intersection(seen), "legacy aliases still present: " + ", ".join(sorted(obsolete & seen)))
need(not any(name.startswith("ANDBRIDGE_") for name in seen),
     "ANDBRIDGE_* aliases are forbidden")

if errors:
    print("Egg validation failed:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(f"Egg OK: {data['name']} ({len(data.get('variables') or [])} variables)")
