import { GlAreaChart } from '@gitlab/ui/src/charts';
import timezoneMock from 'timezone-mock';
import UsageTrendsChart from 'ee/usage_quotas/usage_billing/components/usage_trends_chart.vue';
import { useFakeDate } from 'helpers/fake_date';
import { shallowMountExtended, getInstanceSlots } from 'helpers/vue_test_utils_helper';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { getSlotText } from './__helpers__/get_slot_text';

describe('UsageTrendsChart', () => {
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
          monthlyCommitmentIsAvailable: true,
          monthlyCommitmentTotalCredits: 50,
          monthlyCommitmentDailyUsage: [
            { date: '2025-10-06', creditsUsed: 1 },
            { date: '2025-10-07', creditsUsed: 1.5 },
            { date: '2025-10-10', creditsUsed: 2 },
          ],
          monthlyWaiverIsAvailable: true,
          monthlyWaiverTotalCredits: 100,
          monthlyWaiverDailyUsage: [
            { date: '2025-10-12', creditsUsed: 5 },
            { date: '2025-10-14', creditsUsed: 7.5 },
            { date: '2025-10-15', creditsUsed: 10 },
          ],
          overageIsAllowed: true,
          overageDailyUsage: [
            { date: '2025-10-15', creditsUsed: 12.5 },
            { date: '2025-10-16', creditsUsed: 13 },
            { date: '2025-10-18', creditsUsed: 15.5 },
          ],
        };

        const createComponent = (props = {}) => {
          wrapper = shallowMountExtended(UsageTrendsChart, {
            propsData: { ...defaultProps, ...props },
          });
        };

        const findGlAreaChart = () => wrapper.findComponent(GlAreaChart);
        const findHumanTimeframe = () => wrapper.findComponent(HumanTimeframe);

        describe('rendering elements', () => {
          beforeEach(() => {
            createComponent();
          });

          it('renders chart heading', () => {
            expect(wrapper.find('h2').text()).toBe('GitLab Credits usage');
          });

          it('renders HumanTimeframe with correct props', () => {
            expect(findHumanTimeframe().exists()).toBe(true);
            expect(findHumanTimeframe().props()).toMatchObject({
              from: '2025-10-01',
              till: '2025-10-31',
            });
          });

          describe('GlAreaChart props', () => {
            it('passes correct `option` prop to GlAreaChart', () => {
              expect(findGlAreaChart().props('option')).toMatchObject({
                xAxis: {
                  name: 'Date',
                  type: 'category',
                  axisTick: {
                    show: false,
                  },
                  axisLabel: {
                    formatter: expect.any(Function),
                  },
                },
                yAxis: {
                  name: 'Credits',
                },
              });
            });

            it('passes x-axis label formatter that parses dates', () => {
              const xAxisLabelFormatter =
                findGlAreaChart().props('option').xAxis.axisLabel.formatter;

              expect(xAxisLabelFormatter('2025-10-01')).toBe('1 Oct');
            });

            describe('tooltip-value slot', () => {
              let slotFn;

              beforeEach(() => {
                slotFn = getInstanceSlots(wrapper.findComponent(GlAreaChart).vm)['tooltip-value'];
              });

              it('formats big number', () => {
                const slotContent = slotFn({ value: 1000 });

                expect(getSlotText(slotContent)).toContain('1k');
              });

              it('formats fractal number', () => {
                const slotContent = slotFn({ value: 1.33333 });

                expect(getSlotText(slotContent)).toContain('1.3');
              });

              it('formats null value', () => {
                const slotContent = slotFn({ value: null });

                expect(getSlotText(slotContent)).toContain('—');
              });
            });

            it('renders tooltip-title slot with formatted date', () => {
              const slotFn = getInstanceSlots(wrapper.findComponent(GlAreaChart).vm)[
                'tooltip-title'
              ];
              const slotContent = slotFn({ params: { value: '2025-10-31' } });

              expect(getSlotText(slotContent)).toContain('31 October');
            });

            describe('chart options', () => {
              let chartOptions;

              beforeEach(() => {
                chartOptions = findGlAreaChart().props('option');
              });

              describe.each`
                maxCreditsUsed | expected | description
                ${100}         | ${160}   | ${'with usage below limits'}
                ${200}         | ${210}   | ${'with usage above limits'}
                ${203}         | ${210}   | ${'with usage above limits and doesnt divide by 10 cleanly'}
              `('$description', ({ maxCreditsUsed, expected }) => {
                it('calculates max value properly', () => {
                  const maxValue = chartOptions.yAxis.max({ max: maxCreditsUsed });

                  expect(maxValue).toBe(expected);
                });
              });
            });

            it('passes correct monthly commitment data', () => {
              const chartData = findGlAreaChart().props('data');
              const monthlyCommitment = chartData.find(
                (series) => series.name === 'Monthly commitment',
              );

              expect(monthlyCommitment).toEqual(
                expect.objectContaining({
                  name: 'Monthly commitment',
                  stack: 'daily',
                  markLine: expect.objectContaining({
                    data: [{ name: 'Monthly commitment limit', yAxis: 50 }],
                  }),
                  data: [
                    ['2025-10-01', null],
                    ['2025-10-02', null],
                    ['2025-10-03', null],
                    ['2025-10-04', null],
                    ['2025-10-05', 0],
                    ['2025-10-06', 1],
                    ['2025-10-07', 2.5],
                    ['2025-10-08', 2.5],
                    ['2025-10-09', 2.5],
                    ['2025-10-10', 4.5],
                    ['2025-10-11', 4.5],
                    ['2025-10-12', 4.5],
                    ['2025-10-13', 4.5],
                    ['2025-10-14', 4.5],
                    ['2025-10-15', 4.5],
                    ['2025-10-16', 4.5],
                    ['2025-10-17', 4.5],
                    ['2025-10-18', 4.5],
                    ['2025-10-19', 4.5],
                    ['2025-10-20', 4.5],
                    ['2025-10-21', null],
                    ['2025-10-22', null],
                    ['2025-10-23', null],
                    ['2025-10-24', null],
                    ['2025-10-25', null],
                    ['2025-10-26', null],
                    ['2025-10-27', null],
                    ['2025-10-28', null],
                    ['2025-10-29', null],
                    ['2025-10-30', null],
                    ['2025-10-31', null],
                  ],
                }),
              );
            });

            it('passes correct monthly waiver data', () => {
              const chartData = findGlAreaChart().props('data');
              const monthlyWaiver = chartData.find((series) => series.name === 'Monthly waiver');

              expect(monthlyWaiver).toEqual(
                expect.objectContaining({
                  name: 'Monthly waiver',
                  stack: 'daily',
                  markLine: expect.objectContaining({
                    data: [{ name: 'Monthly waiver limit', yAxis: 150 }],
                  }),
                  data: [
                    ['2025-10-01', null],
                    ['2025-10-02', null],
                    ['2025-10-03', null],
                    ['2025-10-04', null],
                    ['2025-10-05', null],
                    ['2025-10-06', null],
                    ['2025-10-07', null],
                    ['2025-10-08', null],
                    ['2025-10-09', null],
                    ['2025-10-10', null],
                    ['2025-10-11', 0],
                    ['2025-10-12', 5],
                    ['2025-10-13', 5],
                    ['2025-10-14', 12.5],
                    ['2025-10-15', 22.5],
                    ['2025-10-16', 22.5],
                    ['2025-10-17', 22.5],
                    ['2025-10-18', 22.5],
                    ['2025-10-19', 22.5],
                    ['2025-10-20', 22.5],
                    ['2025-10-21', null],
                    ['2025-10-22', null],
                    ['2025-10-23', null],
                    ['2025-10-24', null],
                    ['2025-10-25', null],
                    ['2025-10-26', null],
                    ['2025-10-27', null],
                    ['2025-10-28', null],
                    ['2025-10-29', null],
                    ['2025-10-30', null],
                    ['2025-10-31', null],
                  ],
                }),
              );
            });

            it('passes correct on-demand usage data', () => {
              const chartData = findGlAreaChart().props('data');
              const onDemand = chartData.find((series) => series.name === 'On-demand');

              expect(onDemand).toEqual(
                expect.objectContaining({
                  name: 'On-demand',
                  stack: 'daily',
                  data: [
                    ['2025-10-01', null],
                    ['2025-10-02', null],
                    ['2025-10-03', null],
                    ['2025-10-04', null],
                    ['2025-10-05', null],
                    ['2025-10-06', null],
                    ['2025-10-07', null],
                    ['2025-10-08', null],
                    ['2025-10-09', null],
                    ['2025-10-10', null],
                    ['2025-10-11', null],
                    ['2025-10-12', null],
                    ['2025-10-13', null],
                    ['2025-10-14', 0],
                    ['2025-10-15', 12.5],
                    ['2025-10-16', 25.5],
                    ['2025-10-17', 25.5],
                    ['2025-10-18', 41],
                    ['2025-10-19', 41],
                    ['2025-10-20', 41],
                    ['2025-10-21', null],
                    ['2025-10-22', null],
                    ['2025-10-23', null],
                    ['2025-10-24', null],
                    ['2025-10-25', null],
                    ['2025-10-26', null],
                    ['2025-10-27', null],
                    ['2025-10-28', null],
                    ['2025-10-29', null],
                    ['2025-10-30', null],
                    ['2025-10-31', null],
                  ],
                }),
              );
            });
          });
        });

        describe('when only monthly commitment is available', () => {
          beforeEach(() => {
            createComponent({
              ...defaultProps,
              monthlyCommitmentIsAvailable: true,
              monthlyCommitmentDailyUsage: [{ date: '2025-10-18', creditsUsed: 2 }],
              monthlyWaiverIsAvailable: false,
              monthlyWaiverDailyUsage: [],
              overageIsAllowed: false,
              overageDailyUsage: [],
            });
          });

          it('passes correct monthly commitment data', () => {
            const chartData = findGlAreaChart().props('data');

            expect(chartData).toEqual([
              expect.objectContaining({
                name: 'Monthly commitment',
                stack: 'daily',
                markLine: expect.objectContaining({
                  data: [{ name: 'Monthly commitment limit', yAxis: 50 }],
                }),
                data: expect.arrayContaining([
                  ['2025-10-16', null],
                  ['2025-10-17', 0],
                  ['2025-10-18', 2],
                  ['2025-10-19', 2],
                  ['2025-10-20', 2],
                  ['2025-10-21', null],
                ]),
              }),
            ]);
          });
        });

        describe('when only monthly commitment and overage is available', () => {
          beforeEach(() => {
            createComponent({
              ...defaultProps,
              monthlyCommitmentIsAvailable: true,
              monthlyCommitmentDailyUsage: [{ date: '2025-10-18', creditsUsed: 2 }],
              monthlyWaiverIsAvailable: false,
              monthlyWaiverDailyUsage: [],
              overageIsAllowed: true,
              overageDailyUsage: [{ date: '2025-10-19', creditsUsed: 3 }],
            });
          });

          it('passes correct monthly commitment and on-demand usage', () => {
            const chartData = findGlAreaChart().props('data');

            expect(chartData).toEqual([
              expect.objectContaining({
                name: 'Monthly commitment',
                stack: 'daily',
                markLine: expect.objectContaining({
                  data: [{ name: 'Monthly commitment limit', yAxis: 50 }],
                }),
                data: expect.arrayContaining([
                  ['2025-10-16', null],
                  ['2025-10-17', 0],
                  ['2025-10-18', 2],
                  ['2025-10-19', 2],
                  ['2025-10-20', 2],
                  ['2025-10-21', null],
                ]),
              }),
              expect.objectContaining({
                name: 'On-demand',
                stack: 'daily',
                data: expect.arrayContaining([
                  ['2025-10-17', null],
                  ['2025-10-18', 0],
                  ['2025-10-19', 3],
                  ['2025-10-20', 3],
                  ['2025-10-21', null],
                ]),
              }),
            ]);
          });
        });

        describe('with usage data coming out of order', () => {
          beforeEach(() => {
            createComponent({
              ...defaultProps,
              monthlyCommitmentIsAvailable: true,
              monthlyCommitmentDailyUsage: [
                { date: '2025-10-18', creditsUsed: 1 },
                { date: '2025-10-15', creditsUsed: 2 },
                { date: '2025-10-17', creditsUsed: 5 },
              ],
              monthlyWaiverIsAvailable: false,
              monthlyWaiverDailyUsage: [],
              overageIsAllowed: false,
              overageDailyUsage: [],
            });
          });

          it('passes dates in order and properly accumulated', () => {
            const chartData = findGlAreaChart().props('data');

            expect(chartData).toEqual([
              expect.objectContaining({
                name: 'Monthly commitment',
                stack: 'daily',
                markLine: expect.objectContaining({
                  data: [{ name: 'Monthly commitment limit', yAxis: 50 }],
                }),
                data: expect.arrayContaining([
                  ['2025-10-13', null],
                  ['2025-10-14', 0],
                  ['2025-10-15', 2],
                  ['2025-10-16', 2],
                  ['2025-10-17', 7],
                  ['2025-10-18', 8],
                  ['2025-10-19', 8],
                  ['2025-10-20', 8],
                  ['2025-10-21', null],
                ]),
              }),
            ]);
          });
        });
      },
    );
  });
});
