<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlDropdownDivider } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { isSubGroup } from '../utils';
import {
  PROJECT_SECURITY_CONFIGURATION_PATH,
  PROJECT_VULNERABILITY_REPORT_PATH,
  GROUP_VULNERABILITY_REPORT_PATH,
} from '../constants';

export default {
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlDropdownDivider,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['canManageAttributes', 'canApplyProfiles'],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['open-scanners-drawer', 'open-attributes-drawer'],
  methods: {
    securityConfigurationPath(item) {
      if (!item?.webUrl) return '#';
      return `${item.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}`;
    },
    vulnerabilityReportPath(item) {
      if (!item?.webUrl) return '#';

      return isSubGroup(item)
        ? `${item.webUrl}${GROUP_VULNERABILITY_REPORT_PATH}`
        : `${item.webUrl}${PROJECT_VULNERABILITY_REPORT_PATH}`;
    },
    firstSectionActions(item) {
      const isGroup = isSubGroup(item);

      const items = [];

      if (this.glFeatures.securityScanProfilesFeature && this.canApplyProfiles) {
        if (isGroup) {
          items.push({
            text: s__('SecurityInventory|Manage security scanners for subgroup projects'),
            action: () => this.$emit('open-scanners-drawer', item.id),
          });
        }
      }

      return items;
    },
    secondSectionActions(item) {
      const hasWebUrl = Boolean(item?.webUrl);
      const isGroup = isSubGroup(item);

      const items = [];

      items.push({
        text: isGroup
          ? s__('SecurityInventory|View subgroup')
          : s__('SecurityInventory|View project'),
        href: hasWebUrl ? item.webUrl : '#',
      });
      items.push({
        text: s__('SecurityInventory|View vulnerability report'),
        href: this.vulnerabilityReportPath(item),
      });

      if (!isGroup) {
        items.push({
          text: s__('SecurityInventory|Manage security configuration'),
          href: this.securityConfigurationPath(item),
        });
        if (this.canManageAttributes) {
          items.push({
            text: s__('SecurityInventory|Edit security attributes'),
            action: () => this.$emit('open-attributes-drawer', item),
          });
        }
      }

      return items;
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    category="tertiary"
    variant="default"
    size="small"
    icon="ellipsis_v"
    no-caret
  >
    <gl-disclosure-dropdown-item
      v-for="(action, index) in firstSectionActions(item)"
      :key="`primary-action-${index}`"
      :item="action"
    />
    <gl-dropdown-divider v-if="firstSectionActions(item).length" />
    <gl-disclosure-dropdown-item
      v-for="(action, index) in secondSectionActions(item)"
      :key="`secondary-action-${index}`"
      :item="action"
    />
  </gl-disclosure-dropdown>
</template>
