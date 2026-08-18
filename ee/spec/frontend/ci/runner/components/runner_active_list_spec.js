import { GlLink, GlTable, GlSkeletonLoader } from '@gitlab/ui';
import { extendedWrapper, mountExtended } from 'helpers/vue_test_utils_helper';

import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { mostActiveRunnersData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

const mostActiveRunners = mostActiveRunnersData.data.runners.nodes;
const [{ adminUrl, ...mockRunner }, { adminUrl2, ...mockRunner2 }] = mostActiveRunners;

mockRunner.webUrl = adminUrl;
mockRunner2.webUrl = adminUrl2;

describe('RunnerActiveList', () => {
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findHeaders = () => wrapper.findAll('thead th');
  const findRows = () => wrapper.findAll('tbody tr');
  const findCell = (row = 0, fieldKey) =>
    extendedWrapper(findRows().at(row).find(`[data-testid="td-${fieldKey}"]`));

  const createComponent = ({ props = {}, ...options } = {}) => {
    wrapper = mountExtended(RunnerActiveList, {
      propsData: {
        ...props,
      },
      ...options,
    });
  };

  describe('When loading data', () => {
    it('should show a loading skeleton', () => {
      createComponent({ props: { loading: true }, mountFn: mountExtended });

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('When there are active runners', () => {
    beforeEach(() => {
      createComponent({
        props: {
          activeRunners: [mockRunner, mockRunner2],
        },
        mountFn: mountExtended,
      });
    });

    it('shows table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('shows the "Most active runners" heading', () => {
      expect(wrapper.find('h2').text()).toBe('Most active runners');
    });

    it('shows headers', () => {
      const headers = findHeaders().wrappers.map((w) => w.text());
      expect(headers).toEqual(['Runner', 'Running Jobs']);
    });

    it('shows runners', () => {
      expect(findRows()).toHaveLength(mostActiveRunners.length);

      // Row 1
      const runner = `#${getIdFromGraphQLId(mockRunner.id)} (${mockRunner.shortSha}) - ${
        mockRunner.description
      }`;
      expect(findCell(0, 'runner').text()).toBe(runner);
      expect(findCell(0, 'runningJobCount').text()).toContain('2');

      // Row 2
      const runner2 = `#${getIdFromGraphQLId(mockRunner2.id)} (${mockRunner2.shortSha}) - ${
        mockRunner2.description
      }`;
      expect(findCell(1, 'runner').text()).toBe(runner2);
      expect(findCell(1, 'runningJobCount').text()).toContain('1');
    });

    it('shows jobs link', () => {
      const url = findCell(0, 'runningJobCount').findComponent(GlLink).attributes('href');
      expect(url).toBe(mockRunner.webUrl);
    });
  });

  describe('When there are no runners', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('should render no runners', () => {
      expect(findTable().exists()).toBe(false);

      expect(wrapper.text()).toContain('no runners');
    });
  });
});
