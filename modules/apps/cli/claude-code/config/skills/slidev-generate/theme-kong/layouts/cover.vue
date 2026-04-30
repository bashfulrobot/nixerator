<template>
  <div class="kong-cover">
    <img src="/kong-logo.png" alt="Kong" class="kong-cover__logo" />
    <div class="kong-cover__body">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <slot />
      <p v-if="tagline" class="kong-cover__tagline">{{ tagline }}</p>
    </div>
    <div class="kong-cover__meta">
      <p v-if="speaker" class="kong-cover__speaker">{{ speaker }}</p>
      <p v-if="date" class="kong-cover__date">{{ date }}</p>
    </div>
  </div>
</template>

<script setup>
defineProps({
  eyebrow: String,
  tagline: String,
  speaker: String,
  date: String
});
</script>

<style scoped>
.kong-cover {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  background-image:
    radial-gradient(circle at 85% 110%, rgba(204, 255, 0, 0.18), transparent 55%),
    radial-gradient(circle at 0% -10%, rgba(204, 255, 0, 0.08), transparent 50%);
  padding: 4rem 5rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 2rem;
  color: var(--kong-surface);
}

.kong-cover__logo {
  height: 2.25rem;
  width: auto;
}

.kong-cover__body {
  align-self: center;
  max-width: 60rem;
}

.kong-cover__body :slotted(h1) {
  font-family: var(--kong-display);
  font-size: 5.25rem;
  font-weight: 700;
  line-height: 1.02;
  letter-spacing: -0.02em;
  color: var(--kong-surface);
  margin: 0.75rem 0 0;
}

.kong-cover__tagline {
  margin-top: 1.75rem;
  font-size: 1.4rem;
  color: var(--kong-grey-300);
  max-width: 44rem;
}

.kong-cover__meta {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  border-top: 1px solid rgba(204, 255, 0, 0.25);
  padding-top: 1.5rem;
}

.kong-cover__speaker {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 1.05rem;
  color: var(--kong-surface);
  margin: 0;
}

.kong-cover__date {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.95rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--kong-lime);
  margin: 0;
}
</style>
