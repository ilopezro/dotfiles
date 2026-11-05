import { expect, test } from "bun:test";
import { appCandidates, compareVersions, installedTarget, parseArtifacts } from "@/commands/casks.ts";

const info = `==> docker-desktop (Docker Desktop, Docker CE): 4.97.0,244584 (auto_updates)
App to build and share containerised applications and microservices
==> Artifacts
Docker.app (App)
/Applications/Docker.app/Contents/Resources/bin/docker -> /usr/local/bin/docker (Binary)
/Applications/Docker.app/Contents/Resources/etc/docker.zsh-completion (Zsh Completion)
==> Analytics
install: 1 (30 days)
==> 1password (1Password): 8.12.42 (auto_updates)
==> Artifacts
1Password.app (App)
`;

test("collects App and Binary artifacts per cask", () => {
  const artifacts = parseArtifacts(info);
  expect(artifacts.get("docker-desktop")).toEqual([
    { kind: "app", value: "Docker.app" },
    { kind: "bin", value: "/Applications/Docker.app/Contents/Resources/bin/docker -> /usr/local/bin/docker" },
  ]);
  expect(artifacts.get("1password")).toEqual([{ kind: "app", value: "1Password.app" }]);
});

test("checks the target of a source -> target artifact, keeping its directory", () => {
  expect(installedTarget("/Applications/Docker.app/x/docker -> /usr/local/bin/docker")).toBe("/usr/local/bin/docker");
  expect(installedTarget("Slack.app")).toBe("Slack.app");
});

test("compares versions numerically, ignoring build ids and separators", () => {
  expect(compareVersions("26.195.1006", "26.189.0928.0009")).toBe(1);
  expect(compareVersions("4.98.0", "4.98.0,245422")).toBe(0);
  expect(compareVersions("7.2.5 (90525)", "7.2.5.90525")).toBe(0);
  expect(compareVersions("1.3", "1.3.1")).toBe(-1);
});

test("finds app bundles from App artifacts and pkg uninstall stanzas", () => {
  const cask = (artifacts: Record<string, unknown[]>[]) => ({ token: "x", version: "1", artifacts });
  expect(appCandidates(cask([{ app: ["Slack.app"] }]))[0]).toBe("/Applications/Slack.app");
  expect(appCandidates(cask([{ app: ["a.app", { target: "B.app" }] }]))[0]).toBe("/Applications/B.app");
  expect(
    appCandidates(
      cask([{ uninstall: [{ delete: ["/Applications/OneDrive.app", "/Library/Logs/x", "/Applications/*.app"] }] }]),
    ),
  ).toEqual(["/Applications/OneDrive.app"]);
});
