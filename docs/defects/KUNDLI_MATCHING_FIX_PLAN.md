# Kundli Matching (Ashta Koota) — Defect & Remediation Plan

_Filed: 2026-08-10_

## Context

Kundli matching is the app's most consequential output: it drives the marriage-compatibility verdict (X/36 Gun Milan). A review of the lookup tables against the classical Ashta Koota reference found that **6 of the 8 kootas are computed from wrong data or wrong logic**. Static analysis (`flutter analyze`, `compileall`) is clean — every item below is a correctness defect a linter cannot catch.

**Scope:** backend only. The real calculation lives in
[backend/services/kundli_service.py](backend/services/kundli_service.py) + [backend/data/kundli_tables.py](backend/data/kundli_tables.py). The Flutter side ([mobile-app/lib/screens/kundli_screen.dart](mobile-app/lib/screens/kundli_screen.dart), [mobile-app/lib/data/kundli_mock_data.dart](mobile-app/lib/data/kundli_mock_data.dart)) only renders mock fallbacks and is unaffected. Western sun-sign compatibility (`compatibility_service.py`) is a separate feature and out of scope.

## Severity summary

| # | Koota | Points | Defect | Severity |
|---|-------|:-----:|--------|----------|
| 1 | **Nadi** | 8 | Middle block of `NADI` is a copy of the first block instead of its reverse → 6/27 nakshatras misclassified; **19.8%** of couples get the wrong Nadi verdict (verified: 144/729). Nadi dosha is a hard blocker. | **Critical** |
| 2 | **Graha Maitri** | 5 | Friendship matrix only ever holds friend values; **64/144** lord pairs fall through to a hard-coded neutral `3`. Enemy scores unreachable → koota can only return 3–5. | **Critical** |
| 3 | **Yoni** | 4 | Scored by numeric distance between arbitrary animal IDs; `YONI_ANIMAL` has ~8 wrong entries; `YONI_COMPAT` is dead code. | **High** |
| 4 | **Varna** | 1 | Indexed by nakshatra (Varna is a *rashi* property); `>=` comparison inverted by the `0=Brahmin` encoding. | **High** |
| 5 | **Gana** | 6 | Rohini typed as Deva; should be Manushya → **7.1%** of pairs wrong (verified: 52/729). | **Medium** |
| 6 | **Vashya** | 2 | Leo classified as a domestic quadruped (Chatushpada) instead of Vanachara; value `3` never appears in the table. | **Medium** |

> Independently reproduced statistics: Nadi wrong-verdict rate **144/729 = 19.75%**; Gana wrong-pair rate **52/729 = 7.13%** (excludes the unaffected Rohini–Rohini pair); Graha Maitri fall-through **64/144**.

---

## Reference: the 27 nakshatras (index 0–26)

`0 Ashwini · 1 Bharani · 2 Krittika · 3 Rohini · 4 Mrigashira · 5 Ardra · 6 Punarvasu · 7 Pushya · 8 Ashlesha · 9 Magha · 10 Purva Phalguni · 11 Uttara Phalguni · 12 Hasta · 13 Chitra · 14 Swati · 15 Vishakha · 16 Anuradha · 17 Jyeshtha · 18 Mula · 19 Purva Ashadha · 20 Uttara Ashadha · 21 Shravana · 22 Dhanishta · 23 Shatabhisha · 24 Purva Bhadrapada · 25 Uttara Bhadrapada · 26 Revati`

Rashis (index 0–11): `0 Aries · 1 Taurus · 2 Gemini · 3 Cancer · 4 Leo · 5 Virgo · 6 Libra · 7 Scorpio · 8 Sagittarius · 9 Capricorn · 10 Aquarius · 11 Pisces`

---

## Fix 1 — Nadi (Critical)

**File:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L24-L27)

The table is three identical 9-blocks. The middle block must be the **reverse** of the first (Aadi–Madhya–Antya runs forward, then backward, then forward again).

```python
# Current (WRONG) — middle block copied:
NADI = [0,1,2,2,1,0,0,1,2, 0,1,2,2,1,0,0,1,2, 0,1,2,2,1,0,0,1,2]

# Corrected — middle block reversed:
NADI = [0,1,2,2,1,0,0,1,2, 2,1,0,0,1,2,2,1,0, 0,1,2,2,1,0,0,1,2]
```

Fixes the 6 misclassified nakshatras: Magha, Uttara Phalguni, Hasta, Swati, Vishakha, Jyeshtha. No logic change to `_nadi_score`.

## Fix 2 — Graha Maitri (Critical)

**Files:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L32-L59), scoring in [backend/services/kundli_service.py](backend/services/kundli_service.py#L78-L84)

`_init_graha_friendship` only inserts friend pairs (4/5) plus the diagonal, so `.get((l1,l2), 3)` returns 3 for every non-friend pair and enemy scores (0–2) are impossible. Replace the hand-built partial dict with the classical **Naisargika Maitri** (natural friendship) sets and derive the combined 5-point score so the full 0–5 range is reachable.

Planet encoding used by `RASHI_LORD`: `0=Sun 1=Moon 3=Mercury 4=Mars 5=Jupiter 6=Venus 7=Saturn`.

| Planet | Friends | Neutral | Enemies |
|--------|---------|---------|---------|
| Sun (0) | Moon, Mars, Jupiter | Mercury | Venus, Saturn |
| Moon (1) | Sun, Mercury | Mars, Jupiter, Venus, Saturn | — |
| Mars (4) | Sun, Moon, Jupiter | Venus, Saturn | Mercury |
| Mercury (3) | Sun, Venus | Mars, Jupiter, Saturn | Moon |
| Jupiter (5) | Sun, Moon, Mars | Saturn | Mercury, Venus |
| Venus (6) | Mercury, Saturn | Mars, Jupiter | Sun, Moon |
| Saturn (7) | Mercury, Venus | Jupiter | Sun, Moon, Mars |

Combined score (relationship of L1→L2 with L2→L1; a planet is friendly to itself):

| Combination | Points |
|-------------|:------:|
| friend + friend | 5 |
| friend + neutral | 4 |
| neutral + neutral | 3 |
| friend + enemy | 2 |
| neutral + enemy | 1 |
| enemy + enemy | 0 |

```python
# kundli_tables.py — replace GRAHA_FRIENDSHIP + _init_graha_friendship with:
GRAHA_FRIENDS  = {0:{1,4,5}, 1:{0,3}, 3:{0,6}, 4:{0,1,5}, 5:{0,1,4}, 6:{3,7}, 7:{3,6}}
GRAHA_ENEMIES  = {0:{6,7}, 1:set(), 3:{1}, 4:{3}, 5:{3,6}, 6:{0,1}, 7:{0,1,4}}
# Neutral = everything else (implicit).

def _relation(a, b):
    if a == b or b in GRAHA_FRIENDS[a]: return "F"
    if b in GRAHA_ENEMIES[a]: return "E"
    return "N"

def graha_maitri_points(l1, l2):
    r = {_relation(l1, l2), _relation(l2, l1)}
    if r == {"F"}: return 5
    if r == {"F", "N"}: return 4
    if r == {"N"}: return 3
    if r == {"F", "E"}: return 2
    if r == {"N", "E"}: return 1
    return 0  # {"E"}
```

Then `_graha_maitri_score` calls `graha_maitri_points(lord1, lord2)` instead of the dict lookup.

> Note: the intermediate-point convention (the 4/3/2/1 rows) varies slightly across classical sources; the friend/neutral/enemy table itself is unambiguous. Lock the table in tests; treat the point mapping as the tunable part.

## Fix 3 — Yoni (High)

**Files:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L11-L17), scoring in [backend/services/kundli_service.py](backend/services/kundli_service.py#L63-L75)

Three problems: (a) `_yoni_score` uses `abs(y1 - y2)` — numeric distance between arbitrary IDs is meaningless; (b) `YONI_ANIMAL` mis-assigns ~8 nakshatras so real yoni pairs are broken; (c) `YONI_COMPAT` holds only the diagonal and is never referenced.

**3a. Correct animal map** (14 animals; `0 Horse · 1 Elephant · 2 Sheep · 3 Serpent · 4 Dog · 5 Cat · 6 Rat · 7 Cow · 8 Buffalo · 9 Tiger · 10 Deer · 11 Monkey · 12 Mongoose · 13 Lion`):

```python
YONI_ANIMAL = [0,1,2,3,3,4,5,2,5,6,6,7,8,9,8,9,10,10,4,11,12,11,13,0,13,7,1]
```

This restores the correct same-yoni pairs (e.g. Krittika+Pushya = Sheep, Magha+P.Phalguni = Rat, Chitra+Vishakha = Tiger, Anuradha+Jyeshtha = Deer, Dhanishta+P.Bhadrapada = Lion) and leaves **Uttara Ashadha (Mongoose)** correctly unpaired.

**3b. Real scoring.** Same yoni → 4; mortal enemies → 0; otherwise friend/neutral/enemy from the classical Yoni Kuta matrix. The seven mortal-enemy pairs (score 0) are canonical:

```
{Horse,Buffalo} {Elephant,Lion} {Sheep,Monkey} {Serpent,Mongoose}
{Dog,Deer} {Cat,Rat} {Cow,Tiger}
→ {0,8} {1,13} {2,11} {3,12} {4,10} {5,6} {7,9}
```

Replace the dead `YONI_COMPAT` with a real 14×14 `YONI_MATRIX` (values 0–4) and rewrite `_yoni_score` as a lookup:

```python
def _yoni_score(nak1, nak2):
    y1, y2 = YONI_ANIMAL[nak1], YONI_ANIMAL[nak2]
    if y1 == y2:
        return 4
    return YONI_MATRIX[y1][y2]
```

**Action item:** populate the intermediate friend(3)/neutral(2)/enemy(1) cells of `YONI_MATRIX` from a cited reference (e.g. B. V. Raman, *Muhurtha*). Diagonal (=4) and the seven 0-pairs above are locked; the rest are transcribed and covered by tests.

## Fix 4 — Varna (High)

**Files:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L3-L6), scoring in [backend/services/kundli_service.py](backend/services/kundli_service.py#L32-L35)

Varna is determined by the **Moon rashi**, not the nakshatra, and with the `0=Brahmin` (highest) encoding the winning condition is `boy <= girl`, not `>=`.

```python
# kundli_tables.py — replace the 27-entry nakshatra table with a 12-entry rashi table:
# Brahmin=0 (Cancer/Scorpio/Pisces) · Kshatriya=1 (Aries/Leo/Sag)
# Vaishya=2 (Taurus/Virgo/Cap)      · Shudra=3 (Gemini/Libra/Aqua)
VARNA_RASHI = [1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0]  # by rashi 0–11
```

```python
# kundli_service.py — take rashi indices and invert the comparison (person1 = boy):
def _varna_score(rashi1: int, rashi2: int) -> int:
    v1, v2 = VARNA_RASHI[rashi1], VARNA_RASHI[rashi2]
    return 1 if v1 <= v2 else 0   # boy's varna equal or higher (lower number = higher)
```

Update the call site in `calculate_kundli` from `_varna_score(nak1, nak2)` to `_varna_score(rashi1, rashi2)`, and drop the old `VARNA` import.

## Fix 5 — Gana (Medium)

**File:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L19-L22)

Single-cell data error: Rohini (index 3) is `0` (Deva) but is classically Manushya (`1`). `_gana_score` logic is correct and needs no change.

```python
# index:      0 1 2 3 4 5 6 7 8 9 ...
GANA = [0,1,2, 1, 0,1,0,0,2,2,1,1,0,2,0,2,0,2,2,1,1,0,2,2,1,1,0]
#              ^ Rohini: 0 → 1
```

## Fix 6 — Vashya (Medium)

**File:** [backend/data/kundli_tables.py](backend/data/kundli_tables.py#L8-L9)

Leo (rashi 4) is the sole Vanachara (wild-animal, value `3`) sign but is coded `0` (Chatushpada). Value `3` currently never appears in the table.

```python
# groups: 0=Chatushpada 1=Manava 2=Jalachara 3=Vanachara 4=Keeta   (by rashi 0–11)
VASHYA_SIGN = [0, 0, 1, 2, 3, 1, 1, 4, 0, 0, 1, 2]
#                          ^ Leo: 0 → 3
```

> The `_vashya_score` group heuristic (mutual-pair set) is a simplification of the classical controller relationship. Fixing the Leo data removes the concrete defect; replacing the heuristic with the full controller matrix is an optional follow-up, not part of this defect.

---

## Verification plan

1. **Unit tests** — new `backend/tests/test_kundli_tables.py`:
   - `NADI`, `GANA`, `VARNA_RASHI`, `VASHYA_SIGN` equal the corrected reference arrays; each has the right length (27 / 27 / 12 / 12) and expected value counts (e.g. Nadi/Gana each: nine 0s, nine 1s, nine 9s… i.e. 9 per class; Varna: 3 per class).
   - `YONI_ANIMAL`: every animal id appears exactly twice **except** Mongoose (12) once; assert the known same-yoni pairs and the 7 mortal-enemy `→0` cells.
   - `graha_maitri_points`: symmetric in its two args; full 0–5 range reachable; spot-check Sun–Venus=0, Moon–Mercury=2 (friend one way, enemy the other), Sun–Mercury=4, Mars–Mercury=1.
2. **Koota-level tests** — `test_kundli_service.py`: assert each `_*_score` obeys its max and, for a fixed set of nakshatra/rashi pairs, matches hand-computed classical values. Guard the historic bugs explicitly (e.g. a Rohini pairing scores Gana as Manushya; a same-Nadi pair from the old middle block now scores correctly).
3. **Regression fixture** — 3–4 real birth-data couples with an independently computed 36-point breakdown; assert total + per-koota.
4. `python -m compileall backend` and Pylance clean.
5. Backend is bind-mounted with `--reload` — no rebuild needed; a plain `./backend/server.sh restart` (or hot-reload) picks up the edits. Smoke-test `POST /api/v1/kundli/match` and confirm the koota breakdown changes for a known-affected couple.

## Rollout / risk

- **Data-only fixes (1, 5, 6)** are the lowest risk — array edits, no control flow.
- **Fixes 2 and 4** change scoring logic and the Varna call signature; covered by the unit tests above.
- **Fix 3** needs the intermediate `YONI_MATRIX` cells transcribed from a cited source before merge; the animal-map and mortal-enemy fixes can land first behind tests.
- **User-visible impact:** existing match scores will shift (some couples move across the Excellent/Good/Average bands, and Nadi-dosha verdicts flip for ~1 in 5 couples). This is a correction, but if any scores are persisted/cached, invalidate them on deploy. Kundli results are computed on demand (not in the horoscope caches), so no cache migration is expected — confirm before release.

## Suggested sequence

1. Land Fixes 1, 5, 6 (data) + their table tests.
2. Land Fix 4 (Varna: table + signature + call site).
3. Land Fix 2 (Graha Maitri rewrite) + tests.
4. Land Fix 3 (Yoni map + scoring) once `YONI_MATRIX` is sourced.
5. Add the couple-level regression fixture; verify live.
