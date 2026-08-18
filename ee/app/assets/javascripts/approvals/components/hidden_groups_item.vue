<script>
import { GlTooltipDirective, GlIcon } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'HiddenGroupsItem',
  components: {
    GlIcon,
    HelpIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <div class="square s24 gl-mr-3 gl-items-center gl-justify-center">
      <gl-icon name="folder" :size="16" variant="subtle" data-testid="folder-icon" />
    </div>
    <span>{{ __('Private group(s)') }}</span>
    <help-icon
      v-gl-tooltip
      :title="__('One or more groups that you don\'t have access to.')"
      class="gl-ml-2"
      data-testid="help-icon"
    />
  </div>
</template>
