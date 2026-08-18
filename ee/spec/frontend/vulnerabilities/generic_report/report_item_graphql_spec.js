import MockAdapter from 'axios-mock-adapter';
import ReportItem, {
  GRAPHQL_TYPENAMES,
} from 'ee/vulnerabilities/components/generic_report/report_item_graphql.vue';
import { vulnerabilityDetails } from 'ee_jest/security_dashboard/components/pipeline/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';

describe('ee/vulnerabilities/components/generic_report/report_item_graphql.vue', () => {
  let wrapper;
  let mock;

  const createWrapper = ({ props } = {}) =>
    shallowMountExtended(ReportItem, {
      propsData: {
        item: {},
        ...props,
      },
      provide: {
        commitPathTemplate: 'commitPathTemplate',
      },
      stubs: {
        VulnerabilityDetailTable: true,
      },
    });

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe.each(GRAPHQL_TYPENAMES)('with report type "%s"', (reportType) => {
    const testData = Object.values(vulnerabilityDetails).find((item) => item.type === reportType);
    const reportItem = { type: reportType, ...testData };

    it('passes the report data as props', () => {
      wrapper = createWrapper({ props: { item: reportItem } });
      expect(wrapper.props('item')).toEqual(reportItem);
    });
  });
});
