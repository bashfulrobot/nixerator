# Meeting Transcript Summary Instructions for AI/LLM

## Objective
Transform meeting transcripts into structured summaries with business casual tone, written from the user's perspective.

## Input Requirements
- Meeting transcript text in `transcript.txt` file
- Current working directory path (to derive customer name)
- Current date (yyyy-mm-dd format)
- Optional: `pov-input.md` file in current directory (if exists)

## Output Structure and Formatting

### 1. Document Title
Format: `*_yyyy-mm-dd CUSTOMER CADENCE CALL SUMMARY_*`
- Extract customer name from directory path (typically: `/path/to/Customers/{CustomerName}/`)
- Use ALL CAPS for entire title (bold italics Slack format)
- Example: `*_2025-09-24 ZILLOW CADENCE CALL SUMMARY_*`

### 2. Content Sections (in order)

#### ***TOPIC SECTIONS***
- Create separate sections for each distinct topic discussed
- Title format: `_{TOPIC NAME}_` (ALL WORDS IN ALL CAPS, italicized only)
- **IMPORTANT**: Add a blank line after each topic title before the content
- Write in paragraph format (not bullet points)
- Do NOT indent paragraphs - start at the left margin
- **Extract ALL content from transcript** - this is your primary source of information
- Maintain verbosity and include all relevant details from transcript
- Keep content focused and to-the-point
- Write from the user's first-person perspective
- **The transcript contains both topic identification AND all summary content**
- **IMPORTANT**: If `pov-input.md` exists, enhance topic sections with structured input:
  - Parse bullet structure: top-level bullets are topics, nested bullets are details
  - Map topics from input file to corresponding transcript topics
  - Augment (don't replace) transcript content with input file details
  - Focus on extracting and incorporating all nested bullet details
  - Ensure input details are seamlessly integrated into narrative paragraphs
  - **Input File Purpose and Limitations**:
    - Input files serve as importance indicators and context guides only
    - **THE TRANSCRIPT IS THE SOURCE OF TRUTH** - never add information not present in transcript
    - Use input files to highlight what to look for and prioritize in the transcript
    - Do not deviate or add external data unless explicitly requested
    - Only extract and emphasize transcript content that aligns with input guidance
  - **Context Matching Guidelines**:
    - Input files may contain incomplete thoughts or sentence fragments
    - Treat input items as context indicators to look for in the transcript
    - Match input context to actual transcript content even if wording differs
    - Handle spelling mistakes and technical abbreviations (DNS, API, etc.)
    - Standardize inconsistent terminology (e.g., "openmetrics" vs "open metrics" → "OpenMetrics")
    - Recognize technology names and acronyms that may appear abbreviated or misspelled
    - Use input as a guide to identify and expand on relevant transcript sections

#### ***ACTIVITY TIMELINE*** (Optional - only if discussed)
- Section title: `_ACTIVITY TIMELINE_` (italics only, all caps)
- **Only include this section if the transcript contains dates, deadlines, or milestones**
- Add an intro line: "To provide a clear view of upcoming milestones and deadlines discussed during the call:"
- Use bullet point format with `-`
- Format: `- **{Date}**: {Description of milestone, deadline, or scheduled activity}`
- Bold the date portion for visual emphasis
- List dates in chronological order
- Include context about potential changes (e.g., "potential slip to Mon")
- Capture all mentioned dates: target dates, handoffs, go-lives, scheduled meetings, etc.

#### ***PEOPLE*** (Optional - only if discussed)
- Section title: `*PEOPLE*` (bold only, all caps)
- **Only include this section if the transcript contains relevant information**
- Use bullet point format with `-`
- Highlight customer people, their roles, and responsibilities
- Format: `- {Name} ({Role/Title}): {Responsibilities or relevant context}`
- Include key stakeholders, decision makers, or important contacts mentioned
- Keep descriptions concise but capture important context about their role

#### ***AUTOMATION, INFRASTRUCTURE & TOOLS*** (Optional - only if discussed)
- Section title: `*AUTOMATION, INFRASTRUCTURE & TOOLS*` (bold only, all caps)
- **Only include this section if the transcript contains relevant information**
- Use bullet point format with `-`
- Highlight automation initiatives, infrastructure discussions, and tools mentioned
- Include deployment pipelines, CI/CD systems, monitoring tools, cloud infrastructure, etc.
- Format: `- {Tool/System name}: {Brief description or context}`
- Focus on technical decisions, implementations, or plans discussed

#### ***RISKS*** (Optional - only if discussed)
- Section title: `*RISKS*` (bold only, all caps)
- **Only include this section if the transcript contains relevant information**
- Use bullet point format with `-`
- Highlight identified risks, concerns, or potential blockers
- Format: `- {Risk description}` or `- {Risk}: {Mitigation strategy if discussed}`
- Include technical risks, business risks, timeline concerns, dependencies, etc.
- Be specific about the nature and impact of each risk

#### ***HIGHLIGHTS***
- Section title: `*HIGHLIGHTS*` (bold only)
- Use bullet point format with `-`
- Capture key insights, decisions, or notable moments
- Keep items concise but informative

#### ***ACTION ITEMS***
- Section title: `*ACTION ITEMS*` (bold only)
- Use bullet point format with `-`
- Format: `- {Assignee}: {Action item description}`
- Be specific about who is responsible for each item
- Include deadlines or timeframes when mentioned

#### ***MEETING RECORDING***
- Section title: `*MEETING RECORDING*` (bold only)
- Single bullet point with markdown link
- Format: `- [Clari Recording](PLACEHOLDER_URL)`
- Use exact placeholder URL text for manual replacement later

## Tone and Style Guidelines
- Business casual tone throughout
- Professional but conversational
- Write from the user's perspective (first person)
- Avoid overly formal or technical jargon unless necessary
- Maintain consistency in voice and style

## Technical Requirements
- All output must be Slack-compatible markdown
- **CRITICAL MARKDOWN FORMATTING RULES:**
  - `*text*` = bold
  - `_text_` = italics
  - `*_text_*` = bold italics
  - **NEVER** use `**text**` anywhere in the document
- Document title: `*_TITLE_*` (bold italics, all caps)
- Topic sections: `_TITLE_` (italics only, all caps)
- Activity Timeline section: `_ACTIVITY TIMELINE_` (italics only, all caps)
- Other sections (People, Automation/Infrastructure/Tools, Risks, Highlights, Action Items, Meeting Recording): `*TITLE*` (bold only, all caps)
- Use `-` for bullet points (not `•`)
- Use standard markdown formatting for links
- Ensure proper spacing between sections

## File Output
- Save to current working directory
- Filename format: `yyyy-mm-dd-{CustomerName}-cadence-call-summary.md`
- Customer name should match the folder name under "Customers" in the path
- Use exact date format and maintain consistent naming

## Processing Steps
1. Read and parse `transcript.txt` to identify distinct topics and extract all content
2. Check for optional `pov-input.md` file in current directory
3. If either input file exists, parse the structured input for topic enhancement
4. Extract customer name from working directory path
5. Generate appropriate filename with current date
6. Structure content according to the specified sections using transcript as source of truth
7. Apply formatting rules consistently
8. Output complete markdown file

## Quality Checklist
- [ ] Title follows exact format with correct date and customer name
- [ ] All section titles are properly formatted (*_ALL WORDS CAPS_*)
- [ ] Topic sections are in paragraph format with sufficient detail
- [ ] If `pov-input.md` exists, all input details are incorporated into topics
- [ ] Optional sections (Activity Timeline, People, Automation/Infrastructure/Tools, Risks) included only if relevant content exists in transcript
- [ ] Activity Timeline lists dates chronologically with bold dates and clear descriptions (if included)
- [ ] All sections use `-` bullet points (except topic sections which are paragraphs)
- [ ] People section includes names, roles, and responsibilities (if included)
- [ ] Automation/Infrastructure/Tools section captures technical systems discussed (if included)
- [ ] Risks section identifies concerns and potential mitigations (if included)
- [ ] Action items include assignee names
- [ ] Meeting recording link uses placeholder URL
- [ ] Content maintains business casual tone
- [ ] Written from the user's perspective
- [ ] Slack-compatible markdown formatting
- [ ] File saved with correct naming convention
- [ ] Document ends with blank line

## Example Output Structure
```markdown
2025-09-24 [CUSTOMER] cadence call summary

*_TOPIC ONE EXAMPLE_*
Detailed paragraph discussing the first topic...

*_TOPIC TWO EXAMPLE_*
Detailed paragraph discussing the second topic...

_ACTIVITY TIMELINE_

To provide a clear view of upcoming milestones and deadlines discussed during the call:
- **Jan 30 (Fri)**: Wave 1.2 target due date (potential slip to Mon).
- **Feb 2 (Mon)**: Standard Image update scheduled. Internal prep for Martech.
- **Feb 9 (Week of)**: Team out / No Knowledge Transfer sessions.
- **Feb 23**: GIH non-prod handoff target.

*PEOPLE*
- Jane Smith (VP of Engineering): Leads the platform team, responsible for infrastructure decisions
- Bob Johnson (DevOps Lead): Managing the CI/CD pipeline migration

*AUTOMATION, INFRASTRUCTURE & TOOLS*
- Jenkins: Current CI/CD system, planning migration to GitHub Actions
- Kubernetes: Production deployment platform, evaluating cost optimization
- Datadog: Monitoring and observability platform

*RISKS*
- Timeline risk: Q1 deadline may be too aggressive given current resource constraints
- Dependency on third-party API that has experienced recent outages
- Knowledge transfer gap if key team member leaves before documentation is complete

*HIGHLIGHTS*
- Key insight or decision from the meeting
- Notable moment or achievement discussed

*ACTION ITEMS*
- John Doe: Complete project analysis by Friday
- Jane Smith: Schedule follow-up meeting with stakeholders

*MEETING RECORDING*
- [Clari Recording](PLACEHOLDER_URL)

```
