<script>
import {
  GlBadge,
  GlLink,
  GlButton,
  GlModal,
  GlTooltip,
  GlFormInput,
  GlFormTextarea,
  GlFormGroup,
  GlCollapsibleListbox,
  GlFormInputGroup,
  GlInputGroupText,
  GlTooltipDirective,
  GlTruncate,
  GlToggle,
} from '@gitlab/ui';
import { cloneDeep, omit } from 'lodash-es';
import { isValidURL } from '~/lib/utils/url_utility';
import { s__, __, sprintf } from '~/locale';
import {
  requirementDefaultValidationState,
  maxControlsNumber,
  requirementsDocsUrl,
  requirementEvents,
} from '../constants';
import { EXTERNAL_CONTROL_LABEL } from '../../../../constants';
import { statusesInfo } from '../../../standards_adherence_report/components/details_drawer/statuses_info';

const MAX_NAME_LENGTH = 255;
const MAX_DESCRIPTION_LENGTH = 500;

export default {
  name: 'RequirementModal',
  components: {
    GlModal,
    GlFormInput,
    GlFormTextarea,
    GlFormGroup,
    GlBadge,
    GlLink,
    GlButton,
    GlTooltip,
    GlCollapsibleListbox,
    GlFormInputGroup,
    GlInputGroupText,
    GlTruncate,
    GlToggle,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    requirement: {
      type: Object,
      required: true,
    },
    gitlabStandardControls: {
      type: Array,
      required: true,
    },
    isNewFramework: {
      type: Boolean,
      required: true,
    },
  },
  emits: [requirementEvents.create, requirementEvents.update],
  data() {
    return {
      requirementData: null,
      validation: {
        ...requirementDefaultValidationState,
      },
      controls: [],
      searchQuery: '',
      controlValidation: {},
      validationWatchersRegistered: false,
      visibleExternalControls: {},
    };
  },
  computed: {
    isEdit() {
      return Boolean(this.requirementData?.id || this.requirementData?.index !== null);
    },
    title() {
      return this.isEdit ? this.$options.i18n.editText : this.$options.i18n.createTitle;
    },
    disabledAddControlBtnText() {
      return sprintf(
        s__('ComplianceFrameworks|You can create a maximum of %{maxControlsNumber} controls'),
        { maxControlsNumber },
      );
    },
    controlItems() {
      return this.gitlabStandardControls
        .filter((control) => !this.controls.some((c) => c?.name === control.id))
        .filter((control) => control.name.toLowerCase().includes(this.searchQuery.toLowerCase()))
        .map(({ id, name }) => ({
          value: id,
          text: name,
          tooltip: statusesInfo[id]?.description || '',
        }))
        .sort((a, b) => a.text.localeCompare(b.text));
    },
    modalButtonProps() {
      const { createButtonText, editText, existingFrameworkButtonText } = this.$options.i18n;

      let text = existingFrameworkButtonText;

      if (this.isNewFramework) {
        text = this.isEdit ? editText : createButtonText;
      }

      return {
        primary: {
          text,
          attributes: { category: 'primary', variant: 'confirm' },
        },
        cancel: {
          text: __('Cancel'),
        },
      };
    },
    canAddControl() {
      return this.controls.length < maxControlsNumber;
    },
    controlsLength() {
      return this.controls.filter((control) => control?.name).length;
    },
  },
  watch: {
    requirement: {
      immediate: true,
      handler(newRequirement) {
        this.requirementData = cloneDeep(newRequirement);
        this.initializeControls();
        this.validation = { ...requirementDefaultValidationState };
      },
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API.
    show() {
      this.$refs.modal.show();
    },
    initializeControls() {
      const sourceControls = this.requirementData?.stagedControls?.length
        ? this.requirementData.stagedControls
        : this.requirementData?.complianceRequirementsControls?.nodes || [];

      if (sourceControls.length) {
        this.controls = sourceControls.map((control) => {
          const standardControl = this.gitlabStandardControls.find(
            (ctrl) => ctrl.id === control.name,
          );

          const baseControl = {
            id: control.id,
            name: control.name,
            controlType: control.controlType,
            displayName: control.controlType === 'external' ? control.name : standardControl?.name,
          };

          if (control.controlType === 'external') {
            return {
              ...baseControl,
              externalControlName: control.externalControlName,
              externalUrl: control.externalUrl,
              secretToken: control.secretToken,
              pingEnabled: control.pingEnabled ?? true,
            };
          }

          return {
            ...baseControl,
            expression: control.expression,
          };
        });
      } else {
        this.controls = [null];
      }
      this.controlValidation = {};
      this.visibleExternalControls = {};
    },
    isValidSecretToken(control) {
      return (
        control?.controlType !== 'external' ||
        this.showExternalControlSummary(control) ||
        control.secretToken?.trim()
      );
    },
    isValidExternalName(control) {
      const name = control.externalControlName?.trim() || '';
      return name.length <= MAX_NAME_LENGTH;
    },
    validateControl(control) {
      if (!control) return true;

      const validations = {
        internal: () => true,
        external: () => {
          const urlValid =
            this.showExternalControlSummary(control) || isValidURL(control.externalUrl);
          const secretValid = this.isValidSecretToken(control);
          const nameValid = this.isValidExternalName(control);
          return {
            isValid: urlValid && secretValid && nameValid,
            urlValid,
            secretValid,
            nameValid,
          };
        },
      };

      const validator = validations[control.controlType];
      return validator ? validator() : true;
    },
    validateExternalControl(control, index) {
      if (!control || control.controlType !== 'external') {
        return true;
      }

      const validation = this.validateControl(control);
      this.controlValidation[index] = {
        externalControlName: validation.nameValid,
        externalUrl: validation.urlValid,
        secretToken: validation.secretValid,
      };

      return validation.isValid;
    },
    validateRequirementName() {
      const name = this.requirementData.name?.trim();
      return Boolean(name) && name.length <= MAX_NAME_LENGTH;
    },
    validateRequirementDescription() {
      const description = this.requirementData.description?.trim();
      return Boolean(description) && description.length <= MAX_DESCRIPTION_LENGTH;
    },
    validateForm() {
      const requirementValidation = {
        name: this.validateRequirementName(),
        description: this.validateRequirementDescription(),
      };

      const controlsValidation = this.controls.map((control, index) => {
        const validation = this.validateControl(control);
        if (typeof validation === 'object') {
          this.controlValidation[index] = {
            externalControlName: validation.nameValid,
            externalUrl: validation.urlValid,
            secretToken: validation.secretValid,
          };
          return validation.isValid;
        }
        return validation;
      });

      this.validation = {
        ...requirementValidation,
        controls: controlsValidation.every(Boolean),
      };

      return Object.values(this.validation).every(Boolean);
    },
    handleSubmit(event) {
      if (!this.validationWatchersRegistered) {
        this.$watch(
          'controls',
          () => {
            this.controls.forEach((control, index) => {
              if (control?.controlType === 'external') {
                this.validateExternalControl(control, index);
              }
            });
          },
          { deep: true },
        );

        this.$watch('requirementData.name', () => {
          this.validation.name = Boolean(this.requirementData.name);
        });

        this.$watch('requirementData.description', () => {
          this.validation.description = Boolean(this.requirementData.description);
        });

        this.validationWatchersRegistered = true;
      }

      if (this.validateForm()) {
        const stagedControls = this.controls
          .map((control) => {
            if (!control) return null;
            if (!control.name) return null;

            if (control.expression) {
              if (typeof control.expression === 'string') {
                return {
                  ...control,
                  expression: control.expression,
                };
              }
              const expressionWithoutTypename = omit(control.expression, '__typename');
              const expression = Object.keys(expressionWithoutTypename).length
                ? JSON.stringify(expressionWithoutTypename)
                : null;
              return {
                ...control,
                expression,
              };
            }

            const controlWithoutSecretToken = this.showExternalControlSummary(control)
              ? omit(control, 'secretToken')
              : control;

            return {
              ...controlWithoutSecretToken,
              expression: null,
            };
          })
          .filter(Boolean);

        const { index, ...requirement } = this.requirementData;
        requirement.stagedControls = stagedControls;
        const eventName = this.isEdit ? requirementEvents.update : requirementEvents.create;

        this.$emit(eventName, {
          requirement,
          index,
        });
      } else {
        event.preventDefault();
      }
    },
    getToggleText(control) {
      return control?.controlType === 'external'
        ? this.$options.i18n.externalControl
        : control?.displayName || this.$options.i18n.toggleText;
    },
    getSelected(control) {
      return control?.id || null;
    },
    addControl(type = 'internal') {
      if (this.canAddControl) {
        const newIndex = this.controls.length;
        this.controls.push({
          controlType: type,
          externalControlName: '',
          externalUrl: '',
          secretToken: '',
          name: type === 'external' ? 'external_control' : '',
          pingEnabled: type === 'external' ? true : undefined,
        });
        if (type === 'external') {
          this.controlValidation[newIndex] = {
            externalControlName: false,
            externalUrl: false,
            secretToken: false,
          };
        }
      }
    },
    addExternalControl() {
      this.addControl('external');
    },
    removeControl(index) {
      this.controls.splice(index, 1);
    },
    onControlSelect(index, selectedId) {
      if (!selectedId) {
        this.controls.splice(index, 1, null);
        return;
      }

      const selectedControl = this.gitlabStandardControls.find((ctrl) => ctrl.id === selectedId);
      if (selectedControl) {
        this.controls.splice(index, 1, {
          id: this.controls[index]?.id,
          name: selectedControl.id,
          expression: selectedControl.expression,
          displayName: selectedControl.name,
          controlType: 'internal',
        });
      }
    },
    isExternalControl(control) {
      return control?.controlType === 'external';
    },
    controlInputState(index, field) {
      return !(
        this.validationWatchersRegistered &&
        this.controlValidation[index] &&
        !this.controlValidation[index][field]
      );
    },
    requirementInputState(field) {
      return !this.validationWatchersRegistered || this.validation[field];
    },
    showExternalControlSummary(control) {
      return control?.id && !this.visibleExternalControls[control.id];
    },

    enableExternalControlEdit(control) {
      this.visibleExternalControls = {
        ...this.visibleExternalControls,
        [control.id]: control.externalUrl,
      };
    },
    disableExternalControlEdit(control) {
      const controlIndex = this.controls.findIndex((c) => c.id === control.id);
      if (controlIndex !== -1) {
        this.controls[controlIndex].externalUrl = this.visibleExternalControls[control.id];
      }

      this.visibleExternalControls = {
        ...this.visibleExternalControls,
        [control.id]: null,
      };
    },
    externalControlDisplayValue(externalControl) {
      return externalControl.externalControlName;
    },
    showExternalControlFieldToggle(control) {
      return control?.id;
    },
    showPingDisabledBadge({ controlType, pingEnabled } = {}) {
      return controlType === 'external' && pingEnabled === false;
    },
  },
  requirementsDocsUrl,
  i18n: {
    createTitle: s__('ComplianceFrameworks|Create new requirement'),
    editText: s__('ComplianceFrameworks|Edit requirement'),
    createButtonText: s__('ComplianceFrameworks|Create requirement'),
    existingFrameworkButtonText: s__('ComplianceFrameworks|Save changes to the framework'),
    nameInput: sprintf(s__('ComplianceFrameworks|Name (max %{maxLength} characters)'), {
      maxLength: MAX_NAME_LENGTH,
    }),
    descriptionInput: sprintf(
      s__('ComplianceFrameworks|Description (max %{maxLength} characters)'),
      { maxLength: MAX_DESCRIPTION_LENGTH },
    ),
    controlsTitle: s__('ComplianceFrameworks|Controls (optional)'),
    controlsText: s__(
      'ComplianceFrameworks|GitLab controls are pre-defined rules that are configured for GitLab resources. External environmental controls use the API to check the status and details of an external environment.',
    ),
    learnMore: __('Learn more.'),
    nameInputInvalid: sprintf(
      s__('ComplianceFrameworks|Name is required and must be less than %{maxLength} characters'),
      { maxLength: MAX_NAME_LENGTH },
    ),
    descriptionInputInvalid: sprintf(
      s__(
        'ComplianceFrameworks|Description is required and must be less than %{maxLength} characters',
      ),
      { maxLength: MAX_DESCRIPTION_LENGTH },
    ),
    addControl: s__('ComplianceFrameworks|Add a GitLab control'),
    addExternalControl: s__('ComplianceFrameworks|Add an external control'),
    toggleText: s__('ComplianceFrameworks|Choose a GitLab control'),
    externalControl: s__('ComplianceFrameworks|External control'),
    removeControl: s__('ComplianceFrameworks|Remove control'),
    externalControlName: s__('ComplianceFrameworks|External Control Name'),
    externalUrlLabel: s__('ComplianceFrameworks|External URL'),
    secretLabel: s__('ComplianceFrameworks|HMAC shared secret'),
    secretDescription: s__(
      'ComplianceFrameworks|Provide a shared secret to be used when sending a request for an external check to authenticate request using HMAC.',
    ),
    invalidControlNameError: s__('ComplianceFrameworks|Please enter a valid name'),
    invalidUrlError: s__('ComplianceFrameworks|Please enter a valid URL'),
    secretTokenRequired: s__('ComplianceFrameworks|Secret token is required'),
    pingEnabledLabel: s__('ComplianceFrameworks|Enable ping'),
    pingEnabledHelpText: s__(
      "ComplianceFrameworks|When enabled, GitLab pings this external control every 12 hours to reset its status to 'pending'. To manage the control status exclusively through the API, disable this setting.",
    ),
    pingDisabled: s__('ComplianceFrameworks|Disabled'),
    EXTERNAL_CONTROL_LABEL,
  },
};
</script>

<template>
  <gl-modal
    v-if="requirementData"
    ref="modal"
    :title="title"
    modal-id="requirement-modal"
    :action-primary="modalButtonProps.primary"
    :action-cancel="modalButtonProps.cancel"
    @primary="handleSubmit"
  >
    <gl-form-group
      :label="$options.i18n.nameInput"
      label-for="name-input"
      :invalid-feedback="$options.i18n.nameInputInvalid"
      :state="requirementInputState('name')"
      data-testid="name-input-group"
    >
      <gl-form-input
        id="name-input"
        v-model="requirementData.name"
        name="name"
        data-testid="name-input"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionInput"
      :invalid-feedback="$options.i18n.descriptionInputInvalid"
      :state="requirementInputState('description')"
      data-testid="description-input-group"
    >
      <gl-form-textarea
        id="description-input"
        v-model="requirementData.description"
        name="description"
        data-testid="description-input"
        :no-resize="false"
        :rows="5"
      />
    </gl-form-group>
    <b>{{ $options.i18n.controlsTitle }}</b>
    <gl-badge>{{ controlsLength }}</gl-badge>
    <p>
      {{ $options.i18n.controlsText }}
      <gl-link :href="$options.requirementsDocsUrl" target="_blank">{{
        $options.i18n.learnMore
      }}</gl-link>
    </p>

    <div
      v-for="(control, index) in controls"
      :key="index"
      class="gl-mb-3 gl-flex gl-items-center gl-justify-between gl-rounded-base gl-bg-subtle gl-p-3"
    >
      <div class="gl-flex-grow-1 gl-mr-3 gl-w-full">
        <template v-if="isExternalControl(control)">
          <template v-if="showExternalControlSummary(control)">
            <div class="gl-flex gl-items-center gl-justify-between">
              <div :data-testid="`external-control-summary-${index}`">
                {{ externalControlDisplayValue(control) }}
                <gl-badge>{{ $options.i18n.EXTERNAL_CONTROL_LABEL }}</gl-badge>
                <gl-badge v-if="showPingDisabledBadge(control)" variant="warning" class="gl-ml-2">
                  {{ $options.i18n.pingDisabled }}
                </gl-badge>
              </div>
            </div>
          </template>
          <template v-else>
            <gl-form-group
              :label="$options.i18n.externalControlName"
              label-sr-only
              :invalid-feedback="$options.i18n.invalidControlNameError"
              :state="controlInputState(index, 'externalControlName')"
              :data-testid="`external-name-input-group-${index}`"
            >
              <gl-form-input-group>
                <template #prepend>
                  <gl-input-group-text>
                    <gl-truncate :text="$options.i18n.externalControlName" position="middle" />
                  </gl-input-group-text>
                </template>
                <gl-form-input
                  v-model="control.externalControlName"
                  type="text"
                  :data-testid="`external-name-input-${index}`"
                  class="gl-w-full"
                />
              </gl-form-input-group>
            </gl-form-group>

            <gl-form-group
              :label="$options.i18n.externalUrlLabel"
              :label-sr-only="true"
              :invalid-feedback="$options.i18n.invalidUrlError"
              :state="controlInputState(index, 'externalUrl')"
              :data-testid="`external-url-input-group-${index}`"
            >
              <gl-form-input-group>
                <template #prepend>
                  <gl-input-group-text>
                    <gl-truncate :text="$options.i18n.externalUrlLabel" position="middle" />
                  </gl-input-group-text>
                </template>
                <gl-form-input
                  v-model="control.externalUrl"
                  type="url"
                  :data-testid="`external-url-input-${index}`"
                  class="gl-w-full"
                />
              </gl-form-input-group>
            </gl-form-group>

            <gl-form-group
              :label="$options.i18n.secretLabel"
              :label-sr-only="true"
              :invalid-feedback="$options.i18n.secretTokenRequired"
              :state="controlInputState(index, 'secretToken')"
              class="gl-mt-3"
              :data-testid="`external-secret-input-group-${index}`"
            >
              <gl-form-input-group>
                <template #prepend>
                  <gl-input-group-text>
                    <gl-truncate :text="$options.i18n.secretLabel" position="middle" />
                  </gl-input-group-text>
                </template>
                <gl-form-input
                  v-model="control.secretToken"
                  type="password"
                  :data-testid="`external-secret-input-${index}`"
                />
              </gl-form-input-group>
              <template #description>
                <div class="gl-text-sm">
                  {{ $options.i18n.secretDescription }}
                </div>
              </template>
            </gl-form-group>

            <gl-form-group class="gl-mt-3" :data-testid="`ping-enabled-group-${index}`">
              <template #label>
                <div class="gl-flex gl-items-center gl-gap-3">
                  <span>{{ $options.i18n.pingEnabledLabel }}</span>
                  <gl-toggle
                    v-model="control.pingEnabled"
                    :data-testid="`ping-enabled-toggle-${index}`"
                    class="!gl-flex-row"
                  />
                </div>
              </template>
              <template #description>
                <div class="gl-text-sm">
                  {{ $options.i18n.pingEnabledHelpText }}
                </div>
              </template>
            </gl-form-group>
          </template>
        </template>
        <gl-collapsible-listbox
          v-else
          placement="bottom"
          positioning-strategy="absolute"
          boundary="viewport"
          :data-testid="`control-select-${index}`"
          :selected="getSelected(control)"
          searchable
          :toggle-text="getToggleText(control)"
          :items="controlItems"
          @select="onControlSelect(index, $event)"
          @search="searchQuery = $event"
        >
          <template #list-item="{ item }">
            <div v-gl-tooltip="item.tooltip" class="gl-w-full">
              {{ item.text }}
            </div>
          </template>
        </gl-collapsible-listbox>
      </div>

      <template v-if="showExternalControlFieldToggle(control)">
        <template v-if="showExternalControlSummary(control)">
          <gl-button
            :aria-label="$options.i18n.removeControl"
            category="tertiary"
            icon="pencil"
            :data-testid="`external-control-edit-button-${index}`"
            @click="enableExternalControlEdit(control)"
          />
        </template>
        <template v-else>
          <gl-button
            :aria-label="$options.i18n.removeControl"
            category="tertiary"
            icon="close"
            :data-testid="`external-control-close-button-${index}`"
            @click="disableExternalControlEdit(control)"
          />
        </template>
      </template>
      <gl-button
        :aria-label="$options.i18n.removeControl"
        category="tertiary"
        icon="remove"
        class="gl-align-top"
        @click="removeControl(index)"
      />
    </div>

    <gl-tooltip
      v-if="!canAddControl"
      placement="right"
      :target="() => $refs.addControlBtn"
      :title="disabledAddControlBtnText"
    />
    <div ref="addControlBtn" class="gl-inline-block">
      <gl-button
        category="secondary"
        variant="confirm"
        class="gl-mt-3 gl-block"
        data-testid="add-control-button"
        :disabled="!canAddControl"
        @click="addControl"
      >
        {{ $options.i18n.addControl }}
      </gl-button>
    </div>

    <div ref="addExternalControlBtn" class="gl-ml-3 gl-inline-block">
      <gl-button
        category="secondary"
        class="gl-mt-3 gl-block"
        data-testid="add-external-control-button"
        :disabled="!canAddControl"
        @click="addExternalControl"
      >
        {{ $options.i18n.addExternalControl }}
      </gl-button>
    </div>
  </gl-modal>
</template>
