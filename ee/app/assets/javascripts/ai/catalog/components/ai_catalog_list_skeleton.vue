<script>
export default {
  name: 'AiCatalogListSkeleton',
  props: {
    showRightElement: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <ul class="gl-m-0 gl-list-none gl-p-0">
    <li
      v-for="n in 5"
      :key="n"
      class="gl-border-b gl-flex gl-items-start gl-justify-between gl-gap-6 gl-p-5"
    >
      <div class="gl-flex gl-grow gl-flex-col gl-gap-3">
        <div class="gl-animate-skeleton-loader gl-h-5 gl-max-w-48 gl-rounded-default"></div>
        <div class="gl-animate-skeleton-loader gl-h-7 gl-max-w-3xl gl-rounded-default"></div>
        <div class="gl-flex gl-gap-2">
          <div class="gl-animate-skeleton-loader gl-h-5 gl-w-5 gl-rounded-default"></div>
          <div class="gl-animate-skeleton-loader gl-h-5 gl-w-12 gl-rounded-default"></div>
        </div>
      </div>
      <div
        v-if="showRightElement"
        data-testid="right-element-placeholder"
        class="gl-animate-skeleton-loader gl-h-6 gl-w-6 gl-rounded-default"
      ></div>
    </li>
  </ul>
</template>
