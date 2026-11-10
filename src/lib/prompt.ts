import { C } from "@/lib/colors.ts";

export function confirm(question: string) {
  const answer = prompt(`${C.bold}${question}${C.reset} [y/N]`) ?? "";
  return /^(y|yes)$/i.test(answer.trim());
}
