import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 5;
const unitSlug = "handle-public-problems";
const unitTitle = "Handle problems in public";

export const unit05: LessonSpec[] = [
  {
    order: 21, unitOrder, unitSlug, unitTitle,
    title: "Fix a wrong order or bill",
    scenario: "Point out two restaurant mistakes calmly and get them corrected.",
    difficulty: 4.05,
    rounds: [
      p("Get the server’s attention politely.", "Excuse me, could you check this for me?", "Open the complaint without sounding accusatory.", [["Em ơi,", "excuse me"], ["kiểm tra giúp anh cái này được không?", "could you check this for me"]], [["Em ơi,", "excuse me"], ["kiểm tra giúp anh cái này được không?", "could you check this for me"]]),
      p("Explain the order problem precisely.", "I asked for this dish without peanuts, but it has peanuts.", "Contrast what you requested with what arrived.", [["Anh có dặn món này không bỏ đậu phộng,", "I asked for this dish without peanuts"], ["mà giờ lại có đậu phộng.", "but it has peanuts"]], [["Anh có dặn món này không cho lạc,", "I asked for this dish without peanuts"], ["mà giờ lại có lạc.", "but it has peanuts"]]),
      p("Request the practical solution.", "Could you please have the kitchen remake it?", "Ask clearly for the dish to be replaced.", [["Em nhờ bếp", "could you please have the kitchen"], ["làm lại giúp anh nha.", "remake it"]], [["Em nhờ bếp", "could you please have the kitchen"], ["làm lại giúp anh nhé.", "remake it"]]),
      p("Point out a second issue on the bill.", "Also, I think this drink was charged twice.", "Add another issue without escalating your tone.", [["Với lại hình như", "also, I think"], ["ly nước này tính hai lần rồi.", "this drink was charged twice"]]),
      p("Acknowledge the correction.", "That looks right now. Thank you for checking.", "Confirm the solution and close politely.", [["Giờ đúng rồi đó,", "that looks right now"], ["cảm ơn em đã kiểm tra.", "thank you for checking"]], [["Giờ đúng rồi,", "that looks right now"], ["cảm ơn em đã kiểm tra.", "thank you for checking"]]),
    ],
  },
  {
    order: 22, unitOrder, unitSlug, unitTitle,
    title: "Deal with a late delivery",
    scenario: "Call about a delivery that is late and obtain a useful update.",
    difficulty: 4.1,
    rounds: [
      p("Identify the order and problem.", "I’m calling about order 248; it still hasn’t arrived.", "Give the reference number and current issue.", [["Tôi gọi về đơn hai bốn tám,", "I’m calling about order 248"], ["tới giờ vẫn chưa nhận được.", "it still hasn’t arrived"]], [["Tôi gọi về đơn hai bốn tám,", "I’m calling about order 248"], ["đến giờ vẫn chưa nhận được.", "it still hasn’t arrived"]]),
      p("Explain how late it is.", "The app said it would arrive before noon.", "State the promised delivery window.", [["Trên ứng dụng báo", "the app said"], ["là giao trước mười hai giờ.", "it would arrive before noon"]]),
      p("Ask for a specific status check.", "Could you check whether the driver has picked it up yet?", "Request information that helps locate the order.", [["Bạn kiểm tra giúp", "could you check"], ["tài xế lấy hàng chưa?", "whether the driver has picked it up yet"]]),
      p("Respond to another vague estimate.", "Could you give me a more exact time? I need to go out soon.", "Push politely for a useful estimate.", [["Bạn báo giúp giờ cụ thể hơn được không?", "could you give me a more exact time"], ["Tôi sắp phải ra ngoài.", "I need to go out soon"]]),
      p("Confirm the agreed next step.", "Okay, if it isn’t here by two, I’ll call back.", "Set a clear follow-up point.", [["Được, nếu hai giờ chưa tới", "okay, if it isn’t here by two"], ["thì tôi gọi lại.", "I’ll call back"]], [["Được, nếu hai giờ chưa đến", "okay, if it isn’t here by two"], ["thì tôi gọi lại.", "I’ll call back"]]),
    ],
  },
  {
    order: 23, unitOrder, unitSlug, unitTitle,
    title: "Return or exchange something",
    scenario: "Explain a product defect and negotiate a reasonable exchange.",
    difficulty: 4.15,
    rounds: [
      p("Introduce the purchase and issue.", "I bought this yesterday, but it won’t turn on.", "State when you bought it and what is wrong.", [["Tôi mua cái này hôm qua,", "I bought this yesterday"], ["mà giờ mở không lên.", "but it won’t turn on"]], [["Tôi mua cái này hôm qua,", "I bought this yesterday"], ["mà giờ bật không lên.", "but it won’t turn on"]]),
      p("Explain what you already tried.", "I charged it fully and tried again, but nothing changed.", "Show that the problem is not a simple oversight.", [["Tôi sạc đầy rồi thử lại,", "I charged it fully and tried again"], ["nhưng vẫn vậy.", "but nothing changed"]], [["Tôi sạc đầy rồi thử lại,", "I charged it fully and tried again"], ["nhưng vẫn thế.", "but nothing changed"]]),
      p("Ask about the store’s solution.", "Can I exchange it for another one?", "Request an exchange directly but politely.", [["Tôi đổi qua cái khác", "can I exchange it for another one"], ["được không?", "is that possible"]]),
      p("Respond when the same model is unavailable.", "If that model is out of stock, can I choose a different one?", "Negotiate an alternative product.", [["Nếu mẫu đó hết hàng", "if that model is out of stock"], ["thì tôi chọn mẫu khác được không?", "can I choose a different one"]]),
      p("Clarify the price difference.", "If the other one costs more, I’ll pay the difference.", "Confirm how an upgrade would be handled.", [["Mẫu kia mắc hơn thì", "if the other one costs more"], ["tôi bù thêm tiền.", "I’ll pay the difference"]], [["Mẫu kia đắt hơn thì", "if the other one costs more"], ["tôi bù thêm tiền.", "I’ll pay the difference"]]),
    ],
  },
  {
    order: 24, unitOrder, unitSlug, unitTitle,
    title: "Ask for help with a service",
    scenario: "Report an intermittent internet problem and arrange a repair visit.",
    difficulty: 4.2,
    rounds: [
      p("Describe the service issue.", "My internet has kept dropping since yesterday.", "Explain an intermittent problem and when it began.", [["Mạng nhà tôi", "my internet"], ["từ hôm qua tới giờ cứ bị rớt.", "has kept dropping since yesterday"]], [["Mạng nhà tôi", "my internet"], ["từ hôm qua đến giờ cứ bị mất.", "has kept dropping since yesterday"]]),
      p("Explain what troubleshooting you tried.", "I restarted the modem twice, but it didn’t help.", "Rule out the basic fix.", [["Tôi khởi động lại modem hai lần rồi,", "I restarted the modem twice"], ["mà vẫn không được.", "but it didn’t help"]]),
      p("Clarify the pattern.", "It works for a few minutes, then disconnects again.", "Describe exactly how the fault behaves.", [["Mạng chạy được vài phút", "it works for a few minutes"], ["rồi lại mất.", "then disconnects again"]]),
      p("Request an on-site check.", "Could you send someone to take a look this afternoon?", "Ask for a technician and a time window.", [["Chiều nay bên mình", "this afternoon, could you"], ["cho người qua kiểm tra được không?", "send someone to take a look"]]),
      p("Confirm access arrangements.", "Please call me ten minutes before you arrive so I can come downstairs.", "Give a practical arrival instruction.", [["Trước khi tới khoảng mười phút", "about ten minutes before you arrive"], ["gọi tôi để tôi xuống mở cửa nha.", "call me so I can come downstairs"]], [["Trước khi đến khoảng mười phút", "about ten minutes before you arrive"], ["gọi tôi để tôi xuống mở cửa nhé.", "call me so I can come downstairs"]]),
    ],
  },
  {
    order: 25, unitOrder, unitSlug, unitTitle,
    title: "Resolve a complicated problem",
    scenario: "Work through a hotel booking mix-up from explanation to confirmation.",
    difficulty: 4.25,
    rounds: [
      p("Explain the mismatch at check-in.", "My booking is for three nights, but your system only shows two.", "State the booked stay and the incorrect record.", [["Tôi đặt ba đêm,", "my booking is for three nights"], ["mà hệ thống bên mình chỉ hiện hai đêm.", "but your system only shows two"]]),
      p("Offer evidence that can help.", "I have the confirmation email here if you need to see it.", "Provide documentation without sounding defensive.", [["Tôi có thư xác nhận ở đây,", "I have the confirmation email here"], ["nếu bạn cần xem.", "if you need to see it"]]),
      p("Clarify what solution you need.", "I need to stay through Monday morning as originally booked.", "State the non-negotiable practical requirement.", [["Tôi cần ở tới sáng thứ Hai", "I need to stay through Monday morning"], ["đúng như lúc đặt.", "as originally booked"]], [["Tôi cần ở đến sáng thứ Hai", "I need to stay through Monday morning"], ["đúng như lúc đặt.", "as originally booked"]]),
      p("Evaluate the proposed room change.", "Changing rooms is okay, as long as the price stays the same.", "Accept a compromise with one condition.", [["Đổi phòng cũng được,", "changing rooms is okay"], ["miễn là giá không đổi.", "as long as the price stays the same"]]),
      p("Confirm the complete resolution.", "So I’ll stay here tonight and move rooms tomorrow after noon, correct?", "Repeat every important part of the solution.", [["Vậy tối nay tôi ở phòng này,", "so I’ll stay here tonight"], ["mai sau mười hai giờ đổi phòng, đúng không?", "and move rooms tomorrow after noon, correct"]]),
    ],
  },
];
