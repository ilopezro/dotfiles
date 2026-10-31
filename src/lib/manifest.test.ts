import { expect, test } from "bun:test";
import { parseCaskfile, parseFields, parseLines, parseToolVersions } from "@/lib/manifest.ts";

test("keeps the last entry without a trailing newline and skips blank lines", () => {
  expect(parseLines("a\n\nb\r\n  \nc")).toEqual(["a", "b", "c"]);
});

test("splits pipe-delimited manifests", () => {
  expect(parseFields("com.apple.dock|autohide|bool|true|Dock\n")).toEqual([
    ["com.apple.dock", "autohide", "bool", "true", "Dock"],
  ]);
});

test("reads cask tokens, ignoring options and comments", () => {
  expect(parseCaskfile('cask "1password"\n# cask "nope"\ncask "foo", args: { "x" => 1 }\n')).toEqual(["1password", "foo"]);
});

test("reads .tool-versions", () => {
  expect(parseToolVersions("nodejs 24.13.0\npython  3.14.3")).toEqual([
    { name: "nodejs", version: "24.13.0" },
    { name: "python", version: "3.14.3" },
  ]);
});
