import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const unitOrder = 4;
const unitSlug = "manage-real-life-changes";
const unitTitle = "Manage real-life changes";

export const unit04: LessonSpec[] = [
  {
    order: 16,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Arrange an appointment",
    scenario: "Call a salon to book and then adjust an appointment.",
    difficulty: 2.85,
    rounds: [
      r(
        "Tell the receptionist why you are calling.",
        "I’d like to book a haircut, please.",
        "State the service you want politely.",
        [
          s("Dạ, em muốn đặt lịch", "I’d like to book an appointment"),
          s("cắt tóc ạ.", "for a haircut"),
        ],
      ),
      r(
        "Ask about availability on a specific day.",
        "Do you have any openings on Saturday?",
        "Ask whether Saturday is available.",
        [
          s("Thứ Bảy", "on Saturday"),
          s("bên chị còn giờ trống không?", "do you have any openings?"),
        ],
      ),
      r(
        "Respond when the first time is inconvenient.",
        "Three o’clock is a little late for me.",
        "Explain why the proposed time does not quite work.",
        [
          s("Ba giờ", "three o’clock"),
          s("thì hơi trễ", "is a little late"),
          s("với em.", "for me"),
        ],
        [
          s("Ba giờ", "three o’clock"),
          s("thì hơi muộn", "is a little late"),
          s("với em.", "for me"),
        ],
      ),
      r(
        "Ask for a nearby alternative.",
        "Is there an earlier time?",
        "Request an earlier option politely.",
        [s("Có giờ nào", "is there any time"), s("sớm hơn không chị?", "earlier?")],
      ),
      r(
        "Confirm the final arrangement clearly.",
        "Yes, ten o’clock works. Please book that for me.",
        "Repeat the chosen time and confirm it.",
        [
          s("Dạ, mười giờ được ạ.", "yes, ten o’clock works"),
          s("Chị đặt giúp em nha.", "please book that for me"),
        ],
        [
          s("Vâng, mười giờ được ạ.", "yes, ten o’clock works"),
          s("Chị đặt giúp em nhé.", "please book that for me"),
        ],
      ),
    ],
  },
  {
    order: 17,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Share a task",
    scenario: "Coordinate a small project with a classmate.",
    difficulty: 2.9,
    rounds: [
      r(
        "Propose a simple division of work.",
        "I’ll do the first part, and you do the second part.",
        "Divide the task clearly.",
        [
          s("Mình làm phần đầu,", "I’ll do the first part"),
          s("bạn làm phần sau nha.", "and you do the second part"),
        ],
        [
          s("Mình làm phần đầu,", "I’ll do the first part"),
          s("bạn làm phần sau nhé.", "and you do the second part"),
        ],
      ),
      r(
        "Check when your classmate can finish.",
        "When do you think you can finish?",
        "Ask for a realistic completion time.",
        [s("Bạn nghĩ", "do you think"), s("khi nào làm xong?", "when you can finish?")],
      ),
      r(
        "Explain your own constraint.",
        "I’m busy tonight, but I’ll be free tomorrow morning.",
        "Contrast tonight with tomorrow morning.",
        [
          s("Tối nay mình bận", "I’m busy tonight"),
          s("nhưng sáng mai rảnh.", "but I’ll be free tomorrow morning"),
        ],
      ),
      r(
        "Offer help if the other part becomes difficult.",
        "If that part is hard, send it to me and I’ll take a look.",
        "Make a practical offer of help.",
        [
          s("Phần đó mà khó", "if that part is hard"),
          s("thì gửi mình coi cho.", "send it to me and I’ll take a look"),
        ],
        [
          s("Phần đó mà khó", "if that part is hard"),
          s("thì gửi mình xem giúp.", "send it to me and I’ll take a look"),
        ],
      ),
      r(
        "Confirm how you will combine the work.",
        "When we’re both done, we’ll put it together.",
        "Finish with the shared next step.",
        [
          s("Khi nào cả hai làm xong", "when we’re both done"),
          s("thì ghép lại.", "we’ll put it together"),
        ],
      ),
    ],
  },
  {
    order: 18,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Explain what went wrong",
    scenario: "Ask an older coworker for help when your belongings fail you.",
    difficulty: 2.95,
    rounds: [
      r(
        "Explain that you cannot find an important item.",
        "I can’t find my wallet.",
        "State the missing item directly.",
        [
          s("Em tìm hoài", "I’ve looked everywhere"),
          s("không thấy ví.", "and can’t find my wallet"),
        ],
      ),
      r(
        "Say where you last remember having it.",
        "I still had it when I bought lunch earlier.",
        "Give the last known moment clearly.",
        [
          s("Hồi nãy mua cơm", "when I bought lunch earlier"),
          s("em vẫn còn cầm.", "I still had it"),
        ],
        [
          s("Lúc nãy mua cơm", "when I bought lunch earlier"),
          s("em vẫn còn cầm.", "I still had it"),
        ],
      ),
      r(
        "Add another problem that blocks you from calling.",
        "My phone is out of battery too.",
        "Mention the second practical problem.",
        [s("Điện thoại em", "my phone"), s("cũng hết pin rồi.", "is out of battery too")],
      ),
      r(
        "Ask to borrow something useful.",
        "Could I borrow your charger for a moment?",
        "Make a polite borrowing request.",
        [
          s("Anh cho em mượn", "could I borrow your"),
          s("cục sạc một chút", "charger for a moment"),
          s("được không?", "would that be okay?"),
        ],
        [
          s("Anh cho em mượn", "could I borrow your"),
          s("bộ sạc một chút", "charger for a moment"),
          s("được không ạ?", "would that be okay?"),
        ],
      ),
      r(
        "Say what you will do once the phone turns on.",
        "Once the phone turns on, I’ll call the restaurant.",
        "End with your plan to recover the wallet.",
        [
          s("Điện thoại lên nguồn", "once the phone turns on"),
          s("là em gọi lại quán.", "I’ll call the restaurant"),
        ],
      ),
    ],
  },
  {
    order: 19,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Ask for practical care",
    scenario: "Tell a friend you feel unwell and arrange a safe ride home.",
    difficulty: 3.0,
    rounds: [
      r(
        "Tell your friend why you need to stop walking.",
        "Wait a moment, I’m feeling a little dizzy.",
        "Ask for a pause and name the feeling.",
        [
          s("Đợi mình chút,", "wait a moment"),
          s("mình hơi chóng mặt.", "I’m feeling a little dizzy"),
        ],
      ),
      r(
        "Give a likely everyday explanation without diagnosing yourself.",
        "I may have been out in the sun too long.",
        "Offer a cautious explanation.",
        [s("Chắc mình", "maybe I"), s("đi ngoài nắng lâu quá.", "was out in the sun too long")],
      ),
      r(
        "Ask for somewhere to sit and recover.",
        "Let me sit here for a bit.",
        "Request a short rest.",
        [s("Cho mình ngồi đây", "let me sit here"), s("nghỉ chút nha.", "and rest for a bit")],
        [s("Cho mình ngồi đây", "let me sit here"), s("nghỉ chút nhé.", "and rest for a bit")],
      ),
      r(
        "Decide that going home is the sensible next step.",
        "I think I should go home early today.",
        "State the decision calmly.",
        [s("Chắc bữa nay", "I think today"), s("mình nên về sớm.", "I should go home early")],
        [s("Chắc hôm nay", "I think today"), s("mình nên về sớm.", "I should go home early")],
      ),
      r(
        "Ask your friend for concrete help.",
        "Could you help me book a car?",
        "Make one clear practical request.",
        [s("Bạn đặt xe", "could you book a car"), s("giúp mình được không?", "for me?")],
      ),
    ],
  },
  {
    order: 20,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Keep the day on track",
    scenario: "Handle delays, a dead phone, and a changed appointment.",
    difficulty: 3.05,
    rounds: [
      r(
        "Tell a friend why your schedule has slipped.",
        "My meeting ran long, so I’m running late.",
        "Connect the delay with your current situation.",
        [
          s("Cuộc họp kéo dài", "my meeting ran long"),
          s("nên mình tới trễ.", "so I’m running late"),
        ],
        [
          s("Cuộc họp kéo dài", "my meeting ran long"),
          s("nên mình đến muộn.", "so I’m running late"),
        ],
      ),
      r(
        "Explain why you could not warn them sooner.",
        "My phone died, so I couldn’t message you.",
        "Explain the communication problem.",
        [
          s("Điện thoại hết pin", "my phone died"),
          s("nên mình không nhắn được.", "so I couldn’t message you"),
        ],
      ),
      r(
        "Say what else now needs to change.",
        "I probably won’t make the three o’clock appointment.",
        "State the scheduling consequence.",
        [
          s("Chắc mình", "I probably"),
          s("không kịp lịch hẹn", "won’t make the appointment"),
          s("lúc ba giờ.", "at three o’clock"),
        ],
      ),
      r(
        "Ask your friend to take one helpful action.",
        "Could you call and move it to tomorrow for me?",
        "Ask for a specific favor.",
        [
          s("Bạn gọi dời qua mai", "could you call and move it to tomorrow"),
          s("giúp mình được không?", "for me?"),
        ],
        [
          s("Bạn gọi đổi sang ngày mai", "could you call and move it to tomorrow"),
          s("giúp mình được không?", "for me?"),
        ],
      ),
      r(
        "Confirm the recovery plan for the rest of the day.",
        "Thanks. I’ll charge my phone and come straight over.",
        "Close with thanks and two next actions.",
        [
          s("Cảm ơn bạn.", "thanks"),
          s("Mình sạc điện thoại", "I’ll charge my phone"),
          s("rồi qua liền.", "and come straight over"),
        ],
        [
          s("Cảm ơn bạn.", "thanks"),
          s("Mình sạc điện thoại", "I’ll charge my phone"),
          s("rồi qua ngay.", "and come straight over"),
        ],
      ),
    ],
  },
];
