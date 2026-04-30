<template>
  <KongChrome :category="category">
    <div class="kong-mosaic">
      <header v-if="title || eyebrow" class="kong-mosaic__head">
        <p v-if="eyebrow" class="kong-eyebrow">{{ eyebrow }}</p>
        <h2 v-if="title">{{ title }}</h2>
      </header>

      <div class="kong-mosaic__grid">
        <div v-if="award" class="kong-mosaic__cell kong-mosaic__cell--award">
          <p class="kong-mosaic__label">{{ award.label || 'Recognition' }}</p>
          <p class="kong-mosaic__award-name">{{ award.name }}</p>
          <p v-if="award.note" class="kong-mosaic__note">{{ award.note }}</p>
        </div>

        <div v-if="share" class="kong-mosaic__cell kong-mosaic__cell--share">
          <p class="kong-mosaic__label">{{ share.label || 'Market share' }}</p>
          <p class="kong-mosaic__share-num">{{ share.value }}</p>
          <p v-if="share.note" class="kong-mosaic__note">{{ share.note }}</p>
        </div>

        <div v-if="quote" class="kong-mosaic__cell kong-mosaic__cell--quote">
          <span class="kong-mosaic__qmark" aria-hidden="true">&ldquo;</span>
          <p class="kong-mosaic__quote-body">{{ quote.body }}</p>
          <p v-if="quote.attribution" class="kong-mosaic__quote-attr">{{ quote.attribution }}</p>
        </div>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';

defineProps({
  title: String,
  eyebrow: String,
  category: String,
  award: Object,
  share: Object,
  quote: Object,
});
</script>

<style scoped>
.kong-mosaic {
  width: 100%;
  height: 100%;
  padding: 1.8rem 2.4rem 1.4rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1.2rem;
  color: var(--kong-surface);
}

.kong-mosaic__head h2 {
  margin: 0.3rem 0 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.4rem;
  line-height: 1.05;
  letter-spacing: -0.01em;
  max-width: 80%;
}

.kong-mosaic__grid {
  display: grid;
  gap: 4px;
  background: rgba(204, 255, 0, 0.08);
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  grid-template-areas:
    "award quote"
    "share quote";
  align-items: stretch;
}

.kong-mosaic__cell {
  background: var(--kong-bg-dark);
  padding: 1.2rem 1.4rem;
  display: grid;
  align-content: center;
  gap: 0.5rem;
  position: relative;
  overflow: hidden;
}

.kong-mosaic__cell--award { grid-area: award; }
.kong-mosaic__cell--share { grid-area: share; }
.kong-mosaic__cell--quote {
  grid-area: quote;
  background: var(--kong-bg-deep);
  align-content: start;
  padding-top: 0.7rem;
}

.kong-mosaic__cell--share::after {
  content: '';
  position: absolute;
  right: -20%;
  top: -40%;
  width: 70%;
  height: 130%;
  background: radial-gradient(closest-side, rgba(204, 255, 0, 0.18), transparent 70%);
  pointer-events: none;
}

.kong-mosaic__label {
  position: relative;
  margin: 0;
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.72rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-mosaic__award-name {
  position: relative;
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.4rem;
  line-height: 1.15;
  color: var(--kong-surface);
}

.kong-mosaic__share-num {
  position: relative;
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 4rem;
  line-height: 0.95;
  color: var(--kong-lime);
  letter-spacing: -0.04em;
}

.kong-mosaic__note {
  position: relative;
  margin: 0.2rem 0 0;
  font-family: var(--kong-sans);
  font-size: 0.82rem;
  color: var(--kong-grey-300);
  line-height: 1.4;
}

.kong-mosaic__qmark {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 4rem;
  line-height: 0.6;
  color: var(--kong-lime);
  margin-bottom: 0.5rem;
}

.kong-mosaic__quote-body {
  margin: 0;
  font-family: var(--kong-display);
  font-weight: 500;
  font-size: 1.2rem;
  line-height: 1.3;
  color: var(--kong-surface);
  letter-spacing: -0.005em;
}

.kong-mosaic__quote-attr {
  margin-top: auto;
  padding-top: 0.8rem;
  border-top: 1px solid rgba(204, 255, 0, 0.15);
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.8rem;
  color: var(--kong-grey-300);
}
</style>
