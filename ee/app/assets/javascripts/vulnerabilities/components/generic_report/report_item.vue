<script>
import { REPORT_COMPONENTS, getComponentNameForType } from './types/component_map';

export default {
  name: 'GenericReportItem',
  components: {
    ...REPORT_COMPONENTS,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    componentName() {
      return getComponentNameForType(this.item.type);
    },
  },
};
</script>
<template>
  <component :is="componentName" v-bind="item" data-testid="reportComponent" />
</template>
