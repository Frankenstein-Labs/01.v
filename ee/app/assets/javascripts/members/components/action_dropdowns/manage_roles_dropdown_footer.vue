<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'ManageRolesDropdownFooter',
  components: {
    GlButton,
  },
  inject: {
    manageMemberRolesPath: {
      default: null,
    },
  },
};
</script>

<template>
  <div v-if="manageMemberRolesPath" class="gl-border-t gl-border-dropdown gl-p-2">
    <gl-button
      :href="manageMemberRolesPath"
      category="tertiary"
      class="gl-w-full !gl-justify-start"
    >
      {{ s__('MemberRole|Manage roles') }}
    </gl-button>
  </div>
</template>
