import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { setLanguage } from 'jest/__helpers__/locale_helper';
import { TABLE_METRICS, TREND_STYLE_DESC } from 'ee/analytics/dashboards/constants';
import ComparisonTable from 'ee/analytics/dashboards/components/comparison_table.vue';
import { VSD_COMPARISON_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import TrendLine from '~/analytics/analytics_dashboards/components/visualizations/data_table/trend_line.vue';
import { buildMetricLink } from '~/analytics/dashboards/utils';
import { mockComparativeTableData } from '../mock_data';

describe('Comparison table', () => {
  let wrapper;

  const now = new Date();
  const mockMetric = { identifier: 'lead_time', value: 'Lead time' };
  const requestPath = 'groups/test';
  const isProject = false;
  const filterLabels = ['test::one', 'test::two'];

  const createWrapper = (props = {}) => {
    wrapper = mountExtended(ComparisonTable, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        tableData: mockComparativeTableData,
        requestPath,
        isProject,
        now,
        filterLabels,
        ...props,
      },
    });
  };

  const findMetricTableCell = (identifier) =>
    wrapper.findComponentByTestId(`${identifier}-metric-cell`);
  const findMetricComparisonSkeletons = () => wrapper.findAllByTestId('metric-comparison-skeleton');
  const findTrendLine = () => wrapper.findComponent(TrendLine);
  const findTrendLineSkeleton = () => wrapper.findByTestId('metric-chart-skeleton');
  const findTrendIndicator = () => wrapper.findByTestId('metric-trend-indicator');
  const findValueLimitInfoIcon = () => wrapper.findByTestId('metric-max-value-info-icon');

  describe('metric table cell', () => {
    describe.each(Object.keys(TABLE_METRICS))('%s metric', (identifier) => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders table cell', () => {
        expect(findMetricTableCell(identifier).exists()).toBe(true);
        expect(findMetricTableCell(identifier).props()).toMatchObject({
          identifier,
          link: buildMetricLink({ identifier, isProject, namespace: requestPath, filterLabels }),
          trackingProperty: VSD_COMPARISON_TABLE_TRACKING_PROPERTY,
        });
      });
    });
  });

  it('shows loading skeletons for each metric comparison cell', () => {
    createWrapper({ tableData: [{ metric: mockMetric }] });
    expect(findMetricComparisonSkeletons()).toHaveLength(3);
  });

  describe('date range table cell', () => {
    const valueLimit = {
      max: 10001,
      mask: '10000+',
      description: 'The maximum value has been exceeded',
    };

    const mockTimePeriods = [
      {
        change: 0.25,
        value: valueLimit.mask,
        valueLimitMessage: valueLimit.description,
      },
      {
        change: 0.6,
        value: 8000,
      },
      {
        change: 0,
        value: 6000,
      },
    ];

    describe('When value has exceeded maximum value', () => {
      const [timePeriodWithMaximum] = mockTimePeriods;

      beforeEach(() => {
        createWrapper({
          tableData: [
            {
              metric: mockMetric,
              thisMonth: timePeriodWithMaximum,
              valueLimit,
            },
          ],
        });
      });

      it('displays correct value', () => {
        const { value } = timePeriodWithMaximum;

        expect(wrapper.findByText(value).exists()).toBe(true);
      });

      it(`should render value limit info icon with tooltip`, () => {
        const tooltip = getBinding(findValueLimitInfoIcon().element, 'gl-tooltip');

        expect(findValueLimitInfoIcon().exists()).toBe(true);
        expect(tooltip).toBeDefined();
        expect(findValueLimitInfoIcon().attributes('title')).toBe(
          timePeriodWithMaximum.valueLimitMessage,
        );
      });

      it('should not render trend indicator', () => {
        expect(findTrendIndicator().exists()).toBe(false);
      });
    });

    describe.each`
      description                                               | timePeriodIndex | shouldRenderTrendIndicator | formattedValue | language
      ${'When value has changed from previous month'}           | ${1}            | ${true}                    | ${'8,000'}     | ${'en-US'}
      ${'When value has not changed or exceeded maximum value'} | ${2}            | ${false}                   | ${'6.000'}     | ${'de-DE'}
    `(
      '$description',
      ({ timePeriodIndex, shouldRenderTrendIndicator, formattedValue, language }) => {
        const findMetricDataRow = () => wrapper.find('tbody tr');

        beforeEach(() => {
          setLanguage(language);

          createWrapper({
            tableData: [
              {
                metric: mockMetric,
                thisMonth: mockTimePeriods[timePeriodIndex],
                valueLimit,
              },
            ],
          });
        });

        it('displays correct value', () => {
          expect(findMetricDataRow().html()).toContain(formattedValue);
        });

        it(`${
          shouldRenderTrendIndicator ? 'should render' : 'should not render'
        } trend indicator`, () => {
          expect(findTrendIndicator().exists()).toBe(shouldRenderTrendIndicator);
        });

        it(`should not render value limit info icon`, () => {
          expect(findValueLimitInfoIcon().exists()).toBe(false);
        });
      },
    );
  });

  describe('sparkline chart', () => {
    beforeEach(() => {
      // Needed due to a deprecation in the GlSparkline API:
      // https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2119 [CLOSED]
      // eslint-disable-next-line no-console
      console.warn = jest.fn();
    });

    it('renders the skeleton when there is no data', () => {
      createWrapper({ tableData: [{ metric: mockMetric }] });
      expect(findTrendLine().exists()).toBe(false);
      expect(findTrendLineSkeleton().exists()).toBe(true);
    });

    it('renders the line when there is data', () => {
      createWrapper({
        tableData: [
          {
            metric: mockMetric,
            chart: {
              data: [['', 1]],
            },
          },
        ],
      });
      expect(findTrendLineSkeleton().exists()).toBe(false);
      expect(findTrendLine().exists()).toBe(true);
    });

    it('applies the metric trend style', () => {
      createWrapper({
        tableData: [
          {
            metric: mockMetric,
            trendStyle: TREND_STYLE_DESC,
            chart: {
              data: [['', 1]],
            },
          },
        ],
      });
      expect(findTrendLine().props('trendStyle')).toEqual(TREND_STYLE_DESC);
    });
  });
});
