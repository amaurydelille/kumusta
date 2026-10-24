import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 2;
const unitSlug = "make-plans-together";
const unitTitle = "Make plans with other people";

export const unit02: LessonSpec[] = [
  {
    order: 6, unitOrder, unitSlug, unitTitle,
    title: "Suggest something to do",
    scenario: "Turn a vague wish to meet into a concrete activity.",
    difficulty: 3.3,
    rounds: [
      p("Bring up the weekend casually.", "Are you doing anything this weekend?", "Check whether your friend may be free.", [["Cuối tuần này", "this weekend"], ["bạn có làm gì không?", "are you doing anything"]]),
      p("Suggest trying a place you heard about.", "I heard there’s a new restaurant that’s pretty good.", "Introduce an activity as something you heard about.", [["Nghe nói có quán mới", "I heard there’s a new restaurant"], ["ăn cũng được lắm.", "that’s pretty good"]], [["Nghe nói có quán mới", "I heard there’s a new restaurant"], ["ăn khá ổn.", "that’s pretty good"]]),
      p("Make the invitation feel low-pressure.", "If you’re free, should we try it?", "Invite your friend without assuming they can come.", [["Bạn rảnh thì", "if you’re free"], ["tụi mình đi thử không?", "should we try it"]], [["Bạn rảnh thì", "if you’re free"], ["bọn mình đi thử không?", "should we try it"]]),
      p("Offer an alternative activity.", "If you don’t feel like eating out, coffee is fine too.", "Give an easy second option.", [["Không muốn đi ăn thì", "if you don’t feel like eating out"], ["đi cà phê cũng được.", "coffee is fine too"]]),
      p("Let the other person choose.", "See what you feel like doing, then tell me.", "End by leaving the choice open.", [["Bạn coi muốn đi đâu", "see what you feel like doing"], ["rồi nói mình biết nha.", "then tell me"]], [["Bạn xem muốn đi đâu", "see what you feel like doing"], ["rồi bảo mình nhé.", "then tell me"]]),
    ],
  },
  {
    order: 7, unitOrder, unitSlug, unitTitle,
    title: "Find a time that works",
    scenario: "Compare schedules and settle on a workable meeting time.",
    difficulty: 3.35,
    rounds: [
      p("Say when you are generally available.", "I’m free after six on weekdays.", "Give a useful availability window.", [["Ngày thường", "on weekdays"], ["sau sáu giờ mình mới rảnh.", "I’m free after six"]]),
      p("Explain one schedule limitation.", "Tuesday won’t work because I have to work late.", "Rule out a day and give the reason.", [["Thứ Ba chắc không được,", "Tuesday probably won’t work"], ["mình phải làm trễ.", "because I have to work late"]], [["Thứ Ba chắc không được,", "Tuesday probably won’t work"], ["mình phải làm muộn.", "because I have to work late"]]),
      p("Offer two possible alternatives.", "Wednesday or Thursday both work for me.", "Give the other person a choice of days.", [["Thứ Tư hoặc thứ Năm", "Wednesday or Thursday"], ["mình đều được.", "both work for me"]]),
      p("Negotiate the exact time.", "Could we make it around seven thirty?", "Suggest a more convenient time.", [["Khoảng bảy giờ rưỡi", "around seven thirty"], ["được không?", "could we make it"]]),
      p("Confirm the final arrangement.", "Okay, Thursday at seven thirty. I’ll message you that day.", "Repeat the plan and promise to check in.", [["Vậy thứ Năm, bảy giờ rưỡi nha.", "okay, Thursday at seven thirty"], ["Hôm đó mình nhắn bạn.", "I’ll message you that day"]], [["Vậy thứ Năm, bảy giờ rưỡi nhé.", "okay, Thursday at seven thirty"], ["Hôm đó mình nhắn bạn.", "I’ll message you that day"]]),
    ],
  },
  {
    order: 8, unitOrder, unitSlug, unitTitle,
    title: "Choose between options",
    scenario: "Compare two places based on price, distance, and atmosphere.",
    difficulty: 3.4,
    rounds: [
      p("Compare convenience first.", "The first place is closer, but it’s usually crowded.", "Contrast distance with crowd levels.", [["Quán đầu gần hơn,", "the first place is closer"], ["nhưng thường đông lắm.", "but it’s usually crowded"]]),
      p("Describe the tradeoff at the second place.", "The other place is farther, but it’s quieter.", "Present the opposite tradeoff.", [["Quán kia xa hơn chút,", "the other place is a little farther"], ["bù lại yên tĩnh hơn.", "but it’s quieter"]]),
      p("Bring price into the comparison.", "As for price, the two places are about the same.", "Explain that price does not decide it.", [["Còn giá thì", "as for price"], ["hai bên cũng ngang nhau.", "the two places are about the same"]]),
      p("State your preference with a reason.", "I’d lean toward the quieter place so we can talk.", "Give a tentative preference and justification.", [["Mình nghiêng về quán yên hơn,", "I’d lean toward the quieter place"], ["để còn nói chuyện.", "so we can talk"]]),
      p("Invite the other person’s view.", "But if you don’t want to go far, the closer place is fine.", "Show flexibility after stating your preference.", [["Mà bạn ngại đi xa thì", "but if you don’t want to go far"], ["quán gần cũng được.", "the closer place is fine"]]),
    ],
  },
  {
    order: 9, unitOrder, unitSlug, unitTitle,
    title: "Change the plan smoothly",
    scenario: "Tell a friend you will be late and adjust the plan without tension.",
    difficulty: 3.45,
    rounds: [
      p("Warn your friend as soon as possible.", "I’m afraid I’m going to be about twenty minutes late.", "Give a realistic delay estimate.", [["Chắc mình tới trễ", "I’m afraid I’m going to be late"], ["khoảng hai mươi phút.", "by about twenty minutes"]], [["Chắc mình đến muộn", "I’m afraid I’m going to be late"], ["khoảng hai mươi phút.", "by about twenty minutes"]]),
      p("Give a brief reason.", "The meeting ran longer than expected.", "Explain the delay without overexplaining.", [["Cuộc họp kéo dài", "the meeting ran longer"], ["hơn mình tưởng.", "than I expected"]]),
      p("Tell them not to wait outside.", "Go inside first; you don’t need to wait for me.", "Make the wait more comfortable for them.", [["Bạn vô trước đi,", "go inside first"], ["khỏi cần đứng đợi mình.", "you don’t need to wait for me"]], [["Bạn vào trước đi,", "go inside first"], ["không cần đứng đợi mình.", "you don’t need to wait for me"]]),
      p("Offer to change the plan if needed.", "If it’s inconvenient, we can move it to another day.", "Offer a genuine alternative.", [["Nếu bất tiện quá thì", "if it’s too inconvenient"], ["tụi mình dời qua bữa khác.", "we can move it to another day"]], [["Nếu bất tiện quá thì", "if it’s too inconvenient"], ["bọn mình chuyển sang hôm khác.", "we can move it to another day"]]),
      p("Confirm after your friend agrees to wait.", "Thanks. I’ll let you know when I’m close.", "Thank them and promise an update.", [["Cảm ơn nha,", "thanks"], ["gần tới mình báo.", "I’ll let you know when I’m close"]], [["Cảm ơn nhé,", "thanks"], ["gần đến mình báo.", "I’ll let you know when I’m close"]]),
    ],
  },
  {
    order: 10, unitOrder, unitSlug, unitTitle,
    title: "Organize a group outing",
    scenario: "Coordinate a small group without making the chat confusing.",
    difficulty: 3.5,
    rounds: [
      p("Summarize who can attend.", "So far, four people have confirmed.", "Give the group a clear attendance update.", [["Tới giờ", "so far"], ["có bốn người xác nhận rồi.", "four people have confirmed"]], [["Đến giờ", "so far"], ["có bốn người xác nhận rồi.", "four people have confirmed"]]),
      p("Identify the remaining uncertainty.", "Only Minh still hasn’t said whether he can come.", "Name the one unresolved response.", [["Chỉ còn Minh", "only Minh"], ["chưa nói có đi được không.", "still hasn’t said whether he can come"]]),
      p("Divide one practical responsibility.", "I’ll book the table; can you ask everyone about food?", "Take one task and delegate another.", [["Mình đặt bàn cho,", "I’ll book the table"], ["bạn hỏi mọi người vụ đồ ăn nha.", "can you ask everyone about food"]], [["Mình đặt bàn cho,", "I’ll book the table"], ["bạn hỏi mọi người chuyện đồ ăn nhé.", "can you ask everyone about food"]]),
      p("Set a decision deadline.", "Let’s finalize the head count by tomorrow afternoon.", "Give the group a reasonable deadline.", [["Chiều mai", "by tomorrow afternoon"], ["mình chốt số người nha.", "let’s finalize the head count"]], [["Chiều mai", "by tomorrow afternoon"], ["mình chốt số người nhé.", "let’s finalize the head count"]]),
      p("Post a concise final recap.", "Saturday at seven, at the place on Nguyen Thi Minh Khai Street.", "State the final time and location clearly.", [["Chốt lại là thứ Bảy, bảy giờ,", "the final plan is Saturday at seven"], ["ở quán đường Nguyễn Thị Minh Khai nha.", "at the place on Nguyen Thi Minh Khai Street"]], [["Chốt lại là thứ Bảy, bảy giờ,", "the final plan is Saturday at seven"], ["ở quán phố Nguyễn Thị Minh Khai nhé.", "at the place on Nguyen Thi Minh Khai Street"]]),
    ],
  },
];
