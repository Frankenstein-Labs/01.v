import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import timezoneMock from 'timezone-mock';
import UsageOverviewChart from 'ee/usage_quotas/usage_billing/components/usage_overview_chart.vue';
import { useFakeDate } from 'helpers/fake_date';
import { shallowMountExtended, getInstanceSlots } from 'helpers/vue_test_utils_helper';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { getSlotText } from './__helpers__/get_slot_text';

describe('UsageOverviewChart', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  describe('DST transitions', () => {
    describe.each(['US/Pacific', 'Europe/London', 'UTC', 'Brazil/East'])(
      '%s timezone',
      (timezone) => {
        beforeAll(() => {
          timezoneMock.register(timezone);
        });

        afterAll(() => {
          timezoneMock.unregister();
        });

        // Set a fake date, as we use today date for data manipulation
        // 20th Oct 2025
        useFakeDate(2025, 9, 20);

        const defaultProps = {
          monthStartDate: '2025-10-01',
          monthEndDate: '2025-10-31',
          commitmentDailyUsage: [
            { date: '2025-10-06', creditsUsed: 5 },
            { date: '2025-10-07', creditsUsed: 12 },
            { date: '2025-10-10', creditsUsed: 18 },
          ],
          waiverDailyUsage: [
            { date: '2025-10-12', creditsUsed: 25 },
            { date: '2025-10-14', creditsUsed: 50 },
          ],
          overageDailyUsage: [
            { date: '2025-10-15', creditsUsed: 24 },
            { date: '2025-10-16', creditsUsed: 30 },
          ],
          paidTierTrialDailyUsage: [
            { date: '2025-10-08', creditsUsed: 10 },
            { date: '2025-10-09', creditsUsed: 15 },
          ],
          usersUsageDailyUsage: [
            { date: '2025-10-11', creditsUsed: 8 },
            { date: '2025-10-13', creditsUsed: 12 },
          ],
        };

        const createComponent = (props = {}) => {
          wrapper = shallowMountExtended(UsageOverviewChart, {
            propsData: { ...defaultProps, ...props },
          });
        };

        const findGlStackedColumnChart = () => wrapper.findComponent(GlStackedColumnChart);
        const findHumanTimeframe = () => wrapper.findComponent(HumanTimeframe);

        describe('rendering elements', () => {
          beforeEach(() => {
            createComponent();
          });

          it('renders chart heading', () => {
            expect(wrapper.find('h2').text()).toBe('Daily GitLab Credits usage');
          });

          it('renders HumanTimeframe with correct props', () => {
            expect(findHumanTimeframe().exists()).toBe(true);
            expect(findHumanTimeframe().props()).toMatchObject({
              from: '2025-10-01',
              till: '2025-10-31',
            });
          });

          describe('GlStackedColumnChart props', () => {
            it('passes correct `option` prop to GlStackedColumnChart', () => {
              expect(findGlStackedColumnChart().props('option')).toMatchObject({
                xAxis: {
                  type: 'category',
                  axisTick: {
                    show: false,
                  },
                  axisLabel: {
                    formatter: expect.any(Function),
                  },
                },
                yAxis: [
                  {
                    type: 'value',
                    name: 'GitLab Credits',
                    axisLabel: {
                      formatter: expect.any(Function),
                    },
                  },
                ],
              });
            });

            it('passes x-axis label formatter that formats date of month', () => {
              const xAxisLabelFormatter =
                findGlStackedColumnChart().props('option').xAxis.axisLabel.formatter;

              expect(xAxisLabelFormatter('2025-10-01')).toBe('01');
              expect(xAxisLabelFormatter('2025-10-15')).toBe('15');
              expect(xAxisLabelFormatter('2025-10-31')).toBe('31');
            });

            it('passes y-axis label formatter that formats numbers', () => {
              const yAxisLabelFormatter =
                findGlStackedColumnChart().props('option').yAxis[0].axisLabel.formatter;

              expect(yAxisLabelFormatter(1000)).toContain('1k');
              expect(yAxisLabelFormatter(100)).toBe('100');
            });

            describe('tooltip-value slot', () => {
              let slotFn;

              beforeEach(() => {
                slotFn = getInstanceSlots(wrapper.findComponent(GlStackedColumnChart).vm)[
                  'tooltip-value'
                ];
              });

              it('formats big number', () => {
                const slotContent = slotFn({ value: [null, 1000] });

                expect(getSlotText(slotContent)).toContain('1k');
              });

              it('formats fractal number', () => {
                const slotContent = slotFn({ value: [null, 1.33333] });

                expect(getSlotText(slotContent)).toContain('1.3');
              });

              it('formats null value', () => {
                const slotContent = slotFn({ value: [null, null] });

                expect(getSlotText(slotContent)).toContain('—');
              });
            });

            it('renders tooltip-title slot with formatted date', () => {
              const slotFn = getInstanceSlots(wrapper.findComponent(GlStackedColumnChart).vm)[
                'tooltip-title'
              ];
              const slotContent = slotFn({ params: { value: '2025-10-31' } });

              expect(getSlotText(slotContent)).toContain('31 October');
            });
          });
        });

        describe('data series rendering', () => {
          describe('with all data types present', () => {
            beforeEach(() => {
              createComponent();
            });

            it('renders all five data series', () => {
              const chartData = findGlStackedColumnChart().props('bars');

              expect(chartData).toHaveLength(5);
              expect(chartData.map((bar) => bar.name)).toEqual([
                'Trial',
                'Included credits',
                'Monthly commitment',
                'Monthly waiver',
                'On-demand',
              ]);
            });

            it('passes correct trial data', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const trialData = chartData.find((series) => series.name === 'Trial');

              expect(trialData).toEqual(
                expect.objectContaining({
                  name: 'Trial',
                  stack: 'daily',
                  itemStyle: expect.objectContaining({
                    color: expect.any(String),
                  }),
                  data: expect.arrayContaining([
                    ['2025-10-08', 10],
                    ['2025-10-09', 15],
                  ]),
                }),
              );
            });

            it('passes correct included credits data', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const usersUsageData = chartData.find((series) => series.name === 'Included credits');

              expect(usersUsageData).toEqual(
                expect.objectContaining({
                  name: 'Included credits',
                  stack: 'daily',
                  itemStyle: expect.objectContaining({
                    color: expect.any(String),
                  }),
                  data: expect.arrayContaining([
                    ['2025-10-11', 8],
                    ['2025-10-13', 12],
                  ]),
                }),
              );
            });

            it('passes correct monthly commitment data', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const commitmentData = chartData.find(
                (series) => series.name === 'Monthly commitment',
              );

              expect(commitmentData).toEqual(
                expect.objectContaining({
                  name: 'Monthly commitment',
                  stack: 'daily',
                  itemStyle: expect.objectContaining({
                    color: expect.any(String),
                  }),
                  data: expect.arrayContaining([
                    ['2025-10-06', 5],
                    ['2025-10-07', 12],
                    ['2025-10-10', 18],
                  ]),
                }),
              );
            });

            it('passes correct monthly waiver data', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const waiverData = chartData.find((series) => series.name === 'Monthly waiver');

              expect(waiverData).toEqual(
                expect.objectContaining({
                  name: 'Monthly waiver',
                  stack: 'daily',
                  itemStyle: expect.objectContaining({
                    color: expect.any(String),
                  }),
                  data: expect.arrayContaining([
                    ['2025-10-12', 25],
                    ['2025-10-14', 50],
                  ]),
                }),
              );
            });

            it('passes correct on-demand usage data', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const overageData = chartData.find((series) => series.name === 'On-demand');

              expect(overageData).toEqual(
                expect.objectContaining({
                  name: 'On-demand',
                  stack: 'daily',
                  itemStyle: expect.objectContaining({
                    color: expect.any(String),
                  }),
                  data: expect.arrayContaining([
                    ['2025-10-15', 24],
                    ['2025-10-16', 30],
                  ]),
                }),
              );
            });
          });

          describe('with no data', () => {
            beforeEach(() => {
              createComponent({
                commitmentDailyUsage: [],
                waiverDailyUsage: [],
                overageDailyUsage: [],
                paidTierTrialDailyUsage: [],
                usersUsageDailyUsage: [],
              });
            });

            it('renders no data series', () => {
              const chartData = findGlStackedColumnChart().props('bars');

              expect(chartData).toHaveLength(0);
            });
          });

          describe('with zero credits used', () => {
            beforeEach(() => {
              createComponent({
                commitmentDailyUsage: [{ date: '2025-10-18', creditsUsed: 0 }],
                waiverDailyUsage: [{ date: '2025-10-18', creditsUsed: 0 }],
                overageDailyUsage: [{ date: '2025-10-18', creditsUsed: 0 }],
                paidTierTrialDailyUsage: [{ date: '2025-10-18', creditsUsed: 0 }],
                usersUsageDailyUsage: [{ date: '2025-10-18', creditsUsed: 0 }],
              });
            });

            it('does not render any data series', () => {
              const chartData = findGlStackedColumnChart().props('bars');

              expect(chartData).toHaveLength(0);
            });
          });

          describe('data array building', () => {
            beforeEach(() => {
              createComponent({
                commitmentDailyUsage: [
                  { date: '2025-10-06', creditsUsed: 5 },
                  { date: '2025-10-10', creditsUsed: 18 },
                ],
                waiverDailyUsage: [],
                overageDailyUsage: [],
                paidTierTrialDailyUsage: [],
                usersUsageDailyUsage: [],
              });
            });

            it('fills missing dates with null values', () => {
              const chartData = findGlStackedColumnChart().props('bars');
              const commitmentData = chartData[0].data;

              // Check that dates between 2025-10-06 and 2025-10-10 are filled
              const dateRange = commitmentData.slice(5, 10); // indices for Oct 6-10

              expect(dateRange).toEqual(
                expect.arrayContaining([
                  ['2025-10-06', 5],
                  ['2025-10-07', null],
                  ['2025-10-08', null],
                  ['2025-10-09', null],
                  ['2025-10-10', 18],
                ]),
              );
            });
          });
        });

        describe('month dates calculation', () => {
          beforeEach(() => {
            createComponent();
          });

          it('generates correct month dates array', () => {
            const monthDates = findGlStackedColumnChart().props('groupBy');

            expect(monthDates).toHaveLength(31);
            expect(monthDates[0]).toBe('2025-10-01');
            expect(monthDates[30]).toBe('2025-10-31');
          });

          it('passes month dates to groupBy prop', () => {
            const groupBy = findGlStackedColumnChart().props('groupBy');

            expect(groupBy).toEqual(
              expect.arrayContaining(['2025-10-01', '2025-10-15', '2025-10-31']),
            );
          });
        });

        describe('custom palette', () => {
          beforeEach(() => {
            createComponent();
          });

          it('generates custom palette from bar colors', () => {
            const customPalette = findGlStackedColumnChart().props('customPalette');
            const bars = findGlStackedColumnChart().props('bars');

            expect(customPalette).toHaveLength(bars.length);
            expect(customPalette).toEqual(bars.map((bar) => bar.itemStyle.color));
          });

          it('passes custom palette to chart', () => {
            const customPalette = findGlStackedColumnChart().props('customPalette');

            expect(customPalette).toHaveLength(5);
            customPalette.forEach((color) => {
              expect(color).toMatch(/^#[0-9a-f]{6}$/i);
            });
          });
        });

        describe('chart configuration', () => {
          beforeEach(() => {
            createComponent();
          });

          it('passes correct chart props', () => {
            const chartProps = findGlStackedColumnChart().props();

            expect(chartProps).toMatchObject({
              xAxisTitle: 'Date',
              xAxisType: 'category',
              yAxisTitle: 'GitLab Credits',
              includeLegendAvgMax: false,
            });
          });
        });
      },
    );
  });
});
