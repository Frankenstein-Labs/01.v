<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlFormRadioGroup,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { scrollTo } from '~/lib/utils/scroll_utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import {
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW,
} from 'ee/ai/catalog/constants';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import {
  denormalizeMergeRequestEventTypes,
  normalizeMergeRequestEventTypes,
} from 'ee/ai/duo_agents_platform/utils';
import getCatalogConsumerItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_catalog_consumer_items.query.graphql';
import projectServiceAccountsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_service_accounts.query.graphql';
import AiLegalDisclaimer from 'ee/ai/duo_agents_platform/components/common/ai_legal_disclaimer.vue';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';
import FlowTriggerConditions from './flow_trigger_conditions.vue';

const MODE_CREATE = 'create';
const MODE_EDIT = 'edit';

const CONFIG_MODE_CATALOG = 'catalog';
const CONFIG_MODE_FILE_PATH = 'manual';

export default {
  name: 'AiFlowTriggerForm',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlForm,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormInput,
    GlFormTextarea,
    UserSelect,
    ErrorsAlert,
    AiLegalDisclaimer,
    FormGroup,
    FlowTriggerConditions,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => [MODE_CREATE, MODE_EDIT].includes(mode),
    },
    errorMessages: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      validator(obj) {
        return [
          'description',
          'eventTypes',
          'filter',
          'configPath',
          'user',
          'aiCatalogItemConsumer',
        ].every((prop) => prop in obj);
      },
      default: () => {
        return {
          description: '',
          eventTypes: null,
          filter: {},
          configPath: '',
          user: null,
          aiCatalogItemConsumer: {},
        };
      },
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: String,
      required: true,
    },
  },
  emits: ['cancel', 'dismiss-errors', 'submit'],
  apollo: {
    catalogItems: {
      query: getCatalogConsumerItemsQuery,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          itemTypes: this.catalogItemTypes,
        };
      },
      skip() {
        return !this.isCatalogConfigModeAvailable;
      },
      update(data) {
        // Code Review foundational flow is invoked by assigning `@GitLabDuo` as a reviewer, not via user-defined triggers.
        return (
          data.aiCatalogConfiguredItems?.nodes
            ?.filter(
              (catalogItem) =>
                catalogItem.item.foundationalFlowReference !==
                FOUNDATIONAL_FLOW_REFERENCE_CODE_REVIEW,
            )
            ?.map((catalogItem) => ({
              id: catalogItem.id,
              name: catalogItem.item.name,
            })) || []
        );
      },
      error() {
        this.errors.push(
          s__(
            'DuoAgentsPlatform|An error occurred while fetching flows configured for this project.',
          ),
        );
      },
    },
  },
  data() {
    const isCatalogAvailable =
      this.glAbilities.readAiCatalogFlow || this.glAbilities.readAiCatalogThirdPartyFlow;
    const hasConsumerId = Boolean(this.initialValues.aiCatalogItemConsumer.id);
    const hasConfigPath = Boolean(this.initialValues.configPath);
    const useCatalogMode = isCatalogAvailable && (hasConsumerId || !hasConfigPath);

    const { eventTypes, filter } = normalizeMergeRequestEventTypes({
      eventTypes: this.initialValues.eventTypes,
      filter: this.initialValues.filter,
    });

    return {
      catalogItems: [],
      errors: [],
      configMode: useCatalogMode ? CONFIG_MODE_CATALOG : CONFIG_MODE_FILE_PATH,
      configPath: this.initialValues.configPath,
      description: this.initialValues.description,
      eventTypes,
      filter,
      isTriggerFilterValid: true,
      showEventTypesErrors: false,
      selectedFlow: this.initialValues.aiCatalogItemConsumer.id,
      selectedUsers: this.initialValues.user ? [{ ...this.initialValues.user }] : null,
    };
  },
  computed: {
    selectedUsersFieldValue() {
      return this.selectedUsers || [];
    },
    catalogItemTypes() {
      const types = [];

      if (this.glAbilities.readAiCatalogFlow) {
        types.push(AI_CATALOG_TYPE_FLOW);
      }

      if (this.glAbilities.readAiCatalogThirdPartyFlow) {
        types.push(AI_CATALOG_TYPE_THIRD_PARTY_FLOW);
      }

      return types;
    },
    isCatalogConfigModeAvailable() {
      return this.catalogItemTypes.length > 0;
    },
    isCatalogConfigMode() {
      return this.configMode === CONFIG_MODE_CATALOG;
    },
    isConfigurationSourceToggleAvailable() {
      return this.isCatalogConfigModeAvailable && this.glAbilities.createAiCatalogThirdPartyFlow;
    },
    catalogConfigModeTexts() {
      if (this.glAbilities.readAiCatalogFlow && this.glAbilities.readAiCatalogThirdPartyFlow) {
        return {
          label: s__('AICatalog|Flow or external agent'),
          placeholder: s__('AICatalog|Select flow or external agent'),
        };
      }

      if (this.glAbilities.readAiCatalogFlow) {
        return {
          label: s__('AICatalog|Flow'),
          placeholder: s__('AICatalog|Select flow'),
        };
      }

      if (this.glAbilities.readAiCatalogThirdPartyFlow) {
        return {
          label: s__('AICatalog|External agent'),
          placeholder: s__('AICatalog|Select external agent'),
        };
      }

      return {};
    },
    isEditMode() {
      return this.mode === MODE_EDIT;
    },
    submitButtonText() {
      return this.isEditMode
        ? s__('DuoAgentsPlatform|Save changes')
        : s__('DuoAgentsPlatform|Create trigger');
    },
    selectedEventTypeValues() {
      return (this.eventTypes || [])
        .map((valueInt) => FLOW_TRIGGER_TYPES.find((type) => type.valueInt === valueInt)?.value)
        .filter(Boolean);
    },
    selectedUserName() {
      return this.selectedUsers?.length > 0
        ? this.selectedUsers[0].name
        : s__('DuoAgentsPlatform|Select a service account');
    },
    selectedCatalogItem() {
      return this.catalogItems.find((item) => {
        return item.id === this.selectedFlow;
      });
    },
    catalogItemOptions() {
      return this.catalogItems.map((catalogConsumerItem) => ({
        value: catalogConsumerItem.id,
        text: catalogConsumerItem.name,
      }));
    },
    selectedFlowText() {
      return this.selectedCatalogItem?.name ?? this.catalogConfigModeTexts.placeholder;
    },
    fields() {
      return {
        description: {
          id: 'trigger-description',
          label: s__('DuoAgentsPlatform|Description'),
          validations: {
            requiredLabel: s__('DuoAgentsPlatform|Description is required.'),
          },
          inputAttrs: {
            placeholder: s__('DuoAgentsPlatform|Enter a description for this trigger'),
          },
        },
        serviceAccount: {
          id: 'trigger-owner',
          label: s__('DuoAgentsPlatform|Service account'),
          groupAttrs: {
            labelDescription: s__(
              'DuoAgentsPlatform|Ensure the service account has a role equal to or less than the users in the project. The account can be used for triggers only.',
            ),
          },
          validations: {
            requiredLabel: s__('DuoAgentsPlatform|Service account is required.'),
          },
        },
        configPath: {
          id: 'trigger-config-path',
          label: s__('DuoAgentsPlatform|Configuration path'),
          groupAttrs: {
            labelDescription: s__('DuoAgentsPlatform|Enter the path to your configuration file.'),
          },
          validations: {
            requiredLabel: s__('DuoAgentsPlatform|Configuration path is required.'),
          },
          inputAttrs: {
            placeholder: s__('DuoAgentsPlatform|Path to configuration file'),
          },
        },
        catalogItem: {
          id: 'trigger-agent',
          label: this.catalogConfigModeTexts.label,
          groupAttrs: { labelDescription: this.catalogConfigModeTexts.labelDescription },
          validations: { requiredLabel: s__('DuoAgentsPlatform|Target is required.') },
        },
      };
    },
  },
  watch: {
    async errorMessages(newValue) {
      if (newValue.length === 0) {
        return;
      }
      scrollTo(
        {
          top: 0,
          left: 0,
          behavior: 'smooth',
        },
        this.$el,
      );
    },
    selectedUsersFieldValue() {
      this.$nextTick(() => {
        this.$refs.fieldServiceAccount?.validate();
      });
    },
    configMode() {
      this.$nextTick(() => {
        this.$refs.fieldConfigPath?.reset();
        this.$refs.fieldServiceAccount?.reset();
        this.$refs.fieldCatalogItem?.reset();
      });
    },
  },
  methods: {
    setEventTypes(newStringValues) {
      this.eventTypes = newStringValues
        .map((value) => FLOW_TRIGGER_TYPES.find((type) => type.value === value)?.valueInt)
        // Drops both unknown values and types with no id yet, so neither reaches the API.
        .filter((valueInt) => valueInt != null);
    },
    onUserSelect(users) {
      this.selectedUsers = users;
    },
    onUserSelectError() {
      this.errors.push(s__('DuoAgentsPlatform|An error occurred while fetching users.'));
    },
    setSelectedFlow(selectedValue) {
      this.selectedFlow = selectedValue;
    },
    validate() {
      this.showEventTypesErrors = true;
      const fieldsValid = Object.keys(this.$refs)
        .filter((key) => key.startsWith('field'))
        .reduce((allValid, key) => {
          if (this.$refs[key] == null) return allValid;
          const isFieldValid = this.$refs[key].validate();
          return allValid && isFieldValid;
        }, true);
      return fieldsValid && this.isTriggerFilterValid;
    },
    onSubmit() {
      const isFormValid = this.validate();
      if (!isFormValid) {
        return;
      }

      const { eventTypes, filter } = denormalizeMergeRequestEventTypes({
        eventTypes: this.eventTypes,
        filter: this.filter,
      });

      this.$emit('submit', {
        description: this.description.trim(),
        eventTypes,
        filter,
        userId:
          this.isCatalogConfigMode || !this.selectedUsers?.length ? null : this.selectedUsers[0].id,
        configPath: this.isCatalogConfigMode ? null : this.configPath.trim() || null,
        aiCatalogItemConsumerId: this.isCatalogConfigMode ? this.selectedFlow : null,
      });
    },
    usersProcessor(data) {
      // Suppress the Code Review foundational flow's service account — it's driven by `@GitLabDuo` reviewer assignment, not user-defined triggers.
      return (
        data.project?.projectMembers?.nodes
          ?.map(({ user }) => user)
          ?.filter((user) => !user?.username?.startsWith('duo-code-review-')) || []
      );
    },
    dismissErrors() {
      this.errors = [];
    },
  },
  projectServiceAccountsQuery,
  configModeOptions: [
    {
      value: CONFIG_MODE_CATALOG,
      label: s__('DuoAgentsPlatform|Flow or external agent'),
      help: s__('DuoAgentsPlatform|Select any flow or external agent enabled in this project.'),
    },
    {
      value: CONFIG_MODE_FILE_PATH,
      label: s__('DuoAgentsPlatform|Configuration path'),
      help: s__(
        'DuoAgentsPlatform|Specify the path to a YAML file that contains a flow definition.',
      ),
    },
  ],
};
</script>

<template>
  <div>
    <errors-alert :errors="errors" alert-class="gl-mb-3 gl-mt-5" @dismiss="dismissErrors" />
    <gl-alert
      v-if="errorMessages.length"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      data-testid="error-messages-alert"
      @dismiss="$emit('dismiss-errors')"
    >
      <ul class="!gl-mb-0 gl-pl-5">
        <li v-for="(errorMessage, index) in errorMessages" :key="index">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <gl-form class="gl-flex gl-grow gl-flex-col gl-gap-5" @submit.prevent="onSubmit">
      <form-group
        #default="{ state, blur }"
        ref="fieldDescription"
        :field="fields.description"
        :field-value="description"
      >
        <gl-form-textarea
          :id="fields.description.id"
          v-model="description"
          :placeholder="fields.description.inputAttrs.placeholder"
          rows="1"
          :state="state"
          @blur="blur"
        />
      </form-group>

      <div>
        <h2 class="gl-heading-3 gl-mb-1 gl-mt-3">{{ s__('DuoAgentsPlatform|Target') }}</h2>
        <p class="gl-text-subtle">
          {{ s__('DuoAgentsPlatform|What this trigger runs.') }}
        </p>
        <div class="gl-flex gl-flex-col gl-gap-6">
          <gl-form-group
            v-if="isConfigurationSourceToggleAvailable"
            :label="s__('DuoAgentsPlatform|Configuration source')"
            label-for="config-mode"
            class="!gl-mb-0"
          >
            <gl-form-radio-group
              id="config-mode"
              v-model="configMode"
              class="gl-flex gl-flex-wrap gl-gap-3"
            >
              <gl-form-radio
                v-for="option in $options.configModeOptions"
                :key="option.value"
                :value="option.value"
                class="gl-w-48"
              >
                {{ option.label }}
                <template #help>{{ option.help }}</template>
              </gl-form-radio>
            </gl-form-radio-group>
          </gl-form-group>

          <template v-if="isCatalogConfigMode">
            <form-group
              ref="fieldCatalogItem"
              #default="{ state, blur }"
              :field="fields.catalogItem"
              :field-value="selectedFlow"
              data-testid="trigger-agent-group"
            >
              <gl-collapsible-listbox
                :id="fields.catalogItem.id"
                :items="catalogItemOptions"
                :selected="selectedFlow"
                :toggle-text="selectedFlowText"
                :header-text="catalogConfigModeTexts.placeholder"
                :loading="$apollo.queries.catalogItems.loading"
                block
                panel-match-trigger-width
                toggle-class="gl-max-w-48"
                searchable
                data-testid="trigger-agent-listbox"
                :state="state"
                @change="blur"
                @select="setSelectedFlow"
              />
            </form-group>
          </template>
          <template v-else>
            <form-group
              #default="{ state, blur }"
              ref="fieldConfigPath"
              :field="fields.configPath"
              :field-value="configPath"
            >
              <gl-form-input
                :id="fields.configPath.id"
                v-model="configPath"
                :placeholder="fields.configPath.inputAttrs.placeholder"
                type="text"
                :state="state"
                @blur="blur"
              />
            </form-group>

            <form-group
              ref="fieldServiceAccount"
              :field="fields.serviceAccount"
              :field-value="selectedUsers"
            >
              <user-select
                :id="fields.serviceAccount.id"
                :value="selectedUsersFieldValue"
                :text="selectedUserName"
                :header-text="s__('DuoAgentsPlatform|Select a service account')"
                :full-path="projectPath"
                :allow-multiple-assignees="false"
                :custom-search-users-query="$options.projectServiceAccountsQuery"
                :custom-search-users-processor="usersProcessor"
                class="gl-w-full"
                @input="onUserSelect"
                @error="onUserSelectError"
              />
            </form-group>
          </template>
        </div>
      </div>

      <flow-trigger-conditions
        :item-type-label="s__('AICatalog|agent or flow')"
        :event-types="selectedEventTypeValues"
        :filter="filter"
        :show-errors="showEventTypesErrors"
        @update:event-types="setEventTypes"
        @update:filter="filter = $event"
        @update:filter-valid="isTriggerFilterValid = $event"
      />

      <div class="gl-flex gl-flex-wrap gl-gap-3">
        <gl-button
          :loading="isLoading"
          type="submit"
          variant="confirm"
          data-testid="trigger-submit-button"
          class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
        >
          {{ submitButtonText }}
        </gl-button>
        <gl-button
          :disabled="isLoading"
          class="gl-w-full @sm/panel:gl-w-auto"
          data-testid="trigger-cancel-button"
          @click="$emit('cancel')"
        >
          {{ __('Cancel') }}
        </gl-button>
      </div>
      <ai-legal-disclaimer />
    </gl-form>
  </div>
</template>
