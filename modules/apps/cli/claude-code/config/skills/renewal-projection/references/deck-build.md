# Building the renewal deck

Rendering and the Kong brand belong to the `kong-pptx` skill — invoke it and follow its theme rules.
This file adds what's specific to a renewal-projection deck: the slide spine, a reusable generator
skeleton, the speaker-notes convention, and the working-doc templates.

## Recommended slide spine

The deck should read as a build: raw inputs → what they imply → the model → the drivers → what's
open → the recommendation. A presenter can drop slides, but this order keeps the logic honest.

1. **Title** — customer + "API Consumption & Growth Projection" (or similar).
2. **Level set** — the data exactly as provided, two cards (current usage vs expected growth). The
   shared baseline so nobody relitigates the inputs.
3. **Stats** — the same numbers as a scoreboard, with the contracted entitlement alongside so usage
   has a license to sit against.
4. **Consumption chart** — stacked bar: measured-actual base (annualized) + projected additions.
   If there's an entitlement line (e.g. licensed request volume), show it so over/under-consumption
   is visible.
5. **Growth drivers** — quantified vs unquantified upside, each labelled by source.
6. **Assumptions & open items** — the gaps; mirror `confirmations-needed.md`.
7. **Recommendation** — the action on the line that holds the value, tied to the timeline.

Keep the chart anchored on the measured actual; layer projections visibly on top so the eye
separates ground truth from forecast.

## Generator skeleton (pptxgenjs, dark Kong theme)

`npm install pptxgenjs` locally, then a `generate.js` like this. Kong logo assets (wordmark, mark,
footer mark) come from `kong-branding/assets/logos/deck-optimized/`; background art (rays, etc.)
comes from `kong-revealjs-theme/theme/assets/images/` since that's deck-specific texture, not a
brand logo. Point `IMG` at wherever you copied them. Palette below matches `kong-revealjs-theme/theme/kong.css`
exactly (this deck should stay in lockstep with that skill's values, not drift its own) — full
brand documentation lives in the `kong-branding` skill: black `000000`, white `FFFFFF`, neon
`CCFF00`, silver `AAB4BB`, muted `8A8F89`, card `30352F`, dark card `0D1A0E`, border `1F3D1F`.
Font `Funnel Sans`.

```js
const pptxgen = require("pptxgenjs");
const path = require("path");
const IMG = path.join(__dirname, "assets", "images");
const C = { black:"000000", white:"FFFFFF", green:"CCFF00", silver:"AAB4BB",
            muted:"8A8F89", card:"30352F", cardDark:"0D1A0E", border:"1F3D1F" };
const FONT = "Funnel Sans";
const pres = new pptxgen(); pres.layout = "LAYOUT_16x9"; // 10 x 5.625

function footer(s, n) {
  s.addShape(pres.shapes.LINE, { x:0.4, y:5.16, w:9.2, h:0, line:{ color:C.border, width:1 } });
  s.addImage({ path: path.join(IMG,"kong-mark-footer.png"), x:0.4, y:5.26, w:0.22, h:0.22 });
  s.addText("AI CONNECTIVITY", { x:0.68, y:5.26, w:2.2, h:0.22, fontFace:FONT, fontSize:7, color:C.green, bold:true, charSpacing:1, valign:"middle", margin:0 });
  s.addText("INTERNAL DRAFT · NOT FOR EXTERNAL USE", { x:5.2, y:5.26, w:3.8, h:0.22, fontFace:FONT, fontSize:7, color:C.muted, valign:"middle", align:"right", margin:0 });
  s.addText(String(n), { x:9.15, y:5.26, w:0.45, h:0.22, fontFace:FONT, fontSize:7, color:C.muted, align:"right", valign:"middle", margin:0 });
}
function header(s, label, runs) {
  s.addText(label.toUpperCase(), { x:0.5, y:0.42, w:9, h:0.25, fontFace:FONT, fontSize:10, color:C.green, bold:true, charSpacing:2, margin:0 });
  s.addText(runs, { x:0.5, y:0.7, w:9, h:0.7, fontFace:FONT, fontSize:32, color:C.white, bold:true, margin:0 });
}

// Consumption chart: measured base (silver) + projection (green), stacked.
// dataLabelFormatCode "0.#;0.#;;" -> one decimal, and hides the zero label on the base bar.
function consumptionChart(s) {
  const data = [
    { name:"Base (measured)",     labels:["Current (annualized)","Modeled renewal yr"], values:[26,26] },
    { name:"Projected addition",  labels:["Current (annualized)","Modeled renewal yr"], values:[0,7.6] },
  ];
  s.addChart(pres.charts.BAR, data, {
    x:0.5, y:1.55, w:5.9, h:3.4, barDir:"col", barGrouping:"stacked",
    chartColors:[C.silver, C.green], chartArea:{ fill:{ color:C.black } }, plotArea:{ fill:{ color:C.black } },
    catAxisLabelColor:C.silver, valAxisLabelColor:C.muted, valAxisMinVal:0, valAxisMaxVal:38, valAxisMajorUnit:10,
    valAxisTitle:"Requests / year (millions)", showValAxisTitle:true, valAxisTitleColor:C.muted,
    valGridLine:{ color:C.border, size:0.5 }, catGridLine:{ style:"none" },
    showValue:true, dataLabelColor:C.cardDark, dataLabelFontBold:true, dataLabelFormatCode:"0.#;0.#;;",
    showLegend:true, legendPos:"b", legendColor:C.silver, showTitle:false,
  });
}
// ...title/level-set/stats/drivers/assumptions/recommendation slides per the spine...
pres.writeFile({ fileName: "renewal-projection.pptx" });
```

### pptxgenjs gotchas (also in the kong-pptx skill)

- Hex colours never start with `#`; never encode opacity in an 8-char hex (both corrupt the file).
- `bullet: true`, never a literal "•". For paragraph-style body, drop bullets and use `paraSpaceAfter`.
- Don't reuse a shadow/option object across `addShape` calls — pptxgenjs mutates it in place.
- A stacked chart can't easily total-label bars; put the total in the slide header or a side card.

### Render and QA

No `pdftoppm`/`gs` on PATH? LibreOffice converts to PDF (`soffice --headless --convert-to pdf`), and
a ghostscript binary usually exists in the nix store — point ImageMagick at it
(`magick -density 130 deck.pdf -alpha remove slide-%d.jpg`). Then read the JPGs and fix overlaps,
overflow, stray chart labels. One fix-and-verify cycle minimum. Confirm notes embedded:
`python3` + `zipfile` over `ppt/notesSlides/notesSlide*.xml`.

## Speaker-notes convention

Notes are a data audit trail, not a script. Each slide:

```
SOURCES: which numbers are measured (and who pulled them), which are customer projections, which
         are Salesforce entitlement. Be specific — name the actual figure and its origin.
SALESFORCE CONTEXT (where relevant): the licensed quantities the slide's usage sits against.
WHY THIS SLIDE: the reason it earns a place in the build.
OPEN: what still needs confirming, and by whom.
```

Lead consumption slides with the measured ground-truth figure spelled out (e.g. the exact request
count and window) so it's never confused with the projections built on top of it.

## Working docs

`customer-questions.md` — only what the customer can answer (go-live dates, future volumes, whether
new items are net-new services, double-count checks). Slack-friendly markdown, text-polished.

`confirmations-needed.md` — open items grouped by owner, each with why it matters and where to get
it. Mark what Salesforce already answered so the list shrinks honestly. Suggest an order
(data owner → deal desk → renewal manager → customer).
