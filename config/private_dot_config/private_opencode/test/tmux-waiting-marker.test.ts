import { expect, test } from "bun:test"
import { join } from "node:path"

const markerScript = join(import.meta.dir, "..", "tmux-waiting-marker.sh")

async function runTmux(
  socket: string,
  arguments_: readonly string[],
): Promise<string> {
  const process = Bun.spawn(["tmux", "-L", socket, ...arguments_], {
    stdout: "pipe",
    stderr: "pipe",
  })
  const [exitCode, stdout, stderr] = await Promise.all([
    process.exited,
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
  ])
  expect(exitCode, stderr).toBe(0)
  return stdout.trim()
}

async function runTmuxBestEffort(
  socket: string,
  arguments_: readonly string[],
): Promise<void> {
  const process = Bun.spawn(["tmux", "-L", socket, ...arguments_], {
    stdout: "ignore",
    stderr: "ignore",
  })
  await process.exited
}

test("sets the window marker when OpenCode drops TMUX_PANE", async () => {
  const suffix = crypto.randomUUID()
  const socket = `omo-marker-test-${suffix}`
  const session = `marker-test-${suffix}`
  const done = `marker-done-${suffix}`
  const release = `marker-release-${suffix}`

  await runTmux(socket, ["new-session", "-d", "-s", session, "-x", "80", "-y", "24"])
  try {
    const waiter = Bun.spawn(["tmux", "-L", socket, "wait-for", done], {
      stdout: "ignore",
      stderr: "pipe",
    })
    const command = `env -u TMUX_PANE "${markerScript}" complete; tmux wait-for -S "${done}"; tmux wait-for "${release}"`
    await runTmux(socket, ["send-keys", "-t", session, "-l", command])
    await runTmux(socket, ["send-keys", "-t", session, "Enter"])
    const [waitExit, waitError] = await Promise.all([
      waiter.exited,
      new Response(waiter.stderr).text(),
    ])
    expect(waitExit, waitError).toBe(0)

    const marker = await runTmux(socket, [
      "display-message",
      "-p",
      "-t",
      session,
      "#{@opencode_waiting}",
    ])
    expect(marker).toBe("●")
  } finally {
    await runTmuxBestEffort(socket, ["wait-for", "-S", release])
    await runTmuxBestEffort(socket, ["kill-session", "-t", session])
  }
})

test("prints the originating window index and name", async () => {
  // Given
  const suffix = crypto.randomUUID()
  const socket = `omo-pane-label-test-${suffix}`
  const session = `pane-label-test-${suffix}`

  await runTmux(socket, ["new-session", "-d", "-s", session, "-x", "80", "-y", "24"])
  try {
    await runTmux(socket, ["rename-window", "-t", session, "ha"])
    const paneID = await runTmux(socket, [
      "display-message",
      "-p",
      "-t",
      session,
      "#{pane_id}",
    ])
    const windowIndex = await runTmux(socket, [
      "display-message",
      "-p",
      "-t",
      session,
      "#{window_index}",
    ])
    const tmuxEnvironment = await runTmux(socket, [
      "display-message",
      "-p",
      "-t",
      session,
      "#{socket_path},#{pid},0",
    ])

    // When
    const process = Bun.spawn([markerScript, "window_label"], {
      env: { ...Bun.env, TMUX: tmuxEnvironment, TMUX_PANE: paneID },
      stdout: "pipe",
      stderr: "pipe",
    })
    const [exitCode, label, error] = await Promise.all([
      process.exited,
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
    ])

    // Then
    expect(exitCode, error).toBe(0)
    expect(label.trim()).toBe(`${windowIndex}: ha`)
  } finally {
    await runTmuxBestEffort(socket, ["kill-session", "-t", session])
  }
})
