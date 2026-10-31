// Readers for the install/* manifests. Blank lines are skipped and a missing trailing
// newline never drops the last entry.
import { readFileSync } from "node:fs";

export function parseLines(text: string) {
  return text
    .split("\n")
    .map((line) => line.replace(/\r$/, ""))
    .filter((line) => line.trim() !== "");
}

export function parseFields(text: string) {
  return parseLines(text).map((line) => line.split("|"));
}

export function parseCaskfile(text: string) {
  return parseLines(text).flatMap((line) => {
    const token = line.match(/^cask "([^"]+)"/)?.[1];
    return token ? [token] : [];
  });
}

export function parseToolVersions(text: string) {
  return parseLines(text).map((line) => {
    const [name = "", version = ""] = line.trim().split(/\s+/);
    return { name, version };
  });
}

export function readText(path: string) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

export const readLines = (path: string) => parseLines(readText(path));
export const readFields = (path: string) => parseFields(readText(path));
