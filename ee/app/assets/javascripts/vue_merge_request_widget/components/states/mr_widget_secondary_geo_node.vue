<script>
import { GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import StateContainer from '~/vue_merge_request_widget/components/state_container.vue';
import BoldText from '~/vue_merge_request_widget/components/bold_text.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

const message = s__(
  'mrWidget|%{boldStart}Merge unavailable:%{boldEnd} merge requests are read-only in a secondary Geo node.',
);

export default {
  name: 'MrWidgetSecondaryGeoNode',
  message,
  components: {
    BoldText,
    HelpIcon,
    StateContainer,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <state-container status="failed" is-collapsible>
    <bold-text :message="$options.message" />
    <a
      v-gl-tooltip
      class="gl-ml-2"
      :href="mr.geoSecondaryHelpPath"
      :title="__('About this feature')"
      target="_blank"
      rel="noopener noreferrer nofollow"
    >
      <help-icon />
    </a>
  </state-container>
</template>
