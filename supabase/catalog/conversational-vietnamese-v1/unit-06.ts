import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 6;
const unitSlug = "navigate-relationships";
const unitTitle = "Navigate relationships and expectations";

export const unit06: LessonSpec[] = [
  {
    order: 26, unitOrder, unitSlug, unitTitle,
    title: "Refuse without offending",
    scenario: "Decline a last-minute invitation warmly and respectfully.",
    difficulty: 4.3,
    rounds: [
      p("Show appreciation before refusing.", "Thanks for inviting me; I’d really like to come.", "Make clear that the invitation matters to you.", [["Cảm ơn bạn đã rủ,", "thanks for inviting me"], ["mình cũng muốn đi lắm.", "I’d really like to come"]]),
      p("Give an honest but brief reason.", "But I already promised my family I’d have dinner with them tonight.", "Explain the prior commitment naturally.", [["Mà tối nay", "but tonight"], ["mình hứa ăn cơm với gia đình rồi.", "I already promised my family I’d have dinner with them"]]),
      p("Avoid sounding uncertain.", "So I really can’t make it this time.", "Decline clearly after giving the reason.", [["Nên lần này", "so this time"], ["mình không đi được thiệt.", "I really can’t make it"]], [["Nên lần này", "so this time"], ["mình thực sự không đi được.", "I really can’t make it"]]),
      p("Offer a specific alternative.", "How about lunch together next Saturday?", "Suggest another time rather than a vague future meeting.", [["Hay thứ Bảy tuần sau", "how about next Saturday"], ["tụi mình ăn trưa nha?", "we have lunch together"]], [["Hay thứ Bảy tuần sau", "how about next Saturday"], ["bọn mình ăn trưa nhé?", "we have lunch together"]]),
      p("End with goodwill toward the event.", "Have fun tonight, and send me some pictures.", "Close in a supportive, friendly way.", [["Tối nay chơi vui nha,", "have fun tonight"], ["nhớ gửi hình cho mình coi.", "send me some pictures"]], [["Tối nay chơi vui nhé,", "have fun tonight"], ["nhớ gửi ảnh cho mình xem.", "send me some pictures"]]),
    ],
  },
  {
    order: 27, unitOrder, unitSlug, unitTitle,
    title: "Set a respectful boundary",
    scenario: "Ask a housemate to change a recurring behavior without starting a fight.",
    difficulty: 4.35,
    rounds: [
      p("Ask for a moment to talk.", "Can we talk about something for a minute?", "Open a sensitive conversation calmly.", [["Mình nói chuyện này", "can we talk about something"], ["một chút được không?", "for a minute"]]),
      p("Describe the behavior without exaggerating.", "The past few nights, the music has been pretty loud after midnight.", "Name the recurring issue and time.", [["Mấy tối nay", "the past few nights"], ["sau mười hai giờ nhạc hơi lớn.", "the music has been pretty loud after midnight"]]),
      p("Explain its impact on you.", "I have to get up early, so I haven’t been sleeping well.", "Connect the behavior to a concrete effect.", [["Mình phải dậy sớm", "I have to get up early"], ["nên mấy hôm nay ngủ không ngon.", "so I haven’t been sleeping well"]]),
      p("Make a specific request.", "After eleven, could you use headphones?", "Ask for one clear behavioral change.", [["Sau mười một giờ", "after eleven"], ["bạn đeo tai nghe giúp mình nha.", "could you use headphones"]], [["Sau mười một giờ", "after eleven"], ["bạn đeo tai nghe giúp mình nhé.", "could you use headphones"]]),
      p("Show willingness to be fair.", "If anything I do bothers you, please tell me too.", "Make the boundary reciprocal.", [["Mình có gì làm bạn khó chịu", "if anything I do bothers you"], ["thì bạn cũng cứ nói nha.", "please tell me too"]], [["Mình có gì làm bạn khó chịu", "if anything I do bothers you"], ["thì bạn cũng cứ nói nhé.", "please tell me too"]]),
    ],
  },
  {
    order: 28, unitOrder, unitSlug, unitTitle,
    title: "Apologize and repair things",
    scenario: "Own a mistake, explain it briefly, and rebuild trust with a colleague.",
    difficulty: 4.4,
    rounds: [
      p("Apologize for the specific mistake.", "I’m sorry I sent you the old version of the file.", "Name exactly what you did wrong.", [["Xin lỗi bạn,", "I’m sorry"], ["mình gửi nhầm file cũ.", "I sent you the old version of the file"]]),
      p("Take responsibility without making excuses.", "I was rushing and didn’t check carefully before sending it.", "Explain briefly while still owning the error.", [["Lúc gửi mình vội quá", "I was rushing when I sent it"], ["nên không kiểm tra kỹ.", "and didn’t check carefully"]]),
      p("Acknowledge the impact.", "I know that made you redo part of the work.", "Show that you understand the consequence for them.", [["Mình biết vì vậy", "I know that because of that"], ["bạn phải làm lại một phần.", "you had to redo part of the work"]]),
      p("State the repair already made.", "I’ve sent the correct file and highlighted every change.", "Explain the concrete corrective action.", [["Mình gửi lại bản đúng rồi", "I’ve sent the correct file"], ["và đánh dấu hết chỗ thay đổi.", "and highlighted every change"]]),
      p("Commit to preventing a repeat.", "Next time I’ll double-check before I send anything.", "End with a credible preventive action.", [["Lần sau trước khi gửi", "next time before I send anything"], ["mình sẽ kiểm tra lại kỹ.", "I’ll double-check"]]),
    ],
  },
  {
    order: 29, unitOrder, unitSlug, unitTitle,
    title: "Handle personal questions",
    scenario: "Respond tactfully when relatives ask about marriage and work.",
    difficulty: 4.45,
    rounds: [
      p("Respond lightly to a marriage question.", "I’m not in a rush; when there’s good news, I’ll tell everyone.", "Deflect a personal question with warmth.", [["Con chưa vội đâu,", "I’m not in a rush"], ["có tin vui con báo cả nhà.", "when there’s good news, I’ll tell everyone"]], [["Cháu chưa vội đâu ạ,", "I’m not in a rush"], ["có tin vui cháu báo cả nhà.", "when there’s good news, I’ll tell everyone"]]),
      p("Answer a salary question indirectly.", "My income is enough for me to live comfortably for now.", "Give a polite answer without sharing a number.", [["Thu nhập hiện giờ", "my income for now"], ["cũng đủ để con sống thoải mái.", "is enough for me to live comfortably"]], [["Thu nhập hiện giờ", "my income for now"], ["cũng đủ để cháu sống thoải mái ạ.", "is enough for me to live comfortably"]]),
      p("Respond to pressure about changing jobs.", "I’m considering it, but I haven’t made a decision yet.", "Show that you heard the advice without committing.", [["Con cũng đang cân nhắc,", "I’m considering it"], ["nhưng chưa quyết định.", "but I haven’t made a decision yet"]], [["Cháu cũng đang cân nhắc,", "I’m considering it"], ["nhưng chưa quyết định ạ.", "but I haven’t made a decision yet"]]),
      p("Set a soft limit on the topic.", "Let me figure it out slowly; please don’t worry too much.", "Ask for space while reassuring the relative.", [["Để con từ từ tính nha,", "let me figure it out slowly"], ["mọi người đừng lo quá.", "please don’t worry too much"]], [["Để cháu từ từ tính ạ,", "let me figure it out slowly"], ["mọi người đừng lo quá.", "please don’t worry too much"]]),
      p("Redirect to a shared topic.", "By the way, who made this soup? It’s really good.", "Move the conversation away naturally.", [["Mà canh này ai nấu vậy?", "by the way, who made this soup"], ["Ngon quá trời.", "it’s really good"]], [["Mà canh này ai nấu thế ạ?", "by the way, who made this soup"], ["Ngon quá.", "it’s really good"]]),
    ],
  },
  {
    order: 30, unitOrder, unitSlug, unitTitle,
    title: "Get through a demanding day",
    scenario: "Manage changing plans, a service problem, and social tension.",
    difficulty: 4.5,
    rounds: [
      p("Update a friend when the morning plan changes.", "My appointment is taking longer than expected, so could we meet thirty minutes later?", "Explain a delay and propose an exact adjustment.", [["Buổi hẹn của mình kéo dài hơn dự tính,", "my appointment is taking longer than expected"], ["tụi mình gặp muộn hơn nửa tiếng nha?", "could we meet thirty minutes later"]], [["Cuộc hẹn của mình kéo dài hơn dự kiến,", "my appointment is taking longer than expected"], ["bọn mình gặp muộn hơn nửa tiếng nhé?", "could we meet thirty minutes later"]]),
      p("Call about a missing item from lunch.", "The food arrived, but one drink is missing from the order.", "Report a partial delivery accurately.", [["Đồ ăn giao tới rồi,", "the food arrived"], ["nhưng đơn thiếu một ly nước.", "but one drink is missing from the order"]], [["Đồ ăn giao đến rồi,", "the food arrived"], ["nhưng đơn thiếu một cốc nước.", "but one drink is missing from the order"]]),
      p("Disagree tactfully during an afternoon discussion.", "I understand your point, but I think we need more information first.", "Acknowledge another view before disagreeing.", [["Mình hiểu ý bạn,", "I understand your point"], ["nhưng chắc mình cần thêm thông tin trước.", "but I think we need more information first"]]),
      p("Decline an evening request when exhausted.", "I’d like to help, but today I really don’t have the energy.", "Protect your limit without sounding uncaring.", [["Mình cũng muốn giúp,", "I’d like to help"], ["mà hôm nay thiệt sự hết sức rồi.", "but today I really don’t have the energy"]], [["Mình cũng muốn giúp,", "I’d like to help"], ["nhưng hôm nay thực sự hết sức rồi.", "but today I really don’t have the energy"]]),
      p("End the day by repairing a small misunderstanding.", "I wasn’t upset with you earlier; I was just overwhelmed.", "Clarify your emotional state and protect the relationship.", [["Hồi nãy mình không có giận bạn,", "I wasn’t upset with you earlier"], ["chỉ là nhiều chuyện quá thôi.", "I was just overwhelmed"]], [["Lúc nãy mình không giận bạn,", "I wasn’t upset with you earlier"], ["chỉ là nhiều việc quá thôi.", "I was just overwhelmed"]]),
    ],
  },
];
