<script>
import {
  GlForm,
  GlButton,
  GlFormCheckbox,
  GlSprintf,
  GlLink,
  GlFormFields,
  GlFormInput,
} from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import countryStateMixin from 'ee/vue_shared/mixins/country_state_mixin';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import { PROMO_URL } from '~/constants';
import { InternalEvents } from '~/tracking';

export default {
  name: 'CreateTrialForm',
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormCheckbox,
    GlSprintf,
    GlLink,
    GlFormFields,
    GlFormInput,
    ListboxInput,
  },
  mixins: [countryStateMixin, InternalEvents.mixin()],
  props: {
    userData: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      formValues: {
        first_name: this.userData.firstName || '',
        last_name: this.userData.lastName || '',
        email_address: this.userData.emailAddress || '',
        company_name: '',
        country: '',
        state: '',
        consent_to_marketing: '',
      },
      consentToMarketingValue: '1',
      // eslint-disable-next-line vue/no-unused-properties
      skipCountryStateQueries: false, // used by mixin
    };
  },
  computed: {
    fields() {
      const groupAttrs = { class: 'gl-col-span-12' };

      const fields = {
        first_name: {
          label: this.$options.i18n.firstNameLabel,
          groupAttrs: { class: 'gl-col-span-12 @md/panel:gl-col-span-6' },
          validators: [formValidators.required(__('First name is required.'))],
        },
        last_name: {
          label: this.$options.i18n.lastNameLabel,
          groupAttrs: { class: 'gl-col-span-12 @md/panel:gl-col-span-6' },
          validators: [formValidators.required(__('Last name is required.'))],
        },
        email_address: {
          label: this.$options.i18n.emailAddressLabel,
          groupAttrs,
          validators: [formValidators.required(__('Email address is required.'))],
        },
        company_name: {
          label: this.$options.i18n.companyNameLabel,
          groupAttrs,
          validators: [formValidators.required(__('Company name is required.'))],
        },
        country: {
          label: this.$options.i18n.countryLabel,
          groupAttrs,
          validators: [formValidators.required(__('Country or region is required.'))],
        },
      };

      if (this.showState) {
        fields.state = {
          label: this.$options.i18n.stateLabel,
          groupAttrs,
          validators: [formValidators.required(__('State or province is required.'))],
        };
      }

      return fields;
    },
    isSubmitDisabled() {
      return this.isLoadingCountryOrState;
    },
  },
  mounted() {
    this.trackEvent('sm_trial_create_form_render');
  },
  methods: {
    onSubmit() {
      this.trackEvent('sm_trial_create_form_submit_click');
      this.$refs.form.$el.submit();
    },
    onConsentChange(checked) {
      if (checked === '0') {
        this.trackEvent('sm_trial_create_form_uncheck_consent');
      }
      this.consentToMarketingValue = checked;
    },
  },
  i18n: {
    firstNameLabel: s__('Trial|First name'),
    lastNameLabel: s__('Trial|Last name'),
    emailAddressLabel: s__('Trial|Work email address'),
    companyNameLabel: s__('Trial|Company name'),
    countryPrompt: s__('Trial|Select a country or region'),
    countryLabel: s__('Trial|Country or region'),
    statePrompt: s__('Trial|Select state or province'),
    stateLabel: s__('Trial|State or province'),
    consentToMarketingLabel: s__(
      'Trial|I agree that GitLab can contact me by email about its product, services, or events.',
    ),
    submitButtonLabel: s__('Trial|Get started'),
    termsText: s__(
      'Trial|By clicking %{buttonText} you accept the %{subscriptionAgreement} and acknowledge the %{privacyStatement}.',
    ),
    subscriptionAgreement: {
      text: s__('Trial|GitLab Subscription Agreement'),
      url: `${PROMO_URL}/handbook/legal/subscription-agreement`,
    },
    privacyStatement: {
      text: s__('Trial|Privacy Statement'),
      url: `${PROMO_URL}/privacy`,
    },
  },
  formId: 'start-sm-trial-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    method="post"
    data-testid="sm-trial-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid gl-grid-cols-12 gl-gap-x-4 gl-gap-y-2"
      @submit="onSubmit"
    >
      <template #input(first_name)="{ id, value, input = () => {}, blur = () => {} }">
        <gl-form-input
          :id="id"
          name="first_name"
          :value="value"
          data-testid="first-name-input"
          @input="input"
          @blur="blur"
        />
      </template>
      <template #input(last_name)="{ id, value, input = () => {}, blur = () => {} }">
        <gl-form-input
          :id="id"
          name="last_name"
          :value="value"
          data-testid="last-name-input"
          @input="input"
          @blur="blur"
        />
      </template>
      <template #input(email_address)="{ id, value, input = () => {}, blur = () => {} }">
        <gl-form-input
          :id="id"
          name="email_address"
          type="email"
          :value="value"
          data-testid="email-address-input"
          @input="input"
          @blur="blur"
        />
      </template>
      <template #input(company_name)="{ id, value, input = () => {}, blur = () => {} }">
        <gl-form-input
          :id="id"
          name="company_name"
          :value="value"
          data-testid="company-name-input"
          @input="input"
          @blur="blur"
        />
      </template>
      <template #input(country)="{ value, input }">
        <listbox-input
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
      <template #input(state)="{ value, input }">
        <listbox-input
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

    <div class="gl-mt-3">
      <input type="hidden" name="consent_to_marketing" :value="consentToMarketingValue" />
      <gl-form-checkbox
        :checked="consentToMarketingValue"
        value="1"
        unchecked-value="0"
        data-testid="consent-checkbox"
        @change="onConsentChange"
      >
        {{ $options.i18n.consentToMarketingLabel }}
      </gl-form-checkbox>
    </div>

    <gl-button
      class="js-no-auto-disable gl-my-3 gl-w-full"
      type="submit"
      variant="confirm"
      data-testid="submit-button"
      :disabled="isSubmitDisabled"
    >
      {{ $options.i18n.submitButtonLabel }}
    </gl-button>

    <div class="gl-mt-5 gl-text-base">
      <gl-sprintf :message="$options.i18n.termsText">
        <template #buttonText
          ><strong>{{ $options.i18n.submitButtonLabel }}</strong></template
        >
        <template #subscriptionAgreement>
          <gl-link :href="$options.i18n.subscriptionAgreement.url" target="_blank">
            {{ $options.i18n.subscriptionAgreement.text }}
          </gl-link>
        </template>
        <template #privacyStatement>
          <gl-link :href="$options.i18n.privacyStatement.url" target="_blank">
            {{ $options.i18n.privacyStatement.text }}
          </gl-link>
        </template>
      </gl-sprintf>
    </div>
  </gl-form>
</template>
