import { isEmpty } from 'lodash-es';
import {
  AGE,
  ALLOW_DENY,
  ALLOWED,
  ATTRIBUTE,
  DENIED,
  FALSE_POSITIVE,
  FIX_AVAILABLE,
  LICENSE_OVERRIDES,
  NEWLY_DETECTED,
  OVERRIDES,
  PREVIOUSLY_EXISTING,
  STATUS,
  TYPE,
} from '../rule/scan_filters/constants';
import { groupVulnerabilityStatesWithDefaults } from './vulnerability_states';

export const buildFiltersFromRule = (rule) => {
  const {
    vulnerability_age: vulnerabilityAge,
    vulnerability_states: vulnerabilityStates,
    vulnerability_attributes: attributes,
  } = rule || {};

  const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(vulnerabilityStates);
  const vulnerabilityAttributes = attributes || {};

  const filters = {
    [AGE]: !isEmpty(vulnerabilityAge),
    [NEWLY_DETECTED]:
      Boolean(vulnerabilityStateGroups[NEWLY_DETECTED]) || isEmpty(vulnerabilityStateGroups),
    [PREVIOUSLY_EXISTING]: Boolean(vulnerabilityStateGroups[PREVIOUSLY_EXISTING]),
    [FALSE_POSITIVE]: vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
    [FIX_AVAILABLE]: vulnerabilityAttributes[FIX_AVAILABLE] !== undefined,
  };
  filters[STATUS] = Boolean(filters[NEWLY_DETECTED] && filters[PREVIOUSLY_EXISTING]);
  filters[ATTRIBUTE] = Boolean(filters[FALSE_POSITIVE] && filters[FIX_AVAILABLE]);

  return filters;
};

/**
 * Build allow or deny list from a policy rule
 * @param rule
 * @returns {{[ALLOW_DENY]: boolean, [STATUS]: boolean}}
 */
export const buildFiltersFromLicenseRule = (rule) => {
  let { licenses = {} } = rule || {};
  const { license_types } = rule || {};

  licenses = licenses ?? {};

  return {
    [STATUS]: true,
    [TYPE]: Boolean(license_types),
    [ALLOW_DENY]: ALLOWED in licenses || DENIED in licenses,
    [OVERRIDES]: LICENSE_OVERRIDES in (rule || {}),
  };
};
