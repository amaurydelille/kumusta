import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Analytics } from "@vercel/analytics/next"
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://viet-buddy-six.vercel.app"),
  title: {
    default: "VietBuddy | Vietnamese for real ears",
    template: "%s | VietBuddy",
  },
  description:
    "Learn the Vietnamese people actually speak through short, listening-first lessons in Northern or Southern Vietnamese.",
  applicationName: "VietBuddy",
  keywords: [
    "learn Vietnamese",
    "Vietnamese listening",
    "Vietnamese speaking",
    "Southern Vietnamese",
    "Northern Vietnamese",
  ],
  icons: {
    icon: [{ url: "/app-icon.png", type: "image/png", sizes: "1024x1024" }],
    shortcut: "/app-icon.png",
    apple: "/app-icon.png",
  },
  openGraph: {
    title: "VietBuddy | Vietnamese for real ears",
    description:
      "Short, listening-first lessons for the Vietnamese people actually speak.",
    type: "website",
    siteName: "VietBuddy",
    images: [
      {
        url: "/screenshots/home.PNG",
        width: 900,
        height: 1948,
        alt: "VietBuddy daily lesson screen",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "VietBuddy | Vietnamese for real ears",
    description:
      "Short, listening-first lessons for the Vietnamese people actually speak.",
    images: ["/screenshots/home.PNG"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link
          rel="preload"
          href="/fonts/Patriot-Black.woff2?v=2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
      <Analytics/>
    </html>
  );
}
