import { get, set } from 'lodash-es';

export const buildVulnerabilitiesPayload = (payload, property = '', value = {}) => {
  return set(payload, ['vulnerability_attributes', property], value);
};

export const getVulnerabilityAttribute = (payload, property = '') => {
  return get(payload, ['vulnerability_attributes', property], undefined);
};
