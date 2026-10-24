import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 6;
const unitSlug = "between-vietnamese-worlds";
const unitTitle = "Move confidently between Vietnamese worlds";

export const unit06: LessonSpec[] = [
  {
    order: 26, unitOrder, unitSlug, unitTitle,
    title: "Sound professional, not bureaucratic",
    scenario: "Give a concise work update, raise a risk, and propose a solution.",
    difficulty: 4.8,
    rounds: [
      p("Lead with the current status.", "We’ve finished the main part; only final testing remains.", "Give the headline before the details.", "Phần chính bên tôi làm xong rồi,|giờ chỉ còn kiểm tra lần cuối.", "we’ve finished the main part|only final testing remains", "Phần chính bên tôi đã xong,|giờ chỉ còn kiểm tra lần cuối.", "we’ve finished the main part|only final testing remains"),
      p("Raise a risk without creating panic.", "There is one issue that may affect Friday’s schedule.", "Name the risk and its possible impact.", "Có một vấn đề|có thể ảnh hưởng lịch thứ Sáu.", "there is one issue|that may affect Friday’s schedule"),
      p("Explain what is causing it.", "We’re still waiting for the partner to confirm the data.", "Identify the dependency objectively.", "Bên tôi vẫn đang chờ đối tác|xác nhận số liệu.", "we’re still waiting for the partner|to confirm the data"),
      p("Offer a practical response.", "If we don’t hear back by tomorrow, we’ll use the previous figures temporarily.", "Pair the risk with a contingency.", "Nếu mai chưa có phản hồi,|bên tôi sẽ tạm dùng số liệu cũ.", "if we don’t hear back by tomorrow|we’ll use the previous figures temporarily"),
      p("Confirm what others need to do.", "For now, your team doesn’t need to change anything.", "End with a clear action status for the listener.", "Hiện giờ phía anh|chưa cần thay đổi gì.", "for now, your team|doesn’t need to change anything"),
    ],
  },
  {
    order: 27, unitOrder, unitSlug, unitTitle,
    title: "Handle formal adult responsibilities",
    scenario: "Clarify documents and next steps during an administrative appointment.",
    difficulty: 4.85,
    rounds: [
      p("Explain what you came to do.", "I’m here to update the address on my application.", "State your administrative purpose precisely.", "Tôi tới để cập nhật địa chỉ|trong hồ sơ đã nộp.", "I’m here to update the address|on my submitted application", "Tôi đến để cập nhật địa chỉ|trong hồ sơ đã nộp.", "I’m here to update the address|on my submitted application"),
      p("Check which evidence is accepted.", "Does the proof of residence need to be an original, or is a copy enough?", "Clarify a document requirement.", "Giấy xác nhận chỗ ở cần bản gốc,|hay bản sao là được?", "does the proof of residence need to be an original|or is a copy enough"),
      p("Explain a missing document.", "I don’t have the original today because it’s being reissued.", "Give a concise reason for an incomplete file.", "Hôm nay tôi chưa có bản gốc,|vì đang làm lại giấy mới.", "I don’t have the original today|because it’s being reissued"),
      p("Ask whether the process can begin anyway.", "Can you process the other documents first while I wait?", "Request a lawful partial next step.", "Trong lúc chờ, anh xử lý trước|những giấy tờ còn lại được không?", "while I wait, can you process first|the other documents"),
      p("Confirm the deadline and delivery method.", "So I need to submit it by Friday, either here or online, correct?", "Repeat the full requirement before leaving.", "Vậy hạn là thứ Sáu,|nộp tại đây hoặc trực tuyến đều được, đúng không?", "so the deadline is Friday|and I can submit here or online, correct"),
    ],
  },
  {
    order: 28, unitOrder, unitSlug, unitTitle,
    title: "Participate in cultural occasions",
    scenario: "Speak appropriately while attending a family remembrance ceremony.",
    difficulty: 4.9,
    rounds: [
      p("Greet the family at the remembrance ceremony.", "We came to offer incense for Grandpa and visit everyone.", "Use warm ceremonial language without sounding theatrical.", "Tụi con tới thắp nhang cho ông|và thăm cả nhà.", "we came to offer incense for Grandpa|and visit everyone", "Chúng cháu đến thắp hương cho ông|và thăm cả nhà ạ.", "we came to offer incense for Grandpa|and visit everyone"),
      p("Ask how to help appropriately.", "Is there anything that still needs doing? Please show me where to help.", "Offer help while respecting the hosts’ organization.", "Còn việc gì chưa xong,|cô chỉ con phụ với.", "is there anything that still needs doing|please show me where to help", "Còn việc gì chưa xong,|cô bảo cháu phụ với ạ.", "is there anything that still needs doing|please show me where to help"),
      p("Explain a cultural detail to a companion.", "We greet the elders first, then we can sit with everyone else.", "Guide someone through the social order gently.", "Mình chào người lớn trước,|rồi ngồi với mọi người sau.", "we greet the elders first|then we can sit with everyone else"),
      p("Receive hospitality without repeated refusal.", "Yes, I’ll have a little. Thank you for preparing everything.", "Accept graciously after a polite offer.", "Dạ, con dùng một chút.|Cảm ơn cô đã chuẩn bị.", "yes, I’ll have a little|thank you for preparing everything", "Dạ, cháu dùng một chút ạ.|Cảm ơn cô đã chuẩn bị.", "yes, I’ll have a little|thank you for preparing everything"),
      p("Leave without disrupting the occasion.", "We’ll head home now so the family can rest; thank you for having us.", "Give a considerate reason and warm farewell.", "Tụi con xin phép về|để cả nhà còn nghỉ, cảm ơn cô nha.", "we’ll head home so the family can rest|thank you for having us", "Chúng cháu xin phép về|để cả nhà còn nghỉ, cảm ơn cô ạ.", "we’ll head home so the family can rest|thank you for having us"),
    ],
  },
  {
    order: 29, unitOrder, unitSlug, unitTitle,
    title: "Adapt across regions",
    scenario: "Recognize regional choices and adapt without treating one as superior.",
    difficulty: 4.95,
    rounds: [
      p("Describe a harmless vocabulary difference.", "I usually say muong, but here everyone says thia.", "Notice a regional word without correcting anyone.", "Mình hay nói muỗng,|mà ở đây ai cũng nói thìa.", "I usually say muong|but here everyone says thia", "Mình hay nói thìa,|nhưng trong Nam mọi người nói muỗng.", "I usually say thia|but in the South everyone says muong"),
      p("Ask about an unfamiliar regional word.", "I understand the sentence, but what does that word mean here?", "Request clarification without judging the usage.", "Mình hiểu cả câu,|mà từ đó ở đây nghĩa là gì?", "I understand the sentence|but what does that word mean here"),
      p("Adjust your own word choice for clarity.", "I’ll use the word everyone here knows so it’s easier to understand.", "Adapt pragmatically without hiding your identity.", "Mình dùng từ ở đây ai cũng biết,|cho dễ hiểu hơn.", "I’ll use the word everyone here knows|so it’s easier to understand"),
      p("Explain an accent misunderstanding lightly.", "I heard it differently at first, but now I recognize the accent.", "Repair comprehension without blaming the speaker.", "Lúc đầu mình nghe ra từ khác,|giờ quen giọng rồi mới hiểu.", "I heard it differently at first|but now I recognize the accent"),
      p("State a respectful view of variation.", "The wording differs by region; it isn’t a matter of right or wrong.", "Frame regional difference without hierarchy.", "Mỗi vùng nói một kiểu,|chứ không phải ai đúng ai sai.", "the wording differs by region|it isn’t a matter of right or wrong"),
    ],
  },
  {
    order: 30, unitOrder, unitSlug, unitTitle,
    title: "Bring your full identity into Vietnamese",
    scenario: "Use Vietnamese across family, work, emotion, and cultural belonging.",
    difficulty: 5.0,
    rounds: [
      p("Explain your relationship with Vietnamese.", "I understood Vietnamese growing up, but speaking it confidently took longer.", "Describe passive understanding and active growth.", "Từ nhỏ mình đã hiểu tiếng Việt,|nhưng nói tự tin thì mất lâu hơn.", "I understood Vietnamese growing up|but speaking it confidently took longer"),
      p("Reject a narrow test of belonging.", "Sometimes I search for words, but that doesn’t make this language less mine.", "Express linguistic identity without defensiveness.", "Có lúc mình vẫn phải tìm từ,|nhưng tiếng Việt vẫn là của mình.", "sometimes I still search for words|but Vietnamese is still mine"),
      p("Describe adapting across contexts.", "I don’t speak to Grandma the same way I speak to friends or colleagues.", "Show awareness of relationship and register.", "Mình nói với bà|khác với lúc nói cùng bạn bè hay đồng nghiệp.", "I speak to Grandma|differently than I speak to friends or colleagues"),
      p("Name what fluency means personally.", "For me, fluency means being able to say what I truly feel.", "Define success through meaningful expression.", "Với mình, nói giỏi là|nói được điều mình thật sự cảm thấy.", "for me, fluency means|being able to say what I truly feel"),
      p("Close with a forward-looking commitment.", "I’ll keep speaking, making mistakes, and building a closer connection.", "End the roadmap with confident persistence.", "Mình sẽ cứ nói, cứ sai,|rồi ngày càng thấy gần gũi hơn.", "I’ll keep speaking and making mistakes|and build a closer connection"),
    ],
  },
];
