<script>
import { GlButton, GlIcon, GlLoadingIcon, GlModal, GlAlert } from '@gitlab/ui';
import { produce } from 'immer';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__ } from '~/locale';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';
import updateWorkItemSettingsMutation from 'ee/work_items/graphql/update_work_item_settings.mutation.graphql';

export default {
  actionCancel: {
    text: __('Cancel'),
  },
  actionPrimary: {
    text: __('Disable'),
    attributes: {
      variant: 'confirm',
    },
  },
  name: 'WorkItemTypesCustomization',
  components: {
    GlButton,
    GlIcon,
    GlLoadingIcon,
    GlModal,
    GlAlert,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      workItemSettings: null,
      showModal: false,
      errorMessage: '',
    };
  },
  apollo: {
    workItemSettings: {
      query() {
        return this.fullPath ? namespaceWorkItemSettingsQuery : orgWorkItemSettingsQuery;
      },
      variables() {
        return this.fullPath ? { fullPath: this.fullPath } : {};
      },
      update(data) {
        if (!data) {
          return this.workItemSettings;
        }
        const settings = this.fullPath
          ? data?.namespace?.workItemSettings
          : data?.organization?.workItemSettings;
        return settings || this.workItemSettings;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    enabled() {
      return this.workItemSettings?.customizableTypeVisibility ?? false;
    },
    isLoading() {
      return this.$apollo.queries.workItemSettings.loading;
    },
    buttonText() {
      return this.enabled ? s__('WorkItem|Disable') : s__('WorkItem|Enable');
    },
    statusIcon() {
      return this.enabled ? 'check' : 'cancel';
    },
    statusText() {
      return this.enabled ? s__('WorkItem|Enabled') : s__('WorkItem|Disabled');
    },
    statusTextColor() {
      return this.enabled ? 'gl-text-success' : 'gl-text-danger';
    },
  },
  methods: {
    async handleClick() {
      if (this.enabled) {
        this.showModal = true;
      } else {
        await this.updateCustomizableTypeVisibility(true);
      }
    },
    async handleModal() {
      await this.updateCustomizableTypeVisibility(false);
    },
    async updateCustomizableTypeVisibility(customizableTypeVisibility) {
      // Clear any previous errors
      this.errorMessage = '';

      try {
        const variableInput = this.fullPath
          ? { fullPath: this.fullPath, customizableTypeVisibility }
          : { customizableTypeVisibility };

        const { data } = await this.$apollo.mutate({
          mutation: updateWorkItemSettingsMutation,
          variables: {
            input: {
              ...variableInput,
            },
          },
          update: (cache, { data: responseData }) => {
            const updatedSettings = responseData?.workItemSettingsUpdate?.workItemSettings;
            const responseErrors = responseData?.workItemSettingsUpdate?.errors;

            if (!updatedSettings || responseErrors?.length) return;

            this.updateWorkItemSettingsCache(cache, updatedSettings);
          },
        });

        const { errors, workItemSettings } = data?.workItemSettingsUpdate || {};

        if (errors && errors.length > 0) {
          const errorMessage = errors.join(', ');
          this.errorMessage = errorMessage;
          Sentry.captureException(new Error(`Work item settings update failed: ${errorMessage}`));
          return;
        }

        this.workItemSettings = workItemSettings ?? this.workItemSettings;
        this.showModal = false;
      } catch (error) {
        const errorMessage =
          error.message || s__('WorkItem|An error occurred while updating work item settings.');
        this.errorMessage = errorMessage;
        Sentry.captureException(error);
      }
    },
    updateWorkItemSettingsCache(cache, updatedSettings) {
      const queryArgs = this.fullPath
        ? {
            query: namespaceWorkItemSettingsQuery,
            variables: { fullPath: this.fullPath },
          }
        : { query: orgWorkItemSettingsQuery };

      let sourceData;
      try {
        sourceData = cache.readQuery(queryArgs);
      } catch (error) {
        // Query not in cache yet, skip update
        return;
      }
      if (!sourceData) return;

      const updatedData = produce(sourceData, (draft) => {
        const parent = this.fullPath ? draft.namespace : draft.organization;
        if (parent?.workItemSettings) {
          parent.workItemSettings.customizableTypeVisibility =
            updatedSettings.customizableTypeVisibility;
        }
      });

      cache.writeQuery({ ...queryArgs, data: updatedData });
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      class="gl-mb-5"
      :dismissible="true"
      data-testid="work-item-types-customization-error-alert"
      @dismiss="errorMessage = ''"
    >
      {{ errorMessage }}
    </gl-alert>
    <div
      class="gl-border gl-mb-5 gl-flex gl-items-center gl-justify-between gl-gap-3 gl-rounded-xl gl-bg-subtle gl-p-4"
    >
      <div>
        <h3 class="gl-m-0 gl-mb-1 gl-text-base">
          {{ s__('WorkItem|Type customization in projects') }}
        </h3>
        <span class="gl-text-subtle">
          {{ s__('WorkItem|Allow types to be disabled in projects.') }}
        </span>
      </div>
      <div
        class="gl-flex gl-items-center gl-whitespace-nowrap"
        :class="statusTextColor"
        data-testid="status-block"
      >
        <gl-loading-icon v-if="isLoading" size="sm" class="gl-mr-2" inline />
        <template v-else>
          <gl-icon class="gl-mr-2" :name="statusIcon" />
          {{ statusText }}
        </template>
        <gl-button class="gl-ml-4" size="small" :disabled="isLoading" @click="handleClick">
          {{ buttonText }}
        </gl-button>
      </div>
      <gl-modal
        v-model="showModal"
        :action-cancel="$options.actionCancel"
        :action-primary="$options.actionPrimary"
        modal-id="type-customization-modal"
        :title="s__('WorkItem|Disable type customization in projects')"
        @primary="handleModal"
      >
        {{
          s__(
            'WorkItem|All available types will be enabled in all groups and projects. Re-enabling this setting later will return each group or project to its current configuration.',
          )
        }}
      </gl-modal>
    </div>
  </div>
</template>
