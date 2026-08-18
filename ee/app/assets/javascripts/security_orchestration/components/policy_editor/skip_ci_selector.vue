<script>
import { GlSprintf, GlLink, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import {
  DEFAULT_REVERSED_SKIP_SI_CONFIGURATION,
  DEFAULT_SKIP_SI_CONFIGURATION,
} from 'ee/security_orchestration/components/constants';

export default {
  SKIP_CI_PATH: helpPagePath('ci/pipelines/_index.md', { anchor: 'skip-a-pipeline' }),
  i18n: {
    skipCiConfigurationLabel: s__('SecurityOrchestration|Prevent users from skipping pipelines'),
    skipCiHeader: s__(
      'SecurityOrchestration|Configure policies to control whether individual users or service accounts can use %{linkStart}skip_ci%{linkEnd} to skip pipelines.',
    ),
    skipCiExceptionText: s__('SecurityOrchestration|except for:'),
  },
  name: 'SkipCiSelector',
  components: {
    GlToggle,
    GlSprintf,
    GlLink,
    UserSelect,
  },
  props: {
    skipCiConfiguration: {
      type: Object,
      required: false,
      default: undefined,
    },
    isReversed: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['changed'],
  computed: {
    configuration() {
      return this.skipCiConfiguration || this.fallbackValue;
    },
    fallbackValue() {
      return this.isReversed
        ? DEFAULT_REVERSED_SKIP_SI_CONFIGURATION
        : DEFAULT_SKIP_SI_CONFIGURATION;
    },
    enabled() {
      return Boolean(this.configuration?.allowed);
    },
    selectedUsers() {
      const { allowlist: { users = [] } = {} } = this.configuration || {};
      return users.map(({ id }) => id) || [];
    },
  },
  methods: {
    updateConfiguration(value) {
      this.$emit('changed', 'skip_ci', {
        allowed: !value,
      });
    },
    updateUsers({ user_approvers_ids: users = [] }) {
      this.$emit('changed', 'skip_ci', {
        ...this.configuration,
        allowed: false,
        allowlist: { users: users?.map((id) => ({ id })) },
      });
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-3">
      <gl-sprintf :message="$options.i18n.skipCiHeader">
        <template #link="{ content }">
          <gl-link :href="$options.SKIP_CI_PATH" target="_blank" rel="noopener noreferrer">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <div
      class="gl-flex gl-flex-wrap gl-items-center gl-gap-3 @lg/panel:gl-flex-nowrap @lg/panel:gl-gap-0"
    >
      <gl-toggle
        :value="!enabled"
        :label="$options.i18n.skipCiConfigurationLabel"
        label-position="left"
        data-testid="allow-selector"
        @change="updateConfiguration"
      />

      <div class="gl-align-items-center gl-ml-3 gl-flex gl-items-center">
        <span :class="{ 'gl-text-subtle': enabled }">{{ $options.i18n.skipCiExceptionText }}</span>
        <user-select
          reset-on-empty
          :disabled="enabled"
          :selected="selectedUsers"
          class="gl-ml-3"
          @select-items="updateUsers"
        />
      </div>
    </div>
  </div>
</template>
