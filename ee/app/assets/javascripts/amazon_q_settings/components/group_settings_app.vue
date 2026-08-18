<script>
import { updateGroupSettings } from 'ee/api/groups_api';
import showToast from '~/vue_shared/plugins/global_toast';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import AmazonQSettingsBlock from './amazon_q_settings_block.vue';

export default {
  name: 'GroupSettingsApp',
  components: {
    AmazonQSettingsBlock,
  },
  provide() {
    return {
      areDuoSettingsLocked: this.areDuoSettingsLocked,
      duoAvailabilityAdminLocked: this.duoAvailabilityAdminLocked,
      duoAvailabilityCascadingSettings: this.duoAvailabilityCascadingSettings,
    };
  },
  props: {
    groupId: {
      type: String,
      required: true,
    },
    initAutoReviewEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    initAvailability: {
      type: String,
      required: false,
      default: '',
    },
    // This is needed by duo_availability_form through provide/inject
    areDuoSettingsLocked: {
      type: Boolean,
      required: false,
      default: false,
    },
    // This is needed by duo_availability_form through provide/inject
    duoAvailabilityAdminLocked: {
      type: Boolean,
      required: false,
      default: false,
    },
    // This is needed by duo_availability_form through provide/inject
    duoAvailabilityCascadingSettings: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  i18n: {
    successMessage: __('Group was successfully updated.'),
    errorMessage: __('An error occurred while updating your settings.'),
  },
  data() {
    return {
      availability: this.initAvailability,
      autoReviewEnabled: this.initAutoReviewEnabled,
      isLoading: false,
    };
  },
  methods: {
    async onSubmit({ availability, autoReviewEnabled }) {
      try {
        this.isLoading = true;

        await updateGroupSettings(this.groupId, {
          duo_availability: availability,
          amazon_q_auto_review_enabled: autoReviewEnabled,
        });

        this.availability = availability;
        this.autoReviewEnabled = autoReviewEnabled;
        showToast(this.$options.i18n.successMessage, { variant: 'success' });
      } catch (error) {
        createAlert({
          message: this.$options.i18n.errorMessage,
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>
<template>
  <amazon-q-settings-block
    :init-availability="availability"
    :init-auto-review-enabled="autoReviewEnabled"
    :is-loading="isLoading"
    @submit="onSubmit"
  />
</template>
