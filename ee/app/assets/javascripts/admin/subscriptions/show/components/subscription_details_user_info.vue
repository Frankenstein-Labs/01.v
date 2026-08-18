<script>
import { GlCard, GlSprintf } from '@gitlab/ui';
import { n__, __ } from '~/locale';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'SubscriptionDetailsUserInfo',
  components: {
    GlCard,
    GlSprintf,
    HelpPageLink,
    PromoPageLink,
  },
  props: {
    subscription: {
      type: Object,
      required: true,
    },
  },
  computed: {
    usersInSubscription() {
      return this.subscription.usersInLicenseCount ?? __('Unlimited');
    },
    billableUsers() {
      return this.subscription.billableUsersCount;
    },
    maximumUsers() {
      return this.subscription.maximumUserCount;
    },
    usersOverSubscription() {
      return this.subscription.usersOverLicenseCount;
    },
    usersOverSubscriptionText() {
      if (this.subscription.trial) {
        return __(
          "You are using a trial license. When you use a paid subscription, you'll be charged for %{trueUpLinkStart}users over license%{trueUpLinkEnd}.",
        );
      }

      return __(
        "You'll be charged for %{trueUpLinkStart}users over license%{trueUpLinkEnd} on a quarterly or annual basis, depending on the terms of your agreement.",
      );
    },
    isUsersInSubscriptionVisible() {
      return this.subscription.plan === 'ultimate';
    },
    usersInSubscriptionTitle() {
      if (this.subscription.usersInLicenseCount) {
        return n__(
          'User in subscription',
          'Users in subscription',
          this.subscription.usersInLicenseCount,
        );
      }

      return __('Users in subscription');
    },
  },
  // eslint-disable-next-line @gitlab/no-hardcoded-urls -- External link using PromoPageLink Vue component
  trueUpPath: '/pricing/licensing-faq/#what-does-users-over-license-mean',
};
</script>

<template>
  <div class="gl-grid gl-gap-5 @sm/panel:gl-grid-cols-2">
    <gl-card>
      <template #header>
        <h2 role="presentation">
          {{ usersInSubscriptionTitle }}
        </h2>
      </template>

      <h3
        class="gl-heading-1 gl-m-0"
        role="presentation"
        data-testid="users-in-subscription-content"
      >
        {{ usersInSubscription }}
      </h3>
      <div v-if="isUsersInSubscriptionVisible" data-testid="users-in-subscription-desc">
        {{
          __(
            `Users with a Guest role or those who don't belong to a Project or Group will not use a seat from your license.`,
          )
        }}
      </div>
    </gl-card>

    <gl-card data-testid="billable-users">
      <template #header>
        <h2 role="presentation">
          {{ __('Billable users') }}
        </h2>
      </template>

      <h3 class="gl-heading-1 gl-m-0" role="presentation" data-testid="billable-users-count">
        {{ billableUsers }}
      </h3>
      <div>
        <gl-sprintf
          :message="
            __(
              'This is the number of %{billableUsersLinkStart}billable users%{billableUsersLinkEnd} on your installation, and this is the minimum number you need to purchase when you renew your license.',
            )
          "
        >
          <template #billableUsersLink="{ content }">
            <help-page-link href="subscriptions/manage_seats#billable-users">
              {{ content }}
            </help-page-link>
          </template>
        </gl-sprintf>
      </div>
    </gl-card>

    <gl-card data-testid="maximum-users">
      <template #header>
        <h2 role="presentation">
          {{ __('Maximum users') }}
        </h2>
      </template>

      <h3 class="gl-heading-1 gl-m-0" role="presentation">{{ maximumUsers }}</h3>
      <div>
        {{
          __('This is the highest peak of users on your installation since the license started.')
        }}
      </div>
    </gl-card>

    <gl-card data-testid="users-over-license">
      <template #header>
        <h2 role="presentation">
          {{ __('Users over subscription') }}
        </h2>
      </template>

      <h3 class="gl-heading-1 gl-m-0" role="presentation">{{ usersOverSubscription }}</h3>
      <div>
        <gl-sprintf :message="usersOverSubscriptionText">
          <template #trueUpLink="{ content }">
            <promo-page-link :path="$options.trueUpPath">
              {{ content }}
            </promo-page-link>
          </template>
        </gl-sprintf>
      </div>
    </gl-card>
  </div>
</template>
