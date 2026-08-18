<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlBadge,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __, s__, sprintf, n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { InternalEvents } from '~/tracking';
import AiCatalogItemUserAttribution from 'ee/ai/catalog/components/ai_catalog_item_user_attribution.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import { resolveVersion, isGitLabMaintainedItem } from '../utils';
import {
  isAiCatalogItemEnabledInGroup,
  isAiCatalogItemEnabledInProject,
  getAiCatalogItemVisibilityLevel,
} from '../capabilities';
import {
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_CONSUMER_TYPE_PROJECT,
  AI_CATALOG_CONSUMER_TYPE_GROUP,
  AI_CATALOG_CONSUMER_LABELS,
  TRACK_EVENT_DISABLE_AI_CATALOG_ITEM,
  TRACK_EVENT_ITEM_TYPES,
  TRACK_EVENT_ORIGIN_PROJECT,
  TRACK_EVENT_ORIGIN_GROUP,
  TRACK_EVENT_PAGE_LIST,
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
} from '../constants';
import { getRegistryItem } from '../item_type_registry';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    AiCatalogItemUserAttribution,
    GlBadge,
    GlIcon,
    FoundationalIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  mixins: [InternalEvents.mixin(), glFeatureFlagsMixin()],
  inject: {
    isGlobalNamespace: {},
    isProjectNamespace: {},
    isGroupNamespace: {},
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
    },
  },
  emits: ['disable'],
  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    targetType() {
      return this.isProjectNamespace
        ? AI_CATALOG_CONSUMER_TYPE_PROJECT
        : AI_CATALOG_CONSUMER_TYPE_GROUP;
    },
    resolvedVersionKey() {
      return resolveVersion(this.item, {
        isGlobalNamespace: this.isGlobalNamespace,
        isGroupNamespace: this.isGroupNamespace,
      }).key;
    },
    targetTypeLabel() {
      return AI_CATALOG_CONSUMER_LABELS[this.targetType];
    },
    actionItems() {
      return this.itemTypeConfig.actionItems?.(this.item) || [];
    },
    showDisableAction() {
      return this.itemTypeConfig.disableActionItem?.showActionItem?.(this.item);
    },
    hasActionItems() {
      return this.actionItems.length > 0;
    },
    showActions() {
      return this.showDisableAction || this.hasActionItems;
    },
    formattedItemId() {
      return getIdFromGraphQLId(this.item.id);
    },
    isFoundationalAgent() {
      return this.item.itemType === AI_CATALOG_TYPE_FOUNDATIONAL_AGENT;
    },
    showItemRoute() {
      const { routes } = getRegistryItem(this.item.itemType);

      return this.isFoundationalAgent
        ? { name: routes.show, params: { reference: this.item.reference } }
        : { name: routes.show, params: { id: this.formattedItemId } };
    },
    disableActionItem() {
      return this.itemTypeConfig.disableActionItem.text || __('Disable');
    },
    visibilityLevel() {
      return getAiCatalogItemVisibilityLevel(this.item, this.glFeatures);
    },
    visibilityIconName() {
      return VISIBILITY_TYPE_ICON[this.visibilityLevel];
    },
    visibilityTooltip() {
      return this.itemTypeConfig.visibilityTooltip?.[this.visibilityLevel];
    },
    visibilityLevelLabel() {
      return VISIBILITY_LEVEL_LABELS[this.visibilityLevel];
    },
    isSourceProjectNull() {
      return !this.item.project?.nameWithNamespace;
    },
    sourceProjectName() {
      return this.isSourceProjectNull
        ? s__('AICatalog|Private')
        : this.item.project?.nameWithNamespace;
    },
    sourceProjectTooltip() {
      return this.isSourceProjectNull
        ? s__("AICatalog|Managed by a private project you don't have access to.")
        : this.item.project?.nameWithNamespace;
    },
    isGitLabMaintained() {
      return isGitLabMaintainedItem(this.item);
    },
    isThirdPartyFlow() {
      return this.item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    statusBadge() {
      if (!this.itemTypeConfig.showStatusBadge || isAiCatalogItemEnabledInProject(this.item)) {
        return null;
      }
      const isEnabledInGroup = isAiCatalogItemEnabledInGroup(this.item);
      return {
        title: isEnabledInGroup
          ? s__('AICatalog|Ready to enable')
          : s__('AICatalog|Pending approval'),
        variant: isEnabledInGroup ? 'success' : 'warning',
        tooltipText: isEnabledInGroup
          ? sprintf(
              s__(
                'AICatalog|To use this %{itemType}, a user with at least the Maintainer role must enable it in this project.',
              ),
              {
                itemType: this.itemTypeLabel,
              },
            )
          : sprintf(
              s__(
                'AICatalog|To use this %{itemType}, a user with the Owner role must enable it in the top-level group.',
              ),
              {
                itemType: this.itemTypeLabel,
              },
            ),
      };
    },
    softDeletedTooltipText() {
      return sprintf(
        s__(
          'AICatalog|This %{itemType} was removed from the AI Catalog. You can still use it in this %{targetType}.',
        ),
        {
          itemType: this.itemTypeLabel,
          targetType: this.targetTypeLabel,
        },
      );
    },
    starCountAriaLabel() {
      return n__('%d star', '%d stars', this.item.starCount);
    },
    usageCountAriaLabel() {
      return n__('%d project', '%d projects', this.item.last30DayUsageCount);
    },
  },
  methods: {
    onClickDisable() {
      this.$emit('disable');
      this.trackEvent(TRACK_EVENT_DISABLE_AI_CATALOG_ITEM, {
        label: TRACK_EVENT_ITEM_TYPES[this.item.itemType],
        origin: this.isProjectNamespace ? TRACK_EVENT_ORIGIN_PROJECT : TRACK_EVENT_ORIGIN_GROUP,
        page: TRACK_EVENT_PAGE_LIST,
      });
    },
  },
};
</script>

<template>
  <li
    data-testid="ai-catalog-item"
    class="gl-border-b gl-relative gl-flex gl-grow gl-cursor-pointer gl-items-start gl-justify-between gl-p-4 gl-pt-5 gl-transition-background hover:gl-bg-subtle"
  >
    <div class="gl-flex gl-min-w-0 gl-flex-col gl-gap-3">
      <h2 class="gl-heading-5 gl-m-0 gl-line-clamp-2 gl-text-ellipsis gl-p-0 @sm:gl-line-clamp-1">
        <router-link
          class="!gl-text-default !gl-no-underline gl-stretched-link"
          :to="showItemRoute"
        >
          {{ item.name }}
        </router-link>

        <foundational-icon
          v-if="isGitLabMaintained"
          :item-type="item.itemType"
          :resource-id="item.id"
          :size="16"
          class="gl-relative gl-ml-1"
        />
      </h2>
      <div
        v-if="item.descriptionHtml"
        v-safe-html="item.descriptionHtml"
        class="md gl-m-0 gl-line-clamp-3 gl-text-ellipsis gl-p-0 gl-text-subtle @sm:gl-line-clamp-2 @md:gl-line-clamp-1"
      ></div>
      <p
        v-else
        class="gl-m-0 gl-line-clamp-3 gl-text-ellipsis gl-p-0 gl-text-subtle @sm:gl-line-clamp-2 @md:gl-line-clamp-1"
      >
        {{ item.description }}
      </p>
      <div class="gl-z-1 gl-flex gl-min-w-0 gl-flex-wrap gl-items-center gl-gap-x-4 gl-gap-y-2">
        <div
          v-if="!isGitLabMaintained"
          v-gl-tooltip
          :title="sourceProjectTooltip"
          data-testid="ai-catalog-item-source-project"
          class="gl-flex gl-min-w-0 gl-items-center gl-gap-2 gl-whitespace-nowrap"
        >
          <gl-icon name="project" variant="subtle" :size="14" class="gl-shrink-0" />
          <span class="gl-truncate gl-pt-px gl-text-subtle">
            {{ sprintf(s__('AICatalog|Project: %{label}'), { label: sourceProjectName }) }}
          </span>
        </div>
        <div
          v-if="visibilityTooltip"
          v-gl-tooltip
          :title="visibilityTooltip"
          data-testid="ai-catalog-item-visibility"
          class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
        >
          <gl-icon :name="visibilityIconName" variant="subtle" :size="14" />
          <span class="gl-pt-px gl-text-subtle">{{
            sprintf(s__('AICatalog|Visibility: %{label}'), { label: visibilityLevelLabel })
          }}</span>
        </div>
        <ai-catalog-item-user-attribution
          :item="item"
          :version-key="resolvedVersionKey"
          author-classes="gl-text-subtle"
        />
        <div
          v-if="isThirdPartyFlow"
          v-gl-tooltip
          :title="s__('AICatalog|Connects to an AI model provider outside GitLab.')"
          data-testid="ai-catalog-item-external"
          class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
        >
          <gl-icon name="connected" variant="subtle" :size="14" />
          <span class="gl-pt-px gl-text-subtle">{{ s__('AICatalog|External') }}</span>
        </div>
        <div
          v-if="item.isUpdateAvailable"
          v-gl-tooltip
          :title="
            s__(
              'AICatalog|A new version is available. If you have at least the Maintainer role, you can update this item.',
            )
          "
          data-testid="ai-catalog-item-update"
          class="gl-flex gl-items-center gl-gap-2 gl-whitespace-nowrap"
        >
          <router-link :to="showItemRoute">
            <gl-badge variant="info">{{ s__('AICatalog|Update available') }}</gl-badge>
          </router-link>
        </div>
        <div
          v-if="statusBadge"
          v-gl-tooltip
          :title="statusBadge.tooltipText"
          data-testid="ai-catalog-item-status-badge"
          class="gl-shrink-0 gl-whitespace-nowrap"
        >
          <gl-badge :variant="statusBadge.variant">{{ statusBadge.title }}</gl-badge>
        </div>
        <div
          v-if="item.softDeleted"
          v-gl-tooltip
          :title="softDeletedTooltipText"
          data-testid="ai-catalog-item-unlisted"
          class="gl-shrink-0 gl-whitespace-nowrap"
        >
          <gl-badge variant="warning">{{ s__('AICatalog|Unlisted') }}</gl-badge>
        </div>
      </div>
    </div>
    <div class="gl-z-1 gl-flex gl-shrink-0 gl-items-center gl-gap-3">
      <span
        v-gl-tooltip
        :title="
          s__('AICatalog|The number of projects that have used this item in the last 30 days.')
        "
        :aria-label="usageCountAriaLabel"
        class="gl-flex gl-items-center gl-gap-1 gl-text-subtle"
        data-testid="usage-count-display"
      >
        <gl-icon name="chart" :size="14" />
        <span>{{ item.last30DayUsageCount }}</span>
      </span>
      <span
        class="gl-flex gl-items-center gl-gap-1 gl-text-subtle"
        :aria-label="starCountAriaLabel"
        data-testid="star-count-display"
      >
        <gl-icon :name="item.starred ? 'star' : 'star-o'" :size="14" />
        <span>{{ item.starCount }}</span>
      </span>
      <gl-disclosure-dropdown
        v-if="showActions"
        :toggle-text="__('More actions')"
        category="tertiary"
        icon="ellipsis_v"
        class="gl-z-1"
        no-caret
        text-sr-only
      >
        <gl-disclosure-dropdown-group v-if="hasActionItems">
          <gl-disclosure-dropdown-item
            v-for="(actionItem, index) in actionItems"
            :key="index"
            :item="actionItem"
          >
            <template #list-item>
              <span>
                <gl-icon
                  :name="actionItem.icon"
                  class="gl-mr-2"
                  variant="subtle"
                  aria-hidden="true"
                />
                {{ actionItem.text }}
              </span>
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown-group>
        <gl-disclosure-dropdown-group v-if="showDisableAction" :bordered="hasActionItems">
          <gl-disclosure-dropdown-item data-testid="disable-button" @action="onClickDisable">
            <template #list-item>
              <span>
                <gl-icon name="cancel" class="gl-mr-2" variant="current" aria-hidden="true" />
                {{ disableActionItem }}
              </span>
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown-group>
      </gl-disclosure-dropdown>
    </div>
  </li>
</template>
