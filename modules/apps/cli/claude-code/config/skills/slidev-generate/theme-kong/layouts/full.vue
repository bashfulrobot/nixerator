<template>
  <KongChrome :category="category" :hide-footer="hideFooter" :bleed="bleed">
    <div class="kong-full" :data-bleed="bleed ? 'true' : 'false'">
      <slot />
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  category: String,
  bleed: { type: Boolean, default: false },
  hideFooter: { type: Boolean, default: false },
});
</script>

<style scoped>
.kong-full {
  width: 100%;
  height: 100%;
  position: relative;
  color: var(--kong-surface);
  overflow: hidden;
}

.kong-full[data-bleed="true"] :slotted(img:only-child) {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.kong-full[data-bleed="false"] {
  padding: 1.6rem 2rem;
}
</style>
