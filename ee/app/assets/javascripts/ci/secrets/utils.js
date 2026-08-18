import { s__ } from '~/locale';
import { ENTITLEMENT_STATE_BLOCKED, ENTITLEMENT_STATE_INELIGIBLE } from './constants';

// Mirrors the backend write-entitlement rule (Entitlement#permits_writes?):
// any blocked reason and ineligibility deny provisioning, while active
// trial and paid states permit it.
export const isProvisioningBlockedByEntitlement = (entitlement) =>
  entitlement?.state === ENTITLEMENT_STATE_BLOCKED ||
  entitlement?.state === ENTITLEMENT_STATE_INELIGIBLE;

export const formatGraphQLError = (errorString, defaultMessage) => {
  if (typeof errorString === 'string' && errorString.length > 0) {
    return errorString.replace('GraphQL error: ', '');
  }

  return (
    defaultMessage ||
    s__('SecretsManager|An error occurred while fetching secrets manager data. Please try again.')
  );
};
