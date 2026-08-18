<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { s__ } from '~/locale';
import { SETUP_TOOLS } from '../../../constants';

export default {
  name: 'ArtifactRegistrySetupToolSelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    format: {
      type: String,
      required: true,
    },
    selected: {
      type: String,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return {
      labelId: uniqueId('setup-tool-label-'),
    };
  },
  computed: {
    tools() {
      return SETUP_TOOLS[this.format] ?? [];
    },
  },
  i18n: {
    label: s__('ArtifactRegistry|Build tool'),
  },
};
</script>

<template>
  <div v-if="tools.length">
    <span :id="labelId" class="gl-sr-only">{{ $options.i18n.label }}</span>
    <gl-collapsible-listbox
      :items="tools"
      :selected="selected"
      :toggle-aria-labelled-by="labelId"
      @select="$emit('select', $event)"
    />
  </div>
</template>
