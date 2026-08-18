<script>
import { GlLink, GlToggle } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import Api from 'ee/api';
import { refreshCurrentPage } from '~/lib/utils/url_utility';

export default {
  FEEDBACK_ISSUE_LINK: 'https://gitlab.com/gitlab-org/gitlab/-/issues/545147',
  i18n: {
    feedbackLabel: __('Give us feedback'),
    labelDisabled: s__('SecurityOrchestration|Enable advanced editor'),
    labelEnabled: s__('SecurityOrchestration|Enable standard editor'),
  },
  name: 'AdvancedEditorToggle',
  components: {
    GlLink,
    GlToggle,
  },
  inject: ['policyEditorEnabled'],
  data() {
    return {
      advancedEditorEnabled: this.policyEditorEnabled,
    };
  },
  computed: {
    label() {
      const { labelEnabled, labelDisabled } = this.$options.i18n;

      return this.advancedEditorEnabled ? labelEnabled : labelDisabled;
    },
  },
  methods: {
    async toggleAdvancedEditor(advancedEditorEnabled) {
      this.advancedEditorEnabled = advancedEditorEnabled;

      await Api.updateUserPreferences(advancedEditorEnabled);
      refreshCurrentPage();
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-2">
    <gl-toggle
      label-position="left"
      :label="label"
      :value="advancedEditorEnabled"
      @change="toggleAdvancedEditor"
    />
    <gl-link
      v-if="advancedEditorEnabled"
      class="@md/panel:gl-ml-auto"
      :href="$options.FEEDBACK_ISSUE_LINK"
      target="_blank"
    >
      {{ $options.i18n.feedbackLabel }}
    </gl-link>
  </div>
</template>
