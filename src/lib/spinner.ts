// A spinner for silent work: commands whose output is captured, so the screen would
// otherwise sit frozen. Never wrap `run()` with it — streamed child output and sudo
// prompts share the line and would be garbled or hidden.
import { writeSync } from "node:fs";
import { C, STDERR } from "@/lib/colors.ts";

const FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const CLEAR_LINE = "\r\x1b[2K";

// Drawn on stderr, and only when it is a terminal: stdout may be captured
// (`make demo` records it) and must never contain frames.
const enabled = !!process.stderr.isTTY && process.env.TERM !== "dumb" && !process.env.CI;

// The frames tick while `task` awaits a child process, which only works because
// proc.ts spawns asynchronously.
export async function spin<T>(label: string, task: () => Promise<T>): Promise<T> {
  if (!enabled) return task();

  let frame = 0;
  const draw = () => {
    writeSync(
      STDERR,
      `${CLEAR_LINE}  ${C.blue}${FRAMES[frame++ % FRAMES.length]}${C.reset} ${C.dim}${label}${C.reset}`,
    );
  };
  draw();
  const timer = setInterval(draw, 80);
  try {
    return await task();
  } finally {
    clearInterval(timer);
    writeSync(STDERR, CLEAR_LINE);
  }
}
