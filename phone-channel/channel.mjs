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
  { name: 'phone-channel', version: '0.1.0' },
  {
    capabilities: {
      experimental: { 'claude/channel': {} },
      tools: {},
    },
    instructions: [
      'You are running on an Android phone in Termux.',
      'Messages arrive as <channel source="phone-channel" chat_id="...">.',
      'These are instructions from the user on their desktop computer.',
      'Execute the requested task, then reply with the reply tool passing the chat_id.',
      '',
      'You have access to termux-api commands:',
      '  termux-tts-speak - text to speech (use -r 1.2 for slightly faster)',
      '  termux-speech-to-text - speech to text',
      '  termux-notification - show Android notification',
      '  termux-sms-send - send SMS',
      '  termux-vibrate - vibrate the phone',
      '  termux-torch - toggle flashlight',
      '  termux-battery-status - battery info',
      '  termux-location - GPS location',
      '  termux-camera-photo - take a photo',
      '  termux-clipboard-set / termux-clipboard-get - clipboard',
      '',
      'Keep replies SHORT - one or two sentences. The user reads them from their desktop.',
      'When speaking aloud with termux-tts-speak, keep it to one sentence max.',
      '',
      'To send tasks to the desktop agent:',
      '  curl -d \'{"task_id":"p-001","type":"exec","body":"..."}\'  http://100.99.44.89:8789',
      'Task protocol:',
      '  Incoming messages may be JSON with task_id, type (exec/query/result), body.',
      '  When replying to a task, include the task_id so the sender can correlate it.',
      '  Use status: done, error, or need_human (when only the user can do something manually).',
      '',
      '## SMS-Forwarded Messages',
      'Messages with "source":"sms" are texts the user sent themselves as task triggers.',
      'Evaluate whether the SMS describes a task suitable for TaskPilot (research, building, multi-step work)',
      'or is just a note/reminder (buy milk, call dentist).',
      '',
      'For tasks: spawn on desktop via SSH:',
      '  ssh 100.99.44.89 "python /home/thatcher/projects/nov/projects/plugins/taskpilot/spawner_cli.py \'<description>\'"',
      'Parse the JSON response. On success, notify:',
      '  termux-notification --title "TaskPilot: <task_id>" --content "Spawned on port <port>"',
      'On failure or desktop unreachable:',
      '  termux-notification --title "TaskPilot Failed" --content "<error>"',
      '',
      'For non-tasks: just acknowledge with a notification.',
      '',
      '## TaskPilot Replies',
      'Messages with "source":"taskpilot" are from spawned desktop agents.',
      'Show notification: termux-notification --title "Task: <task_id>" --content "<body>"',
      'If it contains a question, also speak it: termux-tts-speak "<question>"',
      '',
      'If the user texts a reply referencing a task, route it to the task channel:',
      '  curl -s -d "<reply>" http://100.99.44.89:<port>',
      'Remember task_id -> port mappings from when you spawned them.',
    ].join('\n'),
  },
)

// --- Reply tool ---
mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'reply',
      description: 'Send a reply back to the desktop user',
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

// --- HTTP server on 0.0.0.0:8788 (reachable via Tailscale) ---
let nextId = 1

const httpServer = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`)

  // SSE stream for watching replies from desktop
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

httpServer.listen(8788, '0.0.0.0', () => {
  // silence — stdout is reserved for MCP stdio transport
})
