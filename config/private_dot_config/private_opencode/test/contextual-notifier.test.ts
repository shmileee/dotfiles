import { describe, expect, test } from "bun:test"

import {
  buildNotificationContent,
  decideCompletionNotification,
  type CompletionReadiness,
  type NotificationContext,
} from "../lib/contextual-notifier"

const ready = {
  background: "idle",
  session: "top-level",
  superseded: false,
  todos: "complete",
} satisfies CompletionReadiness

describe("decideCompletionNotification", () => {
  test("notifies when a top-level session is genuinely ready for input", () => {
    expect(decideCompletionNotification(ready)).toEqual({ kind: "notify" })
  })

  test("does not announce completion while OmO background work is active", () => {
    expect(
      decideCompletionNotification({ ...ready, background: "active" }),
    ).toEqual({ kind: "skip", reason: "active_background_work" })
  })

  test("does not announce a child session completion", () => {
    expect(
      decideCompletionNotification({ ...ready, session: "child" }),
    ).toEqual({ kind: "skip", reason: "child_session" })
  })

  test("fails closed when session parentage cannot be established", () => {
    expect(
      decideCompletionNotification({ ...ready, session: "unknown" }),
    ).toEqual({ kind: "skip", reason: "unknown_state" })
  })

  test("does not announce completion while session todos remain", () => {
    expect(
      decideCompletionNotification({ ...ready, todos: "incomplete" }),
    ).toEqual({ kind: "skip", reason: "incomplete_todos" })
  })

  test("fails closed when background or todo state cannot be read", () => {
    expect(
      decideCompletionNotification({ ...ready, background: "unknown" }),
    ).toEqual({ kind: "skip", reason: "unknown_state" })
    expect(
      decideCompletionNotification({ ...ready, todos: "unknown" }),
    ).toEqual({ kind: "skip", reason: "unknown_state" })
  })

  test("does not announce an idle event superseded by new activity", () => {
    expect(
      decideCompletionNotification({ ...ready, superseded: true }),
    ).toEqual({ kind: "skip", reason: "superseded" })
  })
})

describe("buildNotificationContent", () => {
  test("includes the project, session, prompt, and assistant result for completion", () => {
    const context = {
      event: "complete",
      projectName: "opencode",
      sessionTitle: "Fix duplicate notifications",
      lastUserText: "Stop subagents from triggering alerts",
      lastAssistantText: "The local notifier now filters child sessions.",
    } satisfies NotificationContext

    const content = buildNotificationContent(context)

    expect(content.title).toBe("OpenCode · opencode")
    expect(content.subtitle).toBe("Fix duplicate notifications")
    expect(content.body).toContain("Ready for input")
    expect(content.body).toContain("Stop subagents from triggering alerts")
    expect(content.body).toContain(
      "The local notifier now filters child sessions.",
    )
  })

  test("identifies the actionable event and retains error context", () => {
    const content = buildNotificationContent({
      event: "error",
      projectName: "opencode",
      sessionTitle: "Run migration",
      lastUserText: "Apply the schema update",
      errorText: "Database connection refused",
    })

    expect(content.title).toBe("OpenCode · opencode")
    expect(content.subtitle).toBe("Run migration")
    expect(content.body).toContain("Error")
    expect(content.body).toContain("Database connection refused")
    expect(content.body).toContain("Apply the schema update")
  })

  test("truncates long untrusted message content", () => {
    const content = buildNotificationContent({
      event: "question",
      projectName: "opencode",
      sessionTitle: "A".repeat(200),
      lastUserText: "B".repeat(1_000),
      lastAssistantText: "C".repeat(1_000),
    })

    expect(content.title.length).toBeLessThanOrEqual(80)
    expect(content.subtitle.length).toBeLessThanOrEqual(100)
    expect(content.body.length).toBeLessThanOrEqual(420)
  })
})
