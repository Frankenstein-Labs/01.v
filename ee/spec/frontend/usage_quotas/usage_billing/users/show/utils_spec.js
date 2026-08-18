import { processFlowTypes } from 'ee/usage_quotas/usage_billing/users/show/utils';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { mockDataWithPool } from './mock_data';

jest.mock('~/lib/logger');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('Usage Billing Users Show Utils', () => {
  describe('processFlowTypes', () => {
    it('transforms raw flow types to value/text format', () => {
      const rawFlowTypes = [
        { id: 'software_development', title: 'Software Development Flow' },
        { id: 'code_review', title: 'Code Review Flow' },
      ];

      const result = processFlowTypes(rawFlowTypes);

      expect(result).toEqual([
        { value: 'software_development', text: expect.any(String) },
        { value: 'code_review', text: expect.any(String) },
      ]);
    });

    it('uses localized titles for known flow types', () => {
      const rawFlowTypes = [
        { id: 'software_development', title: 'ommitted' },
        { id: 'code_suggestions', title: 'ommitted' },
        { id: 'chat', title: 'ommitted' },
      ];

      const result = processFlowTypes(rawFlowTypes);

      expect(result).toEqual([
        { value: 'software_development', text: 'Software Development Flow' },
        { value: 'code_suggestions', text: 'Code Suggestions' },
        { value: 'chat', text: 'Agentic Chat' },
      ]);
    });

    it('has translations for all mocked flow types', () => {
      const mockFlowTypes =
        mockDataWithPool.data.subscriptionUsage.usersUsage.users.nodes[0].usedFlowTypes;

      processFlowTypes(mockFlowTypes);

      // Ensure no errors are logged since all flow types should have translations
      expect(logError).not.toHaveBeenCalled();
      expect(captureException).not.toHaveBeenCalled();
    });

    describe('fallback on missing translations', () => {
      it('falls back to API-served title for unknown flow types', () => {
        const rawFlowTypes = [{ id: 'unknown_flow_type', title: 'Unknown Flow Type Title' }];

        const result = processFlowTypes(rawFlowTypes);

        expect(result).toEqual([{ value: 'unknown_flow_type', text: 'Unknown Flow Type Title' }]);
      });

      it('logs error and captures exception when translation is missing', () => {
        const rawFlowTypes = [{ id: 'unknown_flow_type', title: 'Unknown Flow Type Title' }];
        const expectedError = new Error('Missing localized flow type: unknown_flow_type');

        processFlowTypes(rawFlowTypes);

        expect(logError).toHaveBeenCalledWith(expectedError);
        expect(captureException).toHaveBeenCalledWith(expectedError);
      });

      it('logs error and captures exception when translation is missing for multiple types', () => {
        const rawFlowTypes = [
          { id: 'unknown_flow_type', title: 'Unknown Flow Type Title' },
          { id: 'unknown_flow_type_2', title: 'Unknown Flow Type Title 2' },
        ];
        const expectedError = new Error(
          'Missing localized flow type: unknown_flow_type, unknown_flow_type_2',
        );

        processFlowTypes(rawFlowTypes);

        expect(logError).toHaveBeenCalledWith(expectedError);
        expect(captureException).toHaveBeenCalledWith(expectedError);
      });
    });
  });
});
