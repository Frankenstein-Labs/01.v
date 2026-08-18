import { s__ } from '~/locale';

export const LIMITED_ACCESS_MESSAGING = Object.freeze({
  MANAGED_BY_RESELLER: {
    title: s__(
      'SubscriptionManagement|Changes to subscriptions from GitLab partners require assistance',
    ),
    content: s__(
      'SubscriptionManagement|This subscription is managed through a GitLab Partner. To make changes to the subscription, contact the partner.',
    ),
  },
});

export const LIMITED_ACCESS_KEYS = Object.keys(LIMITED_ACCESS_MESSAGING);
