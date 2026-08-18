<script>
import { GlCard, GlLink, GlIcon, GlSprintf } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'DuoDisabledNonAdminEmptyState',
  components: {
    GlCard,
    GlLink,
    GlIcon,
    GlSprintf,
  },
  props: {
    containerType: {
      type: String,
      required: false,
      default: 'group',
    },
  },
  computed: {
    turnOnInstructionsText() {
      if (this.containerType === 'project') {
        return this.$options.i18n.projectInstructions;
      }
      return this.$options.i18n.groupInstructions;
    },
    containerDisabledText() {
      if (this.containerType === 'project') {
        return this.$options.i18n.projectDisabled;
      }
      return this.$options.i18n.groupDisabled;
    },
  },
  tanukiAiSvgUrl,
  learnMorePath: helpPagePath('user/duo_agent_platform/_index'),
  i18n: {
    projectInstructions: s__(
      'DuoAgenticChat|An Owner, Maintainer, or administrator can turn on GitLab Duo for this project.',
    ),
    groupInstructions: s__(
      'DuoAgenticChat|An Owner or administrator can turn on GitLab Duo for this group.',
    ),
    projectDisabled: s__(
      'DuoAgenticChat|GitLab Duo is disabled for this project. %{linkStart}Learn more%{linkEnd}.',
    ),
    groupDisabled: s__(
      'DuoAgenticChat|GitLab Duo is disabled for this group. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4"
    data-testid="duo-disabled-non-admin-empty-state"
  >
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />

    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|GitLab Duo Agent Platform is turned off') }}
    </h2>

    <div class="gl-flex gl-gap-1">
      <p class="gl-m-0 gl-text-subtle" data-testid="description">
        <gl-sprintf :message="containerDisabledText">
          <template #link="{ content }">
            <gl-link
              :href="$options.learnMorePath"
              target="_blank"
              rel="noopener noreferrer"
              data-testid="duo-learn-more"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </p>
    </div>

    <gl-card class="gl-mt-3 gl-w-full" header-class="gl-px-5" body-class="gl-p-5 gl-flex gl-gap-4">
      <template #header>
        <span class="gl-text-sm gl-font-bold">{{
          s__('DuoAgenticChat|Get GitLab Duo turned on')
        }}</span>
      </template>
      <template #default>
        <gl-icon name="user" aria-hidden="true" />
        <p class="gl-text-subtle" data-testid="turn-on-instructions">
          {{ turnOnInstructionsText }}
        </p>
      </template>
    </gl-card>
  </div>
</template>
