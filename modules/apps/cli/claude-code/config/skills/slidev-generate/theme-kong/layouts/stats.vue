<template>
  <KongChrome :category="category">
    <div class="kong-stats">
      <header v-if="title || eyebrow || intro" class="kong-stats__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title" v-html="renderedTitle" />
        <p v-if="intro" class="kong-stats__intro">{{ intro }}</p>
      </header>

      <div class="kong-stats__grid" :data-cols="colCount">
        <div
          v-for="(item, i) in items"
          :key="i"
          class="kong-stats__cell"
          :data-glow="(i === 1 || i === 3 || i === 5) ? 'true' : 'false'"
        >
          <p class="kong-stats__num">{{ item.value }}</p>
          <p v-if="item.label" class="kong-stats__label">{{ item.label }}</p>
          <p v-if="item.note" class="kong-stats__note">{{ item.note }}</p>
        </div>
      </div>

      <p v-if="footer" class="kong-stats__footer">{{ footer }}</p>
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
  category: String,
  footer: String,
  items: { type: Array, default: () => [] },
});

const colCount = computed(() => {
  const n = props.items.length;
  if (n <= 1) return 1;
  if (n === 2) return 2;
  if (n === 3) return 3;
  if (n === 4) return 2;
  return 3;
});

// Allow `**accent**` in title to render as lime emphasis without italic.
const renderedTitle = computed(() => {
  if (!props.title) return '';
  return props.title.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
});
</script>

<style scoped>
.kong-stats {
  width: 100%;
  height: 100%;
  padding: 1.6rem 2rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1rem;
  color: var(--kong-surface);
}

.kong-stats__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 70%;
}

.kong-stats__head h2 :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-stats__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 60%;
}

.kong-stats__grid {
  display: grid;
  gap: 4px;
  align-content: stretch;
  background: rgba(204, 255, 0, 0.08);
}

.kong-stats__grid[data-cols="1"] { grid-template-columns: 1fr; }
.kong-stats__grid[data-cols="2"] { grid-template-columns: repeat(2, 1fr); }
.kong-stats__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }

.kong-stats__cell {
  position: relative;
  background: var(--kong-bg-dark);
  padding: 1.4rem 1.4rem 1.2rem;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.kong-stats__cell[data-glow="true"]::before {
  content: '';
  position: absolute;
  top: -40%;
  right: -25%;
  width: 80%;
  height: 120%;
  background: radial-gradient(closest-side, rgba(204, 255, 0, 0.18), transparent 70%);
  pointer-events: none;
}

.kong-stats__num {
  position: relative;
  margin: 0 0 0.5rem;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 3.4rem;
  line-height: 1;
  color: var(--kong-lime);
  letter-spacing: -0.04em;
}

.kong-stats__label {
  position: relative;
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.9rem;
  font-weight: 500;
  color: var(--kong-surface);
}

.kong-stats__note {
  position: relative;
  margin: 0.4rem 0 0;
  font-size: 0.85rem;
  color: var(--kong-grey-300);
}

.kong-stats__footer {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  color: var(--kong-grey-400);
}
</style>
