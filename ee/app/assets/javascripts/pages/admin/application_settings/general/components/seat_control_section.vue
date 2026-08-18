<script>
import {
  GlFormGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlFormInput,
  GlSprintf,
  GlIcon,
} from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import {
  SEAT_CONTROL,
  USER_PROVISIONING_METHOD,
} from 'ee/pages/admin/application_settings/general/constants';
import BeforeSubmitUserCapOverLicensedUsersModal from 'ee_component/pages/admin/application_settings/general/components/before_submit_user_cap_over_licensed_users_modal.vue';
import SeatControlMemberPromotionManagement from 'ee_component/pages/admin/application_settings/general/components/seat_control_member_promotion_management.vue';

export default {
  name: 'SeatControlsSection',
  components: {
    BeforeSubmitUserCapOverLicensedUsersModal,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormInput,
    GlSprintf,
    GlIcon,
    HelpPageLink,
    SeatControlMemberPromotionManagement,
  },
  mixins: [glLicensedFeaturesMixin()],
  provide() {
    return {
      beforeSubmitHookContexts: {
        [this.userCapOverLicensedUsersModalId]: {
          shouldPreventSubmit: () => this.shouldShowUserCapModal,
        },
      },
    };
  },
  inject: [
    'licensedUserCount',
    'newUserSignupsCap',
    'pendingUserCount',
    'promotionManagementAvailable',
    'seatControl',
    'ldapSyncConfigured',
    'samlScimConfigured',
    'contractOveragesAllowed',
  ],
  emits: ['check-users-auto-approval', 'submit'],
  data() {
    return {
      newUserCapValue: this.newUserSignupsCap,
      newSeatControlSettings: parseInt(this.seatControl, 10),
    };
  },
  computed: {
    hasChangedFromUserCapToOpenAccess() {
      if (!this.isOpenAccessEnabled) return false;
      return this.initialSeatControlSettings === SEAT_CONTROL.USER_CAP;
    },
    hasUserCapBeenIncreased() {
      if (!this.isUserCapEnabled) return false;
      if (this.hasUserCapChangedFromUnlimitedToLimited) return false;
      if (this.hasUserCapChangedFromLimitedToUnlimited) return true;

      const oldValueAsInteger = parseInt(this.initialUserCapValue, 10);
      const newValueAsInteger = this.parsedNewUserCapValue;

      return newValueAsInteger > oldValueAsInteger;
    },
    hasUserCapChangedFromLimitedToUnlimited() {
      return !this.isInitialUserCapUnlimited && this.isNewUserCapUnlimited;
    },
    hasUserCapChangedFromUnlimitedToLimited() {
      return this.isInitialUserCapUnlimited && !this.isNewUserCapUnlimited;
    },
    initialUserCapValue() {
      return this.newUserSignupsCap;
    },
    isBlockOveragesEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.BLOCK_OVERAGES;
    },
    isNewUserCapUnlimited() {
      // The current value of User Cap is unlimited if no value is provided in the field
      return this.newUserCapValue === '';
    },
    isInitialUserCapUnlimited() {
      // The previous/initial value of User Cap is unlimited if it was empty
      return this.initialUserCapValue === '';
    },
    isOpenAccessEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.OFF;
    },
    isUserCapEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.USER_CAP;
    },
    isUserCapOverLicensedUsers() {
      return this.parsedNewUserCapValue > this.parsedLicensedUserCount;
    },
    parsedNewUserCapValue() {
      return parseInt(this.newUserCapValue, 10);
    },
    parsedLicensedUserCount() {
      return parseInt(this.licensedUserCount, 10);
    },
    initialSeatControlSettings() {
      return parseInt(this.seatControl, 10);
    },
    userCapOverLicensedUsersModalId() {
      return 'before-submit-user-cap-over-licensed-users-modal';
    },
    shouldShowSeatControlSection() {
      return Boolean(this.glLicensedFeatures.seatControl);
    },
    shouldShowUserCapModal() {
      if (this.pendingUserCount > 0) return false;
      if (!this.licensedUserCount) return false;
      if (!this.parsedNewUserCapValue) return false;
      return this.isUserCapOverLicensedUsers;
    },
    shouldVerifyUsersAutoApproval() {
      if (this.isBlockOveragesEnabled) return false;
      if (this.hasChangedFromUserCapToOpenAccess) return true;
      return this.hasUserCapBeenIncreased;
    },
    provisioningWarning() {
      if (this.ldapSyncConfigured && this.samlScimConfigured)
        return USER_PROVISIONING_METHOD.LDAP_SAML_SCIM;
      if (this.ldapSyncConfigured) return USER_PROVISIONING_METHOD.LDAP;
      if (this.samlScimConfigured) return USER_PROVISIONING_METHOD.SAML_SCIM;
      return null;
    },
  },
  methods: {
    handleSeatControlSettingsChange(newSeatControlSettings) {
      this.newSeatControlSettings = parseInt(newSeatControlSettings, 10);
      this.newUserCapValue = this.isUserCapEnabled ? this.newUserCapValue : '';
      this.$emit('check-users-auto-approval', this.shouldVerifyUsersAutoApproval);
    },
    handleUserCapChange(newUserCapValue) {
      this.newUserCapValue = newUserCapValue;
      this.$emit('check-users-auto-approval', this.shouldVerifyUsersAutoApproval);
    },
  },
  SEAT_CONTROL,
  USER_PROVISIONING_METHOD,
};
</script>

<template>
  <div v-if="shouldShowSeatControlSection">
    <gl-form-group :label="s__('ApplicationSettings|Seat control')">
      <div
        v-if="contractOveragesAllowed === false"
        class="gl-flex gl-items-start gl-gap-3"
        data-testid="contract-overages-allowed"
      >
        <gl-icon name="lock" class="gl-mt-1 gl-flex-shrink-0 gl-text-gray-500" />
        <p class="gl-mb-0">
          <gl-sprintf
            :message="
              s__(
                'ApplicationSettings|%{restrictedAccessStart}Restricted access%{restrictedAccessEnd} is turned on for your license by default. This setting prevents overages when no seats are available. %{purchaseSeatsStart}Purchase more seats%{purchaseSeatsEnd} to add users.',
              )
            "
          >
            <template #restrictedAccess="{ content }">
              <help-page-link
                href="subscriptions/manage_seats.md#restricted-access"
                target="_blank"
                >{{ content }}</help-page-link
              >
            </template>
            <template #purchaseSeats="{ content }">
              <help-page-link href="subscriptions/manage_seats#buy-more-seats" target="_blank">{{
                content
              }}</help-page-link>
            </template>
          </gl-sprintf>
        </p>
      </div>
      <gl-form-radio-group
        v-else
        :checked="initialSeatControlSettings"
        name="application_setting[seat_control]"
        @change="handleSeatControlSettingsChange"
      >
        <gl-form-radio
          :value="$options.SEAT_CONTROL.BLOCK_OVERAGES"
          data-testid="seat-control-restricted-access"
        >
          {{ s__('ApplicationSettings|Restricted access') }}
          <template #help>
            <div>
              {{
                s__(
                  'ApplicationSettings|Prevent the billable user count from exceeding the number of seats in the license, for example, when non-billable users create their own groups and projects.',
                )
              }}
            </div>
            <div v-if="provisioningWarning" data-testid="provisioning-warning" class="gl-mt-3">
              <gl-icon name="warning" class="gl-mr-2 gl-text-warning" />

              <gl-sprintf
                v-if="provisioningWarning === $options.USER_PROVISIONING_METHOD.LDAP"
                :message="
                  s__(
                    'ApplicationSettings|%{ldapSyncConfiguredStart}LDAP sync%{ldapSyncConfiguredEnd} is active. With restricted access turned on and if no seats are available, new users provisioned through LDAP are assigned the non-billable Minimal Access role.',
                  )
                "
              >
                <template #ldapSyncConfigured="{ content }">
                  <help-page-link href="administration/auth/ldap/_index.md">{{
                    content
                  }}</help-page-link>
                </template>
              </gl-sprintf>

              <gl-sprintf
                v-if="provisioningWarning === $options.USER_PROVISIONING_METHOD.SAML_SCIM"
                :message="
                  s__(
                    'ApplicationSettings|%{samlConfiguredStart}SAML%{samlConfiguredEnd}/%{scimConfiguredStart}SCIM%{scimConfiguredEnd} is active. With restricted access turned on and if no seats are available, new users provisioned through SAML/SCIM are assigned the non-billable Minimal Access role.',
                  )
                "
              >
                <template #samlConfigured="{ content }">
                  <help-page-link href="integration/saml">{{ content }}</help-page-link>
                </template>
                <template #scimConfigured="{ content }">
                  <help-page-link href="administration/settings/scim_setup">{{
                    content
                  }}</help-page-link>
                </template>
              </gl-sprintf>

              <gl-sprintf
                v-if="provisioningWarning === $options.USER_PROVISIONING_METHOD.LDAP_SAML_SCIM"
                :message="
                  s__(
                    'ApplicationSettings|%{ldapSyncConfiguredStart}LDAP sync%{ldapSyncConfiguredEnd} and %{samlConfiguredStart}SAML%{samlConfiguredEnd}/%{scimConfiguredStart}SCIM%{scimConfiguredEnd} provisioning are active. With restricted access turned on and if no seats are available, new users provisioned through any of these methods are assigned the non-billable Minimal Access role.',
                  )
                "
              >
                <template #ldapSyncConfigured="{ content }">
                  <help-page-link href="administration/auth/ldap/_index.md">{{
                    content
                  }}</help-page-link>
                </template>
                <template #samlConfigured="{ content }">
                  <help-page-link href="integration/saml">{{ content }}</help-page-link>
                </template>
                <template #scimConfigured="{ content }">
                  <help-page-link href="administration/settings/scim_setup">{{
                    content
                  }}</help-page-link>
                </template>
              </gl-sprintf>
            </div>
          </template>
        </gl-form-radio>

        <gl-form-radio :value="$options.SEAT_CONTROL.USER_CAP" data-testid="seat-control-user-cap">
          {{ s__('ApplicationSettings|Controlled access') }}
          <template #help
            >{{
              s__(
                'ApplicationSettings|Administrator approval required for new users. Set a user cap for the maximum number of users who can be added without administrator approval.',
              )
            }}
          </template>
        </gl-form-radio>

        <div class="gl-ml-6 gl-mt-3">
          <gl-form-group
            id="user-cap-input-group"
            data-testid="user-cap-group"
            :label="__('Set user cap')"
            label-for="user-cap-input"
            label-sr-only
          >
            <gl-form-input
              id="user-cap-input"
              v-model="newUserCapValue"
              type="text"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input"
              :disabled="!isUserCapEnabled"
              @input="handleUserCapChange"
            />
            <input
              type="hidden"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input-hidden"
              :disabled="isUserCapEnabled"
              :value="newUserCapValue"
            />
            <small class="form-text gl-text-subtle">
              {{
                s__(
                  'ApplicationSettings|Users added beyond this limit require administrator approval. Leave blank for unlimited.',
                )
              }}
              <gl-sprintf
                v-if="licensedUserCount"
                :message="
                  s__(
                    'ApplicationSettings|A user cap that exceeds the current licensed user count (%{licensedUserCount}) may result in %{linkStart}seat overages%{linkEnd}.',
                  )
                "
                ><template #licensedUserCount>{{ licensedUserCount }}</template>
                <template #link="{ content }">
                  <help-page-link href="subscriptions/quarterly_reconciliation">{{
                    content
                  }}</help-page-link>
                </template>
              </gl-sprintf>
            </small>
          </gl-form-group>
        </div>

        <gl-form-radio :value="$options.SEAT_CONTROL.OFF" data-testid="seat-control-open-access">
          {{ s__('ApplicationSettings|Open access') }}
          <template #help
            >{{ s__('ApplicationSettings|Administrator approval not required for new users.') }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      v-if="promotionManagementAvailable"
      :label="s__('ApplicationSettings|Role Promotions')"
    >
      <seat-control-member-promotion-management />
    </gl-form-group>

    <before-submit-user-cap-over-licensed-users-modal
      :id="userCapOverLicensedUsersModalId"
      :licensed-user-count="parsedLicensedUserCount"
      :user-cap="parsedNewUserCapValue"
      @primary="$emit('submit')"
    />
  </div>
</template>
