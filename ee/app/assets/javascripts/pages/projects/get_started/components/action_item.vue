<script>
import { GlIcon, GlLink, GlTooltipDirective } from '@gitlab/ui';
import eventHub from '~/invite_members/event_hub';
import { LEARN_GITLAB } from 'ee/invite_members/constants';
import Tracking from '~/tracking';
import { INVITE_URL_TYPE } from '../constants';

export default {
  name: 'ActionItem',
  components: {
    GlIcon,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [Tracking.mixin({ category: 'projects:learn_gitlab:show' })],
  props: {
    action: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isDisabled() {
      return this.action.enabled === false;
    },
  },
  methods: {
    handleActionClick() {
      if (this.action.urlType === INVITE_URL_TYPE) {
        eventHub.$emit('open-modal', { source: LEARN_GITLAB });
      }

      this.track('click_link', { label: this.action.trackLabel });
    },
  },
};
</script>

<template>
  <li class="gl-flex gl-items-center gl-gap-3">
    <gl-link
      v-if="!isDisabled"
      class="gl-display-inline-block"
      :href="action.url"
      @click="handleActionClick"
    >
      {{ action.title }}
    </gl-link>
    <span
      v-else
      class="gl-display-inline-block gl-text-subtle"
      aria-disabled="true"
      :aria-label="
        s__('LearnGitLab|You don\'t have sufficient access to perform this action: ') + action.title
      "
      data-testid="action-disabled"
    >
      {{ action.title }}
      <gl-icon
        v-gl-tooltip="s__('LearnGitLab|You don\'t have sufficient access to perform this action')"
        name="lock"
        class="gl-ml-2"
        aria-hidden="true"
        data-testid="disabled-icon"
      />
      <span class="gl-sr-only">
        {{ s__("LearnGitLab|You don't have sufficient access to perform this action") }}
      </span>
    </span>
  </li>
</template>
