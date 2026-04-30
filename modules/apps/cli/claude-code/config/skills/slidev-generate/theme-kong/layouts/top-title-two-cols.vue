<template>
  <KongChrome :category="category">
    <div class="kong-ttcols" :data-margin="margin">
      <header class="kong-ttcols__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
        <p v-if="intro" class="kong-ttcols__intro">{{ intro }}</p>
      </header>
      <div class="kong-ttcols__grid">
        <div class="kong-ttcols__left">
          <slot name="left" />
        </div>
        <div class="kong-ttcols__divider" aria-hidden="true" />
        <div class="kong-ttcols__right">
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
  intro: String,
  category: String,
  margin: { type: String, default: 'normal' },
});
</script>

<style scoped>
.kong-ttcols {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-ttcols[data-margin="tight"]   { padding: 1.4rem 2rem; gap: 1rem; }
.kong-ttcols[data-margin="tighter"] { padding: 1rem 1.6rem; gap: 0.8rem; }
.kong-ttcols[data-margin="none"]    { padding: 0.5rem 1rem; gap: 0.5rem; }

.kong-ttcols__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  letter-spacing: -0.01em;
  line-height: 1.05;
  max-width: 80%;
}

.kong-ttcols__intro {
  margin: 0.6rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  max-width: 75%;
}

.kong-ttcols__grid {
  display: grid;
  grid-template-columns: 1fr 1px 1fr;
  gap: 1.8rem;
  align-items: start;
  align-self: stretch;
}

.kong-ttcols__divider {
  align-self: stretch;
  background: rgba(204, 255, 0, 0.15);
}

.kong-ttcols__left,
.kong-ttcols__right {
  font-family: var(--kong-sans);
  font-size: 1rem;
  line-height: 1.5;
  color: var(--kong-grey-300);
}

.kong-ttcols__left :deep(strong),
.kong-ttcols__right :deep(strong) {
  color: var(--kong-lime);
  font-weight: 600;
}
</style>
