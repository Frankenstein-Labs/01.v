<script>
import { GlFormTextarea, GlModal, GlFormFields } from '@gitlab/ui';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import countryStateMixin from 'ee/vue_shared/mixins/country_state_mixin';
import {
  LEADS_COUNTRY_PROMPT,
  LEADS_COUNTRY_LABEL,
  LEADS_COMPANY_NAME_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import { TRIAL_STATE_PROMPT, TRIAL_STATE_LABEL } from 'ee/trials/constants';
import {
  PQL_COMMENT_LABEL,
  PQL_HAND_RAISE_ACTION_ERROR,
  PQL_HAND_RAISE_ACTION_SUCCESS,
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
  PQL_MODAL_CANCEL,
  PQL_MODAL_FOOTER_TEXT,
  PQL_MODAL_HEADER_TEXT,
  PQL_MODAL_ID,
  PQL_MODAL_PRIMARY,
  PQL_MODAL_TITLE,
  PQL_PHONE_DESCRIPTION,
} from '../constants';
import eventHub from '../event_hub';

export default {
  name: 'HandRaiseLeadModal',
  components: {
    GlFormTextarea,
    GlModal,
    GlFormFields,
    ListboxInput,
  },
  mixins: [Tracking.mixin(), countryStateMixin],
  props: {
    user: {
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
      ctaTracking: {},
      glmContent: '',
      productInteraction: '',
      formValues: {},
    };
  },
  computed: {
    modalHeaderText() {
      return sprintf(this.$options.i18n.modalHeaderText, {
        userName: this.user.userName,
      });
    },
    canSubmit() {
      return (
        this.formValues.firstName &&
        this.formValues.lastName &&
        this.formValues.companyName &&
        this.formValues.phoneNumber &&
        this.formValues.country &&
        (this.stateRequired ? this.formValues.state : true)
      );
    },
    actionPrimary() {
      return {
        text: this.$options.i18n.modalPrimary,
        attributes: {
          variant: 'confirm',
          disabled: !this.canSubmit,
          class: 'gl-w-full @sm:gl-w-auto',
        },
      };
    },
    actionCancel() {
      return {
        text: this.$options.i18n.modalCancel,
        attributes: {
          class: 'gl-w-full @sm:gl-w-auto',
        },
      };
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by Tracking mixin for analytics tracking
    tracking() {
      return {
        label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
        experiment: this.ctaTracking.experiment,
      };
    },
    formParams() {
      return {
        namespaceId: Number(this.user.namespaceId),
        firstName: this.formValues.firstName,
        lastName: this.formValues.lastName,
        companyName: this.formValues.companyName,
        phoneNumber: this.formValues.phoneNumber,
        country: this.formValues.country,
        state: this.stateRequired ? this.formValues.state : null,
        comment: this.formValues.comment,
        glmContent: this.glmContent,
        productInteraction: this.productInteraction,
      };
    },
    fields() {
      const result = {
        firstName: {
          label: LEADS_FIRST_NAME_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12 @md/panel:gl-col-span-6',
          },
          inputAttrs: {
            name: 'first_name',
            'data-testid': 'first-name-field',
          },
        },
        lastName: {
          label: LEADS_LAST_NAME_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12 @md/panel:gl-col-span-6',
          },
          inputAttrs: {
            name: 'last_name',
            'data-testid': 'last-name-field',
          },
        },
        companyName: {
          label: LEADS_COMPANY_NAME_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
          inputAttrs: {
            name: 'company_name',
          },
        },
        phoneNumber: {
          label: LEADS_PHONE_NUMBER_LABEL,
          groupAttrs: {
            description: PQL_PHONE_DESCRIPTION,
            class: 'gl-col-span-12',
          },
          inputAttrs: {
            name: 'phone_number',
          },
        },
      };

      if (this.showCountry) {
        result.country = {
          label: LEADS_COUNTRY_LABEL,
          groupAttrs: {
            class: 'gl-col-span-12',
          },
        };

        if (this.showState) {
          result.state = {
            label: TRIAL_STATE_LABEL,
            groupAttrs: {
              class: 'gl-col-span-12',
            },
          };
        }
      }

      result.comment = {
        label: PQL_COMMENT_LABEL,
        groupAttrs: {
          optional: true,
          class: 'gl-col-span-12',
        },
      };

      return result;
    },
  },
  mounted() {
    this.formValues = {
      firstName: this.user.firstName,
      lastName: this.user.lastName,
      companyName: this.user.companyName,
      phoneNumber: '',
      country: '',
      state: '',
      comment: '',
    };

    eventHub.$on('openModal', (options) => {
      this.openModal(options);
    });
  },
  methods: {
    openModal({ productInteraction, ctaTracking, glmContent }) {
      // The items being passed here are what can be unique about a particular
      // instance of this modal.
      this.productInteraction = productInteraction;
      this.ctaTracking = ctaTracking;
      this.glmContent = glmContent;

      this.skipCountryStateQueries = false;

      this.$root.$emit(BV_SHOW_MODAL, this.$options.modalId);
      this.track('hand_raise_form_viewed');
    },
    resetForm() {
      this.formValues.firstName = '';
      this.formValues.lastName = '';
      this.formValues.companyName = '';
      this.formValues.phoneNumber = '';
      this.formValues.country = '';
      this.formValues.state = '';
      this.formValues.comment = '';
    },
    async submit() {
      await SubscriptionsApi.sendHandRaiseLead(this.submitPath, this.formParams)
        .then(() => {
          createAlert({
            message: this.$options.i18n.handRaiseActionSuccess,
            variant: VARIANT_SUCCESS,
          });
          this.resetForm();
          this.track('hand_raise_submit_form_succeeded');
        })
        .catch((error) => {
          createAlert({
            message: this.$options.i18n.handRaiseActionError,
            captureError: true,
            error,
          });
          this.track('hand_raise_submit_form_failed');
        });
    },
  },
  i18n: {
    countryPrompt: LEADS_COUNTRY_PROMPT,
    statePrompt: TRIAL_STATE_PROMPT,
    modalTitle: PQL_MODAL_TITLE,
    modalPrimary: PQL_MODAL_PRIMARY,
    modalCancel: PQL_MODAL_CANCEL,
    modalHeaderText: PQL_MODAL_HEADER_TEXT,
    modalFooterText: PQL_MODAL_FOOTER_TEXT,
    handRaiseActionError: PQL_HAND_RAISE_ACTION_ERROR,
    handRaiseActionSuccess: PQL_HAND_RAISE_ACTION_SUCCESS,
  },
  modalId: PQL_MODAL_ID,
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="$options.modalId"
    data-testid="hand-raise-lead-modal"
    size="sm"
    :title="$options.i18n.modalTitle"
    :action-primary="actionPrimary"
    :action-cancel="actionCancel"
    @primary="submit"
    @cancel="track('hand_raise_form_canceled')"
  >
    {{ modalHeaderText }}
    <gl-form-fields
      v-model="formValues"
      :form-id="$options.modalId"
      :fields="fields"
      class="gl-mt-5 gl-grid md:gl-gap-x-4"
    >
      <template #input(country)="{ value, input }">
        <listbox-input
          :selected="value"
          name="country"
          :items="countries"
          :default-toggle-text="$options.i18n.countryPrompt"
          :block="true"
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
      <template #input(comment)>
        <gl-form-textarea v-model="formValues.comment" no-resize />
      </template>
    </gl-form-fields>
    <p class="gl-text-subtle">
      {{ $options.i18n.modalFooterText }}
    </p>
  </gl-modal>
</template>
