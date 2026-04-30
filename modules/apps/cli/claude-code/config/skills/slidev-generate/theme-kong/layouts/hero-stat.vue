<template>
  <KongChrome :category="category">
    <div class="kong-hero">
      <header class="kong-hero__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title" v-html="renderedTitle" />
        <p v-if="intro" class="kong-hero__intro">{{ intro }}</p>
      </header>

      <div class="kong-hero__stat">
        <p v-if="label" class="kong-hero__label">{{ label }}</p>
        <p class="kong-hero__num">{{ value }}</p>
        <p v-if="note" class="kong-hero__note">{{ note }}</p>
      </div>

      <img
        v-if="!hideOrbit"
        src="/kong-blades-orbit.png"
        alt=""
        class="kong-hero__orbit"
      />
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
  value: { type: [String, Number], default: '' },
  label: String,
  note: String,
  hideOrbit: { type: Boolean, default: false },
});

const renderedTitle = computed(() => {
  if (!props.title) return '';
  return props.title.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
});
</script>

<style scoped>
.kong-hero {
  width: 100%;
  height: 100%;
  padding: 2rem 2.4rem 1.6rem;
  display: grid;
  grid-template-columns: 1.1fr 1fr;
  gap: 2rem;
  align-items: center;
  color: var(--kong-surface);
  position: relative;
  overflow: hidden;
}

.kong-hero__orbit {
  position: absolute;
  right: -8rem;
  top: -6rem;
  width: 24rem;
  opacity: 0.4;
  pointer-events: none;
}

.kong-hero__head h2 {
  margin: 0.4rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.6rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
}

.kong-hero__head h2 :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-hero__intro {
  margin: 0.8rem 0 0;
  font-family: var(--kong-sans);
  font-size: 1rem;
  color: var(--kong-grey-300);
  max-width: 95%;
  line-height: 1.5;
}

.kong-hero__stat {
  position: relative;
  z-index: 1;
  background: var(--kong-bg-dark);
  padding: 1.8rem 1.6rem;
  display: grid;
  gap: 0.6rem;
  border-left: 4px solid var(--kong-lime);
}

.kong-hero__label {
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.78rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-hero__num {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 6rem;
  line-height: 0.95;
  color: var(--kong-lime);
  letter-spacing: -0.05em;
}

.kong-hero__note {
  margin: 0.2rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.9rem;
  color: var(--kong-grey-300);
  line-height: 1.4;
}
</style>
