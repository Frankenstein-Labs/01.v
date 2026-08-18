import {
  fileLineCodequality,
  fileLineSast,
  groupSastFindingsByLine,
} from 'ee/diffs/components/inline_findings_utils';
import { sastData, codequalityData } from './mocks/inline_findings';

describe('EE Diffs Module Getters', () => {
  describe('fileLineCodequality', () => {
    it.each`
      line | severity
      ${1} | ${'minor'}
      ${2} | ${'no'}
      ${3} | ${'major'}
      ${4} | ${'no'}
    `('finds $severity degradation on line $line', ({ line, severity }) => {
      if (severity === 'no') {
        expect(fileLineCodequality('index.js', line, codequalityData)).toEqual([]);
      } else {
        expect(fileLineCodequality('index.js', line, codequalityData)[0]).toMatchObject({
          line,
          severity,
        });
      }
    });
  });

  describe('fileLineSast', () => {
    it.each`
      line | severity
      ${1} | ${'low'}
      ${2} | ${'no'}
      ${3} | ${'medium'}
      ${4} | ${'no'}
    `('finds $severity degradation on line $line', ({ line, severity }) => {
      if (severity === 'no') {
        expect(fileLineSast('index.js', line, sastData)).toEqual([]);
      } else {
        expect(fileLineSast('index.js', line, sastData)[0]).toMatchObject({
          line,
          severity,
        });
      }
    });
  });

  describe('groupSastFindingsByLine', () => {
    it("groups a file's SAST findings by their start line", () => {
      const grouped = groupSastFindingsByLine('index.js', sastData);

      expect(Object.keys(grouped)).toEqual(['1', '3']);
      expect(grouped[1][0]).toMatchObject({ line: 1, severity: 'low' });
      expect(grouped[3][0]).toMatchObject({ line: 3, severity: 'medium' });
    });

    it('returns an empty object when the file has no findings', () => {
      expect(groupSastFindingsByLine('does-not-exist.js', sastData)).toEqual({});
    });

    it('returns an empty object when there is no report', () => {
      expect(groupSastFindingsByLine('index.js', null)).toEqual({});
    });
  });

  const codeFlowDetails = [
    {
      name: 'code_flows',
      items: [],
    },
  ];

  it.each`
    line | details
    ${1} | ${codeFlowDetails}
    ${2} | ${'no'}
  `('finds details on line $line', ({ line, details }) => {
    if (details === 'no') {
      expect(fileLineSast('index.js', line, sastData)).toEqual([]);
    } else {
      expect(fileLineSast('index.js', line, sastData)[0]).toMatchObject({
        line,
        details,
      });
    }
  });
});
