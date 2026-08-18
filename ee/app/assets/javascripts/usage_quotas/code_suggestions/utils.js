import { parseBoolean } from '~/lib/utils/common_utils';
import { DUO_HEALTH_CHECK_CATEGORIES } from './constants';

export const probesByCategory = (probes) => {
  // Only keep the categories with a probe name included in the category values
  const relevantCategories = DUO_HEALTH_CHECK_CATEGORIES.filter((category) =>
    category.values.some((value) => probes.some((probe) => probe.name === value)),
  );

  return relevantCategories.map((category) => ({
    ...category,
    probes: probes.filter(({ name }) => category.values.includes(name)),
  }));
};

export const parseProvideData = (el) => {
  const {
    fullPath,
    groupId,
    duoProTrialHref,
    addDuoProHref,
    duoProBulkUserAssignmentAvailable,
    isFreeNamespace,
    buySubscriptionPath,
    duoAddOnIsTrial,
    duoAddOnStartDate,
    duoAddOnEndDate,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadGlmContent,
    handRaiseLeadProductInteraction,
    handRaiseLeadButtonAttributes,
    handRaiseLeadCtaTracking,
    duoPagePath,
  } = el.dataset;

  let handRaiseLeadButtonAttributesParsed;
  let handRaiseLeadCtaTrackingParsed;

  try {
    handRaiseLeadButtonAttributesParsed = JSON.parse(handRaiseLeadButtonAttributes);
  } catch {
    handRaiseLeadButtonAttributesParsed = {};
  }

  try {
    handRaiseLeadCtaTrackingParsed = JSON.parse(handRaiseLeadCtaTracking);
  } catch {
    handRaiseLeadCtaTrackingParsed = {};
  }

  return {
    fullPath,
    groupId: parseInt(groupId, 10),
    duoProTrialHref,
    duoAddOnIsTrial: parseBoolean(duoAddOnIsTrial),
    duoAddOnStartDate,
    duoAddOnEndDate,
    addDuoProHref,
    isSaaS: true,
    isFreeNamespace: parseBoolean(isFreeNamespace),
    buySubscriptionPath,
    isBulkAddOnAssignmentEnabled: parseBoolean(duoProBulkUserAssignmentAvailable),
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadData: {
      glmContent: handRaiseLeadGlmContent,
      productInteraction: handRaiseLeadProductInteraction,
      buttonAttributes: handRaiseLeadButtonAttributesParsed,
      ctaTracking: handRaiseLeadCtaTrackingParsed,
    },
    duoPagePath,
  };
};
