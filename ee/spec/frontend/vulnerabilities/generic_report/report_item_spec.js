import ReportItem from 'ee/vulnerabilities/components/generic_report/report_item.vue';
import { REPORT_COMPONENTS } from 'ee/vulnerabilities/components/generic_report/types/component_map';
import { extendedWrapper, shallowMountExtended } from 'helpers/vue_test_utils_helper';

const REPORT_TYPE_DIFF = 'diff';
const REPORT_TYPE_FILE_LOCATION = 'file-location';
const REPORT_TYPE_LIST = 'list';
const REPORT_TYPE_MARKDOWN = 'markdown';
const REPORT_TYPE_MODULE_LOCATION = 'module-location';
const REPORT_TYPE_TEXT = 'text';
const REPORT_TYPE_URL = 'url';
const REPORT_TYPE_VALUE = 'value';

const REPORT_TYPES = [
  REPORT_TYPE_DIFF,
  REPORT_TYPE_FILE_LOCATION,
  REPORT_TYPE_LIST,
  REPORT_TYPE_MARKDOWN,
  REPORT_TYPE_MODULE_LOCATION,
  REPORT_TYPE_TEXT,
  REPORT_TYPE_URL,
  REPORT_TYPE_VALUE,
];

const TEST_DATA = {
  [REPORT_TYPE_URL]: {
    href: 'http://foo.com',
  },
  [REPORT_TYPE_LIST]: {
    items: [],
  },
  [REPORT_TYPE_DIFF]: {
    before: 'foo',
    after: 'bar',
  },
  [REPORT_TYPE_TEXT]: {
    name: 'some-string-field',
    value: 'some-value',
  },
  [REPORT_TYPE_VALUE]: {
    name: 'some-numeric-field',
    value: 15,
  },
  [REPORT_TYPE_MODULE_LOCATION]: {
    moduleName: 'foo.c',
    offset: 15,
  },
  [REPORT_TYPE_FILE_LOCATION]: {
    fileName: 'index.js',
    lineStart: '1',
    lineEnd: '2',
  },
  [REPORT_TYPE_MARKDOWN]: {
    name: 'Markdown:',
    value: 'Checkout [GitLab](http://gitlab.com)',
  },
};

describe('ee/vulnerabilities/components/generic_report/report_item.vue', () => {
  let wrapper;

  const createWrapper = ({ props } = {}) => {
    wrapper = shallowMountExtended(ReportItem, {
      propsData: {
        item: {},
        ...props,
      },
      // manual stubbing is needed because the components are dynamically imported
      stubs: Object.keys(REPORT_COMPONENTS),
    });
  };

  const findReportComponent = () => extendedWrapper(wrapper.findByTestId('reportComponent'));

  describe.each(REPORT_TYPES)('with report type "%s"', (reportType) => {
    const reportItem = { type: reportType, ...TEST_DATA[reportType] };

    beforeEach(() => {
      createWrapper({ props: { item: reportItem } });
    });

    it('renders the corresponding component', () => {
      expect(findReportComponent().exists()).toBe(true);
    });

    it('passes the report data as props', () => {
      expect(wrapper.props()).toMatchObject({
        item: reportItem,
      });
    });
  });
});
