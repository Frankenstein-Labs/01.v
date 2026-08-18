import { s__ } from '~/locale';
import { PROMO_URL } from '~/constants';

export const TRIAL_PHONE_DESCRIPTION = s__('Trial|Allowed characters: +, 0-9, -, and spaces.');
export const TRIAL_STATE_LABEL = s__('Trial|State or province');
export const TRIAL_STATE_PROMPT = s__('Trial|Select state or province');
export const TRIAL_TERMS_TEXT = s__(
  'Trial|By clicking "%{buttonText}" you accept the %{gitlabSubscriptionAgreement} and acknowledge the %{privacyStatement} and %{cookiePolicy}',
);
export const TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT = {
  text: s__('Trial|GitLab Subscription Agreement'),
  url: `${PROMO_URL}/handbook/legal/subscription-agreement`,
};
export const TRIAL_PRIVACY_STATEMENT = {
  text: s__('Trial|Privacy Statement'),
  url: `${PROMO_URL}/privacy`,
};
export const TRIAL_COOKIE_POLICY = {
  text: s__('Trial|Cookie Policy.'),
  url: `${PROMO_URL}/privacy/cookies`,
};
