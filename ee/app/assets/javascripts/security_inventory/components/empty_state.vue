<script>
import { GlEmptyState } from '@gitlab/ui';
import EMPTY_SUBGROUP_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-projects-md.svg?url';
import { s__ } from '~/locale';

export default {
  components: {
    GlEmptyState,
  },
  inject: ['newProjectPath'],
  i18n: {
    emptyStateTitle: s__('SecurityInventory|No projects found'),
    emptyStateDescription: s__(
      'SecurityInventory|Add projects to this group to start tracking their security posture.',
    ),
  },
  EMPTY_SUBGROUP_SVG,
};
</script>

<template>
  <gl-empty-state
    :title="$options.i18n.emptyStateTitle"
    :description="$options.i18n.emptyStateDescription"
    :svg-path="$options.EMPTY_SUBGROUP_SVG"
    :svg-height="150"
    :primary-button-text="__('New Project')"
    :primary-button-link="newProjectPath"
  />
</template>
