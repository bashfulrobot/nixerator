# Text Polish: Voice Integration

## Summary

Split the text-polish module into two variants behind separate keybindings:

- **Super-Shift-R** -- voiced polish (rewrites in Dustin's voice with auto register detection)
- **Super-Ctrl-R** -- generic polish (current behaviour, tone-preserving)

## Module structure

```
modules/apps/cli/text-polish/
  default.nix                    # two bindings, two replaceVars calls
  scripts/
    text-polish.sh               # generic polish (unchanged, remapped to Super-Ctrl-R)
    text-polish-voice.sh         # voiced polish (new, mapped to Super-Shift-R)
```

## Approach

Two fully independent scripts (Approach A). No shared files, no flags. The prompt is the only difference; shell logic (grab text, guard length, call `claude -p`, copy result, notify) is duplicated across both scripts.

## Generic script (text-polish.sh)

No changes to the script itself. The only change is the keybinding moves from Super-Shift-R to Super-Ctrl-R.

## Voiced script (text-polish-voice.sh)

Same shell structure as the generic script. Different prompt, built from three layers:

### Layer 1: Conciseness and preservation rules

Carried over from the current generic script verbatim:

- Ruthless conciseness (cut unnecessary words, merge redundant sentences)
- Fix grammar and spelling
- Preserve original language (do not translate)
- Preserve formatting (markdown, bold, italic, code blocks, links)
- Never modify URLs, code blocks, inline code, names, product names, technical terms, or quoted text
- Delete filler words and hedging (unless expressing genuine uncertainty)
- Replace adverbs with stronger verbs
- Replace wordy phrases with single words
- Cut redundancy (pairs, implied modifiers, repeated points)
- Reduce prepositional phrases
- Convert negatives to affirmatives
- Use active voice
- Prefer short common words
- Start with the point (no throat-clearing)
- Sentence length: average 14-18 words, max two clauses, prefer periods over semicolons
- Parallel structure in lists and comparisons

### Layer 2: Voice DNA and register detection

Drawn from the writing-style skill. The key instruction shifts from "preserve the original tone" to "rewrite in Dustin's voice."

**Voice characteristics (always applied):**

- Direct and conversational -- writes like he talks, no corporate filler
- Short sentences, fragments encouraged
- Warm but not performative -- friendly without exclamation-mark overload
- Thinks out loud ("I wonder if...", "My understanding is...")
- Easygoing confidence -- knows his stuff without proving it
- Canadian English spellings (favour, behaviour, colour, realise)

**Auto register detection:**

Claude infers the register from text characteristics. No manual hints.

- **Slack:** Short text, no greeting/sign-off, casual tone. Output: lowercase OK, drop periods on short messages, preserve "QQ -" prefix, light emoji use OK.
- **Customer email:** "Hey/Hi Name," opening, structured content, external audience. Output: "Cheers," sign-off (preserve if present, add if missing from emails), bullet points for multi-item content, slightly longer sentences than Slack but still punchy, contractions used freely.
- **Internal email:** Internal audience indicators, less structured than customer email. Output: "Cheers," sign-off, more direct about needs, practical and no fluff.
- **Summary:** Bullet-point structure, status updates, recaps. Output: bullets for structure, lead with what matters, action items clear and attributed, "My intent was to..." framing where appropriate.

### Layer 3: Anti-patterns (unified)

Merged from writing-style anti-patterns (superset of current anti-slop rules):

- Never use: additionally, furthermore, moreover, crucial, delve, enhance, foster, landscape, pivotal, showcase, testament, underscore, vibrant, tapestry, intricate, garner, enduring, groundbreaking, nestled, renowned, seamless
- Use simple verbs ("is" not "serves as", "has" not "boasts")
- No dashes (em dashes or en dashes) in paragraph prose. Dashes are OK only when formatting concise structured information (e.g., bullet lists, key-value pairs, label-value separators)
- No rule-of-three patterns ("streamlining, enhancing, and fostering")
- No negative parallelisms ("not just X, but Y")
- No significance inflation
- No promotional or sycophantic language ("Great question!", "Absolutely!")
- No bolded inline headers in lists ("**Speed:** ...")
- No generic positive conclusions ("The future looks bright")
- No filler phrases ("In order to", "At this point in time", "It is important to note")
- No hedging excess ("It could potentially possibly be argued...")
- No curly quotation marks
- No Title Case For Headings
- No emojis decorating headings or bullet points

## Nix module changes (default.nix)

- Add a second `replaceVars` call for `text-polish-voice.sh` (same substitutions: wl_paste, wl_copy, notify_send)
- Split keybinding into two conf.d files:
  - `hypr/conf.d/text-polish.conf`: `bind = SUPER SHIFT, R, exec, <bash> <text-polish-voice.sh>`
  - `hypr/conf.d/text-polish-generic.conf`: `bind = SUPER CTRL, R, exec, <bash> <text-polish.sh>`

## Testing

- Select Slack-style text, press Super-Shift-R, verify output has Dustin's casual voice
- Select customer email text, press Super-Shift-R, verify "Cheers," sign-off and Canadian English
- Select any text, press Super-Ctrl-R, verify behaviour matches current generic polish
- Verify both notifications display correctly
- Verify text too long (>10,000 chars) and empty selection errors work on both shortcuts
