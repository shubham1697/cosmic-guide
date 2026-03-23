"""Horoscope data and retrieval."""

from datetime import date

# Pre-written horoscope templates per sign
HOROSCOPE_DATA = {
    "Aries": {
        "general": "Today is a day of bold moves and fresh starts. Your natural leadership shines through, and others look to you for guidance. Trust your instincts — they rarely lead you astray. A surprising opportunity may present itself by evening.",
        "love": "Romance is in the air for Aries today. If single, a chance encounter could spark something meaningful. In a relationship, your partner appreciates your directness. Show your softer side tonight.",
        "career": "Your professional life gets a boost today. A project you've been working on gains momentum. Colleagues admire your drive. Stay focused and avoid unnecessary conflicts — diplomacy wins the day.",
        "health": "Your energy levels are high today. Channel this into physical activity — a morning run or workout will set the tone. Stay hydrated and don't skip meals despite your busy schedule.",
        "overall_score": 85, "lucky_number": "7", "lucky_color": "Red", "mood": "Energetic",
    },
    "Taurus": {
        "general": "Stability and comfort are your themes today. Financial matters look favorable — a good day for practical decisions. Your patience is tested but rewarded. Ground yourself in nature if possible.",
        "love": "Sensuality and deep connection define your love life today. Plan a cozy evening with your partner. Singles may find attraction in unexpected places. Let your guard down a little.",
        "career": "Hard work pays off as recognition comes your way. A raise or promotion may be discussed. Stick to your methodical approach — rushing won't serve you. Collaborate with earth sign colleagues.",
        "health": "Focus on relaxation today. Your body needs rest after recent exertion. A warm bath, gentle stretching, or meditation will restore your balance. Pay attention to your throat and neck.",
        "overall_score": 78, "lucky_number": "4", "lucky_color": "Green", "mood": "Grounded",
    },
    "Gemini": {
        "general": "Your mind buzzes with brilliant ideas today. Social connections bring unexpected opportunities. Embrace your dual nature — both logic and creativity serve you well. A conversation sparks a new direction.",
        "love": "Communication is your superpower in love today. Share your thoughts openly — vulnerability strengthens bonds. Singles may find sparks flying through witty conversation and intellectual connection.",
        "career": "Multitasking comes naturally today. A brainstorming session yields breakthrough ideas. Network actively — your charm opens doors that effort alone cannot. Write down your best ideas.",
        "health": "Mental stimulation is as vital as physical health. Try a puzzle or learn something new. Calm your racing mind with breathing exercises before bed. Watch your screen time tonight.",
        "overall_score": 82, "lucky_number": "5", "lucky_color": "Yellow", "mood": "Curious",
    },
    "Cancer": {
        "general": "Home and family take center stage today. Your nurturing instincts are heightened — trust them. Emotional insights guide you toward meaningful decisions that benefit everyone around you.",
        "love": "Deep emotional connections flourish today. Express your feelings without fear — your partner craves your tenderness. Singles may feel drawn to someone who feels like home and safety.",
        "career": "Your intuition about workplace dynamics is spot-on today. A supportive gesture toward a colleague builds a lasting alliance. Creative projects benefit from your emotional depth and sensitivity.",
        "health": "Comfort food calls, but balance indulgence with nutrition. Water activities soothe your soul — consider a swim or a long bath. Prioritize rest and emotional processing tonight.",
        "overall_score": 79, "lucky_number": "2", "lucky_color": "Silver", "mood": "Nurturing",
    },
    "Leo": {
        "general": "The spotlight finds you effortlessly today. Your natural radiance draws admiration and opportunity. Step into your power with confidence — the universe rewards bold self-expression and authenticity.",
        "love": "Passion runs high today. Grand gestures and heartfelt words strengthen romantic bonds. Singles should let their magnetic personality shine — someone special is watching and captivated.",
        "career": "Leadership opportunities abound. Your creative vision inspires your team and catches the attention of decision-makers. Present your ideas with the confidence and flair they deserve.",
        "health": "Your vitality is strong today. Channel it into an activity you love — dance, sports, or outdoor adventures. Protect your heart with cardiovascular exercise and joyful movement.",
        "overall_score": 88, "lucky_number": "1", "lucky_color": "Gold", "mood": "Confident",
    },
    "Virgo": {
        "general": "Details matter today, and you see them all. Your analytical mind solves problems others overlook. Focus on organization and refinement — small improvements lead to significant results over time.",
        "love": "Acts of service speak louder than words in love today. Show you care through practical support and thoughtful gestures. Singles may connect with someone who appreciates your grounded nature.",
        "career": "Precision and thoroughness earn you recognition. A complex task that others gave up on yields to your methodical approach. Document your process — it will prove valuable later.",
        "health": "Pay attention to nutrition and digestive health today. A clean, balanced meal plan works wonders for your energy. Gentle yoga or stretching helps release tension in your shoulders.",
        "overall_score": 81, "lucky_number": "6", "lucky_color": "Navy", "mood": "Analytical",
    },
    "Libra": {
        "general": "Harmony and balance guide you today. Your diplomatic skills resolve tensions with grace and ease. Beauty surrounds you — take time to appreciate art, music, or the natural world.",
        "love": "Partnership energy is strong. Compromise comes easily and deepens your connection. Singles are drawn to elegance and intellect — an art gallery or concert may hold romantic potential.",
        "career": "Collaboration yields exceptional results. Your ability to see all sides makes you an invaluable mediator. A partnership or joint venture shows promising signs and deserves your attention.",
        "health": "Seek aesthetic pleasure in your wellness routine. A beautifully prepared meal or a luxurious skincare ritual lifts your spirits. Balance social time with peaceful solitude.",
        "overall_score": 80, "lucky_number": "8", "lucky_color": "Pink", "mood": "Harmonious",
    },
    "Scorpio": {
        "general": "Powerful transformations stir beneath the surface today. Your intensity and depth of perception reveal hidden truths. Trust your instincts — they pierce through illusion like no other sign.",
        "love": "Intimacy deepens as you allow yourself to be truly seen. Magnetic attraction draws others to your enigmatic presence. Singles may feel an intense, almost fated connection forming.",
        "career": "Research and investigation yield breakthroughs. Your ability to dig deeper where others stop gives you a competitive edge. A secret or hidden information comes to light in your favor.",
        "health": "Emotional release is vital for your well-being today. Journal, meditate, or engage in intense exercise to process deep feelings. Hydration and detoxifying foods support your body.",
        "overall_score": 83, "lucky_number": "3", "lucky_color": "Crimson", "mood": "Intense",
    },
    "Sagittarius": {
        "general": "Adventure beckons and your optimism is infectious today. The horizon expands with possibilities — say yes to new experiences. A philosophical insight shifts your perspective meaningfully.",
        "love": "Freedom and excitement fuel your romantic energy. Surprise your partner with a spontaneous adventure. Singles thrive in travel or educational settings — love finds the open-minded.",
        "career": "Big-picture thinking sets you apart today. An international or cross-cultural opportunity may arise. Your enthusiasm for learning opens doors to growth. Share your knowledge generously.",
        "health": "Outdoor activity is your best medicine. Hiking, cycling, or exploring a new trail invigorates your body and spirit. Watch your tendency to overdo — moderation sustains energy.",
        "overall_score": 86, "lucky_number": "11", "lucky_color": "Turquoise", "mood": "Adventurous",
    },
    "Capricorn": {
        "general": "Discipline and ambition drive you toward your goals today. Long-term plans crystallize into actionable steps. Your reputation for reliability opens doors — honor your commitments fully.",
        "love": "Steady devotion speaks volumes today. Show your commitment through consistency and dependability. Singles may find attraction in someone ambitious and grounded like themselves.",
        "career": "Authority figures take notice of your dedication. A promotion or increased responsibility is on the horizon. Your strategic planning pays dividends — stay the steady course.",
        "health": "Bone and joint health deserve attention. Strength training and calcium-rich foods support your framework. Take regular breaks from desk work — your posture will thank you.",
        "overall_score": 77, "lucky_number": "10", "lucky_color": "Charcoal", "mood": "Determined",
    },
    "Aquarius": {
        "general": "Innovation and originality mark your day. Your unconventional ideas are ahead of their time — don't let skeptics dim your vision. Community involvement brings unexpected fulfillment.",
        "love": "Intellectual connection sparks romance. Share your visions for the future with someone who appreciates your uniqueness. Singles may find love through humanitarian causes or group activities.",
        "career": "Technology and innovation are your allies. A creative solution to a longstanding problem earns respect. Collaborate with like-minded visionaries — together you can change the game.",
        "health": "Circulation and nervous system health benefit from attention today. Try something unconventional — cold plunges, acupuncture, or sound healing. Social wellness matters too.",
        "overall_score": 84, "lucky_number": "22", "lucky_color": "Electric Blue", "mood": "Visionary",
    },
    "Pisces": {
        "general": "Your imagination and intuition are exceptionally strong today. Dreams may hold meaningful messages — pay attention. Creative and spiritual pursuits bring deep satisfaction and clarity.",
        "love": "Your empathetic nature creates soul-deep connections. Romance feels almost magical today — lean into it. Singles may sense a kindred spirit through art, music, or shared vulnerability.",
        "career": "Creative projects flourish under your inspired touch. Your ability to sense what others need makes you invaluable in collaborative settings. Trust your artistic vision — it's right on target.",
        "health": "Water is your healing element today. Swimming, baths, or simply drinking more water restores your energy. Protect your sensitive nature with healthy boundaries and quiet reflection.",
        "overall_score": 76, "lucky_number": "12", "lucky_color": "Sea Green", "mood": "Dreamy",
    },
}

# Default horoscope for signs without custom data
DEFAULT_HOROSCOPE = {
    "general": "The cosmos align in your favor today. Trust the universe's plan and stay open to new possibilities. Your intuition is heightened — follow your inner voice. Connections with others bring unexpected joy.",
    "love": "Love energy surrounds you today. Open your heart to giving and receiving affection. Communication is key — express your feelings honestly. The stars encourage vulnerability and trust.",
    "career": "Professional growth is on the horizon. Your creative ideas gain traction with decision-makers. Stay focused on long-term goals rather than short-term wins. A mentor figure may offer valuable guidance.",
    "health": "Balance is essential today. Listen to your body's signals and honor what it needs. Incorporate mindfulness into your routine. A walk in nature or gentle yoga will restore your energy.",
    "overall_score": 75, "lucky_number": "9", "lucky_color": "Purple", "mood": "Intuitive",
}


def get_horoscope(zodiac_sign: str) -> dict:
    """Get horoscope data for a zodiac sign (uses pre-written data or defaults)."""
    today = date.today().isoformat()
    data = HOROSCOPE_DATA.get(zodiac_sign, DEFAULT_HOROSCOPE)
    return {
        "sign": zodiac_sign,
        "date": today,
        "general": data["general"],
        "love": data["love"],
        "career": data["career"],
        "health": data["health"],
        "overall_score": data["overall_score"],
        "lucky_number": data["lucky_number"],
        "lucky_color": data["lucky_color"],
        "mood": data["mood"],
    }
