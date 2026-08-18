<script>
import {
  GlForm,
  GlFormTextarea,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormCheckbox,
  GlAlert,
  GlButton,
  GlToastMixin,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, __, n__ } from '~/locale';
import {
  DRAWER_MODES,
  STATUS_TYPES,
  ExclusionType,
  EXCLUSION_TYPE_MAP,
  StatusType,
  ExclusionScannerEnum,
} from '../constants';
import projectSecurityExclusionCreateMutation from '../graphql/project_security_exclusion_create.mutation.graphql';
import projectSecurityExclusionUpdateMutation from '../graphql/project_security_exclusion_update.mutation.graphql';

export default {
  name: 'ExclusionForm',
  components: {
    GlForm,
    GlFormTextarea,
    GlFormGroup,
    GlFormRadioGroup,
    GlFormCheckbox,
    GlAlert,
    GlButton,
  },
  mixins: [GlToastMixin],
  inject: ['projectFullPath'],
  i18n: {
    typeLabel: s__('SecurityExclusions|Type'),
    typeDescription: s__('SecurityExclusions|Select which type of content to exclude'),
    contentLabel: s__('SecurityExclusions|Value'),
    descriptionLabel: s__('SecurityExclusions|Description'),
    descriptionDescription: s__(
      'SecurityExclusions|Provide context for why the content is being excluded.',
    ),
    descriptionPlaceholder: s__('SecurityExclusions|ex: This secret is used for testing'),
    enforcementLabel: s__('SecurityExclusions|Enforcement'),
    enforcementDescription: s__(
      'SecurityExclusions|Select the secret detection methods this exclusion should apply to.',
    ),
    secretPushProtection: s__('SecurityExclusions|Secret push protection'),
    statusLabel: s__('SecurityExclusions|Status'),
    cancelButton: __('Cancel'),
    addButton: s__('SecurityExclusions|Add Exclusion'),
    saveButton: s__('SecurityExclusions|Save Changes'),
    unknownError: __('Something went wrong. Please try again.'),
  },
  projectSecurityExclusionCreateMutation,
  projectSecurityExclusionUpdateMutation,
  props: {
    exclusion: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    mode: {
      type: String,
      required: false,
      default: DRAWER_MODES.ADD,
      validator(value) {
        return Object.values(DRAWER_MODES).includes(value);
      },
    },
  },
  emits: ['cancel', 'saved'],
  data() {
    return {
      typeOptions: Object.values(EXCLUSION_TYPE_MAP),
      statusOptions: STATUS_TYPES,
      form: {
        type: this.exclusion.type || ExclusionType.PATH,
        value: this.exclusion.value || '',
        description: this.exclusion.description || '',
        secretPushProtection: this.exclusion.secretPushProtection ?? true,
        status: this.exclusion.active ?? StatusType.ENABLE,
      },
      isLoading: false,
      showAlert: false,
      errors: [],
      isEdit: this.mode === DRAWER_MODES.EDIT,
    };
  },
  computed: {
    saveButtonTitle() {
      return this.isEdit ? this.$options.i18n.saveButton : this.$options.i18n.addButton;
    },
    errorTitle() {
      return n__(
        'SecurityExclusions|The following error occured while saving the exclusion:',
        'SecurityExclusions|The following errors occured while saving the exclusion:',
        this.errors.length,
      );
    },
    selectedType() {
      return this.typeOptions.find((option) => option.value === this.form.type);
    },
    mutationVariables() {
      return {
        ...(this.isEdit ? { id: this.exclusion.id } : { projectPath: this.projectFullPath }),
        type: this.form.type,
        value: this.form.value,
        description: this.form.description,
        scanner: ExclusionScannerEnum.SECRET_PUSH_PROTECTION,
        active: this.form.status === StatusType.ENABLE,
      };
    },
  },
  methods: {
    async saveExclusions() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.isEdit
            ? projectSecurityExclusionUpdateMutation
            : projectSecurityExclusionCreateMutation,
          variables: {
            input: this.mutationVariables,
          },
        });

        const { errors } = this.isEdit
          ? data.projectSecurityExclusionUpdate
          : data.projectSecurityExclusionCreate;

        if (errors.length > 0) {
          this.showErrors(errors);
          return;
        }
        this.$toast.show(s__('SecurityExclusions|Exclusion has been created successfully'));
        this.$emit('saved');
      } catch (error) {
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
    submit() {
      this.isLoading = true;
      this.hideErrors();
      this.saveExclusions();
    },
    cancel() {
      this.$emit('cancel');
    },
    showErrors(errors = []) {
      this.errors = errors;
      this.showAlert = true;
    },
    hideErrors() {
      this.errors = [];
      this.showAlert = false;
    },
  },
};
</script>

<template>
  <gl-form @submit.prevent="submit">
    <gl-alert
      v-if="showAlert"
      variant="danger"
      :title="errorTitle"
      class="gl-mb-5"
      @dismiss="hideErrors"
    >
      <ul v-if="errors.length" class="gl-mb-0 gl-mt-3">
        <li v-for="error in errors" :key="error" v-text="error"></li>
      </ul>
    </gl-alert>
    <gl-form-group
      :label="$options.i18n.typeLabel"
      :label-description="$options.i18n.typeDescription"
    >
      <gl-form-radio-group v-model="form.type" :options="typeOptions" stacked>
        <template #help="{ option }">
          {{ option.description }}
        </template>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.contentLabel"
      :label-description="selectedType.contentDescription"
    >
      <gl-form-textarea
        v-model="form.value"
        :placeholder="selectedType.contentPlaceholder"
        rows="5"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.descriptionLabel"
      :label-description="$options.i18n.descriptionDescription"
    >
      <gl-form-textarea
        v-model="form.description"
        :placeholder="$options.i18n.descriptionPlaceholder"
        rows="3"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18n.enforcementLabel"
      :label-description="$options.i18n.enforcementDescription"
    >
      <gl-form-checkbox v-model="form.secretPushProtection" disabled>
        {{ $options.i18n.secretPushProtection }}
      </gl-form-checkbox>
    </gl-form-group>

    <gl-form-group :label="$options.i18n.statusLabel">
      <gl-form-radio-group v-model="form.status" :options="statusOptions" />
    </gl-form-group>

    <div>
      <gl-button
        :loading="isLoading"
        type="submit"
        variant="confirm"
        data-testid="form-submit-button"
        @click.prevent="submit"
        >{{ saveButtonTitle }}</gl-button
      >
      <gl-button
        class="gl-ml-3"
        variant="default"
        data-testid="form-cancel-button"
        @click="cancel"
        >{{ $options.i18n.cancelButton }}</gl-button
      >
    </div>
  </gl-form>
</template>
