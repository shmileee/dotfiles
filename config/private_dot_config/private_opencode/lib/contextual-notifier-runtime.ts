import { z } from "zod"

import {
  buildNotificationContent,
  decideCompletionNotification,
  type NotificationContent,
  type NotificationKind,
} from "./contextual-notifier"

export type SessionSnapshot = {
  readonly parentID?: string | undefined
  readonly title: string
}

export type MessageSnapshot = {
  readonly lastAssistantText?: string | undefined
  readonly lastUserText?: string | undefined
}

export type TodoSnapshot = {
  readonly status: string
}
export type MarkerEvent = NotificationKind | "session_started" | "user_message"

export type NotifierRuntime = {
  readonly projectName: string
  readonly readBackground: (sessionID: string) => Promise<"active" | "idle" | "unknown">
  readonly readMessages: (sessionID: string) => Promise<MessageSnapshot | undefined>
  readonly readSession: (sessionID: string) => Promise<SessionSnapshot | undefined>
  readonly readTodos: (sessionID: string) => Promise<readonly TodoSnapshot[] | undefined>
  readonly mark: (event: MarkerEvent) => Promise<void>
  readonly notify: (content: NotificationContent) => Promise<void>
}

const eventSchema = z.object({ type: z.string(), properties: z.unknown() })

const sessionPropertiesSchema = z.object({ sessionID: z.string() })
const sessionCreatedPropertiesSchema = z.object({ info: z.object({ id: z.string(), parentID: z.string().optional() }) })
const messagePropertiesSchema = z.object({
  info: z.object({ id: z.string(), role: z.string(), sessionID: z.string() }),
})
const permissionPropertiesSchema = z.object({
  sessionID: z.string(),
  permission: z.string().optional(),
  title: z.string().optional(),
  type: z.string().optional(),
})
const errorPropertiesSchema = z.object({
  sessionID: z.string().optional(),
  error: z
    .object({
      name: z.string(),
      data: z.object({ message: z.string().optional() }).passthrough().optional(),
    })
    .optional(),
})

async function deliverAction(
  runtime: NotifierRuntime,
  event: NotificationKind,
  sessionID: string,
  isCurrent: () => boolean,
  errorText?: string,
): Promise<boolean> {
  const session = await runtime.readSession(sessionID).catch(() => undefined)
  if (!session || session.parentID || !isCurrent()) return false

  const messages = await runtime.readMessages(sessionID).catch(() => undefined)
  if (!isCurrent()) return false
  const content = buildNotificationContent({
    event,
    projectName: runtime.projectName,
    sessionTitle: session.title,
    lastUserText: messages?.lastUserText,
    lastAssistantText: messages?.lastAssistantText,
    errorText,
  })

  await Promise.allSettled([runtime.mark(event), runtime.notify(content)])
  return true
}

async function handleCompletion(
  runtime: NotifierRuntime,
  sessionID: string,
  isCurrent: () => boolean,
): Promise<boolean> {
  const [session, background, todos] = await Promise.all([
    runtime.readSession(sessionID).catch(() => undefined),
    runtime.readBackground(sessionID).catch(() => "unknown" as const),
    runtime.readTodos(sessionID).catch(() => undefined),
  ])
  const sessionState = session
    ? session.parentID
      ? ("child" as const)
      : ("top-level" as const)
    : ("unknown" as const)
  const todosState = todos
    ? todos.some(
        (todo) => todo.status !== "completed" && todo.status !== "cancelled",
      )
      ? ("incomplete" as const)
      : ("complete" as const)
    : ("unknown" as const)
  const decision = decideCompletionNotification({
    background,
    session: sessionState,
    superseded: !isCurrent(),
    todos: todosState,
  })

  if (decision.kind === "skip" || !session) return false

  const messages = await runtime.readMessages(sessionID).catch(() => undefined)
  if (!isCurrent()) return false
  const content = buildNotificationContent({
    event: "complete",
    projectName: runtime.projectName,
    sessionTitle: session.title,
    lastUserText: messages?.lastUserText,
    lastAssistantText: messages?.lastAssistantText,
  })
  await Promise.allSettled([runtime.mark("complete"), runtime.notify(content)])
  return true
}

function permissionKind(properties: z.infer<typeof permissionPropertiesSchema>): "permission" | "plan_exit" {
  const name = [properties.permission, properties.type, properties.title]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase()
  return name.includes("plan") ? "plan_exit" : "permission"
}

async function markTopLevel(runtime: NotifierRuntime, sessionID: string, event: "user_message"): Promise<void> {
  const session = await runtime.readSession(sessionID).catch(() => undefined)
  if (!session || session.parentID) return
  await runtime.mark(event).catch(() => undefined)
}

export function createNotifierEventHandler(
  runtime: NotifierRuntime,
): (event: unknown) => Promise<void> {
  const completedSessions = new Set<string>()
  const inFlightCompletions = new Map<string, number>()
  const latestUserMessageIDs = new Map<string, string>()
  const revisions = new Map<string, number>()
  const revision = (sessionID: string): number => revisions.get(sessionID) ?? 0
  const supersede = (sessionID: string): void => {
    revisions.set(sessionID, revision(sessionID) + 1)
    completedSessions.delete(sessionID)
  }

  return async (rawEvent: unknown): Promise<void> => {
    const parsedEvent = eventSchema.safeParse(rawEvent)
    if (!parsedEvent.success) return
    const { type, properties } = parsedEvent.data

    if (type === "session.created") {
      const parsed = sessionCreatedPropertiesSchema.safeParse(properties)
      if (!parsed.success) return
      supersede(parsed.data.info.id)
      if (!parsed.data.info.parentID) {
        await runtime.mark("session_started").catch(() => undefined)
      }
      return
    }

    if (type === "message.updated") {
      const parsed = messagePropertiesSchema.safeParse(properties)
      if (!parsed.success || parsed.data.info.role !== "user") return
      const { id, sessionID } = parsed.data.info
      if (latestUserMessageIDs.get(sessionID) === id) return
      latestUserMessageIDs.set(sessionID, id)
      supersede(sessionID)
      await markTopLevel(runtime, sessionID, "user_message")
      return
    }

    if (
      type === "permission.replied" ||
      type === "question.replied" ||
      type === "question.rejected" ||
      type === "question.v2.replied" ||
      type === "question.v2.rejected"
    ) {
      const parsed = sessionPropertiesSchema.safeParse(properties)
      if (!parsed.success) return
      supersede(parsed.data.sessionID)
      await markTopLevel(runtime, parsed.data.sessionID, "user_message")
      return
    }

    if (type === "session.idle") {
      const parsed = sessionPropertiesSchema.safeParse(properties)
      if (!parsed.success) return
      const sessionID = parsed.data.sessionID
      const startedAt = revision(sessionID)
      if (completedSessions.has(sessionID) || inFlightCompletions.get(sessionID) === startedAt) return
      inFlightCompletions.set(sessionID, startedAt)
      try {
        if (await handleCompletion(runtime, sessionID, () => revision(sessionID) === startedAt) && revision(sessionID) === startedAt) {
          completedSessions.add(sessionID)
        }
      } finally {
        if (inFlightCompletions.get(sessionID) === startedAt) {
          inFlightCompletions.delete(sessionID)
        }
      }
      return
    }

    if (type === "question.asked" || type === "question.v2.asked") {
      const parsed = sessionPropertiesSchema.safeParse(properties)
      if (parsed.success) {
        const startedAt = revision(parsed.data.sessionID)
        await deliverAction(runtime, "question", parsed.data.sessionID, () => revision(parsed.data.sessionID) === startedAt)
      }
      return
    }

    if (type === "permission.asked" || type === "permission.updated") {
      const parsed = permissionPropertiesSchema.safeParse(properties)
      if (parsed.success) {
        const startedAt = revision(parsed.data.sessionID)
        await deliverAction(
          runtime,
          permissionKind(parsed.data),
          parsed.data.sessionID,
          () => revision(parsed.data.sessionID) === startedAt,
        )
      }
      return
    }

    if (type !== "session.error") return
    const parsed = errorPropertiesSchema.safeParse(properties)
    if (
      !parsed.success ||
      !parsed.data.sessionID ||
      parsed.data.error?.name === "MessageAbortedError"
    ) {
      return
    }
    const sessionID = parsed.data.sessionID
    const startedAt = revision(sessionID)
    await deliverAction(
      runtime,
      "error",
      sessionID,
      () => revision(sessionID) === startedAt,
      parsed.data.error?.data?.message ?? parsed.data.error?.name,
    )
  }
}
