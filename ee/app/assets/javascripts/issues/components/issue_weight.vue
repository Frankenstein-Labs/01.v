<script>
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import { sprintf, __ } from '~/locale';

export default {
  name: 'IssueCardWeight',
  components: {
    WorkItemAttribute,
  },
  props: {
    weight: {
      type: Number,
      required: true,
    },
  },
  methods: {
    createAriaLabel() {
      return sprintf(__(`Weight: %{weighted}`), {
        weighted: this.weight,
      });
    },
  },
};
</script>

<template>
  <work-item-attribute
    wrapper-component="button"
    anchor-id="board-card-weight"
    wrapper-component-class="board-card-info board-card-weight gl-inline-flex gl-cursor-help gl-items-center gl-align-bottom gl-text-sm gl-text-subtle !gl-cursor-help gl-bg-transparent gl-border-0 gl-p-0 focus-visible:gl-focus-inset"
    :title="`${weight}`"
    title-component-class="board-card-info-text"
    icon-name="weight"
    :aria-label="createAriaLabel()"
  >
    <template #tooltip-text>
      <span class="gl-block gl-font-bold">{{ __('Weight') }}</span>
      <span>{{ weight }}</span>
    </template>
  </work-item-attribute>
</template>
