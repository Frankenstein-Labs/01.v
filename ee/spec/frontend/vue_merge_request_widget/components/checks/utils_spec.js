import { getSelectedModeOption } from 'ee/vue_merge_request_widget/components/checks/utils';
import { EXCEPTION_MODE, WARN_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';

describe('getSelectedModeOption', () => {
  it.each`
    hasBypassPolicies | hasBypassExceptions | expected
    ${false}          | ${false}            | ${''}
    ${true}           | ${false}            | ${WARN_MODE}
    ${false}          | ${true}             | ${EXCEPTION_MODE}
    ${true}           | ${true}             | ${''}
    ${undefined}      | ${undefined}        | ${''}
    ${false}          | ${undefined}        | ${''}
    ${undefined}      | ${false}            | ${''}
    ${true}           | ${undefined}        | ${WARN_MODE}
    ${undefined}      | ${true}             | ${EXCEPTION_MODE}
  `(
    'with hasBypassPolicies=$hasBypassPolicies and hasBypassExceptions=$hasBypassExceptions returns $expected',
    ({ hasBypassPolicies, hasBypassExceptions, expected }) => {
      const result = getSelectedModeOption({
        hasBypassPolicies,
        hasBypassExceptions,
      });

      expect(result).toBe(expected);
    },
  );
});
