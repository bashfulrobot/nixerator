<template>
  <KongChrome>
    <div class="kong-cover">
      <img src="/kong-blades-tall.png" alt="" class="kong-cover__blades" />

      <header class="kong-cover__head">
        <img src="/kong-logo.png" alt="Kong" />
      </header>

      <div class="kong-cover__title-box">
        <slot />
      </div>

      <div class="kong-cover__subtitle" v-if="product || tagline">
        <p v-if="product" class="kong-cover__product">
          <span class="kong-cover__product-mark">Kong</span>
          {{ product }}
        </p>
        <p v-if="tagline" class="kong-cover__tagline">{{ tagline }}</p>
      </div>

      <div class="kong-cover__meta" v-if="date || speaker">
        <span v-if="date" class="kong-cover__date">{{ date }}</span>
        <span v-if="speaker" class="kong-cover__speaker">{{ speaker }}</span>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  product: String,
  tagline: String,
  date: String,
  speaker: String,
});
</script>

<style scoped>
.kong-cover {
  position: relative;
  width: 100%;
  height: 100%;
  padding: 1.4rem 2rem 1.6rem;
  display: grid;
  grid-template-rows: auto 1fr auto auto;
  gap: 1rem;
}

.kong-cover__blades {
  position: absolute;
  right: 0;
  top: 0;
  height: 100%;
  width: 55%;
  object-fit: cover;
  object-position: left center;
  z-index: 0;
}

.kong-cover__head {
  z-index: 2;
}

.kong-cover__head img {
  height: 1.95rem;
  width: auto;
}

.kong-cover__title-box {
  align-self: center;
  z-index: 2;
  max-width: 65%;
}

.kong-cover__title-box :slotted(h1) {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 5.2rem;
  line-height: 1.18;
  letter-spacing: -0.02em;
  margin: 0;
  color: var(--kong-surface);
  background: var(--kong-bg-dark);
  display: inline;
  box-decoration-break: clone;
  -webkit-box-decoration-break: clone;
  padding: 0.02em 0.35em 0.1em;
}

.kong-cover__subtitle {
  z-index: 2;
  background: var(--kong-bg-dark);
  display: inline-block;
  align-self: end;
  padding: 0.4rem 0.7rem;
  width: fit-content;
  max-width: 60%;
}

.kong-cover__product {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 1.4rem;
  font-weight: 600;
  color: var(--kong-surface);
}

.kong-cover__product-mark {
  color: var(--kong-lime);
  font-weight: 700;
}

.kong-cover__tagline {
  margin: 0.2rem 0 0;
  font-family: var(--kong-sans);
  font-size: 1rem;
  font-weight: 500;
  color: var(--kong-surface);
}

.kong-cover__meta {
  z-index: 2;
  display: inline-flex;
  align-items: center;
  gap: 1.4rem;
  background: var(--kong-bg-dark);
  padding: 0.4rem 0.7rem;
  align-self: end;
  width: fit-content;
}

.kong-cover__date {
  background: var(--kong-lime);
  color: var(--kong-bg-dark);
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.85rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  padding: 0.4rem 0.85rem;
}

.kong-cover__speaker {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--kong-surface);
}
</style>
