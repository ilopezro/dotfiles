// Deletes local branches that are done, without touching the ones that must stay.
// What stays comes from .branchkeep files: ~/.branchkeep (stowed from runcom/) applies
// everywhere, plus the nearest .branchkeep in the repo's directory or a parent. The
// files are globally git-ignored and never leave the machine.
import { existsSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { error, fail, info, note, pass, print, STDERR, section, success, warn } from "@/lib/colors.ts";
import { readText } from "@/lib/manifest.ts";
import { HOME } from "@/lib/paths.ts";
import { capture, has, lines, run, succeeds } from "@/lib/proc.ts";
import { confirm } from "@/lib/prompt.ts";
import { spin } from "@/lib/spinner.ts";

const KEEPFILE = ".branchkeep";

export type Rule = { pattern: string; source: string };
export type Branch = { name: string; sha: string; upstream: string; track: string; age: string };
export type MergedPr = { number: number; headRefOid: string };
export type Verdict = { branch: Branch; kind: "keep" | "safe" | "ask"; reason: string };
export type Context = {
  worktrees: Map<string, string>;
  defaultBranch: string;
  rules: Rule[];
  merged: Map<string, MergedPr[]>;
};

const tilde = (path: string) => (path.startsWith(HOME) ? `~${path.slice(HOME.length)}` : path);

export function parseKeepfile(text: string) {
  return text
    .split("\n")
    .map((line) => line.replace(/#.*/, "").trim())
    .filter((line) => line !== "");
}

// Branch names contain slashes, so unlike a path glob `*` crosses them: `*sandbox*`
// has to match `colby/x-sandbox`.
export function matches(pattern: string, branch: string) {
  const source = pattern
    .split("*")
    .map((part) => part.replace(/[.+^${}()|[\]\\]/g, "\\$&").replaceAll("?", "."))
    .join(".*");
  return new RegExp(`^${source}$`).test(branch);
}

// Nearest wins: the first .branchkeep found walking up from the repo is the only
// local one. $HOME's is the global file and is read separately.
export function findKeepfile(start: string, home: string, exists: (path: string) => boolean = existsSync) {
  for (let dir = start; dir !== home; dir = dirname(dir)) {
    const file = join(dir, KEEPFILE);
    if (exists(file)) return file;
    if (dir === dirname(dir)) break;
  }
  return null;
}

// Branch -> worktree path. A worktree whose directory is gone ("prunable") protects
// nothing: `git worktree prune` drops it before anything is deleted.
export function parseWorktrees(porcelain: string) {
  const result = new Map<string, string>();
  for (const block of porcelain.split("\n\n")) {
    const fields = block.split("\n");
    const path = fields.find((f) => f.startsWith("worktree "))?.slice("worktree ".length);
    const branch = fields.find((f) => f.startsWith("branch refs/heads/"))?.slice("branch refs/heads/".length);
    if (path && branch && !fields.some((f) => f.startsWith("prunable"))) result.set(branch, path);
  }
  return result;
}

// Only a merged PR whose head is this exact commit makes a branch safe. The repo may
// squash-merge and the upstream is usually deleted by then, so neither
// `git branch --merged` nor ahead/behind counts can prove nothing would be lost.
export function classify(branch: Branch, { worktrees, defaultBranch, rules, merged }: Context): Verdict {
  const gone = branch.track === "[gone]";
  const worktree = worktrees.get(branch.name);
  if (worktree) {
    const stale = gone ? " (upstream gone: stale worktree?)" : "";
    return { branch, kind: "keep", reason: `checked out in ${tilde(worktree)}${stale}` };
  }
  if (branch.name === defaultBranch) return { branch, kind: "keep", reason: "default branch" };
  const rule = rules.findLast((r) => matches(r.pattern, branch.name));
  if (rule) return { branch, kind: "keep", reason: `${rule.source}: ${rule.pattern}` };

  const prs = merged.get(branch.name) ?? [];
  const exact = prs.find((pr) => pr.headRefOid === branch.sha);
  if (exact) return { branch, kind: "safe", reason: `PR #${exact.number} merged` };

  const last = `last commit ${branch.age}`;
  if (prs[0]) {
    return { branch, kind: "ask", reason: `PR #${prs[0].number} merged, but this branch has other commits, ${last}` };
  }
  if (gone) return { branch, kind: "ask", reason: `upstream gone, no merged PR found, ${last}` };
  if (!branch.upstream) return { branch, kind: "ask", reason: `never pushed, ${last}` };
  return {
    branch,
    kind: "ask",
    reason: `tracks ${[branch.upstream, branch.track].filter(Boolean).join(" ")}, ${last}`,
  };
}

const git = (...args: string[]) => capture(["git", ...args]);

// Worktrees share the main checkout's rules wherever they live, so the walk starts
// from the main checkout, not the current directory.
async function repoRoot() {
  const common = await git("rev-parse", "--path-format=absolute", "--git-common-dir");
  if (!common.ok) return null;
  if (basename(common.out) === ".git") return dirname(common.out);
  return (await git("rev-parse", "--show-toplevel")).out || null;
}

function readRules(file: string): Rule[] {
  return parseKeepfile(readText(file)).map((pattern) => ({ pattern, source: tilde(file) }));
}

async function listBranches(): Promise<Branch[]> {
  const format = "%(refname:short)%09%(objectname)%09%(upstream:short)%09%(upstream:track)%09%(committerdate:relative)";
  return lines((await git("for-each-ref", `--format=${format}`, "refs/heads")).out).map((line) => {
    const [name = "", sha = "", upstream = "", track = "", age = ""] = line.split("\t");
    return { name, sha, upstream, track, age };
  });
}

async function mergedPrs(names: string[]) {
  const merged = new Map<string, MergedPr[]>();
  let failed = !has("gh");
  const queue = [...names];
  const worker = async () => {
    for (let name = queue.shift(); name && !failed; name = queue.shift()) {
      const fields = ["--json", "number,headRefOid", "--limit", "20"];
      const result = await capture(["gh", "pr", "list", "--head", name, "--state", "merged", ...fields]);
      if (result.ok) merged.set(name, JSON.parse(result.out) as MergedPr[]);
      else failed = true;
    }
  };
  await Promise.all(Array.from({ length: 8 }, worker));
  return { merged, failed };
}

async function survey(root: string) {
  const localFile = findKeepfile(root, HOME);
  const globalFile = join(HOME, KEEPFILE);
  const rules = [...(existsSync(globalFile) ? readRules(globalFile) : []), ...(localFile ? readRules(localFile) : [])];

  const fetched = await spin("Fetching remotes", () => succeeds(["git", "fetch", "--all", "--prune", "--quiet"]));
  const worktrees = parseWorktrees((await git("worktree", "list", "--porcelain")).out);
  const defaultBranch = (await git("symbolic-ref", "--short", "-q", "refs/remotes/origin/HEAD")).out.replace(
    /^origin\//,
    "",
  );
  const branches = await listBranches();

  const context: Context = { worktrees, defaultBranch, rules, merged: new Map() };
  const candidates = branches.filter((b) => classify(b, context).kind !== "keep").map((b) => b.name);
  const prs = await spin(`Looking up merged PRs for ${candidates.length} branches`, () => mergedPrs(candidates));
  context.merged = prs.merged;

  return {
    localFile,
    fetched,
    ghFailed: prs.failed && candidates.length > 0,
    verdicts: branches.map((b) => classify(b, context)),
  };
}

function report({ localFile, fetched, ghFailed, verdicts }: Awaited<ReturnType<typeof survey>>) {
  const group = (kind: Verdict["kind"]) => verdicts.filter((v) => v.kind === kind);
  const show = (title: string, list: Verdict[], line: (msg: string) => void) => {
    if (list.length === 0) return;
    section(`${title} (${list.length})`);
    for (const { branch, reason } of list) line(`${branch.name}  ${reason}`);
    print();
  };

  show("Kept", group("keep"), pass);
  show("Safe to delete", group("safe"), info);
  show("Needs a decision", group("ask"), warn);

  if (!fetched) warn("could not fetch; upstream state may be out of date");
  if (ghFailed) warn("could not ask GitHub (gh) about merged PRs, so no branch counts as safe");
  if (!localFile) {
    warn(`no ${KEEPFILE} covers this repo: only ~/${KEEPFILE} and the default branch are protected`);
    note("run `dot branches setup` to choose what stays");
  }
}

async function remove({ branch }: Verdict) {
  if (await succeeds(["git", "branch", "-D", branch.name]))
    pass(`deleted ${branch.name} (was ${branch.sha.slice(0, 10)})`);
  else fail(`could not delete ${branch.name}`);
}

// Safe branches go with one confirmation; every other branch is asked about on its
// own unless --all, since a yes there can delete commits that exist nowhere else.
export async function prune({ all, dryRun }: { all: boolean; dryRun: boolean }) {
  const root = await repoRoot();
  if (!root) {
    error("dot: not inside a git repository", STDERR);
    return false;
  }

  const result = await survey(root);
  report(result);
  const safe = result.verdicts.filter((v) => v.kind === "safe");
  const ask = result.verdicts.filter((v) => v.kind === "ask");
  if (safe.length + ask.length === 0) {
    success("Nothing to tidy.");
    return true;
  }
  if (dryRun) return true;
  if (!process.stdin.isTTY) {
    note("No terminal to confirm on; nothing was deleted.");
    return true;
  }
  if (!result.localFile && !confirm(`Continue without a ${KEEPFILE} for this repo?`)) {
    note("Nothing deleted.");
    return true;
  }

  await git("worktree", "prune");
  if (safe.length > 0 && confirm(`Delete the ${safe.length} safe branches?`)) {
    for (const verdict of safe) await remove(verdict);
  }
  if (ask.length > 0 && (!all || confirm(`Delete all ${ask.length} branches that need a decision?`))) {
    for (const verdict of ask) {
      if (all || confirm(`Delete ${verdict.branch.name}? (${verdict.reason})`)) await remove(verdict);
    }
  }
  note("Restore a deleted branch with: git branch <name> <commit>");
  return true;
}

function template(candidates: string[]) {
  return [
    '# Branches `git tidy` never deletes here. One glob per line; * also matches "/".',
    `# Applies on top of ~/${KEEPFILE}, to every repo under this directory that has no`,
    `# nearer ${KEEPFILE}. Stays on this machine: the file is globally git-ignored.`,
    "#",
    "# Uncomment what must stay:",
    ...candidates.map((name) => `# ${name}`),
    "",
  ].join("\n");
}

// The file can sit in the repo or in any parent below $HOME, so one file can cover a
// folder of related repos.
export async function setup() {
  const root = await repoRoot();
  if (!root) {
    error("dot: not inside a git repository", STDERR);
    return false;
  }
  if (!process.stdin.isTTY) {
    error("dot: setup needs a terminal", STDERR);
    return false;
  }

  const dirs = [root];
  if (root.startsWith(`${HOME}/`)) {
    for (let dir = dirname(root); dir !== HOME; dir = dirname(dir)) dirs.push(dir);
  }
  const existing = dirs.findIndex((dir) => existsSync(join(dir, KEEPFILE)));
  const preferred = Math.max(existing, 0);

  section(`Where should ${KEEPFILE} live?`);
  dirs.forEach((dir, i) => {
    const scope = i === 0 ? "this repo only" : "every repo below it";
    info(`${i + 1}) ${tilde(dir)}  ${scope}${existsSync(join(dir, KEEPFILE)) ? ", exists" : ""}`);
  });
  const answer = (prompt(`Choice [${preferred + 1}]`) ?? "").trim();
  const dir = dirs[answer === "" ? preferred : Number(answer) - 1];
  if (!dir) {
    error("dot: not one of the choices", STDERR);
    return false;
  }

  const file = join(dir, KEEPFILE);
  if (!existsSync(file)) {
    const defaultBranch = (await git("symbolic-ref", "--short", "-q", "refs/remotes/origin/HEAD")).out;
    const live = (await listBranches()).filter((b) => b.upstream && b.track !== "[gone]");
    const longLived = live.filter((b) => !b.name.includes("/") && `origin/${b.name}` !== defaultBranch);
    writeFileSync(file, template(longLived.map((b) => b.name)));
  }

  const editor = (process.env.VISUAL || process.env.EDITOR || "vi").split(/\s+/);
  if (!(await run([...editor, file]))) return false;
  pass(`${tilde(file)} saved`);
  note("run `git tidy -n` (or `gtd -n`) to preview what it keeps");
  return true;
}
