<template>
  <div class="kong-content" :data-margin="margin">
    <header class="kong-content__head">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <h2 v-if="title">{{ title }}</h2>
    </header>
    <div class="kong-content__body">
      <slot />
    </div>
    <footer class="kong-content__foot">
      <img src="/kong-logo.png" alt="" />
    </footer>
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
.kong-content {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem 2rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1.5rem;
  color: var(--kong-surface);
}

.kong-content[data-margin="tight"] {
  padding: 2rem 4rem 1.5rem;
  gap: 1.1rem;
}
.kong-content[data-margin="tighter"] {
  padding: 1.25rem 3rem 1rem;
  gap: 0.85rem;
}
.kong-content[data-margin="none"] {
  padding: 0.5rem 1rem;
  gap: 0.5rem;
}

.kong-content__head h2 {
  margin: 0.4rem 0 0;
  font-size: 3.25rem;
}

.kong-content__body {
  font-size: 1.25rem;
  color: var(--kong-grey-300);
}

.kong-content__foot {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  border-top: 1px solid rgba(204, 255, 0, 0.18);
  padding-top: 0.75rem;
}

.kong-content__foot img {
  height: 1.1rem;
  opacity: 0.85;
}
</style>
