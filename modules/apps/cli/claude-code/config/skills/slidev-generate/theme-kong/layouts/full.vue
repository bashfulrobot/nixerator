<template>
  <div class="kong-full">
    <slot />
  </div>
</template>

<style scoped>
.kong-full {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  position: relative;
  padding: 0;
  color: var(--kong-surface);
  overflow: hidden;
}

/* If the only child is an image, fill the canvas. */
.kong-full :slotted(img:only-child) {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
