import { describe, expect, test } from "bun:test"

import type { NotificationContent } from "../lib/contextual-notifier"
import {
  createNotifierEventHandler,
  type MarkerEvent,
  type NotifierRuntime,
} from "../lib/contextual-notifier-runtime"

type Harness = {
  readonly events: MarkerEvent[]
  readonly notifications: NotificationContent[]
  readonly runtime: NotifierRuntime
}

function createHarness(
  overrides: Partial<NotifierRuntime> = {},
): Harness {
  const events: MarkerEvent[] = []
  const notifications: NotificationContent[] = []
  const runtime = {
    projectName: "opencode",
    readBackground: async () => "idle" as const,
    readMessages: async () => ({
      lastUserText: "Fix duplicate notifications",
      lastAssistantText: "The notifier is ready.",
    }),
    readSession: async () => ({ title: "Contextual notifier" }),
    readTodos: async () => [{ status: "completed" }],
    mark: async (event: MarkerEvent) => {
      events.push(event)
    },
    notify: async (content: NotificationContent) => {
      notifications.push(content)
    },
    ...overrides,
  } satisfies NotifierRuntime

  return { events, notifications, runtime }
}

const idleEvent = {
  type: "session.idle",
  properties: { sessionID: "main" },
}

describe("createNotifierEventHandler", () => {
  test("delivers one contextual completion for a ready top-level session", async () => {
    const harness = createHarness()
    const handle = createNotifierEventHandler(harness.runtime)

    await handle(idleEvent)

    expect(harness.events).toEqual(["complete"])
    expect(harness.notifications).toHaveLength(1)
    expect(harness.notifications[0]?.title).toBe("OpenCode · opencode")
    expect(harness.notifications[0]?.subtitle).toBe("Contextual notifier")
    expect(harness.notifications[0]?.body).toContain(
      "Fix duplicate notifications",
    )
  })

  test("deduplicates repeated idle events until the user sends another message", async () => {
    const harness = createHarness()
    const handle = createNotifierEventHandler(harness.runtime)

    await handle(idleEvent)
    await handle(idleEvent)
    await handle({
      type: "message.updated",
      properties: {
        info: { id: "message-1", role: "user", sessionID: "main" },
      },
    })
    await handle(idleEvent)

    expect(harness.events).toEqual([
      "complete",
      "user_message",
      "complete",
    ])
    expect(harness.notifications).toHaveLength(2)
  })

  test("suppresses parent idle while OmO continuation work is active", async () => {
    const harness = createHarness({
      readBackground: async () => "active",
    })

    await createNotifierEventHandler(harness.runtime)(idleEvent)

    expect(harness.events).toEqual([])
    expect(harness.notifications).toEqual([])
  })

  test("suppresses child idle and fails closed on lookup failure", async () => {
    const child = createHarness({
      readSession: async () => ({ parentID: "main", title: "Explore" }),
    })
    const failed = createHarness({
      readSession: async () => {
        throw new Error("session unavailable")
      },
    })

    await createNotifierEventHandler(child.runtime)(idleEvent)
    await createNotifierEventHandler(failed.runtime)(idleEvent)

    expect(child.notifications).toEqual([])
    expect(failed.notifications).toEqual([])
  })

  test("suppresses completion while session todos remain incomplete", async () => {
    const harness = createHarness({
      readTodos: async () => [{ status: "in_progress" }],
    })

    await createNotifierEventHandler(harness.runtime)(idleEvent)

    expect(harness.events).toEqual([])
    expect(harness.notifications).toEqual([])
  })

  test("delivers an actionable top-level question with session context", async () => {
    const harness = createHarness()
    const event = {
      type: "question.asked",
      properties: {
        id: "question-1",
        sessionID: "main",
        questions: [],
      },
    }

    await createNotifierEventHandler(harness.runtime)(event)

    expect(harness.events).toEqual(["question"])
    expect(harness.notifications[0]?.body).toContain("Question waiting")
    expect(harness.notifications[0]?.body).toContain(
      "Fix duplicate notifications",
    )
  })

  test("maps plan-exit permission requests separately", async () => {
    const harness = createHarness()
    const event = {
      type: "permission.asked",
      properties: {
        id: "permission-1",
        sessionID: "main",
        permission: "plan_exit",
      },
    }

    await createNotifierEventHandler(harness.runtime)(event)

    expect(harness.events).toEqual(["plan_exit"])
    expect(harness.notifications[0]?.body).toContain("Plan ready for review")
  })

  test("clears the marker with the script's user-message event", async () => {
    const harness = createHarness()
    const handle = createNotifierEventHandler(harness.runtime)

    await handle({
      type: "message.updated",
      properties: {
        info: { id: "message-2", role: "user", sessionID: "main" },
      },
    })

    expect(harness.events).toEqual(["user_message"])
    expect(harness.notifications).toEqual([])
  })

  test("clears the marker when a new session starts", async () => {
    const harness = createHarness()

    await createNotifierEventHandler(harness.runtime)({
      type: "session.created",
      properties: { info: { id: "new-session" } },
    })

    expect(harness.events).toEqual(["session_started"])
    expect(harness.notifications).toEqual([])
  })

  test("delivers real errors but ignores user-aborted sessions", async () => {
    const harness = createHarness()
    const handle = createNotifierEventHandler(harness.runtime)

    await handle({
      type: "session.error",
      properties: {
        sessionID: "main",
        error: { name: "APIError", data: { message: "Connection refused" } },
      },
    })
    await handle({
      type: "session.error",
      properties: {
        sessionID: "main",
        error: { name: "MessageAbortedError", data: {} },
      },
    })

    expect(harness.events).toEqual(["error"])
    expect(harness.notifications).toHaveLength(1)
    expect(harness.notifications[0]?.body).toContain("Connection refused")
  })
})
