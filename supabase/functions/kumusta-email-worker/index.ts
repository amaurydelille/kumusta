/// <reference lib="deno.ns" />

import { createAdminClient } from "../_shared/auth.ts";
import {
  errorResponse,
  fetchWithTimeout,
  HttpError,
  isPlainObject,
  jsonResponse,
  readBoundedResponseBody,
  requestID,
  requiredEnv,
  secureEqual,
} from "../_shared/http.ts";
import type { TransactionalEmailType } from "../kumusta-revenuecat-webhook/contract.ts";

const maximumProviderResponseBytes = 32_768;
const maximumJobsPerRun = 10;

interface EmailJob {
  id: string;
  user_id: string;
  email_type: TransactionalEmailType;
  attempts: number;
}

interface RenderedEmail {
  subject: string;
  html: string;
  text: string;
}

Deno.serve(async (req: Request) => {
  const id = requestID(req);
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });
  if (req.method !== "POST") {
    return errorResponse(
      new HttpError(405, "method_not_allowed", "Use POST."),
      id,
    );
  }

  try {
    const expected = `Bearer ${requiredEnv("EMAIL_WORKER_AUTHORIZATION")}`;
    const provided = req.headers.get("authorization") ?? "";
    if (!await secureEqual(provided, expected)) {
      throw new HttpError(401, "invalid_worker_authorization", "Unauthorized.");
    }

    const admin = createAdminClient();
    const { data, error } = await admin.rpc("kumusta_claim_email_jobs", {
      p_limit: maximumJobsPerRun,
    });
    if (error) {
      console.error("email_job_claim_failed", { request_id: id, code: error.code });
      throw new HttpError(503, "email_queue_unavailable", "Please retry.");
    }

    const jobs = Array.isArray(data) ? data as EmailJob[] : [];
    let sent = 0;
    let deferred = 0;
    let failed = 0;
    for (const job of jobs) {
      const result = await processJob(admin, job);
      if (result === "sent") sent += 1;
      if (result === "deferred") deferred += 1;
      if (result === "failed") failed += 1;
    }

    return jsonResponse(200, {
      processed: jobs.length,
      sent,
      deferred,
      failed,
    }, id);
  } catch (error) {
    return errorResponse(error, id);
  }
});

async function processJob(
  admin: ReturnType<typeof createAdminClient>,
  job: EmailJob,
): Promise<"sent" | "deferred" | "failed"> {
  const { data: authData, error: authError } = await admin.auth.admin.getUserById(
    job.user_id,
  );
  if (authError) {
    return recordFailure(admin, job, `auth_lookup_failed:${authError.code ?? "unknown"}`);
  }

  const email = authData.user?.email?.trim();
  if (!email) {
    return deferOrFail(
      admin,
      job,
      "customer_email_unavailable",
      "The account does not have an email address yet.",
    );
  }

  const { data: profile, error: profileError } = await admin
    .from("kumusta_profiles")
    .select("display_name")
    .eq("id", job.user_id)
    .maybeSingle();
  if (profileError) {
    return recordFailure(admin, job, `profile_lookup_failed:${profileError.code}`);
  }

  const displayName = typeof profile?.display_name === "string" ? profile.display_name.trim() : "";
  const message = renderEmail(job.email_type, displayName);

  let response: Response;
  try {
    response = await fetchWithTimeout(
      "https://api.resend.com/emails",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${requiredEnv("RESEND_API_KEY")}`,
          "Content-Type": "application/json",
          "Idempotency-Key": `kumusta-email-job-${job.id}`,
        },
        body: JSON.stringify({
          from: Deno.env.get("EMAIL_FROM")?.trim() ||
            "Amaury from Kumusta <amaury@kumusta.app>",
          to: [email],
          reply_to: Deno.env.get("EMAIL_REPLY_TO")?.trim() ||
            "amaury@kumusta.app",
          subject: message.subject,
          html: message.html,
          text: message.text,
        }),
      },
      10_000,
    );
  } catch {
    return deferOrFail(admin, job, "resend_request_failed", "Resend request failed.");
  }

  const responseBody = await readProviderResponse(response);
  if (!response.ok || !isPlainObject(responseBody)) {
    const providerError = providerErrorMessage(responseBody, response.status);
    return deferOrFail(admin, job, `resend_http_${response.status}`, providerError);
  }

  const providerMessageID = typeof responseBody.id === "string" ? responseBody.id : null;
  return markSent(admin, job.id, providerMessageID);
}

async function readProviderResponse(response: Response): Promise<unknown> {
  try {
    const bytes = await readBoundedResponseBody(response, maximumProviderResponseBytes);
    const text = new TextDecoder().decode(bytes);
    if (!text) return {};
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

function providerErrorMessage(body: unknown, status: number): string {
  if (isPlainObject(body) && Array.isArray(body.message)) {
    return `resend_${status}:${body.message.slice(0, 2).join(" ")}`.slice(0, 2000);
  }
  if (isPlainObject(body) && typeof body.message === "string") {
    return `resend_${status}:${body.message}`.slice(0, 2000);
  }
  return `resend_http_${status}`;
}

async function markSent(
  admin: ReturnType<typeof createAdminClient>,
  jobID: string,
  providerMessageID: string | null,
): Promise<"sent"> {
  const { error } = await admin
    .from("kumusta_email_jobs")
    .update({
      status: "sent",
      provider_message_id: providerMessageID,
      last_error: null,
      locked_at: null,
      sent_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", jobID)
    .eq("status", "sending");
  if (error) throw new HttpError(503, "email_queue_unavailable", "Please retry.");
  return "sent";
}

async function deferOrFail(
  admin: ReturnType<typeof createAdminClient>,
  job: EmailJob,
  errorCode: string,
  message: string,
): Promise<"deferred" | "failed"> {
  const isFinal = job.attempts >= 6;
  const nextAttemptAt = new Date(
    Date.now() + retryDelayMilliseconds(job.attempts),
  ).toISOString();
  const { error } = await admin
    .from("kumusta_email_jobs")
    .update({
      status: isFinal ? "failed" : "pending",
      next_attempt_at: nextAttemptAt,
      locked_at: null,
      last_error: `${errorCode}:${message}`.slice(0, 2000),
      updated_at: new Date().toISOString(),
    })
    .eq("id", job.id)
    .eq("status", "sending");
  if (error) throw new HttpError(503, "email_queue_unavailable", "Please retry.");
  return isFinal ? "failed" : "deferred";
}

function recordFailure(
  admin: ReturnType<typeof createAdminClient>,
  job: EmailJob,
  error: string,
): Promise<"deferred" | "failed"> {
  return deferOrFail(admin, job, error, "The email job could not be prepared.");
}

function retryDelayMilliseconds(attempts: number): number {
  const delays = [5, 15, 60, 360, 1_440, 4_320];
  return delays[Math.min(Math.max(attempts - 1, 0), delays.length - 1)] * 60_000;
}

function renderEmail(type: TransactionalEmailType, name: string): RenderedEmail {
  const safeName = escapeHTML(name);
  const greeting = name ? `Hi ${safeName}` : "Hi";
  const plainGreeting = name ? `Hi ${name}` : "Hi";
  switch (type) {
    case "subscription_welcome":
      return {
        subject: "Welcome to Kumusta",
        html:
          `<p>${greeting},</p><p>Thank you for subscribing to Kumusta. I’m really happy to have you with me.</p><p>If you need anything at all, simply reply to this email. I’m here to help.</p><p>Happy learning,<br>Amaury<br>Kumusta</p>`,
        text:
          `${plainGreeting},\n\nThank you for subscribing to Kumusta. I’m really happy to have you with me.\n\nIf you need anything at all, simply reply to this email. I’m here to help.\n\nHappy learning,\nAmaury\nKumusta`,
      };
    case "subscription_cancellation_feedback":
      return {
        subject: "Could you tell me what I could do better?",
        html:
          `<p>${greeting},</p><p>I saw that you canceled your Kumusta subscription. I’m sorry to see you go, but I’d really value your feedback.</p><p>What did you enjoy? What didn’t work for you? What were you hoping Kumusta would do better?</p><p>Just reply to this email, even a few words would help me improve.</p><p>Thank you,<br>Amaury<br>Kumusta</p>`,
        text:
          `${plainGreeting},\n\nI saw that you canceled your Kumusta subscription. I’m sorry to see you go, but I’d really value your feedback.\n\nWhat did you enjoy? What didn’t work for you? What were you hoping Kumusta would do better?\n\nJust reply to this email, even a few words would help me improve.\n\nThank you,\nAmaury\nKumusta`,
      };
    case "subscription_refund":
      return {
        subject: "Could I make this right?",
        html:
          `<p>${greeting},</p><p>I saw that your refund was processed, and I’m sorry that something went wrong.</p><p>Before you move on, could you reply and tell me what happened? I’d really appreciate one chance to understand the problem and see whether I can improve your experience.</p><p>Your refund has already been processed, and replying to this email will not change that.</p><p>Best,<br>Amaury<br>Kumusta</p>`,
        text:
          `${plainGreeting},\n\nI saw that your refund was processed, and I’m sorry that something went wrong.\n\nBefore you move on, could you reply and tell me what happened? I’d really appreciate one chance to understand the problem and see whether I can improve your experience.\n\nYour refund has already been processed, and replying to this email will not change that.\n\nBest,\nAmaury\nKumusta`,
      };
  }
}

function escapeHTML(value: string): string {
  return value.replace(/[&<>'"]/g, (character) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "'": "&#39;",
      '"': "&quot;",
    })[character] ?? character);
}
