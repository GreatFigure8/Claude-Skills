// Minimal streamText fake: toTextStreamResponse() is plain text chunks, as the AI SDK returns.
export function streamText(options: { abortSignal?: AbortSignal }): { toTextStreamResponse: () => Response } {
  void options
  return {
    toTextStreamResponse: () => {
      const encoder = new TextEncoder()
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          for (const part of ['Hello', ', ', 'world']) controller.enqueue(encoder.encode(part))
          controller.close()
        },
      })
      return new Response(stream, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } })
    },
  }
}
