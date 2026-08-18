import {
  buildFiltersFromRule,
  buildFiltersFromLicenseRule,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  AGE,
  AGE_DAY,
  ALLOW_DENY,
  ATTRIBUTE,
  FALSE_POSITIVE,
  FIX_AVAILABLE,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  STATUS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { LESS_THAN_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';

describe('buildFiltersFromRule', () => {
  describe('age filter', () => {
    it('is true when vulnerability_age is provided', () => {
      const filters = buildFiltersFromRule({
        vulnerability_age: { interval: AGE_DAY, value: 1, operator: LESS_THAN_OPERATOR },
      });

      expect(filters[AGE]).toBe(true);
    });

    it('is false otherwise', () => {
      const filters = buildFiltersFromRule({});

      expect(filters[AGE]).toBe(false);
    });
  });

  describe('status filter', () => {
    describe('NEWLY_DETECTED', () => {
      it('is true when vulnerability_states are not provided', () => {
        const filters = buildFiltersFromRule({});

        expect(filters[NEWLY_DETECTED]).toBe(true);
      });

      it('is true when vulnerability_states include states belonging to newly_detected group', () => {
        const filters = buildFiltersFromRule({ vulnerability_states: ['new_needs_triage'] });

        expect(filters[NEWLY_DETECTED]).toBe(true);
      });

      it('is false when vulnerability_states only include states belonging to previously_existing group', () => {
        const filters = buildFiltersFromRule({ vulnerability_states: ['detected'] });

        expect(filters[NEWLY_DETECTED]).toBe(false);
      });
    });

    describe('PREVIOUSLY_EXISTING', () => {
      it('is false when vulnerability_states are not provided', () => {
        const filters = buildFiltersFromRule({});

        expect(filters[PREVIOUSLY_EXISTING]).toBe(false);
      });

      it('is true when vulnerability_states include states belonging to previously_existing group', () => {
        const filters = buildFiltersFromRule({ vulnerability_states: ['detected'] });

        expect(filters[PREVIOUSLY_EXISTING]).toBe(true);
      });

      it('is false when vulnerability_states only include states belonging to newly_detected group', () => {
        const filters = buildFiltersFromRule({ vulnerability_states: ['newly_detected'] });

        expect(filters[PREVIOUSLY_EXISTING]).toBe(false);
      });
    });

    describe('STATUS', () => {
      it.each`
        states                            | expectedResult
        ${[]}                             | ${false}
        ${['newly_detected']}             | ${false}
        ${['detected']}                   | ${false}
        ${['newly_detected', 'detected']} | ${true}
      `(
        'sets STATUS filter as true when states from both groups are provided',
        ({ states, expectedResult }) => {
          const filters = buildFiltersFromRule({
            vulnerability_states: states,
          });

          expect(filters[STATUS]).toBe(expectedResult);
        },
      );
    });
  });

  describe('attribute filter', () => {
    it.each`
      falsePositive | fixAvailable | expectedAttributeFilter
      ${undefined}  | ${undefined} | ${false}
      ${true}       | ${undefined} | ${false}
      ${undefined}  | ${true}      | ${false}
      ${false}      | ${false}     | ${true}
      ${false}      | ${true}      | ${true}
      ${true}       | ${false}     | ${true}
      ${true}       | ${true}      | ${true}
    `(
      'sets ATTRIBUTE filter as true when both FALSE_POSITIVE and FIX_AVAILABLE are provided',
      ({ falsePositive, fixAvailable, expectedAttributeFilter }) => {
        const filters = buildFiltersFromRule({
          vulnerability_attributes: {
            [FALSE_POSITIVE]: falsePositive,
            [FIX_AVAILABLE]: fixAvailable,
          },
        });

        expect(filters[ATTRIBUTE]).toBe(expectedAttributeFilter);
      },
    );

    it.each`
      ruleValue    | expectedResult
      ${undefined} | ${false}
      ${true}      | ${true}
      ${false}     | ${true}
    `(
      'sets FALSE_POSITIVE and FIX_AVAILABLE filters as true when provided',
      ({ ruleValue, expectedResult }) => {
        const filters = buildFiltersFromRule({
          vulnerability_attributes: { [FALSE_POSITIVE]: ruleValue, [FIX_AVAILABLE]: ruleValue },
        });

        expect(filters[FALSE_POSITIVE]).toBe(expectedResult);
        expect(filters[FIX_AVAILABLE]).toBe(expectedResult);
      },
    );

    it.each`
      rule                                       | expectedResult
      ${undefined}                               | ${false}
      ${null}                                    | ${false}
      ${{}}                                      | ${false}
      ${{ vulnerability_attributes: undefined }} | ${false}
      ${{ vulnerability_attributes: null }}      | ${false}
      ${{ vulnerability_attributes: {} }}        | ${false}
      ${{ vulnerability_age: null }}             | ${false}
      ${{ vulnerability_age: undefined }}        | ${false}
      ${{ vulnerability_age: {} }}               | ${false}
      ${{ vulnerability_states: undefined }}     | ${false}
      ${{ vulnerability_states: null }}          | ${false}
      ${{ vulnerability_states: [] }}            | ${false}
    `('sets FALSE_POSITIVE when value or rule is undefined', ({ rule, expectedResult }) => {
      const filters = buildFiltersFromRule(rule);

      expect(filters[FALSE_POSITIVE]).toBe(expectedResult);
      expect(filters[FIX_AVAILABLE]).toBe(expectedResult);
    });
  });
});

describe('buildFiltersFromLicenseRule', () => {
  it.each`
    rule                             | expectedResult
    ${undefined}                     | ${false}
    ${null}                          | ${false}
    ${{ licenses: {} }}              | ${false}
    ${{ licenses: undefined }}       | ${false}
    ${{ licenses: null }}            | ${false}
    ${{ licenses: { allowed: [] } }} | ${true}
    ${{ licenses: { denied: [] } }}  | ${true}
    ${{ licenses: { invalid: [] } }} | ${false}
  `('sets ALLOW_DENY list filter', ({ rule, expectedResult }) => {
    const filters = buildFiltersFromLicenseRule(rule);

    expect(filters[STATUS]).toBe(true);
    expect(filters[ALLOW_DENY]).toBe(expectedResult);
  });
});
