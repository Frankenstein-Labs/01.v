<script>
import { GlButton, GlCard } from '@gitlab/ui';
import TANUKI_AI_ILLUSTRATION from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { s__ } from '~/locale';
import { sendDuoChatCommand } from 'ee/ai/utils';

const DEFAULT_AGENT_ID = 'gid://gitlab/Ai::FoundationalChatAgent/ci_expert_agent-v1';

export default {
  name: 'DuoAnalyzeCard',
  components: {
    GlButton,
    GlCard,
  },
  inject: ['resourceId'],
  emits: ['create-empty-config-file'],
  tanukiAiIllustrationPath: TANUKI_AI_ILLUSTRATION,
  methods: {
    callDuo() {
      sendDuoChatCommand({
        // eslint-disable-next-line @gitlab/no-hardcoded-urls
        question: '/pipeline_authoring',
        resourceId: this.resourceId,
        agenticPrompt: s__(
          'Pipelines|Analyze this repository and create a CI/CD pipeline that meets the needs of the project.',
        ),
        agent: { id: DEFAULT_AGENT_ID },
      });

      this.$emit('create-empty-config-file');
    },
  },
};
</script>
<template>
  <gl-card body-class="gl-flex gl-flex-col">
    <template #header>
      <h2 class="gl-heading-scale-300 gl-mb-0">{{ s__('Pipelines|AI-generated pipeline') }}</h2>
    </template>
    <template #default>
      <p class="gl-grow">
        {{
          s__(
            'Pipelines|Use GitLab Duo to analyze your repository and create a matching CI/CD pipeline.',
          )
        }}
      </p>
      <gl-button
        icon="tanuki-ai"
        variant="confirm"
        data-testid="analyze-repository-button"
        @click="callDuo"
      >
        {{ s__('Pipelines|Analyze repository') }}
      </gl-button>
    </template>
  </gl-card>
</template>
