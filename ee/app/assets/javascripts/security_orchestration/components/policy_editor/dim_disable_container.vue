<script>
export default {
  name: 'DimDisableContainer',
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <div class="gl-relative gl-mt-7">
    <slot name="title"></slot>

    <slot v-if="disabled" name="disabled"></slot>
    <slot v-else></slot>

    <div
      v-if="disabled"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-0 gl-bg-default gl-opacity-5"
      data-testid="overlay"
    ></div>
  </div>
</template>
