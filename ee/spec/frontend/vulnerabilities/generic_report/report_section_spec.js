import { within } from '@testing-library/dom';
import { GlCollapse } from '@gitlab/ui';
import ReportSection from 'ee/vulnerabilities/components/generic_report/report_section.vue';
import {
  REPORT_TYPE_CODE,
  REPORT_TYPE_TABLE,
  REPORT_TYPE_URL,
} from 'ee/vulnerabilities/components/generic_report/types/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

const TEST_DATA = {
  supportedTypes: {
    url: {
      name: 'url',
      type: REPORT_TYPE_URL,
      href: 'http://foo.com',
    },
    table: {
      name: 'table',
      type: REPORT_TYPE_TABLE,
      header: [],
      rows: [],
    },
    code: {
      name: 'code',
      type: REPORT_TYPE_CODE,
      value: '<h1>Foo</h1>',
    },
  },
  unsupportedTypes: {
    unsupported: {
      name: 'four',
      type: 'not-supported',
    },
  },
};

describe('ee/vulnerabilities/components/generic_report/report_section.vue', () => {
  let wrapper;

  const createWrapper = (options) => {
    wrapper = shallowMountExtended(ReportSection, {
      propsData: {
        details: { ...TEST_DATA.supportedTypes, ...TEST_DATA.unsupportedTypes },
      },
      ...options,
    });
  };

  const withinWrapper = () => within(wrapper.element);
  const findHeader = () => wrapper.find('header');
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findHeading = () =>
    withinWrapper().getByRole('heading', {
      name: /evidence/i,
    });
  const findReportsSection = () => wrapper.findByTestId('reports');
  const findAllReportRows = () => wrapper.findAll('[data-testid*="report-row"]');
  const findReportRowByLabel = (label) => wrapper.findByTestId(`report-row-${label}`);
  const findReportItemByLabel = (label) => wrapper.findComponentByTestId(`report-item-${label}`);
  const supportedReportTypesLabels = Object.keys(TEST_DATA.supportedTypes);

  describe('with supported report types', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('reports section', () => {
      it('contains a heading', () => {
        expect(findHeading()).toBeInstanceOf(HTMLElement);
      });

      it('collapses when the header is clicked', async () => {
        expect(findCollapse().props('visible')).toBe(true);

        await findHeader().trigger('click');

        expect(findCollapse().props('visible')).toBe(false);
      });
    });

    describe('report rows', () => {
      it('shows a row for each report item', () => {
        expect(findAllReportRows()).toHaveLength(supportedReportTypesLabels.length);
      });

      it.each(supportedReportTypesLabels)(
        'renders the correct label for report row: %s',
        (label) => {
          expect(within(findReportRowByLabel(label).element).getByText(label)).toBeInstanceOf(
            HTMLElement,
          );
        },
      );
    });

    describe('report items', () => {
      it.each(supportedReportTypesLabels)(
        'passes the correct props to item for row: %s',
        (label) => {
          expect(findReportItemByLabel(label).props()).toMatchObject({
            item: TEST_DATA.supportedTypes[label],
          });
        },
      );
    });
  });

  describe('with unsupported report types', () => {
    it('only renders valid report types', () => {
      createWrapper({
        propsData: {
          details: {
            ...TEST_DATA.supportedTypes,
            ...TEST_DATA.unsupportedTypes,
          },
        },
      });

      expect(findAllReportRows()).toHaveLength(supportedReportTypesLabels.length);
    });

    it('does not render the section if the details only contain non-supported types', () => {
      createWrapper({
        propsData: {
          details: {
            ...TEST_DATA.unsupportedTypes,
          },
        },
      });

      expect(findReportsSection().exists()).toBe(false);
    });
  });
});
