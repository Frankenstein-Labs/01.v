<script>
import { GlEmptyState, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';

export const i18n = {
  title: s__('Workspaces|Instant development environments'),
  description: s__(
    `Workspaces|Each workspace is a secure cloud environment for your GitLab project.
      Quickly switch between projects, live preview, and compile code on any device.`,
  ),
  primaryButtonText: s__('Workspaces|New workspace'),
};

export default {
  name: 'EmptyState',
  components: {
    GlEmptyState,
    GlButton,
  },
  inject: ['emptyStateSvgPath'],
  props: {
    title: {
      type: String,
      required: false,
      default: i18n.title,
    },
    description: {
      type: String,
      required: false,
      default: i18n.description,
    },
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
  },
  i18n,
};
</script>

<template>
  <div>
    <gl-empty-state
      :title="title"
      :description="description"
      :svg-path="emptyStateSvgPath"
      :svg-height="150"
    >
      <template v-if="newWorkspacePath" #actions>
        <gl-button
          variant="confirm"
          class="gl-mx-2 gl-mb-3"
          :to="newWorkspacePath"
          data-testid="new-workspace-button"
          >{{ $options.i18n.primaryButtonText }}</gl-button
        >
      </template>
    </gl-empty-state>
  </div>
</template>
