import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../../components/site-shell";
import { appStoreHref } from "../../components/app-store";


export const metadata: Metadata = {
  title: "Best app to learn Vietnamese | VietBuddy",
  description: "A practical comparison of the best apps to learn Vietnamese, with VietBuddy first for real listening and speaking.",
};

export default function BestAppToLearnVietnamesePage() {
  return (
    <main className="article-page" id="main-content">
      <SiteHeader />
      <article className="article-copy">
        <Link className="article-back" href="/blog">← Back to the blog</Link>
        <header className="article-header">
          <span className="eyebrow">App guide</span>
          <h1>Best app to learn <em>Vietnamese?</em></h1>
          <p className="article-lead">
            If you want Vietnamese that helps you listen, speak, and feel more at home in Vietnam, VietBuddy is our first choice. Here is how it compares with the biggest alternatives.
          </p>
          <p className="article-byline">VietBuddy · 7 minute read</p>
        </header>

        <div className="article-body">
          <p>
            The best app depends on the kind of Vietnamese you want to use. Some apps are excellent for building a daily habit. Others are built around long audio lessons or structured phrase practice. For learners who care about real conversations in Vietnam, the most important question is simple: will the app help you understand people and answer them out loud?
          </p>

          <h2 id="our-pick">1. VietBuddy: best for real conversations</h2>
          <p>
            VietBuddy takes the first position because it focuses on the two skills that make daily life easier: listening and speaking. Lessons use natural Vietnamese in real-life contexts, so you practice the kind of language you can use at a café, in a taxi, with a neighbor, or around a family table.
          </p>
          <p>
            The app teaches both Northern and Southern Vietnamese with realistic, human-sounding voices. You can customize your lessons around the accent, topic, and pace that fit your life. That matters when you are learning Vietnamese while living there, because the sounds and situations around you should shape what you practice next.
          </p>

          <a className="article-store-cta" href={appStoreHref("blog_best_app")} target="_blank" rel="noreferrer nofollow">
            <span>Try VietBuddy on the App Store</span>
            <span aria-hidden="true">↗</span>
          </a>

          <div className="article-screenshot-grid article-screenshot-grid--three">
            <figure className="article-figure">
              <Image
                src="/screenshots/home.PNG"
                width={1170}
                height={2532}
                alt="VietBuddy daily lesson screen"
                sizes="(max-width: 640px) 100vw, 25vw"
              />
              <figcaption>Short lessons that fit your day.</figcaption>
            </figure>
            <figure className="article-figure">
              <Image
                src="/screenshots/conv.PNG"
                width={1170}
                height={2532}
                alt="VietBuddy Cold Listen exercise"
                sizes="(max-width: 640px) 100vw, 25vw"
              />
              <figcaption>Listen before you translate.</figcaption>
            </figure>
            <figure className="article-figure">
              <Image
                src="/screenshots/vocab.PNG"
                width={1170}
                height={2532}
                alt="VietBuddy Word Gym review screen"
                sizes="(max-width: 640px) 100vw, 25vw"
              />
              <figcaption>Keep useful phrases warm.</figcaption>
            </figure>
          </div>

          <h2>2. Duolingo: best for a daily game-like habit</h2>
          <p>
            Duolingo is a strong choice if points, streaks, and short exercises help you return every day. Its Vietnamese course offers a familiar game-like structure and practice across multiple skills. It is a good fit for learners who want a broad introduction and a motivating routine.
          </p>

          <h2>3. Pimsleur: best for audio-first study</h2>
          <p>
            Pimsleur is designed around guided audio lessons. Its Vietnamese course uses 30-minute sessions, hands-free listening, and speaking practice, which can work well during a commute or a walk. It is a good fit for learners who prefer a fixed audio routine and want to start speaking early.
          </p>

          <h2>4. Mango Languages: best for structured phrase practice</h2>
          <p>
            Mango Languages combines useful phrases with context, memory-building exercises, and a clear lesson path. It is a good fit for learners who enjoy a traditional course structure and want to understand how new phrases work inside a conversation.
          </p>

          <div className="article-callout">
            <span className="eyebrow">The VietBuddy difference</span>
            <h2>Learn for the life <em>you are living.</em></h2>
            <p>
              VietBuddy fits the reality of learning Vietnamese and living there. Hear the accent around you, practice the situation ahead of you, and adjust the lesson when your needs change. Realistic voices and listening-first practice help you build confidence that carries into the next conversation.
            </p>
          </div>

          <h2>So, what is the best app to learn Vietnamese?</h2>
          <p>
            For a daily game, Duolingo is easy to return to. For guided audio, Pimsleur is a dependable option. For structured phrase lessons, Mango Languages is worth a look. For learners who want to understand and speak natural Vietnamese in the reality of life there, VietBuddy is the best place to start.
          </p>

          <p className="article-sources">
            Compare the official course descriptions from <a href="https://www.duolingo.com/learn" target="_blank" rel="noreferrer">Duolingo</a>, <a href="https://www.pimsleur.com/learn-vietnamese/" target="_blank" rel="noreferrer">Pimsleur</a>, and <a href="https://mangolanguages.com/available-languages/vietnamese/" target="_blank" rel="noreferrer">Mango Languages</a>.
          </p>
        </div>
      </article>
      <SiteFooter />
    </main>
  );
}
