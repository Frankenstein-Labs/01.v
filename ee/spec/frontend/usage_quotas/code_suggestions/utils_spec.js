import { DUO_HEALTH_CHECK_CATEGORIES } from 'ee/usage_quotas/code_suggestions/constants';
import { probesByCategory } from 'ee/usage_quotas/code_suggestions/utils';
import {
  MOCK_NETWORK_PROBES,
  MOCK_SYNCHRONIZATION_PROBES,
  MOCK_SYSTEM_EXCHANGE_PROBES,
  MOCK_AI_GATEWAY_PROBES,
  MOCK_CODE_SUGGESTIONS_PROBES,
  MOCK_FOUNDATIONAL_FLOWS_PROBES,
  MOCK_BILLING_PREREQUISITE_PROBES,
} from './mock_data';

describe('Code Suggestions Utils', () => {
  describe('probesByCategory', () => {
    it('properly splits up probes into categories', () => {
      const probes = [
        ...MOCK_NETWORK_PROBES.success,
        ...MOCK_SYNCHRONIZATION_PROBES.success,
        ...MOCK_SYSTEM_EXCHANGE_PROBES.success,
      ];

      const expected = probesByCategory(probes);

      expect(expected).toHaveLength(3);
      expect(expected[0]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[1],
        probes: MOCK_NETWORK_PROBES.success,
      });
      expect(expected[1]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[2],
        probes: MOCK_SYNCHRONIZATION_PROBES.success,
      });
      expect(expected[2]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[5],
        probes: MOCK_SYSTEM_EXCHANGE_PROBES.success,
      });
    });

    it('Only output the given probes category', () => {
      const probes = [...MOCK_AI_GATEWAY_PROBES.success, ...MOCK_CODE_SUGGESTIONS_PROBES.success];

      const expected = probesByCategory(probes);

      expect(expected).toHaveLength(2);

      expect(expected[0]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[0],
        probes: MOCK_AI_GATEWAY_PROBES.success,
      });
      expect(expected[1]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[3],
        probes: MOCK_CODE_SUGGESTIONS_PROBES.success,
      });
    });

    it('groups foundational-flows probes into the Foundational flows category', () => {
      const expected = probesByCategory(MOCK_FOUNDATIONAL_FLOWS_PROBES.success);
      const foundationalFlowsCategory = DUO_HEALTH_CHECK_CATEGORIES.find((category) =>
        category.values.includes('allow_flow_execution_probe'),
      );

      expect(expected).toHaveLength(1);
      expect(expected[0]).toStrictEqual({
        ...foundationalFlowsCategory,
        probes: MOCK_FOUNDATIONAL_FLOWS_PROBES.success,
      });
    });

    it('groups billing prerequisite probes into the billing prerequisites category', () => {
      const expected = probesByCategory(MOCK_BILLING_PREREQUISITE_PROBES.success);
      const billingCategory = DUO_HEALTH_CHECK_CATEGORIES.find((category) =>
        category.values.includes('billing_customers_dot_probe'),
      );

      expect(expected).toHaveLength(1);
      expect(expected[0]).toStrictEqual({
        ...billingCategory,
        probes: MOCK_BILLING_PREREQUISITE_PROBES.success,
      });
    });
  });
});
