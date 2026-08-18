<script>
import { GlForm, GlButton, GlFormInput, GlFormGroup, GlFormFields } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import csrf from '~/lib/utils/csrf';
import { __ } from '~/locale';

export default {
  name: 'SubscriptionWelcomeForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormInput,
    GlFormGroup,
    GlFormFields,
  },
  props: {
    userData: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    namespaceId: {
      type: [Number, String],
      required: false,
      default: null,
    },
    serverValidations: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      formValues: {
        first_name: this.userData.firstName,
        last_name: this.userData.lastName,
        company_name: this.userData.companyName,
        group_name: this.userData.groupName,
        project_name: this.userData.projectName,
        namespace_id: this.namespaceId,
      },
    };
  },
  computed: {
    fields() {
      const result = {};

      if (this.userData.showNameFields) {
        result.first_name = {
          label: __('First name'),
          groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6 gl-mb-6' },
          inputAttrs: { name: 'first_name' },
          validators: [formValidators.required(__('First name is required.'))],
        };

        result.last_name = {
          label: __('Last name'),
          groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6 gl-mb-6' },
          inputAttrs: { name: 'last_name' },
          validators: [formValidators.required(__('Last name is required.'))],
        };
      }

      result.company_name = {
        label: __('Company name'),
        groupAttrs: { class: 'gl-col-span-12 gl-mb-6' },
        inputAttrs: { name: 'company_name' },
        validators: [formValidators.required(__('Company name is required.'))],
      };

      const isGroupNameRequired = !this.namespaceId;

      result.group_name = {
        label: null,
        groupAttrs: { class: 'gl-col-span-12 gl-mb-3' },
        inputAttrs: {
          name: 'group_name',
          disabled: !isGroupNameRequired,
        },
        validators: isGroupNameRequired
          ? [formValidators.required(__('Group name is required.'))]
          : [],
      };

      result.project_name = {
        label: null,
        groupAttrs: { class: 'gl-col-span-12 gl-mb-3' },
        inputAttrs: { name: 'project_name' },
        validators: [formValidators.required(__('Project name is required.'))],
      };

      result.namespace_id = {
        label: '',
        groupAttrs: { class: 'gl-hidden' },
      };

      return result;
    },
  },
  methods: {
    onCompanyNameChange(input, text) {
      input(text);
      if (text) {
        this.formValues.group_name = `${text}-${this.$options.i18n.group}`;
        this.formValues.project_name = `${text}-${this.$options.i18n.project}`;
      }
    },
    onSubmit() {
      this.$refs.form.$el.submit();
    },
  },
  i18n: {
    group: __('group'),
    project: __('project'),
  },
  formId: 'subscription-welcome-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    method="post"
    data-testid="subscription-welcome-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <input type="hidden" name="_method" value="patch" />

    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid gl-grid-cols-12 md:gl-gap-x-6"
      :server-validations="serverValidations"
      @submit="onSubmit"
    >
      <template v-if="!userData.showNameFields" #after(company_name)>
        <input
          type="hidden"
          :value="userData.firstName"
          name="first_name"
          data-testid="hidden-first-name"
        />
        <input
          type="hidden"
          :value="userData.lastName"
          name="last_name"
          data-testid="hidden-last-name"
        />
      </template>

      <template
        #input(company_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-input
          :id="id"
          name="company_name"
          :value="value"
          :state="validation.state"
          data-testid="company-name"
          @input="onCompanyNameChange(input, $event)"
          @blur="blur"
        />
      </template>

      <template
        #input(group_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-group
          :label="__('Group name')"
          :label-description="
            s__('InProductMarketing|A group is your workspace for managing members and settings')
          "
          :label-for="id"
        >
          <gl-form-input
            :id="id"
            name="group_name"
            :value="value"
            :state="validation.state"
            :disabled="fields.group_name.inputAttrs.disabled"
            @input="input"
            @blur="blur"
          />
        </gl-form-group>
      </template>

      <template
        #input(project_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-group
          :label="__('Project name')"
          :label-description="
            s__(
              'InProductMarketing|A project is a Git repository plus extra features for collaboration',
            )
          "
          :label-for="id"
        >
          <gl-form-input
            :id="id"
            name="project_name"
            :value="value"
            :state="validation.state"
            @input="input"
            @blur="blur"
          />
        </gl-form-group>
      </template>

      <template #input(namespace_id)="{ value }">
        <input type="hidden" :value="value" name="namespace_id" />
      </template>
    </gl-form-fields>

    <gl-button type="submit" variant="confirm" block class="js-no-auto-disable">
      {{ __('Continue') }}
    </gl-button>
  </gl-form>
</template>
