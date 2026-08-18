import { CUSTOM_STRATEGY_OPTIONS_KEYS } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  validateStrategyValues,
  doesVariablesOverrideHasValidStructure,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/utils';

describe('validateStrategyValues', () => {
  it.each`
    input                              | expected
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[0]} | ${true}
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[1]} | ${true}
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[2]} | ${true}
    ${'other string'}                  | ${false}
  `('validates correctly for $input', ({ input, expected }) => {
    expect(validateStrategyValues(input)).toBe(expected);
  });

  it.each`
    description                                  | input                                          | expected
    ${'valid structure with both keys'}          | ${{ allowed: true, exceptions: [] }}           | ${true}
    ${'valid structure with different values'}   | ${{ allowed: false, exceptions: ['test'] }}    | ${true}
    ${'valid structure without exceptions'}      | ${{ allowed: false }}                          | ${true}
    ${'invalid structure with disallowed keys'}  | ${{ allowed: true, exceptions: [], other: 1 }} | ${false}
    ${'invalid structure with wrong allowed'}    | ${{ allowed: 'true', exceptions: [] }}         | ${false}
    ${'invalid structure with wrong exceptions'} | ${{ allowed: true, exceptions: 'not-array' }}  | ${false}
    ${'empty object (default parameter)'}        | ${{}}                                          | ${false}
  `('returns $expected for $description', ({ input, expected }) => {
    expect(doesVariablesOverrideHasValidStructure(input)).toBe(expected);
  });
});
