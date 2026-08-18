<script>
import { GlSprintf, GlFormCheckbox, GlPopover, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';

export default {
  name: 'DuoPromptCacheForm',
  i18n: {
    sectionTitle: __('Prompt cache'),
    checkboxLabel: s__('AiPowered|Turn on prompt caching'),
    checkboxHelpText: s__(
      'AiPowered|Use prompt caching to improve GitLab Duo performance. %{linkStart}What is prompt caching%{linkEnd}?',
    ),
    popoverTitle: s__('AiPowered|Setting unavailable'),
    popoverContent: s__(
      'AiPowered|When GitLab Duo is not available, prompt caching cannot be turned on.',
    ),
  },
  components: {
    GlSprintf,
    GlFormCheckbox,
    GlPopover,
    GlLink,
  },
  inject: ['arePromptCacheSettingsAllowed'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    promptCacheEnabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['change'],
  data() {
    return {
      cacheEnabled: this.promptCacheEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.cacheEnabled);
    },
  },
  promptCacheHelpPath: helpPagePath('user/project/repository/code_suggestions/_index.md', {
    anchor: '#prompt-caching',
  }),
};
</script>
<template>
  <div v-if="arePromptCacheSettingsAllowed">
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="cacheEnabled"
      data-testid="use-prompt-cache-checkbox"
      :disabled="disabledCheckbox"
      @change="checkboxChanged"
    >
      <span id="duo-prompt-cache-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
      <template #help>
        <gl-sprintf :message="$options.i18n.checkboxHelpText">
          <template #link="{ content }">
            <gl-link :href="$options.promptCacheHelpPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-checkbox>
    <gl-popover v-if="disabledCheckbox" target="duo-prompt-cache-checkbox-label">
      <template #title>{{ $options.i18n.popoverTitle }}</template>
      <span data-testid="duo-prompt-cache-popover">
        {{ $options.i18n.popoverContent }}
      </span>
    </gl-popover>
  </div>
</template>
