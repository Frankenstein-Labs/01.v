import {
  normalizeVulnerabilityStates,
  enableStatusFilter,
  enableAttributeFilter,
  selectFilter,
  removePropertyFromPayload,
  getAgeTooltip,
  selectEmptyArrayWhenAllSelected,
  buildVulnerabilityAttributes,
  buildExploitSettingsAttributes,
  removeExploitSettingsFromScanner,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import { DEFAULT_EPSS_VALUE } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';

import {
  AGE,
  AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY,
  AGE_TOOLTIP_MAXIMUM_REACHED,
  DEFAULT_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  ENRICHMENT_DATA_UNAVAILABLE,
  ENRICHMENT_DATA_ACTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { GREATER_THAN_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';

describe('scan filter utils', () => {
  describe('normalizeVulnerabilityStates', () => {
    it.each`
      states                                                           | output
      ${{ [NEWLY_DETECTED]: [], [PREVIOUSLY_EXISTING]: [] }}           | ${null}
      ${{ [NEWLY_DETECTED]: ['new'], [PREVIOUSLY_EXISTING]: [] }}      | ${['new']}
      ${{ [NEWLY_DETECTED]: [], [PREVIOUSLY_EXISTING]: ['existing'] }} | ${['existing']}
    `('returns normalized states', ({ states, output }) => {
      expect(normalizeVulnerabilityStates(states)).toEqual(output);
    });

    it('returns empty array when states match defaults', () => {
      const states = {
        [NEWLY_DETECTED]: DEFAULT_VULNERABILITY_STATES.filter((s) => s.startsWith('new')),
        [PREVIOUSLY_EXISTING]: DEFAULT_VULNERABILITY_STATES.filter((s) => !s.startsWith('new')),
      };

      expect(normalizeVulnerabilityStates(states)).toEqual([]);
    });

    it('handles missing keys', () => {
      expect(normalizeVulnerabilityStates({})).toBeNull();
    });
  });

  describe('enableStatusFilter', () => {
    it('enables newly detected when none present', () => {
      const filters = {};

      expect(enableStatusFilter(filters)).toEqual({
        [NEWLY_DETECTED]: true,
      });
    });

    it('enables previously existing when newly detected already enabled', () => {
      const filters = {
        [NEWLY_DETECTED]: true,
      };

      expect(enableStatusFilter(filters)).toEqual({
        [NEWLY_DETECTED]: true,
        [PREVIOUSLY_EXISTING]: true,
      });
    });
  });

  describe('enableAttributeFilter', () => {
    it.each`
      attributes                    | output
      ${{ [FIX_AVAILABLE]: true }}  | ${{ [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: true }}
      ${{ [FALSE_POSITIVE]: true }} | ${{ [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: true }}
    `('enables attribute filters when attribute filter is selected', ({ attributes, output }) => {
      expect(enableAttributeFilter(attributes)).toEqual(output);
    });
  });

  describe('selectFilter', () => {
    it('enables status filter when filter is status', () => {
      const filters = {};
      expect(selectFilter('status', filters)).toEqual({ [NEWLY_DETECTED]: true });
    });

    it('calls onAttribute callback when filter is attribute', () => {
      const filters = { existing: true };
      const vulnerabilityAttributes = { [FIX_AVAILABLE]: true };
      const onAttribute = jest.fn();

      const result = selectFilter('attribute', filters, { onAttribute, vulnerabilityAttributes });

      expect(onAttribute).toHaveBeenCalledWith({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: true,
      });
      expect(result).toEqual(filters);
    });

    it('adds filter with empty array for other filters', () => {
      const filters = { existing: true };
      expect(selectFilter('severity', filters)).toEqual({ existing: true, severity: [] });
    });
  });

  describe('removePropertyFromPayload', () => {
    it.each`
      payload                       | key       | output
      ${{ test: true }}             | ${'test'} | ${{}}
      ${{ test: true }}             | ${'noop'} | ${{ test: true }}
      ${{ test: true, foo: 'bar' }} | ${'test'} | ${{ foo: 'bar' }}
      ${{ test: true }}             | ${''}     | ${{ test: true }}
    `('removes property from payload', ({ payload, key, output }) => {
      expect(removePropertyFromPayload(payload, key)).toEqual(output);
    });
  });

  describe('getAgeTooltip', () => {
    const filter = {
      value: AGE,
      tooltip: {
        [AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY]: 'no previous',
        [AGE_TOOLTIP_MAXIMUM_REACHED]: 'max reached',
      },
    };

    it.each`
      vulnerabilityStates                        | expected
      ${{ [PREVIOUSLY_EXISTING]: [] }}           | ${'no previous'}
      ${{ [PREVIOUSLY_EXISTING]: ['existing'] }} | ${'max reached'}
    `('returns correct tooltip for AGE filter', ({ vulnerabilityStates, expected }) => {
      expect(getAgeTooltip(filter, vulnerabilityStates)).toBe(expected);
    });

    it.each`
      filterValue  | expected
      ${'other'}   | ${''}
      ${undefined} | ${''}
    `('returns empty string for unsupported filter values', ({ filterValue, expected }) => {
      expect(getAgeTooltip({ value: filterValue }, {})).toBe(expected);
    });
  });

  describe('selectEmptyArrayWhenAllSelected', () => {
    it.each`
      values        | allCount | output
      ${['a', 'b']} | ${2}     | ${[]}
      ${['a']}      | ${2}     | ${['a']}
      ${[]}         | ${2}     | ${[]}
    `('returns correct array', ({ values, allCount, output }) => {
      expect(selectEmptyArrayWhenAllSelected(values, allCount)).toEqual(output);
    });

    it.each`
      values       | allCount | output
      ${null}      | ${2}     | ${[]}
      ${['a']}     | ${NaN}   | ${[]}
      ${'invalid'} | ${2}     | ${[]}
    `('handles invalid inputs', ({ values, allCount, output }) => {
      expect(selectEmptyArrayWhenAllSelected(values, allCount)).toEqual(output);
    });
  });

  describe('buildVulnerabilityAttributes', () => {
    it('returns merged attributes with KEV, EPSS, and incoming attributes', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true },
        kevFilterValue: true,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0.5,
      });

      expect(result).toEqual({
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
        [FIX_AVAILABLE]: true,
      });
    });

    it('handles EPSS value of 0 correctly', () => {
      const result = buildVulnerabilityAttributes({
        attributes: {},
        kevFilterValue: false,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0,
      });

      expect(result).toEqual({
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0 },
      });
    });

    it('returns null when all inputs are empty or falsy', () => {
      const result = buildVulnerabilityAttributes({
        attributes: {},
        kevFilterValue: false,
        epssOperator: null,
        epssValue: null,
      });

      expect(result).toBeNull();
    });

    it('omits KEV when kevFilterValue is falsy', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true },
        kevFilterValue: false,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0.1,
      });

      expect(result).not.toHaveProperty(KNOWN_EXPLOITED);
      expect(result).toEqual({
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.1 },
        [FIX_AVAILABLE]: true,
      });
    });

    it('omits EPSS when operator is null', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true },
        kevFilterValue: true,
        epssOperator: null,
        epssValue: 0.5,
      });

      expect(result).not.toHaveProperty(EPSS_SCORE);
      expect(result).toEqual({
        [KNOWN_EXPLOITED]: true,
        [FIX_AVAILABLE]: true,
      });
    });

    it('omits EPSS when value is null', () => {
      const result = buildVulnerabilityAttributes({
        attributes: {},
        kevFilterValue: true,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: null,
      });

      expect(result).not.toHaveProperty(EPSS_SCORE);
      expect(result).toEqual({
        [KNOWN_EXPLOITED]: true,
      });
    });

    it('includes enrichment_data_unavailable when enrichmentDataAction is provided', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true },
        kevFilterValue: true,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0.5,
        enrichmentDataAction: ENRICHMENT_DATA_ACTIONS.BLOCK,
      });

      expect(result).toEqual({
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
        [ENRICHMENT_DATA_UNAVAILABLE]: { action: ENRICHMENT_DATA_ACTIONS.BLOCK },
        [FIX_AVAILABLE]: true,
      });
    });

    it('includes enrichment_data_unavailable with ignore action', () => {
      const result = buildVulnerabilityAttributes({
        attributes: {},
        kevFilterValue: false,
        epssOperator: null,
        epssValue: null,
        enrichmentDataAction: ENRICHMENT_DATA_ACTIONS.IGNORE,
      });

      expect(result).toEqual({
        [ENRICHMENT_DATA_UNAVAILABLE]: { action: ENRICHMENT_DATA_ACTIONS.IGNORE },
      });
    });

    it('omits enrichment_data_unavailable when enrichmentDataAction is not provided', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true },
        kevFilterValue: true,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0.5,
      });

      expect(result).not.toHaveProperty(ENRICHMENT_DATA_UNAVAILABLE);
    });

    it('preserves enrichment_data_unavailable when other attributes change', () => {
      const result = buildVulnerabilityAttributes({
        attributes: { [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: false },
        kevFilterValue: true,
        epssOperator: GREATER_THAN_OPERATOR,
        epssValue: 0.5,
        enrichmentDataAction: ENRICHMENT_DATA_ACTIONS.IGNORE,
      });

      expect(result).toHaveProperty(ENRICHMENT_DATA_UNAVAILABLE, {
        action: ENRICHMENT_DATA_ACTIONS.IGNORE,
      });
      expect(result).toHaveProperty(KNOWN_EXPLOITED, true);
      expect(result).toHaveProperty(EPSS_SCORE);
      expect(result).toHaveProperty(FIX_AVAILABLE, true);
      expect(result).toHaveProperty(FALSE_POSITIVE, false);
    });
  });

  describe('removeExploitSettingsFromScanner', () => {
    it('strips KEV and EPSS from vulnerability_attributes', () => {
      const scanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.1 },
          [FIX_AVAILABLE]: true,
        },
      };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual({
        type: 'dependency_scanning',
        vulnerability_attributes: { [FIX_AVAILABLE]: true },
      });
    });

    it('drops the vulnerability_attributes key when no other attributes remain', () => {
      const scanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.1 },
        },
      };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual({
        type: 'dependency_scanning',
      });
    });

    it('returns the scanner unchanged when there are no vulnerability_attributes at all', () => {
      const scanner = { type: 'dependency_scanning', severity_levels: ['high'] };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual(scanner);
    });

    it('leaves non-exploit-settings attributes intact when KEV/EPSS are absent', () => {
      const scanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: { [FIX_AVAILABLE]: true },
      };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual(scanner);
    });

    it('treats null vulnerability_attributes as empty', () => {
      const scanner = { type: 'dependency_scanning', vulnerability_attributes: null };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual({ type: 'dependency_scanning' });
    });

    it('treats a non-object vulnerability_attributes as empty', () => {
      const scanner = { type: 'dependency_scanning', vulnerability_attributes: ['oops'] };

      expect(removeExploitSettingsFromScanner(scanner)).toEqual({ type: 'dependency_scanning' });
    });
  });

  describe('buildExploitSettingsAttributes', () => {
    it('emits KEV/EPSS defaults for a scanner without vulnerability_attributes', () => {
      expect(buildExploitSettingsAttributes({ type: 'dependency_scanning' })).toEqual({
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
      });
    });

    it('preserves existing non-exploit attributes', () => {
      const scanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: { [FIX_AVAILABLE]: true },
      };

      expect(buildExploitSettingsAttributes(scanner)).toEqual({
        [FIX_AVAILABLE]: true,
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
      });
    });

    it('preserves pre-existing KEV/EPSS rather than overwriting with defaults', () => {
      const scanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: false,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.9 },
        },
      };

      expect(buildExploitSettingsAttributes(scanner)).toEqual({
        [KNOWN_EXPLOITED]: false,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.9 },
      });
    });

    it('treats null vulnerability_attributes as empty', () => {
      const scanner = { type: 'dependency_scanning', vulnerability_attributes: null };

      expect(buildExploitSettingsAttributes(scanner)).toEqual({
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
      });
    });
  });
});
