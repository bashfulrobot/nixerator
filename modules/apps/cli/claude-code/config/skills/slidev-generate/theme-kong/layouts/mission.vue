<template>
  <KongChrome :category="category">
    <div class="kong-mission">
      <p v-if="eyebrow" class="kong-eyebrow kong-mission__eyebrow">{{ eyebrow }}</p>

      <div class="kong-mission__statement">
        <p v-if="statement" class="kong-mission__big" v-html="renderedStatement" />
        <slot v-else />
      </div>

      <div v-if="body || $slots.body" class="kong-mission__body">
        <p v-if="body">{{ body }}</p>
        <slot v-else name="body" />
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import { computed } from 'vue';
import KongChrome from '../components/KongChrome.vue';

const props = defineProps({
  eyebrow: { type: String, default: 'Mission' },
  statement: String,
  body: String,
  category: String,
});

const renderedStatement = computed(() => {
  if (!props.statement) return '';
  return props.statement.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
});
</script>

<style scoped>
.kong-mission {
  width: 100%;
  height: 100%;
  padding: 2.4rem 3rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1.4rem;
  color: var(--kong-surface);
}

.kong-mission__eyebrow {
  margin: 0;
}

.kong-mission__statement {
  align-self: center;
  border-left: 4px solid var(--kong-lime);
  padding-left: 1.8rem;
  max-width: 90%;
}

.kong-mission__big {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.6rem;
  line-height: 1.15;
  letter-spacing: -0.01em;
  color: var(--kong-surface);
  margin: 0;
}

.kong-mission__big :deep(strong) {
  color: var(--kong-lime);
  font-weight: inherit;
}

.kong-mission__statement :slotted(p) {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.6rem;
  line-height: 1.15;
  letter-spacing: -0.01em;
  color: var(--kong-surface);
  margin: 0;
}

.kong-mission__body {
  border-top: 1px solid rgba(204, 255, 0, 0.18);
  padding-top: 1rem;
  max-width: 70%;
}

.kong-mission__body p {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 0.95rem;
  color: var(--kong-grey-300);
  line-height: 1.5;
}
</style>
