<script>
import { GlDisclosureDropdownGroup, GlDisclosureDropdownItem } from '@gitlab/ui';
import { generateAnalyticsDashboardLink } from '~/analytics/shared/utils';
import { OVERLAY_GOTO } from '~/super_sidebar/components/global_search/command_palette/constants';
import FrequentItem from '~/super_sidebar/components/global_search/components/frequent_item.vue';
import FrequentItemSkeleton from '~/super_sidebar/components/global_search/components/frequent_item_skeleton.vue';
import { TRACKING_ACTION_CLICK_DASHBOARD_ITEM } from './tracking';

export default {
  name: 'DashboardItemsList',
  i18n: {
    OVERLAY_GOTO,
  },
  components: {
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    FrequentItem,
    FrequentItemSkeleton,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    emptyStateText: {
      type: String,
      required: true,
    },
    groupName: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: false,
      default: () => [],
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    dashboardName: {
      type: String,
      required: true,
    },
    bordered: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    formattedItems() {
      return this.items.map((item) => {
        const dashboardHref = generateAnalyticsDashboardLink({
          namespacePath: item.fullPath,
          isGroup: this.isGroup,
          dashboardSlug: this.dashboardName,
        });

        return {
          forDropdown: {
            id: item.id,
            text: item.name,
            href: dashboardHref,
            extraAttrs: {
              'data-track-action': TRACKING_ACTION_CLICK_DASHBOARD_ITEM,
              'data-track-label': this.isGroup ? 'group' : 'project',
              'data-track-property': this.dashboardName,
            },
          },
          forRenderer: {
            id: item.id,
            title: item.name,
            subtitle: item.namespace,
            avatar: item.avatarUrl,
          },
        };
      });
    },
    showEmptyState() {
      return !this.loading && this.formattedItems.length === 0;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-group :bordered="bordered">
    <template #group-label>{{ groupName }}</template>

    <gl-disclosure-dropdown-item v-if="loading">
      <frequent-item-skeleton />
    </gl-disclosure-dropdown-item>
    <template v-else>
      <gl-disclosure-dropdown-item
        v-for="item of formattedItems"
        :key="item.forDropdown.id"
        :item="item.forDropdown"
        class="show-on-focus-or-hover--context show-focus-layover"
      >
        <template #list-item><frequent-item :item="item.forRenderer" /></template>
      </gl-disclosure-dropdown-item>
    </template>

    <gl-disclosure-dropdown-item v-if="showEmptyState" class="gl-cursor-text">
      <span class="gl-mx-3 gl-my-3 gl-text-sm gl-text-subtle">{{ emptyStateText }}</span>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown-group>
</template>
