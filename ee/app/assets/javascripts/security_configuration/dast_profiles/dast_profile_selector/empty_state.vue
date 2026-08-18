<script>
export default {
  name: 'DastProfileSelectorEmptyState',
};
</script>

<template>
  <div>
    <div
      class="gl-mb-5 gl-flex gl-flex-col gl-items-center gl-rounded-small gl-bg-subtle gl-p-6 gl-text-center"
    >
      <h5 class="gl-h5 gl-mb-2 gl-mt-0 gl-text-subtle">
        <slot name="header"></slot>
      </h5>
      <span class="gl-text-subtle">
        <slot name="content"></slot>
      </span>
    </div>
  </div>
</template>
