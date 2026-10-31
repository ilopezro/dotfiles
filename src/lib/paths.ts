import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export const HOME = process.env.HOME ?? homedir();

// A compiled binary's modules live in Bun's virtual /$bunfs, so the repo is found
// from the executable (bin/dot) instead of from this file.
const repoRoot = import.meta.dir.startsWith("/$bunfs")
  ? resolve(dirname(realpathSync(process.execPath)), "..")
  : resolve(import.meta.dir, "../..");

export const DOTFILES_DIR = process.env.DOTFILES_DIR ?? repoRoot;

export const installFile = (name: string) => join(DOTFILES_DIR, "install", name);

export function expandHome(path: string) {
  return path.replace(/^\$HOME/, HOME).replace(/^~/, HOME);
}
