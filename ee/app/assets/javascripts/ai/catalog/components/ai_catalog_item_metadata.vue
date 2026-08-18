<script>
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import AiCatalogItemUserAttribution from 'ee/ai/catalog/components/ai_catalog_item_user_attribution.vue';
import { s__ } from '~/locale';
import { getByVersionKey, isGitLabMaintainedItem } from 'ee/ai/catalog/utils';
import { AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';

export default {
  name: 'AiCatalogItemMetadata',
  components: {
    AiCatalogItemUserAttribution,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  computed: {
    activeVersion() {
      return getByVersionKey(this.item, this.versionKey);
    },
    metaData() {
      const items = [];

      if (isGitLabMaintainedItem(this.item)) {
        items.push({
          icon: 'tanuki-verified',
          text: s__('AICatalog|GitLab-managed'),
          testId: 'gitlab-maintained',
        });
      }

      if (this.item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW) {
        items.push({
          icon: 'connected',
          text: s__('AICatalog|External'),
          tooltip: s__('AICatalog|Connects to an AI model provider outside GitLab.'),
          testId: 'external',
        });
      }

      if (this.activeVersion?.humanVersionName) {
        items.push({
          icon: 'tag',
          text: this.activeVersion?.humanVersionName,
          testId: 'version',
        });
      }

      if (this.item.last30DayUsageCount !== undefined) {
        items.push({
          icon: 'chart',
          text: this.item.last30DayUsageCount,
          testId: 'usage-count',
          tooltip: s__(
            'AICatalog|The number of projects that have used this item in the last 30 days.',
          ),
        });
      }

      return items;
    },
  },
};
</script>

<template>
  <ul class="gl-my-2 gl-flex gl-list-none gl-flex-col gl-gap-x-5 gl-pl-0 sm:gl-mb-4 sm:gl-flex-row">
    <li>
      <ai-catalog-item-user-attribution :item="item" :version-key="versionKey" />
    </li>
    <li
      v-for="meta in metaData"
      :key="meta.testId"
      v-gl-tooltip="meta.tooltip"
      :data-testid="`metadata-${meta.testId}`"
    >
      <gl-icon :name="meta.icon" variant="subtle" />
      {{ meta.text }}
    </li>
  </ul>
</template>
