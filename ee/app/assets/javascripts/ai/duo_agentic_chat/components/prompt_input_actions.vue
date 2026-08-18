<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlIcon, GlToggle } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';

export default {
  name: 'PromptInputActions',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlToggle,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    webSearchEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['update:web-search-enabled'],
  computed: {
    hasWebSearch() {
      return Boolean(this.glFeatures?.dapWebSearch);
    },
  },
  methods: {
    toggleWebSearch() {
      this.$emit('update:web-search-enabled', !this.webSearchEnabled);
    },
  },
  i18n: {
    MORE_ACTIONS: s__('DuoAgenticChat|More actions'),
    WEB_SEARCH: s__('DuoAgenticChat|Web search'),
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    v-if="hasWebSearch"
    icon="plus"
    category="tertiary"
    positioning-strategy="fixed"
    no-caret
    :auto-close="false"
    :disabled="disabled"
    :toggle-text="$options.i18n.MORE_ACTIONS"
    text-sr-only
  >
    <gl-disclosure-dropdown-item data-testid="web-search-item" @action="toggleWebSearch">
      <template #list-item>
        <gl-toggle
          :value="webSearchEnabled"
          :label="$options.i18n.WEB_SEARCH"
          label-position="left"
          class="gl-w-full gl-justify-between"
          data-testid="web-search-toggle"
        >
          <template #label>
            <span class="gl-flex gl-items-center gl-gap-3">
              <gl-icon name="earth" variant="current" />
              {{ $options.i18n.WEB_SEARCH }}
            </span>
          </template>
        </gl-toggle>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
</template>
