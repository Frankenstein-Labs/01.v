import {
  getComponentNameForType,
  REPORT_COMPONENTS,
} from 'ee/vulnerabilities/components/generic_report/types/component_map';
import { REPORT_TYPES } from 'ee/vulnerabilities/components/generic_report/types/constants';

describe('Component Map', () => {
  describe('getComponentNameForType', () => {
    describe.each`
      reportType      | expectedComponentName
      ${'list'}       | ${'ReportTypeList'}
      ${'named-list'} | ${'ReportTypeNamed-list'}
      ${'url'}        | ${'ReportTypeUrl'}
      ${'diff'}       | ${'ReportTypeDiff'}
    `('when input is $input', ({ reportType, expectedComponentName }) => {
      it(`returns ${expectedComponentName}`, () => {
        expect(getComponentNameForType(reportType)).toEqual(expectedComponentName);
      });
    });
  });

  describe('REPORT_COMPONENTS', () => {
    it.each(REPORT_TYPES)('has a component defined for report type "%s"', (reportType) => {
      expect(REPORT_COMPONENTS[getComponentNameForType(reportType)]).toBeDefined();
    });
  });
});
