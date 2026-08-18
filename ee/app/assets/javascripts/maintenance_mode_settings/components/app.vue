<script>
import {
  GlForm,
  GlToggle,
  GlFormGroup,
  GlFormTextarea,
  GlFormCharacterCount,
  GlButton,
  GlLoadingIcon,
  GlModal,
} from '@gitlab/ui';
import { __, s__, n__ } from '~/locale';
import { updateApplicationSettings } from '~/rest_api';
import { createAlert } from '~/alert';

export default {
  name: 'MaintenanceModeSettingsApp',
  i18n: {
    toggleLabel: __('Enable maintenance mode'),
    toggleHelpText: __(
      'Non-admin users are restricted to read-only access, in both GitLab UI and API.',
    ),
    bannerMessagePlaceholder: __('GitLab is undergoing maintenance'),
    buttonText: __('Save changes'),
    bannerLabel: __('Banner message (optional)'),
  },
  components: {
    GlForm,
    GlToggle,
    GlFormGroup,
    GlFormTextarea,
    GlFormCharacterCount,
    GlButton,
    GlLoadingIcon,
    GlModal,
  },
  props: {
    initialBannerMessage: {
      type: String,
      required: false,
      default: '',
    },
    initialMaintenanceEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      bannerMessage: this.initialBannerMessage,
      isMaintenanceEnabled: this.initialMaintenanceEnabled,
      showDangerModal: false,
    };
  },
  computed: {
    isMessageTooLong() {
      return this.bannerMessage?.length > this.$options.messageMaxLength;
    },
  },
  methods: {
    async updateMaintenanceModeSettings() {
      try {
        this.isLoading = true;

        const {
          data: {
            maintenance_mode: maintenanceMode,
            maintenance_mode_message: maintenanceModeMessage,
          },
        } = await updateApplicationSettings({
          maintenance_mode: this.isMaintenanceEnabled,
          maintenance_mode_message: this.bannerMessage,
        });

        this.isMaintenanceEnabled = Boolean(maintenanceMode);
        this.bannerMessage = maintenanceModeMessage || '';
      } catch {
        createAlert({
          message: s__('MaintenanceMode|There was an error updating the Maintenance Mode Settings'),
        });
      } finally {
        this.isLoading = false;
      }
    },
    remainingCountText(count) {
      return n__('%d character remaining.', '%d characters remaining.', count);
    },
    overLimitText(count) {
      return n__('%d character over limit.', '%d characters over limit.', count);
    },
    handleToggleChange(value) {
      if (!value && this.bannerMessage) {
        this.showDangerModal = true;
        return;
      }

      this.isMaintenanceEnabled = value;
    },
    handleConfirmDisable() {
      this.isMaintenanceEnabled = false;
      this.bannerMessage = '';
    },
    handleModalChange(value) {
      this.showDangerModal = value;
    },
  },
  bannerInputId: 'maintenanceBannerMessage',
  countTextId: 'character-count-text',
  messageMaxLength: 255,
  modal: {
    actionPrimary: {
      text: __('Confirm'),
      attributes: {
        variant: 'confirm',
      },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <section>
    <gl-loading-icon v-if="isLoading" size="xl" />
    <gl-form v-else @submit.prevent="updateMaintenanceModeSettings">
      <gl-toggle
        :value="isMaintenanceEnabled"
        :label="$options.i18n.toggleLabel"
        class="gl-mb-6"
        @change="handleToggleChange"
      >
        <template #description>
          {{ $options.i18n.toggleHelpText }}
        </template>
      </gl-toggle>
      <gl-form-group
        v-if="isMaintenanceEnabled"
        :label="$options.i18n.bannerLabel"
        :label-for="$options.bannerInputId"
      >
        <gl-form-textarea
          :id="$options.bannerInputId"
          v-model="bannerMessage"
          :aria-describedby="$options.countTextId"
          :placeholder="$options.i18n.bannerMessagePlaceholder"
          no-resize
        />
        <template #description>
          <gl-form-character-count
            :value="bannerMessage"
            :limit="$options.messageMaxLength"
            :count-text-id="$options.countTextId"
          >
            <template #remaining-count-text="{ count }">{{ remainingCountText(count) }}</template>
            <template #over-limit-text="{ count }">{{ overLimitText(count) }}</template>
          </gl-form-character-count>
        </template>
      </gl-form-group>
      <gl-button variant="confirm" type="submit" :disabled="isMessageTooLong">{{
        $options.i18n.buttonText
      }}</gl-button>
    </gl-form>
    <gl-modal
      :visible="showDangerModal"
      :title="__('Are you sure?')"
      modal-id="maintenance-mode-disable"
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="handleConfirmDisable"
      @change="handleModalChange"
    >
      {{ s__('MaintenanceMode|By disabling maintenance mode your banner message will be lost.') }}
    </gl-modal>
  </section>
</template>
