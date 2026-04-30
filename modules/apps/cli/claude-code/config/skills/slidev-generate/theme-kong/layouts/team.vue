<template>
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
          <p class="kong-team__name">{{ p.name }}</p>
          <p class="kong-team__title">{{ p.title }}</p>
        </figcaption>
      </figure>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
const props = defineProps({
  title: String,
  eyebrow: String,
  people: { type: Array, default: () => [] }
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
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 2rem;
}

.kong-team__head h2 {
  margin: 0.4rem 0 0;
  font-size: 2.75rem;
}

.kong-team__grid {
  display: grid;
  gap: 2rem 1.5rem;
  align-content: start;
}
.kong-team__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }
.kong-team__grid[data-cols="4"] { grid-template-columns: repeat(4, 1fr); }
.kong-team__grid[data-cols="6"] { grid-template-columns: repeat(6, 1fr); }

.kong-team__photo {
  aspect-ratio: 1 / 1;
  background: var(--kong-bg-olive);
  border: 1px solid rgba(204, 255, 0, 0.2);
  border-radius: 8px;
  overflow: hidden;
}
.kong-team__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  filter: grayscale(0.15) contrast(1.05);
}

.kong-team__name {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 1.05rem;
  margin: 0.6rem 0 0.15rem;
  color: var(--kong-surface);
}
.kong-team__title {
  font-family: var(--kong-sans);
  font-weight: 500;
  font-size: 0.85rem;
  color: var(--kong-grey-400);
  margin: 0;
}
</style>
