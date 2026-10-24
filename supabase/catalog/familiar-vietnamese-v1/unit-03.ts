import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const unitOrder = 3;
const unitSlug = "join-social-life";
const unitTitle = "Join social life";

export const unit03: LessonSpec[] = [
  {
    order: 11,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Welcome someone in",
    scenario: "Receive an older friend visiting your home for the first time.",
    difficulty: 2.65,
    rounds: [
      r(
        "Invite your guest to come inside.",
        "Come in, please.",
        "Give a warm, natural invitation to enter.",
        [s("Dạ,", "yes, politely"), s("chị vào nhà đi.", "come inside")],
      ),
      r(
        "Offer a comfortable place to sit.",
        "Sit here; it’s cooler.",
        "Guide your guest to a comfortable seat.",
        [s("Chị ngồi đây", "sit here"), s("cho mát nha.", "where it’s cooler")],
        [s("Chị ngồi đây", "sit here"), s("cho mát ạ.", "where it’s cooler")],
      ),
      r(
        "Offer a choice of drinks.",
        "Would you like tea or water?",
        "Offer two drink choices without sounding formal.",
        [s("Chị uống trà", "would you like tea"), s("hay nước?", "or water?")],
      ),
      r(
        "Respond when your guest offers to help.",
        "No need, I’m almost done.",
        "Politely decline help and reassure your guest.",
        [s("Không cần đâu chị,", "no need"), s("em làm gần xong rồi.", "I’m almost done")],
      ),
      r(
        "Encourage your guest to relax.",
        "Make yourself at home, okay?",
        "End with a warm invitation to relax.",
        [s("Chị cứ tự nhiên", "make yourself at home"), s("nha.", "okay")],
        [s("Chị cứ tự nhiên", "make yourself at home"), s("nhé.", "okay")],
      ),
    ],
  },
  {
    order: 12,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Be a thoughtful guest",
    scenario: "Visit a friend’s apartment and follow the household routine.",
    difficulty: 2.7,
    rounds: [
      r(
        "Ask what to do with your shoes.",
        "Where should I leave my shoes?",
        "Ask about the household routine.",
        [s("Mình để giày", "I should leave my shoes"), s("ở đâu vậy?", "where?")],
      ),
      r(
        "Check whether your friend wants the door closed.",
        "Should I close the door?",
        "Ask before changing something in the home.",
        [s("Mình đóng cửa lại", "I should close the door"), s("nha?", "okay?")],
        [s("Mình đóng cửa lại", "I should close the door"), s("nhé?", "okay?")],
      ),
      r(
        "Offer the small gift you brought.",
        "I brought you a little fruit.",
        "Give the host your small gift naturally.",
        [
          s("Mình có mua", "I bought"),
          s("ít trái cây", "a little fruit"),
          s("cho bạn nè.", "for you"),
        ],
        [
          s("Mình có mua", "I bought"),
          s("ít hoa quả", "a little fruit"),
          s("cho bạn này.", "for you"),
        ],
      ),
      r(
        "Offer to help before the meal.",
        "Do you need me to help with anything?",
        "Make a useful offer of help.",
        [s("Bạn có cần", "do you need"), s("mình phụ gì không?", "me to help with anything?")],
        [s("Bạn có cần", "do you need"), s("mình giúp gì không?", "me to help with anything?")],
      ),
      r(
        "Thank your friend as you settle in.",
        "Thanks, your place feels really cozy.",
        "Give a specific, natural compliment.",
        [s("Cảm ơn nha,", "thanks"), s("nhà bạn ấm cúng ghê.", "your place feels really cozy")],
        [s("Cảm ơn nhé,", "thanks"), s("nhà bạn ấm cúng thật.", "your place feels really cozy")],
      ),
    ],
  },
  {
    order: 13,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Handle a phone call",
    scenario: "Call an older colleague while you are on a noisy street.",
    difficulty: 2.75,
    rounds: [
      r(
        "Check whether the connection is clear.",
        "Hello, can you hear me clearly?",
        "Open the call and check the sound.",
        [s("A lô,", "hello"), s("anh nghe rõ em không?", "can you hear me clearly?")],
      ),
      r(
        "Explain the noise on your end.",
        "I’m outside, so it’s a little noisy.",
        "Explain why the call is hard to hear.",
        [s("Em đang ở ngoài đường", "I’m outside"), s("nên hơi ồn.", "so it’s a little noisy")],
      ),
      r(
        "Ask whether this is a good time.",
        "Are you free to talk right now?",
        "Check whether the other person can talk.",
        [s("Bây giờ anh", "right now, are you"), s("nói chuyện được không?", "free to talk?")],
      ),
      r(
        "Offer an alternative when they are busy.",
        "If you’re busy, I’ll call back later.",
        "Respond flexibly to their schedule.",
        [s("Nếu anh đang bận", "if you’re busy"), s("thì lát em gọi lại.", "I’ll call back later")],
      ),
      r(
        "Leave the essential information before ending.",
        "I’ll send you the address by message.",
        "Say how you will send the details.",
        [s("Em nhắn địa chỉ", "I’ll send the address by message"), s("cho anh nha.", "to you")],
        [s("Em nhắn địa chỉ", "I’ll send the address by message"), s("cho anh nhé.", "to you")],
      ),
    ],
  },
  {
    order: 14,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Give a real opinion",
    scenario: "Recommend a neighborhood restaurant to a friend.",
    difficulty: 2.8,
    rounds: [
      r(
        "Give your overall opinion of the restaurant.",
        "I think that place is pretty good.",
        "Open with a measured opinion.",
        [s("Theo mình thì", "I think"), s("quán đó khá ổn.", "that place is pretty good")],
      ),
      r(
        "Explain what makes it worth visiting.",
        "The food is good, and the prices are reasonable.",
        "Support the opinion with two details.",
        [
          s("Đồ ăn ngon", "the food is good"),
          s("mà giá cũng vừa phải.", "and the prices are reasonable"),
        ],
      ),
      r(
        "Mention one drawback honestly.",
        "It gets crowded, especially in the evening.",
        "Add a realistic drawback.",
        [
          s("Có điều quán hơi đông,", "the only thing is it gets crowded"),
          s("nhất là buổi tối.", "especially in the evening"),
        ],
      ),
      r(
        "Recommend the best time based on that drawback.",
        "If you go early, you won’t have to wait long.",
        "Turn the drawback into practical advice.",
        [s("Bạn đi sớm", "if you go early"), s("thì khỏi đợi lâu.", "you won’t have to wait long")],
      ),
      r(
        "Offer a personal favorite from the menu.",
        "If it were me, I’d try their grilled chicken.",
        "Finish with a specific recommendation.",
        [
          s("Nếu là mình", "if it were me"),
          s("thì mình thử", "I’d try"),
          s("gà nướng ở đó.", "their grilled chicken"),
        ],
      ),
    ],
  },
  {
    order: 15,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Spend an evening together",
    scenario: "Welcome a friend, catch up, and suggest what to do next.",
    difficulty: 2.85,
    rounds: [
      r(
        "Welcome your friend after they arrive.",
        "Come in—have you been waiting long?",
        "Welcome them and check on the delay.",
        [s("Vào đi,", "come in"), s("bạn đợi lâu chưa?", "have you been waiting long?")],
      ),
      r(
        "Explain why you were not ready sooner.",
        "I just got home, so I haven’t tidied up yet.",
        "Give a natural explanation without over-apologizing.",
        [
          s("Mình mới về tới", "I just got home"),
          s("nên chưa dọn kịp.", "so I haven’t tidied up yet"),
        ],
      ),
      r(
        "Offer something while you both settle down.",
        "Sit for a bit; I’ll get us some water.",
        "Combine a suggestion with what you will do.",
        [
          s("Ngồi chơi chút đi,", "sit for a bit"),
          s("mình lấy nước cho.", "I’ll get us some water"),
        ],
      ),
      r(
        "Ask for your friend’s opinion about dinner.",
        "What do you feel like eating tonight?",
        "Invite your friend to choose the direction.",
        [s("Tối nay", "tonight"), s("bạn muốn ăn gì?", "what do you feel like eating?")],
      ),
      r(
        "Make a flexible suggestion based on their answer.",
        "If you don’t mind, let’s try the place near my building.",
        "Suggest a nearby option while leaving room to disagree.",
        [
          s("Nếu bạn không ngại", "if you don’t mind"),
          s("thì mình thử quán", "let’s try the place"),
          s("gần nhà nha.", "near my building"),
        ],
        [
          s("Nếu bạn không ngại", "if you don’t mind"),
          s("thì mình thử quán", "let’s try the place"),
          s("gần nhà nhé.", "near my building"),
        ],
      ),
    ],
  },
];
