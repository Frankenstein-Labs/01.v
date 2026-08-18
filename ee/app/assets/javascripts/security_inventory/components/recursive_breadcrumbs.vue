<script>
import { GlBreadcrumb } from '@gitlab/ui';
import GroupAvatarAndParentQuery from '../graphql/group_avatar_and_parent.query.graphql';
import { hasReachedMainGroup } from '../utils';

export default {
  name: 'RecursiveBreadcrumbs',
  components: {
    GlBreadcrumb,
  },
  props: {
    items: {
      type: Array,
      required: false,
      default: () => [],
    },
    currentPath: {
      type: String,
      required: true,
    },
    groupFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      group: {},
    };
  },
  apollo: {
    group: {
      query: GroupAvatarAndParentQuery,
      variables() {
        return {
          fullPath: this.currentPath,
        };
      },
    },
  },
  computed: {
    hasReachedMainGroup() {
      return hasReachedMainGroup(this.currentPath, this.groupFullPath, this.group);
    },
    crumbs() {
      return [
        {
          text: this.group.name,
          to: {
            hash: this.currentPath,
          },
          avatarPath: this.group.avatarUrl,
        },
        ...this.items,
      ];
    },
  },
};
</script>

<template>
  <gl-breadcrumb
    v-if="hasReachedMainGroup"
    :items="crumbs"
    :auto-resize="true"
    size="md"
    class="gl-my-5"
  />
  <recursive-breadcrumbs
    v-else
    :items="crumbs"
    :current-path="group?.parent?.fullPath"
    :group-full-path="groupFullPath"
  />
</template>
