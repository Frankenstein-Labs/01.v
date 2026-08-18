<script>
import {
  GlAlert,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSprintf,
  GlButton,
  GlPopover,
  GlAccordion,
  GlAccordionItem,
} from '@gitlab/ui';
import { debounce } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import ColorPicker from '~/vue_shared/components/color_picker/color_picker.vue';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS as DEBOUNCE_DELAY } from '~/lib/utils/constants';
import { validateHexColor } from '~/lib/utils/color_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  validatePipelineConfirmationFormat,
  fetchPipelineConfigurationFileExists,
} from 'ee/groups/settings/compliance_frameworks/utils';
import { maxNameLength, i18n } from '../constants';
import complianceFrameworkNameCheckQuery from '../graphql/compliance_framework_name_check.query.graphql';
import EditSection from './edit_section.vue';

const RESERVED_NAMES = ['default', __('default')];

export default {
  name: 'BasicInformationSection',
  components: {
    ColorPicker,
    EditSection,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlSprintf,
    GlPopover,
    GlAlert,
    GlButton,
    GlFormTextarea,
    GlAccordion,
    GlAccordionItem,
  },
  inject: [
    'migratePipelineToPolicyPath',
    'pipelineConfigurationFullPathEnabled',
    'pipelineConfigurationEnabled',
    'pipelineExecutionPolicyPath',
    'groupPath',
  ],
  props: {
    value: {
      type: Object,
      required: true,
    },
    hasMigratedPipeline: {
      type: Boolean,
      required: false,
      default: false,
    },
    showValidation: {
      type: Boolean,
      required: false,
      default: false,
    },
    isInherited: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input', 'validity-change'],

  data() {
    return {
      formData: JSON.parse(JSON.stringify(this.value)),
      maintenanceModeDismissed: false,
      pipelineConfigurationFileExists: true,
      hadPipelineConfiguration: Boolean(this.value.pipelineConfigurationFullPath),
      duplicateName: null,
      isCheckingDuplicateName: false,
      nameCheckRequestId: 0,
    };
  },

  computed: {
    isCreatingNewPolicy() {
      return !this.formData.pipelineConfigurationFullPath || !this.formData.id;
    },

    dynamicMigratePipelineToPolicyPath() {
      if (this.isCreatingNewPolicy) {
        return this.pipelineExecutionPolicyPath;
      }

      const url = new URL(this.pipelineExecutionPolicyPath, document.location.href);
      url.searchParams.set('path', this.formData.pipelineConfigurationFullPath);
      url.searchParams.set('compliance_framework_name', this.formData.name);
      url.searchParams.set('compliance_framework_id', getIdFromGraphQLId(this.formData.id));

      return url.toString();
    },
    deprecationWarningButtonText() {
      if (this.isCreatingNewPolicy) {
        return this.$options.i18n.deprecationWarning.migratePipelineToPolicyEmpty;
      }

      // migrate pipeline to policy
      return this.$options.i18n.deprecationWarning.migratePipelineToPolicy;
    },
    pipelineConfigurationFeedbackMessage() {
      if (!this.isValidPipelineConfigurationFormat) {
        return this.$options.i18n.pipelineConfigurationInputInvalidFormat;
      }

      return this.$options.i18n.pipelineConfigurationInputUnknownFile;
    },

    nameFeedbackMessage() {
      if (!this.formData.name || this.formData.name.length > maxNameLength) {
        return this.$options.i18n.titleInputInvalid;
      }
      if (RESERVED_NAMES.includes(this.formData.name.toLowerCase())) {
        return this.$options.i18n.nameInputReserved(this.formData.name);
      }
      if (this.isDuplicateName) {
        return this.$options.i18n.nameInputDuplicate;
      }
      return '';
    },

    isDuplicateName() {
      return this.duplicateName !== null && this.duplicateName === this.formData.name;
    },

    compliancePipelineConfigurationHelpPath() {
      return helpPagePath('user/compliance/compliance_pipelines', {
        anchor: 'example-configuration',
      });
    },

    isValidColor() {
      return Boolean(this.formData.color) && validateHexColor(this.formData.color);
    },

    isValidName() {
      return Boolean(this.formData.name) && this.nameFeedbackMessage === '';
    },

    isValidDescription() {
      return Boolean(this.formData.description);
    },

    isValidPipelineConfiguration() {
      if (!this.formData.pipelineConfigurationFullPath) {
        return null;
      }

      return this.isValidPipelineConfigurationFormat && this.pipelineConfigurationFileExists;
    },

    isValidPipelineConfigurationFormat() {
      return validatePipelineConfirmationFormat(this.formData.pipelineConfigurationFullPath);
    },

    isValid() {
      return (
        this.isValidName &&
        this.isValidDescription &&
        this.isValidColor &&
        this.isValidPipelineConfiguration !== false
      );
    },
    showMaintenanceModeAlert() {
      return !this.maintenanceModeDismissed && this.pipelineConfigurationEnabled;
    },
    showPostMigrationAlert() {
      return !this.isCreatingNewPolicy && this.hasMigratedPipeline;
    },
    expandPipelineConfig() {
      return Boolean(this.formData.pipelineConfigurationFullPath);
    },

    isNameFeedbackVisible() {
      if (this.isDuplicateName) {
        return false;
      }
      return this.getValidationState(this.isValidName);
    },

    isDescriptionFeedbackVisible() {
      return this.getValidationState(this.isValidDescription);
    },

    isPipelineConfigurationFeedbackVisible() {
      return this.getValidationState(this.isValidPipelineConfiguration);
    },

    isColorFeedbackVisible() {
      return this.getValidationState(this.isValidColor);
    },

    nameInputDisabled() {
      return this.isInherited;
    },

    descriptionInputDisabled() {
      return this.isInherited;
    },

    pipelineConfigDisabled() {
      return this.isInherited;
    },

    setAsDefaultDisabled() {
      return this.isInherited;
    },
  },

  watch: {
    formData: {
      handler(newValue) {
        this.$emit('input', newValue);
      },
      deep: true,
    },
    'formData.pipelineConfigurationFullPath': {
      handler(path) {
        if (path) {
          this.validatePipelineInput(path);
        }
      },
    },
    isValid: {
      immediate: true,
      handler(val) {
        this.$emit('validity-change', val);
      },
    },
  },

  mounted() {
    if (this.formData.name) {
      this.checkNameUniqueness();
    }
  },

  methods: {
    async validatePipelineConfigurationPath(path) {
      this.pipelineConfigurationFileExists = await fetchPipelineConfigurationFileExists(path);
    },

    validatePipelineInput: debounce(function debounceValidation(path) {
      this.validatePipelineConfigurationPath(path);
    }, DEBOUNCE_DELAY),

    handleOnDismissMaintenanceMode() {
      this.maintenanceModeDismissed = true;
    },

    getValidationState(state) {
      return this.showValidation ? state : true;
    },

    async checkNameUniqueness() {
      const { name } = this.formData;
      if (!name || name.length > maxNameLength) {
        this.duplicateName = null;
        return;
      }
      if (RESERVED_NAMES.includes(name.toLowerCase())) {
        this.duplicateName = null;
        return;
      }
      if (this.nameInputDisabled || !this.groupPath) {
        return;
      }

      this.nameCheckRequestId += 1;
      const requestId = this.nameCheckRequestId;
      this.isCheckingDuplicateName = true;

      try {
        const { data } = await this.$apollo.query({
          query: complianceFrameworkNameCheckQuery,
          variables: { fullPath: this.groupPath, search: name },
          fetchPolicy: 'no-cache',
        });

        if (requestId !== this.nameCheckRequestId) {
          return;
        }

        const nodes = data?.namespace?.complianceFrameworks?.nodes || [];
        const match = nodes.find((node) => node.name === name && node.id !== this.formData.id);
        this.duplicateName = match ? name : null;
      } catch (error) {
        if (requestId === this.nameCheckRequestId) {
          this.duplicateName = null;
          Sentry.captureException(error);
        }
      } finally {
        if (requestId === this.nameCheckRequestId) {
          this.isCheckingDuplicateName = false;
        }
      }
    },

    onNameBlur() {
      this.checkNameUniqueness();
    },

    onNameInput() {
      if (this.duplicateName && this.formData.name !== this.duplicateName) {
        this.duplicateName = null;
      }
    },
  },

  i18n,
  disabledPipelineConfigurationInputPopoverTarget:
    'disabled-pipeline-configuration-input-popover-target',
};
</script>
<template>
  <edit-section
    :title="$options.i18n.basicInformation"
    :description="$options.i18n.basicInformationDescription"
    is-required
    :is-completed="isValid"
    :is-inherited="isInherited"
  >
    <div class="gl-px-4">
      <gl-form-group
        :label="$options.i18n.titleInputLabel"
        label-for="name-input"
        :state="isNameFeedbackVisible"
        :invalid-feedback="nameFeedbackMessage"
        data-testid="name-input-group"
      >
        <gl-form-input
          id="name-input"
          v-model="formData.name"
          name="name"
          :state="isNameFeedbackVisible"
          :disabled="nameInputDisabled"
          data-testid="name-input"
          @input="onNameInput"
          @blur="onNameBlur"
        />
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.descriptionInputLabel"
        label-for="description-input"
        :invalid-feedback="$options.i18n.descriptionInputInvalid"
        :state="isDescriptionFeedbackVisible"
        data-testid="description-input-group"
      >
        <gl-form-textarea
          id="description-input"
          v-model="formData.description"
          name="description"
          :state="isDescriptionFeedbackVisible"
          :disabled="descriptionInputDisabled"
          data-testid="description-input"
          :no-resize="false"
          :rows="5"
        />
      </gl-form-group>
      <color-picker
        v-if="!isInherited"
        v-model="formData.color"
        :label="$options.i18n.colorInputLabel"
        :state="isColorFeedbackVisible"
      />
      <gl-form-group
        v-else
        :label="$options.i18n.colorInputLabel"
        data-testid="color-display-group"
      >
        <div
          class="input-group gl-align-center gl-max-w-26 gl-rounded-none gl-rounded-br-base gl-rounded-tr-base"
        >
          <div class="input-group-prepend">
            <div
              class="gl-relative gl-w-7 gl-rounded-bl-base gl-rounded-tl-base gl-border-1 gl-border-solid gl-bg-subtle"
              :style="{
                backgroundColor: formData.color,
                borderColor: 'var(--gl-control-border-color-default)',
              }"
            ></div>
          </div>
          <gl-form-input
            :value="formData.color"
            disabled
            readonly
            class="GLFormInput form-control"
            maxlength="7"
          />
        </div>
      </gl-form-group>
      <gl-accordion v-if="hadPipelineConfiguration" :auto-collapse="false" :header-level="1">
        <gl-accordion-item
          :title="$options.i18n.pipelineConfigurationInputLabel"
          :header-level="1"
          :visible="expandPipelineConfig"
        >
          <gl-alert
            v-if="showMaintenanceModeAlert"
            variant="warning"
            class="gl-my-3"
            data-testid="maintenance-mode-alert"
            :dismissible="true"
            :title="$options.i18n.deprecationWarning.title"
            @dismiss="handleOnDismissMaintenanceMode"
          >
            <template v-if="showPostMigrationAlert">
              <p
                v-for="(message, index) in $options.i18n.deprecationWarning.postMigrationMessages"
                :key="index"
              >
                {{ message }}
              </p>
            </template>
            <template v-else>
              <p>
                <gl-sprintf :message="$options.i18n.deprecationWarning.message">
                  <template #link="{ content }">
                    <gl-link :href="pipelineExecutionPolicyPath" target="_blank">
                      {{ content }}
                    </gl-link>
                  </template>
                </gl-sprintf>
              </p>

              <gl-sprintf :message="$options.i18n.deprecationWarning.details">
                <template #link="{ content }">
                  <gl-link :href="migratePipelineToPolicyPath" target="_blank">
                    {{ content }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </template>
            <template v-if="!showPostMigrationAlert" #actions>
              <gl-button
                category="primary"
                variant="confirm"
                data-testid="migrate-action-button"
                :href="dynamicMigratePipelineToPolicyPath"
                target="_blank"
              >
                {{ deprecationWarningButtonText }}
              </gl-button>

              <gl-button class="gl-ml-5" @click="handleOnDismissMaintenanceMode">
                {{ $options.i18n.deprecationWarning.dismiss }}
              </gl-button>
            </template>
          </gl-alert>

          <gl-form-group
            v-if="
              pipelineConfigurationFullPathEnabled &&
              pipelineConfigurationEnabled &&
              hadPipelineConfiguration
            "
            label-for="pipeline-configuration-input"
            :invalid-feedback="pipelineConfigurationFeedbackMessage"
            :state="isPipelineConfigurationFeedbackVisible"
            data-testid="pipeline-configuration-input-group"
          >
            <template #description>
              <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDescription">
                <template #code="{ content }">
                  <code>{{ content }}</code>
                </template>

                <template #link="{ content }">
                  <gl-link :href="compliancePipelineConfigurationHelpPath" target="_blank">
                    {{ content }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </template>

            <gl-form-input
              id="pipeline-configuration-input"
              v-model="formData.pipelineConfigurationFullPath"
              name="pipeline_configuration_full_path"
              :state="isPipelineConfigurationFeedbackVisible"
              :disabled="pipelineConfigDisabled"
              data-testid="pipeline-configuration-input"
            />
          </gl-form-group>

          <gl-form-group
            v-else
            id="disabled-pipeline-configuration-input-group"
            label-for="disabled-pipeline-configuration-input"
            data-testid="disabled-pipeline-configuration-input-group"
          >
            <template #description>
              <gl-sprintf :message="$options.i18n.pipelineConfigurationInputDescription">
                <template #code="{ content }">
                  <code>{{ content }}</code>
                </template>

                <template #link="{ content }">
                  <gl-link :href="compliancePipelineConfigurationHelpPath" target="_blank">
                    {{ content }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </template>

            <div :id="$options.disabledPipelineConfigurationInputPopoverTarget" tabindex="0">
              <gl-form-input
                id="disabled-pipeline-configuration-input"
                disabled
                data-testid="disabled-pipeline-configuration-input"
              />
            </div>

            <gl-popover
              :title="$options.i18n.pipelineConfigurationInputDisabledPopoverTitle"
              show-close-button
              :target="$options.disabledPipelineConfigurationInputPopoverTarget"
              data-testid="disabled-pipeline-configuration-input-popover"
            >
              <p class="gl-mb-0">
                <gl-sprintf
                  :message="$options.i18n.pipelineConfigurationInputDisabledPopoverContent"
                >
                  <template #link="{ content }">
                    <gl-link
                      :href="$options.i18n.pipelineConfigurationInputDisabledPopoverLink"
                      target="_blank"
                      class="gl-text-sm"
                    >
                      {{ content }}
                    </gl-link>
                  </template>
                </gl-sprintf>
              </p>
            </gl-popover>
          </gl-form-group>
        </gl-accordion-item>
      </gl-accordion>
      <gl-form-checkbox
        v-model="formData.default"
        name="default"
        class="gl-mt-5"
        :disabled="setAsDefaultDisabled"
      >
        <span class="gl-font-bold">{{ $options.i18n.setAsDefault }}</span>
        <template #help>
          <div>
            {{ $options.i18n.setAsDefaultDetails }}
            {{ $options.i18n.setAsDefaultOnlyOne }}
          </div>
        </template>
      </gl-form-checkbox>
    </div>
  </edit-section>
</template>
