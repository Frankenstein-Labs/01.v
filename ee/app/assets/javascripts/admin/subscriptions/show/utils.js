import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { sprintf, s__ } from '~/locale';
import {
  subscriptionTypes,
  offlineCloudLicenseText,
  onlineCloudLicenseText,
  licenseFileText,
} from './constants';

export const formatPlan = (plan, subscription) => {
  const name = capitalizeFirstCharacter(plan);
  if (subscription.hasGitlabCreditsAddOn) {
    return sprintf(s__('SuperSonics|%{plan} with GitLab Credits'), { plan: name });
  }
  return name;
};

export const getLicenseFromData = ({ data } = {}) => data?.gitlabSubscriptionActivate?.license;
export const getErrorsAsData = ({ data } = {}) => data?.gitlabSubscriptionActivate?.errors || [];

export function getLicenseTypeLabel(type) {
  switch (type) {
    case subscriptionTypes.OFFLINE_CLOUD:
      return offlineCloudLicenseText;
    case subscriptionTypes.ONLINE_CLOUD:
      return onlineCloudLicenseText;
    default:
      return licenseFileText;
  }
}
