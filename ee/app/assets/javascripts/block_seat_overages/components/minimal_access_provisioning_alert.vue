<script>
import { GlAlert, GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { n__, sprintf } from '~/locale';

export default {
  name: 'MinimalAccessProvisioningAlert',
  components: {
    GlAlert,
    GlButton,
    GlLink,
    GlSprintf,
  },
  props: {
    dismissPath: {
      type: String,
      required: true,
    },
    affectedUsersCount: {
      type: Number,
      required: true,
    },
    purchaseSeatsLink: {
      type: String,
      required: true,
    },
    learnMoreLink: {
      type: String,
      required: true,
    },
    restrictedAccessLink: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isDismissed: false,
    };
  },
  computed: {
    title() {
      return sprintf(
        n__(
          'BlockSeatsOverages|%{count} user assigned the Minimal Access role',
          'BlockSeatsOverages|%{count} users assigned the Minimal Access role',
          this.affectedUsersCount,
        ),
        { count: this.affectedUsersCount },
      );
    },
    bodyText() {
      return n__(
        'BlockSeatsOverages|%{count} user provisioned through LDAP or SAML/SCIM has been assigned the Minimal Access role because %{linkStart}restricted access%{linkEnd} is on and no seats are available.',
        'BlockSeatsOverages|%{count} users provisioned through LDAP or SAML/SCIM have been assigned the Minimal Access role because %{linkStart}restricted access%{linkEnd} is on and no seats are available.',
        this.affectedUsersCount,
      );
    },
  },
  methods: {
    dismiss() {
      this.isDismissed = true;

      axios.post(this.dismissPath).catch((error) => {
        Sentry.captureException(error);
      });
    },
  },
};
</script>

<template>
  <gl-alert v-if="!isDismissed" variant="warning" :title="title" class="gl-mt-5" @dismiss="dismiss">
    <gl-sprintf :message="bodyText">
      <template #count>{{ affectedUsersCount }}</template>
      <template #link="{ content }">
        <gl-link
          :href="restrictedAccessLink"
          target="_blank"
          data-testid="restricted-access-link"
          >{{ content }}</gl-link
        >
      </template>
    </gl-sprintf>
    <template #actions>
      <div class="gl-flex gl-gap-3">
        <gl-button
          variant="confirm"
          :href="purchaseSeatsLink"
          target="_blank"
          data-testid="purchase-seats-button"
          >{{ __('Purchase more seats') }}</gl-button
        >
        <gl-button :href="learnMoreLink" target="_blank" data-testid="learn-more-button">{{
          __('Learn more')
        }}</gl-button>
      </div>
    </template>
  </gl-alert>
</template>
