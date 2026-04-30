<template>
  <KongChrome>
    <div class="kong-section">
      <img src="/kong-blades-wide.png" alt="" class="kong-section__blades kong-section__blades--top" />
      <img src="/kong-blades-wide.png" alt="" class="kong-section__blades kong-section__blades--bottom" />

      <div class="kong-section__inner">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <div class="kong-section__body">
          <slot />
        </div>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';
defineProps({ eyebrow: String });
</script>

<style scoped>
.kong-section {
  position: relative;
  width: 100%;
  height: 100%;
  display: grid;
  grid-template-rows: 1fr auto 1fr;
  align-items: center;
  overflow: hidden;
}

.kong-section__blades {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.kong-section__blades--top { object-position: center top; }
.kong-section__blades--bottom { transform: scaleY(-1); }

.kong-section__inner {
  padding: 2rem 4rem;
  background: var(--kong-bg-dark);
  display: grid;
  gap: 0.8rem;
}

.kong-section__body :slotted(h1),
.kong-section__body :slotted(h2) {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 3rem;
  line-height: 1.1;
  letter-spacing: -0.01em;
  margin: 0;
  max-width: 80%;
  color: var(--kong-surface);
}

.kong-section__body :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-section__body :deep(em) {
  font-style: normal;
  color: var(--kong-lime);
}
</style>
