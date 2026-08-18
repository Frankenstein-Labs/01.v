<script>
import { GlLink, GlCard, GlIcon, GlSprintf } from '@gitlab/ui';
import { __ } from '~/locale';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from '../../constants';

export default {
  name: 'AccessDeniedEmptyState',
  components: {
    GlSprintf,
    GlLink,
    GlCard,
    GlIcon,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    containerType: {
      type: String,
      required: false,
      default: TYPENAME_GROUP,
    },
  },
  computed: {
    namespaceTypeLabel() {
      return this.containerType === TYPENAME_GROUP ? __('group') : __('project');
    },
  },
  mounted() {
    this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_NOT_AVAILABLE);
  },
  dapDocs: helpPagePath('/user/duo_agent_platform/_index.md'),
  trackingEvents: DUO_PANEL_EMPTY_STATE_EVENTS,
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4">
    <tanuki-ai-icon />

    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgentsPlatform|Access required') }}
    </h2>
    <p class="gl-m-0 gl-text-subtle" data-testid="empty-state-text">
      <gl-sprintf
        :message="
          s__(
            `DuoAgentsPlatform|You don't have permission to use GitLab Duo Agent Platform in this %{namespaceType}. %{learnMoreLinkStart}Learn more%{learnMoreLinkEnd}.`,
          )
        "
      >
        <template #namespaceType>{{ namespaceTypeLabel }}</template>
        <template #learnMoreLink="{ content }">
          <gl-link
            target="_blank"
            :href="$options.dapDocs"
            data-event-tracking="click_link"
            :data-event-label="$options.trackingEvents.CLICK_LEARN_MORE"
            data-testid="learn-more-link"
            >{{ content }}</gl-link
          >
        </template>
      </gl-sprintf>
    </p>
    <gl-card class="gl-mt-3 gl-w-full">
      <template #header>
        <span class="gl-font-bold">{{ s__('DuoAgentsPlatform|Get access to GitLab Duo') }}</span>
      </template>
      <div class="gl-flex gl-flex-col gl-gap-4">
        <div class="gl-flex gl-gap-x-2">
          <div><gl-icon name="user" /></div>
          <div>
            <div class="gl-font-bold gl-text-strong">
              {{ s__('DuoAgentsPlatform|Who can grant you access') }}
            </div>
            <div class="gl-text-subtle">
              {{ s__('DuoAgentsPlatform|Contact a project Maintainer or group Owner') }}
            </div>
          </div>
        </div>
      </div>
    </gl-card>
  </div>
</template>
