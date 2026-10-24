import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { SiteFooter, SiteHeader } from "../../components/site-shell";
import { appStoreHref } from "../../components/app-store";


export const metadata: Metadata = {
  title: "Vietnamese tones explained with real words | VietBuddy",
  description: "Learn the six Vietnamese tones with clear examples, practical listening advice, and a short daily routine for real conversations.",
  keywords: [
    "Vietnamese tones",
    "six Vietnamese tones",
    "Vietnamese tone marks",
    "Vietnamese tone chart",
    "how to pronounce Vietnamese tones",
  ],
};

export default function VietnameseTonesPage() {
  return (
    <main className="article-page" id="main-content">
      <SiteHeader />
      <article className="article-copy">
        <Link className="article-back" href="/blog">← Back to the blog</Link>
        <header className="article-header">
          <span className="eyebrow">Listening and tones</span>
          <h1>Vietnamese tones, heard in <em>real words.</em></h1>
          <p className="article-lead">
            The six Vietnamese tones become easier when you hear their movement inside useful phrases. Learn the basic shapes, then practice them with natural voices and everyday situations.
          </p>
          <p className="article-byline">VietBuddy · 8 minute read</p>
        </header>

        <div className="article-body">
          <p>
            Vietnamese tones can feel abstract on a page. A mark above or below a vowel gives you a clue, yet your voice still needs to move through the word in a particular way. Tone belongs to the sound of the syllable, so it deserves the same daily attention as the initial consonant or vowel.
          </p>
          <p>
            The fastest way to make progress is to connect each tone to a short phrase. Listen for the pitch movement, feel the voice quality, and repeat the entire chunk. The goal is a recognizable spoken phrase that works in a real conversation.
          </p>

          <a className="article-store-cta" href={appStoreHref("blog_tones")} target="_blank" rel="noreferrer nofollow">
            <span>Try VietBuddy, the best app to learn Vietnamese tones in context</span>
            <span aria-hidden="true">↗</span>
          </a>

          <figure className="article-figure article-figure--wide">
            <Image
              src="/screenshots/vocab.PNG"
              width={1170}
              height={2532}
              alt="VietBuddy Word Gym screen showing a saved Vietnamese listening chunk"
              sizes="(max-width: 760px) 100vw, 760px"
            />
            <figcaption>Hear a useful chunk again before you say it.</figcaption>
          </figure>

          <h2>What are the six Vietnamese tones?</h2>
          <p>
            The tone names below are the standard starting point for Vietnamese learners. Their exact sound can vary by region and speaker, especially in Southern Vietnamese. Use the descriptions as a listening map, then follow a recording from the accent you want to learn.
          </p>

          <table className="article-tone-table">
            <thead>
              <tr>
                <th>Tone</th>
                <th>Mark</th>
                <th>Listening shape</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>ngang</td>
                <td>no mark</td>
                <td>Level and steady</td>
              </tr>
              <tr>
                <td>sắc</td>
                <td>acute accent</td>
                <td>Rising and bright</td>
              </tr>
              <tr>
                <td>huyền</td>
                <td>grave accent</td>
                <td>Falling and low</td>
              </tr>
              <tr>
                <td>hỏi</td>
                <td>hook above</td>
                <td>Dipping, then rising</td>
              </tr>
              <tr>
                <td>ngã</td>
                <td>tilde</td>
                <td>Rising with a broken quality</td>
              </tr>
              <tr>
                <td>nặng</td>
                <td>dot below</td>
                <td>Low, tight, and cut short</td>
              </tr>
            </tbody>
          </table>

          <p>
            One classic practice set uses the syllable <em>ma</em>: <em>ma, má, mà, mả, mã, mạ</em>. The spelling changes only by the tone mark, while the meaning and sound change with it. Treat this as a listening exercise, then move quickly into words and sentences you actually need.
          </p>

          <h2>Start with the level and falling tones</h2>
          <p>
            Ngang and huyền create a useful first contrast. Keep <em>ngang</em> steady and let <em>huyền</em> fall into a lower finish. Record yourself saying the pair, then compare the final part of the voice rather than judging the whole word at once.
          </p>
          <p>
            Add one phrase that belongs to your life. You could practice a greeting, a coffee order, or a sentence you use with family. A meaningful phrase gives the tone a place to live in your memory.
          </p>

          <h2>Feel the movement in rising and dipping tones</h2>
          <p>
            Sắc rises with a clear upward movement. Hỏi dips before it comes back up. These tones can sound close when you only read their names, so listen for the direction across the syllable. Let the voice move gradually instead of jumping to the highest pitch immediately.
          </p>
          <p>
            Speakers may produce these tones with different voice ranges. That is one reason natural recordings are useful. You are learning a contour and a rhythm, rather than trying to copy a single pitch that every speaker must use.
          </p>

          <h2>Learn ngã and nặng with voice quality</h2>
          <p>
            Ngã and nặng are easier to hear when you notice how the voice closes. Ngã can include a broken or interrupted quality. Nặng is compact, low, and often ends with a tight closure. Keep the word short and let the ending finish cleanly.
          </p>
          <p>
            Regional pronunciation affects how these tones sound. Many Southern speakers merge hỏi and ngã in everyday speech, while Northern speech commonly keeps a stronger contrast. Read <Link href="/blog/northern-vs-southern-vietnamese-pronunciation">our Northern and Southern Vietnamese guide</Link> before deciding which recording style should be your main reference.
          </p>

          <div className="article-callout">
            <span className="eyebrow">Why context matters</span>
            <h2>Tone practice should sound like <em>life.</em></h2>
            <p>
              VietBuddy places tones inside realistic situations, from a café conversation to a quick exchange with a neighbor. Natural voices give you the rhythm around each tone, and the situation helps you remember why the phrase matters. You hear the Vietnamese people use in real life before you study the explanation.
            </p>
          </div>

          <h2>A seven-minute tone practice routine</h2>
          <ol>
            <li>Listen to a short phrase at natural speed.</li>
            <li>Identify the situation before reading the transcript.</li>
            <li>Choose one syllable and follow its pitch movement.</li>
            <li>Repeat the complete phrase, keeping the rhythm intact.</li>
            <li>Record one attempt and compare the tone shape.</li>
            <li>Save the phrase for another short review tomorrow.</li>
          </ol>
          <p>
            Keep the correction small. If the phrase has six syllables, choose one tone to notice on the first repetition. Your ear will become more precise as the phrase returns in different contexts.
          </p>

          <div className="article-screenshot-grid">
            <figure className="article-figure">
              <Image
                src="/screenshots/conv.PNG"
                width={1170}
                height={2532}
                alt="VietBuddy Cold Listen screen with natural speed Southern Vietnamese audio"
                sizes="(max-width: 640px) 100vw, 33vw"
              />
              <figcaption>Catch the situation before the transcript.</figcaption>
            </figure>
            <figure className="article-figure">
              <Image
                src="/screenshots/home.PNG"
                width={1170}
                height={2532}
                alt="VietBuddy Today screen with a seven-minute Vietnamese lesson"
                sizes="(max-width: 640px) 100vw, 33vw"
              />
              <figcaption>Make tone practice fit a normal day.</figcaption>
            </figure>
          </div>

          <h2>Use tones to become easier to understand</h2>
          <p>
            You do not need a perfect accent before you speak. You need a useful next attempt. Listen closely, choose one tone movement, and bring it into a phrase you can imagine using today. That is how tone knowledge becomes speaking confidence.
          </p>
          <p>
            Download VietBuddy on the <a href={appStoreHref("blog_tones_inline")} target="_blank" rel="noreferrer nofollow">App Store</a> and practice Vietnamese tones with natural voices, realistic context, and situations drawn from real spoken Vietnamese.
          </p>

          <p className="article-sources">
            Next: <Link href="/blog/vietnamese-pronunciation">How to pronounce Vietnamese</Link> or <Link href="/blog/northern-vs-southern-vietnamese-pronunciation">Northern and Southern Vietnamese pronunciation</Link>.
          </p>
        </div>
      </article>
      <SiteFooter />
    </main>
  );
}
