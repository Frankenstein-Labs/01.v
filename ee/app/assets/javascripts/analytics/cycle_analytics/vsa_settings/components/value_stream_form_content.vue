<script>
import { GlButton, GlForm, GlFormInput, GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { cloneDeep, uniqueId } from 'lodash-es';
import { swapArrayItems } from '~/lib/utils/array_utility';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { visitUrlWithAlerts, mergeUrlParams } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getLabelEventsIdentifiers } from 'ee/analytics/cycle_analytics/utils';
import createValueStream from '../graphql/create_value_stream.mutation.graphql';
import updateValueStream from '../graphql/update_value_stream.mutation.graphql';
import {
  validateValueStreamName,
  cleanStageName,
  validateStage,
  formatStageDataForSubmission,
  hasDirtyStage,
  sortStagesByHidden,
} from '../utils';
import {
  STAGE_SORT_DIRECTION,
  defaultCustomStageFields,
  PRESET_OPTIONS,
  PRESET_OPTIONS_DEFAULT,
  VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID,
} from '../constants';
import ValueStreamFormContentActions from './value_stream_form_content_actions.vue';
import CustomStageFields from './custom_stage_fields.vue';
import DefaultStageFields from './default_stage_fields.vue';

const initializeStageErrors = (defaultStages, selectedPreset = PRESET_OPTIONS_DEFAULT) =>
  selectedPreset === PRESET_OPTIONS_DEFAULT ? defaultStages.map(() => ({})) : [{}];

const initializeStages = (defaultStages, selectedPreset = PRESET_OPTIONS_DEFAULT) => {
  const stages =
    selectedPreset === PRESET_OPTIONS_DEFAULT ? defaultStages : [{ ...defaultCustomStageFields }];
  return stages.map((stage) => ({ ...stage, transitionKey: uniqueId('stage-') }));
};

const initializeEditingStages = (stages = []) =>
  cloneDeep(stages).map((stage) => ({
    ...stage,
    transitionKey: uniqueId(`stage-${stage.name}-`),
  }));

export default {
  name: 'ValueStreamFormContent',
  components: {
    CrudComponent,
    GlButton,
    GlForm,
    GlFormInput,
    GlFormGroup,
    GlFormRadioGroup,
    DefaultStageFields,
    CustomStageFields,
    ValueStreamFormContentActions,
  },
  mixins: [Tracking.mixin()],
  inject: ['vsaPath', 'fullPath', 'valueStreamGid', 'stageEvents', 'defaultStages'],
  props: {
    initialData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    const {
      defaultStages,
      initialData: { name: initialName, stages: initialStages = [] },
    } = this;

    return {
      selectedPreset: PRESET_OPTIONS_DEFAULT,
      presetOptions: PRESET_OPTIONS,
      name: initialName,
      nameErrors: [],
      stageErrors: [{}],
      isSubmitting: false,
      stages: this.valueStreamGid
        ? initializeEditingStages(initialStages)
        : initializeStages(defaultStages),
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.valueStreamGid);
    },
    isValueStreamNameValid() {
      return !this.nameErrors?.length;
    },
    invalidNameFeedback() {
      return this.nameErrors?.length ? this.nameErrors.join('\n\n') : null;
    },
    hasFormErrors() {
      return Boolean(
        this.nameErrors.length || this.stageErrors.some((obj) => Object.keys(obj).length),
      );
    },
    isDirtyEditing() {
      return (
        this.isEditing &&
        (this.name !== this.initialData.name || hasDirtyStage(this.stages, this.initialData.stages))
      );
    },
    currentValueStreamStageNames() {
      return this.stages.map(({ name }) => cleanStageName(name));
    },
    submissionSuccessfulAlert() {
      const id = VSA_SETTINGS_FORM_SUBMISSION_SUCCESS_ALERT_ID;
      const message = sprintf(
        this.isEditing
          ? s__("CreateValueStreamForm|'%{name}' Value Stream has been successfully saved.")
          : s__("CreateValueStreamForm|'%{name}' Value Stream has been successfully created."),
        { name: this.name },
      );

      return { id, message, variant: 'success' };
    },
    formattedStages() {
      return formatStageDataForSubmission(this.stages, this.isEditing);
    },
  },
  methods: {
    async onSubmit() {
      this.validate();
      if (this.hasFormErrors) return;

      this.isSubmitting = true;

      try {
        const {
          data: {
            valueStreamChange: { valueStream, errors },
          },
        } = await this.submitRequest();

        if (errors?.length) {
          createAlert({ message: `${errors.join('. ')}.` });
          this.isSubmitting = false;
          return;
        }

        this.track('submit_form', {
          label: this.isEditing ? 'edit_value_stream' : 'create_value_stream',
        });

        const redirectPath = mergeUrlParams(
          { value_stream_id: getIdFromGraphQLId(valueStream.id) },
          this.vsaPath,
        );
        visitUrlWithAlerts(redirectPath, [this.submissionSuccessfulAlert]);
      } catch (error) {
        const message = this.isEditing
          ? s__(
              'CreateValueStreamForm|An error occurred while updating the custom value stream. Try again.',
            )
          : s__(
              'CreateValueStreamForm|An error occurred while creating the custom value stream. Try again.',
            );
        createAlert({ message, error, captureError: true });

        this.isSubmitting = false;
      }
    },
    submitRequest() {
      const { isEditing, valueStreamGid: id, name, fullPath, formattedStages: stages } = this;
      const params = isEditing
        ? {
            mutation: updateValueStream,
            variables: { id, name, stages },
          }
        : {
            mutation: createValueStream,
            variables: { name, fullPath, stages },
          };

      return this.$apollo.mutate(params);
    },
    stageGroupLabel(index) {
      return sprintf(s__('CreateValueStreamForm|Stage %{index}'), { index: index + 1 });
    },
    recoverStageTitle(name) {
      return sprintf(s__('CreateValueStreamForm|%{name} (default)'), { name });
    },
    validateStages() {
      return this.stages.map((stage) =>
        validateStage({
          currentStage: stage,
          allStageNames: this.currentValueStreamStageNames,
          labelEvents: getLabelEventsIdentifiers(this.stageEvents),
        }),
      );
    },
    validate() {
      const { name } = this;
      this.nameErrors = validateValueStreamName({ name });
      this.stageErrors = this.validateStages();
    },
    moveItem(arr, index, direction) {
      return direction === STAGE_SORT_DIRECTION.UP
        ? swapArrayItems(arr, index - 1, index)
        : swapArrayItems(arr, index, index + 1);
    },
    handleMove({ index, direction }) {
      const newStages = this.moveItem(this.stages, index, direction);
      const newErrors = this.moveItem(this.stageErrors, index, direction);
      this.stages = cloneDeep(newStages);
      this.stageErrors = cloneDeep(newErrors);
    },
    validateStageFields(index) {
      const copy = [...this.stageErrors];
      copy[index] = validateStage({ currentStage: this.stages[index] });
      this.stageErrors = copy;
    },
    fieldErrors(index) {
      return this.stageErrors && this.stageErrors[index] ? this.stageErrors[index] : {};
    },
    setHidden(index, hidden) {
      const newStages = [...this.stages];
      newStages[index] = { ...this.stages[index], hidden };
      this.stages = sortStagesByHidden(newStages);
    },
    onRemove(index) {
      const newErrors = this.stageErrors.filter((_, idx) => idx !== index);
      const newStages = this.stages.filter((_, idx) => idx !== index);
      this.stages = [...newStages];
      this.stageErrors = [...newErrors];
    },
    lastStage() {
      const stages = this.$refs.formStages;
      return stages[stages.length - 1];
    },
    async scrollToLastStage() {
      await this.$nextTick();
      // Scroll to the new stage we have added
      this.lastStage().focus();
      this.lastStage().scrollIntoView({ behavior: 'smooth' });
    },
    addNewStage() {
      // validate previous stages only and add a new stage
      this.validate();
      this.stages = sortStagesByHidden([
        ...this.stages,
        { ...defaultCustomStageFields, transitionKey: uniqueId('stage-') },
      ]);
      this.stageErrors = [...this.stageErrors, {}];
    },
    onAddStage() {
      this.addNewStage();
      this.scrollToLastStage();
    },
    onFieldInput(activeStageIndex, { field, value }) {
      const updatedStage = { ...this.stages[activeStageIndex], [field]: value };
      const copy = [...this.stages];
      copy[activeStageIndex] = updatedStage;
      this.stages = copy;
    },
    resetAllFieldsToDefault() {
      this.stages = initializeStages(this.defaultStages, this.selectedPreset);
      this.stageErrors = initializeStageErrors(this.defaultStages, this.selectedPreset);
    },
    handleResetDefaults() {
      if (this.isEditing) {
        const {
          initialData: { name: initialName, stages: initialStages },
        } = this;
        this.name = initialName;
        this.nameErrors = [];
        this.stages = initializeStages(initialStages);
        this.stageErrors = [{}];
      } else {
        this.resetAllFieldsToDefault();
      }
    },
    onSelectPreset(value) {
      this.selectedPreset = value;

      if (this.selectedPreset === PRESET_OPTIONS_DEFAULT) {
        this.handleResetDefaults();
      } else {
        this.resetAllFieldsToDefault();
      }
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <gl-form>
      <crud-component
        :title="s__('CreateValueStreamForm|Value stream stages')"
        :description="s__('CreateValueStreamForm|Default stages can only be hidden or re-ordered')"
        body-class="!gl-mx-0"
      >
        <template v-if="isDirtyEditing" #actions>
          <transition name="fade">
            <gl-button data-testid="vsa-reset-button" variant="link" @click="handleResetDefaults">{{
              s__('CreateValueStreamForm|Restore defaults')
            }}</gl-button>
          </transition>
        </template>

        <div class="gl-px-5">
          <gl-form-group
            data-testid="create-value-stream-name"
            label-for="create-value-stream-name"
            :label="s__('CreateValueStreamForm|Value Stream name')"
            :invalid-feedback="invalidNameFeedback"
            :state="isValueStreamNameValid"
          >
            <div class="gl-flex gl-justify-between">
              <gl-form-input
                id="create-value-stream-name"
                v-model.trim="name"
                name="create-value-stream-name"
                data-testid="create-value-stream-name-input"
                :placeholder="s__('CreateValueStreamForm|Enter value stream name')"
                :state="isValueStreamNameValid"
                :autofocus="!name"
                required
              />
            </div>
          </gl-form-group>
          <gl-form-radio-group
            v-if="!isEditing"
            :checked="selectedPreset"
            class="gl-mb-4"
            data-testid="vsa-preset-selector"
            :options="presetOptions"
            name="preset"
            @input="onSelectPreset"
          />
        </div>

        <div class="gl-border-t gl-pt-5" data-testid="extended-form-fields">
          <transition-group name="stage-list" tag="div">
            <div
              v-for="(stage, index) in stages"
              ref="formStages"
              :key="stage.id || stage.transitionKey"
              class="gl-border-b gl-mb-5 gl-px-5 gl-pb-3"
            >
              <gl-form-group
                v-if="stage.hidden"
                class="gl-mb-0 gl-flex gl-pr-3"
                label-class="gl-flex gl-float-left"
                data-testid="vsa-hidden-stage"
              >
                <template #label>
                  <span class="gl-heading-4 gl-mb-0 gl-ml-8">{{
                    recoverStageTitle(stage.name)
                  }}</span>
                </template>
                <gl-button
                  variant="link"
                  data-testid="stage-action-restore"
                  @click="setHidden(index, false)"
                  >{{ s__('CreateValueStreamForm|Restore stage') }}</gl-button
                >
              </gl-form-group>
              <custom-stage-fields
                v-else-if="stage.custom"
                :stage-label="stageGroupLabel(index)"
                :stage="stage"
                :index="index"
                :total-stages="stages.length"
                :errors="fieldErrors(index)"
                @move="handleMove"
                @remove="onRemove"
                @input="onFieldInput(index, $event)"
              />
              <default-stage-fields
                v-else
                :stage-label="stageGroupLabel(index)"
                :stage="stage"
                :index="index"
                :total-stages="stages.length"
                :errors="fieldErrors(index)"
                @move="handleMove"
                @hide="setHidden(index, true)"
                @input="validateStageFields(index)"
              />
            </div>
          </transition-group>
        </div>

        <gl-button
          class="gl-ml-5"
          icon="plus"
          data-testid="add-button"
          :disabled="isSubmitting"
          @click="onAddStage"
          >{{ s__('CreateValueStreamForm|Add a stage') }}</gl-button
        >
      </crud-component>

      <value-stream-form-content-actions
        class="gl-mt-6"
        :is-loading="isSubmitting"
        @click-primary-action="onSubmit"
      />
    </gl-form>
  </div>
</template>
