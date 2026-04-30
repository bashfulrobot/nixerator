<template>
  <KongChrome :category="category">
    <div class="kong-team">
      <header class="kong-team__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2>{{ title || 'Meet the team' }}</h2>
      </header>
      <div class="kong-team__grid" :data-cols="cols">
        <figure v-for="(p, i) in people" :key="i" class="kong-team__cell">
          <div class="kong-team__photo">
            <img v-if="p.image" :src="p.image" :alt="p.name" />
          </div>
          <figcaption>
            <p class="kong-team__title-line">{{ p.title }}</p>
            <p class="kong-team__name">{{ p.name }}</p>
          </figcaption>
        </figure>
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
  category: String,
  people: { type: Array, default: () => [] },
});
const cols = computed(() => {
  const n = props.people.length;
  if (n <= 3) return 3;
  if (n <= 4) return 4;
  return 6;
});
</script>

<style scoped>
.kong-team {
  width: 100%;
  height: 100%;
  padding: 1.6rem 2rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-team__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  letter-spacing: -0.01em;
}

.kong-team__grid {
  display: grid;
  gap: 1.4rem 1.2rem;
  align-content: start;
}
.kong-team__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }
.kong-team__grid[data-cols="4"] { grid-template-columns: repeat(4, 1fr); }
.kong-team__grid[data-cols="6"] { grid-template-columns: repeat(6, 1fr); }

.kong-team__photo {
  aspect-ratio: 1 / 1;
  background: var(--kong-bg-deep);
  border: 1px solid rgba(204, 255, 0, 0.15);
  overflow: hidden;
}
.kong-team__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  filter: grayscale(0.1) contrast(1.05);
}

.kong-team__title-line {
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.7rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--kong-lime);
  margin: 0.5rem 0 0.1rem;
}
.kong-team__name {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 0.95rem;
  margin: 0;
  color: var(--kong-surface);
}
</style>
