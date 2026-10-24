import { NextFetchEvent, NextRequest } from "next/server";
import { redirectCampaignClick } from "./worker/app-store-redirect";

export function middleware(request: NextRequest, event: NextFetchEvent) {
  return (
    redirectCampaignClick(
      request,
      {
        SUPABASE_URL: process.env.SUPABASE_URL,
        SUPABASE_PUBLISHABLE_KEY: process.env.SUPABASE_PUBLISHABLE_KEY,
        NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
          process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      },
      event,
    ) ?? undefined
  );
}

export const config = {
  matcher: "/",
};
