// Applies and verifies macOS preferences from install/Defaultsfile. Lines are
// `domain|key|type|value|restart`, where type is any `defaults write` type (bool,
// int, float, string) and restart is the app to killall when the value changed
// (`-` for none).
import { fail, info, note, pass } from "@/lib/colors.ts";
import { readFields } from "@/lib/manifest.ts";
import { installFile } from "@/lib/paths.ts";
import { capture, run } from "@/lib/proc.ts";
import { spin } from "@/lib/spinner.ts";

// `defaults read` prints booleans as 1/0, so both sides are normalized before
// comparing — otherwise `true` never equals `1` and apply re-writes every run.
export function normalize(value: string) {
  if (value === "true" || value === "YES") return "1";
  if (value === "false" || value === "NO") return "0";
  return value;
}

async function entries() {
  return spin("Reading macOS defaults", readEntries);
}

async function readEntries() {
  const result = [];
  for (const [domain = "", key = "", type = "", value = "", restart = "-"] of readFields(installFile("Defaultsfile"))) {
    const current = (await capture(["defaults", "read", domain, key])).out;
    result.push({ domain, key, type, value, restart, current, matches: normalize(current) === normalize(value) });
  }
  return result;
}

export async function check() {
  let ok = true;
  for (const { domain, key, value, current, matches } of await entries()) {
    if (matches) {
      pass(`${domain} ${key} = ${value}`);
    } else {
      fail(`${domain} ${key} (want ${value}, have ${current || "unset"})`);
      ok = false;
    }
  }
  return ok;
}

export async function apply() {
  const restarts = new Set<string>();
  for (const { domain, key, type, value, restart, matches } of await entries()) {
    if (matches) {
      note(`Already set: ${domain} ${key} = ${value}`);
      continue;
    }
    info(`Setting ${domain} ${key} = ${value}`);
    if (!(await run(["defaults", "write", domain, key, `-${type}`, value]))) return false;
    restarts.add(restart);
  }
  for (const app of restarts) {
    if (app === "-") continue;
    info(`Restarting ${app}`);
    await run(["killall", app], { quietErrors: true });
  }
  return true;
}
