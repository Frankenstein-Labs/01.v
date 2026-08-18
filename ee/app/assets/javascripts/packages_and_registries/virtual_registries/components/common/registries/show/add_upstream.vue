<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlSkeletonLoader,
} from '@gitlab/ui';

export default {
  name: 'AddUpstream',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlSkeletonLoader,
  },
  props: {
    disabled: {
      type: Boolean,
      default: false,
      required: false,
    },
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
    canLink: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  emits: ['create', 'link'],
  methods: {
    create() {
      this.$emit('create');
    },
    link() {
      this.$emit('link');
    },
  },
};
</script>

<template>
  <gl-skeleton-loader v-if="loading" :lines="1" :equal-width-lines="true" />
  <gl-disclosure-dropdown
    v-else-if="canLink"
    :disabled="disabled"
    size="small"
    placement="bottom-end"
    :toggle-text="s__('VirtualRegistry|Add upstream')"
  >
    <gl-disclosure-dropdown-item @action="create">
      <template #list-item>{{ s__('VirtualRegistry|Create new upstream') }}</template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item @action="link">
      <template #list-item>{{ s__('VirtualRegistry|Link existing upstream') }}</template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
  <gl-button v-else :disabled="disabled" size="small" @click="create">
    {{ s__('VirtualRegistry|Add upstream') }}
  </gl-button>
</template>
