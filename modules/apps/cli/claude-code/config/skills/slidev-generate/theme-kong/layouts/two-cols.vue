<template>
  <KongChrome :category="category">
    <div class="kong-cols" :data-margin="margin">
      <header v-if="title || eyebrow" class="kong-cols__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
      </header>
      <div class="kong-cols__grid">
        <div class="kong-cols__left">
          <slot name="left" />
        </div>
        <div class="kong-cols__divider" aria-hidden="true" />
        <div class="kong-cols__right">
          <slot name="right" />
        </div>
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
});
</script>

<style scoped>
.kong-cols {
  width: 100%;
  height: 100%;
  padding: 2rem 2.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.6rem;
  color: var(--kong-surface);
}

.kong-cols[data-margin="tight"]   { padding: 1.5rem 2rem; gap: 1.1rem; }
.kong-cols[data-margin="tighter"] { padding: 1.1rem 1.6rem; gap: 0.85rem; }
.kong-cols[data-margin="none"]    { padding: 0.5rem 1rem; gap: 0.5rem; }

.kong-cols__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  letter-spacing: -0.01em;
  line-height: 1.05;
}

.kong-cols__grid {
  display: grid;
  grid-template-columns: 1fr 1px 1fr;
  gap: 2rem;
  align-items: start;
}

.kong-cols__divider {
  align-self: stretch;
  background: rgba(204, 255, 0, 0.15);
}

.kong-cols__left,
.kong-cols__right {
  font-family: var(--kong-sans);
  font-size: 1rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
}

.kong-cols__left :deep(strong),
.kong-cols__right :deep(strong) {
  color: var(--kong-lime);
  font-weight: 600;
}
</style>
