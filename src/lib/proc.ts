import { STDERR, print } from "./colors.ts";

type RunOptions = { cwd?: string; quietErrors?: boolean };

// Spawns asynchronously, even though every caller awaits it: a blocked event loop
// would keep signal handlers and the sudo keepalive timer from ever running.
export async function run(cmd: string[], { cwd, quietErrors = false }: RunOptions = {}) {
  try {
    const proc = Bun.spawn(cmd, {
      cwd,
      stdio: ["inherit", "inherit", quietErrors ? "ignore" : "inherit"],
    });
    return (await proc.exited) === 0;
  } catch {
    if (!quietErrors) print(`dot: ${cmd[0]}: command not found`, STDERR);
    return false;
  }
}

export async function capture(cmd: string[]) {
  try {
    const proc = Bun.spawn(cmd, { stdin: "ignore", stdout: "pipe", stderr: "ignore" });
    const out = await new Response(proc.stdout).text();
    return { ok: (await proc.exited) === 0, out: out.replace(/\n+$/, "") };
  } catch {
    return { ok: false, out: "" };
  }
}

export async function succeeds(cmd: string[]) {
  return (await capture(cmd)).ok;
}

export function has(cmd: string) {
  return Bun.which(cmd) !== null;
}

export function lines(text: string) {
  return text.split("\n").filter((line) => line !== "");
}
