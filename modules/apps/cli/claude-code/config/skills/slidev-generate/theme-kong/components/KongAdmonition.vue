<template>
  <aside class="kong-admonition" :data-type="type">
    <p class="kong-admonition__label">{{ resolvedLabel }}</p>
    <div class="kong-admonition__body"><slot /></div>
  </aside>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  type: { type: String, default: 'info' },
  title: String,
});

const TYPE_LABEL = {
  info: 'NOTE',
  tip: 'TIP',
  warn: 'WATCH OUT',
  caution: 'CAUTION',
  perf: 'PERFORMANCE',
  security: 'SECURITY',
  deprecated: 'DEPRECATED',
};

const resolvedLabel = computed(() => {
  const base = TYPE_LABEL[props.type] || String(props.type).toUpperCase();
  return props.title ? `${base} — ${props.title}` : base;
});
</script>

<style scoped>
.kong-admonition {
  background: var(--kong-bg-olive);
  border-left: 4px solid var(--kong-lime);
  padding: 1rem 1.25rem;
  margin: 0.85rem 0;
  display: grid;
  gap: 0.45rem;
}

.kong-admonition__label {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.85rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
  margin: 0;
}

.kong-admonition[data-type="warn"] {
  border-left-color: var(--kong-coral);
}
.kong-admonition[data-type="warn"] .kong-admonition__label {
  color: var(--kong-coral);
}

.kong-admonition[data-type="caution"] {
  border-left-color: var(--kong-coral);
  background: rgba(228, 105, 98, 0.12);
}
.kong-admonition[data-type="caution"] .kong-admonition__label {
  color: var(--kong-coral);
}

.kong-admonition[data-type="deprecated"] {
  border-left-color: var(--kong-grey-500);
  background: var(--kong-bg-olive-dim);
}
.kong-admonition[data-type="deprecated"] .kong-admonition__label {
  color: var(--kong-grey-300);
}

.kong-admonition__body {
  font-family: var(--kong-sans);
  font-size: 1rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
}

.kong-admonition__body :deep(p) { margin: 0; }
.kong-admonition__body :deep(p + p) { margin-top: 0.5rem; }
.kong-admonition__body :deep(code) {
  background: rgba(0, 0, 0, 0.35);
}
</style>
