// Mirrors lib/colors.sh so dot output matches the Makefile's. Uses the 16 ANSI colors
// so the terminal theme (Catppuccin via Ghostty) decides the actual shades and follows
// light/dark switches. Color is off when stdout is not a terminal or NO_COLOR is set;
// CLICOLOR_FORCE=1 keeps it on for captured output (`make demo` records it for the
// README GIF).
import { writeSync } from "node:fs";

export const colorEnabled =
  !process.env.NO_COLOR && (!!process.env.CLICOLOR_FORCE || (!!process.stdout.isTTY && process.env.TERM !== "dumb"));

const sgr = (code: string) => (colorEnabled ? `\x1b[${code}m` : "");

export const C = {
  reset: sgr("0"),
  bold: sgr("1"),
  dim: sgr("2"),
  red: sgr("31"),
  green: sgr("32"),
  yellow: sgr("33"),
  blue: sgr("34"),
};

// Written synchronously so lines never land out of order with the output of child
// processes that share the terminal.
export const STDOUT = 1;
export const STDERR = 2;

export function print(text = "", fd = STDOUT) {
  writeSync(fd, `${text}\n`);
}

const helper =
  (format: (msg: string) => string) =>
  (msg: string, fd = STDOUT) =>
    print(format(msg), fd);

export const pass = helper((m) => `  ${C.green}✓${C.reset} ${m}`);
export const fail = helper((m) => `  ${C.red}✗${C.reset} ${m}`);
export const warn = helper((m) => `  ${C.yellow}!${C.reset} ${m}`);
export const info = helper((m) => `  ${C.blue}›${C.reset} ${m}`);
export const note = helper((m) => `  ${C.dim}${m}${C.reset}`);
export const section = helper((m) => `${C.bold}${m}${C.reset}`);
export const step = helper((m) => `${C.blue}==>${C.reset} ${C.bold}${m}${C.reset}`);
export const success = helper((m) => `${C.green}${m}${C.reset}`);
export const error = helper((m) => `${C.red}${m}${C.reset}`);
