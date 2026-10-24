import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const unitOrder = 1;
const unitSlug = "open-the-conversation";
const unitTitle = "Open the conversation";

export const unit01: LessonSpec[] = [
  {
    order: 1,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say hello to the right person",
    scenario: "Meet several people and greet each one warmly.",
    difficulty: 1.0,
    rounds: [
      r("Greet someone around your age.", "Hello.", "Give the short peer greeting.", [
        s("Chào", "hello"),
        s("bạn.", "you / friend", "Use bạn with a peer in this scene."),
      ]),
      r(
        "Greet a man slightly older than you.",
        "Hello.",
        "Use the respectful address for the man in this scene.",
        [
          s("Chào", "hello"),
          s("anh ạ.", "older man, politely", "Ạ adds respectful deference here."),
        ],
      ),
      r(
        "Greet a woman slightly older than you.",
        "Hello.",
        "Use the respectful address for the woman in this scene.",
        [
          s("Chào", "hello"),
          s("chị ạ.", "older woman, politely", "Ạ keeps the greeting respectful."),
        ],
      ),
      r(
        "Check how your new friend is doing.",
        "How are you?",
        "Ask the friendly question in one smooth line.",
        [
          s("Bạn", "you"),
          s("khỏe không?", "are you well?", "This is a friendly wellbeing question."),
        ],
      ),
      r(
        "Answer that you are well and thank your friend.",
        "I’m well, thank you.",
        "Answer warmly without pausing between the two parts.",
        [
          s("Mình khỏe,", "I’m well"),
          s("cảm ơn bạn.", "thank you", "Include bạn to keep the reply personal."),
        ],
      ),
    ],
  },
  {
    order: 2,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Exchange names",
    scenario: "Introduce yourself to a new Vietnamese friend.",
    difficulty: 1.05,
    rounds: [
      r(
        "Tell the other person your name.",
        "My name is Sam.",
        "Say the full introduction as one thought.",
        [s("Mình tên là", "my name is"), s("Sam.", "Sam")],
      ),
      r(
        "Ask your new friend’s name.",
        "What’s your name?",
        "Ask the question with a light, friendly tone.",
        [s("Bạn", "you"), s("tên gì?", "what name?", "Together this asks someone’s name.")],
      ),
      r(
        "Listen as the other person introduces herself.",
        "My name is Linh.",
        "Repeat Linh’s introduction exactly.",
        [s("Mình tên là", "my name is"), s("Linh.", "Linh")],
      ),
      r(
        "Tell your new friend you are pleased to meet.",
        "Nice to meet you.",
        "Keep the familiar phrase moving naturally.",
        [s("Rất vui", "very pleased"), s("được gặp bạn.", "to meet you")],
      ),
      r("Return the friendly feeling.", "Me too.", "Give the short natural reply.", [
        s("Mình", "me / I"),
        s("cũng vậy.", "feel the same way"),
      ]),
    ],
  },
  {
    order: 3,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Be polite naturally",
    scenario: "Handle small moments of courtesy with a new friend.",
    difficulty: 1.1,
    rounds: [
      r("Thank your friend for helping you.", "Thank you.", "Thank your friend directly.", [
        s("Cảm ơn", "thank you"),
        s("bạn nha.", "you, warmly", "Nha makes the Southern reply friendly."),
      ], [
        s("Cảm ơn", "thank you"),
        s("bạn nhé.", "you, warmly", "Nhé makes the Northern reply friendly."),
      ]),
      r("Respond when your friend thanks you.", "You’re welcome.", "Use the everyday response.", [
        s("Không", "not"),
        s(
          "có gì.",
          "anything to mention",
          "Together the phrase means there is nothing to thank you for.",
        ),
      ]),
      r("Apologize for bumping into someone.", "I’m sorry.", "Give the short sincere apology.", [
        s("Xin", "ask / offer"),
        s("lỗi nha.", "sorry", "Nha keeps a minor apology warm."),
      ], [s("Xin", "ask / offer"), s("lỗi nhé.", "sorry", "Nhé keeps a minor apology warm.")]),
      r(
        "Reassure your friend after a small mistake.",
        "It’s okay.",
        "Say the whole reassurance calmly.",
        [s("Không sao", "it’s okay"), s("đâu.", "really", "Đâu adds reassurance in this reply.")],
      ),
      r(
        "Agree politely to a simple suggestion.",
        "Yes, that works.",
        "Give the short polite agreement.",
        [s("Dạ,", "yes, politely"), s("được.", "that works")],
        [s("Vâng,", "yes, politely"), s("được ạ.", "that works, politely")],
      ),
    ],
  },
  {
    order: 4,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Say you are still learning",
    scenario: "Keep a conversation manageable when speech moves too fast.",
    difficulty: 1.15,
    rounds: [
      r(
        "Explain that you only recently started Vietnamese.",
        "I’ve only just started learning Vietnamese.",
        "Say the explanation without apologizing for learning.",
        [
          s("Mình mới học", "I just started learning"),
          s("tiếng Việt thôi.", "Vietnamese, that’s all", "Thôi keeps the claim modest."),
        ],
      ),
      r(
        "Explain how much Vietnamese you can speak.",
        "I can speak a little.",
        "Keep the modest answer light.",
        [s("Mình nói được", "I can speak"), s("một chút.", "a little")],
      ),
      r(
        "Say clearly that you have not understood.",
        "I don’t understand yet.",
        "Use the short repair phrase immediately.",
        [
          s("Mình", "I"),
          s("chưa hiểu.", "don’t understand yet", "Chưa leaves room for understanding after help."),
        ],
      ),
      r(
        "Ask the other person to slow down.",
        "Could you speak more slowly?",
        "Make the complete request politely.",
        [
          s("Bạn nói", "you speak"),
          s("chậm lại", "more slowly"),
          s("được không?", "would that be possible?"),
        ],
      ),
      r(
        "Ask your friend to repeat the sentence.",
        "Could you say that again for me?",
        "Use the full recovery request.",
        [
          s("Bạn nói lại", "say it again"),
          s("giùm mình", "for me", "Giùm is natural in many Southern requests."),
          s("được không?", "could you?"),
        ],
        [
          s("Bạn nói lại", "say it again"),
          s("giúp mình", "for me", "Giúp is natural in this Northern request."),
          s("được không ạ?", "could you, politely?"),
        ],
      ),
    ],
  },
  {
    order: 5,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Your first meeting",
    scenario: "Carry a first meeting from greeting to goodbye.",
    difficulty: 1.2,
    rounds: [
      r(
        "Open the meeting with a peer.",
        "Hello, my name is Sam.",
        "Join the greeting and introduction smoothly.",
        [s("Chào bạn,", "hello"), s("mình tên là", "my name is"), s("Sam.", "Sam")],
      ),
      r(
        "Ask the other person’s name.",
        "What’s your name?",
        "Ask the familiar question naturally.",
        [s("Còn bạn,", "and you"), s("bạn tên gì?", "what’s your name?")],
      ),
      r("Respond after hearing the name.", "Nice to meet you.", "Give the warm response.", [
        s("Rất vui", "very pleased"),
        s("được gặp bạn.", "to meet you"),
      ]),
      r(
        "Explain that you are a new learner.",
        "I’ve only just started learning Vietnamese.",
        "Use the explanation before the conversation gets faster.",
        [
          s("Mình mới học", "I just started learning"),
          s("tiếng Việt thôi.", "Vietnamese, that’s all"),
        ],
      ),
      r(
        "Close the meeting positively.",
        "Thank you. See you again.",
        "Say thanks and then the goodbye.",
        [s("Cảm ơn bạn.", "Thank you."), s("Hẹn gặp lại.", "See you again.")],
      ),
    ],
  },
];
