<script>
import { GlForm, GlButton, GlSprintf, GlLink, GlFormFields, GlFormInput } from '@gitlab/ui';
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
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import countryStateMixin from 'ee/vue_shared/mixins/country_state_mixin';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import {
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_TERMS_TEXT,
  TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
  TRIAL_PRIVACY_STATEMENT,
  TRIAL_COOKIE_POLICY,
  TRIAL_STATE_LABEL,
  TRIAL_STATE_PROMPT,
} from '../constants';

export const CREATE_GROUP_OPTION_VALUE = '0';

export default {
  name: 'CreateTrialForm',
  csrf,
  components: {
    ListboxInput,
    GlForm,
    GlButton,
    GlFormInput,
    GlSprintf,
    GlLink,
    GlFormFields,
  },
  directives: {
    autofocusonshow,
  },
  mixins: [countryStateMixin],
  props: {
    userData: {
      type: Object,
      required: true,
    },
    namespaceData: {
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
    border: {
      type: Boolean,
      required: true,
    },
    canCreateGroup: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  data() {
    return {
      serverValidations: { new_group_name: this.namespaceData.createErrors },
      formValues: {},
      // eslint-disable-next-line vue/no-unused-properties
      skipCountryStateQueries: false, // used by mixin
    };
  },
  computed: {
    showNamespaceSelector() {
      return this.namespaceData.anyTrialEligibleNamespaces;
    },
    showNewGroupNameField() {
      return (
        !this.namespaceData.anyTrialEligibleNamespaces ||
        this.formValues.group === CREATE_GROUP_OPTION_VALUE
      );
    },
    showCreateGroupButton() {
      return this.canCreateGroup && this.formValues.group !== CREATE_GROUP_OPTION_VALUE;
    },
    groupOptions() {
      return [
        ...(this.formValues.group === CREATE_GROUP_OPTION_VALUE ? [this.createGroupOption] : []),
        ...this.namespaceData.items,
      ];
    },
    fields() {
      const result = {};

      if (this.showNamespaceSelector) {
        result.group = {
          label: __('Group'),
          groupAttrs: {
            labelDescription: __('Your trial will be applied to this group.'),
            class: 'gl-col-span-12',
            'data-testid': 'group-dropdown-container',
          },
          validators: [
            formValidators.factory(__('Please select a group for your trial.'), (fieldValue) => {
              return fieldValue || !this.namespaceData.anyTrialEligibleNamespaces;
            }),
          ],
        };
      }

      if (this.showNewGroupNameField) {
        result.new_group_name = {
          label: __('New group name'),
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          validators: [formValidators.required(__('You must enter a new group name.'))],
        };
      }

      if (this.userData.showNameFields) {
        Object.assign(result, {
          first_name: {
            label: LEADS_FIRST_NAME_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12 @md/panel:gl-col-span-6',
            },
            inputAttrs: {
              name: 'first_name',
              'data-testid': 'first-name-field',
            },
            validators: [formValidators.required(__('First name is required.'))],
          },
          last_name: {
            label: LEADS_LAST_NAME_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12 @md/panel:gl-col-span-6',
            },
            inputAttrs: {
              name: 'last_name',
              'data-testid': 'last-name-field',
            },
            validators: [formValidators.required(__('Last name is required.'))],
          },
        });
      }

      Object.assign(result, {
        company_name: {
          label: LEADS_COMPANY_NAME_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          inputAttrs: {
            name: 'company_name',
            'data-testid': 'company-name-field',
          },
          validators: [formValidators.required(__('Company name is required.'))],
        },
      });

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
            'data-testid': 'country-dropdown-container',
          },
          validators: [formValidators.required(__('Country or region is required.'))],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
              'data-testid': 'state-dropdown-container',
            },
            validators: [
              formValidators.factory(__('State or province is required.'), (fieldValue) => {
                return !this.stateRequired || (this.stateRequired && fieldValue);
              }),
            ],
          };
        }
      }

      result.phone_number = {
        label: LEADS_PHONE_NUMBER_LABEL,
        groupAttrs: {
          optional: true,
          class: 'gl-col-span-12',
        },
        inputAttrs: {
          name: 'phone_number',
          'data-testid': 'phone-number-field',
        },
        validators: [
          formValidators.factory(TRIAL_PHONE_DESCRIPTION, (val) => {
            if (!val || val.trim() === '') {
              return true;
            }
            return /^\+?[0-9\-\s]+$/.test(val);
          }),
        ],
      };

      return result;
    },
    createGroupOption() {
      return { value: CREATE_GROUP_OPTION_VALUE, text: __('Create group') };
    },
  },
  mounted() {
    this.formValues = {
      group: this.namespaceData.initialValue,
      new_group_name: this.namespaceData.newGroupName,
      first_name: this.userData.firstName,
      last_name: this.userData.lastName,
      company_name: this.userData.companyName,
      country: this.userData.country,
      state: this.userData.state,
      phone_number: this.userData.phoneNumber,
    };
  },
  methods: {
    onSubmit() {
      trackSaasTrialLeadSubmit(this.gtmSubmitEventLabel, this.userData.emailDomain);
      this.$refs.form.$el.submit();
    },
    handleCreateGroupClick(onSelect) {
      onSelect(CREATE_GROUP_OPTION_VALUE);
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
    countryPrompt: LEADS_COUNTRY_PROMPT,
    statePrompt: TRIAL_STATE_PROMPT,
    buttonText: s__('Trial|Activate my trial'),
    termsText: TRIAL_TERMS_TEXT,
    gitlabSubscription: TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT,
    privacyStatement: TRIAL_PRIVACY_STATEMENT,
    cookiePolicy: TRIAL_COOKIE_POLICY,
    creditsNote: s__(
      'Trial|Any purchased GitLab Credits will continue to be used during your trial.',
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
    :class="['gl-p-6', { 'gl-border-1 gl-border-solid gl-border-gray-100 gl-p-6': border }]"
    data-testid="trial-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid @md/panel:gl-gap-x-4"
      :server-validations="serverValidations"
      @submit="onSubmit"
    >
      <template #input(group)="{ id, value, input }">
        <listbox-input
          :toggle-id="id"
          :selected="value"
          name="namespace_id"
          label-for="namespace_id"
          :items="groupOptions"
          :default-toggle-text="__('Select a group')"
          :block="true"
          :fluid-width="true"
          data-testid="namespace-dropdown"
          @select="(val) => input && input(val)"
        >
          <template v-if="showCreateGroupButton" #footer="{ onSelect }">
            <div
              class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown-divider !gl-p-2 !gl-pt-0 gl-border-t-solid"
            >
              <gl-button
                category="tertiary"
                block
                class="!gl-mt-2 !gl-justify-start"
                data-testid="footer-bottom-button"
                @click="handleCreateGroupClick(onSelect)"
              >
                {{ __('Create group') }}
              </gl-button>
            </div>
          </template>
        </listbox-input>
      </template>
      <template #input(new_group_name)="{ id, value, input, validation }">
        <gl-form-input
          :id="id"
          ref="newGroupNameInput"
          v-autofocusonshow
          :value="value"
          :state="validation.state"
          name="new_group_name"
          @input="input"
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
    </gl-form-fields>
    <gl-button
      type="submit"
      variant="confirm"
      data-testid="submit-button"
      class="js-no-auto-disable gl-w-full"
      :disabled="isLoadingCountryOrState"
    >
      {{ $options.i18n.buttonText }}
    </gl-button>
    <div class="gl-mt-5 gl-text-sm gl-text-subtle">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #buttonText>{{ $options.i18n.buttonText }}</template>
        <template #gitlabSubscriptionAgreement>
          <gl-link :href="$options.i18n.gitlabSubscription.url" target="_blank">
            {{ $options.i18n.gitlabSubscription.text }}
          </gl-link>
        </template>
        <template #privacyStatement>
          <gl-link :href="$options.i18n.privacyStatement.url" target="_blank">
            {{ $options.i18n.privacyStatement.text }}
          </gl-link>
        </template>
        <template #cookiePolicy>
          <gl-link :href="$options.i18n.cookiePolicy.url" target="_blank">
            {{ $options.i18n.cookiePolicy.text }}
          </gl-link>
        </template>
      </gl-sprintf>

      <div class="gl-mt-5">
        {{ $options.i18n.creditsNote }}
      </div>
    </div>
  </gl-form>
</template>
