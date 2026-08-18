<script>
import { GlForm, GlButton, GlFormFields } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_COUNTRY_LABEL,
  LEADS_COUNTRY_PROMPT,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import csrf from '~/lib/utils/csrf';
import { __, s__, sprintf } from '~/locale';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import countryStateMixin from 'ee/vue_shared/mixins/country_state_mixin';
import {
  TRIAL_PHONE_DESCRIPTION,
  TRIAL_STATE_PROMPT,
  TRIAL_STATE_LABEL,
} from 'ee/trials/constants';
import { trackCompanyForm } from 'ee/google_tag_manager';
import Tracking from '~/tracking';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';

export default {
  name: 'CompanyForm',
  csrf,
  components: {
    ListboxInput,
    GlForm,
    GlButton,
    GlFormFields,
  },
  mixins: [countryStateMixin],
  inject: {
    user: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
    showFormFooter: {
      type: Boolean,
      required: true,
    },
    trackActionForErrors: {
      type: String,
      required: true,
    },
    trialDuration: {
      type: String,
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
    formSubmitText() {
      if (this.showFormFooter) {
        return s__('Trial|Continue with trial');
      }

      return s__('Trial|Continue');
    },
    footerDescriptionText() {
      return sprintf(
        s__(
          'Trial|Try GitLab Ultimate and automate tasks with GitLab Duo Agent Platform free for %{duration} days. After that, continue with free features or upgrade to a paid plan.',
        ),
        { duration: this.trialDuration },
      );
    },
    fields() {
      const result = {};

      if (this.user.showNameFields) {
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
          },
          validators: [formValidators.required(__('Company name is required.'))],
        },
      });

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          validators: [formValidators.required(__('Country or region is required.'))],
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
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
  },
  mounted() {
    this.formValues = {
      first_name: this.user.firstName,
      last_name: this.user.lastName,
      company_name: this.user.companyName,
      phone_number: this.user.phoneNumber,
      country: this.user.country,
      state: this.user.state,
    };
  },
  methods: {
    onSubmit() {
      trackCompanyForm('ultimate_trial', this.user.emailDomain);
      this.$refs.form.$el.submit();
    },
    onFieldValidation(event) {
      if (!event.state) {
        this.trackFieldError(event);
      }
    },
    trackFieldError(event) {
      const { fieldName } = event;
      const action = FormErrorTracker.formattedAction(this.trackActionForErrors);
      const label = FormErrorTracker.formattedLabel(fieldName);

      Tracking.event(undefined, action, { label });
    },
  },
  i18n: {
    countryPrompt: LEADS_COUNTRY_PROMPT,
    statePrompt: TRIAL_STATE_PROMPT,
  },
  formId: 'company-form',
};
</script>

<template>
  <gl-form
    :id="$options.formId"
    ref="form"
    :action="submitPath"
    class="gl-border-1 gl-border-solid gl-border-default gl-p-6"
    method="post"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />

    <gl-form-fields
      v-model="formValues"
      :form-id="$options.formId"
      :fields="fields"
      class="gl-grid @md/panel:gl-gap-x-4"
      @field-validation="onFieldValidation"
      @submit="onSubmit"
    >
      <template v-if="!user.showNameFields" #after(company_name)>
        <input
          type="hidden"
          :value="user.firstName"
          name="first_name"
          data-testid="hidden-first-name"
        />
        <input
          type="hidden"
          :value="user.lastName"
          name="last_name"
          data-testid="hidden-last-name"
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
          :aria-label="$options.i18n.countryPrompt"
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
          :aria-label="$options.i18n.statePrompt"
          data-testid="state-dropdown"
          @select="(val) => input && input(val)"
        />
      </template>
    </gl-form-fields>

    <gl-button
      type="submit"
      variant="confirm"
      class="js-no-auto-disable gl-w-full"
      :disabled="isLoadingCountryOrState"
    >
      {{ formSubmitText }}
    </gl-button>

    <div v-if="showFormFooter" class="gl-mt-4">
      <span data-testid="footer_description_text" class="gl-text-sm gl-text-subtle">
        {{ footerDescriptionText }}
      </span>
    </div>
  </gl-form>
</template>
