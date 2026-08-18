<script>
import {
  GlCard,
  GlIcon,
  GlLoadingIcon,
  GlFormCheckbox,
  GlFormGroup,
  GlSprintf,
  GlLink,
  GlButton,
  GlDisclosureDropdown,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { SCAN_PROFILE_CATEGORIES } from '~/security_configuration/constants';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import { APPROACH_ADVANCED } from './constants';

export default {
  name: 'EnableScannersSelectScanners',
  components: {
    GlCard,
    GlIcon,
    GlLoadingIcon,
    GlFormCheckbox,
    GlFormGroup,
    GlSprintf,
    GlLink,
    GlButton,
    GlDisclosureDropdown,
    ScanProfileDetailsModal,
  },
  inject: ['enableScanners'],
  SCAN_PROFILE_CATEGORIES,
  APPROACH_ADVANCED,
  data() {
    return {
      previewProfile: null,
    };
  },
  computed: {
    areAllScannersSelected() {
      const { allScanTypes } = this.enableScanners;
      return allScanTypes.length > 0 && allScanTypes.every((type) => this.isScanTypeSelected(type));
    },
    areSomeScannersSelected() {
      return (
        this.enableScanners.allScanTypes.some((type) => this.isScanTypeSelected(type)) &&
        !this.areAllScannersSelected
      );
    },
  },
  methods: {
    isScanTypeSelected(scanType) {
      return this.enableScanners.selectedScanners.some((scanner) => scanner.scanType === scanType);
    },
    scannerMetadata(scanType) {
      return SCAN_PROFILE_CATEGORIES[scanType];
    },
    profileDropdownItems(profiles) {
      return profiles.map((profile) => ({
        text: profile.name,
        value: profile,
      }));
    },
    onProfileSelected(scanType, { value }) {
      this.enableScanners.selectScannerProfile(scanType, value);
    },
    selectedProfileName(scanType) {
      return (
        this.enableScanners.activeProfileForScanType(scanType)?.name ??
        s__('SecurityConfiguration|Select a profile')
      );
    },
    openPreview(scanType) {
      const profile = this.enableScanners.activeProfileForScanType(scanType);
      if (profile) {
        this.previewProfile = profile;
      }
    },
    closePreview() {
      this.previewProfile = null;
    },
  },
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="enableScanners.isLoadingAvailableScanners" size="lg" class="gl-my-6" />
    <template v-else>
      <div
        class="gl-mb-4 gl-flex gl-items-baseline gl-justify-between gl-rounded-xl gl-bg-strong gl-px-5 gl-py-4"
      >
        <gl-form-checkbox
          :checked="areAllScannersSelected"
          :indeterminate="areSomeScannersSelected"
          @change="enableScanners.toggleAllScanners"
        >
          {{ __('Select all scanners') }}
        </gl-form-checkbox>
        <span class="gl-text-subtle">
          {{
            sprintf(__('%{selected} of %{total} selected'), {
              selected: enableScanners.allScanTypes.filter((type) => isScanTypeSelected(type))
                .length,
              total: enableScanners.allScanTypes.length,
            })
          }}
        </span>
      </div>
      <div class="gl-grid gl-grid-cols-2 gl-gap-5">
        <label
          v-for="(profiles, scanType) in enableScanners.profilesByScanType"
          :key="scanType"
          class="gl-mb-0 gl-cursor-pointer gl-font-normal"
        >
          <gl-card>
            <template #header>
              <div class="gl-flex gl-justify-between">
                <span class="gl-flex gl-items-center gl-gap-2">
                  <gl-icon name="code" />
                  <strong>{{ __('Code security') }}</strong>
                </span>
                <gl-form-checkbox
                  :checked="isScanTypeSelected(scanType)"
                  @change="(checked) => enableScanners.toggleScanner(scanType, checked)"
                />
              </div>
            </template>
            <div class="gl-p-3">
              <strong>{{ scannerMetadata(scanType).name }}</strong>
              <p>
                <gl-sprintf :message="scannerMetadata(scanType).helpDescription">
                  <template #link="{ content }">
                    <gl-link :href="scannerMetadata(scanType).helpLink" target="_blank">{{
                      content
                    }}</gl-link>
                  </template>
                </gl-sprintf>
              </p>
              <hr class="gl-mb-5 gl-mt-3" />
              <gl-form-group>
                <template #label>
                  <div class="gl-flex gl-items-center gl-justify-between">
                    <span>{{ s__('SecurityConfiguration|Configuration profile') }}</span>
                    <gl-button
                      variant="link"
                      data-testid="preview-profile-link"
                      @click="openPreview(scanType)"
                    >
                      {{ s__('SecurityConfiguration|Preview profile') }}
                    </gl-button>
                  </div>
                </template>
                <gl-disclosure-dropdown
                  :items="profileDropdownItems(profiles)"
                  :toggle-text="selectedProfileName(scanType)"
                  :disabled="!isScanTypeSelected(scanType)"
                  block
                  @action="(item) => onProfileSelected(scanType, item)"
                />
              </gl-form-group>
            </div>
          </gl-card>
        </label>
      </div>
      <scan-profile-details-modal
        :profile-id="previewProfile?.id ?? ''"
        :scan-type="previewProfile?.scanType ?? ''"
        :visible="Boolean(previewProfile)"
        :with-apply-action="false"
        @close="closePreview"
      />
    </template>
  </div>
</template>
