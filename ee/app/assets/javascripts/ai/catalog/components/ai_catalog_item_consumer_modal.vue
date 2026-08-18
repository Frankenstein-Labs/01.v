<script>
import { uniqueId } from 'lodash-es';
import { GlAlert, GlForm, GlFormGroup, GlModal, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, s__, sprintf } from '~/locale';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  FLOW_TRIGGER_TYPE_MENTION,
  FLOW_TRIGGER_TYPE_ASSIGN,
  FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER,
} from 'ee/ai/duo_agents_platform/constants';
import FlowTriggerEventsField from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_events_field.vue';
import {
  denormalizeMergeRequestEventTypes,
  eventTypeIntsToValues,
  eventTypeValuesToInts,
} from 'ee/ai/duo_agents_platform/utils';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_PROJECT_CONSUMER_LABEL_DESCRIPTION,
  AI_CATALOG_PROJECT_MULTI_CONSUMER_LABEL_DESCRIPTION,
  MAX_PROJECTS_BULK_ENABLE,
} from '../constants';
import { isAiCatalogItemRestricted } from '../capabilities';
import FormProjectMultiSelect from './form_project_multi_select.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import AiCatalogItemConsumerDisclaimer from './ai_catalog_item_consumer_disclaimer.vue';

const DEFAULT_TRIGGER_TYPES = [
  FLOW_TRIGGER_TYPE_MENTION.value,
  FLOW_TRIGGER_TYPE_ASSIGN.value,
  FLOW_TRIGGER_TYPE_ASSIGN_REVIEWER.value,
];

export default {
  name: 'AiCatalogItemConsumerModal',
  formId: uniqueId('ai-catalog-item-consumer-form-'),
  components: {
    FormProjectMultiSelect,
    FormProjectDropdown,
    FlowTriggerEventsField,
    GlAlert,
    GlForm,
    GlFormGroup,
    GlModal,
    GlSprintf,
    AiCatalogItemConsumerDisclaimer,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    isProjectNamespace: {},
    contextProjectId: {
      from: 'projectId',
      default: null,
    },
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
    modalId: {
      type: String,
      required: false,
      default: 'add-item-consumer-modal',
    },
    canEnable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['hide', 'submit'],
  data() {
    return {
      isOpen: this.open,
      projectId: null,
      projectIds: [],
      isDirty: false,
      error: null,
      triggerTypes: [],
      triggerFilter: {},
      isTriggerFilterValid: true,
      mountedAt: null,
    };
  },
  computed: {
    defaultProjectId() {
      if (this.isProjectNamespace) {
        return convertToGraphQLId(TYPENAME_PROJECT, this.contextProjectId);
      }
      return this.item.public ? null : this.item.project?.id;
    },
    showProjectSection() {
      return !this.isProjectNamespace;
    },
    modal() {
      return {
        actionPrimary: {
          text: __('Enable'),
          attributes: {
            variant: 'confirm',
            type: 'submit',
            form: this.$options.formId,
            disabled: !this.canEnable,
          },
        },
        actionCancel: {
          text: __('Cancel'),
        },
      };
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    title() {
      return sprintf(s__('AICatalog|Enable %{itemType} in your project'), {
        itemType: this.itemTypeLabel,
      });
    },
    isRestricted() {
      return isAiCatalogItemRestricted(this.item, this.glFeatures);
    },
    restrictedGroupName() {
      return this.item.project?.rootGroup?.fullName;
    },
    canEnableOnMultipleProjects() {
      return (
        (this.item.public || this.isRestricted) && this.glFeatures.aiCatalogBulkItemConsumerCreate
      );
    },
    projectLabelDescription() {
      return this.canEnableOnMultipleProjects
        ? AI_CATALOG_PROJECT_MULTI_CONSUMER_LABEL_DESCRIPTION[this.item.itemType]
        : AI_CATALOG_PROJECT_CONSUMER_LABEL_DESCRIPTION[this.item.itemType];
    },
    isProjectValid() {
      if (!this.isDirty) return true;
      return this.canEnableOnMultipleProjects
        ? this.projectIds.length > 0 && this.projectIds.length <= MAX_PROJECTS_BULK_ENABLE
        : Boolean(this.projectId);
    },
    projectInvalidFeedback() {
      if (!this.canEnableOnMultipleProjects) {
        return s__('AICatalog|Project is required.');
      }
      if (this.projectIds.length > MAX_PROJECTS_BULK_ENABLE) {
        return s__('AICatalog|Limit of 100 projects reached.');
      }
      return s__('AICatalog|At least one project is required.');
    },
    showStaticFields() {
      return !this.item.public && !this.isRestricted;
    },
    isFormValid() {
      return this.isProjectValid && this.hasSelectedTriggers && this.isTriggerFilterValid;
    },
    isFoundationalFlow() {
      return this.item.itemType === AI_CATALOG_TYPE_FLOW && this.item.foundational;
    },
    showTriggers() {
      if (this.isFoundationalFlow) {
        return false;
      }
      return [AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW].includes(this.item.itemType);
    },
    triggersLabelDescription() {
      return sprintf(
        s__(
          'AICatalog|Choose what events in this project trigger the %{itemType}. You can change this later.',
        ),
        { itemType: this.itemTypeLabel },
      );
    },
    hasSelectedTriggers() {
      return !this.showTriggers || !this.isDirty || this.triggerTypes.length > 0;
    },
  },
  watch: {
    defaultProjectId(newVal) {
      if (this.projectId == null && newVal) {
        this.projectId = newVal;
        Sentry.captureException(
          new Error('AiCatalogItemConsumerModal: project data arrived after mount'),
          {
            level: 'info',
            tags: {
              race_type: 'ai_catalog_project_field',
              item_type: this.item?.itemType,
            },
            extra: {
              item_id: this.item?.id,
              time_to_resolve_ms:
                this.mountedAt != null ? Math.round(performance.now() - this.mountedAt) : null,
            },
          },
        );
      }
    },
  },
  mounted() {
    this.mountedAt = performance.now();
    this.resetForm();
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isFormValid) {
        return;
      }
      this.isOpen = false;
      this.isDirty = false;

      let payload;

      if (this.canEnableOnMultipleProjects) {
        payload = { target: this.projectIds };
      } else {
        payload = { target: { projectId: this.projectId } };
      }

      if (this.showTriggers) {
        // The field consolidates merge_request_ready (4) and merge_request_code_conflict (5)
        // into merge_request (6) with an action filter. The backend dispatches ready/conflict
        // via separate event types, so split them back out before submitting.
        const { eventTypes, filter } = denormalizeMergeRequestEventTypes({
          eventTypes: eventTypeValuesToInts(this.triggerTypes),
          filter: this.triggerFilter,
        });

        payload.triggerTypes = eventTypeIntsToValues(eventTypes);
        if (Object.keys(filter).length > 0) {
          payload.triggerFilter = filter;
        }
      }

      this.$emit('submit', payload);
    },
    resetForm() {
      this.projectId = this.defaultProjectId;
      this.projectIds = [];
      this.isDirty = false;
      this.error = null;
      this.triggerTypes = [...DEFAULT_TRIGGER_TYPES];
      this.triggerFilter = {};
      this.isTriggerFilterValid = true;
    },
    onHidden() {
      this.resetForm();
      this.$emit('hide');
    },
  },
};
</script>

<template>
  <gl-modal
    v-model="isOpen"
    :modal-id="modalId"
    :title="title"
    :action-primary="modal.actionPrimary"
    :action-cancel="modal.actionCancel"
    @primary.prevent
    @hidden="onHidden"
  >
    <gl-alert
      v-if="error"
      data-testid="error-alert"
      variant="danger"
      class="gl-mb-5"
      @dismiss="error = null"
    >
      {{ error }}
    </gl-alert>

    <gl-alert
      v-if="!item.public && !isProjectNamespace && item.project && !isRestricted"
      data-testid="private-alert"
      :dismissible="false"
      variant="info"
      class="gl-mb-5"
    >
      <gl-sprintf
        :message="
          s__(
            'AICatalog|This %{itemType} is private and can only be enabled in the project it was created in or its top-level group. Duplicate the agent to use the same configuration in other projects.',
          )
        "
      >
        <template #itemType>{{ itemTypeLabel }}</template>
      </gl-sprintf>
    </gl-alert>

    <gl-alert
      v-if="isRestricted && !isProjectNamespace && item.project"
      data-testid="restricted-alert"
      :dismissible="false"
      variant="info"
      class="gl-mb-5"
    >
      <gl-sprintf
        :message="
          s__(
            'AICatalog|This %{itemType} can only be enabled in projects within the top-level group %{groupName}.',
          )
        "
      >
        <template #itemType>{{ itemTypeLabel }}</template>
        <template #groupName>{{ restrictedGroupName }}</template>
      </gl-sprintf>
    </gl-alert>

    <dl>
      <dt class="gl-mb-2 gl-font-bold">
        <gl-sprintf :message="s__('AICatalog|Selected %{itemType}')">
          <template #itemType>{{ itemTypeLabel }}</template>
        </gl-sprintf>
      </dt>
      <dd class="gl-break-all">{{ item.name }}</dd>
    </dl>

    <gl-form :id="$options.formId" @submit.prevent="handleSubmit">
      <template v-if="showProjectSection">
        <div v-if="showStaticFields && item.project">
          <dl>
            <dt class="gl-mb-2 gl-font-bold">{{ __('Project') }}</dt>
            <dd data-testid="project-name">{{ item.project.nameWithNamespace }}</dd>
          </dl>
        </div>
        <div v-else>
          <form-project-multi-select
            v-if="canEnableOnMultipleProjects"
            id="project-ids"
            v-model="projectIds"
            data-testid="project-multi-select"
            :is-valid="isProjectValid"
            :item-id="item.id"
            :project-label-description="projectLabelDescription"
            :project-invalid-feedback="projectInvalidFeedback"
            @error="onError"
          />
          <gl-form-group
            v-else
            :label="__('Project')"
            :label-description="projectLabelDescription"
            label-for="project-id"
            :state="isProjectValid"
            :invalid-feedback="projectInvalidFeedback"
          >
            <form-project-dropdown
              id="project-id"
              v-model="projectId"
              data-testid="project-dropdown"
              :disabled="!canEnable"
              :is-valid="isProjectValid"
              :item-id="item.id"
              @error="onError"
            />
          </gl-form-group>
        </div>
      </template>
      <gl-form-group
        v-if="showTriggers && canEnable"
        :label="s__('AICatalog|Add triggers')"
        :label-description="triggersLabelDescription"
        label-for="flow-triggers"
        :state="hasSelectedTriggers"
        :invalid-feedback="s__('AICatalog|Select at least one trigger.')"
      >
        <flow-trigger-events-field
          listbox-id="flow-triggers"
          :item-type-label="itemTypeLabel"
          :event-types="triggerTypes"
          :filter="triggerFilter"
          :state="hasSelectedTriggers"
          :show-errors="isDirty"
          @update:event-types="triggerTypes = $event"
          @update:filter="triggerFilter = $event"
          @update:filter-valid="isTriggerFilterValid = $event"
        />
      </gl-form-group>
    </gl-form>
    <ai-catalog-item-consumer-disclaimer :item-type="item.itemType" :can-enable="canEnable" />
  </gl-modal>
</template>
