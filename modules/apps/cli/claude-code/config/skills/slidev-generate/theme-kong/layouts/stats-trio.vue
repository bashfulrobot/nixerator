<template>
  <KongChrome :category="category">
    <div class="kong-trio">
      <header class="kong-trio__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title" v-html="renderedTitle" />
        <p v-if="intro" class="kong-trio__intro">{{ intro }}</p>
      </header>

      <div class="kong-trio__row">
        <div
          v-for="(item, i) in items.slice(0, 3)"
          :key="i"
          class="kong-trio__cell"
        >
          <p v-if="item.label" class="kong-trio__label">{{ item.label }}</p>
          <p class="kong-trio__num">{{ item.value }}</p>
          <p v-if="item.note" class="kong-trio__note">{{ item.note }}</p>
        </div>
      </div>

      <p v-if="footer" class="kong-trio__footer">{{ footer }}</p>
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
.kong-trio {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-trio__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 75%;
}

.kong-trio__head h2 :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-trio__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 70%;
}

.kong-trio__row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 4px;
  background: rgba(204, 255, 0, 0.08);
  align-items: stretch;
}

.kong-trio__cell {
  background: var(--kong-bg-dark);
  padding: 1.4rem 1.4rem 1.2rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 0.6rem;
  position: relative;
  overflow: hidden;
}

.kong-trio__cell::after {
  content: '';
  position: absolute;
  bottom: -30%;
  left: -10%;
  width: 50%;
  height: 80%;
  background: radial-gradient(closest-side, rgba(204, 255, 0, 0.14), transparent 70%);
  pointer-events: none;
}

.kong-trio__label {
  position: relative;
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.72rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-trio__num {
  position: relative;
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 3.4rem;
  line-height: 1;
  color: var(--kong-surface);
  letter-spacing: -0.04em;
  align-self: end;
}

.kong-trio__note {
  position: relative;
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.82rem;
  color: var(--kong-grey-300);
  line-height: 1.4;
}

.kong-trio__footer {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.8rem;
  color: var(--kong-grey-400);
}
</style>
