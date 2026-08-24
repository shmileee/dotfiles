export const notificationKinds = [
  "complete",
  "error",
  "permission",
  "question",
  "plan_exit",
] as const

export type NotificationKind = (typeof notificationKinds)[number]

export type CompletionReadiness = {
  readonly background: "active" | "idle" | "unknown"
  readonly session: "child" | "top-level" | "unknown"
  readonly superseded: boolean
  readonly todos: "complete" | "incomplete" | "unknown"
}

export type CompletionDecision =
  | { readonly kind: "notify" }
  | {
      readonly kind: "skip"
      readonly reason:
        | "active_background_work"
        | "child_session"
        | "incomplete_todos"
        | "superseded"
        | "unknown_state"
    }

export type NotificationContext = {
  readonly event: NotificationKind
  readonly projectName: string
  readonly sessionTitle: string
  readonly lastUserText?: string | undefined
  readonly lastAssistantText?: string | undefined
  readonly errorText?: string | undefined
}

export type NotificationContent = {
  readonly body: string
  readonly subtitle: string
  readonly title: string
}

export function decideCompletionNotification(
  readiness: CompletionReadiness,
): CompletionDecision {
  if (readiness.superseded) {
    return { kind: "skip", reason: "superseded" }
  }

  if (readiness.session === "child") {
    return { kind: "skip", reason: "child_session" }
  }

  if (readiness.session === "unknown") {
    return { kind: "skip", reason: "unknown_state" }
  }

  if (readiness.background === "active") {
    return { kind: "skip", reason: "active_background_work" }
  }

  if (readiness.background === "unknown") {
    return { kind: "skip", reason: "unknown_state" }
  }

  if (readiness.todos === "incomplete") {
    return { kind: "skip", reason: "incomplete_todos" }
  }

  if (readiness.todos === "unknown") {
    return { kind: "skip", reason: "unknown_state" }
  }

  return { kind: "notify" }
}

const eventLabels = {
  complete: "Ready for input",
  error: "Error",
  permission: "Permission required",
  plan_exit: "Plan ready for review",
  question: "Question waiting",
} satisfies Record<NotificationKind, string>

function compact(value: string | undefined, limit: number): string | undefined {
  const normalized = value?.replace(/\s+/g, " ").trim()
  if (!normalized) return undefined
  if (normalized.length <= limit) return normalized
  return `${normalized.slice(0, limit - 1).trimEnd()}…`
}

export function buildNotificationContent(
  context: NotificationContext,
): NotificationContent {
  const title = `OpenCode · ${compact(context.projectName, 69) ?? "project"}`
  const subtitle = compact(context.sessionTitle, 100) ?? "OpenCode session"
  const lines = [eventLabels[context.event]]
  const userText = compact(context.lastUserText, 150)
  const assistantText = compact(context.lastAssistantText, 150)
  const errorText = compact(context.errorText, 175)

  if (userText) lines.push(`You: ${userText}`)
  if (context.event === "error" && errorText) {
    lines.push(errorText)
  } else if (assistantText) {
    lines.push(`Agent: ${assistantText}`)
  }

  return {
    title,
    subtitle,
    body: compact(lines.join("\n"), 420) ?? eventLabels[context.event],
  }
}
