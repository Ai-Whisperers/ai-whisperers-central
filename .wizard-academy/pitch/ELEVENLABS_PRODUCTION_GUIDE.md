# ElevenLabs Studio Production Guide

> **Objective:** transform the *15_MINUTE_EXPONENTIAL_PITCH.md* script into a "Perfect" 15-minute immersive audio experience using the full power of ElevenLabs Studio 3.0.

## 1. Project Setup
- **Create New Project:** Select **"Create a new project"** -> **"Start audio project from scratch"**.
- **Model Selection:** Use **English v3** (or Multilingual v2) in Project Settings.
- **Quality:** Ensure you are on a Creator/Pro plan for **192 kbps MP3** or **WAV**.

## 2. Voice & Performance Settings (The "Definitive" Take)

**Crucial Note:** The script has been divested of stage directions (e.g. `[sighs]`) because the AI reads them out loud. You must "direct" the performance using the settings below.

### Global Voice Settings
**Recommended Voice:** **"Marcus"** (Authoritative, Deep) or **"Antoni"** (Balanced, Professional).

- **Stability:** **35%**. (Allows for significant emotional variance).
- **Similarity:** **80%**. (Keeps the voice character consistent).
- **Style Exaggeration:** **30%**. (Pushes the model to "perform").
- **Speed:** **1.0x**.

### How to Achieve "Stage Directions" Manually
Since we removed the text tags, use the **Contextual Sidebar** to clone the intended emotion for specific blocks:

| Intended Emotion | How to Achieve it in Studio |
| :--- | :--- |
| **[Serious/Firm]** | Select text -> Lower **Stability** to **30%**. Increase **Style Exaggeration** to **40%**. |
| **[Clears Throat]** | Do not try to generate this. Insert a **"Throat Clear"** SFX clip on the timeline *before* the text. |
| **[Sighs]** | Insert a **"Male Sigh"** SFX clip on the timeline. Leave 0.5s pause after it. |
| **[Whispering]** | Use **Actor Mode** (see below) or create a custom "Whisper" voice clone to assign to just that line. |
| **[Annoyed]** | Increase **Speed** slightly (1.1x) and lower **Stability** to **25%** for a more "snappy" delivery. |

## 3. Chapter Organization & Pacing
The script is designed in **5 logical phases**. Create 5 separate Chapters in the Sidebar.

| Chapter | Title (Internal) | Mood/Pacing | Recommended Music/SFX |
| :--- | :--- | :--- | :--- |
| **1** | **The Lead and the Forest** | Exhausted -> Ominous | *SFX: Heavy Machinery, Typing, Static* |
| **2** | **The Guild (High Alchemy)** | Warm, Magical, Clarity | *Music: Fantasy Orchestral, Wind Chimes* |
| **3** | **The Four Pillars** | Educational, Rhythmic | *Music: Minimalist, "Thinking" Pulse* |
| **4** | **Transmutation (Giddles)** | Fast -> Silent -> Peaceful | *Music: Driving Beat -> **Silence** -> Ambient* |
| **5** | **The Athanor (Call to Action)** | Solemn, Grand, Epic | *Music: Epic Crescendo* |

## 4. Timeline Engineering
Use the **Timeline** to "Director" the pauses. Do not rely on the text alone.

### The "1.5s Pause" Rule
Use the **"Add Pause"** button in the Studio editor to insert a **1.5s pause** between each of the major `---` sections in the script.

### Specific Transitions
- **The "Bell Chime" Transition (Chapter 1 -> 2):**
    - Cut the "Machinery" SFX *instantly* after "The grinding stops abruptly."
    - Insert **0.5s silence** (or a "Sigh" SFX here).
    - Play **"Bell Chime"** SFX.
    - Allow the chime to ring out for **1.5s** before the voice says "But there is another way."

## 5. Advanced Features: Actor Mode
For the "hook" lines, using Actor Mode is safer than relying on text prompts.

- **"The Magic... is real."** (End of Chapter 5)
    - *Direction:* Record yourself whispering this line very close to the mic. Use Actor Mode to apply the chosen Voice ID to your whisper.

## 6. Pronunciation Dictionary
Ensure these terms are pronounced correctly. Add them to the Project Dictionary.

| Term | Phonetic | Note |
| :--- | :--- | :--- |
| **Athanor** | `ATH-uh-nor` | Emphasis on first syllable. |
| **Homunculus** | `ho-MUNK-yoo-lus` | "ho" like "hot", "MUNK" like "monk". |
| **Giddles** | `GID-uls` | Hard G. Rhymes with "Fiddles". |
| **Ay-Eye** | `Eye` | Ensure the model says the letters "A" "I". |
| **Philosopher's** | `fi-LOS-uh-fers` | Standard. |

## 7. Quality Control
- **Generation History:** Use this to "reroll" specific sentences.
- **Lock Paragraphs:** Once a paragraph is perfect, use the **Lock** button.
