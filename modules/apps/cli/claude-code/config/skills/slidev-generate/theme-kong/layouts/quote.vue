<template>
  <KongChrome :category="category">
    <div class="kong-quote">
      <span class="kong-quote__mark" aria-hidden="true">&ldquo;</span>
      <div class="kong-quote__body">
        <slot />
      </div>
      <footer v-if="attribution || role" class="kong-quote__foot">
        <p v-if="attribution" class="kong-quote__attr">{{ attribution }}</p>
        <p v-if="role" class="kong-quote__role">{{ role }}</p>
      </footer>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';
defineProps({
  attribution: String,
  role: String,
  category: String,
});
</script>

<style scoped>
.kong-quote {
  width: 100%;
  height: 100%;
  padding: 2.4rem 3rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1rem;
  color: var(--kong-surface);
  position: relative;
}

.kong-quote__mark {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 9rem;
  line-height: 0.6;
  color: var(--kong-lime);
  margin: 0;
  user-select: none;
}

.kong-quote__body {
  align-self: center;
  max-width: 78%;
}

.kong-quote__body :slotted(p),
.kong-quote__body :slotted(blockquote) {
  font-family: var(--kong-display);
  font-weight: 500;
  font-size: 2.4rem;
  line-height: 1.2;
  color: var(--kong-surface);
  letter-spacing: -0.01em;
  margin: 0;
}

.kong-quote__body :slotted(strong),
.kong-quote__body :slotted(em) {
  color: var(--kong-lime);
  font-style: normal;
  font-weight: inherit;
}

.kong-quote__foot {
  border-top: 1px solid rgba(204, 255, 0, 0.18);
  padding-top: 0.8rem;
  display: flex;
  align-items: baseline;
  gap: 1rem;
}

.kong-quote__attr {
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.95rem;
  color: var(--kong-surface);
  margin: 0;
}

.kong-quote__role {
  font-family: var(--kong-sans);
  font-size: 0.85rem;
  color: var(--kong-grey-400);
  margin: 0;
}
</style>
