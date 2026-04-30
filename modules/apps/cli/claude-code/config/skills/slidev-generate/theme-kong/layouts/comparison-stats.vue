<template>
  <KongChrome :category="category">
    <div class="kong-comp">
      <div class="kong-comp__text">
        <header class="kong-comp__head">
          <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
          <h2 v-if="title" v-html="renderedTitle" />
          <p v-if="intro" class="kong-comp__intro">{{ intro }}</p>
        </header>

        <ul v-if="bullets?.length" class="kong-comp__bullets">
          <li v-for="(b, i) in bullets" :key="i">{{ b }}</li>
        </ul>

        <p v-if="footer" class="kong-comp__footer">{{ footer }}</p>
      </div>

      <div class="kong-comp__viz">
        <slot name="viz">
          <div v-if="bars?.length" class="kong-comp__bars">
            <div
              v-for="(bar, i) in bars"
              :key="i"
              class="kong-comp__bar"
              :data-highlight="bar.highlight ? 'true' : 'false'"
            >
              <span class="kong-comp__bar-label">{{ bar.label }}</span>
              <div class="kong-comp__bar-track">
                <div
                  class="kong-comp__bar-fill"
                  :style="{ width: `${Math.min(Math.max(bar.value, 0), 100)}%` }"
                />
              </div>
              <span class="kong-comp__bar-value">{{ bar.display ?? `${bar.value}%` }}</span>
            </div>
          </div>
        </slot>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import { computed } from 'vue';
import KongChrome from '../components/KongChrome.vue';

const props = defineProps({
  title: String,
  eyebrow: String,
  intro: String,
  footer: String,
  category: String,
  bullets: { type: Array, default: () => [] },
  bars: { type: Array, default: () => [] },
});

const renderedTitle = computed(() => {
  if (!props.title) return '';
  return props.title.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
});
</script>

<style scoped>
.kong-comp {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-columns: 1fr 1.05fr;
  gap: 2rem;
  align-items: stretch;
  color: var(--kong-surface);
}

.kong-comp__text {
  display: grid;
  grid-template-rows: auto auto auto;
  gap: 1rem;
  align-content: start;
}

.kong-comp__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
}

.kong-comp__head h2 :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-comp__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  line-height: 1.5;
}

.kong-comp__bullets {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.4rem;
}

.kong-comp__bullets li {
  position: relative;
  padding-left: 1.1rem;
  font-family: var(--kong-sans);
  font-size: 0.9rem;
  line-height: 1.45;
  color: var(--kong-grey-300);
  margin: 0;
}

.kong-comp__bullets li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.55em;
  width: 0.45em;
  height: 0.45em;
  background: var(--kong-lime);
}

.kong-comp__footer {
  margin: 0.4rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.78rem;
  letter-spacing: 0.04em;
  color: var(--kong-grey-400);
}

.kong-comp__viz {
  background: var(--kong-bg-dark);
  border-left: 3px solid var(--kong-lime);
  padding: 1.2rem 1.4rem;
  display: grid;
  align-content: center;
}

.kong-comp__bars {
  display: grid;
  gap: 0.85rem;
}

.kong-comp__bar {
  display: grid;
  grid-template-columns: 6.5rem 1fr auto;
  align-items: center;
  gap: 0.7rem;
}

.kong-comp__bar-label {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.78rem;
  letter-spacing: 0.04em;
  color: var(--kong-grey-300);
  text-transform: uppercase;
}

.kong-comp__bar-track {
  height: 0.65rem;
  background: rgba(204, 255, 0, 0.08);
  position: relative;
  overflow: hidden;
}

.kong-comp__bar-fill {
  height: 100%;
  background: var(--kong-lime-soft);
  transition: width 0.6s ease;
}

.kong-comp__bar[data-highlight="true"] .kong-comp__bar-fill {
  background: var(--kong-lime);
}

.kong-comp__bar-value {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1rem;
  color: var(--kong-surface);
  letter-spacing: -0.01em;
  min-width: 3rem;
  text-align: right;
}

.kong-comp__bar[data-highlight="true"] .kong-comp__bar-value {
  color: var(--kong-lime);
}
</style>
