<script>
import { GlButton, GlCard, GlIcon, GlAvatarLabeled, GlSprintf } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import securityAgentAvatarUrl from 'ee_images/bot_avatars/security-agent.png';
import plannerAgentAvatarUrl from 'ee_images/bot_avatars/planner-agent.png';
import analyticsAgentAvatarUrl from 'ee_images/bot_avatars/analytics-agent.png';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from '../../constants';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'StartTrialEmptyState',
  components: {
    GlButton,
    GlCard,
    GlIcon,
    GlAvatarLabeled,
    GlSprintf,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    newTrialPath: {
      type: String,
      required: true,
    },
    trialDuration: {
      type: String,
      required: true,
    },
  },
  mounted() {
    this.trackEvent(DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_NOT_AVAILABLE);
  },
  tanukiAiSvgUrl,
  securityAgentAvatarUrl,
  plannerAgentAvatarUrl,
  analyticsAgentAvatarUrl,
  dapDocs: helpPagePath('/user/duo_agent_platform/_index.md'),
  trackingEvents: DUO_PANEL_EMPTY_STATE_EVENTS,
  workflowExamples: [
    {
      icon: 'merge-request',
      title: s__('DuoAgentsPlatform|Review a merge request'),
      subtitle: s__('DuoAgentsPlatform|Identify code improvements'),
    },
    {
      icon: 'pipeline',
      title: s__('DuoAgentsPlatform|Fix a failing pipeline'),
      subtitle: s__('DuoAgentsPlatform|Analyze pipeline failures and get fix suggestions'),
    },
  ],
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-5">
    <tanuki-ai-icon />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgentsPlatform|Try GitLab Duo Agent Platform') }}
    </h2>
    <p class="gl-m-0 gl-text-subtle" data-testid="empty-state-text">
      <gl-sprintf
        :message="
          s__(
            'DuoAgentsPlatform|Start your free %{strongStart}%{trialDuration}-day trial%{strongEnd} now to accelerate your software delivery. Automate tasks with AI agents, from searching projects to creating commits.',
          )
        "
      >
        <template #strong="{ content }">
          <strong>{{ sprintf(content, { trialDuration }) }}</strong>
        </template>
      </gl-sprintf>
    </p>
    <div class="gl-flex gl-gap-3">
      <gl-button
        variant="confirm"
        category="primary"
        :href="newTrialPath"
        data-event-tracking="click_link"
        :data-event-label="$options.trackingEvents.CLICK_START_TRIAL"
        data-testid="start-trial-link"
      >
        {{ s__('DuoAgentsPlatform|Start a Free Trial') }}
      </gl-button>
      <gl-button
        variant="default"
        data-event-tracking="click_link"
        :data-event-label="$options.trackingEvents.CLICK_LEARN_MORE"
        data-testid="learn-more-link"
        :href="$options.dapDocs"
      >
        {{ __('Learn more') }}
      </gl-button>
    </div>
    <gl-card class="gl-mt-3 gl-w-full">
      <template #header>
        <span class="gl-font-bold">{{
          s__('DuoAgentsPlatform|Complete multi-step tasks with flows')
        }}</span>
      </template>
      <div class="gl-flex gl-flex-col gl-gap-4">
        <div
          v-for="(example, i) in $options.workflowExamples"
          :key="i"
          class="gl-flex gl-gap-x-2"
          data-testid="workflow-example"
        >
          <div><gl-icon :name="example.icon" /></div>
          <div>
            <div class="gl-font-bold gl-text-strong">
              {{ example.title }}
            </div>
            <div class="gl-text-subtle">{{ example.subtitle }}</div>
          </div>
        </div>
      </div>
    </gl-card>
    <h3 class="gl-heading-5 gl-m-0">
      {{ s__('DuoAgentsPlatform|Chat with a specialized agent') }}
    </h3>
    <p class="gl-m-0">
      {{
        s__(
          'DuoAgentsPlatform|With a trial you can chat with AI agents tailored to your development workflow, such as the following agents:',
        )
      }}
    </p>
    <div class="gl-flex gl-w-full gl-justify-start gl-gap-5 gl-pb-5">
      <gl-avatar-labeled
        :src="$options.securityAgentAvatarUrl"
        :size="32"
        :label="s__('DuoAgentsPlatform|Security Agent')"
        fallback-on-error
      />
      <gl-avatar-labeled
        :src="$options.plannerAgentAvatarUrl"
        :size="32"
        :label="s__('DuoAgentsPlatform|Planning Agent')"
        fallback-on-error
      />
      <gl-avatar-labeled
        :src="$options.analyticsAgentAvatarUrl"
        :size="32"
        :label="s__('DuoAgentsPlatform|Data Analyst')"
        fallback-on-error
      />
    </div>
  </div>
</template>
