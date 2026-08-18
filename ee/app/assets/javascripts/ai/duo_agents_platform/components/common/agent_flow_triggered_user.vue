<script>
import { GlAvatarLink, GlTooltipDirective } from '@gitlab/ui';
import { getNumericId } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'AgentFlowTriggeredUser',
  components: {
    GlAvatarLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    user: {
      required: false,
      type: Object,
      default: () => ({}),
    },
  },
  computed: {
    userId() {
      return getNumericId(this.user?.id);
    },
    userUsername() {
      return this.user?.username || '';
    },
    userWebUrl() {
      return this.user?.webUrl || '';
    },
    userName() {
      return this.user?.name || '';
    },
  },
};
</script>
<template>
  <span>
    <gl-avatar-link
      v-gl-tooltip.bottom
      :href="userWebUrl"
      :data-user-id="userId"
      :data-username="userUsername"
      :title="userName"
      class="js-user-link"
    >
      @{{ userUsername }}
    </gl-avatar-link>
  </span>
</template>
