<template>
  <div class="kong-box" :data-tone="tone">
    <span v-if="label" class="kong-box__label">{{ label }}</span>
    <div class="kong-box__body"><slot /></div>
  </div>
</template>

<script setup>
defineProps({
  label: String,
  tone: { type: String, default: 'lime' },
});
</script>

<style scoped>
.kong-box {
  width: 100%;
  height: 100%;
  border: 2px solid var(--kong-lime);
  background: rgba(204, 255, 0, 0.05);
  position: relative;
  pointer-events: none;
}

.kong-box[data-tone="warn"] {
  border-color: var(--kong-coral);
  background: rgba(228, 105, 98, 0.08);
}

.kong-box[data-tone="muted"] {
  border-color: var(--kong-grey-500);
  background: rgba(170, 180, 187, 0.05);
}

.kong-box__label {
  position: absolute;
  top: -0.95rem;
  left: 0.6rem;
  background: var(--kong-bg-dark);
  padding: 0 0.55rem;
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.78rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-box[data-tone="warn"] .kong-box__label { color: var(--kong-coral); }
.kong-box[data-tone="muted"] .kong-box__label { color: var(--kong-grey-300); }

.kong-box__body {
  font-family: var(--kong-sans);
  color: var(--kong-grey-300);
  padding: 1rem;
  pointer-events: auto;
  height: 100%;
  box-sizing: border-box;
}
</style>
