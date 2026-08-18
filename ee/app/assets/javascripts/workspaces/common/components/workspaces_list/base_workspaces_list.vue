<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import WorkspaceEmptyState from './empty_state.vue';

export const i18n = {
  learnMoreHelpLink: __('Learn more'),
  heading: s__('Workspaces|Workspaces'),
};

const workspacesHelpPath = helpPagePath('user/workspace/_index.md');

export default {
  name: 'BaseWorkspacesList',
  components: {
    GlAlert,
    GlLink,
    IndexLayout,
    WorkspaceEmptyState,
  },
  props: {
    empty: {
      type: Boolean,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['error'],
  methods: {
    clearError() {
      this.$emit('error', '');
    },
  },
  i18n,
  workspacesHelpPath,
};
</script>
<template>
  <index-layout :heading="$options.i18n.heading" :page-heading-sr-only="empty">
    <template v-if="loading || !empty" #actions>
      <gl-link class="gl-m-2 gl-hidden @sm/panel:gl-block" :href="$options.workspacesHelpPath">
        {{ $options.i18n.learnMoreHelpLink }}
      </gl-link>
      <slot name="header"></slot>
    </template>

    <gl-alert v-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>
    <workspace-empty-state v-if="!loading && empty" :new-workspace-path="newWorkspacePath" />
    <slot v-else name="workspaces-list"></slot>
  </index-layout>
</template>
