<template>
  <KongChrome :category="category">
    <div class="kong-image" :data-position="position">
      <div class="kong-image__text">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
        <div class="kong-image__body"><slot /></div>
      </div>
      <div class="kong-image__media">
        <img v-if="src" :src="src" :alt="alt || ''" />
        <slot v-else name="media" />
        <p v-if="caption" class="kong-image__caption">{{ caption }}</p>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  title: String,
  eyebrow: String,
  category: String,
  src: String,
  alt: String,
  caption: String,
  position: { type: String, default: 'right' },
});
</script>

<style scoped>
.kong-image {
  width: 100%;
  height: 100%;
  padding: 2rem 2.4rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  align-items: center;
  color: var(--kong-surface);
}

.kong-image[data-position="left"] .kong-image__text  { order: 2; }
.kong-image[data-position="left"] .kong-image__media { order: 1; }

.kong-image__text h2 {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  margin: 0.4rem 0 1rem;
  color: var(--kong-surface);
}

.kong-image__body {
  font-family: var(--kong-sans);
  font-size: 1rem;
  color: var(--kong-grey-300);
  line-height: 1.5;
}

.kong-image__body :deep(strong) {
  color: var(--kong-lime);
  font-weight: 600;
}

.kong-image__media {
  align-self: stretch;
  display: grid;
  grid-template-rows: 1fr auto;
  gap: 0.5rem;
  background: var(--kong-bg-deep);
  border: 1px solid rgba(204, 255, 0, 0.15);
  overflow: hidden;
}

.kong-image__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.kong-image__caption {
  font-family: var(--kong-sans);
  font-size: 0.78rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--kong-lime);
  margin: 0;
  padding: 0.5rem 0.8rem;
  border-top: 1px solid rgba(204, 255, 0, 0.15);
}
</style>
