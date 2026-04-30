<template>
  <div class="kong-stats">
    <header v-if="title || eyebrow" class="kong-stats__head">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <h2 v-if="title">{{ title }}</h2>
    </header>
    <div class="kong-stats__grid" :data-cols="items.length">
      <div v-for="(item, i) in items" :key="i" class="kong-stats__cell">
        <p class="kong-stats__num">{{ item.value }}</p>
        <p class="kong-stats__label">{{ item.label }}</p>
        <p v-if="item.note" class="kong-stats__note">{{ item.note }}</p>
      </div>
    </div>
    <p v-if="footer" class="kong-stats__footer">{{ footer }}</p>
  </div>
</template>

<script setup>
defineProps({
  title: String,
  eyebrow: String,
  footer: String,
  items: { type: Array, default: () => [] }
});
</script>

<style scoped>
.kong-stats {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 2rem;
  color: var(--kong-surface);
}

.kong-stats__head h2 {
  margin: 0.4rem 0 0;
  font-size: 2.75rem;
}

.kong-stats__grid {
  display: grid;
  gap: 2.5rem 3rem;
  align-content: center;
  align-items: start;
}

.kong-stats__grid[data-cols="1"] { grid-template-columns: 1fr; }
.kong-stats__grid[data-cols="2"] { grid-template-columns: repeat(2, 1fr); }
.kong-stats__grid[data-cols="3"] { grid-template-columns: repeat(3, 1fr); }
.kong-stats__grid[data-cols="4"] { grid-template-columns: repeat(2, 1fr); }
.kong-stats__grid[data-cols="5"],
.kong-stats__grid[data-cols="6"] { grid-template-columns: repeat(3, 1fr); }

.kong-stats__num {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 5rem;
  line-height: 1;
  color: var(--kong-lime);
  letter-spacing: -0.04em;
  margin: 0 0 0.5rem;
}

.kong-stats__label {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.9rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--kong-grey-400);
  margin: 0;
}

.kong-stats__note {
  margin-top: 0.6rem;
  font-size: 0.95rem;
  color: var(--kong-grey-300);
}

.kong-stats__footer {
  font-size: 1rem;
  color: var(--kong-grey-400);
  border-top: 1px solid rgba(204, 255, 0, 0.18);
  padding-top: 1rem;
  margin: 0;
}
</style>
