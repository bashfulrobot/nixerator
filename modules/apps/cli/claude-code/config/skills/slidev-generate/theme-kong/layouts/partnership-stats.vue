<template>
  <KongChrome :category="category">
    <div class="kong-pstats">
      <header class="kong-pstats__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title" v-html="renderedTitle" />
        <p v-if="intro" class="kong-pstats__intro">{{ intro }}</p>
      </header>

      <div class="kong-pstats__row">
        <div
          v-for="(item, i) in items.slice(0, 2)"
          :key="i"
          class="kong-pstats__cell"
        >
          <p class="kong-pstats__num">{{ item.value }}</p>
          <p v-if="item.label" class="kong-pstats__label">{{ item.label }}</p>
          <p v-if="item.note" class="kong-pstats__note">{{ item.note }}</p>
        </div>
      </div>

      <p v-if="footer" class="kong-pstats__footer">{{ footer }}</p>
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
  items: { type: Array, default: () => [] },
});

const renderedTitle = computed(() => {
  if (!props.title) return '';
  return props.title.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
});
</script>

<style scoped>
.kong-pstats {
  width: 100%;
  height: 100%;
  padding: 2rem 2.4rem 1.6rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr auto;
  gap: 1.6rem 2rem;
  color: var(--kong-surface);
}

.kong-pstats__head {
  grid-column: 1 / -1;
  align-self: end;
}

.kong-pstats__head h2 {
  margin: 0.4rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 90%;
}

.kong-pstats__head h2 :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-pstats__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 80%;
}

.kong-pstats__row {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
  background: rgba(204, 255, 0, 0.08);
  align-items: stretch;
}

.kong-pstats__cell {
  background: var(--kong-bg-dark);
  padding: 1.6rem 1.6rem 1.4rem;
  display: grid;
  gap: 0.4rem;
  align-content: center;
  position: relative;
  overflow: hidden;
}

.kong-pstats__cell:nth-child(odd)::after {
  content: '';
  position: absolute;
  bottom: -30%;
  right: -15%;
  width: 60%;
  height: 100%;
  background: radial-gradient(closest-side, rgba(204, 255, 0, 0.16), transparent 70%);
  pointer-events: none;
}

.kong-pstats__num {
  position: relative;
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 4.6rem;
  line-height: 1;
  color: var(--kong-lime);
  letter-spacing: -0.04em;
}

.kong-pstats__label {
  position: relative;
  margin: 0.2rem 0 0;
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 1rem;
  color: var(--kong-surface);
}

.kong-pstats__note {
  position: relative;
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  color: var(--kong-grey-300);
  line-height: 1.4;
}

.kong-pstats__footer {
  grid-column: 1 / -1;
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.8rem;
  color: var(--kong-grey-400);
}
</style>
