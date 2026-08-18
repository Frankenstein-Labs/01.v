<script>
import { GlModal, GlBadge } from '@gitlab/ui';
import SecurityConfigurationImage from 'ee_images/promotions/profiles-promo-image_radius_2x.png';

import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { EVENT_CLICK_SCAN_PROFILE_LEARN_MORE_LINK } from '~/security_configuration/constants';

export const SCANNER_PROFILE_LAUNCH_MODAL = 'scanner_profile_launch_modal';
export const FEATURE_NAME = 'security_scanner_profiles_announcement';

export default {
  name: 'ScannerProfileLaunchModal',
  components: {
    GlModal,
    GlBadge,
    UserCalloutDismisser,
  },
  mixins: [InternalEvents.mixin()],
  data() {
    return {
      scanProfilesDocPath: helpPagePath(
        '/user/application_security/configuration/security_configuration_profiles',
      ),
    };
  },
  SecurityConfigurationImage,
  computed: {
    actionPrimaryProps() {
      return {
        text: s__('SecurityProfiles|Got it!'),
        attributes: {
          variant: 'confirm',
        },
      };
    },
    actionSecondaryProps() {
      return {
        text: s__('SecurityProfiles|Learn more'),
        attributes: {
          variant: 'default',
          href: this.scanProfilesDocPath,
          target: '_blank',
          category: 'secondary',
        },
      };
    },
  },
  methods: {
    handleSecondary(event) {
      // Prevent modal from closing when clicking Learn more
      // Open the link in a new tab
      event.preventDefault();
      visitUrl(this.scanProfilesDocPath, true);
      this.trackEvent(EVENT_CLICK_SCAN_PROFILE_LEARN_MORE_LINK);
    },
  },
  i18n: {
    badge: s__('SecurityProfiles|New feature'),
    title: s__('SecurityProfiles|Introducing Security Configuration Profiles'),
    body: s__(
      'SecurityProfiles|Configure once. Apply everywhere. Profiles make it easier to configure and manage your security tools at scale. Secret push protection is the first type of scan supported by this new feature.',
    ),
    illustrationAlt: s__('SecurityProfiles|Security configuration illustration'),
  },
  FEATURE_NAME,
};
</script>

<template>
  <user-callout-dismisser :feature-name="$options.FEATURE_NAME">
    <template #default="{ dismiss, shouldShowCallout }">
      <gl-modal
        :visible="shouldShowCallout"
        :action-primary="actionPrimaryProps"
        :action-secondary="actionSecondaryProps"
        modal-id="scanner-profile-launch-modal"
        data-testid="scanner-profile-launch-modal"
        size="md"
        hide-header
        @primary="dismiss"
        @secondary="handleSecondary"
      >
        <div>
          <img
            :src="$options.SecurityConfigurationImage"
            :alt="$options.i18n.illustrationAlt"
            class="gl-mb-5 gl-w-full"
          />
          <div class="gl-mb-3">
            <gl-badge variant="info" size="md">{{ $options.i18n.badge }}</gl-badge>
          </div>
          <h2 class="gl-font-size-h1 gl-mb-4">{{ $options.i18n.title }}</h2>
          <p class="gl-mb-0 gl-text-subtle">{{ $options.i18n.body }}</p>
        </div>
      </gl-modal>
    </template>
  </user-callout-dismisser>
</template>
