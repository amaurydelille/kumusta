/// <reference lib="deno.ns" />

import {
  HttpError,
  readBoundedRequestBody,
  readBoundedResponseBody,
  ResponseBodyTooLargeError,
} from "./http.ts";

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("bounded response reader joins streamed chunks", async () => {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new TextEncoder().encode("kum"));
      controller.enqueue(new TextEncoder().encode("usta"));
      controller.close();
    },
  });
  const bytes = await readBoundedResponseBody(new Response(body), 9);
  assert(new TextDecoder().decode(bytes) === "kumusta", "Chunks were not joined");
});

Deno.test("bounded response reader cancels an oversized stream", async () => {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(6));
      controller.enqueue(new Uint8Array(6));
      controller.close();
    },
  });
  try {
    await readBoundedResponseBody(new Response(body), 10);
  } catch (error) {
    assert(error instanceof ResponseBodyTooLargeError, "Wrong overflow error");
    return;
  }
  throw new Error("Oversized stream was accepted");
});

Deno.test("bounded response reader rejects oversized Content-Length early", async () => {
  const response = new Response(null, { headers: { "Content-Length": "1001" } });
  try {
    await readBoundedResponseBody(response, 1_000);
  } catch (error) {
    assert(error instanceof ResponseBodyTooLargeError, "Wrong declared-length error");
    return;
  }
  throw new Error("Oversized declared response was accepted");
});

Deno.test("bounded request reader joins an upload without trusting declared size", async () => {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array([1, 2]));
      controller.enqueue(new Uint8Array([3, 4]));
      controller.close();
    },
  });
  const bytes = await readBoundedRequestBody(
    new Request("https://example.test", { method: "POST", body }),
    4,
    2,
  );
  assert(bytes.join(",") === "1,2,3,4", "Upload chunks were not joined");
});

Deno.test("bounded request reader rejects a streamed overflow", async () => {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(6));
      controller.enqueue(new Uint8Array(6));
      controller.close();
    },
  });
  try {
    await readBoundedRequestBody(
      new Request("https://example.test", { method: "POST", body }),
      10,
    );
  } catch (error) {
    assert(error instanceof HttpError && error.status === 413, "Wrong upload overflow error");
    return;
  }
  throw new Error("Oversized upload was accepted");
});
