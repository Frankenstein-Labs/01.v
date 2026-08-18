<script>
import { GlEmptyState, GlSprintf, GlLink, GlButton } from '@gitlab/ui';
import emptyStateSvgPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-secure-md.svg?url';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import ExperimentHeader from './experiment_header.vue';

export default {
  name: 'EmptyState',
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
    GlButton,
    ExperimentHeader,
  },
  emits: ['primary-action'],
  methods: {
    handlePrimaryButtonAction() {
      this.$emit('primary-action');
    },
  },
  emptyStateSvgPath,
  learnMoreLink: helpPagePath('user/application_security/secret_detection/_index'),
  i18n: {
    emptyStateTitle: s__('SecretDetection|No exclusions yet'),
    emptyStateDescription: s__(
      'SecretDetection|Use secret detection exclusions to specify file paths, raw values, and regex that should be excluded by secret detection in this project. %{linkStart}Learn more.%{linkEnd}',
    ),
    primaryButtonText: s__('SecretDetection|Add exclusion'),
  },
};
</script>

<template>
  <div>
    <experiment-header />
    <gl-empty-state :title="$options.i18n.emptyStateTitle" :svg-path="$options.emptyStateSvgPath">
      <template #description>
        <span class="gl-text-lg gl-leading-24">
          <gl-sprintf :message="$options.i18n.emptyStateDescription">
            <template #link="{ content }">
              <gl-link :href="$options.learnMoreLink">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </span>
      </template>

      <template #actions>
        <gl-button variant="confirm" class="gl-mt-3" @click="handlePrimaryButtonAction">
          {{ $options.i18n.primaryButtonText }}
        </gl-button>
      </template>
    </gl-empty-state>
  </div>
</template>
