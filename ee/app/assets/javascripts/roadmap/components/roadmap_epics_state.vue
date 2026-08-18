<script>
import { GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { STATUS_ALL, STATUS_CLOSED, STATUS_OPEN } from '~/issues/constants';
import { __ } from '~/locale';

export default {
  name: 'RoadmapEpicsState',
  components: {
    GlFormGroup,
    GlFormRadioGroup,
  },
  props: {
    epicsState: {
      type: String,
      required: true,
    },
  },
  emits: ['set-epics-state'],
  computed: {
    availableStates() {
      const all = { text: __('Show all epics'), value: STATUS_ALL };
      const opened = { text: __('Show open epics'), value: STATUS_OPEN };
      const closed = { text: __('Show closed epics'), value: STATUS_CLOSED };

      return [all, opened, closed];
    },
  },
  methods: {
    handleEpicStateChange(epicsState) {
      if (epicsState !== this.epicsState) {
        this.$emit('set-epics-state', { epicsState });
      }
    },
  },
  i18n: {
    header: __('Epics'),
  },
};
</script>

<template>
  <div>
    <gl-form-group class="gl-mb-0" :label="$options.i18n.header" data-testid="roadmap-epics-state">
      <gl-form-radio-group
        :checked="epicsState"
        stacked
        :options="availableStates"
        @change="handleEpicStateChange"
      />
    </gl-form-group>
  </div>
</template>
