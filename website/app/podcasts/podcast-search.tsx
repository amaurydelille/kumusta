"use client";

import Image from "next/image";
import { ArrowUpRight, MagnifyingGlass, PlayCircle, X, YoutubeLogo } from "@phosphor-icons/react";
import { useMemo, useState } from "react";

const podcasts = [
  {
    category: "Episode 01 · Beginner Vietnamese",
    title: "Vietnamese for Beginners: Tones, Pronunciation & Everyday Phrases",
    copy: "Start hearing Vietnamese with a friendly guide to tones, pronunciation, and useful phrases for everyday conversations.",
    topics: ["beginner", "tones", "pronunciation", "everyday phrases"],
    href: "https://youtu.be/GPi_GqU9M9c",
    thumbnail: "https://i.ytimg.com/vi/GPi_GqU9M9c/hqdefault.jpg",
    imageAlt: "Vietnamese for Beginners podcast episode thumbnail",
  },
];

const topics = ["Beginner", "Pronunciation", "Tones", "Everyday phrases"];

export function PodcastSearch() {
  const [query, setQuery] = useState("");
  const normalizedQuery = query.trim().toLowerCase();
  const results = useMemo(
    () => podcasts.filter((podcast) =>
      [podcast.category, podcast.title, podcast.copy, ...podcast.topics].some((value) => value.toLowerCase().includes(normalizedQuery)),
    ),
    [normalizedQuery],
  );

  return (
    <section className="podcast-search" aria-labelledby="podcast-search-title">
      <div className="podcast-search__inner">
        <span className="eyebrow"><YoutubeLogo weight="fill" /> From the VietBuddy channel</span>
        <h1 id="podcast-search-title">Listen, learn, and <em>stay curious.</em></h1>
        <p className="podcast-search__lead">Longer conversations and practical Vietnamese listening for the moments beyond the lesson.</p>
        <form className="blog-search__form podcast-search__form" role="search" onSubmit={(event) => event.preventDefault()}>
          <MagnifyingGlass aria-hidden="true" weight="bold" />
          <label className="sr-only" htmlFor="podcast-search-input">Search VietBuddy podcasts</label>
          <input
            id="podcast-search-input"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search tones, pronunciation, everyday phrases..."
            autoComplete="off"
          />
          {query && (
            <button type="button" className="blog-search__clear" onClick={() => setQuery("")} aria-label="Clear podcast search">
              <X weight="bold" />
            </button>
          )}
        </form>
        <div className="blog-search__topics podcast-search__topics" aria-label="Search podcasts by topic">
          <span>Explore:</span>
          {topics.map((topic) => (
            <button type="button" key={topic} onClick={() => setQuery(topic)} className={query.toLowerCase() === topic.toLowerCase() ? "is-active" : ""}>
              {topic}
            </button>
          ))}
        </div>
        <div className="podcast-search__results" aria-live="polite">
          <div className="blog-search__results-heading">
            <span>{normalizedQuery ? `${results.length} ${results.length === 1 ? "episode" : "episodes"} found` : "Latest episodes"}</span>
          </div>
          {results.length > 0 ? results.map((podcast) => (
            <a className="podcast-result" href={podcast.href} target="_blank" rel="noreferrer" key={podcast.title}>
              <div className="podcast-result__media">
                <Image src={podcast.thumbnail} alt={podcast.imageAlt} width={290} height={164} sizes="(max-width: 640px) 100vw, 290px" unoptimized />
                <span className="podcast-result__play" aria-hidden="true"><PlayCircle weight="fill" /></span>
                <span className="podcast-result__youtube"><YoutubeLogo weight="fill" /> YouTube</span>
              </div>
              <div className="podcast-result__body">
                <span>{podcast.category}</span>
                <h2>{podcast.title}</h2>
                <p>{podcast.copy}</p>
                <span className="podcast-result__link">Listen on YouTube <ArrowUpRight weight="bold" /></span>
              </div>
            </a>
          )) : <p className="blog-search__empty">No episodes match that search yet. Try another topic.</p>}
        </div>
      </div>
    </section>
  );
}
