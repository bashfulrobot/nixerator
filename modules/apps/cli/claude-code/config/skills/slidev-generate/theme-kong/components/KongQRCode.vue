<template>
  <div class="kong-qrcode">
    <QrcodeVue
      :value="value"
      :size="size"
      :level="level"
      :background="background"
      :foreground="foreground"
      render-as="svg"
    />
    <p v-if="caption" class="kong-qrcode__caption">{{ caption }}</p>
  </div>
</template>

<script setup>
import QrcodeVue from 'qrcode.vue';

defineProps({
  value: { type: String, required: true },
  size: { type: Number, default: 240 },
  level: { type: String, default: 'M' },
  background: { type: String, default: '#001408' },
  foreground: { type: String, default: '#CCFF00' },
  caption: String,
});
</script>

<style scoped>
.kong-qrcode {
  display: inline-grid;
  gap: 0.7rem;
  justify-items: center;
  background: var(--kong-bg-olive);
  border: 1px solid rgba(204, 255, 0, 0.25);
  padding: 1rem;
}

.kong-qrcode__caption {
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.8rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
  text-align: center;
}
</style>
