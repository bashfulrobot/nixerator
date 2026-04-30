<template>
  <KongChrome :category="category">
    <div class="kong-agenda">
      <header class="kong-agenda__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2>{{ title || 'Agenda' }}</h2>
        <p v-if="date" class="kong-agenda__date">{{ date }}</p>
      </header>

      <ol class="kong-agenda__list" :data-cols="cols">
        <li
          v-for="(item, i) in items"
          :key="i"
          class="kong-agenda__item"
        >
          <span class="kong-agenda__num">{{ String(i + 1).padStart(2, '0') }}</span>
          <div class="kong-agenda__detail">
            <p class="kong-agenda__title">{{ typeof item === 'string' ? item : item.title }}</p>
            <p
              v-if="typeof item !== 'string' && item.note"
              class="kong-agenda__note"
            >{{ item.note }}</p>
          </div>
        </li>
      </ol>

      <img
        v-if="!hideOrbit"
        src="/kong-blades-orbit.png"
        alt=""
        class="kong-agenda__orbit"
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
  date: String,
  category: String,
  hideOrbit: { type: Boolean, default: false },
  items: { type: Array, default: () => [] },
});

const cols = computed(() => {
  const n = props.items.length;
  if (n <= 2) return 1;
  if (n <= 4) return 2;
  return 2;
});
</script>

<style scoped>
.kong-agenda {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
  position: relative;
  overflow: hidden;
}

.kong-agenda__orbit {
  position: absolute;
  right: -6rem;
  bottom: -6rem;
  width: 22rem;
  opacity: 0.45;
  pointer-events: none;
}

.kong-agenda__head {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: end;
  gap: 1rem;
  border-bottom: 1px solid rgba(204, 255, 0, 0.18);
  padding-bottom: 1rem;
}

.kong-agenda__head h2 {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.6rem;
  letter-spacing: -0.01em;
  margin: 0.3rem 0 0;
  grid-column: 1;
}

.kong-agenda__date {
  grid-column: 2;
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.78rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--kong-bg-dark);
  background: var(--kong-lime);
  padding: 0.45rem 0.8rem;
  align-self: end;
}

.kong-agenda__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 1.1rem 2rem;
  align-content: start;
  position: relative;
  z-index: 1;
}

.kong-agenda__list[data-cols="1"] { grid-template-columns: 1fr; }
.kong-agenda__list[data-cols="2"] { grid-template-columns: 1fr 1fr; }

.kong-agenda__item {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 1rem;
  align-items: start;
  padding: 0.6rem 0;
  border-top: 1px solid rgba(204, 255, 0, 0.1);
}

.kong-agenda__item:first-child,
.kong-agenda__list[data-cols="2"] .kong-agenda__item:nth-child(2) {
  border-top: none;
}

.kong-agenda__num {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2rem;
  line-height: 1;
  color: var(--kong-lime);
  letter-spacing: -0.02em;
  min-width: 2.6rem;
}

.kong-agenda__detail { padding-top: 0.2rem; }

.kong-agenda__title {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.15rem;
  margin: 0;
  color: var(--kong-surface);
  line-height: 1.2;
}

.kong-agenda__note {
  margin: 0.25rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  color: var(--kong-grey-400);
  line-height: 1.4;
}

.kong-agenda__list ul li::before { display: none; }
</style>
