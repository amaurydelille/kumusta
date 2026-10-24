import { type LessonSpec, round as r, segment as s } from "./catalog.ts";

const sayHello = { unitOrder: 1, unitSlug: "say-hello", unitTitle: "Say hello" };
const eatAndPay = { unitOrder: 2, unitSlug: "eat-and-pay", unitTitle: "Eat and pay" };
const outAndAbout = { unitOrder: 3, unitSlug: "out-and-about", unitTitle: "Out and about" };

export const beginnerLessons: LessonSpec[] = [
  {
    order: 1,
    ...sayHello,
    title: "Greet your neighbour politely",
    scenario: "Say hello to the neighbours and learn when to add po.",
    difficulty: 1.0,
    goalTags: ["lifeInThePhilippines", "family", "travel"],
    rounds: [
      r(
        "Your new neighbour, a woman your age, waves at you.",
        "Hi! How are you?",
        "Greet her the easy, friendly way.",
        [
          s("Uy!", "hey!", "A warm, casual way to get someone's attention."),
          s("Kumusta ka?", "how are you?", "Ka is the casual 'you' for people your age."),
        ],
      ),
      r(
        "An older neighbour, Aling Nena, steps out of her gate.",
        "Good morning, ma'am.",
        "Greet her respectfully.",
        [
          s("Magandang umaga", "good morning", "Literally 'beautiful morning'."),
          s("po.", "(respect)", "Po shows respect to an older person."),
        ],
      ),
      r(
        "Ask Aling Nena how she is.",
        "How are you, ma'am?",
        "Ask how she is, keeping it respectful.",
        [
          s("Kumusta", "how are"),
          s("po kayo?", "you (respectful)?", "Kayo is the respectful 'you'; po adds courtesy."),
        ],
      ),
      r(
        "She asks how you are. Tell her you're fine.",
        "I'm fine, thank you.",
        "Answer and thank her politely.",
        [
          s("Mabuti naman", "I'm fine", "Naman softens it: 'fine, thankfully'."),
          s("po,", "(respect)"),
          s("salamat po.", "thank you (respectful)"),
        ],
      ),
      r(
        "Your friendly neighbour heads off to work.",
        "Take care!",
        "Wish her well as she leaves.",
        [
          s("Ingat", "take care", "A very common way to say goodbye."),
          s("ka!", "you!", "Casual 'you' again for a friend."),
        ],
      ),
    ],
  },
  {
    order: 2,
    ...sayHello,
    title: "Introduce yourself at a barkada party",
    scenario: "Meet your friend's barkada: share your name and where you're from.",
    difficulty: 1.1,
    goalTags: ["partner", "culture", "lifeInThePhilippines"],
    rounds: [
      r(
        "At a friend's birthday, someone from their barkada smiles and comes over.",
        "Hi! I'm Sam.",
        "Say hi and tell her your name.",
        [
          s("Hi!", "hi!", "Friends in Manila greet each other with an English 'hi' all the time."),
          s("Ako si", "I am", "Si comes right before a person's name."),
          s("Sam.", "Sam."),
        ],
      ),
      r(
        "She laughs and says she forgot to introduce herself.",
        "And you, what's your name?",
        "Turn the question back to her.",
        [
          s("Ikaw,", "and you,", "Starting with ikaw turns the question back: 'how about you?'"),
          s("anong pangalan", "what name", "Anong is ano plus the linker -ng."),
          s("mo?", "your?", "Mo means 'your' and comes after the noun."),
        ],
      ),
      r(
        "Her name is Joy. You hear an accent and get curious about her home province.",
        "Where are you from?",
        "Ask where she's from.",
        [
          s("Taga-saan", "from where", "Taga- means 'from' a place, so taga-saan is 'from where?'"),
          s("ka?", "are you?"),
        ],
      ),
      r(
        "Joy is from Cebu. She asks about you.",
        "I'm from Canada, but I live in Makati.",
        "Say where you're from and where you live now.",
        [
          s("Taga-Canada ako,", "I'm from Canada,", "Put taga- in front of any place name."),
          s("pero sa Makati", "but in Makati"),
          s("ako nakatira.", "I live.", "Nakatira means 'living, residing'."),
        ],
      ),
      r(
        "Your friend calls Joy over to cut the cake.",
        "Okay, see you around!",
        "Say a casual goodbye for now.",
        [
          s("Sige,", "okay,", "Sige is the all-purpose 'okay, go ahead'."),
          s("kita-kits!", "see you!", "Playful slang among friends, from 'kita tayo'."),
        ],
      ),
    ],
  },
  {
    order: 3,
    ...sayHello,
    title: "Meet Lola with a mano",
    scenario: "Greet your grandmother the respectful way and introduce your partner.",
    difficulty: 1.2,
    goalTags: ["family", "partner", "culture"],
    rounds: [
      r(
        "You arrive at your family's house with your partner. Lola is sitting in the living room.",
        "Your blessing, Lola.",
        "Ask for her blessing as you take her hand to your forehead.",
        [
          s("Mano po,", "your hand (blessing)", "Say this as you press her hand to your forehead."),
          s("Lola.", "Grandma."),
        ],
      ),
      r(
        "Lola squeezes your hand and smiles.",
        "Good afternoon, Lola. How are you?",
        "Greet her and ask how she is.",
        [
          s("Magandang hapon po,", "good afternoon,", "Hapon is the afternoon."),
          s("Lola.", "Grandma."),
          s("Kumusta po kayo?", "how are you?", "Use kayo and po with elders, never ka."),
        ],
      ),
      r(
        "Lola looks curiously at the person beside you.",
        "Lola, this is Alex, my boyfriend.",
        "Introduce your partner to her.",
        [
          s("Lola,", "Grandma,"),
          s("si Alex po,", "this is Alex,", "Si plus a name is enough to introduce someone."),
          s("ang boyfriend ko.", "my boyfriend.", "Ko means 'my' and comes after the noun."),
        ],
      ),
      r(
        "Alex tries out a shy hello. Lola is delighted.",
        "He's learning Tagalog.",
        "Tell her he's learning the language.",
        [
          s("Nag-aaral po siya", "he's studying", "Nag-aaral is 'studying' right now."),
          s("ng Tagalog.", "Tagalog."),
        ],
      ),
      r(
        "Lola waves you both toward the table full of food.",
        "Thank you, Lola. We'll eat now.",
        "Thank her and say you'll both eat.",
        [
          s("Salamat po, Lola.", "thank you, Grandma."),
          s("Kakain na po", "we'll eat now", "Kakain is 'will eat'; na means 'now'."),
          s("kami.", "we (not including her)."),
        ],
      ),
    ],
  },
  {
    order: 4,
    ...eatAndPay,
    title: "Order at the carinderia",
    scenario: "Point at the dishes, order a meal with rice and pay for it.",
    difficulty: 1.3,
    goalTags: ["lifeInThePhilippines", "travel"],
    rounds: [
      r(
        "You're at a busy roadside eatery with trays of food behind the glass. Point at one.",
        "Miss, what's this?",
        "Ask the server what the dish is.",
        [
          s("Ate,", "miss,", "Ate ('big sister') is a polite way to address a woman serving you."),
          s("ano po", "what"),
          s("ito?", "is this?", "Ito is 'this', for something near you."),
        ],
      ),
      r(
        "She says it's sinigang, a sour soup. It looks great.",
        "One sinigang, please.",
        "Order one serving of it.",
        [
          s(
            "Isa nga pong",
            "one, please,",
            "Nga po makes a request polite; po becomes pong before a noun.",
          ),
          s("sinigang.", "sinigang (sour soup)."),
        ],
      ),
      r(
        "She asks if you want anything with it.",
        "And one rice, please.",
        "Add a cup of rice to your order.",
        [
          s("Saka", "and also", "Saka adds one more thing; many people say tsaka."),
          s("isang kanin", "one rice", "Isa becomes isang before a noun."),
          s("po.", "(respect)"),
        ],
      ),
      r(
        "You finish eating and walk to the counter.",
        "How much is it all?",
        "Ask for the total.",
        [
          s("Magkano po", "how much", "Magkano is the question for prices."),
          s("lahat?", "for everything?"),
        ],
      ),
      r(
        "She tells you the total. Hand her the money.",
        "Here's my payment.",
        "Say this as you hand over the money.",
        [
          s("Heto po", "here", "Heto is 'here it is' as you hand something over."),
          s("ang bayad ko.", "my payment.", "Bayad is a payment or fare."),
        ],
      ),
    ],
  },
  {
    order: 5,
    ...eatAndPay,
    title: "Sari-sari store run",
    scenario: "Buy a snack and a drink at the corner store and check your change.",
    difficulty: 1.4,
    goalTags: ["lifeInThePhilippines", "travel"],
    rounds: [
      r(
        "You walk up to the little corner store window. The owner is inside watching TV.",
        "Excuse me, I'd like to buy something!",
        "Call out to get the owner's attention.",
        [
          s(
            "Pabili",
            "may I buy",
            "The classic call at a store window, roughly 'selling, please!'",
          ),
          s("po!", "(respect)!"),
        ],
      ),
      r(
        "She comes to the window. Point at the snacks hanging up.",
        "One chicharon, please.",
        "Ask for one bag of pork cracklings.",
        [
          s("Isang chicharon", "one chicharon", "Pork cracklings, a classic store snack."),
          s("nga po.", "please.", "Nga po softens a request."),
        ],
      ),
      r(
        "It's hot out and you're thirsty.",
        "Do you have cold water?",
        "Ask whether she has cold water.",
        [
          s("May malamig", "is there cold", "May means 'there is' or 'have'."),
          s("po ba", "(question)", "Ba turns the sentence into a yes-or-no question."),
          s("kayong tubig?", "water, do you?", "Kayo plus the linker -ng joins it to tubig."),
        ],
      ),
      r(
        "She says it all comes to eighty pesos. You only have a big bill.",
        "Eighty? Here's a hundred.",
        "Check the price and hand her the bill.",
        [
          s("Otsenta po?", "eighty?", "Prices are often said with Spanish numbers: otsenta is 80."),
          s("Heto pong", "here's", "Heto po becomes heto pong before the amount."),
          s("isang daan.", "one hundred."),
        ],
      ),
      r(
        "She counts out some coins and hands them to you.",
        "My change is twenty, right?",
        "Check that your change is right.",
        [
          s("Bente po", "twenty", "Bente is 20, from Spanish veinte."),
          s("ang sukli,", "is the change,", "Sukli is the change you get back."),
          s("di ba?", "right?", "Di ba is short for hindi ba, 'isn't it?'"),
        ],
      ),
    ],
  },
  {
    order: 6,
    ...eatAndPay,
    title: "Let's eat: lunch with a friend",
    scenario: "Check if your friend has eaten, then pick a dish and a place.",
    difficulty: 1.5,
    goalTags: ["partner", "culture", "lifeInThePhilippines"],
    rounds: [
      r(
        "It's noon and your friend Carlo drops by your desk.",
        "Have you eaten yet?",
        "Ask him the classic Filipino check-in question.",
        [
          s("Kumain", "eaten", "Kumain is the completed form of 'eat'."),
          s("ka na?", "have you yet?", "Asking this is a way of saying 'I care about you'."),
        ],
      ),
      r(
        "He says not yet, and he's starving.",
        "Come on, let's eat!",
        "Invite him to go eat with you.",
        [
          s("Tara,", "come on,", "Tara is 'let's go'."),
          s("kain tayo!", "let's eat!", "Tayo is the 'we' that includes the listener."),
        ],
      ),
      r(
        "On the way out, he asks what you're in the mood for. You turn it back to him.",
        "What do you want to eat?",
        "Ask what he feels like eating.",
        [
          s("Anong gusto", "what (do you) want", "Gusto means 'want' or 'like'."),
          s("mong kainin?", "you to eat?", "Mo plus -ng links it to kainin, 'to eat'."),
        ],
      ),
      r(
        "He can't decide and says you choose.",
        "Me, I'd like sisig.",
        "Say what you'd like to eat.",
        [
          s("Ako,", "me,"),
          s("gusto ko", "I want", "Ko is 'I' here, the one who wants."),
          s("ng sisig.", "sisig (sizzling pork).", "Ng marks the thing you want."),
        ],
      ),
      r(
        "You know a cheap place at the end of the street.",
        "Let's just go to the corner place. It's cheap there.",
        "Suggest the place on the corner and say why.",
        [
          s("Sa kanto", "at the corner", "Kanto is a street corner."),
          s("na lang tayo,", "let's just go,", "Na lang means 'just, instead'."),
          s("mura doon.", "it's cheap there."),
        ],
      ),
    ],
  },
  {
    order: 7,
    ...outAndAbout,
    title: "Ride a jeepney",
    scenario: "Check the route, pass the fare and get off at your stop.",
    difficulty: 1.6,
    goalTags: ["travel", "lifeInThePhilippines"],
    rounds: [
      r(
        "A jeepney pulls up. Before climbing in, check the route with the driver.",
        "Driver, is this going to Cubao?",
        "Ask the driver if it goes to Cubao.",
        [
          s("Kuya,", "driver,", "Kuya ('big brother') is how you address a male driver."),
          s("Cubao po", "to Cubao"),
          s("ba ito?", "is this?", "Ba makes it a yes-or-no question."),
        ],
      ),
      r(
        "You sit at the back, far from the driver. Hand your coins to the passenger next to you.",
        "Here's my fare, just one.",
        "Pass your fare and say it's for one person.",
        [
          s("Bayad po,", "fare,", "Bayad is what everyone says when passing money forward."),
          s("isa lang.", "just one.", "Lang means 'just, only'."),
        ],
      ),
      r(
        "A new passenger hands you coins to pass forward to the driver.",
        "Driver, here's a fare from them.",
        "Pass it on and tell the driver it's someone else's.",
        [
          s("Kuya,", "driver,"),
          s(
            "bayad daw",
            "a fare, they say",
            "Daw means someone else said it; use raw after a vowel.",
          ),
          s("po.", "(respect)."),
        ],
      ),
      r(
        "You don't know the stops well. Ask the driver to warn you.",
        "Please tell me when we reach Cubao.",
        "Ask him to let you know when you get there.",
        [
          s("Pakisabi po", "please tell me", "Paki- turns a verb into a polite request."),
          s("kapag Cubao na.", "when it's Cubao already.", "Kapag means 'when'."),
        ],
      ),
      r(
        "You see your stop coming up.",
        "Stop please, just by the side!",
        "Tell the driver to stop so you can get off.",
        [
          s("Para po,", "stop,", "Para is how you ask any jeepney to stop."),
          s("sa tabi lang!", "just at the side!"),
        ],
      ),
    ],
  },
  {
    order: 8,
    ...outAndAbout,
    title: "Ask for directions",
    scenario: "Find an ATM, the pharmacy and the mall by asking a guard.",
    difficulty: 1.7,
    goalTags: ["travel", "lifeInThePhilippines"],
    rounds: [
      r(
        "You need cash. A security guard is standing outside a bank on a busy street.",
        "Excuse me, is there an ATM near here?",
        "Ask him if there's a cash machine nearby.",
        [
          s("Kuya,", "excuse me (sir),", "Use kuya for a man a bit older than you."),
          s("may ATM po ba", "is there an ATM", "May means 'there is'."),
          s("malapit dito?", "near here?", "Malapit is 'near'."),
        ],
      ),
      r(
        "He points and gives directions quickly. Repeat them back to be sure.",
        "Straight ahead, then right?",
        "Check that you understood the way.",
        [
          s("Diretso lang po,", "just straight,", "From Spanish derecho."),
          s("tapos kanan?", "then right?", "Kanan is right; kaliwa is left."),
        ],
      ),
      r(
        "You also need medicine for a headache.",
        "Where's the nearest pharmacy?",
        "Ask him where the closest pharmacy is.",
        [
          s("Saan po ang", "where is the", "Saan asks for a place."),
          s("pinakamalapit na", "nearest", "Pinaka- means 'most'; na links it to the noun."),
          s("botika?", "pharmacy?"),
        ],
      ),
      r(
        "He says it's past the church.",
        "Is it far? Can I walk there?",
        "Ask if it's far and whether you can walk.",
        [
          s("Malayo po ba?", "is it far?"),
          s("Kaya bang", "is it possible", "Kaya means 'can manage'."),
          s("lakarin?", "to walk?", "Lakarin is 'to walk (a distance)'."),
        ],
      ),
      r(
        "Last stop of the day is the mall, but you have no idea which way it is.",
        "How do I get to the mall?",
        "Ask him how to get to the mall.",
        [
          s("Paano po", "how", "Paano asks 'how'."),
          s("pumunta", "to go"),
          s("sa mall?", "to the mall?", "Sa marks where you're going."),
        ],
      ),
    ],
  },
  {
    order: 9,
    ...outAndAbout,
    title: "Halo-halo and fruit at the market",
    scenario: "Order a dessert at the market, then haggle a little over mangoes.",
    difficulty: 1.8,
    goalTags: ["travel", "culture", "lifeInThePhilippines"],
    rounds: [
      r(
        "It's a hot afternoon at the market. A woman is shaving ice at a dessert stall.",
        "Miss, one halo-halo, please.",
        "Order one of the famous shaved-ice desserts.",
        [
          s("Ate,", "miss,"),
          s(
            "isang halo-halo",
            "one halo-halo",
            "Halo-halo means 'mix-mix': you stir it all together.",
          ),
          s("nga po.", "please."),
        ],
      ),
      r(
        "You see slices of leche flan next to the ice. You want extra.",
        "Can you add more leche flan?",
        "Ask her to add extra caramel custard.",
        [
          s("Puwede pong", "can you", "Puwede is 'can, may'; often written pwede."),
          s("dagdagan", "add more"),
          s("ng leche flan?", "leche flan?", "A caramel custard from the Spanish era."),
        ],
      ),
      r(
        "After your dessert, you stop at a fruit stand piled with ripe mangoes.",
        "How much for a kilo of mangoes?",
        "Ask the price of one kilo.",
        [
          s("Magkano po", "how much"),
          s("ang isang kilo", "is one kilo", "Fruit is sold by the kilo."),
          s("ng mangga?", "of mangoes?"),
        ],
      ),
      r(
        "The vendor names a price that seems a bit high.",
        "That's pricey. Any discount?",
        "React to the price and ask for a discount.",
        [
          s(
            "Ang mahal naman.",
            "that's so pricey.",
            "Ang plus an adjective is an exclamation: 'how expensive!'",
          ),
          s("May tawad", "is there a discount", "Tawad is a haggled discount."),
          s("pa po?", "still?", "Pa means 'still, more'."),
        ],
      ),
      r(
        "The vendor laughs and waits for your offer.",
        "Make it a hundred and I'll take it.",
        "Offer one hundred pesos and promise to buy.",
        [
          s("Isang daan", "one hundred"),
          s("na lang po,", "just, please,", "Na lang lowers an offer: 'just this instead'."),
          s("kukunin ko na.", "I'll take it now.", "Kukunin is 'will take'."),
        ],
      ),
    ],
  },
  {
    order: 10,
    ...outAndAbout,
    title: "Set a time to meet up",
    scenario: "Plan a weekend meetup with a friend: the time and the place.",
    difficulty: 1.9,
    goalTags: ["partner", "lifeInThePhilippines"],
    rounds: [
      r(
        "You're chatting with your friend Bea on the phone about the weekend.",
        "Are you free tomorrow?",
        "Ask if she's free tomorrow.",
        [
          s("Libre ka ba", "are you free", "Libre means both 'free time' and 'free of charge'."),
          s("bukas?", "tomorrow?"),
        ],
      ),
      r(
        "She says yes, after lunch.",
        "What time works for you?",
        "Ask her what time she can make it.",
        [
          s("Anong oras", "what time", "Oras is time, the hour."),
          s("ka puwede?", "can you?"),
        ],
      ),
      r(
        "She suggests mid-afternoon. You agree on a time.",
        "Okay, three in the afternoon.",
        "Confirm three o'clock in the afternoon.",
        [
          s("Sige,", "okay,"),
          s("alas-tres", "three o'clock", "Clock times use Spanish numbers: alas-dos, alas-tres."),
          s("ng hapon.", "in the afternoon."),
        ],
      ),
      r(
        "Now pick an easy place to find each other in town.",
        "Let's meet in front of the church.",
        "Suggest meeting in front of the church.",
        [
          s("Kita tayo", "let's meet", "Kita tayo is 'let's see each other'."),
          s("sa harap", "in front"),
          s("ng simbahan.", "of the church."),
        ],
      ),
      r(
        "Bea is famous for running late. Tease her before you hang up.",
        "Don't be late, okay!",
        "Tell her not to be late, in a playful way.",
        [
          s("Huwag kang", "don't you", "Huwag plus ka plus the linker -ng: 'don't you...'"),
          s(
            "male-late,",
            "be late,",
            "Manila speakers happily put Tagalog prefixes on English verbs.",
          ),
          s("ha!", "okay!", "Ha at the end adds 'okay?' with a friendly push."),
        ],
      ),
    ],
  },
];
