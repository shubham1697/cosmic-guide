"""Kundli (Ashta Koota) scoring lookup tables."""

# ── Varna (caste) — determined by Moon RASHI, not nakshatra ───────────────────
# 0=Brahmin (highest) · 1=Kshatriya · 2=Vaishya · 3=Shudra (lowest)
VARNA_RASHI = [1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0]  # by rashi (0-11)

# ── Vashya groups: 0=Chatushpada, 1=Manava, 2=Jalachara, 3=Vanachara, 4=Keeta ─
VASHYA_SIGN = [0, 0, 1, 2, 3, 1, 1, 4, 0, 0, 1, 2]  # by rashi (0-11); Leo=Vanachara

# ── Yoni: animal of each nakshatra (14 animals) ──────────────────────────
# 0 Horse·1 Elephant·2 Sheep·3 Serpent·4 Dog·5 Cat·6 Rat·7 Cow·8 Buffalo
# 9 Tiger·10 Deer·11 Monkey·12 Mongoose·13 Lion  (Mongoose has no same-yoni pair)
YONI_ANIMAL = [
    0, 1, 2, 3, 3, 4, 5, 2, 5, 6, 6, 7, 8, 9, 8, 9, 10, 10, 4, 11, 12, 11, 13, 0, 13, 7, 1
]

# Seven canonical mortal-enemy animal pairs → Yoni score 0.
YONI_MORTAL_ENEMIES = {
    frozenset({0, 8}),   # Horse–Buffalo
    frozenset({1, 13}),  # Elephant–Lion
    frozenset({2, 11}),  # Sheep–Monkey
    frozenset({3, 12}),  # Serpent–Mongoose
    frozenset({4, 10}),  # Dog–Deer
    frozenset({5, 6}),   # Cat–Rat
    frozenset({7, 9}),   # Cow–Tiger
}


def yoni_points(a1: int, a2: int) -> int:
    """Yoni Koota (max 4): same animal 4, mortal enemies 0, otherwise neutral 2."""
    if a1 == a2:
        return 4
    if frozenset({a1, a2}) in YONI_MORTAL_ENEMIES:
        return 0
    return 2


# ── Gana: 0=Deva, 1=Manushya, 2=Rakshasa ───────────────────────────────
GANA = [
    0, 1, 2, 1, 0, 1, 0, 0, 2, 2, 1, 1, 0, 2, 0, 2, 0, 2, 2, 1, 1, 0, 2, 2, 1, 1, 0
]

# ── Nadi: 0=Aadi, 1=Madhya, 2=Antya — blocks run forward, reverse, forward ─────
NADI = [
    0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2
]

# ── Graha Maitri — natural planetary friendship (Naisargika Maitri) ───────────
# planet codes: 0=Sun 1=Moon 3=Mercury 4=Mars 5=Jupiter 6=Venus 7=Saturn
RASHI_LORD = [4, 6, 3, 1, 0, 3, 6, 4, 5, 7, 7, 5]  # by rashi (0-11)

GRAHA_FRIENDS = {0: {1, 4, 5}, 1: {0, 3}, 3: {0, 6}, 4: {0, 1, 5}, 5: {0, 1, 4}, 6: {3, 7}, 7: {3, 6}}
GRAHA_ENEMIES = {0: {6, 7}, 1: set(), 3: {1}, 4: {3}, 5: {3, 6}, 6: {0, 1}, 7: {0, 1, 4}}


def _relation(a: int, b: int) -> str:
    """Natural relationship of planet a toward b: 'F' friend, 'E' enemy, 'N' neutral."""
    if a == b or b in GRAHA_FRIENDS[a]:
        return "F"
    if b in GRAHA_ENEMIES[a]:
        return "E"
    return "N"


def graha_maitri_points(l1: int, l2: int) -> int:
    """Graha Maitri Koota (max 5) from the two rashi lords' mutual relationship."""
    r = {_relation(l1, l2), _relation(l2, l1)}
    if r == {"F"}:
        return 5
    if r == {"F", "N"}:
        return 4
    if r == {"N"}:
        return 3
    if r == {"F", "E"}:
        return 2
    if r == {"N", "E"}:
        return 1
    return 0  # mutual enemies
