import { expect, test } from "bun:test";
import {
  type Branch,
  type Context,
  classify,
  findKeepfile,
  matches,
  parseKeepfile,
  parseWorktrees,
} from "@/commands/branches.ts";

const branch = (over: Partial<Branch>): Branch => ({
  name: "me/feature",
  sha: "aaa",
  upstream: "origin/me/feature",
  track: "[gone]",
  age: "3 days ago",
  ...over,
});

const context = (over: Partial<Context> = {}): Context => ({
  worktrees: new Map(),
  defaultBranch: "main",
  rules: [],
  merged: new Map(),
  ...over,
});

test("reads patterns, skipping comments and blank lines", () => {
  expect(parseKeepfile("# keep\nmain\n\n  *sandbox*  # all of them\nrelease/*")).toEqual([
    "main",
    "*sandbox*",
    "release/*",
  ]);
});

test("* crosses slashes and other characters are literal", () => {
  expect(matches("*sandbox*", "colby/x-sandbox")).toBe(true);
  expect(matches("release/*", "release/1.2/hotfix")).toBe(true);
  expect(matches("main", "maintenance")).toBe(false);
  expect(matches("v1.0", "v1x0")).toBe(false);
  expect(matches("ah-?", "ah-1")).toBe(true);
});

test("uses the nearest .branchkeep below home and never home's own", () => {
  const files = new Set(["/h/.branchkeep", "/h/p/.branchkeep", "/h/p/team/tool/.branchkeep"]);
  const exists = (path: string) => files.has(path);
  expect(findKeepfile("/h/p/team/api", "/h", exists)).toBe("/h/p/.branchkeep");
  expect(findKeepfile("/h/p/team/tool", "/h", exists)).toBe("/h/p/team/tool/.branchkeep");
  expect(findKeepfile("/h/other", "/h", exists)).toBeNull();
  expect(findKeepfile("/tmp/repo", "/h", exists)).toBeNull();
});

test("maps branches to live worktrees, ignoring prunable and detached ones", () => {
  const porcelain = [
    "worktree /repo\nHEAD 111\nbranch refs/heads/main",
    "worktree /tmp/dead\nHEAD 222\nbranch refs/heads/me/dead\nprunable gitdir file points to non-existent location",
    "worktree /repo-x\nHEAD 333\ndetached",
    "worktree /repo-y\nHEAD 444\nbranch refs/heads/me/y",
  ].join("\n\n");
  expect([...parseWorktrees(porcelain)]).toEqual([
    ["main", "/repo"],
    ["me/y", "/repo-y"],
  ]);
});

test("keeps worktree, default, and pattern-matched branches", () => {
  const merged = new Map([["me/feature", [{ number: 7, headRefOid: "aaa" }]]]);
  expect(classify(branch({}), context({ merged, worktrees: new Map([["me/feature", "/wt"]]) })).kind).toBe("keep");
  expect(classify(branch({ name: "main" }), context()).reason).toBe("default branch");
  const rules = [{ pattern: "*sandbox*", source: "~/p/.branchkeep" }];
  expect(classify(branch({ name: "ah-sandbox" }), context({ rules }))).toMatchObject({
    kind: "keep",
    reason: "~/p/.branchkeep: *sandbox*",
  });
});

test("only a merged PR at the same commit is safe", () => {
  const merged = new Map([["me/feature", [{ number: 7, headRefOid: "aaa" }]]]);
  expect(classify(branch({}), context({ merged }))).toMatchObject({ kind: "safe", reason: "PR #7 merged" });
  expect(classify(branch({ sha: "bbb" }), context({ merged })).kind).toBe("ask");
  expect(classify(branch({}), context()).reason).toStartWith("upstream gone");
  expect(classify(branch({ upstream: "", track: "" }), context()).reason).toStartWith("never pushed");
  expect(classify(branch({ upstream: "origin/x", track: "[behind 3]" }), context()).reason).toStartWith(
    "tracks origin/x [behind 3]",
  );
});
