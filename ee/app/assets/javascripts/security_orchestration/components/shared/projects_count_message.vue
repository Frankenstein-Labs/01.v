<script>
import { GlTooltipDirective, GlIcon, GlSprintf } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  i18n: {
    textTemplate: __('%{loadedProjects} of %{totalProjectsCount} %{projects} loaded'),
    tooltipText: __('Scroll to the bottom to load more items'),
  },
  name: 'ProjectsCountMessage',
  directives: { GlTooltip: GlTooltipDirective },
  components: {
    GlIcon,
    GlSprintf,
  },
  props: {
    count: {
      type: Number,
      required: false,
      default: 0,
    },
    totalCount: {
      type: Number,
      required: false,
      default: 0,
    },
    showInfoIcon: {
      type: Boolean,
      required: false,
      default: false,
    },
    infoText: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <div>
    <span data-testid="message">
      <gl-sprintf :message="$options.i18n.textTemplate">
        <template #loadedProjects>
          <strong>{{ count }}</strong>
        </template>
        <template #totalProjectsCount>
          <strong>{{ totalCount }}</strong>
        </template>
        <template #projects>
          {{ infoText }}
        </template>
      </gl-sprintf>
    </span>
    <span>
      <gl-icon
        v-if="showInfoIcon"
        v-gl-tooltip
        name="information-o"
        variant="info"
        :title="$options.i18n.tooltipText"
      />
    </span>
  </div>
</template>
