"use client";

import Image from "next/image";
import Link from "next/link";
import {
  AppleLogo,
  ArrowRight,
  Check,
  Clock,
  Ear,
  Fire,
  Globe,
  Lightning,
  Microphone,
  Plus,
  SpeakerHigh,
  Star,
  Waveform,
} from "@phosphor-icons/react";
import { AnimatePresence, motion } from "framer-motion";
import { useState } from "react";
import { SiteFooter, SiteHeader } from "./components/site-shell";
import { appStoreHref } from "./components/app-store";


const faq = [
  {
    question: "Is VietBuddy right for a complete beginner?",
    answer:
      "Yes. Choose your current level during onboarding and start with short situations you can understand through context. No prior Vietnamese is required.",
  },
  {
    question: "Can I learn Northern or Southern Vietnamese?",
    answer:
      "Both. Choose Northern or Southern Vietnamese when you begin. Your lesson audio follows that choice, and you can change it later in your profile.",
  },
  {
    question: "How long does a lesson take?",
    answer:
      "Choose a five, seven, or ten-minute routine. Every session follows one complete real-life situation, so even a short lesson feels finished.",
  },
];

const testimonials = [
  {
    title: "The perfect app to stick with your Vietnamese",
    date: "Ven.",
    reviewer: "IHM21",
    quote:
      "VietBuddy is the best app I’ve used to learn Vietnamese. I’ve tried many others, but this is the only one that really got me to stick with it and keep my streak going, and I don’t regret it. It’s extremely fun and engaging. Well designed, easy to access, easy to understand, yet suited to any level. Honestly, I think it’s a truly excellent app.",
    position: "one",
  },
  {
    title: "It’s a no-brainer",
    date: "Mon",
    reviewer: "timdll",
    quote:
      "No better option if you want to get serious about learning Vietnamese. I got the yearly plan, and the before-and-after is incredible. The best part is the app’s focus on hearing and speaking.",
    position: "two",
  },
  {
    title: "Life-changing",
    date: "Aug 19",
    reviewer: "AliceChenGM",
    quote:
      "I got the yearly plan, and I can’t think of going back to using other apps. The best part is the listening practice because the voices sound so natural, and they recreate real-life Vietnamese situations. Can’t recommend it enough.",
    position: "three",
  },
  {
    title: "Can’t recommend enough",
    date: "Tue",
    reviewer: "baddiewithchronicillness",
    quote:
      "I got the yearly plan, and the app skyrocketed my Vietnamese from A2 to C1 in a few weeks. I truly recommend doing those listening exercises because that is the reality of living in Vietnam. Learning words and sentences by heart won’t help when you have to understand what locals say to you. I truly can’t recommend it enough. 💕",
    position: "four",
  },
];

const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  visible: (delay = 0) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.55, delay, ease: [0.22, 1, 0.36, 1] as const },
  }),
};

const stagger = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.1 } },
};

function PhoneFrame({
  src,
  alt,
  tilt,
  className = "",
}: {
  src: string;
  alt: string;
  tilt?: "left" | "right";
  className?: string;
}) {
  const tiltClass = tilt === "left" ? "phone-frame--tilt-left" : tilt === "right" ? "phone-frame--tilt-right" : "";

  return (
    <div className={`phone-frame ${tiltClass} ${className}`}>
      <div className="phone-frame__screen">
        <Image src={src} width={1170} height={2532} alt={alt} sizes="(max-width: 760px) 68vw, 320px" />
        <span className="phone-frame__shine" aria-hidden="true" />
      </div>
    </div>
  );
}

function FeatureItem({
  icon,
  title,
  copy,
  tone,
}: {
  icon: "ear" | "wave" | "mic" | "fire";
  title: string;
  copy: string;
  tone: "red" | "green" | "amber";
}) {
  const Icon = icon === "ear" ? Ear : icon === "wave" ? Waveform : icon === "mic" ? Microphone : Fire;
  return (
    <div className="feature-item">
      <span className={`feature-item__icon feature-item__icon--${tone}`}><Icon weight="fill" /></span>
      <span><strong>{title}</strong><small>{copy}</small></span>
    </div>
  );
}

function TestimonialCard({
  testimonial,
}: {
  testimonial: (typeof testimonials)[number];
}) {
  return (
    <article className={`testimonial-card testimonial-card--${testimonial.position}`}>
      <div className="testimonial-card__eyebrow">App Store review</div>
      <h3>{testimonial.title}</h3>
      <div className="testimonial-card__meta">
        <span className="testimonial-card__stars" aria-label="5 out of 5 stars">
          {Array.from({ length: 5 }, (_, index) => <Star key={index} weight="fill" aria-hidden="true" />)}
        </span>
        <span>{testimonial.date} · {testimonial.reviewer}</span>
      </div>
      <p>{testimonial.quote}</p>
    </article>
  );
}

function FAQ() {
  const [open, setOpen] = useState(0);

  return (
    <div className="faq-list">
      {faq.map((item, index) => (
        <div className={`faq-item ${open === index ? "is-open" : ""}`} key={item.question}>
          <button type="button" aria-expanded={open === index} onClick={() => setOpen(open === index ? -1 : index)}>
            <span>{item.question}</span>
            <Plus weight="bold" aria-hidden="true" />
          </button>
          <AnimatePresence initial={false}>
            {open === index && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: "auto", opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
              >
                <p>{item.answer}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      ))}
    </div>
  );
}

export default function Home() {
  const [accent, setAccent] = useState<"north" | "south">("south");

  return (
    <main id="main-content">
      <SiteHeader />

      <section className="public-hero" id="download">
        <div className="public-hero__pattern" aria-hidden="true" />
        <motion.div
          className="public-hero__copy"
          initial="hidden"
          animate="visible"
          variants={stagger}
        >
          <motion.h1 variants={fadeUp} custom={0.08}>Learn <span className="hero-headline__patriot">Vietnamese</span> <em>the way it sounds.</em></motion.h1>
          <motion.p variants={fadeUp} custom={0.16}>
            Build listening and speaking skills with natural, ultra-realistic voices, accurate pronunciation, and the sentence rhythm Vietnamese learners need.
          </motion.p>
          <motion.div className="public-hero__actions" variants={fadeUp} custom={0.24}>
        <a className="app-store-link app-store-link--hero" href={appStoreHref("hero")} target="_blank" rel="noreferrer nofollow" aria-label="Get VietBuddy on the App Store">
              <AppleLogo weight="fill" />
              <span><small>Download now on the</small><strong>App Store</strong></span>
              <ArrowRight weight="bold" />
            </a>
          </motion.div>
        </motion.div>

        <motion.div
          className="public-hero__art"
          initial={{ opacity: 0, y: 44, scale: .95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ type: "spring", stiffness: 120, damping: 18, delay: .22 }}
        >
          <div className="hero-art__phones">
            <div className="hero-art__sun" aria-hidden="true" />
            <div className="hero-art__line hero-art__line--one" aria-hidden="true" />
            <div className="hero-art__line hero-art__line--two" aria-hidden="true" />
            <div className="hero-art__phone hero-art__phone--left">
              <PhoneFrame src="/screenshots/conv.PNG" alt="VietBuddy cold-listen exercise" tilt="left" />
            </div>
            <div className="hero-art__phone hero-art__phone--center">
              <PhoneFrame src="/screenshots/home.PNG" alt="VietBuddy daily lesson screen" />
            </div>
            <div className="hero-art__phone hero-art__phone--right">
              <PhoneFrame src="/screenshots/vocab.PNG" alt="VietBuddy Word Gym review screen" tilt="right" />
            </div>
            <div className="hero-art__buddy">
              <Image src="/be-trau-buddy.png" width={280} height={280} alt="Bé Trâu, the VietBuddy mascot" />
            </div>
          </div>
          <section className="hero-testimonials" aria-label="Testimonials from VietBuddy learners">
            {testimonials.map((testimonial) => <TestimonialCard key={testimonial.reviewer} testimonial={testimonial} />)}
          </section>
        </motion.div>
      </section>

      <section className="intro-section" id="how-it-works">
        <div className="section-wide editorial-grid">
          <motion.div
            className="editorial-copy"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.25 }}
            variants={stagger}
          >
            <motion.span className="eyebrow" variants={fadeUp} custom={0}>Hear the difference</motion.span>
            <motion.h2 variants={fadeUp} custom={0.08}>Natural voices. <em>Natural rhythm.</em></motion.h2>
            <motion.p variants={fadeUp} custom={0.16}>
              Listen to ultra-realistic Vietnamese voices with accurate pronunciation and sentence rhythm, then customize every lesson around your accent, goals, and pace. That&apos;s what makes VietBuddy the best Vietnamese learning app for real conversations.
            </motion.p>
            <motion.div className="feature-list" variants={stagger}>
              <motion.div variants={fadeUp} custom={0}><FeatureItem icon="ear" tone="red" title="Natural, ultra-realistic voices" copy="Hear Vietnamese with human detail, not a synthetic sound." /></motion.div>
              <motion.div variants={fadeUp} custom={0.08}><FeatureItem icon="wave" tone="amber" title="Pronunciation and rhythm" copy="Follow accurate sounds and natural sentence rhythm." /></motion.div>
              <motion.div variants={fadeUp} custom={0.16}><FeatureItem icon="mic" tone="green" title="Fully customizable lessons" copy="Choose your accent, topic, level, and pace." /></motion.div>
            </motion.div>
          </motion.div>
          <motion.div
            className="editorial-art editorial-art--lesson"
            initial={{ opacity: 0, x: 35 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, amount: 0.25 }}
            transition={{ type: "spring", stiffness: 120, damping: 18 }}
          >
            <div className="art-card art-card--red">
              <span className="art-card__eyebrow">Today&apos;s circuit</span>
              <strong>Order an iced coffee and change the sweetness</strong>
              <div className="art-card__footer"><span>7 rounds</span><span>+20 XP</span></div>
              <div className="art-card__mascot"><Image src="/be-trau-buddy.png" width={160} height={160} alt="Bé Trâu on a daily lesson card" /></div>
            </div>
            <div className="art-sticker art-sticker--check"><Check weight="bold" /><span>custom lesson</span></div>
            <div className="art-sticker art-sticker--time"><Clock weight="fill" /><span>5–10 min</span></div>
          </motion.div>
        </div>
      </section>

      <section className="science-section" id="inside">
        <div className="section-wide editorial-grid editorial-grid--reverse">
          <motion.div
            className="editorial-art editorial-art--listen"
            initial={{ opacity: 0, x: -35 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, amount: 0.25 }}
            transition={{ type: "spring", stiffness: 120, damping: 18 }}
          >
            <div className="listen-card">
              <div className="listen-card__head"><span className="listen-card__tag">Cold listen</span><span>01 / 03</span></div>
              <h3>What&apos;s happening?</h3>
              <p>Let your ears make the first guess.</p>
              <div className="listen-card__voice"><div className="voice-orbit"><Image src="/be-trau-buddy.png" width={125} height={125} alt="Bé Trâu speaking in a listening exercise" /></div><div className="voice-lines"><i /><i /><i /><i /><i /><i /><i /><i /><i /></div><span><SpeakerHigh weight="fill" /> Natural speed</span></div>
              <div className="answer-row"><span /><strong>Order an iced coffee</strong></div>
              <div className="answer-row"><span /><strong>Ask for directions</strong></div>
            </div>
            <div className="listen-note"><Waveform weight="bold" /><span><strong>Backed by your ears</strong><small>Text comes after the first guess.</small></span></div>
          </motion.div>
          <motion.div
            className="editorial-copy"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.25 }}
            variants={stagger}
          >
            <motion.span className="eyebrow" variants={fadeUp} custom={0}>A different first step</motion.span>
            <motion.h2 variants={fadeUp} custom={0.08}>Listen first. <em>Understand faster.</em></motion.h2>
            <motion.p variants={fadeUp} custom={0.16}>
              Your brain is already good at finding patterns. VietBuddy gives it something worth noticing: a real voice, a clear situation, and just enough help to connect the dots.
            </motion.p>
            <motion.a className="text-link" href="#get-vietbuddy" variants={fadeUp} custom={0.24}>See the method <ArrowRight weight="bold" /></motion.a>
          </motion.div>
        </div>
      </section>

      <section className="motivation-section">
        <div className="section-wide editorial-grid">
          <motion.div
            className="editorial-copy"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.25 }}
            variants={stagger}
          >
            <motion.span className="eyebrow eyebrow--light" variants={fadeUp} custom={0}>Stay motivated</motion.span>
            <motion.h2 variants={fadeUp} custom={0.08}>Make a habit of <em>showing up.</em></motion.h2>
            <motion.p variants={fadeUp} custom={0.16}>
              A small streak, a clean progress bar, and a buddy who remembers what you are working on. The reward is feeling more ready the next time someone speaks Vietnamese near you.
            </motion.p>
            <motion.div className="motivation-points" variants={stagger}>
              <motion.div variants={fadeUp} custom={0}><Fire weight="fill" /><span><strong>Daily streaks</strong><small>Keep your momentum visible.</small></span></motion.div>
              <motion.div variants={fadeUp} custom={0.08}><Star weight="fill" /><span><strong>Small rewards</strong><small>Every round moves the bar.</small></span></motion.div>
              <motion.div variants={fadeUp} custom={0.16}><Lightning weight="fill" /><span><strong>Smart review</strong><small>Wobbly phrases find you again.</small></span></motion.div>
            </motion.div>
          </motion.div>
          <motion.div
            className="motivation-art"
            initial={{ opacity: 0, y: 30, scale: .96 }}
            whileInView={{ opacity: 1, y: 0, scale: 1 }}
            viewport={{ once: true, amount: 0.25 }}
            transition={{ type: "spring", stiffness: 130, damping: 18 }}
          >
            <div className="streak-card">
              <div className="streak-card__top"><span><Fire weight="fill" /> 7</span><small>day streak</small></div>
              <div className="streak-days"><i /><i /><i /><i /><i /><i /><i className="is-today" /></div>
              <div className="streak-card__bottom"><span><strong>26</strong><small>minutes this week</small></span><span><strong>4</strong><small>sessions finished</small></span></div>
            </div>
            <Image src="/be-trau-buddy.png" width={330} height={330} alt="Bé Trâu celebrates a learning streak" />
            <div className="motivation-bubble"><Check weight="bold" /><span><strong>Good loop</strong><small>One more round today</small></span></div>
          </motion.div>
        </div>
      </section>

      <section className="personal-section">
        <div className="section-wide editorial-grid editorial-grid--reverse">
          <motion.div
            className="personal-art"
            initial={{ opacity: 0, x: -35 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, amount: 0.25 }}
            transition={{ type: "spring", stiffness: 120, damping: 18 }}
          >
            <PhoneFrame src="/screenshots/profile.PNG" alt="VietBuddy profile showing recent listening progress" tilt="left" />
            <div className="personal-stat personal-stat--one"><Globe weight="fill" /><span><strong>Southern</strong><small>Your voice, your pace</small></span></div>
            <div className="personal-stat personal-stat--two"><Lightning weight="fill" /><span><strong>26 min</strong><small>this week</small></span></div>
          </motion.div>
          <motion.div
            className="editorial-copy"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.25 }}
            variants={stagger}
          >
            <motion.span className="eyebrow" variants={fadeUp} custom={0}>Personalized learning</motion.span>
            <motion.h2 variants={fadeUp} custom={0.08}>Your sound. <em>Your pace.</em></motion.h2>
            <motion.p variants={fadeUp} custom={0.16}>
              Choose Northern or Southern Vietnamese, set a routine that fits your day, and let the app remember the phrases that deserve another pass.
            </motion.p>
            <motion.div className="accent-toggle" variants={fadeUp} custom={0.24} role="tablist" aria-label="Choose a Vietnamese accent">
              <button className={accent === "north" ? "is-active" : ""} type="button" role="tab" aria-selected={accent === "north"} onClick={() => setAccent("north")}>Northern</button>
              <button className={accent === "south" ? "is-active" : ""} type="button" role="tab" aria-selected={accent === "south"} onClick={() => setAccent("south")}>Southern</button>
            </motion.div>
            <motion.p className="accent-caption" variants={fadeUp} custom={0.3}><SpeakerHigh weight="fill" /> {accent === "north" ? "Hà Nội voice | crisp tones, standard phrasing." : "Sài Gòn voice | warm, relaxed, everyday speech."}</motion.p>
          </motion.div>
        </div>
      </section>

      <section className="faq-section">
        <div className="section-wide faq-section__inner">
          <motion.div className="faq-section__intro" initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.25 }} variants={stagger}>
            <motion.span className="eyebrow" variants={fadeUp} custom={0}>Good questions</motion.span>
            <motion.h2 variants={fadeUp} custom={0.08}>Before you <em>start listening.</em></motion.h2>
            <motion.p variants={fadeUp} custom={0.16}>Need something else? <Link href="/support">Talk to us.</Link></motion.p>
          </motion.div>
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.25 }} variants={fadeUp} custom={0.1}><FAQ /></motion.div>
        </div>
      </section>

      <section className="download-cta" id="get-vietbuddy">
        <div className="section-wide">
          <motion.div className="download-cta__inner" initial="hidden" whileInView="visible" viewport={{ once: true, amount: 0.3 }} variants={stagger}>
            <div className="download-cta__deco" aria-hidden="true" />
            <motion.div className="download-cta__copy" variants={fadeUp} custom={0}>
              <span className="eyebrow eyebrow--light">Start with seven minutes</span>
              <h2>Learn Vietnamese <em>for real life.</em></h2>
              <p>See why VietBuddy is the best Vietnamese learning app for real-life conversations. Choose your accent, set your pace, and make the next conversation feel closer.</p>
              <a className="app-store-link app-store-link--cta" href={appStoreHref("cta")} target="_blank" rel="noreferrer nofollow" aria-label="Download VietBuddy on the App Store"><AppleLogo weight="fill" /><span><small>Download now on the</small><strong>App Store</strong></span><ArrowRight weight="bold" /></a>
            </motion.div>
            <motion.div className="download-cta__mascot" variants={{ hidden: { opacity: 0, y: 28, scale: .96 }, visible: { opacity: 1, y: 0, scale: 1, transition: { type: "spring", stiffness: 160, damping: 18 } } }}><Image src="/be-trau-buddy.png" width={240} height={240} alt="Bé Trâu welcomes you to VietBuddy" /></motion.div>
          </motion.div>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
