<template>
  <svg
    class="kong-triangle"
    viewBox="0 0 32 32"
    :width="size"
    :height="size"
    aria-hidden="true"
  >
    <!-- A-frame Kong glyph: simplified triangle with center notch. -->
    <path
      d="M16 4 L4 28 L11 28 L13 22 L19 22 L21 28 L28 28 Z M14.6 18 L17.4 18 L16 13.5 Z"
      :fill="color"
    />
  </svg>
</template>

<script setup>
defineProps({
  size: { type: [Number, String], default: 22 },
  color: { type: String, default: '#CCFF00' },
});
</script>

<style scoped>
.kong-triangle { display: block; }
</style>
