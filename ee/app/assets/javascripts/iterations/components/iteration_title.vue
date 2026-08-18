<script>
export default {
  name: 'IterationTitle',
  props: {
    title: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div class="gl-text-subtle">
    {{ title }}
  </div>
</template>
