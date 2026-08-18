<script>
import { GlButton, GlCard } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'DuoDisabledEmptyState',
  components: {
    GlButton,
    GlCard,
    TanukiAiIcon,
  },
  props: {
    duoSettingsPath: {
      type: String,
      required: false,
      default: '',
    },
    containerType: {
      type: String,
      required: false,
      default: 'group',
    },
  },
  computed: {
    description() {
      return {
        project: s__(
          'DuoAgenticChat|As Owner of the project, you can turn on GitLab Duo Agent Platform and its AI features for your team.',
        ),
        group: s__(
          'DuoAgenticChat|As Owner of the group, you can turn on GitLab Duo Agent Platform and its AI features for your team.',
        ),
      }[this.containerType];
    },
  },
  learnMorePath: helpPagePath('user/permissions'),
  steps: [
    {
      title: s__('DuoAgenticChat|Turn on GitLab Duo features'),
      description: s__('DuoAgenticChat|Turn on GitLab Duo features for this project or group.'),
    },
    {
      title: s__('DuoAgenticChat|Optional. Turn on preview features'),
      description: s__(
        'DuoAgenticChat|Turn on beta and experimental features for early access to new tools and improvements.',
      ),
    },
    {
      title: s__('DuoAgenticChat|Turn on flows'),
      description: s__('DuoAgenticChat|Set up automated workflows and AI agents.'),
    },
  ],
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4"
    data-testid="duo-disabled-empty-state"
  >
    <tanuki-ai-icon />

    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|Turn on GitLab Duo Agent Platform') }}
    </h2>

    <p class="gl-m-0 gl-text-subtle">
      {{ description }}
    </p>

    <div class="gl-flex gl-gap-4">
      <gl-button
        :href="$options.learnMorePath"
        target="_blank"
        data-testid="duo-settings-learn-more"
      >
        {{ s__('DuoAgenticChat|Learn more') }}
      </gl-button>
      <gl-button
        :href="duoSettingsPath"
        variant="confirm"
        category="primary"
        data-testid="duo-settings-cta"
      >
        {{ s__('DuoAgenticChat|Go to Duo settings') }}
      </gl-button>
    </div>

    <gl-card class="gl-mt-3 gl-w-full gl-p-0" header-class="gl-px-5 gl-py-4">
      <template #header>
        <span class="gl-text-sm gl-font-bold">{{
          s__('DuoAgenticChat|Steps to turn on GitLab Duo')
        }}</span>
      </template>
      <ul class="gl-m-4 gl-flex gl-flex-col gl-gap-4 gl-pl-4">
        <li v-for="step in $options.steps" :key="step.title">
          <div class="gl-font-bold gl-italic">
            {{ step.title }}
          </div>
          <div class="gl-text-subtle">
            {{ step.description }}
          </div>
        </li>
      </ul>
    </gl-card>
  </div>
</template>
