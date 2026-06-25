/**
 * Example Kong deck — this is the ONLY file you edit to build a presentation.
 * Copy this to deck.js, change the content, open presentation.html.
 *
 * Accent one word in a heading with *asterisks* -> renders neon green.
 */
window.DECK = {
  title: "Kong Theme — Layout Showcase",

  // Footer text (all optional; these are the Kong defaults).
  footer: {
    label: "AI CONNECTIVITY",
    copyright: "© Kong Inc.",
    notice: "NOT TO BE SHARED EXTERNALLY"
  },

  slides: [
    { layout: "title",
      eyebrow: "*Kong* Konnect",
      title: "Presentation\ntitle",
      subtitle: "The Unified API and AI Platform",
      date: "JAN 2026",
      speaker: "Speaker Name" },

    { layout: "title", variant: "cobrand",
      title: "Presentation\ntitle",
      speaker: "Speaker Name", position: "POSITION",
      date: "JAN 2026" },

    { layout: "agenda",
      heading: "January '26",
      items: ["Where we are", "What changed this quarter", "What's next", "Open questions"] },

    { layout: "divider",
      statement: "Write a bold, compelling statement about what the next section will *communicate.*" },

    { layout: "section-statement",
      eyebrow: "Our mission",
      statement: "Write a bold, compelling statement about what the company wants to *achieve.*",
      body: "Explain how a partnership would help make this goal a reality and why it's worth pursuing together." },

    { layout: "content",
      eyebrow: "The challenge",
      title: "Fragmentation drives *AI failure*",
      bullets: [
        "Demonstrate the benefits through charts, graphs, and statistics.",
        "Use this space to explain what the data shows and how it impacts the business.",
        "Each point should build on the previous slide."
      ] },

    { layout: "big-stat",
      eyebrow: "The challenge",
      title: "Fragmentation drives *AI failure*",
      bullets: ["First supporting point.", "Second supporting point.", "Third supporting point."],
      stat: { label: "Gravity orbit cosmos", value: "+80K" } },

    { layout: "stats-grid",
      title: "A secure foundation for *software* delivery",
      note: "Galaxy astronaut nebula the orbit comet supernova.",
      stats: [
        { value: "100,000", label: "Requests per second at peak." },
        { value: "100TB",   label: "Data processed each day.", highlight: true },
        { value: "99.99%",  label: "Control-plane availability." },
        { value: "+80K",    label: "Active deployments." },
        { value: "120M",    label: "Monthly API calls." },
        { value: "<10ms",   label: "Added gateway latency." }
      ] },

    { layout: "value-cards", variant: "3",
      eyebrow: "Our mission",
      statement: "Write a bold, compelling statement about what the company wants to achieve.",
      cards: [
        { title: "Add a value or belief", body: "Define this value and explain how it reflects your culture." },
        { title: "Add a value or belief", body: "Examples might include teamwork, innovation, or customer focus." },
        { title: "Add a value or belief", body: "Describe how it makes you desirable as a partner." }
      ] },

    { layout: "value-cards", variant: "2",
      eyebrow: "Section title",
      statement: "Write a statement about the core principles that guide your actions.",
      cards: [
        { title: "Add a value or belief", body: "Define this value and explain how it reflects your culture." },
        { title: "Add a value or belief", body: "Examples might include teamwork, innovation, or customer focus." }
      ] },

    { layout: "team", variant: "grid",
      title: "Meet the *team*",
      members: [
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" },
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" },
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" },
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" },
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" },
        { name: "Full Name", role: "Title" }, { name: "Full Name", role: "Title" }
      ] },

    { layout: "timeline", variant: "line",
      title: "How the *partnership* will work",
      steps: [
        { label: "Step or milestone", body: "Outline how the partnership will grow.", tag: "January" },
        { label: "Step or milestone", body: "Include details such as shared goals.", tag: "February" },
        { label: "Step or milestone", body: "Add another example with check-ins.", tag: "March" },
        { label: "Step or milestone", body: "Discuss joint initiatives or launches.", tag: "April" },
        { label: "Step or milestone", body: "Add as many steps as you want.", tag: "May" }
      ] },

    { layout: "timeline", variant: "cards",
      eyebrow: "Agenda", title: "Timeline",
      steps: [
        { label: "Quarter, Year", body: "Outline the next steps of the plan." },
        { label: "Quarter, Year", body: "Set a deadline for drafting an agreement." },
        { label: "Quarter, Year", body: "Deliver the implementation plan." },
        { label: "Quarter, Year", body: "Allocate resources and channels." }
      ] },

    { layout: "partnerships", variant: "2",
      title: "Our successful *partnerships*",
      partners: [
        { name: "Partnership 1", when: "Quarter, Year", body: "Introduce one of your current partners and what you accomplished together.", link: "Learn more" },
        { name: "Partnership 2", when: "Quarter, Year", body: "Introduce one of your current partners and what you accomplished together.", link: "Learn more" }
      ] },

    { layout: "partnerships", variant: "4",
      title: "Our successful *partnerships*",
      partners: [
        { name: "Partnership 1", when: "Quarter, Year", body: "Mention their industry, then describe what you accomplished together." },
        { name: "Partnership 2", when: "Quarter, Year", body: "Mention their industry, then describe what you accomplished together." },
        { name: "Partnership 3", when: "Quarter, Year", body: "Mention their industry, then describe what you accomplished together." },
        { name: "Partnership 4", when: "Quarter, Year", body: "Mention their industry, then describe what you accomplished together." }
      ] },

    { layout: "awards-grid",
      eyebrow: "Section title",
      statement: "Highlight your company's growth, metrics, awards, and *achievements.*",
      cells: [
        { type: "award", title: "Industry award", sub: "Product or campaign" },
        { type: "metric", value: "00%", label: "Market share" },
        { type: "list", title: "Certifications", items: ["ISO 27001", "SOC 2 Type II", "PCI DSS"] },
        { type: "metric", value: "#00", label: "Rank in the industry" },
        { type: "quote", value: "Quote from published media coverage about your company", link: "Link to article" }
      ] },

    { layout: "mixed-stats",
      eyebrow: "Let's work together",
      title: "Invite your potential partner to join your *business.*",
      body: "Demonstrate the benefits through charts, graphs, and statistics.",
      cards: [
        { value: "+80K", label: "Add a value", desc: "Galaxy astronaut nebula the orbit." },
        { value: "+120M", label: "Add a value", desc: "Examples of company values.", fill: true },
        { value: "<10ms", label: "Add a value", desc: "Galaxy astronaut nebula the orbit." }
      ] },

    { layout: "persona",
      segment: { title: "Customer segment title", attributes: ["Age range: 00-00", "Education: Highest", "Status: Marital", "Location: City", "Archetype: Tech-savvy"] },
      needs: ["What does this segment want?", "What motivates them?", "What are they looking for?"],
      painPoints: ["What interferes with their goals?", "What frustrates them daily?"],
      skills: [{ label: "Device 1", level: 80 }, { label: "Device 2", level: 45 }, { label: "Device 3", level: 95 }],
      purchasing: [{ label: "Online store", pct: 90 }, { label: "Social media", pct: 55 }, { label: "Physical store", pct: 70 }] },

    { layout: "charts",
      eyebrow: "Let's work together",
      title: "Invite your potential partner to join your *business.*",
      body: "Demonstrate the benefits through charts, graphs, and statistics.",
      bubble: { outer: { label: "Projected", value: "00%" }, inner: { label: "Current", value: "00%" }, caption: "Market reach" },
      bars: [{ value: 40, year: "Year" }, { value: 100, year: "Year" }], barsCaption: "ROI" },

    { layout: "architecture",
      title: "Ships API and AI innovation to *market faster*",
      columns: [
        { label: "MCP Clients / AI Agents", nodes: [{ kind: "bot" }, { kind: "dollar" }, { kind: "kong", label: "AI (MCP) Gateway" }] },
        { nodes: [{ kind: "dollar" }, { kind: "box", label: "MCP Server" }, { kind: "box", label: "MCP Server" }] },
        { nodes: [{ kind: "kong", label: "AI (LLM) Gateway" }, { kind: "kong", label: "AI (LLM) Gateway" }] },
        { nodes: [{ kind: "box", label: "API" }, { kind: "box", label: "Events" }, { kind: "box", label: "API" }] }
      ] },

    { layout: "green-inverted",
      eyebrow: "Our mission",
      statement: "Write a bold, compelling statement about what the company wants to achieve." },

    { layout: "thank-you",
      title: "Thank you!",
      tagline: "Ready for what's next?",
      cta: "Let's talk",
      contact: ["Kong Inc.", "contact@konghq.com", "44 Montgomery Street", "San Francisco, CA 94104, USA", "konghq.com"] }
  ]
};
