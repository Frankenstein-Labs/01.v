<script>
export default {
  name: 'InfoRow',
  props: {
    label: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <h5 class="gl-mt-6 gl-text-default" data-testid="label">{{ label }}</h5>
    <p class="gl-text-default" data-testid="content"><slot></slot></p>
  </div>
</template>
