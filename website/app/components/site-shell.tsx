import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import { appStoreHref } from "./app-store";


export function BrandMark({ compact = false }: { compact?: boolean }) {
  return (
    <Link className="brand" href="/" aria-label="VietBuddy home">
      <Image className="brand__icon" src="/app-icon.png" width={36} height={36} alt="" priority />
      {!compact && <span>VietBuddy</span>}
    </Link>
  );
}

export function SiteHeader({ active }: { active?: "blog" | "podcast" }) {
  return (
    <header className="site-header">
      <div className="site-header__inner">
        <a className="skip-link" href="#main-content">Skip to content</a>
        <BrandMark />
        <nav aria-label="Primary navigation">
          <Link href="/#how-it-works">How it works</Link>
          <Link href="/#inside">Why VietBuddy</Link>
          <Link className={`site-header__blog ${active === "blog" ? "is-active" : ""}`} href="/blog">Blog</Link>
          <Link className={`site-header__podcast ${active === "podcast" ? "is-active" : ""}`} href="/podcasts">Podcasts</Link>
          <Link href="/support">Support</Link>
          <a className="app-store-link app-store-link--nav" href={appStoreHref("nav")} target="_blank" rel="noreferrer nofollow">
            <span>App Store</span>
          </a>
        </nav>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer__inner">
        <BrandMark compact />
        <div className="footer-links" aria-label="Legal and support links">
          <Link href="/support">Support</Link>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <Link href="/delete-account">Delete account</Link>
        </div>
        <p className="footer-note">© {new Date().getFullYear()} VietBuddy. Vietnamese beyond the textbook.</p>
      </div>
    </footer>
  );
}

export function LegalPage({
  eyebrow,
  title,
  updated,
  children,
}: {
  eyebrow: string;
  title: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <main className="legal-page" id="main-content">
      <SiteHeader />
      <article className="legal-copy">
        <span className="eyebrow">{eyebrow}</span>
        <h1>{title}</h1>
        <p className="legal-updated">Last updated: {updated}</p>
        {children}
      </article>
      <SiteFooter />
    </main>
  );
}
