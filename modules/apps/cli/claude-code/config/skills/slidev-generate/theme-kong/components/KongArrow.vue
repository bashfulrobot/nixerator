<template>
  <Arrow
    :x1="x1"
    :y1="y1"
    :x2="x2"
    :y2="y2"
    :color="color"
    :width="width"
    :two-way="twoWay"
  />
</template>

<script setup>
defineProps({
  x1: { type: [Number, String], required: true },
  y1: { type: [Number, String], required: true },
  x2: { type: [Number, String], required: true },
  y2: { type: [Number, String], required: true },
  color: { type: String, default: '#CCFF00' },
  width: { type: [Number, String], default: 2 },
  twoWay: { type: Boolean, default: false },
});
</script>
