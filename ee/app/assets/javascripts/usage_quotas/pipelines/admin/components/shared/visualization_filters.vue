<script>
import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';

export default {
  name: 'VisualizationFilters',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    runners: {
      type: Array,
      required: true,
    },
  },
  emits: ['runner-selected'],
  data() {
    return {
      selectedRunner: null,
    };
  },
  created() {
    this.selectedRunner = this.runners[0].value;
  },
  methods: {
    onSelectedRunner(runner) {
      this.$emit('runner-selected', runner);
    },
  },
};
</script>
<template>
  <div class="gl-my-4 gl-flex">
    <slot></slot>
    <gl-form-group :label="__('Runner')">
      <gl-collapsible-listbox
        v-model="selectedRunner"
        :items="runners"
        block
        data-testid="runner-filter"
        @select="onSelectedRunner"
      />
    </gl-form-group>
  </div>
</template>
