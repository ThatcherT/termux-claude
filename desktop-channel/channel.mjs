#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import http from 'node:http'

// --- Outbound: SSE listeners for replies ---
const listeners = new Set()
function send(text) {
  const chunk = text.split('\n').map(l => `data: ${l}\n`).join('') + '\n'
  for (const emit of listeners) emit(chunk)
}

// --- MCP Server with channel capability ---
const mcp = new Server(
  { name: 'desktop-channel', version: '0.1.0' },
  {
    capabilities: {
      experimental: { 'claude/channel': {} },
      tools: {},
    },
    instructions: [
      'You are running on a Linux desktop.',
      'Messages arrive as <channel source="desktop-channel" chat_id="...">.',
      'These are tasks from the Claude Code agent running on the user\'s Android phone.',
      'Execute the requested task, then reply with the reply tool passing the chat_id.',
      '',
      'You have access to the full desktop environment:',
      '  git, gh (GitHub CLI), docker, node, python, make',
      '  Full filesystem at ~/projects/',
      '  SSH to the phone: ssh -p 8022 100.74.17.91',
      '  Send tasks to the phone: curl -d \'{"task_id":"d-001","type":"exec","body":"..."}\'  http://100.74.17.91:8788',
      '',
      'Task protocol:',
      '  Incoming messages may be JSON with task_id, type (exec/query/result), body.',
      '  When replying to a task, include the task_id in your reply so the sender can correlate it.',
      '  Use status: done, error, or need_human (when only the user can do something manually).',
      '',
      'Keep replies concise. Only ask the user for things that require manual physical action.',
    ].join('\n'),
  },
)

// --- Reply tool ---
mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'reply',
      description: 'Send a reply back to the phone agent',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id: {
            type: 'string',
            description: 'The chat_id from the inbound channel tag',
          },
          text: {
            type: 'string',
            description: 'The reply message',
          },
        },
        required: ['chat_id', 'text'],
      },
    },
  ],
}))

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name === 'reply') {
    const { chat_id, text } = req.params.arguments
    send(`[${chat_id}] ${text}`)
    return { content: [{ type: 'text', text: 'sent' }] }
  }
  throw new Error(`unknown tool: ${req.params.name}`)
})

// --- Connect to Claude Code over stdio ---
await mcp.connect(new StdioServerTransport())

// --- HTTP server on 0.0.0.0:8789 (reachable via Tailscale) ---
let nextId = 1

const httpServer = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`)

  // SSE stream for watching replies
  if (req.method === 'GET' && url.pathname === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    })
    res.write(': connected\n\n')
    const emit = (chunk) => res.write(chunk)
    listeners.add(emit)
    req.on('close', () => listeners.delete(emit))
    return
  }

  // Health check
  if (req.method === 'GET' && url.pathname === '/health') {
    res.writeHead(200)
    res.end('ok')
    return
  }

  // POST: push message into Claude's session
  if (req.method === 'POST') {
    const chunks = []
    for await (const chunk of req) chunks.push(chunk)
    const body = Buffer.concat(chunks).toString()

    const chat_id = String(nextId++)
    await mcp.notification({
      method: 'notifications/claude/channel',
      params: {
        content: body,
        meta: { chat_id, path: url.pathname },
      },
    })
    res.writeHead(200)
    res.end(`ok (chat_id: ${chat_id})`)
    return
  }

  res.writeHead(404)
  res.end('not found')
})

httpServer.listen(8789, '0.0.0.0', () => {
  // silence — stdout is reserved for MCP stdio transport
})
