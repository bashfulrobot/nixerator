<template>
  <div class="kong-image" :data-position="position">
    <div class="kong-image__text">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <h2 v-if="title">{{ title }}</h2>
      <div class="kong-image__body"><slot /></div>
    </div>
    <div class="kong-image__media">
      <img v-if="src" :src="src" :alt="alt || ''" />
      <slot v-else name="media" />
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: String,
  eyebrow: String,
  src: String,
  alt: String,
  position: { type: String, default: 'right' }
});
</script>

<style scoped>
.kong-image {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 3rem;
  align-items: center;
}

.kong-image[data-position="left"] {
  grid-template-columns: 1fr 1fr;
}
.kong-image[data-position="left"] .kong-image__text { order: 2; }
.kong-image[data-position="left"] .kong-image__media { order: 1; }

.kong-image__text h2 {
  font-size: 2.75rem;
  margin: 0.4rem 0 1.2rem;
}

.kong-image__body {
  font-size: 1.15rem;
  color: var(--kong-grey-300);
  line-height: 1.5;
}

.kong-image__media img {
  width: 100%;
  height: auto;
  border-radius: 12px;
  border: 1px solid rgba(204, 255, 0, 0.2);
}
</style>
