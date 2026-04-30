<template>
  <div class="kong-section">
    <p v-if="$slidev.configs.eyebrow || eyebrow" class="kong-eyebrow">{{ eyebrow || $slidev.configs.eyebrow }}</p>
    <div class="kong-rule" />
    <div class="kong-section__body">
      <slot />
    </div>
  </div>
</template>

<script setup>
defineProps({ eyebrow: String });
</script>

<style scoped>
.kong-section {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  background-image:
    linear-gradient(135deg, rgba(204, 255, 0, 0.04) 0%, transparent 60%),
    radial-gradient(circle at 100% 100%, rgba(204, 255, 0, 0.18), transparent 55%);
  padding: 6rem 6rem;
  display: grid;
  grid-template-rows: auto auto 1fr;
  gap: 1rem;
  align-content: center;
}

.kong-section__body :slotted(h1),
.kong-section__body :slotted(h2) {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 4.75rem;
  line-height: 1.04;
  letter-spacing: -0.02em;
  margin: 0;
  max-width: 70%;
}

.kong-section__body :slotted(h1) :deep(em),
.kong-section__body :slotted(h2) :deep(em),
.kong-section__body :slotted(em) {
  color: var(--kong-lime);
  font-style: normal;
}
</style>
