import { type LessonSpec, spokenRound as p } from "./catalog.ts";

const unitOrder = 3;
const unitSlug = "share-opinions-tactfully";
const unitTitle = "Share opinions without sounding blunt";

export const unit03: LessonSpec[] = [
  {
    order: 11, unitOrder, unitSlug, unitTitle,
    title: "Say what you really think",
    scenario: "Give an honest opinion about a popular restaurant tactfully.",
    difficulty: 3.55,
    rounds: [
      p("A friend asks whether you liked the restaurant.", "Honestly, I thought it was just okay.", "Give a measured first reaction.", [["Nói thật là", "honestly"], ["mình thấy cũng bình thường.", "I thought it was just okay"]]),
      p("Mention a specific positive point.", "The atmosphere was nice, and the staff were friendly.", "Acknowledge what the place did well.", [["Không gian thì đẹp,", "the atmosphere was nice"], ["nhân viên cũng dễ thương.", "and the staff were friendly"]], [["Không gian thì đẹp,", "the atmosphere was nice"], ["nhân viên cũng thân thiện.", "and the staff were friendly"]]),
      p("Explain the main disappointment.", "But the food didn’t quite live up to the hype.", "Soften a clear criticism.", [["Nhưng đồ ăn", "but the food"], ["không ngon như lời đồn.", "didn’t quite live up to the hype"]]),
      p("Make the opinion personal, not absolute.", "Maybe it’s just not really to my taste.", "Frame the judgment as your own preference.", [["Có khi là", "maybe"], ["không hợp khẩu vị mình thôi.", "it’s just not really to my taste"]]),
      p("Allow room for a second try.", "I’d still try it again if someone invited me.", "End with an open-minded position.", [["Có người rủ thì", "if someone invited me"], ["mình vẫn đi thử lại.", "I’d still try it again"]]),
    ],
  },
  {
    order: 12, unitOrder, unitSlug, unitTitle,
    title: "Explain your reasons",
    scenario: "Explain why you prefer living near the city center.",
    difficulty: 3.6,
    rounds: [
      p("State your preference clearly.", "I still prefer living close to the center.", "Give your position before explaining it.", [["Mình vẫn thích", "I still prefer"], ["ở gần trung tâm hơn.", "living close to the center"]]),
      p("Give the strongest practical reason.", "The main thing is that getting around is more convenient.", "Introduce your most important reason.", [["Chủ yếu là", "the main thing is"], ["đi lại tiện hơn.", "getting around is more convenient"]]),
      p("Add a concrete example.", "For example, I can walk to work on some days.", "Support the reason with an example.", [["Ví dụ như", "for example"], ["có bữa mình đi bộ tới chỗ làm được.", "I can walk to work on some days"]], [["Ví dụ như", "for example"], ["có hôm mình đi bộ đến chỗ làm được.", "I can walk to work on some days"]]),
      p("Acknowledge the downside.", "Of course, the rent is higher and it’s noisier.", "Show that you understand the tradeoff.", [["Tất nhiên là", "of course"], ["tiền nhà cao hơn mà cũng ồn hơn.", "the rent is higher and it’s noisier"]]),
      p("Explain why the benefit wins.", "But for me, paying a little more for the convenience is worth it.", "Conclude by weighing the tradeoff.", [["Nhưng với mình,", "but for me"], ["mắc hơn chút mà tiện thì cũng đáng.", "paying a little more for the convenience is worth it"]], [["Nhưng với mình,", "but for me"], ["đắt hơn một chút mà tiện thì cũng đáng.", "paying a little more for the convenience is worth it"]]),
    ],
  },
  {
    order: 13, unitOrder, unitSlug, unitTitle,
    title: "Agree, partly agree, or disagree",
    scenario: "Discuss remote work while keeping the exchange friendly.",
    difficulty: 3.65,
    rounds: [
      p("Agree with one clear benefit.", "I agree that working from home saves a lot of time.", "Validate the other person’s strongest point.", [["Mình đồng ý là", "I agree that"], ["làm ở nhà tiết kiệm được nhiều thời gian.", "working from home saves a lot of time"]]),
      p("Add a qualification.", "But that’s only true if the house is quiet enough.", "Limit your agreement with a condition.", [["Nhưng cũng phải", "but that’s only true if"], ["ở nhà đủ yên tĩnh mới được.", "the house is quiet enough"]]),
      p("Disagree from personal experience.", "For me, staying home all day makes it harder to focus.", "Give a different view without attacking theirs.", [["Riêng mình thì", "for me"], ["ở nhà cả ngày lại khó tập trung.", "staying home all day makes it harder to focus"]]),
      p("Find common ground.", "Maybe a few days at home and a few at the office is best.", "Offer a compromise both sides can accept.", [["Có lẽ tốt nhất là", "maybe it’s best"], ["mấy ngày ở nhà, mấy ngày lên công ty.", "a few days at home and a few at the office"]], [["Có lẽ tốt nhất là", "maybe it’s best"], ["vài ngày ở nhà, vài ngày lên công ty.", "a few days at home and a few at the office"]]),
      p("Invite their response.", "What do you think? Would that arrangement work for you?", "Keep the disagreement conversational.", [["Bạn thấy sao?", "what do you think"], ["Làm vậy có hợp với bạn không?", "would that arrangement work for you"]], [["Bạn thấy sao?", "what do you think"], ["Làm thế có hợp với bạn không?", "would that arrangement work for you"]]),
    ],
  },
  {
    order: 14, unitOrder, unitSlug, unitTitle,
    title: "Recommend something personally",
    scenario: "Recommend a place based on what your friend actually likes.",
    difficulty: 3.7,
    rounds: [
      p("Ask what matters before recommending.", "Do you care more about the food or the atmosphere?", "Find out what your friend values.", [["Bạn coi trọng đồ ăn", "do you care more about the food"], ["hay không gian hơn?", "or the atmosphere"]]),
      p("Match a recommendation to their answer.", "If you like somewhere quiet, I know a place that would suit you.", "Tailor the suggestion to their preference.", [["Bạn thích chỗ yên tĩnh thì", "if you like somewhere quiet"], ["mình biết một quán hợp với bạn đó.", "I know a place that would suit you"]], [["Bạn thích chỗ yên tĩnh thì", "if you like somewhere quiet"], ["mình biết một quán khá hợp với bạn đấy.", "I know a place that would suit you"]]),
      p("Describe what makes it special.", "It’s small, but the owner makes everything herself.", "Give a memorable reason for recommending it.", [["Quán nhỏ thôi,", "it’s small"], ["nhưng cô chủ tự làm hết.", "but the owner makes everything herself"]]),
      p("Set an honest expectation.", "The service can be a little slow when it’s busy.", "Warn about one downside fairly.", [["Lúc đông thì", "when it’s busy"], ["phục vụ hơi chậm chút.", "the service can be a little slow"]]),
      p("Give a practical tip.", "Go before seven and you probably won’t have to wait.", "Help your friend get the best experience.", [["Đi trước bảy giờ", "go before seven"], ["thì chắc không phải đợi.", "and you probably won’t have to wait"]]),
    ],
  },
  {
    order: 15, unitOrder, unitSlug, unitTitle,
    title: "Reach a group decision",
    scenario: "Help friends choose a holiday plan with competing preferences.",
    difficulty: 3.75,
    rounds: [
      p("Summarize the two main preferences.", "Some people want the beach, while others prefer the mountains.", "State the disagreement neutrally.", [["Có người muốn đi biển,", "some people want the beach"], ["có người lại thích lên núi.", "while others prefer the mountains"]]),
      p("Identify the shared priority.", "But everyone wants somewhere that isn’t too crowded.", "Find the condition the whole group agrees on.", [["Nhưng ai cũng muốn", "but everyone wants"], ["chỗ nào đừng đông quá.", "somewhere that isn’t too crowded"]]),
      p("Propose a compromise.", "How about somewhere with both a beach and hiking nearby?", "Suggest an option that combines both interests.", [["Hay là mình chọn chỗ", "how about choosing somewhere"], ["vừa có biển vừa có đường đi bộ?", "with both a beach and hiking"]]),
      p("Check the budget before finalizing.", "If the cost stays under three million each, is everyone okay with it?", "Test the proposal against a concrete limit.", [["Nếu mỗi người dưới ba triệu", "if the cost stays under three million each"], ["thì mọi người thấy được không?", "is everyone okay with it"]]),
      p("Close the decision and assign research.", "Okay, let’s go with that. I’ll look for a place to stay tonight.", "Confirm the choice and take the next action.", [["Vậy chốt phương án đó nha,", "okay, let’s go with that"], ["tối nay mình tìm chỗ ở.", "I’ll look for a place to stay tonight"]], [["Vậy chốt phương án đó nhé,", "okay, let’s go with that"], ["tối nay mình tìm chỗ ở.", "I’ll look for a place to stay tonight"]]),
    ],
  },
];
