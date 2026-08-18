<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import { getIterationPeriod } from 'ee/iterations/utils';

export default {
  name: 'WorkItemIterationAttribute',
  components: {
    WorkItemAttribute,
  },
  props: {
    iteration: {
      type: Object,
      required: true,
    },
    namespacePath: {
      type: String,
      required: true,
    },
  },
  computed: {
    iterationId() {
      const { id } = this.iteration;
      return id ? getIdFromGraphQLId(id) : '';
    },
    iterationPeriod() {
      return this.iteration && getIterationPeriod(this.iteration);
    },
  },
};
</script>

<template>
  <work-item-attribute
    is-link
    icon-name="iteration"
    data-testid="iteration-attribute"
    :data-iteration="iterationId"
    :data-namespace-path="namespacePath"
    :icon-size="12"
    :href="iteration.webUrl"
    data-placement="top"
    data-reference-type="iteration"
    wrapper-component-class="!gl-text-subtle gl-bg-transparent gl-border-0 gl-p-0 focus-visible:gl-focus-inset has-popover"
  >
    <template #title>{{ iterationPeriod }}</template>
  </work-item-attribute>
</template>
