import { readFile } from "node:fs/promises"
import { basename, join } from "node:path"

import type { Plugin } from "@opencode-ai/plugin"
import { z } from "zod"

import {
  createNotifierEventHandler,
  type MarkerEvent,
  type MessageSnapshot,
} from "../lib/contextual-notifier-runtime"

const sessionSchema = z.object({
  parentID: z.string().optional(),
  title: z.string(),
})
const todoSchema = z.array(z.object({ status: z.string() }))
const messageHistorySchema = z.array(
  z.object({
    info: z.object({ role: z.enum(["assistant", "user"]) }),
    parts: z.array(
      z.object({ type: z.string(), text: z.string().optional() }).passthrough(),
    ),
  }),
)
const continuationSchema = z.object({
  sources: z.record(
    z.string(),
    z.object({ state: z.string() }).passthrough(),
  ),
})
const notificationSound = "Submarine"

function latestText(
  history: z.infer<typeof messageHistorySchema>,
  role: "assistant" | "user",
): string | undefined {
  for (let index = history.length - 1; index >= 0; index -= 1) {
    const entry = history[index]
    if (!entry || entry.info.role !== role) continue
    const text = entry.parts
      .filter((part) => part.type === "text" && part.text)
      .map((part) => part.text)
      .join("\n")
      .trim()
    if (text) return text
  }
  return undefined
}

function parseMessages(value: unknown): MessageSnapshot | undefined {
  const parsed = messageHistorySchema.safeParse(value)
  if (!parsed.success) return undefined
  return {
    lastUserText: latestText(parsed.data, "user"),
    lastAssistantText: latestText(parsed.data, "assistant"),
  }
}

function isFileNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "ENOENT"
  )
}

export const ContextualNotifier: Plugin = async ({
  client,
  directory,
  $,
}) => {
  const markerScript = join(import.meta.dir, "..", "tmux-waiting-marker.sh")
  const continuationDirectory = join(directory, ".omo", "run-continuation")
  const handler = createNotifierEventHandler({
    projectName: basename(directory) || "project",
    readSession: async (sessionID) => {
      const response = await client.session.get({
        path: { id: sessionID },
        query: { directory },
      })
      const parsed = sessionSchema.safeParse(response.data)
      return parsed.success ? parsed.data : undefined
    },
    readTodos: async (sessionID) => {
      const response = await client.session.todo({
        path: { id: sessionID },
        query: { directory },
      })
      const parsed = todoSchema.safeParse(response.data)
      return parsed.success ? parsed.data : undefined
    },
    readMessages: async (sessionID) => {
      const response = await client.session.messages({
        path: { id: sessionID },
        query: { directory, limit: 20 },
      })
      return parseMessages(response.data)
    },
    readBackground: async (sessionID) => {
      try {
        const raw = await readFile(
          join(continuationDirectory, `${sessionID}.json`),
          "utf8",
        )
        const parsed = continuationSchema.safeParse(JSON.parse(raw))
        if (!parsed.success) return "unknown"
        return Object.values(parsed.data.sources).some(
          (source) => source.state === "active",
        )
          ? "active"
          : "idle"
      } catch (error) {
        return isFileNotFound(error) ? "idle" : "unknown"
      }
    },
    mark: async (event: MarkerEvent) => {
      await $`${markerScript} ${event}`.quiet().nothrow()
    },
    notify: async (content) => {
      const windowLabel = (
        await $`${markerScript} window_label`.quiet().nothrow().text()
      ).trim()
      const subtitle = windowLabel
        ? `${windowLabel} · ${content.subtitle}`
        : content.subtitle
      await $`osascript -e ${"on run argv"} -e ${"display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)"} -e ${"end run"} ${content.body} ${content.title} ${subtitle} ${notificationSound}`
        .quiet()
        .nothrow()
    },
  })

  return {
    event: async ({ event }) => handler(event),
  }
}
