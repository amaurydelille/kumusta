import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render(pathname = "/", environment = {}, context = {
  waitUntil() {},
  passThroughOnException() {},
}) {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(
    new Request(`http://localhost${pathname}`, { headers: { accept: "text/html" } }),
    {
      ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
      ...environment,
    },
    context,
  );
}

test("redirects campaign links and records their attribution payload", async () => {
  const pending = [];
  const trackingRequests = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    trackingRequests.push({ input: String(input), init });
    return new Response(null, { status: 201 });
  };

  try {
    const response = await render(
      "/?from=Helen&fbclid=example-click-id",
      {
        SUPABASE_URL: "https://example.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "test-publishable-key",
      },
      {
        waitUntil(promise) {
          pending.push(promise);
        },
        passThroughOnException() {},
      },
    );

    assert.equal(response.status, 302);
    assert.equal(response.headers.get("location"), "https://apps.apple.com/us/app/vietbuddy-learn-vietnamese/id6796837982");

    await Promise.all(pending);
    assert.equal(trackingRequests.length, 1);
    assert.equal(trackingRequests[0].input, "https://example.supabase.co/rest/v1/app_store_redirect_clicks");

    const payload = JSON.parse(trackingRequests[0].init.body);
    assert.equal(payload.campaign, "helen");
    assert.equal(payload.source_path, "/");
    assert.deepEqual(payload.query_params, {
      from: "Helen",
      fbclid: "example-click-id",
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("server-renders the VietBuddy landing page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /VietBuddy \| Vietnamese for real ears/i);
  assert.match(html, /Build listening and speaking skills with natural, ultra-realistic voices/);
  assert.match(html, /Listen first/);
  assert.match(html, /Privacy/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton/i);
});

test("ships public legal and support pages", async () => {
  for (const [path, expected] of [["/privacy", "Privacy Policy"], ["/terms", "Terms of Use"], ["/support", "Contact support"], ["/delete-account", "Delete your VietBuddy account"]]) {
    const response = await render(path);
    assert.equal(response.status, 200, path);
    assert.match(await response.text(), new RegExp(expected));
  }
});

test("ships the podcast search page with the latest YouTube episode", async () => {
  const response = await render("/podcasts");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Listen, learn, and/);
  assert.match(html, /Vietnamese for Beginners: Tones, Pronunciation/);
  assert.match(html, /GPi_GqU9M9c/);
  assert.match(html, /Search VietBuddy podcasts/);
});

test("ships the three search-focused Vietnamese learning articles", async () => {
  for (const [pathname, expected] of [
    ["/blog/vietnamese-pronunciation", "How to pronounce"],
    ["/blog/vietnamese-tones", "Vietnamese tones"],
    ["/blog/northern-vs-southern-vietnamese-pronunciation", "Northern vs Southern Vietnamese"],
  ]) {
    const response = await render(pathname);
    assert.equal(response.status, 200, pathname);
    const html = await response.text();
    assert.match(html, new RegExp(expected));
    assert.match(html, /App Store/);
    assert.match(html, /natural voices/i);
    assert.match(html, /realistic context/i);
    assert.doesNotMatch(html, /\u2014/);
  }
});

test("ships the best Vietnamese app 2026 article with App Store screenshots", async () => {
  const response = await render("/blog/best-vietnamese-app-2026");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Best Vietnamese mobile app/);
  assert.match(html, /screenshots\/app-store\//);
  assert.match(html, /App Store/);
  assert.doesNotMatch(html, /\u2014/);
  assert.match(html, /href="\/#how-it-works"/);
  assert.match(html, /href="\/#inside"/);
});

test("keeps interactive and accessible landing behavior in source", async () => {
  const [page, css] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
  ]);
  assert.match(page, /AnimatePresence/);
  assert.match(page, /aria-expanded/);
  assert.match(page, /Bé Trâu/);
  assert.match(page, /Get VietBuddy/);
  assert.match(await readFile(new URL("../middleware.ts", import.meta.url), "utf8"), /redirectCampaignClick/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /min-height:900px/);
});
