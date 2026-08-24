import { describe, expect, test } from "bun:test"
import { $ } from "bun"
import { homedir } from "node:os"
import { join } from "node:path"

import { createOpencodeClient } from "@opencode-ai/sdk"
import type { PluginInput } from "@opencode-ai/plugin"
import { z } from "zod"

import { ContextualNotifier } from "../plugin/contextual-notifier"

type Shell = PluginInput["$"]
type ShellExpression = Parameters<Shell>[1]
type Invocation = {
  readonly strings: TemplateStringsArray
  readonly expressions: readonly ShellExpression[]
}

const responseHeaders = { "Content-Type": "application/json" } as const

function createClient(): ReturnType<typeof createOpencodeClient> {
  return createOpencodeClient({
    baseUrl: "http://notifier.test",
    fetch: async (request) => {
      const path = new URL(request.url).pathname
      if (path.endsWith("/todo")) {
        return new Response(JSON.stringify([{ status: "completed" }]), {
          headers: responseHeaders,
        })
      }
      if (path.endsWith("/message")) {
        return new Response(
          JSON.stringify([
            {
              info: { role: "user" },
              parts: [{ type: "text", text: "hi" }],
            },
            {
              info: { role: "assistant" },
              parts: [{ type: "text", text: "Hello" }],
            },
          ]),
          { headers: responseHeaders },
        )
      }
      return new Response(JSON.stringify({ title: "Sound adapter" }), {
        headers: responseHeaders,
      })
    },
  })
}

function createShell(invocations: Invocation[], paneLabel = ""): Shell {
  return Object.assign(
    (strings: TemplateStringsArray, ...expressions: ShellExpression[]) => {
      invocations.push({ strings, expressions })
      if (strings.some((part) => part.includes(" window_label"))) {
        return $`printf %s ${paneLabel}`
      }
      return $`true`
    },
    {
      braces: $.braces,
      escape: $.escape,
      env: $.env,
      cwd: $.cwd,
      nothrow: $.nothrow,
      throws: $.throws,
    },
  )
}

describe("ContextualNotifier adapters", () => {
  test("requests the configured macOS sound with one notification", async () => {
    const invocations: Invocation[] = []
    const hooks = await ContextualNotifier({
      client: createClient(),
      project: {
        id: "global",
        worktree: "/tmp",
        time: { created: 0 },
      },
      directory: "/tmp",
      worktree: "/tmp",
      experimental_workspace: { register: () => {} },
      serverUrl: new URL("http://notifier.test"),
      $: createShell(invocations),
    })

    await hooks.event?.({
      event: { type: "session.idle", properties: { sessionID: "main" } },
    })

    const notification = invocations.find(
      (invocation) => invocation.strings[0] === "osascript -e ",
    )
    expect(notification).toBeDefined()
    if (!notification) return
    expect(notification.expressions).toContain(
      "display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)",
    )
    expect(notification.expressions).toContain("Submarine")
    expect(notification.expressions).toContain("Sound adapter")
  })

  test("includes the originating tmux window label in the notification subtitle", async () => {
    // Given
    const invocations: Invocation[] = []
    const hooks = await ContextualNotifier({
      client: createClient(),
      project: {
        id: "global",
        worktree: "/tmp",
        time: { created: 0 },
      },
      directory: "/tmp",
      worktree: "/tmp",
      experimental_workspace: { register: () => {} },
      serverUrl: new URL("http://notifier.test"),
      $: createShell(invocations, "5: ha"),
    })

    // When
    await hooks.event?.({
      event: { type: "session.idle", properties: { sessionID: "main" } },
    })

    // Then
    const notification = invocations.find(
      (invocation) => invocation.strings[0] === "osascript -e ",
    )
    expect(notification).toBeDefined()
    if (!notification) return
    expect(notification.expressions).toContain("5: ha · Sound adapter")
  })

  test("disables the bundled notification hook when the contextual notifier is active", async () => {
    const raw = await Bun.file(
      join(homedir(), ".omo", "omo.jsonc"),
    ).text()
    const config = z
      .object({
        "[opencode]": z.object({
          disabled_hooks: z.array(z.string()).default([]),
        }),
      })
      .parse(Bun.JSONC.parse(raw))["[opencode]"]

    expect(config.disabled_hooks).toContain("session-notification")
  })
})
