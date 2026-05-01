<template>
  <KongChrome>
    <div class="kong-closing">
      <header class="kong-closing__head">
        <div class="kong-closing__head-left">
          <h1>Thank you!</h1>
        </div>
        <div class="kong-closing__head-cta">
          <p v-if="cta" class="kong-closing__cta">{{ cta }}</p>
          <p v-if="ctaSub" class="kong-closing__cta-sub">{{ ctaSub }}</p>
        </div>
        <div class="kong-closing__head-contact">
          <p class="kong-closing__name">{{ company || 'Kong Inc.' }}</p>
          <p v-if="contact" class="kong-closing__contact">
            <a :href="`mailto:${contact}`">{{ contact }}</a>
          </p>
          <p v-if="address" class="kong-closing__address" v-html="address" />
          <p v-if="url" class="kong-closing__url">
            <a :href="`https://${url.replace(/^https?:\/\//, '')}`">{{ url }}</a>
          </p>
        </div>
      </header>

      <div class="kong-closing__hero">
        <span class="kong-closing__word">Kong</span>
      </div>
    </div>
  </KongChrome>
</template>

<script setup>
import KongChrome from '../components/KongChrome.vue';
defineProps({
  cta: { type: String, default: "Ready for what's next?" },
  ctaSub: { type: String, default: "Let's talk" },
  company: String,
  contact: String,
  address: String,
  url: String,
});
</script>

<style scoped>
.kong-closing {
  width: 100%;
  height: 100%;
  padding: 1.4rem 1.6rem 1.2rem;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 0.6rem;
}

.kong-closing__head {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 1.2rem;
  align-items: start;
  border-bottom: 1px solid rgba(204, 255, 0, 0.18);
  padding-bottom: 1rem;
}

.kong-closing__head h1 {
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 2.6rem;
  margin: 0;
  letter-spacing: -0.01em;
  color: var(--kong-surface);
}

.kong-closing__cta {
  margin: 0.5rem 0 0.1rem;
  font-family: var(--kong-display);
  font-weight: 600;
  font-size: 1.4rem;
  color: var(--kong-lime);
}
.kong-closing__cta-sub {
  margin: 0;
  font-family: var(--kong-sans);
  font-size: 1rem;
  color: var(--kong-grey-300);
}

.kong-closing__head-contact {
  font-family: var(--kong-sans);
  font-size: 0.9rem;
  color: var(--kong-grey-300);
}

.kong-closing__name {
  margin: 0;
  font-weight: 700;
  color: var(--kong-surface);
  font-size: 1rem;
}

.kong-closing__contact { margin: 0.3rem 0 0.2rem; }
.kong-closing__contact a {
  color: var(--kong-lime);
  border-bottom: 1px solid var(--kong-lime);
  text-decoration: none;
}

.kong-closing__address {
  margin: 0.2rem 0 0.4rem;
  line-height: 1.4;
}

.kong-closing__url { margin: 0; }
.kong-closing__url a { color: var(--kong-lime); text-decoration: underline; }

.kong-closing__hero {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background-image: radial-gradient(circle at 50% 50%, rgba(255, 255, 255, 0.04) 1px, transparent 1.5px);
  background-size: 8px 8px;
}

.kong-closing__word {
  font-family: var(--kong-display);
  font-weight: 700;
  font-size: 19rem;
  line-height: 1;
  letter-spacing: -0.04em;
  color: var(--kong-lime);
  white-space: nowrap;
  padding-bottom: 0.05em;
}
</style>
