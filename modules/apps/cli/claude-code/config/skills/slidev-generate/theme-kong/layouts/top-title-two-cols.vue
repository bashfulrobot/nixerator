<template>
  <div class="kong-ttcols" :data-margin="margin">
    <header class="kong-ttcols__head">
      <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
      <h2 v-if="title">{{ title }}</h2>
    </header>
    <div class="kong-ttcols__grid">
      <div class="kong-ttcols__left">
        <slot name="left" />
      </div>
      <div class="kong-ttcols__right">
        <slot name="right" />
      </div>
    </div>
    <footer v-if="!hideFoot" class="kong-ttcols__foot">
      <img src="/kong-logo.png" alt="" />
    </footer>
  </div>
</template>

<script setup>
defineProps({
  title: String,
  eyebrow: String,
  margin: { type: String, default: 'normal' },
  hideFoot: { type: Boolean, default: false },
});
</script>

<style scoped>
.kong-ttcols {
  width: 100%;
  height: 100%;
  background: var(--kong-bg-dark);
  padding: 3.5rem 5rem 2rem;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 1.5rem;
  color: var(--kong-surface);
}

.kong-ttcols[data-margin="tight"] {
  padding: 2rem 4rem 1.5rem;
  gap: 1.1rem;
}
.kong-ttcols[data-margin="tighter"] {
  padding: 1.25rem 3rem 1rem;
  gap: 0.85rem;
}
.kong-ttcols[data-margin="none"] {
  padding: 0.5rem 1rem;
  gap: 0.5rem;
}

.kong-ttcols__head h2 {
  margin: 0.4rem 0 0;
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 3rem;
  letter-spacing: -0.01em;
  line-height: 1.05;
}

.kong-ttcols__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 3rem;
  align-items: start;
}

.kong-ttcols[data-margin="tight"] .kong-ttcols__grid,
.kong-ttcols[data-margin="tighter"] .kong-ttcols__grid {
  gap: 2rem;
}

.kong-ttcols__left,
.kong-ttcols__right {
  font-size: 1.2rem;
  color: var(--kong-grey-300);
}

.kong-ttcols__foot {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  border-top: 1px solid rgba(204, 255, 0, 0.18);
  padding-top: 0.75rem;
}

.kong-ttcols__foot img {
  height: 1.1rem;
  opacity: 0.85;
}
</style>
