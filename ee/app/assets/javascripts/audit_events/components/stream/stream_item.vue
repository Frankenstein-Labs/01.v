<script>
import {
  GlAlert,
  GlBadge,
  GlLink,
  GlPopover,
  GlSprintf,
  GlCollapse,
  GlIcon,
  GlButton,
  GlToggle,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import {
  STREAM_ITEMS_I18N,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
  UPDATE_STREAM_MESSAGE,
} from '../../constants';

import groupAuditEventStreamingDestinationsUpdate from '../../graphql/mutations/update_group_streaming_destination.mutation.graphql';
import instanceAuditEventStreamingDestinationsUpdate from '../../graphql/mutations/update_instance_streaming_destination.mutation.graphql';

import StreamDestinationEditor from './stream_destination_editor.vue';

export default {
  name: 'StreamItem',
  components: {
    GlAlert,
    GlBadge,
    GlLink,
    GlPopover,
    GlSprintf,
    GlCollapse,
    GlButton,
    GlIcon,
    GlToggle,
    StreamDestinationEditor,
  },
  directives: {
    GlTooltip,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['deleted', 'error', 'updated'],
  data() {
    return {
      isEditing: false,
      successMessage: null,
      isUpdatingActive: false,
      destinationActive: this.item.active !== false,
    };
  },
  computed: {
    isItemFiltered() {
      return (
        Boolean(this.item?.eventTypeFilters?.length) || Boolean(this.item?.namespaceFilters?.length)
      );
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationTitle() {
      return this.item.name;
    },
    filterTooltipLink() {
      if (this.isInstance) {
        return this.$options.i18n.FILTER_TOOLTIP_ADMIN_LINK;
      }
      return this.$options.i18n.FILTER_TOOLTIP_GROUP_LINK;
    },
    activeToggleLabel() {
      return this.destinationActive ? __('Active') : __('Inactive');
    },
  },
  watch: {
    'item.active': {
      handler(newVal) {
        this.destinationActive = newVal !== false;
      },
      immediate: true,
    },
  },
  methods: {
    toggleEditMode() {
      this.isEditing = !this.isEditing;

      if (!this.isEditing) {
        this.clearSuccessMessage();
      }
    },
    onUpdated() {
      this.successMessage = UPDATE_STREAM_MESSAGE;
      this.$emit('updated');
    },
    onDelete($event) {
      this.$emit('deleted', $event);
    },
    onEditorError() {
      this.clearSuccessMessage();
      this.$emit('error');
    },
    clearSuccessMessage() {
      this.successMessage = null;
    },
    async toggleActive(newActiveState) {
      this.isUpdatingActive = true;

      try {
        await this.updateDestinationActive(newActiveState);
        this.handleToggleSuccess(newActiveState);
      } catch (error) {
        this.handleToggleError(error, newActiveState);
      } finally {
        this.isUpdatingActive = false;
      }
    },
    async updateDestinationActive(newActiveState) {
      await this.toggleActiveConsolidatedApi(newActiveState);
    },
    handleToggleSuccess(newActiveState) {
      this.destinationActive = newActiveState;
      this.successMessage = newActiveState
        ? __('Destination activated successfully.')
        : __('Destination deactivated successfully.');
      this.$emit('updated');
    },
    handleToggleError(error, newActiveState) {
      Sentry.captureException(error);

      const { message = '' } = error || {};
      const hasSpecificMessage = /(Cannot activate|Maximum number)/.test(message);

      createAlert({
        message: hasSpecificMessage
          ? message
          : __('Failed to update destination status. Please try again.'),
        captureError: true,
        error,
      });
      this.destinationActive = !newActiveState;
    },
    async executeMutation(mutation, variables, resultPath) {
      const { data } = await this.$apollo.mutate({
        mutation,
        variables,
      });

      const result = data[resultPath];

      if (result.errors?.length) {
        throw new Error(result.errors.join(', '));
      }
    },
    async toggleActiveConsolidatedApi(newActiveState) {
      const mutation = this.isInstance
        ? instanceAuditEventStreamingDestinationsUpdate
        : groupAuditEventStreamingDestinationsUpdate;

      const resultPath = this.isInstance
        ? 'instanceAuditEventStreamingDestinationsUpdate'
        : 'groupAuditEventStreamingDestinationsUpdate';

      const variables = {
        input: {
          id: this.item.id,
          name: this.item.name,
          config: {
            ...this.item.config,
          },
          active: newActiveState,
        },
      };

      await this.executeMutation(mutation, variables, resultPath);
    },
  },
  i18n: { ...STREAM_ITEMS_I18N },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <li class="list-item !gl-py-0">
    <div class="gl-flex gl-items-center gl-justify-between gl-py-6">
      <gl-button
        variant="link"
        class="gl-min-w-0 gl-font-bold !gl-text-default"
        :class="{ 'gl-opacity-60': !destinationActive }"
        :aria-expanded="isEditing"
        :aria-disabled="!destinationActive || isUpdatingActive"
        :disabled="isUpdatingActive"
        data-testid="toggle-btn"
        @click="toggleEditMode"
      >
        <gl-icon
          name="chevron-right"
          class="gl-transition-all"
          :class="{ 'gl-rotate-90': isEditing }"
        /><span class="gl-ml-2 gl-text-lg">{{ destinationTitle }}</span>
      </gl-button>

      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-toggle
          :value="destinationActive"
          :label="activeToggleLabel"
          :is-loading="isUpdatingActive"
          :disabled="isUpdatingActive"
          label-position="left"
          data-testid="destination-active-toggle"
          @change="toggleActive"
        />

        <template v-if="isItemFiltered">
          <gl-popover :target="item.id" data-testid="filter-popover">
            <gl-sprintf :message="$options.i18n.FILTER_TOOLTIP_LABEL">
              <template #link="{ content }">
                <gl-link :href="filterTooltipLink" target="_blank">
                  {{ content }}
                </gl-link>
              </template>
            </gl-sprintf>
          </gl-popover>
          <gl-badge :id="item.id" icon="filter" variant="neutral" data-testid="filter-badge">
            {{ $options.i18n.FILTER_BADGE_LABEL }}
          </gl-badge>
        </template>
      </div>
    </div>
    <gl-collapse :visible="isEditing">
      <gl-alert
        v-if="successMessage"
        :dismissible="true"
        class="gl-mb-6 gl-ml-6"
        variant="success"
        @dismiss="clearSuccessMessage"
      >
        {{ successMessage }}
      </gl-alert>
      <stream-destination-editor
        :item="item"
        class="gl-pb-5 gl-pl-6 gl-pr-0"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
    </gl-collapse>
  </li>
</template>
