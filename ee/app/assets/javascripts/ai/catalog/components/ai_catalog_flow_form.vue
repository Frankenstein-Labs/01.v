<script>
import { uniqueId } from 'lodash-es';
import {
  GlButton,
  GlForm,
  GlFormInput,
  GlFormTextarea,
  GlAlert,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  AI_CATALOG_TYPE_FLOW,
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
  FLOW_VISIBILITY_LEVEL_DESCRIPTIONS,
  DEFAULT_FLOW_YML_STRING,
} from 'ee/ai/catalog/constants';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { AI_CATALOG_FLOWS_ROUTE, AI_CATALOG_FLOWS_SHOW_ROUTE } from '../router/constants';
import { getCancelRoute, getSubmitButtonText } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import FormProjectDropdown from './form_project_dropdown.vue';
import FormGroup from './form_group.vue';
import FormSection from './form_section.vue';
import VisibilityLevelRadioGroup from './visibility_level_radio_group.vue';

export default {
  name: 'AiCatalogFlowForm',
  components: {
    ErrorsAlert,
    AiCatalogFormButtons,
    FormFlowDefinition,
    FormProjectDropdown,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormTextarea,
    GlAlert,
    GlSprintf,
    GlLink,
    FormSection,
    FormGroup,
    VisibilityLevelRadioGroup,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    projectId: {
      default: null,
    },
    isGlobalNamespace: {},
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => ['edit', 'create'].includes(mode),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    errors: {
      type: Array,
      required: true,
    },
    initialValues: {
      type: Object,
      required: false,
      default() {
        return {
          projectId: null,
          name: '',
          description: '',
          definition: DEFAULT_FLOW_YML_STRING,
          public: false,
          visibility: VISIBILITY_LEVEL_PRIVATE,
        };
      },
    },
  },
  emits: ['dismiss-errors', 'submit'],
  data() {
    const projectId =
      !this.isGlobalNamespace && this.projectId
        ? convertToGraphQLId(TYPENAME_PROJECT, this.projectId)
        : this.initialValues.projectId;

    const visibilityLevel = this.initialValues.public
      ? VISIBILITY_LEVEL_PUBLIC
      : VISIBILITY_LEVEL_PRIVATE;

    return {
      formValues: {
        ...this.initialValues,
        projectId,
        visibilityLevel: this.glFeatures.aiCatalogInternalVisibility
          ? this.initialValues.visibility
          : visibilityLevel,
      },
      formErrors: [],
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-flow-form-');
    },
    isEditMode() {
      return this.mode === 'edit';
    },
    allErrors() {
      return [...this.errors, ...this.formErrors];
    },
    submitButtonText() {
      return getSubmitButtonText(this.isEditMode, s__('AICatalog|Create flow'));
    },
    cancelRoute() {
      return getCancelRoute(
        this.$route.params,
        AI_CATALOG_FLOWS_SHOW_ROUTE,
        AI_CATALOG_FLOWS_ROUTE,
      );
    },
  },
  watch: {
    'formValues.projectId': function validateProjectField() {
      this.$nextTick(() => {
        this.$refs.fieldProject?.validate();
      });
    },
  },
  methods: {
    handleSubmit() {
      const isFormValid = this.validate();
      if (!isFormValid) {
        return;
      }

      const transformedValues = {
        projectId: this.isEditMode ? undefined : this.formValues.projectId,
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        definition: this.formValues.definition.trim(),
      };

      if (this.glFeatures.aiCatalogInternalVisibility) {
        transformedValues.visibility = this.formValues.visibilityLevel;
      } else {
        transformedValues.public = this.formValues.visibilityLevel === VISIBILITY_LEVEL_PUBLIC;
      }

      this.$emit('submit', transformedValues);
    },
    onError(error) {
      this.formErrors.push(error);
    },
    dismissErrors() {
      this.formErrors = [];
      this.$emit('dismiss-errors');
    },
    validate() {
      return Object.keys(this.$refs)
        .filter((key) => key.startsWith('field'))
        .reduce((allValid, key) => {
          const isFieldValid = this.$refs[key].validate();
          return allValid && isFieldValid;
        }, true);
    },
  },
  AI_CATALOG_TYPE_FLOW,
  VISIBILITY_LEVEL_PUBLIC,
  visibilityLevelTexts: {
    textPrivate: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PRIVATE],
    textRestricted: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_RESTRICTED],
    textPublic: FLOW_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_PUBLIC],
  },
  fields: {
    projectId: {
      id: 'flow-form-project-id',
      label: s__('AICatalog|Managed by'),
      validations: {
        requiredLabel: s__('AICatalog|Project is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|Only members of this project can edit or delete this flow.',
        ),
      },
    },
    name: {
      id: 'flow-form-name',
      label: __('Display name'),
      validations: {
        requiredLabel: s__('AICatalog|Name is required.'),
        maxLength: MAX_LENGTH_NAME,
      },
      inputAttrs: {
        'data-testid': 'flow-form-input-name',
        placeholder: s__('AICatalog|Triage Issue, Generate Release Notes, Update Docs'),
      },
    },
    description: {
      id: 'flow-form-description',
      label: __('Description'),
      validations: {
        requiredLabel: s__('AICatalog|Description is required.'),
        maxLength: MAX_LENGTH_DESCRIPTION,
      },
    },
    visibilityLevel: {
      id: 'flow-form-visibility-level',
      label: __('Visibility'),
      groupAttrs: {
        labelDescription: s__('AICatalog|Choose who can view and interact with this flow.'),
      },
    },
    definition: {
      id: 'flow-form-configuration',
      label: s__('AICatalog|YAML configuration'),
      validations: {
        requiredLabel: s__('AICatalog|Configuration is required.'),
      },
      groupAttrs: {
        labelDescription: s__(
          'AICatalog|This YAML configuration file determines the prompts, tools, and capabilities of your flow. Required properties: version, environment, components, prompts, routers, flow.',
        ),
      },
    },
  },
  publicDeletionHelpLink: helpPagePath('user/duo_agent_platform/flows/custom', {
    anchor: 'flow-visibility',
  }),
};
</script>

<template>
  <div>
    <errors-alert :errors="allErrors" @dismiss="dismissErrors" />
    <div class="gl-flex gl-min-w-0 gl-gap-5">
      <gl-form
        :id="formId"
        class="gl-flex gl-min-w-0 gl-grow gl-flex-col gl-gap-5"
        @submit.prevent="handleSubmit"
      >
        <form-section :title="s__('AICatalog|Basic information')">
          <form-group
            #default="{ state, blur }"
            ref="fieldName"
            :field="$options.fields.name"
            :field-value="formValues.name"
          >
            <gl-form-input
              :id="$options.fields.name.id"
              v-model="formValues.name"
              :data-testid="$options.fields.name.inputAttrs['data-testid']"
              :placeholder="$options.fields.name.inputAttrs.placeholder"
              :state="state"
              @blur="blur"
            />
          </form-group>
          <form-group
            #default="{ state, blur }"
            ref="fieldDescription"
            :field="$options.fields.description"
            :field-value="formValues.description"
          >
            <gl-form-textarea
              :id="$options.fields.description.id"
              v-model="formValues.description"
              :no-resize="false"
              :placeholder="
                s__(
                  'AICatalog|This flow specializes in... It can help you with... Best suited for...',
                )
              "
              :state="state"
              data-testid="flow-form-textarea-description"
              @blur="blur"
            />
          </form-group>
        </form-section>
        <form-section :title="s__('AICatalog|Visibility & access')">
          <form-group
            v-if="isGlobalNamespace"
            ref="fieldProject"
            :field="$options.fields.projectId"
            :field-value="formValues.projectId"
          >
            <form-project-dropdown
              :id="$options.fields.projectId.id"
              v-model="formValues.projectId"
              :disabled="isEditMode"
              @error="onError"
            />
          </form-group>
          <form-group
            :field="$options.fields.visibilityLevel"
            :field-value="formValues.visibilityLevel"
          >
            <visibility-level-radio-group
              :id="$options.fields.visibilityLevel.id"
              v-model="formValues.visibilityLevel"
              :item-type="$options.AI_CATALOG_TYPE_FLOW"
              :texts="$options.visibilityLevelTexts"
            />
            <gl-alert
              v-if="formValues.visibilityLevel === $options.VISIBILITY_LEVEL_PUBLIC"
              :dismissible="false"
              class="gl-mt-2"
            >
              <gl-sprintf
                :message="
                  s__(
                    `AICatalog|If a public flow is enabled, you can't delete it or make it private. %{linkStart}Learn more about flow visibility.%{linkEnd}`,
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="$options.publicDeletionHelpLink">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </gl-alert>
          </form-group>
        </form-section>
        <form-section :title="s__('AICatalog|Configuration')">
          <form-group
            ref="fieldDefinition"
            :key="$options.fields.definition.id"
            :field="$options.fields.definition"
            :field-value="formValues.definition"
          >
            <form-flow-definition
              v-model="formValues.definition"
              data-testid="flow-form-definition"
            />
          </form-group>
        </form-section>
      </gl-form>
    </div>
    <ai-catalog-form-buttons :is-disabled="isLoading" :cancel-route="cancelRoute" class="gl-mt-5">
      <gl-button
        :form="formId"
        :loading="isLoading"
        class="js-no-auto-disable gl-w-full @sm/panel:gl-w-auto"
        type="submit"
        variant="confirm"
        category="primary"
        data-testid="flow-form-submit-button"
      >
        {{ submitButtonText }}
      </gl-button>
    </ai-catalog-form-buttons>
  </div>
</template>
