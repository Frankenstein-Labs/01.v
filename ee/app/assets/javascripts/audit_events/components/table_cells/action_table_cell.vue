<script>
export default {
  name: 'ActionTableCell',
  props: {
    text: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <span class="gl-wrap-anywhere">{{ text }}</span>
</template>
