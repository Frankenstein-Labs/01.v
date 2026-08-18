<script>
import { GlCard, GlLink } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'GetFamiliar',
  components: {
    GlCard,
    GlLink,
  },
  mixins: [InternalEvents.mixin()],
  GITLAB_CREDITS_PATH: helpPagePath('subscriptions/subscription-add-ons'),
};
</script>

<template>
  <div>
    <header>
      <h2 class="gl-text-size-h2">
        {{ s__('LearnGitLab|Get familiar with GitLab Duo Agent Platform') }}
      </h2>
      <p class="gl-mb-3 gl-text-subtle">
        {{
          s__('LearnGitLab|Explore these resources to learn essential features and best practices.')
        }}
      </p>
    </header>

    <gl-card data-testid="duo-code-suggestions-card">
      <template #default>
        <div class="gl-px-5 gl-py-4">
          <ul class="gl-mb-0 gl-pl-4" :aria-label="__(`GitLab Duo Agent Platform features`)">
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|GitLab Credits:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Your trial includes a pool of GitLab Credits shared across your team. Use them to access GitLab Duo Agent Platform features like AI Agents, Flows, and enhanced Chat.',
                )
              }}
              <gl-link :href="$options.GITLAB_CREDITS_PATH" target="_blank">
                {{ s__('LearnGitLab|Learn about GitLab Credits') }}
              </gl-link>
            </li>
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|Agentic Chat:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Answer complex questions with context-aware chat that understands your code, pipelines, and projects.',
                )
              }}
            </li>
            <li class="gl-mb-3">
              <strong>{{ s__('LearnGitLab|Agents:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Handle specific tasks autonomously, from searching across projects to creating commits.',
                )
              }}
            </li>
            <li>
              <strong>{{ s__('LearnGitLab|Flows:') }}</strong>
              {{
                s__(
                  'LearnGitLab|Let you automate entire workflows by combining agents into sequences that run in your IDE or directly in GitLab CI/CD.',
                )
              }}
            </li>
          </ul>
        </div>
      </template>
    </gl-card>
  </div>
</template>
