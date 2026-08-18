<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'ColumnsTarget',
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    target: {
      type: String,
      required: false,
      default: '',
    },
  },
  i18n: {
    notSet: s__('CorpusManagement|Not Set'),
    noSetInfo: s__('CorpusManagement|To use this corpus, edit the corresponding YAML file'),
  },
  computed: {
    hasTarget() {
      return Boolean(this.target);
    },
  },
};
</script>
<template>
  <span v-if="hasTarget" class="gl-text-default"> {{ target }} </span>
  <span v-else v-gl-tooltip.hover class="gl-text-default" :title="$options.i18n.noSetInfo">
    <gl-icon class="gl-mr-1" :size="16" name="information-o" />
    {{ $options.i18n.notSet }}
  </span>
</template>
