<template>
  <div class="kong-frame">
    <!-- Corner registration crosses -->
    <span class="kong-cross kong-cross--tl" aria-hidden="true">+</span>
    <span class="kong-cross kong-cross--tr" aria-hidden="true">+</span>
    <span class="kong-cross kong-cross--bl" aria-hidden="true">+</span>
    <span class="kong-cross kong-cross--br" aria-hidden="true">+</span>

    <!-- Inset content frame -->
    <div class="kong-content" :data-bleed="bleed ? 'true' : 'false'">
      <slot />
    </div>

    <!-- Footer band -->
    <div v-if="!hideFooter" class="kong-footer">
      <div class="kong-footer__cat">
        <KongTriangle :size="18" />
        <span>{{ category }}</span>
      </div>
      <div class="kong-footer__copy">
        <span>&copy; {{ copyright }}</span>
      </div>
      <div class="kong-footer__right">
        <span v-if="external" class="kong-footer__ext">{{ external }}</span>
        <span class="kong-footer__num">{{ slideNo }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, inject } from 'vue';
import KongTriangle from './KongTriangle.vue';

const props = defineProps({
  category: { type: String, default: '' },
  hideFooter: { type: Boolean, default: false },
  bleed: { type: Boolean, default: false },
});

const $slidev = inject('$slidev', null);

const deckCategory = computed(
  () => $slidev?.configs?.kong_category ?? 'AI CONNECTIVITY'
);
const category = computed(() => props.category || deckCategory.value);

const copyright = computed(
  () => $slidev?.configs?.kong_copyright ?? 'Kong Inc.'
);
const external = computed(
  () => $slidev?.configs?.kong_external ?? 'NOT TO BE SHARED EXTERNALLY'
);
const slideNo = computed(() => $slidev?.nav?.currentSlideNo ?? '');
</script>

<style scoped>
.kong-frame {
  position: relative;
  width: 100%;
  height: 100%;
  background: var(--kong-bg-deep);
  color: var(--kong-surface);
  overflow: hidden;
}

/* Corner registration crosses */
.kong-cross {
  position: absolute;
  font-family: var(--kong-mono);
  font-weight: 400;
  font-size: 1.2rem;
  line-height: 1;
  color: var(--kong-lime);
  pointer-events: none;
  user-select: none;
  z-index: 5;
}
.kong-cross--tl { top: 0.55rem;  left: 1.6rem; }
.kong-cross--tr { top: 0.55rem;  right: 1.6rem; }
.kong-cross--bl { bottom: 3.1rem; left: 1.6rem; }
.kong-cross--br { bottom: 3.1rem; right: 1.6rem; }

/* Inset content frame -- bg-dark sits inside the bg-deep outer band. */
.kong-content {
  position: absolute;
  top: 1.4rem;
  bottom: 4rem;
  left: 2.4rem;
  right: 2.4rem;
  background: var(--kong-bg-dark);
  overflow: hidden;
}

/* Bleed mode: drop the inset, content fills the entire slide canvas. */
.kong-content[data-bleed="true"] {
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--kong-bg-deep);
}

/* Footer band along the bottom of the outer canvas. */
.kong-footer {
  position: absolute;
  left: 1.6rem;
  right: 1.6rem;
  bottom: 0.6rem;
  height: 2.4rem;
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  align-items: center;
  font-family: var(--kong-sans);
  font-size: 0.75rem;
  letter-spacing: 0.04em;
  color: var(--kong-grey-400);
  z-index: 4;
}

.kong-footer__cat {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.kong-footer__cat span {
  font-family: var(--kong-sans);
  font-weight: 700;
  font-size: 0.78rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--kong-lime);
}

.kong-footer__copy {
  text-align: center;
  font-size: 0.75rem;
  color: var(--kong-grey-400);
}

.kong-footer__right {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 1.4rem;
}

.kong-footer__ext {
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--kong-grey-500);
}

.kong-footer__num {
  font-family: var(--kong-sans);
  font-weight: 600;
  font-size: 0.85rem;
  color: var(--kong-grey-300);
}
</style>
