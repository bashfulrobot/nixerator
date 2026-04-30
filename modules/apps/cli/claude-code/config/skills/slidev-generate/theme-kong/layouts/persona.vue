<template>
  <KongChrome :category="category">
    <div class="kong-persona">
      <header class="kong-persona__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2>{{ title || name || 'Persona' }}</h2>
        <p v-if="title && name" class="kong-persona__name">{{ name }}</p>
      </header>

      <div class="kong-persona__grid">
        <aside v-if="image || quote" class="kong-persona__profile">
          <div v-if="image" class="kong-persona__photo">
            <img :src="image" :alt="name || ''" />
          </div>
          <p v-if="quote" class="kong-persona__quote">{{ quote }}</p>
        </aside>

        <div class="kong-persona__body">
          <section v-if="demographics?.length" class="kong-persona__block">
            <p class="kong-persona__label">Demographics</p>
            <ul>
              <li v-for="(d, i) in demographics" :key="`d-${i}`">{{ d }}</li>
            </ul>
          </section>

          <section v-if="needs?.length" class="kong-persona__block">
            <p class="kong-persona__label">Needs &amp; goals</p>
            <ul>
              <li v-for="(d, i) in needs" :key="`n-${i}`">{{ d }}</li>
            </ul>
          </section>

          <section v-if="channels?.length" class="kong-persona__block">
            <p class="kong-persona__label">Channels</p>
            <ul>
              <li v-for="(d, i) in channels" :key="`c-${i}`">{{ d }}</li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  title: String,
  name: String,
  eyebrow: String,
  category: String,
  image: String,
  quote: String,
  demographics: { type: Array, default: () => [] },
  needs: { type: Array, default: () => [] },
  channels: { type: Array, default: () => [] },
});
</script>

<style scoped>
.kong-persona {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-persona__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  letter-spacing: -0.01em;
  line-height: 1.05;
}

.kong-persona__name {
  margin: 0.3rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
}

.kong-persona__grid {
  display: grid;
  grid-template-columns: minmax(0, 0.85fr) 1.2fr;
  gap: 1.4rem;
  align-items: start;
}

.kong-persona__profile {
  background: var(--kong-bg-dark);
  border-top: 3px solid var(--kong-lime);
  padding: 1rem;
  display: grid;
  gap: 0.8rem;
}

.kong-persona__photo {
  aspect-ratio: 1 / 1;
  background: var(--kong-bg-deep);
  overflow: hidden;
  border: 1px solid rgba(204, 255, 0, 0.15);
}

.kong-persona__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.kong-persona__quote {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 500;
  font-size: 1rem;
  line-height: 1.3;
  color: var(--kong-lime);
  letter-spacing: -0.005em;
  border-left: 2px solid var(--kong-lime);
  padding-left: 0.7rem;
}

.kong-persona__body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem 1.4rem;
  align-content: start;
}

.kong-persona__block {
  background: var(--kong-bg-dark);
  padding: 0.9rem 1.1rem;
  border-left: 2px solid var(--kong-lime);
}

.kong-persona__block:nth-child(3) {
  grid-column: 1 / -1;
}

.kong-persona__label {
  margin: 0 0 0.4rem;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.7rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-persona__block ul {
  margin: 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: 0.25rem;
}

.kong-persona__block li {
  position: relative;
  padding-left: 0.9rem;
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  line-height: 1.4;
  color: var(--kong-grey-300);
  margin: 0;
}

.kong-persona__block li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.55em;
  width: 0.4em;
  height: 0.4em;
  background: var(--kong-lime);
}
</style>
