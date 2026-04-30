<template>
  <div class="kong-closing">
    <img src="/kong-logo.png" alt="Kong" class="kong-closing__logo" />
    <div class="kong-closing__hero">
      <slot />
    </div>
    <div class="kong-closing__meta">
      <p v-if="contact" class="kong-closing__contact">{{ contact }}</p>
      <p v-if="url" class="kong-closing__url">{{ url }}</p>
    </div>
  </div>
</template>

<script setup>
defineProps({ contact: String, url: String });
</script>

<style scoped>
.kong-closing {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  background-image:
    radial-gradient(circle at 50% 50%, rgba(204, 255, 0, 0.18), transparent 55%);
  padding: 4rem 5rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 2rem;
}

.kong-closing__logo {
  height: 2.25rem;
  width: auto;
  justify-self: start;
}

.kong-closing__hero {
  align-self: center;
  text-align: center;
}

.kong-closing__hero :slotted(h1) {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 7rem;
  line-height: 1;
  letter-spacing: -0.03em;
  color: var(--kong-lime);
  margin: 0;
}

.kong-closing__hero :slotted(p) {
  margin-top: 1rem;
  color: var(--kong-grey-300);
  font-size: 1.25rem;
}

.kong-closing__meta {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  border-top: 1px solid rgba(204, 255, 0, 0.25);
  padding-top: 1.25rem;
}

.kong-closing__contact,
.kong-closing__url {
  font-family: var(--kong-sans);
  font-weight: 500;
  color: var(--kong-grey-300);
  margin: 0;
}
.kong-closing__url {
  color: var(--kong-lime);
  letter-spacing: 0.06em;
}
</style>
