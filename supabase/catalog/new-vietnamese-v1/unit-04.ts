import { type LessonSpec, round as r, segment as s } from "./catalog.ts";
const unitOrder = 4, unitSlug = "shop-and-pay", unitTitle = "Shop and pay";
export const unit04: LessonSpec[] = [
  {
    order: 16,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Ask the price",
    scenario: "Check individual prices and the total before buying.",
    difficulty: 1.6,
    rounds: [
      r(
        "Point to an item and ask its price.",
        "How much is this?",
        "Ask the everyday price question.",
        [s("Cái này", "this item"), s("bao nhiêu tiền vậy?", "how much is it?")],
        [s("Cái này", "this item"), s("bao nhiêu tiền ạ?", "how much is it, politely?")],
      ),
      r("Ask the price for one item.", "How much for one?", "Make the quantity clear.", [
        s("Một cái", "one item"),
        s("bao nhiêu tiền?", "how much?"),
      ]),
      r(
        "Ask the total for two items.",
        "How much for two altogether?",
        "Ask for the combined price.",
        [s("Hai cái", "two items"), s("hết bao nhiêu?", "come to how much?")],
      ),
      r(
        "Confirm that you heard the price correctly.",
        "That price is right, yes?",
        "Check the amount before deciding.",
        [s("Giá này", "this price"), s("đúng không?", "is it correct?")],
      ),
      r("Choose to buy one item.", "Yes, I’ll take one.", "Make the purchase decision.", [
        s("Dạ,", "yes, politely"),
        s("mình lấy một cái.", "I’ll take one"),
      ], [s("Vâng,", "yes, politely"), s("mình lấy một cái ạ.", "I’ll take one")]),
    ],
  },
  {
    order: 17,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Choose the right quantity",
    scenario: "Increase, reduce, and confirm how many items you want.",
    difficulty: 1.65,
    rounds: [
      r(
        "Choose two of the items in front of you.",
        "I’ll take two of these.",
        "State the quantity and item.",
        [s("Cho mình", "I’ll take"), s("hai cái này.", "two of these")],
      ),
      r(
        "Correct the quantity to just one.",
        "I’m only taking one.",
        "Make the correction gently.",
        [s("Mình chỉ lấy", "I’m only taking"), s("một cái thôi.", "one item")],
      ),
      r("Add one more item.", "Please give me one more.", "Use the extra-item request.", [
        s("Cho mình thêm", "give me another"),
        s("một cái nữa.", "one more item"),
      ]),
      r(
        "Choose three bottles of water.",
        "I’ll take three bottles of water.",
        "Keep the number and classifier together.",
        [s("Mình lấy", "I’ll take"), s("ba chai nước.", "three bottles of water")],
      ),
      r("Confirm that you now have enough.", "That’s enough now.", "Close the quantity change.", [
        s("Vậy là", "that makes it"),
        s("đủ rồi.", "enough now"),
      ], [s("Thế là", "that makes it"), s("đủ rồi ạ.", "enough now")]),
    ],
  },
  {
    order: 18,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Compare another option",
    scenario: "Ask for another color, size, or price range.",
    difficulty: 1.7,
    rounds: [
      r(
        "Ask whether another color is available.",
        "Is there another color?",
        "Ask for an alternative color.",
        [s("Có", "is there"), s("màu khác không?", "another color?")],
      ),
      r(
        "Ask to see the blue version.",
        "Could I see the blue one?",
        "Request the color you want to compare.",
        [s("Cho mình coi", "let me see"), s("màu xanh được không?", "the blue one?")],
        [s("Cho mình xem", "let me see"), s("màu xanh được không ạ?", "the blue one, politely?")],
      ),
      r("Ask whether there is a larger size.", "Is there a larger size?", "Ask for a size up.", [
        s("Có", "is there"),
        s("cỡ lớn hơn không?", "a larger size?"),
      ]),
      r(
        "Explain that this size is too small.",
        "This size is too small.",
        "State the problem simply.",
        [s("Cỡ này", "this size"), s("nhỏ quá.", "is too small")],
      ),
      r(
        "Ask whether there is a cheaper option.",
        "Is there a cheaper kind?",
        "Ask for a lower-priced alternative.",
        [s("Có", "is there"), s("loại rẻ hơn không?", "a cheaper kind?")],
      ),
    ],
  },
  {
    order: 19,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Pay for the purchase",
    scenario: "Choose a payment method and finish at the checkout.",
    difficulty: 1.75,
    rounds: [
      r(
        "Ask whether card payment is accepted.",
        "Can I pay by card?",
        "Ask before presenting the card.",
        [s("Mình trả", "I pay"), s("bằng thẻ được không?", "by card, is that possible?")],
      ),
      r("Say that you will pay cash.", "I’ll pay cash.", "Give the payment choice.", [
        s("Mình trả", "I’ll pay"),
        s("tiền mặt.", "cash"),
      ]),
      r(
        "Ask whether the seller has change.",
        "Do you have change?",
        "Ask the practical cash question.",
        [s("Bạn có", "do you have"), s("tiền lẻ không?", "change / small notes?")],
      ),
      r("Ask for the receipt.", "Could I have the receipt?", "Make the short receipt request.", [
        s("Cho mình xin", "could I have"),
        s("hóa đơn.", "the receipt"),
      ]),
      r("Ask for a bag before leaving.", "Could I have a bag?", "Finish with the bag request.", [
        s("Cho mình xin", "could I have"),
        s("một cái túi", "one bag"),
        s("được không?", "is that possible?"),
      ]),
    ],
  },
  {
    order: 20,
    unitOrder,
    unitSlug,
    unitTitle,
    title: "Buy something successfully",
    scenario: "Choose an item, compare it, and complete payment.",
    difficulty: 1.8,
    rounds: [
      r(
        "Ask the price of an item.",
        "How much is this?",
        "Open with the familiar price question.",
        [s("Cái này", "this item"), s("bao nhiêu tiền vậy?", "how much is it?")],
        [s("Cái này", "this item"), s("bao nhiêu tiền ạ?", "how much is it, politely?")],
      ),
      r("Ask to see another color.", "Could I see another color?", "Request an alternative.", [
        s("Cho mình coi", "let me see"),
        s("màu khác được không?", "another color?"),
      ], [
        s("Cho mình xem", "let me see"),
        s("màu khác được không ạ?", "another color, politely?"),
      ]),
      r("Choose two items.", "I’ll take two of these.", "State the final quantity.", [
        s("Mình lấy", "I’ll take"),
        s("hai cái này.", "two of these"),
      ]),
      r("Ask to pay by card.", "Can I pay by card?", "Give the payment preference.", [
        s("Mình trả", "I pay"),
        s("bằng thẻ được không?", "by card, is that possible?"),
      ]),
      r(
        "Request both the receipt and a bag.",
        "Could I have the receipt and a bag?",
        "Close with both final items.",
        [
          s("Cho mình xin", "could I have"),
          s("hóa đơn", "the receipt"),
          s("và một cái túi.", "and one bag"),
        ],
      ),
    ],
  },
];
