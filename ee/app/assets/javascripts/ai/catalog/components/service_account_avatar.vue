<script>
import { GlAvatarLabeled, GlAvatarLink } from '@gitlab/ui';

export default {
  name: 'ServiceAccountAvatar',
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
  },
  props: {
    serviceAccount: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <gl-avatar-link :href="serviceAccount.webPath" :title="serviceAccount.name">
    <gl-avatar-labeled
      :size="32"
      :src="serviceAccount.avatarUrl"
      :label="serviceAccount.name"
      :sub-label="`@${serviceAccount.username}`"
    />
  </gl-avatar-link>
</template>
