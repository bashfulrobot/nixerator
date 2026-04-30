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
  overflow: hidden;
  background: var(--kong-bg-deep);
}

.kong-section__blades {
  position: absolute;
  left: 0;
  width: 100%;
  height: 32%;
  object-fit: cover;
  display: block;
  z-index: 0;
}

.kong-section__blades--top {
  top: 0;
  object-position: center top;
}

.kong-section__blades--bottom {
  bottom: 0;
  transform: scaleY(-1);
  object-position: center top;
}

.kong-section__inner {
  position: absolute;
  top: 32%;
  bottom: 32%;
  left: 0;
  right: 0;
  background: var(--kong-bg-dark);
  padding: 2rem 4rem;
  display: grid;
  align-content: center;
  gap: 0.8rem;
  z-index: 1;
}

.kong-section__body :slotted(h1),
.kong-section__body :slotted(h2) {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 3rem;
  line-height: 1.15;
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
