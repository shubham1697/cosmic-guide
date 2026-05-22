"""Kundli (Ashta Koota) scoring lookup tables."""

# Varna (caste) of each Nakshatra: 0=Brahmin, 1=Kshatriya, 2=Vaishya, 3=Shudra
VARNA = [
    1, 3, 2, 3, 0, 2, 0, 1, 3, 3, 0, 1, 2, 1, 0, 0, 3, 1, 2, 0, 1, 3, 2, 2, 0, 1, 3
]

# Vashya groups: 0=Chatushpada, 1=Manava, 2=Jalachara, 3=Vanachara, 4=Keeta
VASHYA_SIGN = [0, 0, 1, 2, 0, 1, 1, 4, 0, 0, 1, 2]  # by rashi (0-11)

# Yoni (animal pairs): 14 animals
YONI_ANIMAL = [
    0, 1, 2, 3, 3, 4, 5, 6, 5, 7, 8, 9, 10, 11, 10, 12, 8, 7, 4, 13, 13, 13, 9, 0, 6, 9, 1
]
YONI_COMPAT = {
    (i, i): 4 for i in range(14)
}

# Gana: 0=Deva, 1=Manushya, 2=Rakshasa
GANA = [
    0, 1, 2, 0, 0, 1, 0, 0, 2, 2, 1, 1, 0, 2, 0, 2, 0, 2, 2, 1, 1, 0, 2, 2, 1, 1, 0
]

# Nadi: 0=Aadi, 1=Madhya, 2=Antya
NADI = [
    0, 1, 2, 2, 1, 0, 0, 1, 2, 0, 1, 2, 2, 1, 0, 0, 1, 2, 0, 1, 2, 2, 1, 0, 0, 1, 2
]

# Graha Maitri — planetary friendship (simplified lord-of-rashi approach)
RASHI_LORD = [4, 6, 3, 1, 0, 3, 6, 4, 5, 7, 7, 5]  # 0=Sun..7=Saturn  (rashi 0-11)

# Friendship scores: 5=best friends, 4=friends, 3=neutral, 2=enemies, 1=bitter enemies
GRAHA_FRIENDSHIP = {}


def _init_graha_friendship():
    """Initialise the planet friendship matrix (0-7)."""
    friends = {
        (0, 1): 5, (0, 4): 5, (0, 5): 5,
        (1, 0): 5, (1, 3): 4,
        (3, 0): 5, (3, 6): 5,
        (4, 0): 5, (4, 1): 5, (4, 5): 5,
        (5, 0): 5, (5, 1): 5, (5, 4): 5,
        (6, 3): 5, (6, 7): 5,
        (7, 3): 5, (7, 6): 5,
    }
    for i in range(8):
        GRAHA_FRIENDSHIP[(i, i)] = 5
    for (a, b), v in friends.items():
        GRAHA_FRIENDSHIP[(a, b)] = v
        if (b, a) not in GRAHA_FRIENDSHIP:
            GRAHA_FRIENDSHIP[(b, a)] = v


_init_graha_friendship()
