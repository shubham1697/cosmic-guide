import '../models/zodiac.dart';

HoroscopeData getHoroscope(String sign) {
  final horoscopes = {
    'Aries': const HoroscopeData(
      sign: 'Aries',
      date: 'Today',
      general:
          'Today brings a surge of energy and motivation. The stars align to support bold decisions. Trust your instincts and take that leap of faith you\'ve been contemplating.',
      love:
          'Romance is in the air. If single, an unexpected encounter could spark something beautiful. Couples should plan a spontaneous date to reignite the flame.',
      career:
          'Your leadership skills shine brightly today. A new project or opportunity may present itself. Colleagues look to you for guidance — embrace it confidently.',
      health:
          'Channel your abundant energy into physical activity. A morning workout sets the tone for a vibrant day. Stay hydrated and take breaks when needed.',
      overallScore: 85,
      luckyNumber: '7',
      luckyColor: 'Red',
      mood: 'Energetic',
    ),
    'Taurus': const HoroscopeData(
      sign: 'Taurus',
      date: 'Today',
      general:
          'Stability and comfort are your themes today. Focus on building lasting foundations in all areas of life. Your patience will be rewarded with meaningful progress.',
      love:
          'Show your partner your appreciation through small, thoughtful gestures. Singles may find comfort in a familiar face that sees you in a new light.',
      career:
          'Financial opportunities arise. Your practical approach to work impresses superiors. A steady, methodical approach yields the best results today.',
      health:
          'Treat yourself to nourishing food and gentle exercise. A walk in nature reconnects you with your earthy energy. Avoid overindulgence.',
      overallScore: 78,
      luckyNumber: '4',
      luckyColor: 'Green',
      mood: 'Grounded',
    ),
    'Gemini': const HoroscopeData(
      sign: 'Gemini',
      date: 'Today',
      general:
          'Your mind buzzes with brilliant ideas today. Social connections bring unexpected opportunities. Embrace your dual nature — both logic and creativity serve you well right now.',
      love:
          'Communication is your superpower in love today. Share your thoughts openly — vulnerability strengthens bonds. Singles may find sparks flying through witty conversation.',
      career:
          'Multitasking comes naturally today. A brainstorming session yields breakthrough ideas. Network actively — your charm opens doors that effort alone cannot.',
      health:
          'Mental stimulation is as vital as physical health. Try a puzzle or learn something new. Calm your racing mind with breathing exercises before bed.',
      overallScore: 82,
      luckyNumber: '5',
      luckyColor: 'Yellow',
      mood: 'Curious',
    ),
    'Cancer': const HoroscopeData(
      sign: 'Cancer',
      date: 'Today',
      general:
          'Home and family take center stage today. Your nurturing instincts are heightened — trust them. Emotional insights guide you toward meaningful decisions that benefit everyone around you.',
      love:
          'Deep emotional connections flourish today. Express your feelings without fear — your partner craves your tenderness. Singles may feel drawn to someone who feels like home.',
      career:
          'Your intuition about workplace dynamics is spot-on today. A supportive gesture toward a colleague builds a lasting alliance. Creative projects benefit from your emotional depth.',
      health:
          'Comfort food calls, but balance indulgence with nutrition. Water activities soothe your soul — consider a swim or a long bath. Prioritize rest tonight.',
      overallScore: 79,
      luckyNumber: '2',
      luckyColor: 'Silver',
      mood: 'Nurturing',
    ),
    'Leo': const HoroscopeData(
      sign: 'Leo',
      date: 'Today',
      general:
          'The spotlight finds you effortlessly today. Your natural radiance draws admiration and opportunity. Step into your power with confidence — the universe rewards bold self-expression.',
      love:
          'Passion runs high today. Grand gestures and heartfelt words strengthen romantic bonds. Singles should let their magnetic personality shine — someone special is watching.',
      career:
          'Leadership opportunities abound. Your creative vision inspires your team and catches the attention of decision-makers. Present your ideas with the confidence they deserve.',
      health:
          'Your vitality is strong today. Channel it into an activity you love — dance, sports, or outdoor adventures. Protect your heart with cardiovascular exercise.',
      overallScore: 88,
      luckyNumber: '1',
      luckyColor: 'Gold',
      mood: 'Confident',
    ),
    'Virgo': const HoroscopeData(
      sign: 'Virgo',
      date: 'Today',
      general:
          'Details matter today, and you see them all. Your analytical mind solves problems others overlook. Focus on organization and refinement — small improvements lead to significant results.',
      love:
          'Acts of service speak louder than words in love today. Show you care through practical support. Singles may connect with someone who appreciates your thoughtful, grounded nature.',
      career:
          'Precision and thoroughness earn you recognition. A complex task that others gave up on yields to your methodical approach. Document your process — it will be valuable later.',
      health:
          'Pay attention to nutrition and digestive health today. A clean, balanced meal plan works wonders. Gentle yoga or stretching helps release tension you carry in your shoulders.',
      overallScore: 81,
      luckyNumber: '6',
      luckyColor: 'Navy',
      mood: 'Analytical',
    ),
    'Libra': const HoroscopeData(
      sign: 'Libra',
      date: 'Today',
      general:
          'Harmony and balance guide you today. Your diplomatic skills resolve tensions with grace. Beauty surrounds you — take time to appreciate art, music, or the natural world.',
      love:
          'Partnership energy is strong. Compromise comes easily and deepens your connection. Singles are drawn to elegance and intellect — an art gallery or concert may hold romantic potential.',
      career:
          'Collaboration yields exceptional results. Your ability to see all sides makes you an invaluable mediator. A partnership or joint venture shows promising signs today.',
      health:
          'Seek aesthetic pleasure in your wellness routine. A beautifully prepared meal or a luxurious skincare ritual lifts your spirits. Balance social time with peaceful solitude.',
      overallScore: 80,
      luckyNumber: '8',
      luckyColor: 'Pink',
      mood: 'Harmonious',
    ),
    'Scorpio': const HoroscopeData(
      sign: 'Scorpio',
      date: 'Today',
      general:
          'Powerful transformations stir beneath the surface today. Your intensity and depth of perception reveal hidden truths. Trust your instincts — they pierce through illusion like no other sign.',
      love:
          'Intimacy deepens as you allow yourself to be truly seen. Magnetic attraction draws others to your enigmatic presence. Singles may feel an intense, almost fated connection.',
      career:
          'Research and investigation yield breakthroughs. Your ability to dig deeper where others stop gives you a competitive edge. A secret or hidden information comes to light in your favor.',
      health:
          'Emotional release is vital for your well-being today. Journal, meditate, or engage in intense exercise to process deep feelings. Hydration and detoxifying foods support your body.',
      overallScore: 83,
      luckyNumber: '3',
      luckyColor: 'Crimson',
      mood: 'Intense',
    ),
    'Sagittarius': const HoroscopeData(
      sign: 'Sagittarius',
      date: 'Today',
      general:
          'Adventure beckons and your optimism is infectious. The horizon expands with possibilities — say yes to new experiences. A philosophical insight shifts your perspective in a meaningful way.',
      love:
          'Freedom and excitement fuel your romantic energy. Surprise your partner with a spontaneous adventure. Singles thrive in travel or educational settings — love finds the open-minded.',
      career:
          'Big-picture thinking sets you apart today. An international or cross-cultural opportunity may arise. Your enthusiasm for learning opens doors to growth. Teach others what you know.',
      health:
          'Outdoor activity is your best medicine. Hiking, cycling, or exploring a new trail invigorates your body and spirit. Watch your tendency to overdo — moderation sustains energy.',
      overallScore: 86,
      luckyNumber: '11',
      luckyColor: 'Turquoise',
      mood: 'Adventurous',
    ),
    'Capricorn': const HoroscopeData(
      sign: 'Capricorn',
      date: 'Today',
      general:
          'Discipline and ambition drive you toward your goals today. Long-term plans crystallize into actionable steps. Your reputation for reliability opens doors — honor your commitments.',
      love:
          'Steady devotion speaks volumes today. Show your commitment through consistency and dependability. Singles may find attraction in someone ambitious and grounded like themselves.',
      career:
          'Authority figures take notice of your dedication. A promotion or increased responsibility is on the horizon. Your strategic planning pays dividends — stay the course.',
      health:
          'Bone and joint health deserve attention. Strength training and calcium-rich foods support your framework. Take breaks from desk work — your posture will thank you.',
      overallScore: 77,
      luckyNumber: '10',
      luckyColor: 'Charcoal',
      mood: 'Determined',
    ),
    'Aquarius': const HoroscopeData(
      sign: 'Aquarius',
      date: 'Today',
      general:
          'Innovation and originality mark your day. Your unconventional ideas are ahead of their time — don\'t let skeptics dim your vision. Community involvement brings unexpected fulfillment.',
      love:
          'Intellectual connection sparks romance. Share your visions for the future with someone who appreciates your uniqueness. Singles may find love through humanitarian causes or group activities.',
      career:
          'Technology and innovation are your allies. A creative solution to a longstanding problem earns respect. Collaborate with like-minded visionaries — together you can change the game.',
      health:
          'Circulation and nervous system health benefit from attention today. Try something unconventional — cold plunges, acupuncture, or sound healing. Social wellness matters too.',
      overallScore: 84,
      luckyNumber: '22',
      luckyColor: 'Electric Blue',
      mood: 'Visionary',
    ),
    'Pisces': const HoroscopeData(
      sign: 'Pisces',
      date: 'Today',
      general:
          'Your imagination and intuition are exceptionally strong today. Dreams may hold meaningful messages — pay attention. Creative and spiritual pursuits bring deep satisfaction and clarity.',
      love:
          'Your empathetic nature creates soul-deep connections. Romance feels almost magical today — lean into it. Singles may sense a kindred spirit through art, music, or shared vulnerability.',
      career:
          'Creative projects flourish under your inspired touch. Your ability to sense what others need makes you invaluable in collaborative settings. Trust your artistic vision — it\'s right on target.',
      health:
          'Water is your healing element today. Swimming, baths, or simply drinking more water restores your energy. Protect your sensitive nature with healthy boundaries and quiet reflection.',
      overallScore: 76,
      luckyNumber: '12',
      luckyColor: 'Sea Green',
      mood: 'Dreamy',
    ),
  };
  return horoscopes[sign] ??
      HoroscopeData(
        sign: sign,
        date: 'Today',
        general:
            'The cosmos sends you waves of positive energy today. Embrace new opportunities and trust in the universal flow. Your intuition is your greatest guide.',
        love:
            'Open your heart to love\'s possibilities. Whether deepening existing bonds or discovering new connections, the stars favor matters of the heart.',
        career:
            'Professional growth is highlighted. Your unique talents catch the eye of someone influential. Stay focused and dedicated to your goals.',
        health:
            'Balance is key today. Nourish your body, mind, and spirit equally. Gentle exercise and meditation bring harmony to your well-being.',
        overallScore: 75,
        luckyNumber: '9',
        luckyColor: 'Purple',
        mood: 'Intuitive',
      );
}
