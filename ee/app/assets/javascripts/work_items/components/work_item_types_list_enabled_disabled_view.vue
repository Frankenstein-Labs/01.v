<script>
import {
  GlLoadingIcon,
  GlAlert,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
  GlBadge,
  GlToastMixin,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import { n__, s__, sprintf } from '~/locale';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import workItemTypeAvailabilityToggleMutation from 'ee/work_items/graphql/work_item_type_availability_toggle.graphql';

export default {
  name: 'WorkItemTypesListEnabledDisabledView',
  components: {
    CrudComponent,
    WorkItemTypeIcon,
    GlLoadingIcon,
    GlAlert,
    GlButton,
    GlBadge,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      showDisabledTypes: false,
      errorMessage: '',
      workItemSettings: null,
      workItemTypes: [],
    };
  },
  apollo: {
    workItemSettings: {
      query() {
        return namespaceWorkItemSettingsQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data?.namespace?.workItemSettings;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
    workItemTypes: {
      query: workItemTypesConfigurationQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.workItemTypes?.nodes;
      },
      error(error) {
        this.errorMessage = s__('WorkItem|Failed to fetch work item types.');
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    canEnable() {
      return this.config?.enabledWorkItemTypeSettingsPermissions?.includes('enable');
    },
    canDisable() {
      return this.config?.enabledWorkItemTypeSettingsPermissions?.includes('disable');
    },
    customizableTypeVisibility() {
      return this.workItemSettings?.customizableTypeVisibility ?? false;
    },
    partitionedWorkItemTypes() {
      return (this.workItemTypes || [])
        .filter((type) => !type.archived)
        .reduce(
          (acc, item) => {
            acc[item.enabled === false ? 'disabled' : 'enabled'].push(item);
            return acc;
          },
          { enabled: [], disabled: [] },
        );
    },
    enabledWorkItemTypes() {
      return this.partitionedWorkItemTypes.enabled;
    },
    disabledWorkItemTypes() {
      return this.partitionedWorkItemTypes.disabled;
    },
    disabledTypesLabel() {
      const count = this.disabledWorkItemTypes.length;
      return n__('WorkItem|%d disabled type', 'WorkItem|%d disabled types', count);
    },
    isLoading() {
      return (
        this.$apollo.queries.workItemTypes.loading || this.$apollo.queries.workItemSettings.loading
      );
    },
  },
  methods: {
    getTooltipText(item) {
      const baseMessage = s__(
        'WorkItem|This is a system type that cannot be renamed, disabled, or deleted.',
      );

      let additionalText = '';

      if (item.isServiceDesk) {
        additionalText = s__('WorkItem|Usage is controlled by the Service Desk feature.');
      } else if (item.isGroupWorkItemType) {
        additionalText = s__('WorkItem|Usage is limited to groups.');
      } else if (item.isIncidentManagement) {
        additionalText = s__('WorkItem|Usage is controlled by the Monitor feature.');
      }

      return additionalText ? `${baseMessage} ${additionalText}` : baseMessage;
    },
    showDropdown(item) {
      return item.isConfigurable && (this.showEnableAction(item) || this.showDisableAction(item));
    },
    showEnableAction(item) {
      return this.customizableTypeVisibility && this.canEnable && !item.enabled && !item.archived;
    },
    showDisableAction(item) {
      return this.customizableTypeVisibility && this.canDisable && item.enabled && !item.archived;
    },
    async toggleWorkItemTypeAvailability(workItemType, enabled) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: workItemTypeAvailabilityToggleMutation,
          variables: {
            input: {
              workItemTypeId: workItemType.id,
              action: enabled ? 'ENABLE' : 'DISABLE',
              scope: 'THIS',
              fullPath: this.fullPath,
            },
          },
        });

        const { errors } = data?.workItemAvailabilityToggle || {};

        if (errors?.length) {
          throw new Error(errors.join(', '));
        }

        const toastMessage = enabled
          ? sprintf(s__('WorkItem|%{workItemType} enabled.'), { workItemType: workItemType.name })
          : sprintf(s__('WorkItem|%{workItemType} disabled.'), { workItemType: workItemType.name });
        this.$toast.show(toastMessage);
      } catch (error) {
        this.errorMessage =
          error.message || s__('WorkItem|Failed to update work item type availability.');
        Sentry.captureException(error);
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="errorMessage" variant="danger" class="gl-mb-5" @dismiss="errorMessage = ''">
      {{ errorMessage }}
    </gl-alert>

    <gl-loading-icon v-if="isLoading" size="lg" />
    <div v-else>
      <!-- Enabled Types Section -->
      <crud-component :title="s__('WorkItem|Enabled types')" title-tag="h3">
        <div class="-gl-my-4" data-testid="enabled-work-item-types-table">
          <div
            v-for="item in enabledWorkItemTypes"
            :key="item.id"
            class="gl-border-b gl-flex gl-justify-between gl-gap-4 gl-border-b-subtle gl-py-4 last:gl-border-b-0"
            :data-testid="`work-item-type-row-${item.id}`"
          >
            <!-- Type Column -->
            <div class="gl-flex gl-items-center gl-gap-2">
              <work-item-type-icon
                :work-item-type="item.name"
                :type-icon-name="item.iconName"
                class="gl-font-semibold gl-text-default"
                icon-class="gl-flex-shrink-0 gl-mr-2"
                show-text
                icon-variant="subtle"
              />
              <gl-badge
                v-if="!item.isConfigurable"
                v-gl-tooltip
                icon="lock"
                :data-testid="`locked-icon-${item.id}`"
                :title="getTooltipText(item)"
                :aria-label="getTooltipText(item)"
                class="gl-shrink-0"
              />
            </div>

            <!-- Options Column -->
            <gl-disclosure-dropdown
              v-if="showDropdown(item)"
              :toggle-id="`work-item-type-actions-${item.id}`"
              icon="ellipsis_v"
              no-caret
              text-sr-only
              :toggle-text="__('Actions')"
              category="tertiary"
            >
              <gl-disclosure-dropdown-item
                v-if="showDisableAction(item)"
                :data-testid="`disable-action-${item.id}`"
                @action="toggleWorkItemTypeAvailability(item, false)"
              >
                <template #list-item>
                  {{ s__('WorkItem|Disable') }}
                </template>
              </gl-disclosure-dropdown-item>
            </gl-disclosure-dropdown>
          </div>
        </div>
      </crud-component>

      <!-- Disabled Types Section with Toggle Button -->
      <div v-if="disabledWorkItemTypes.length" class="gl-mt-6">
        <gl-button
          category="tertiary"
          size="small"
          class="gl-mb-3"
          data-testid="disabled-types-toggle-button"
          :icon="showDisabledTypes ? 'chevron-down' : 'chevron-right'"
          :aria-expanded="showDisabledTypes"
          @click="showDisabledTypes = !showDisabledTypes"
        >
          {{ disabledTypesLabel }}
        </gl-button>

        <crud-component
          v-if="showDisabledTypes"
          :title="s__('WorkItem|Disabled types')"
          :description="s__('WorkItem|Cannot be used to create new items.')"
        >
          <div class="-gl-my-4" data-testid="disabled-work-item-types-table">
            <div
              v-for="item in disabledWorkItemTypes"
              :key="item.id"
              class="gl-border-b gl-flex gl-justify-between gl-gap-4 gl-border-b-subtle gl-py-4 last:gl-border-b-0"
              :data-testid="`work-item-type-row-${item.id}`"
            >
              <!-- Type Column -->
              <div class="gl-flex gl-items-center gl-gap-2">
                <work-item-type-icon
                  :work-item-type="item.name"
                  :type-icon-name="item.iconName"
                  class="gl-font-semibold gl-text-default"
                  icon-class="gl-flex-shrink-0 gl-mr-2"
                  show-text
                  icon-variant="subtle"
                />

                <gl-badge
                  v-if="!item.isConfigurable"
                  v-gl-tooltip
                  icon="lock"
                  :data-testid="`locked-icon-${item.id}`"
                  :title="getTooltipText(item)"
                  :aria-label="getTooltipText(item)"
                  class="gl-shrink-0"
                />
              </div>

              <!-- Options Column -->
              <gl-disclosure-dropdown
                v-if="showDropdown(item)"
                :toggle-id="`work-item-type-actions-${item.id}`"
                icon="ellipsis_v"
                no-caret
                text-sr-only
                :toggle-text="__('Actions')"
                category="tertiary"
              >
                <gl-disclosure-dropdown-item
                  v-if="showEnableAction(item)"
                  :data-testid="`enable-action-${item.id}`"
                  @action="toggleWorkItemTypeAvailability(item, true)"
                >
                  <template #list-item>
                    {{ s__('WorkItem|Enable') }}
                  </template>
                </gl-disclosure-dropdown-item>
              </gl-disclosure-dropdown>
            </div>
          </div>
        </crud-component>
      </div>
    </div>
  </div>
</template>
