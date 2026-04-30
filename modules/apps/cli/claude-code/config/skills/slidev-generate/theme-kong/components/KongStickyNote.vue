<template>
  <aside v-if="visible" class="kong-stickynote" :style="rootStyle" :data-dev="devOnly ? 'true' : 'false'">
    <p v-if="title" class="kong-stickynote__title">{{ title }}</p>
    <div class="kong-stickynote__body"><slot /></div>
    <p v-if="devOnly" class="kong-stickynote__dev">DEV ONLY</p>
  </aside>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  title: String,
  width: { type: String, default: '240px' },
  devOnly: { type: Boolean, default: false },
});

const visible = computed(() => !props.devOnly || import.meta.env.DEV);
const rootStyle = computed(() => ({ width: props.width }));
</script>

<style scoped>
.kong-stickynote {
  background: var(--kong-bg-olive);
  border: 1px solid rgba(204, 255, 0, 0.4);
  padding: 0.85rem 1rem;
  display: grid;
  gap: 0.4rem;
  font-family: var(--kong-sans);
  color: var(--kong-grey-300);
  font-size: 0.95rem;
  line-height: 1.4;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.45);
}

.kong-stickynote[data-dev="true"] {
  border-style: dashed;
  border-color: var(--kong-coral);
}

.kong-stickynote__title {
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.78rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-stickynote__body { margin: 0; }
.kong-stickynote__body :deep(p) { margin: 0; }
.kong-stickynote__body :deep(p + p) { margin-top: 0.4rem; }

.kong-stickynote__dev {
  margin: 0;
  font-family: var(--kong-mono);
  font-size: 0.7rem;
  letter-spacing: 0.22em;
  color: var(--kong-coral);
  text-transform: uppercase;
  opacity: 0.85;
}
</style>
