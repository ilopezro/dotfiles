import { expect, test } from "bun:test";
import { installedTarget, parseArtifacts } from "@/commands/casks.ts";

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
