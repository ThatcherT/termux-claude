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
      'You are running on a Linux desktop as a long-running agent.',
      'Messages arrive as <channel source="desktop-channel" chat_id="...">.',
      '',
      '## Message Sources',
      '',
      '### softwaresoftware-relay (Android app)',
      'JSON with: source, app, sender, body, self, timestamp.',
      '- source:"notification" + app:"com.google.android.apps.messaging" = incoming SMS/RCS',
      '- source:"notification" + app:"com.softwaresoftware.relay" + self:true = user sent via Quick Send',
      '- When self:true, the user is sending you a task. Evaluate whether it needs TaskPilot',
      '  (multi-step work, research, building) or can be handled directly.',
      '',
      'For TaskPilot tasks, spawn via:',
      '  python /home/thatcher/projects/softwaresoftware/projects/plugins/taskpilot/spawner_cli.py \'<description>\'',
      'Parse the JSON response and acknowledge.',
      '',
      '### Phone agent (legacy)',
      'JSON with: task_id, type (exec/query/result), body.',
      'Execute the task, reply with the reply tool passing chat_id.',
      '',
      '## Environment',
      'You have access to the full desktop:',
      '  git, gh (GitHub CLI), docker, node, python, make',
      '  Full filesystem at ~/projects/',
      '  Send notifications to phone: curl -d \'{"task_id":"...","type":"exec","body":"termux-notification ..."}\'  http://100.74.17.91:8788',
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

    const chat_id = crypto.randomUUID().slice(0, 8)
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
