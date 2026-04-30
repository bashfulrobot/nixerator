<template>
  <KongChrome :category="category">
    <div class="kong-tl">
      <header v-if="title || eyebrow || intro" class="kong-tl__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
        <p v-if="intro" class="kong-tl__intro">{{ intro }}</p>
      </header>

      <div class="kong-tl__track" :style="{ '--kong-tl-cols': items.length }">
        <div class="kong-tl__line" aria-hidden="true" />
        <div
          v-for="(item, i) in items"
          :key="i"
          class="kong-tl__step"
        >
          <div class="kong-tl__node">
            <span class="kong-tl__node-num">{{ String(i + 1).padStart(2, '0') }}</span>
          </div>
          <p v-if="item.label" class="kong-tl__label">{{ item.label }}</p>
          <p class="kong-tl__title">{{ item.title }}</p>
          <p v-if="item.body" class="kong-tl__body">{{ item.body }}</p>
        </div>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  title: String,
  eyebrow: String,
  intro: String,
  category: String,
  items: { type: Array, default: () => [] },
});
</script>

<style scoped>
.kong-tl {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-tl__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.2rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 80%;
}

.kong-tl__intro {
  margin: 0.5rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 75%;
}

.kong-tl__track {
  display: grid;
  grid-template-columns: repeat(var(--kong-tl-cols, 4), 1fr);
  gap: 1.2rem;
  align-content: start;
  position: relative;
  padding-top: 1rem;
}

.kong-tl__line {
  position: absolute;
  top: calc(1rem + 1.05rem);
  left: 1.6rem;
  right: 1.6rem;
  height: 2px;
  background: linear-gradient(
    to right,
    rgba(204, 255, 0, 0.55),
    rgba(204, 255, 0, 0.18)
  );
  z-index: 0;
}

.kong-tl__step {
  position: relative;
  z-index: 1;
  display: grid;
  gap: 0.4rem;
  padding-right: 0.4rem;
}

.kong-tl__node {
  width: 2.1rem;
  height: 2.1rem;
  background: var(--kong-bg-deep);
  border: 2px solid var(--kong-lime);
  display: grid;
  place-items: center;
  margin-bottom: 0.4rem;
}

.kong-tl__node-num {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 0.78rem;
  color: var(--kong-lime);
  letter-spacing: -0.01em;
}

.kong-tl__label {
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.68rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-tl__title {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.05rem;
  line-height: 1.2;
  color: var(--kong-surface);
  letter-spacing: -0.005em;
}

.kong-tl__body {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.82rem;
  line-height: 1.45;
  color: var(--kong-grey-300);
}
</style>
