import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 1;
const unitSlug = "sound-natural";
const unitTitle = "Sound natural, not translated";

export const unit01: LessonSpec[] = [
  {
    order: 1, unitOrder, unitSlug, unitTitle,
    title: "Choose how to address someone",
    scenario: "Adjust pronouns naturally as relationships and settings change.",
    difficulty: 4.05,
    rounds: [
      p("Ask an older acquaintance whether she remembers you.", "Do you remember me? We met at Aunt Lan’s house.", "Address her as an older sister.", "Chị còn nhớ em không?|Mình gặp nhau ở nhà cô Lan đó.", "do you remember me|we met at Aunt Lan’s house"),
      p("Speak warmly to a younger cousin.", "Have you finished school yet, or are you still studying?", "Switch to an older-relative voice.", "Em học xong chưa,|hay vẫn còn đang học?", "have you finished school yet|or are you still studying"),
      p("Ask a same-age stranger for a small favor.", "Could you watch my bag for a moment?", "Use a neutral peer address.", "Bạn trông giùm mình cái túi|một chút được không?", "could you watch my bag for me|for a moment"),
      p("Speak politely to a friend’s mother.", "Auntie, let me carry that inside for you.", "Offer help using a respectful family-style address.", "Cô để con xách cái đó|vô trong cho cô.", "auntie, let me carry that|inside for you", "Cô để cháu xách cái đó|vào trong cho cô ạ.", "auntie, let me carry that|inside for you"),
      p("Explain why you changed pronouns.", "He’s older than me, so I call him anh even though we work together.", "Explain a relationship-based pronoun choice.", "Anh ấy lớn hơn mình,|nên làm chung mình vẫn gọi là anh.", "he’s older than me|so I call him anh even though we work together"),
    ],
  },
  {
    order: 2, unitOrder, unitSlug, unitTitle,
    title: "Use particles with intention",
    scenario: "Change the emotional tone of a message with everyday particles.",
    difficulty: 4.1,
    rounds: [
      p("Remind a friend gently.", "Remember to call me when you get home, okay?", "Use a warm reminder rather than an order.", "Về tới nhà|nhớ gọi mình nha.", "when you get home|remember to call me", "Về đến nhà|nhớ gọi mình nhé.", "when you get home|remember to call me"),
      p("Challenge an assumption lightly.", "You said you weren’t coming, didn’t you?", "Use chứ to call back shared information.", "Bạn nói là|không đi chứ?", "you said|you weren’t coming, didn’t you"),
      p("Insist that something is genuinely true.", "It really is good; I’m not exaggerating.", "Use mà to reinforce your point.", "Ngon thiệt mà,|mình đâu có nói quá.", "it really is good|I’m not exaggerating", "Ngon thật mà,|mình đâu có nói quá.", "it really is good|I’m not exaggerating"),
      p("Point out a consequence with emphasis.", "See? I told you it would rain.", "Use đó or đấy to underline the result.", "Thấy chưa,|mình nói trời sẽ mưa mà.", "see|I told you it would rain", "Thấy chưa,|mình bảo trời sẽ mưa mà.", "see|I told you it would rain"),
      p("Seek friendly agreement.", "This place feels much nicer in the evening, doesn’t it?", "Use a regional tag naturally.", "Tối ở đây|dễ chịu hơn nhiều ha?", "in the evening this place|feels much nicer, doesn’t it", "Buổi tối ở đây|dễ chịu hơn nhiều nhỉ?", "in the evening this place|feels much nicer, doesn’t it"),
    ],
  },
  {
    order: 3, unitOrder, unitSlug, unitTitle,
    title: "Say less and mean more",
    scenario: "Follow and produce natural speech where obvious words disappear.",
    difficulty: 4.15,
    rounds: [
      p("Answer a family member asking whether you ate.", "I already did. What about you?", "Reply without repeating the full verb phrase.", "Con ăn rồi.|Còn mẹ?", "I already did|what about you", "Con ăn rồi ạ.|Còn mẹ?", "I already did|what about you"),
      p("Turn down another serving naturally.", "I’m full; I really can’t eat any more.", "Let context carry the omitted object.", "Con no rồi,|ăn thêm không nổi đâu.", "I’m full|I really can’t eat any more", "Cháu no rồi ạ,|không ăn thêm được đâu.", "I’m full|I really can’t eat any more"),
      p("Ask whether someone completed a shared task.", "Is it done yet? If not, I’ll handle it.", "Use a short context-dependent question.", "Xong chưa?|Chưa thì để mình làm cho.", "is it done yet|if not, I’ll handle it"),
      p("Tell a friend to take whichever item they prefer.", "Take whichever one you like; either is fine.", "Avoid restating the item unnecessarily.", "Thích cái nào lấy cái đó,|cái nào cũng được.", "take whichever one you like|either is fine"),
      p("Understand a compact departure exchange.", "Are you leaving already? Yes, I have an early morning tomorrow.", "Produce both sides of a compressed exchange.", "Về rồi hả?|Ừ, mai dậy sớm.", "are you leaving already|yes, I have an early morning tomorrow", "Về rồi à?|Ừ, mai phải dậy sớm.", "are you leaving already|yes, I have an early morning tomorrow"),
    ],
  },
  {
    order: 4, unitOrder, unitSlug, unitTitle,
    title: "React in the moment",
    scenario: "Use quick reactions and backchannels while someone else is speaking.",
    difficulty: 4.2,
    rounds: [
      p("Show that surprising news makes sense now.", "Oh, so that’s why you left early.", "React with sudden understanding.", "À, hèn chi|bạn về sớm.", "oh, so that’s why|you left early", "À, bảo sao|bạn về sớm.", "oh, so that’s why|you left early"),
      p("Encourage someone to continue.", "Really? And then what happened?", "Show interest without taking over the story.", "Vậy hả?|Rồi sao nữa?", "really|and then what happened", "Thế à?|Rồi sao nữa?", "really|and then what happened"),
      p("Signal sympathetic disbelief.", "Seriously? That’s such bad luck.", "React to an unfortunate twist.", "Thiệt luôn?|Xui dữ vậy.", "seriously|that’s such bad luck", "Thật à?|Đen đủi thế.", "seriously|that’s such bad luck"),
      p("Acknowledge a nuanced explanation.", "Right, I get what you mean now.", "Show that the point has landed.", "Ừ, giờ mình hiểu|ý bạn nói rồi.", "right, now I understand|what you mean"),
      p("React without fully agreeing.", "I see your point, but I’m still not entirely convinced.", "Acknowledge first and preserve your position.", "Nghe cũng có lý,|mà mình vẫn chưa tin hẳn.", "I see your point|but I’m still not entirely convinced"),
    ],
  },
  {
    order: 5, unitOrder, unitSlug, unitTitle,
    title: "Shift register smoothly",
    scenario: "Adapt one message for a friend, an elder, and a professional setting.",
    difficulty: 4.25,
    rounds: [
      p("Tell a close friend you cannot attend.", "I’m tied up tonight, so I can’t make it.", "Deliver the casual version.", "Tối nay mình kẹt rồi,|không qua được đâu.", "I’m tied up tonight|so I can’t make it", "Tối nay mình bận mất rồi,|không qua được đâu.", "I’m tied up tonight|so I can’t make it"),
      p("Tell an aunt the same thing respectfully.", "I’m sorry, Auntie, I’m busy tonight, so I can’t come over.", "Add warmth and deference for an elder.", "Dạ, tối nay con bận,|nên không qua nhà cô được.", "I’m sorry, Auntie, I’m busy tonight|so I can’t come over", "Dạ, tối nay cháu bận,|nên không qua nhà cô được ạ.", "I’m sorry, Auntie, I’m busy tonight|so I can’t come over"),
      p("Decline a work meeting formally.", "I have another commitment at that time, so I can’t attend.", "Use a concise professional register.", "Thời gian đó tôi có lịch khác,|nên không thể tham dự.", "I have another commitment at that time|so I can’t attend"),
      p("Ask a friend to send something again.", "Send that to me again when you have a chance.", "Make a relaxed peer request.", "Rảnh thì gửi lại|cho mình cái đó nha.", "when you have a chance, send|that to me again", "Rảnh thì gửi lại|cho mình cái đó nhé.", "when you have a chance, send|that to me again"),
      p("Ask a client for the same action.", "Could you please resend the document when convenient?", "Use a polished but natural request.", "Khi tiện, anh gửi lại|tài liệu giúp tôi được không?", "when convenient, could you resend|the document for me"),
    ],
  },
];
