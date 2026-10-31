import { expect, test } from "bun:test";
import { normalize } from "./defaults.ts";

test("normalizes booleans so `defaults read` output compares equal", () => {
  expect(normalize("true")).toBe(normalize("1"));
  expect(normalize("NO")).toBe(normalize("0"));
  expect(normalize("33")).toBe("33");
});
