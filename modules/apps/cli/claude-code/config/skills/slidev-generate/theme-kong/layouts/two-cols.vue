<template>
  <div class="kong-cols" :data-margin="margin">
    <header class="kong-cols__head">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <h2 v-if="title">{{ title }}</h2>
    </header>
    <div class="kong-cols__grid">
      <div class="kong-cols__left">
        <slot name="left" />
      </div>
      <div class="kong-cols__right">
        <slot name="right" />
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: String,
  eyebrow: String,
  margin: { type: String, default: 'normal' },
});
</script>

<style scoped>
.kong-cols {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 2rem;
  color: var(--kong-surface);
}

.kong-cols[data-margin="tight"] {
  padding: 2rem 4rem;
  gap: 1.5rem;
}
.kong-cols[data-margin="tighter"] {
  padding: 1.25rem 3rem;
  gap: 1rem;
}
.kong-cols[data-margin="none"] {
  padding: 0.5rem 1rem;
  gap: 0.5rem;
}

.kong-cols__head h2 {
  margin: 0.4rem 0 0;
  font-size: 3rem;
}

.kong-cols__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 3rem;
  align-items: start;
}

.kong-cols__left,
.kong-cols__right {
  font-size: 1.2rem;
  color: var(--kong-grey-300);
}
</style>
