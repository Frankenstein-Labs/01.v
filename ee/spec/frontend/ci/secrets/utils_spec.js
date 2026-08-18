import { formatGraphQLError, isProvisioningBlockedByEntitlement } from 'ee/ci/secrets/utils';

describe('ee/ci/secrets/utils', () => {
  describe('formatGraphQLError', () => {
    it('formats GraphQL errors', () => {
      expect(formatGraphQLError('GraphQL error: Permission denied')).toBe('Permission denied');
    });

    it('returns a fallback error when error is not a valid string', () => {
      expect(formatGraphQLError([])).toBe(
        'An error occurred while fetching secrets manager data. Please try again.',
      );
    });

    it('uses a provided backup message when error string is empty', () => {
      expect(formatGraphQLError(undefined, 'Error message')).toBe('Error message');
    });
  });

  describe('isProvisioningBlockedByEntitlement', () => {
    it.each`
      entitlement                    | isBlocked
      ${null}                        | ${false}
      ${undefined}                   | ${false}
      ${{ state: 'TRIAL_ELIGIBLE' }} | ${false}
      ${{ state: 'TRIAL' }}          | ${false}
      ${{ state: 'PAID' }}           | ${false}
      ${{ state: 'OFFLINE_PAID' }}   | ${false}
      ${{ state: 'BLOCKED' }}        | ${true}
      ${{ state: 'INELIGIBLE' }}     | ${true}
    `('returns $isBlocked when entitlement is $entitlement', ({ entitlement, isBlocked }) => {
      expect(isProvisioningBlockedByEntitlement(entitlement)).toBe(isBlocked);
    });
  });
});
