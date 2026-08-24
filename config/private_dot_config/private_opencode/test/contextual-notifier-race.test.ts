import { describe, expect, test } from "bun:test"

import type { NotificationContent } from "../lib/contextual-notifier"
import {
  createNotifierEventHandler,
  type MarkerEvent,
  type NotifierRuntime,
  type SessionSnapshot,
} from "../lib/contextual-notifier-runtime"

type Deferred<T> = {
  readonly promise: Promise<T>
  readonly resolve: (value: T) => void
}

function deferred<T>(): Deferred<T> {
  let resolver: ((value: T) => void) | undefined
  const promise = new Promise<T>((resolve) => {
    resolver = resolve
  })
  return {
    promise,
    resolve: (value) => {
      if (!resolver) throw new Error("deferred resolver was not initialized")
      resolver(value)
    },
  }
}

function runtimeHarness(overrides: Partial<NotifierRuntime> = {}) {
  const markers: MarkerEvent[] = []
  const notifications: NotificationContent[] = []
  const runtime = {
    projectName: "opencode",
    readBackground: async () => "idle" as const,
    readMessages: async () => ({}),
    readSession: async () => ({ title: "Main session" }),
    readTodos: async () => [],
    mark: async (event: MarkerEvent) => {
      markers.push(event)
    },
    notify: async (content: NotificationContent) => {
      notifications.push(content)
    },
    ...overrides,
  } satisfies NotifierRuntime
  return { markers, notifications, runtime }
}

const idle = {
  type: "session.idle",
  properties: { sessionID: "main" },
}
const userMessage = {
  type: "message.updated",
  properties: { info: { id: "user-1", role: "user", sessionID: "main" } },
}

describe("concurrent notifier events", () => {
  test("reserves a session before async idle checks can duplicate completion", async () => {
    const gate = deferred<SessionSnapshot | undefined>()
    const harness = runtimeHarness({ readSession: async () => gate.promise })
    const handle = createNotifierEventHandler(harness.runtime)

    const first = handle(idle)
    const second = handle(idle)
    gate.resolve({ title: "Main session" })
    await Promise.all([first, second])

    expect(harness.markers).toEqual(["complete"])
    expect(harness.notifications).toHaveLength(1)
  })

  test("cancels a pending completion when user activity supersedes it", async () => {
    const gate = deferred<SessionSnapshot | undefined>()
    let reads = 0
    const harness = runtimeHarness({
      readSession: async () => {
        reads += 1
        return reads === 1 ? gate.promise : { title: "Main session" }
      },
    })
    const handle = createNotifierEventHandler(harness.runtime)

    const pendingIdle = handle(idle)
    await handle(userMessage)
    gate.resolve({ title: "Main session" })
    await pendingIdle

    expect(harness.markers).toEqual(["user_message"])
    expect(harness.notifications).toEqual([])
  })

  test("allows a newer turn to complete while an older idle check is still pending", async () => {
    const gate = deferred<SessionSnapshot | undefined>()
    let reads = 0
    const harness = runtimeHarness({
      readSession: async () => {
        reads += 1
        return reads === 1 ? gate.promise : { title: "Main session" }
      },
    })
    const handle = createNotifierEventHandler(harness.runtime)

    const staleIdle = handle(idle)
    await handle(userMessage)
    const currentIdle = handle(idle)
    gate.resolve({ title: "Main session" })
    await Promise.all([staleIdle, currentIdle])

    expect(harness.markers).toEqual(["user_message", "complete"])
    expect(harness.notifications).toHaveLength(1)
  })

  test("ignores trailing updates for the user message that already completed", async () => {
    const harness = runtimeHarness()
    const handle = createNotifierEventHandler(harness.runtime)
    const repeatedUserMessage = {
      type: "message.updated",
      properties: {
        info: { id: "message-1", role: "user", sessionID: "main" },
      },
    }

    await handle(repeatedUserMessage)
    await handle(idle)
    await handle(repeatedUserMessage)
    await handle(idle)

    expect(harness.markers).toEqual(["user_message", "complete"])
    expect(harness.notifications).toHaveLength(1)
  })

  test("does not commit stale completion state after delivery settles", async () => {
    const deliveryStarted = deferred<void>()
    const deliverySettled = deferred<void>()
    let deliveries = 0
    const harness = runtimeHarness({
      notify: async (content) => {
        deliveries += 1
        if (deliveries === 1) {
          deliveryStarted.resolve()
          await deliverySettled.promise
        }
        harness.notifications.push(content)
      },
    })
    const handle = createNotifierEventHandler(harness.runtime)

    const staleIdle = handle(idle)
    await deliveryStarted.promise
    await handle(userMessage)
    deliverySettled.resolve()
    await staleIdle
    await handle(idle)

    expect(harness.markers).toEqual([
      "complete",
      "user_message",
      "complete",
    ])
    expect(harness.notifications).toHaveLength(2)
  })

  test("cancels a pending question when its reply arrives", async () => {
    const gate = deferred<SessionSnapshot | undefined>()
    let reads = 0
    const harness = runtimeHarness({
      readSession: async () => {
        reads += 1
        return reads === 1 ? gate.promise : { title: "Main session" }
      },
    })
    const handle = createNotifierEventHandler(harness.runtime)

    const pendingQuestion = handle({
      type: "question.asked",
      properties: { sessionID: "main" },
    })
    await handle({
      type: "question.replied",
      properties: { sessionID: "main", requestID: "question-1" },
    })
    gate.resolve({ title: "Main session" })
    await pendingQuestion

    expect(harness.markers).toEqual(["user_message"])
    expect(harness.notifications).toEqual([])
  })

  test("does not clear a parent marker for child user activity", async () => {
    const harness = runtimeHarness({
      readSession: async () => ({ parentID: "main", title: "Child" }),
    })

    await createNotifierEventHandler(harness.runtime)({
      type: "message.updated",
      properties: {
        info: { id: "child-message", role: "user", sessionID: "child" },
      },
    })

    expect(harness.markers).toEqual([])
  })

  test("child creation preserves the parent's completion reservation and marker", async () => {
    const harness = runtimeHarness()
    const handle = createNotifierEventHandler(harness.runtime)

    await handle(idle)
    await handle({
      type: "session.created",
      properties: { info: { id: "child", parentID: "main" } },
    })
    await handle(idle)

    expect(harness.markers).toEqual(["complete"])
    expect(harness.notifications).toHaveLength(1)
  })
})
