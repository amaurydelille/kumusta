"use client";

import { MagnifyingGlass, X } from "@phosphor-icons/react";
import Link from "next/link";
import { useMemo, useState } from "react";

const posts = [
  {
    category: "App guide",
    title: "Best Vietnamese mobile app in 2026",
    copy: "What to look for in a Vietnamese app this year, and why VietBuddy leads for real conversations, natural voices, and accent choice.",
    href: "/blog/best-vietnamese-app-2026",
  },
  {
    category: "Pronunciation",
    title: "How to pronounce Vietnamese without guessing",
    copy: "A practical guide to tones, vowels, consonants, and the listening routine that makes real spoken Vietnamese easier to follow.",
    href: "/blog/vietnamese-pronunciation",
  },
  {
    category: "Listening and tones",
    title: "Vietnamese tones, heard in real words",
    copy: "Learn the six Vietnamese tones through natural voices, useful phrases, and everyday listening practice.",
    href: "/blog/vietnamese-tones",
  },
  {
    category: "App guide",
    title: "Best app to learn Vietnamese: our honest comparison",
    copy: "VietBuddy comes first for real listening and speaking, followed by Duolingo, Pimsleur, and Mango Languages.",
    href: "/blog/best-app-to-learn-vietnamese",
  },
  {
    category: "Accent guide",
    title: "Northern vs Southern Vietnamese: which should you learn?",
    copy: "Compare tones, consonants, vocabulary, and real-life listening situations across the two accents.",
    href: "/blog/northern-vs-southern-vietnamese-pronunciation",
  },
];

const topics = ["Pronunciation", "Listening", "Speaking", "Culture"];

export function BlogSearch() {
  const [query, setQuery] = useState("");
  const normalizedQuery = query.trim().toLowerCase();
  const results = useMemo(
    () => posts.filter((post) => [post.category, post.title, post.copy].some((value) => value.toLowerCase().includes(normalizedQuery))),
    [normalizedQuery],
  );

  return (
    <section className="blog-search" aria-labelledby="blog-search-title">
      <div className="blog-search__inner">
        <h2 id="blog-search-title">What do you want to <em>hear about?</em></h2>
        <form className="blog-search__form" role="search" onSubmit={(event) => event.preventDefault()}>
          <MagnifyingGlass aria-hidden="true" weight="bold" />
          <label className="sr-only" htmlFor="blog-search-input">Search VietBuddy blog</label>
          <input
            id="blog-search-input"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search listening, speaking, culture..."
            autoComplete="off"
          />
          {query && (
            <button type="button" className="blog-search__clear" onClick={() => setQuery("")} aria-label="Clear blog search">
              <X weight="bold" />
            </button>
          )}
        </form>
        <div className="blog-search__topics" aria-label="Search by topic">
          <span>Explore:</span>
          {topics.map((topic) => (
            <button type="button" key={topic} onClick={() => setQuery(topic)} className={query.toLowerCase() === topic.toLowerCase() ? "is-active" : ""}>
              {topic}
            </button>
          ))}
        </div>
        <div className="blog-search__results" aria-live="polite">
          <div className="blog-search__results-heading">
            <span>{normalizedQuery ? `${results.length} ${results.length === 1 ? "article" : "articles"} found` : "All articles"}</span>
          </div>
          {results.length > 0 ? results.map((post) => (
            <Link className="blog-search__result" href={post.href} key={post.title}>
              <span>{post.category}</span>
              <h3>{post.title}</h3>
              <p>{post.copy}</p>
              <span className="blog-search__result-arrow" aria-hidden="true">↗</span>
            </Link>
          )) : <p className="blog-search__empty">No notes match that search yet. Try another topic.</p>}
        </div>
      </div>
    </section>
  );
}
