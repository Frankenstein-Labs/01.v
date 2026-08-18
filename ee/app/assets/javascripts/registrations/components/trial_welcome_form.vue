<script>
import { GlForm, GlButton, GlFormInput, GlFormFields } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COUNTRY_LABEL,
  LEADS_COUNTRY_PROMPT,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
} from 'ee/vue_shared/leads/constants';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import countryStateMixin from 'ee/vue_shared/mixins/country_state_mixin';
import { TRIAL_STATE_PROMPT, TRIAL_STATE_LABEL } from 'ee/trials/constants';

const SETUP_FOR_COMPANY_OPTIONS = [
  { value: 'true', text: __('My team') },
  { value: 'false', text: __('Just me') },
];

export default {
  name: 'CreateUnifiedTrialWelcomeForm',
  csrf,
  components: {
    ListboxInput,
    GlForm,
    GlButton,
    GlFormFields,
    GlFormInput,
  },
  mixins: [countryStateMixin],
  props: {
    userData: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    gtmSubmitEventLabel: {
      type: String,
      required: true,
    },
    namespaceId: {
      type: Number,
      required: false,
      default: null,
    },
    serverValidations: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    roleOptions: {
      type: Array,
      required: true,
    },
    registrationObjectiveOptions: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      formValues: {},
      // eslint-disable-next-line vue/no-unused-properties
      skipCountryStateQueries: false, // used by mixin
    };
  },
  computed: {
    fields() {
      const result = {};

      if (this.userData.showNameFields) {
        Object.assign(result, {
          first_name: {
            label: LEADS_FIRST_NAME_LABEL,
            groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6' },
            inputAttrs: { name: 'first_name' },
            validators: [formValidators.required(__('First name is required.'))],
          },
          last_name: {
            label: LEADS_LAST_NAME_LABEL,
            groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6' },
            inputAttrs: { name: 'last_name' },
            validators: [formValidators.required(__('Last name is required.'))],
          },
        });
      }

      result.company_name = {
        label: LEADS_COMPANY_NAME_LABEL,
        groupAttrs: { class: 'gl-col-span-12' },
        inputAttrs: { name: 'company_name' },
        validators: [formValidators.required(__('Company name is required.'))],
      };

      let groupNameValidators = [];
      if (this.namespaceId === null)
        groupNameValidators = [formValidators.required(__('Group name is required.'))];

      result.group_name = {
        label: __('Group name'),
        groupAttrs: {
          labelDescription: this.$options.i18n.groupDescription,
          class: 'gl-col-span-12',
        },
        inputAttrs: { disabled: this.namespaceId !== null },
        validators: groupNameValidators,
      };

      result.project_name = {
        label: __('Project name'),
        groupAttrs: {
          labelDescription: this.$options.i18n.projectDescription,
          class: 'gl-col-span-12 gl-mb-0',
        },
        validators: [formValidators.required(__('Project name is required.'))],
      };

      result.namespace_id = {
        label: '',
        groupAttrs: { class: 'gl-hidden' },
      };

      result.role = {
        label: __('Role'),
        groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6' },
        validators: [formValidators.required(__('Role is required.'))],
        options: this.roleOptions,
      };

      result.setup_for_company = {
        label: __('Who will be using GitLab?'),
        groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6' },
        validators: [formValidators.required(__('This field is required.'))],
        options: SETUP_FOR_COMPANY_OPTIONS,
      };

      result.registration_objective = {
        label: s__("Trial|What's your reason for joining GitLab?"),
        groupAttrs: { class: 'gl-col-span-12' },
        validators: [formValidators.required(__('This field is required.'))],
        options: this.registrationObjectiveOptions,
      };

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: this.showState ? 'gl-col-span-12 md:gl-col-span-6' : 'gl-col-span-12',
          },
          validators: [formValidators.required(__('Country or region is required.'))],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: { class: 'gl-col-span-12 md:gl-col-span-6' },
            validators: [formValidators.required(__('State or province is required.'))],
          };
        }
      }

      return result;
    },
  },
  mounted() {
    this.formValues = {
      first_name: this.userData.firstName,
      last_name: this.userData.lastName,
      company_name: this.userData.companyName,
      country: this.userData.country,
      state: this.userData.state,
      group_name: this.userData.groupName || '',
      project_name: this.userData.projectName || '',
      namespace_id: this.namespaceId,
      role: this.userData.role || '',
      setup_for_company: this.userData.setupForCompany || '',
      registration_objective: this.userData.registrationObjective || '',
    };
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.userData.emailDomain);
      this.$refs.form.$el.submit();
    },
    onCompanyNameChange(input, text) {
      input(text);
      if (text) {
        this.formValues.group_name = `${text}-${this.$options.i18n.group}`;
        this.formValues.project_name = `${text}-${this.$options.i18n.project}`;
      }
    },
  },
  i18n: {
    countryPrompt: LEADS_COUNTRY_PROMPT,
    statePrompt: TRIAL_STATE_PROMPT,
    group: __('group'),
    project: __('project'),
    rolePrompt: s__('MemberRole|Select a role'),
    setupForCompanyPrompt: __('Please select'),
    registrationObjectivePrompt: __('Select a reason'),
    groupDescription: s__(
      'InProductMarketing|A group is your workspace for managing members and settings',
    ),
    projectDescription: s__(
      'InProductMarketing|A project is a Git repository plus extra features for collaboration',
    ),
  },
  formId: 'create-trial-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    method="post"
    data-testid="trial-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <input type="hidden" name="_method" value="put" />
    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-mb-3 gl-grid gl-grid-cols-12 gl-gap-y-3 md:gl-gap-x-6"
      :server-validations="serverValidations"
      @submit="onSubmit"
    >
      <template
        #input(company_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-input
          :id="id"
          name="company_name"
          :value="value"
          :state="validation.state"
          @input="onCompanyNameChange(input, $event)"
          @blur="blur"
        />
      </template>
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
        #input(group_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-input
          :id="id"
          name="group_name"
          :value="value"
          :state="validation.state"
          :disabled="fields.group_name.inputAttrs.disabled"
          data-testid="group-name-input"
          @input="input"
          @blur="blur"
        />
      </template>
      <template
        #input(project_name)="{ id, value, validation = {}, input = () => {}, blur = () => {} }"
      >
        <gl-form-input
          :id="id"
          name="project_name"
          :value="value"
          :state="validation.state"
          data-testid="project-name-input"
          @input="input"
          @blur="blur"
        />
      </template>

      <template #after(project_name)>
        <hr class="gl-col-span-12 gl-border-subtle" />
      </template>

      <template #input(role)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="onboarding_status_role"
          :items="fields.role.options"
          :default-toggle-text="$options.i18n.rolePrompt"
          :block="true"
          data-testid="role-dropdown"
          @select="(val) => input && input(val)"
        />
      </template>
      <template #input(setup_for_company)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="onboarding_status_setup_for_company"
          :items="fields.setup_for_company.options"
          :default-toggle-text="$options.i18n.setupForCompanyPrompt"
          :block="true"
          @select="(val) => input && input(val)"
        />
      </template>
      <template #input(registration_objective)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="onboarding_status_registration_objective"
          :items="fields.registration_objective.options"
          :default-toggle-text="$options.i18n.registrationObjectivePrompt"
          :block="true"
          @select="(val) => input && input(val)"
        />
      </template>
      <template #input(country)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="country"
          :items="countries"
          :default-toggle-text="$options.i18n.countryPrompt"
          :block="true"
          :loading="isLoadingCountryOrState"
          data-testid="country-dropdown"
          @select="onCountrySelect($event, input)"
        />
      </template>
      <template #input(state)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="state"
          :items="states"
          :default-toggle-text="$options.i18n.statePrompt"
          :block="true"
          data-testid="state-dropdown"
          @select="(val) => input && input(val)"
        />
      </template>
      <template #input(namespace_id)="{ value }">
        <input type="hidden" :value="value" name="namespace_id" />
      </template>
    </gl-form-fields>
    <gl-button
      type="submit"
      variant="confirm"
      data-testid="continue-button"
      class="js-no-auto-disable gl-w-full"
      :disabled="isLoadingCountryOrState"
    >
      {{ __('Continue') }}
    </gl-button>
  </gl-form>
</template>
