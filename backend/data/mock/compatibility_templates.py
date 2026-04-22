"""Static compatibility description templates (fallback — not used in production)."""

# Indexed by score tier: "high" >= 80, "medium" >= 60, "low" < 60
COMPATIBILITY_TEMPLATES = {
    "high": {
        "description": (
            "{sign1} and {sign2} share a natural harmony. Their {elem1} and {elem2} energies "
            "complement each other beautifully, creating a bond that feels effortless and deeply fulfilling."
        ),
        "love_advice": (
            "Nurture this connection with open communication and shared adventures. "
            "Your energies amplify each other."
        ),
        "strengths_together": (
            "Deep understanding, natural chemistry, shared values, and the ability to "
            "grow together through life's challenges."
        ),
        "challenges": (
            "You may become too comfortable — keep the spark alive by trying new things "
            "together and maintaining individual identities."
        ),
    },
    "medium": {
        "description": (
            "{sign1} and {sign2} bring different strengths to the table. The interplay between "
            "{elem1} and {elem2} creates a dynamic, growth-oriented partnership."
        ),
        "love_advice": (
            "Embrace your differences as opportunities to learn and grow. "
            "Patience and understanding are your greatest allies."
        ),
        "strengths_together": (
            "Complementary skills, mutual respect, growth through differences, "
            "and the ability to balance each other out."
        ),
        "challenges": (
            "Communication styles may differ — practice active listening and express "
            "needs clearly to bridge any gaps."
        ),
    },
    "low": {
        "description": (
            "{sign1} and {sign2} face an uphill journey together. The tension between "
            "{elem1} and {elem2} requires conscious effort, but the rewards of overcoming "
            "challenges can be profound."
        ),
        "love_advice": (
            "Success requires mutual respect and willingness to compromise. "
            "Focus on shared goals rather than differences."
        ),
        "strengths_together": (
            "When it works, the contrast creates passion and excitement. "
            "You challenge each other to grow in ways comfortable partners rarely do."
        ),
        "challenges": (
            "Fundamental differences in approach and temperament require patience. "
            "Regular honest conversations prevent misunderstandings."
        ),
    },
}
