import { type LessonSpec, round as r, segment as s } from "./catalog.ts";
const unitOrder = 5, unitSlug = "talk-about-your-life", unitTitle = "Talk about your life";
export const unit05: LessonSpec[] = [
  {
    order: 21,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say what you like",
    scenario: "Share simple preferences during a friendly meal.",
    difficulty: 1.8,
    rounds: [
      r("Say that you like the dish.", "I like this dish.", "Share the simple preference.", [
        s("Mình thích", "I like"),
        s("món này.", "this dish"),
      ]),
      r("Say that you prefer coffee.", "I like coffee more.", "Compare the two choices.", [
        s("Mình thích", "I like"),
        s("cà phê hơn.", "coffee more"),
      ]),
      r(
        "Explain that you cannot eat spicy food.",
        "I can’t eat spicy food.",
        "State the useful food limit clearly.",
        [s("Mình", "I"), s("không ăn cay được.", "can’t eat spicy food")],
      ),
      r(
        "React enthusiastically to the food.",
        "This dish is so delicious.",
        "Give the natural reaction.",
        [s("Món này", "this dish"), s("ngon quá.", "is so delicious")],
      ),
      r(
        "Ask what your friend likes.",
        "What food do you like?",
        "Return the preference question.",
        [s("Còn bạn", "how about you"), s("thích món gì?", "what food do you like?")],
      ),
    ],
  },
  {
    order: 22,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say what you want",
    scenario: "Suggest food, places, and a shared activity.",
    difficulty: 1.85,
    rounds: [
      r("Say what you want to eat.", "I want to eat pho.", "Use the want-plus-action pattern.", [
        s("Mình muốn", "I want"),
        s("ăn phở.", "to eat pho"),
      ]),
      r(
        "Say where you want to go.",
        "I want to go to the market.",
        "Add a destination after the action.",
        [s("Mình muốn", "I want"), s("đi chợ.", "to go to the market")],
      ),
      r("Say what you need to buy.", "I need to buy water.", "State the practical need.", [
        s("Mình cần", "I need"),
        s("mua nước.", "to buy water"),
      ]),
      r(
        "Ask where your friend wants to go.",
        "Where do you want to go?",
        "Ask the matching question.",
        [s("Bạn muốn", "you want"), s("đi đâu?", "to go where?")],
      ),
      r("Suggest going together.", "Then let’s go together.", "End with the friendly suggestion.", [
        s("Vậy", "then"),
        s("mình đi cùng nha.", "let’s go together"),
      ], [s("Thế", "then"), s("mình đi cùng nhé.", "let’s go together")]),
    ],
  },
  {
    order: 23,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Share where you live",
    scenario: "Trade a few facts about home, work, and study.",
    difficulty: 1.9,
    rounds: [
      r("Say where you live.", "I live in Paris.", "Give the short personal fact.", [
        s("Mình sống", "I live"),
        s("ở Paris.", "in Paris"),
      ]),
      r(
        "Say that you work from home.",
        "I work from home.",
        "Keep the workplace phrase together.",
        [s("Mình", "I"), s("làm việc ở nhà.", "work from home")],
      ),
      r(
        "Say what you are currently studying.",
        "I’m studying Vietnamese.",
        "Use the ongoing-action pattern.",
        [s("Mình đang học", "I’m studying"), s("tiếng Việt.", "Vietnamese")],
      ),
      r("Ask where your friend lives.", "Where do you live?", "Ask the personal question warmly.", [
        s("Bạn", "you"),
        s("sống ở đâu?", "live where?"),
      ]),
      r(
        "Ask what kind of work your friend does.",
        "What do you do for work?",
        "Ask the common work question.",
        [s("Bạn", "you"), s("làm nghề gì?", "do what work?")],
      ),
    ],
  },
  {
    order: 24,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Make a simple plan",
    scenario: "Invite a friend for coffee and agree on a time.",
    difficulty: 1.95,
    rounds: [
      r(
        "Ask whether your friend is free today.",
        "Are you free today?",
        "Open the invitation gently.",
        [s("Hôm nay", "today"), s("bạn có rảnh không?", "are you free?")],
      ),
      r(
        "Suggest coffee tomorrow.",
        "Shall we get coffee tomorrow?",
        "Make the casual suggestion.",
        [s("Ngày mai", "tomorrow"), s("mình đi uống cà phê nha?", "shall we get coffee?")],
        [s("Ngày mai", "tomorrow"), s("mình đi uống cà phê nhé?", "shall we get coffee?")],
      ),
      r("Ask what time to meet.", "What time shall we meet?", "Ask for the meeting time.", [
        s("Mấy giờ", "what time"),
        s("mình gặp nhau?", "shall we meet?"),
      ]),
      r("Suggest three o’clock.", "Does three o’clock work?", "Offer the time as a question.", [
        s("Ba giờ", "three o’clock"),
        s("được không?", "does that work?"),
      ]),
      r("Confirm tomorrow’s plan.", "Okay, see you tomorrow.", "Close the plan positively.", [
        s("Được,", "okay"),
        s("hẹn bạn ngày mai.", "see you tomorrow"),
      ]),
    ],
  },
  {
    order: 25,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Have a social exchange",
    scenario: "Move from preferences to a confirmed coffee plan.",
    difficulty: 2.0,
    rounds: [
      r(
        "Check whether your friend is free.",
        "Are you free today?",
        "Start the familiar invitation.",
        [s("Hôm nay", "today"), s("bạn có rảnh không?", "are you free?")],
      ),
      r("Say what you would like to do.", "I want to get coffee.", "State the activity simply.", [
        s("Mình muốn", "I want"),
        s("đi uống cà phê.", "to get coffee"),
      ]),
      r("Ask between coffee and tea.", "Do you like coffee or tea?", "Offer the two choices.", [
        s("Bạn thích", "do you like"),
        s("cà phê hay trà?", "coffee or tea?"),
      ]),
      r("Suggest meeting at three.", "Shall we meet at three?", "Offer the meeting time.", [
        s("Ba giờ", "at three"),
        s("mình gặp nhau nha?", "shall we meet?"),
      ], [s("Ba giờ", "at three"), s("mình gặp nhau nhé?", "shall we meet?")]),
      r("Confirm the exact time.", "Okay, see you at three.", "Finish with the confirmed plan.", [
        s("Được,", "okay"),
        s("hẹn bạn lúc ba giờ.", "see you at three"),
      ]),
    ],
  },
];
