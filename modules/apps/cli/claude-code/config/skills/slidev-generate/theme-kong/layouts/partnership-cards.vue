<template>
  <KongChrome :category="category">
    <div class="kong-pcards">
      <header v-if="title || eyebrow || intro" class="kong-pcards__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
        <p v-if="intro" class="kong-pcards__intro">{{ intro }}</p>
      </header>

      <div class="kong-pcards__grid" :data-cols="cols">
        <article
          v-for="(item, i) in items"
          :key="i"
          class="kong-pcards__card"
        >
          <div class="kong-pcards__top">
            <p v-if="item.label" class="kong-pcards__label">{{ item.label }}</p>
            <p v-if="item.metric" class="kong-pcards__metric">{{ item.metric }}</p>
          </div>
          <h3 class="kong-pcards__title">{{ item.title }}</h3>
          <p v-if="item.body" class="kong-pcards__body">{{ item.body }}</p>
        </article>
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
  category: String,
  items: { type: Array, default: () => [] },
});

const cols = computed(() => {
  const n = props.items.length;
  if (n <= 1) return 1;
  if (n === 2) return 2;
  if (n === 3) return 3;
  return 2;
});
</script>

<style scoped>
.kong-pcards {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.3rem;
  color: var(--kong-surface);
}

.kong-pcards__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  letter-spacing: -0.01em;
  line-height: 1.05;
  max-width: 75%;
}

.kong-pcards__intro {
  margin: 0.5rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 75%;
}

.kong-pcards__grid {
  display: grid;
  gap: 4px;
  background: rgba(204, 255, 0, 0.08);
  align-items: stretch;
}

.kong-pcards__grid[data-cols="1"] { grid-template-columns: 1fr; }
.kong-pcards__grid[data-cols="2"] { grid-template-columns: 1fr 1fr; }
.kong-pcards__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }

/* 4 items: 2x2 */
.kong-pcards__grid[data-cols="2"]:has(.kong-pcards__card:nth-child(4)) {
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
}

.kong-pcards__card {
  background: var(--kong-bg-dark);
  padding: 1.2rem 1.3rem 1rem;
  display: grid;
  grid-template-rows: auto auto 1fr;
  gap: 0.5rem;
  position: relative;
  overflow: hidden;
}

.kong-pcards__card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--kong-lime);
}

.kong-pcards__top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
}

.kong-pcards__label {
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.7rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-pcards__metric {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.6rem;
  line-height: 1;
  color: var(--kong-lime);
  letter-spacing: -0.02em;
}

.kong-pcards__title {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.15rem;
  line-height: 1.2;
  color: var(--kong-surface);
  letter-spacing: -0.005em;
}

.kong-pcards__body {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
  align-self: start;
}
</style>
