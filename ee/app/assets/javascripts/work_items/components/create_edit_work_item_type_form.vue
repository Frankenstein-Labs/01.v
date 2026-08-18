<script>
import {
  GlModal,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlButton,
  GlIcon,
  GlAlert,
  GlFormRadio,
  GlFormRadioGroup,
  GlFormCheckbox,
  GlLoadingIcon,
} from '@gitlab/ui';
import { produce } from 'immer';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { ICON_NAVIGATION_KEYS } from '~/work_items/constants';
import { s__ } from '~/locale';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';
import workItemTypeCreateMutation from 'ee/work_items/graphql/create_work_item_type.mutation.graphql';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import organizationWorkItemTypesQuery from 'ee/work_items/graphql/organization_work_item_types.query.graphql';
import namespaceWorkItemSettingsQuery from 'ee/work_items/graphql/namespace_work_item_settings.query.graphql';
import orgWorkItemSettingsQuery from 'ee/work_items/graphql/organization_work_item_settings.query.graphql';

export default {
  name: 'CreateEditWorkItemTypeForm',
  components: {
    GlModal,
    GlFormGroup,
    GlFormInput,
    GlButton,
    GlIcon,
    GlAlert,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormCheckbox,
    GlForm,
    GlLoadingIcon,
  },
  props: {
    isVisible: {
      type: Boolean,
      required: true,
    },
    workItemTypeIcons: {
      type: Array,
      required: false,
      default: () => [],
    },
    isEditMode: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemType: {
      type: Object,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['save', 'close', 'error', 'success'],
  data() {
    return {
      form: {
        name: this.workItemType?.name || '',
        iconName: this.workItemType?.iconName || this.workItemTypeIcons[0]?.name,
        enabled: this.workItemType?.enabled ?? true,
      },
      workItemSettings: null,
      errors: {},
      showErrors: false,
      isSubmitting: false,
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
        return settings ?? this.workItemSettings;
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    modalTitle() {
      return this.isEditMode ? s__('WorkItem|Edit type name and icon') : s__('WorkItem|New type');
    },
    typeIconToLabelMap() {
      return Object.fromEntries(this.workItemTypeIcons.map(({ name, label }) => [name, label]));
    },
    typeIconNames() {
      return Object.keys(this.typeIconToLabelMap);
    },
    nameErrorState() {
      return this.showErrors && this.formValidationErrors.name ? false : null;
    },
    formValidationErrors() {
      const errors = {};

      if (!this.form.name?.trim()) {
        errors.name = s__('WorkItem|Name is required');
      }

      return errors;
    },
    isFormValid() {
      return Object.keys(this.formValidationErrors).length === 0;
    },
    typeCustomizationDisabled() {
      return !this.workItemSettings?.customizableTypeVisibility;
    },
    isLoading() {
      return this.$apollo.queries.workItemSettings.loading;
    },
  },
  watch: {
    workItemType() {
      // Reinitialize form whenever the workItemType prop changes
      this.initializeForm();
    },
    isVisible(newValue) {
      if (newValue) {
        this.initializeForm();
      }
    },
  },
  methods: {
    initializeForm() {
      this.form = {
        name: this.workItemType?.name || '',
        iconName: this.workItemType?.iconName || this.workItemTypeIcons[0]?.name,
        enabled: this.workItemType?.enabled ?? true,
      };
      this.showErrors = false;
      this.errors = {};
    },
    async handleSubmit() {
      if (!this.isFormValid) {
        this.showErrors = true;
        this.errors = this.formValidationErrors;
        return;
      }

      this.isSubmitting = true;

      const input = {
        name: this.form.name,
        iconName: this.form.iconName,
        enabledByDefaultForNewNamespaces: this.form.enabled,
      };

      if (this.fullPath) {
        input.fullPath = this.fullPath;
      }

      if (this.isEditMode) {
        input.id = this.workItemType.id;
      }

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.isEditMode ? workItemTypeUpdateMutation : workItemTypeCreateMutation,
          variables: {
            input,
          },
          ...(this.isEditMode
            ? {
                optimisticResponse: {
                  workItemTypeUpdate: {
                    __typename: 'WorkItemTypeUpdatePayload',
                    errors: [],
                    workItemType: {
                      ...this.workItemType,
                      __typename: 'WorkItemType',
                      name: this.form.name,
                      iconName: input.iconName || this.workItemType.iconName,
                    },
                  },
                },
              }
            : {
                update: (cache, { data: responseData }) => {
                  const newType = responseData?.workItemTypeCreate?.workItemType;
                  if (!newType || responseData.workItemTypeCreate.errors?.length) return;

                  this.updateWorkItemTypesCache(cache, newType);
                },
              }),
        });

        const mutationResponse = this.isEditMode
          ? data?.workItemTypeUpdate
          : data?.workItemTypeCreate;

        if (mutationResponse?.errors?.length) {
          const errorMessage = mutationResponse?.errors.join(', ');
          throw new Error(errorMessage);
        }

        this.$emit('success', {
          workItemType: mutationResponse?.workItemType,
        });
        this.$emit('close');
      } catch (error) {
        const errorMessage = error.message;
        this.errors = { ...this.errors, form: errorMessage };
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    updateWorkItemTypesCache(cache, newType) {
      if (this.fullPath) {
        const queryArgs = {
          query: workItemTypesConfigurationQuery,
          variables: { fullPath: this.fullPath },
        };

        const sourceData = cache.readQuery(queryArgs);
        if (!sourceData) return;

        const updatedData = produce(sourceData, (draft) => {
          draft.namespace.workItemTypes.nodes.push(newType);
        });

        cache.writeQuery({ ...queryArgs, data: updatedData });
      } else {
        const queryArgs = { query: organizationWorkItemTypesQuery };

        const sourceData = cache.readQuery(queryArgs);

        if (!sourceData) return;

        const updatedData = produce(sourceData, (draft) => {
          draft.organization.workItemTypes.nodes.push(newType);
        });

        cache.writeQuery({ ...queryArgs, data: updatedData });
      }
    },
    handleCancel() {
      this.initializeForm();
      this.$emit('close');
    },
    handleClose() {
      this.initializeForm();
      this.$emit('close');
    },
    onVisibilityChange(visible) {
      if (visible) {
        this.initializeForm();
      }
    },
    handleIconKeydown(event) {
      const allIconNavigationKeys = [
        ...ICON_NAVIGATION_KEYS.PREVIOUS,
        ...ICON_NAVIGATION_KEYS.NEXT,
        ...ICON_NAVIGATION_KEYS.IGNORE,
      ];

      if (!allIconNavigationKeys.includes(event.key)) {
        return;
      }

      event.preventDefault();

      const currentIndex = this.typeIconNames.indexOf(this.form.iconName);
      if (currentIndex < 0) return;

      let newIndex = currentIndex;

      if (ICON_NAVIGATION_KEYS.PREVIOUS.includes(event.key)) {
        newIndex = currentIndex === 0 ? this.typeIconNames.length - 1 : currentIndex - 1;
      } else if (ICON_NAVIGATION_KEYS.NEXT.includes(event.key)) {
        newIndex = currentIndex === this.typeIconNames.length - 1 ? 0 : currentIndex + 1;
      }

      this.form.iconName = this.typeIconNames[newIndex];
      this.focusIcon(newIndex);
    },
    focusIcon(index) {
      this.$nextTick(() => {
        const iconRefs = this.$refs[`icon-${this.typeIconNames[index]}`];
        if (iconRefs && iconRefs.length) {
          iconRefs[0].focus();
        }
      });
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="isVisible"
    :title="modalTitle"
    size="sm"
    modal-id="create-edit-work-item-type-modal"
    @hidden="handleClose"
    @change="onVisibilityChange"
  >
    <gl-form @submit.prevent="handleSubmit">
      <gl-alert v-if="errors.form" class="gl-mb-4" variant="danger" @dismiss="errors.form = ''">
        {{ errors.form }}
      </gl-alert>

      <div class="gl-flex gl-gap-3">
        <gl-form-group
          :label="s__('WorkItem|Name')"
          label-for="work-item-type-name"
          :state="nameErrorState"
          :invalid-feedback="errors.name"
          class="gl-mb-4 gl-flex-1"
        >
          <gl-form-input
            id="work-item-type-name"
            v-model="form.name"
            :maxlength="48"
            :placeholder="s__('WorkItem|Bug')"
            :state="nameErrorState"
            data-testid="work-item-type-name-input"
            autocomplete="off"
          />
        </gl-form-group>
      </div>

      <gl-form-group class="gl-mb-4">
        <template #label>
          <span id="icon-selection-legend">
            {{ s__('WorkItem|Icon') }}
          </span>
        </template>

        <gl-form-radio-group
          id="work-item-type-icon"
          class="icon-selection-set gl-flex gl-flex-wrap gl-gap-3"
          :checked="form.iconName"
        >
          <div aria-live="polite" aria-atomic="true" class="gl-sr-only">
            {{ typeIconToLabelMap[form.iconName] }}
          </div>
          <label
            v-for="icon in workItemTypeIcons"
            :ref="`icon-${icon.name}`"
            :key="icon.name"
            class="gl-flex gl-cursor-pointer gl-items-center gl-rounded-lg gl-p-3 gl-transition-colors"
            :class="form.iconName === icon.name ? 'selected-icon' : ''"
            :style="
              form.iconName === icon.name
                ? { backgroundColor: 'var(--gl-control-background-color-selected-default)' }
                : { backgroundColor: 'var(--gl-control-background-color-default)' }
            "
            :aria-label="icon.label"
            role="radio"
            :aria-checked="form.iconName === icon.name"
            :tabindex="form.iconName === icon.name ? 0 : -1"
            @click="form.iconName = icon.name"
            @keydown="handleIconKeydown"
          >
            <gl-form-radio
              :value="icon.name"
              data-testid="ci-variable-visible-radio"
              tabindex="-1"
              class="gl-sr-only"
            />
            <gl-icon
              :name="icon.name"
              :size="16"
              :style="form.iconName === icon.name ? { filter: 'invert(1)' } : {}"
            />
          </label>
        </gl-form-radio-group>
      </gl-form-group>

      <gl-form-group class="gl-mb-4">
        <gl-loading-icon v-if="isLoading" />
        <gl-form-checkbox
          v-else
          v-model="form.enabled"
          :disabled="typeCustomizationDisabled"
          data-testid="work-item-type-enabled-checkbox"
        >
          <div class="gl-mb-2">{{ s__('WorkItem|Enabled by default') }}</div>
          <div>
            {{ s__('WorkItem|Enable this type automatically for any new projects.') }}
          </div>
        </gl-form-checkbox>
      </gl-form-group>
    </gl-form>

    <template #modal-footer>
      <gl-button data-testid="work-item-type-cancel-button" @click="handleCancel">
        {{ s__('WorkItem|Cancel') }}
      </gl-button>
      <gl-button
        variant="confirm"
        :loading="isSubmitting"
        data-testid="work-item-type-submit-button"
        @click="handleSubmit"
      >
        {{ s__('WorkItem|Save') }}
      </gl-button>
    </template>
  </gl-modal>
</template>
