<script>
import { GlDisclosureDropdown } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { __ } from '~/locale';

export default {
  name: 'GeoSiteActionsMobile',
  i18n: {
    toggleText: __('Actions'),
    editButtonLabel: __('Edit'),
    removeButtonLabel: __('Remove'),
  },
  components: {
    GlDisclosureDropdown,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  emits: ['remove'],
  computed: {
    ...mapGetters(['canRemoveSite']),
    dropdownItems() {
      return [
        {
          text: this.$options.i18n.editButtonLabel,
          href: this.site.webEditUrl,
        },
        {
          text: this.$options.i18n.removeButtonLabel,
          action: () => {
            this.$emit('remove');
          },
          extraAttrs: {
            'data-testid': 'geo-mobile-remove-action',
            class: this.dropdownRemoveClass,
            disabled: !this.canRemoveSite(this.site.id),
          },
        },
      ];
    },
    dropdownRemoveClass() {
      return this.canRemoveSite(this.site.id) ? '!gl-text-danger' : '!gl-text-disabled';
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    icon="ellipsis_v"
    :toggle-text="$options.i18n.toggleText"
    text-sr-only
    category="tertiary"
    no-caret
    :items="dropdownItems"
  />
</template>
