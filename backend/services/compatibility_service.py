"""Zodiac compatibility calculation."""

from services.zodiac_service import ZODIAC_ELEMENTS

# Element-based compatibility scores
ELEMENT_COMPATIBILITY = {
    ("Fire", "Fire"): 80, ("Fire", "Air"): 85, ("Fire", "Earth"): 55, ("Fire", "Water"): 50,
    ("Air", "Air"): 75, ("Air", "Earth"): 60, ("Air", "Water"): 65,
    ("Earth", "Earth"): 90, ("Earth", "Water"): 85,
    ("Water", "Water"): 80,
}


def get_compatibility(sign1: str, sign2: str) -> dict:
    """Calculate compatibility between two zodiac signs."""
    elem1 = ZODIAC_ELEMENTS.get(sign1, "Fire")
    elem2 = ZODIAC_ELEMENTS.get(sign2, "Fire")
    key = (elem1, elem2) if (elem1, elem2) in ELEMENT_COMPATIBILITY else (elem2, elem1)
    score = ELEMENT_COMPATIBILITY.get(key, 70)

    if score >= 80:
        label = "Excellent Match!"
        description = f"{sign1} and {sign2} share a natural harmony. Their {elem1} and {elem2} energies complement each other beautifully, creating a bond that feels effortless and deeply fulfilling."
        love_advice = "Nurture this connection with open communication and shared adventures. Your energies amplify each other."
        strengths_together = "Deep understanding, natural chemistry, shared values, and the ability to grow together through life's challenges."
        challenges = "You may become too comfortable — keep the spark alive by trying new things together and maintaining individual identities."
    elif score >= 60:
        label = "Promising Match"
        description = f"{sign1} and {sign2} bring different strengths to the table. The interplay between {elem1} and {elem2} creates a dynamic, growth-oriented partnership."
        love_advice = "Embrace your differences as opportunities to learn and grow. Patience and understanding are your greatest allies."
        strengths_together = "Complementary skills, mutual respect, growth through differences, and the ability to balance each other out."
        challenges = "Communication styles may differ — practice active listening and express needs clearly to bridge any gaps."
    else:
        label = "Challenging Match"
        description = f"{sign1} and {sign2} face an uphill journey together. The tension between {elem1} and {elem2} requires conscious effort, but the rewards of overcoming challenges can be profound."
        love_advice = "Success requires mutual respect and willingness to compromise. Focus on shared goals rather than differences."
        strengths_together = "When it works, the contrast creates passion and excitement. You challenge each other to grow in ways comfortable partners rarely do."
        challenges = "Fundamental differences in approach and temperament require patience. Regular honest conversations prevent misunderstandings."

    return {
        "sign1": sign1,
        "sign2": sign2,
        "score": score,
        "description": description,
        "love_advice": love_advice,
        "strengths_together": strengths_together,
        "challenges": challenges,
    }
