<template>
  <div class="kong-quote">
    <span class="kong-quote__mark">&ldquo;</span>
    <div class="kong-quote__body">
      <slot />
    </div>
    <p v-if="attribution" class="kong-quote__attr">{{ attribution }}</p>
  </div>
</template>

<script setup>
defineProps({ attribution: String });
</script>

<style scoped>
.kong-quote {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 5rem 6rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1.5rem;
}

.kong-quote__mark {
  font-family: var(--kong-display);
  font-size: 8rem;
  line-height: 0.6;
  color: var(--kong-lime);
}

.kong-quote__body :slotted(p),
.kong-quote__body :slotted(blockquote) {
  font-family: var(--kong-display);
  font-weight: 500;
  font-size: 2.6rem;
  line-height: 1.2;
  color: var(--kong-surface);
  letter-spacing: -0.01em;
  margin: 0;
  max-width: 75%;
}

.kong-quote__attr {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 1.05rem;
  color: var(--kong-grey-400);
  letter-spacing: 0.04em;
  margin: 0;
}
</style>
