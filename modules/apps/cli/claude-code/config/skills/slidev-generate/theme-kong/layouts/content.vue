<template>
  <KongChrome :category="category">
    <div class="kong-content" :data-margin="margin" :data-image="image ? 'true' : 'false'">
      <div class="kong-content__main">
        <header class="kong-content__head">
          <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
          <h2 v-if="title">{{ title }}</h2>
        </header>
        <div class="kong-content__body">
          <slot />
        </div>
      </div>

      <div v-if="image" class="kong-content__media">
        <img :src="image" :alt="imageAlt || ''" />
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
  margin: { type: String, default: 'normal' },
  image: String,
  imageAlt: String,
});
</script>

<style scoped>
.kong-content {
  width: 100%;
  height: 100%;
  padding: 2rem 2.4rem;
  display: grid;
  grid-template-columns: 1fr;
  gap: 2rem;
  color: var(--kong-surface);
}

.kong-content[data-image="true"] {
  grid-template-columns: 1fr 1fr;
}

.kong-content[data-margin="tight"] { padding: 1.5rem 2rem; }
.kong-content[data-margin="tighter"] { padding: 1rem 1.6rem; }
.kong-content[data-margin="none"] { padding: 0.5rem 1rem; }

.kong-content__main {
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
}

.kong-content__head h2 {
  margin: 0.4rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.8rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  color: var(--kong-surface);
}

.kong-content__body {
  font-family: var(--kong-sans);
  font-size: 1.05rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
  align-self: start;
}

.kong-content__body :deep(strong) {
  color: var(--kong-lime);
  font-weight: 600;
}

.kong-content__media {
  align-self: stretch;
  overflow: hidden;
  background: var(--kong-bg-deep);
  display: flex;
  align-items: center;
  justify-content: center;
}

.kong-content__media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
</style>
