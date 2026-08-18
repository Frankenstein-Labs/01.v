<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';

export default {
  name: 'UserLimitReachedAlert',
  components: {
    GlAlert,
    GlSprintf,
  },
  inject: ['canApproveAccessRequests', 'namespaceUserLimit'],
};
</script>

<template>
  <gl-alert v-if="!canApproveAccessRequests" variant="warning" :dismissible="false">
    <gl-sprintf
      :message="
        s__(
          `Members|You can no longer accept access requests because you've reached the %{limit} user limit.`,
        )
      "
    >
      <template #limit>
        {{ namespaceUserLimit }}
      </template>
    </gl-sprintf>
  </gl-alert>
</template>
