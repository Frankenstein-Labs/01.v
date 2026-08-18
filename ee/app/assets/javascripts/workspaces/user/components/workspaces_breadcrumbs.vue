<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ROUTES } from '../constants';

export const BREADCRUMB_LABELS = {
  index: s__('Workspaces|Workspaces'),
  new: s__('Workspaces|Create a new workspace'),
};

export default {
  name: 'WorkspacesBreadcrumbs',
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      type: Array,
      required: true,
    },
  },
  computed: {
    crumbs() {
      const crumbs = [
        {
          text: BREADCRUMB_LABELS[ROUTES.index],
          to: ROUTES.index,
        },
      ];

      if (this.$route.name === ROUTES.new) {
        crumbs.push({
          text: BREADCRUMB_LABELS[ROUTES.new],
          to: ROUTES.new,
        });
      }

      return [...this.staticBreadcrumbs, ...crumbs];
    },
  },
};
</script>

<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
