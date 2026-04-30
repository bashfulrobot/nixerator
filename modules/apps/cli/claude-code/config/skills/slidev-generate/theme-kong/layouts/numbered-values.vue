<template>
  <KongChrome :category="category">
    <div class="kong-nv">
      <header v-if="title || eyebrow || intro" class="kong-nv__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
        <p v-if="intro" class="kong-nv__intro">{{ intro }}</p>
      </header>

      <div class="kong-nv__grid" :data-cols="cols">
        <article
          v-for="(item, i) in items"
          :key="i"
          class="kong-nv__card"
        >
          <p class="kong-nv__num">{{ String(i + 1).padStart(2, '0') }}</p>
          <h3 class="kong-nv__title">{{ item.title }}</h3>
          <p v-if="item.body" class="kong-nv__body">{{ item.body }}</p>
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
  return 3;
});
</script>

<style scoped>
.kong-nv {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-nv__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 75%;
}

.kong-nv__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 70%;
}

.kong-nv__grid {
  display: grid;
  gap: 1.2rem;
  align-content: start;
}

.kong-nv__grid[data-cols="1"] { grid-template-columns: 1fr; }
.kong-nv__grid[data-cols="2"] { grid-template-columns: 1fr 1fr; }
.kong-nv__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }

.kong-nv__card {
  background: var(--kong-bg-dark);
  border-top: 3px solid var(--kong-lime);
  padding: 1.4rem 1.4rem 1.2rem;
  display: grid;
  grid-template-rows: auto auto 1fr;
  gap: 0.5rem;
}

.kong-nv__num {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.4rem;
  letter-spacing: -0.02em;
  color: var(--kong-lime);
  line-height: 1;
}

.kong-nv__title {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.3rem;
  line-height: 1.15;
  color: var(--kong-surface);
  letter-spacing: -0.01em;
}

.kong-nv__body {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.88rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
}
</style>
