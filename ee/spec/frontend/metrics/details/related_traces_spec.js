import { GlSprintf, GlIcon, GlLink } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';

import RelatedTraces from 'ee/metrics/details/related_traces.vue';
import { viewTracesUrlWithMetric } from 'ee/metrics/details/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('ee/metrics/details/utils', () => ({
  viewTracesUrlWithMetric: jest.fn().mockReturnValue('http://mock-path'),
}));

describe('RelatedTraces', () => {
  let wrapper;

  const mountComponent = (props) => {
    wrapper = shallowMountExtended(RelatedTraces, {
      propsData: {
        tracingIndexUrl: 'trace-index',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findTracesList = () => wrapper.findByTestId('traces-list');
  const findTracesListItems = () => findTracesList().findAll('li');

  const createDataPoints = ({ traceIds, value = 0 }) => ({
    // Chart series always have unique names
    seriesName: uniqueId('app.ads.ad_request_type: NOT_TARGETED, app.ads.ad_response_type: RANDOM'),
    color: '#617ae2',
    timestamp: 1725467764487,
    value,
    traceIds,
  });

  const mockDataPoints = [
    createDataPoints({ value: 4000, traceIds: ['t3', 't4'] }),
    createDataPoints({ value: 1500, traceIds: [] }),
    createDataPoints({ value: 9000, traceIds: ['t1', 't2'] }),
  ];

  describe('when there are data points', () => {
    beforeEach(() => {
      mountComponent({ dataPoints: mockDataPoints });
    });

    it('renders the header text', () => {
      expect(wrapper.text()).toContain('Sep 04 2024 16:36:04 UTC');
    });

    it('renders the list of data points', () => {
      expect(findTracesListItems()).toHaveLength(mockDataPoints.length);
    });

    it('renders a link when a data point has related traces', () => {
      const item = findTracesListItems().at(1);

      expect(viewTracesUrlWithMetric).toHaveBeenCalledWith('trace-index', mockDataPoints[0]);

      expect(item.findComponent(GlLink).attributes('href')).toBe('http://mock-path');
    });

    it('renders a message when a data point has no related traces', () => {
      const item = findTracesListItems().at(2);

      expect(item.text()).toContain('No related traces');
    });

    describe('sorts the list items by value descending', () => {
      it.each`
        index | expectedValue | hasTraces
        ${0}  | ${9000}       | ${true}
        ${1}  | ${4000}       | ${true}
        ${2}  | ${1500}       | ${false}
      `(
        'renders the item at $index with value $expectedValue',
        ({ index, expectedValue, hasTraces }) => {
          const item = findTracesListItems().at(index);

          expect(item.text()).toContain(`${expectedValue}`);
          expect(item.text()).toContain(
            mockDataPoints.find(({ value }) => value === expectedValue).seriesName,
          );
          if (hasTraces) {
            expect(item.findComponent(GlIcon).props()).toMatchObject({
              name: 'status_created',
              size: 16,
            });
          } else {
            expect(item.findComponent(GlIcon).props()).toMatchObject({
              name: 'severity-low',
              size: 8,
            });
          }
        },
      );
    });
  });

  describe('when there are no trace IDs in the data points', () => {
    beforeEach(() => {
      mountComponent({
        dataPoints: [createDataPoints({ traceIds: [] })],
      });
    });

    it('does not render the list of data points', () => {
      expect(findTracesList().exists()).toBe(false);
    });

    it('renders the empty state', () => {
      expect(wrapper.text()).toContain(
        'No related traces for the selected time. Select another data point and try again.',
      );
    });
  });

  describe('when there are no data points', () => {
    beforeEach(() => {
      mountComponent({
        dataPoints: [],
      });
    });

    it('does not render the widget', () => {
      expect(wrapper.find('*').exists()).toBe(false);
    });
  });
});
