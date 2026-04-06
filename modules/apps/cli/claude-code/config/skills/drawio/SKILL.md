---
name: drawio
description: >
  Generate draw.io diagrams as mxGraphModel XML. Always use when the user asks to
  create, generate, draw, or design a diagram, flowchart, architecture diagram, ER
  diagram, sequence diagram, class diagram, network diagram, state diagram, mind map,
  org chart, wireframe, or any visual diagram. Also trigger when the user mentions
  draw.io, diagrams.net, mxGraph, .drawio files, or asks to visualize a system,
  workflow, or data model. Trigger on diagram export requests (PNG, SVG, PDF).
allowed-tools:
  - Bash
  - Read
  - Write
  - mcp__drawio__open_drawio_xml
  - mcp__drawio__open_drawio_csv
  - mcp__drawio__open_drawio_mermaid
---

# draw.io Diagram Generation

You are a diagram generation specialist that produces draw.io-compatible mxGraphModel XML. You create professional, well-laid-out diagrams with semantically appropriate shapes and proper draw.io conventions.

## Core Workflow

1. **Generate mxGraphModel XML** for the requested diagram
2. **Write the XML** to a `.drawio` file using the Write tool
3. **If export format requested** (png, svg, pdf), export via the draw.io CLI, then delete the intermediate `.drawio`
4. **Open the result** with `xdg-open <file>` (Linux) or use the MCP tool `mcp__drawio__open_drawio_xml` to open in the browser editor
5. If the CLI is not found, keep the `.drawio` file and tell the user they can open it directly

## XML Structure

Every diagram must have this skeleton:

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Shapes and edges go here with parent="1" -->
  </root>
</mxGraphModel>
```

- Cell `id="0"` is the root (mandatory)
- Cell `id="1"` is the default parent layer (mandatory)
- All diagram elements use `parent="1"` unless using layers or containers
- Use `vertex="1"` for shapes, `edge="1"` for connectors (mutually exclusive)
- Style format: semicolon-separated `key=value;` pairs (e.g. `rounded=1;whiteSpace=wrap;fillColor=#DAE8FC;`)
- Coordinate system: origin (0,0) at top-left; x increases rightward, y increases downward
- Always generate uncompressed plain XML, never compressed/Base64

## Shape Examples

**Rounded rectangle:**
```xml
<mxCell id="2" value="Label" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
</mxCell>
```

**Diamond (decision):**
```xml
<mxCell id="3" value="Condition?" style="rhombus;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="200" width="120" height="80" as="geometry"/>
</mxCell>
```

**Database cylinder:**
```xml
<mxCell id="4" value="Users DB" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;backgroundOutline=1;" vertex="1" parent="1">
  <mxGeometry x="100" y="300" width="100" height="80" as="geometry"/>
</mxCell>
```

## Style Properties Reference

| Property | Values | Use for |
|----------|--------|---------|
| `rounded=1` | 0 or 1 | Rounded corners |
| `whiteSpace=wrap` | wrap | Text wrapping |
| `fillColor=#dae8fc` | Hex color | Background color |
| `strokeColor=#6c8ebf` | Hex color | Border color |
| `fontColor=#333333` | Hex color | Text color |
| `fontSize=14` | Number | Font size in px |
| `shape=cylinder3` | shape name | Database cylinders |
| `shape=mxgraph.flowchart.document` | shape name | Document shapes |
| `ellipse` | style keyword | Circles/ovals |
| `rhombus` | style keyword | Diamonds |
| `edgeStyle=orthogonalEdgeStyle` | style keyword | Right-angle connectors |
| `edgeStyle=elbowEdgeStyle` | style keyword | Elbow connectors |
| `dashed=1` | 0 or 1 | Dashed lines |
| `swimlane` | style keyword | Swimlane containers |
| `group` | style keyword | Invisible container |
| `container=1` | 0 or 1 | Enable container behavior |
| `pointerEvents=0` | 0 or 1 | Prevent container capturing child connections |

## Edge Routing

**CRITICAL: Every edge `mxCell` must contain a `<mxGeometry relative="1" as="geometry"/>` child element.** Self-closing edge cells are invalid and will not render. Always use the expanded form:

```xml
<mxCell id="e1" edge="1" parent="1" source="2" target="3" style="edgeStyle=orthogonalEdgeStyle;">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

**Labeled edge:**
```xml
<mxCell id="e2" value="Yes" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="3" target="4" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

### Layout guidelines

- **Space nodes generously** -- at least 60px apart, prefer 200px horizontal / 120px vertical gaps
- Use `exitX`/`exitY` and `entryX`/`entryY` (values 0-1) to control which side of a node an edge connects to; spread connections across sides
- **Leave room for arrowheads** -- at least 20px of straight segment before target and after source
- Align all nodes to a grid (multiples of 10)
- Use `rounded=1` on edges for cleaner bends
- Use `jettySize=auto` for better port spacing on orthogonal edges
- **Edge labels**: do NOT wrap in HTML markup to reduce font size; default edge label font is already 11px

### Waypoints for complex routing

When edges would overlap, add explicit waypoints:

```xml
<mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="a" target="b">
  <mxGeometry relative="1" as="geometry">
    <Array as="points">
      <mxPoint x="300" y="150"/>
      <mxPoint x="300" y="250"/>
    </Array>
  </mxGeometry>
</mxCell>
```

## Containers and Groups

For nested elements, use draw.io's proper parent-child containment. Set `parent="containerId"` on child cells. Children use **relative coordinates** within the container.

### Container types

| Type | Style | When to use |
|------|-------|-------------|
| **Group** (invisible) | `group;` | No visual border needed; includes `pointerEvents=0` |
| **Swimlane** (titled) | `swimlane;startSize=30;` | Container needs a visible title bar, or container itself has connections |
| **Custom container** | Add `container=1;pointerEvents=0;` to any shape | Any shape acting as a container without its own connections |

**Always add `pointerEvents=0;`** to container styles that should not capture connections. Only omit when the container itself must be connectable (use `swimlane` for that).

### Swimlane example

```xml
<mxCell id="svc1" value="User Service" style="swimlane;startSize=30;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="300" height="200" as="geometry"/>
</mxCell>
<mxCell id="api1" value="REST API" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="svc1">
  <mxGeometry x="20" y="40" width="120" height="60" as="geometry"/>
</mxCell>
<mxCell id="db1" value="Database" style="shape=cylinder3;whiteSpace=wrap;" vertex="1" parent="svc1">
  <mxGeometry x="160" y="40" width="120" height="60" as="geometry"/>
</mxCell>
```

### Invisible group example

```xml
<mxCell id="grp1" value="" style="group;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="300" height="200" as="geometry"/>
</mxCell>
<mxCell id="c1" value="Component A" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="grp1">
  <mxGeometry x="10" y="10" width="120" height="60" as="geometry"/>
</mxCell>
```

## Layers

Layers control visibility and z-order. Cell `id="0"` is the root; cell `id="1"` is the default layer. Additional layers are `mxCell` elements with `parent="0"`:

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="Annotations" parent="0"/>
    <mxCell id="10" value="Server" style="rounded=1;" vertex="1" parent="1">
      <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="20" value="Note: deprecated" style="text;" vertex="1" parent="2">
      <mxGeometry x="100" y="170" width="120" height="30" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

- A layer is an `mxCell` with `parent="0"` and no `vertex` or `edge` attribute
- Assign shapes to a layer by setting `parent` to that layer's id
- Later layers render on top (higher z-order)
- Add `visible="0"` on a layer cell to hide it by default
- Use layers when the diagram has conceptual groupings viewers may want to toggle

## Tags

Tags let viewers show or hide elements by category. Unlike layers, a single element can have multiple tags. Tags require wrapping `mxCell` in an `<object>` element:

```xml
<object id="2" label="Auth Service" tags="critical v2">
  <mxCell style="rounded=1;whiteSpace=wrap;html=1;" vertex="1" parent="1">
    <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
  </mxCell>
</object>
<object id="3" label="Legacy API" tags="critical deprecated">
  <mxCell style="rounded=1;whiteSpace=wrap;html=1;" vertex="1" parent="1">
    <mxGeometry x="300" y="100" width="120" height="60" as="geometry"/>
  </mxCell>
</object>
```

- Tags require the `<object>` wrapper -- plain `mxCell` cannot have tags
- `label` on `<object>` replaces `value` on `mxCell`
- Tags are space-separated in the `tags` attribute
- Viewers filter via Edit > Tags in draw.io

## Metadata and Placeholders

Attach custom key-value properties as attributes on an `<object>` wrapper. Combined with `placeholders="1"`, values substitute into labels via `%propertyName%`:

```xml
<object id="2" label="&lt;b&gt;%component%&lt;/b&gt;&lt;br&gt;Owner: %owner%&lt;br&gt;Status: %status%"
        placeholders="1" component="Auth Service" owner="Team Backend" status="Active">
  <mxCell style="rounded=1;whiteSpace=wrap;html=1;" vertex="1" parent="1">
    <mxGeometry x="100" y="100" width="160" height="80" as="geometry"/>
  </mxCell>
</object>
```

### Placeholder resolution hierarchy

1. Cell attributes (highest priority)
2. Parent container attributes
3. Layer attributes
4. Root container attributes
5. File-level vars (lowest priority)

### Predefined placeholders (no custom properties needed)

`%id%`, `%width%`, `%height%`, `%date%`, `%time%`, `%timestamp%`, `%page%`, `%pagenumber%`, `%pagecount%`, `%filename%`

Use `%%` for a literal percent sign.

## File-Level Variables

Set variables on the `<mxfile>` wrapper for diagram-wide values:

```xml
<mxfile vars='{"project":"Atlas","version":"2.1","author":"Jane Doe"}'>
  <diagram id="page-1" name="Page-1">
    <mxGraphModel adaptiveColors="auto">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

Variables are referenced via `%project%`, `%version%`, etc. in labels with `placeholders="1"`.

## Dark Mode

Set `adaptiveColors="auto"` on `mxGraphModel` for automatic color inversion (already in the skeleton above).

- Default colors (`strokeColor`, `fillColor`, `fontColor` set to `"default"`) adapt automatically
- Explicit hex colors (e.g. `fillColor=#DAE8FC`) are automatically inverted in dark mode
- For manual control: `light-dark(lightColor,darkColor)` (e.g. `fontColor=light-dark(#7EA6E0,#FF0000)`)
- Generally do not specify dark-mode colors -- automatic inversion handles most cases

## Shape Selection Guidance

Before generating, decide if domain-specific shapes are needed:

**Skip `search_shapes`** for standard diagram types using basic geometric shapes:
- Flowcharts, UML (class, sequence, state, activity), ERD, org charts
- Mind maps, Venn diagrams, timelines, wireframes
- Any diagram using only rectangles, diamonds, circles, cylinders, and arrows

**Use `search_shapes`** when the diagram requires industry-specific or branded icons:
- Cloud architecture (AWS, Azure, GCP)
- Network topology (Cisco, rack equipment)
- P&ID (valves, instruments, vessels)
- Electrical/circuit diagrams
- Kubernetes, BPMN with specific task types
- Any domain where the user expects realistic/standardized symbols

**Match the language of labels to the user's language** -- if the user writes in German, French, Japanese, etc., all labels should be in that language.

## Output Format and CLI Export

### Format selection

- No format specified: write `.drawio` file only
- PNG/SVG/PDF requested: export to `name.drawio.<format>` with embedded XML
- JPG requested: export without XML embedding

### Export command

```bash
drawio -x -f <format> -e -b 10 -o <output> <input.drawio>
```

Flags:
- `-x` / `--export`: export mode
- `-f` / `--format`: png, svg, pdf, jpg
- `-e` / `--embed-diagram`: embed XML in output (PNG, SVG, PDF only)
- `-b` / `--border`: border width (default 0, recommend 10)
- `-o` / `--output`: output file path
- `-t` / `--transparent`: transparent background (PNG only)
- `-s` / `--scale`: scale diagram size
- `--width` / `--height`: fit into dimensions (preserves aspect ratio)
- `-a` / `--all-pages`: export all pages (PDF only)
- `-p` / `--page-index`: select specific page (0-based)

### Workflow

1. Write XML to `name.drawio`
2. Export: `drawio -x -f png -e -b 10 -o name.drawio.png name.drawio`
3. Delete intermediate: `rm name.drawio`
4. Open result: `xdg-open name.drawio.png`

If `drawio` is not on PATH, keep the `.drawio` file and inform the user.

## MCP Tools

Three MCP tools are available to open diagrams in the browser-based draw.io editor:

- **`mcp__drawio__open_drawio_xml`** -- pass generated XML to open in the browser editor. Use this to preview diagrams interactively.
- **`mcp__drawio__open_drawio_csv`** -- convert tabular CSV data into diagrams (org charts, flowcharts).
- **`mcp__drawio__open_drawio_mermaid`** -- convert Mermaid.js syntax into editable draw.io diagrams.

Prefer generating native XML and using `open_drawio_xml` or writing `.drawio` files. Use CSV/Mermaid tools only when the user specifically requests those formats.

## File Naming

- Descriptive, lowercase, hyphenated names (e.g. `login-flow`, `database-schema`)
- Export files use double extensions: `name.drawio.png`, `name.drawio.svg`
- Delete intermediate `.drawio` after successful export

## XML Well-Formedness

- **NEVER include ANY XML comments (`<!-- -->`)** -- they waste tokens, can cause parse errors, and serve no purpose
- Escape special characters: `&amp;`, `&lt;`, `&gt;`, `&quot;`
- Always use unique `id` values for every `mxCell` and `object`
- Non-rectangular shapes need matching `perimeter` values in their style

## Complete Examples

### Simple Flowchart

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="start" value="Start" style="ellipse;whiteSpace=wrap;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
      <mxGeometry x="200" y="40" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="process" value="Process Data" style="rounded=1;whiteSpace=wrap;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
      <mxGeometry x="190" y="160" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="decision" value="Valid?" style="rhombus;whiteSpace=wrap;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
      <mxGeometry x="190" y="290" width="120" height="80" as="geometry"/>
    </mxCell>
    <mxCell id="success" value="Save" style="rounded=1;whiteSpace=wrap;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
      <mxGeometry x="80" y="440" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="error" value="Show Error" style="rounded=1;whiteSpace=wrap;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
      <mxGeometry x="300" y="440" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="end" value="End" style="ellipse;whiteSpace=wrap;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
      <mxGeometry x="200" y="570" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="start" target="process">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="process" target="decision">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" value="Yes" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="decision" target="success">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e4" value="No" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="decision" target="error">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="success" target="end">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="error" target="end">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

### Architecture Diagram with Containers

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="client" value="Client Tier" style="swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#666666;fontStyle=1;" vertex="1" parent="1">
      <mxGeometry x="50" y="40" width="200" height="160" as="geometry"/>
    </mxCell>
    <mxCell id="web" value="Web App" style="rounded=1;whiteSpace=wrap;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="client">
      <mxGeometry x="20" y="50" width="160" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="mobile" value="Mobile App" style="rounded=1;whiteSpace=wrap;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="client">
      <mxGeometry x="20" y="100" width="160" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="backend" value="Backend" style="swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#666666;fontStyle=1;" vertex="1" parent="1">
      <mxGeometry x="350" y="40" width="220" height="160" as="geometry"/>
    </mxCell>
    <mxCell id="api" value="API Gateway" style="rounded=1;whiteSpace=wrap;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="backend">
      <mxGeometry x="30" y="50" width="160" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="auth" value="Auth Service" style="rounded=1;whiteSpace=wrap;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="backend">
      <mxGeometry x="30" y="100" width="160" height="40" as="geometry"/>
    </mxCell>
    <mxCell id="data" value="Data Tier" style="swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#666666;fontStyle=1;" vertex="1" parent="1">
      <mxGeometry x="670" y="40" width="200" height="160" as="geometry"/>
    </mxCell>
    <mxCell id="db" value="PostgreSQL" style="shape=cylinder3;whiteSpace=wrap;boundedLbl=1;backgroundOutline=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="data">
      <mxGeometry x="40" y="45" width="120" height="80" as="geometry"/>
    </mxCell>
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="web" target="api">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="mobile" target="api">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="api" target="auth">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
    <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="api" target="db">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```
