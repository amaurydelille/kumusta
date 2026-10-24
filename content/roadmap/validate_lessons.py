"""Validate Kumusta Cantonese roadmap lesson files.

Usage: venv/bin/python validate_lessons.py FILE [FILE ...]
Errors are structural and must be fixed. Warnings are Jyutping readings that
differ from PyCantonese (often fine: n/l lazy readings, polyphones) and
Standard Written Chinese markers; review each one.
"""
import json
import re
import sys
import warnings

warnings.filterwarnings("ignore")
import opencc  # noqa: E402
import pycantonese  # noqa: E402

T2S = opencc.OpenCC("t2s")
S2T = opencc.OpenCC("s2t")
HAN = re.compile(r"[㐀-䶿一-鿿\U00020000-\U0002ffff]")
LATIN = re.compile(r"[A-Za-z][A-Za-z'\-]*")
SYL = re.compile(
    r"^(b|p|m|f|d|t|n|l|g|k|ng|h|gw|kw|w|z|c|s|j)?"
    r"(aa|a|e|i|o|u|oe|eo|yu|m|ng)(i|u|p|t|k|m|n|ng)?[1-6]$"
)
HK_OK = set("晒咁吓")  # standard Hong Kong forms OpenCC maps elsewhere
SWC = ["他", "她", "不", "的", "了", "在", "沒有", "這", "那", "什麼", "是"]
ALLOWED_SWC_WORDS = ["利是", "不過", "的士", "了解", "實在", "存在", "現在", "是但", "那麼", "這樣", "不如", "目的", "真的", "不斷", "不錯", "不好意思", "自在", "在意", "了不起", "不停"]
LAZY = {("n", "l"), ("l", "n"), ("ng", ""), ("", "ng")}

errors, warns = [], []


def err(where, msg):
    errors.append(f"ERROR {where}: {msg}")


_seen_warn = set()


def warn(where, msg):
    key = (where.split(" ")[0], msg.split(" in ")[0])
    if key not in _seen_warn:
        _seen_warn.add(key)
        warns.append(f"warn  {where}: {msg}")


def han_count(text):
    return len(HAN.findall(text))


def check_pair(where, text, jp):
    if not text or not isinstance(text, str):
        err(where, "empty Cantonese text")
        return
    if not isinstance(jp, str) or not jp.strip():
        err(where, f"missing jyutping for {text!r}")
        return
    if jp != jp.strip() or "  " in jp or jp != jp.lower() and not LATIN.search(jp):
        err(where, f"jyutping spacing/case: {jp!r}")
    tokens = jp.split()
    syls = [t for t in tokens if re.search(r"\d$", t)]
    latin_jp = [t for t in tokens if not re.search(r"\d$", t)]
    for s in syls:
        if not SYL.match(s):
            err(where, f"invalid jyutping syllable {s!r} in {text!r}")
    if han_count(text) != len(syls):
        err(where, f"{han_count(text)} Han chars vs {len(syls)} syllables: {text!r} / {jp!r}")
    latin_text = LATIN.findall(text)
    if [w.lower() for w in latin_text] != [w.lower() for w in latin_jp]:
        err(where, f"Latin tokens differ: text {latin_text} vs jyutping {latin_jp}")
    # Simplified characters
    for ch in HAN.findall(text):
        if ch not in HK_OK and S2T.convert(ch) != ch and T2S.convert(ch) == ch:
            err(where, f"Simplified character {ch!r} in {text!r}")
    # Compare readings with PyCantonese (warnings only)
    ref = []
    for word, reading in pycantonese.characters_to_jyutping(text):
        hans = HAN.findall(word)
        if not hans:
            continue
        parsed = re.findall(r"[a-z]+[1-6]", reading or "")
        if reading and len(parsed) == len(hans):
            ref.extend(parsed)
        else:
            ref.extend([None] * len(hans))
    hans = HAN.findall(text)
    if len(ref) == len(syls):
        for ch, mine, theirs in zip(hans, syls, ref):
            if theirs and mine != theirs and not lazy_equal(mine, theirs):
                warn(where, f"{ch} {mine} (lexicon {theirs}) in {text!r}")


def lazy_equal(a, b):
    ia, ib = initial(a), initial(b)
    return a[len(ia):] == b[len(ib):] and (ia, ib) in LAZY


def initial(s):
    m = re.match(r"(ng|gw|kw|[bpmfdtnlgkhwzcsj])?", s)
    return m.group(0) or ""


def check_swc(where, text):
    t = text
    for w in ALLOWED_SWC_WORDS:
        t = t.replace(w, "")
    hits = [m for m in SWC if m in t]
    if hits:
        warn(where, f"Standard Written Chinese markers {hits} in {text!r}")


def check_english(where, text):
    if not isinstance(text, str) or not text.strip():
        err(where, "empty English field")
    elif HAN.search(text):
        err(where, f"Han characters in English field: {text!r}")


def strip_punct(s):
    return re.sub(r"[\s，。！？、「」『』：；…,.!?]", "", s)


def check_lesson(lesson, idx, seen):
    lid = lesson.get("slug", f"#{idx}")
    for key in ["id", "slug", "summary", "level", "estimatedMinutes", "sortOrder", "contentVersion",
                "roadmapVersion", "unitSlug", "unitTitle", "unitOrder", "lessonOrder", "schemaVersion",
                "promptVersion", "difficulty", "contentSource", "reviewStatus", "goalTags", "content"]:
        if key not in lesson:
            err(lid, f"missing {key}")
    if lesson.get("id") in seen:
        err(lid, "duplicate id")
    seen.add(lesson.get("id"))
    c = lesson.get("content", {})
    for key in ["title", "scenarioKey", "scenario", "minutes", "difficulty", "rounds", "vocabulary"]:
        if key not in c:
            err(lid, f"content missing {key}")
    for key in ["title", "scenario"]:
        check_english(lid, c.get(key))
    rounds = c.get("rounds", [])
    if len(rounds) != 5:
        err(lid, f"{len(rounds)} rounds (want 5)")
    for i, r in enumerate(rounds):
        w = f"{lid} r{i + 1}"
        text = r.get("cantonese", "")
        check_pair(w, text, r.get("jyutping"))
        check_swc(w, text)
        for key in ["situation", "translation", "speakingPrompt"]:
            check_english(w, r.get(key))
        chunks = r.get("chunks", [])
        if not 1 <= len(chunks) <= 4:
            err(w, f"{len(chunks)} chunks")
        pos = 0
        for ch in chunks:
            check_pair(w + " chunk", ch.get("cantonese", ""), ch.get("jyutping"))
            check_english(w + " chunk", ch.get("english"))
            if not str(ch.get("note", "")).strip():
                err(w, "empty chunk note")
            found = text.find(ch.get("cantonese", "\0"), pos)
            if found < 0:
                err(w, f"chunk {ch.get('cantonese')!r} is not an ordered substring of {text!r}")
            else:
                pos = found + len(ch["cantonese"])
        glosses = r.get("wordGlosses", [])
        joined = "".join(g.get("token", "") for g in glosses)
        if strip_punct(joined) != strip_punct(text):
            err(w, f"glosses {joined!r} do not rebuild {text!r}")
        for g in glosses:
            if HAN.search(g.get("token", "")) or LATIN.search(g.get("token", "")):
                check_pair(w + " gloss", g.get("token", ""), g.get("jyutping"))
                check_english(w + " gloss", g.get("english"))
        ex = r.get("responseExercise")
        if i in (2, 4):
            if not ex:
                err(w, "missing responseExercise")
            else:
                if ex.get("promptCantonese") != text or ex.get("promptJyutping") != r.get("jyutping"):
                    err(w, "responseExercise prompt must equal the round utterance and jyutping")
                if ex.get("promptTranslation") != r.get("translation"):
                    err(w, "promptTranslation must equal the round translation")
                opts = ex.get("options", [])
                if len(opts) != 3:
                    err(w, "need 3 options")
                k = ex.get("correctOptionIndex")
                if not isinstance(k, int) or not 0 <= k < len(opts) or opts[k].get("englishTranslation") != r.get("translation"):
                    err(w, "correct option must equal the translation")
                eng = [o.get("englishTranslation") for o in opts]
                if len(set(eng)) != len(eng):
                    err(w, "duplicate options")
                for e in eng:
                    check_english(w + " option", e)
        elif ex:
            err(w, "responseExercise only on rounds 3 and 5")
    vocab = c.get("vocabulary", [])
    if not 8 <= len(vocab) <= 10:
        err(lid, f"{len(vocab)} vocabulary items (want 8-10)")
    utterances = [r.get("cantonese", "") for r in rounds]
    for v in vocab:
        w = f"{lid} vocab {v.get('cantonese')}"
        check_pair(w, v.get("cantonese", ""), v.get("jyutping"))
        check_pair(w + " example", v.get("example", ""), v.get("exampleJyutping"))
        check_english(w, v.get("english"))
        check_english(w, v.get("exampleTranslation"))
        if v.get("example") not in utterances:
            err(w, "example must be one of the round utterances")
        elif v.get("cantonese", "\0") not in v.get("example"):
            err(w, "vocabulary item must appear in its example")
        else:
            r = rounds[utterances.index(v["example"])]
            if v.get("exampleJyutping") != r.get("jyutping") or v.get("exampleTranslation") != r.get("translation"):
                err(w, "example jyutping/translation must match the round")


def main():
    seen = set()
    total = 0
    for path in sys.argv[1:]:
        data = json.load(open(path, encoding="utf-8"))
        for i, lesson in enumerate(data.get("lessons", [])):
            check_lesson(lesson, i, seen)
            total += 1
    for line in errors + warns:
        print(line)
    print(f"{total} lessons, {len(errors)} errors, {len(warns)} warnings")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
