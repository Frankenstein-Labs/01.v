import { nextTick } from 'vue';
import { GlColumnChart, GlLineChart, GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import { visitUrl } from '~/lib/utils/url_utility';

import InsightsChart from 'ee/insights/components/insights_chart.vue';
import InsightsChartError from 'ee/insights/components/insights_chart_error.vue';
import { CHART_TYPES, INSIGHTS_CHART_ITEM_SETTINGS, ISSUABLE_TYPES } from 'ee/insights/constants';
import {
  chartInfo,
  barChartData,
  lineChartData,
  stackedBarChartData,
  groupedChartItem,
  undefinedChartItem,
  mockFilterLabels,
  mockCollectionLabels,
  mockGroupBy,
  ungroupedChartItem,
} from 'ee_jest/insights/mock_data';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Insights chart component', () => {
  let wrapper;

  const groupPath = 'test';
  const projectPath = 'test/project';

  const DEFAULT_PROVIDE = {
    fullPath: groupPath,
    isProject: false,
  };

  const generateExpectedDrillDownUrl = ({ rootPath, namespacePath, pathSuffix, params } = {}) => {
    const drillDownUrl = `${rootPath === '/' ? '' : rootPath}/${namespacePath}/${pathSuffix}`;

    if (!params) return drillDownUrl;

    return `${drillDownUrl}?${params}`;
  };

  const createWrapper = ({ props = {}, provide = DEFAULT_PROVIDE } = {}) => {
    wrapper = shallowMount(InsightsChart, {
      propsData: {
        loaded: true,
        type: chartInfo.type,
        title: chartInfo.title,
        data: null,
        groupBy: mockGroupBy,
        error: '',
        ...props,
      },
      provide,
      stubs: { 'gl-column-chart': true, 'insights-chart-error': true },
    });
  };

  const findChart = (component) => wrapper.findComponent(component);

  describe('when chart is loading', () => {
    it('displays the chart loader in the container', () => {
      createWrapper({ props: { loaded: false } });

      expect(wrapper.findComponent(ChartSkeletonLoader).exists()).toBe(true);
    });
  });

  describe.each`
    type                       | component               | name                      | data
    ${CHART_TYPES.BAR}         | ${GlColumnChart}        | ${'GlColumnChart'}        | ${barChartData}
    ${CHART_TYPES.LINE}        | ${GlLineChart}          | ${'GlLineChart'}          | ${lineChartData}
    ${CHART_TYPES.STACKED_BAR} | ${GlStackedColumnChart} | ${'GlStackedColumnChart'} | ${stackedBarChartData}
    ${CHART_TYPES.PIE}         | ${GlColumnChart}        | ${'GlColumnChart'}        | ${barChartData}
  `('when $type chart is loaded', ({ type, component, name, data }) => {
    it(`displays the ${name} chart in container and not the loader`, () => {
      createWrapper({
        props: {
          type,
          data,
        },
      });

      expect(wrapper.findComponent(ChartSkeletonLoader).exists()).toBe(false);
      expect(findChart(component).exists()).toBe(true);
    });
  });

  describe('when chart supports drilling down', () => {
    describe.each`
      type                       | component               | data
      ${CHART_TYPES.BAR}         | ${GlColumnChart}        | ${barChartData}
      ${CHART_TYPES.LINE}        | ${GlLineChart}          | ${lineChartData}
      ${CHART_TYPES.STACKED_BAR} | ${GlStackedColumnChart} | ${stackedBarChartData}
      ${CHART_TYPES.PIE}         | ${GlColumnChart}        | ${barChartData}
    `('$type chart', ({ type, component, data }) => {
      describe('`issue` data source type', () => {
        const dataSourceType = ISSUABLE_TYPES.ISSUE;

        it('should set correct hover interaction properties', () => {
          createWrapper({
            props: { type, data, dataSourceType },
          });

          expect(findChart(component).props('option')).toEqual(
            expect.objectContaining({
              cursor: 'pointer',
              emphasis: {
                focus: 'series',
              },
            }),
          );
        });

        describe('chart item clicked', () => {
          describe("chart item's collection label is defined", () => {
            const filterLabelParams = 'label_name[]=bug&label_name[]=regression';
            const collectionLabelParam = 'label_name[]=S%3A%3A1';

            describe.each`
              filterLabels        | collectionLabels        | groupBy        | chartItemData         | expectedParams
              ${mockFilterLabels} | ${mockCollectionLabels} | ${mockGroupBy} | ${groupedChartItem}   | ${`${filterLabelParams}&${collectionLabelParam}`}
              ${mockFilterLabels} | ${mockCollectionLabels} | ${undefined}   | ${ungroupedChartItem} | ${`${filterLabelParams}&${collectionLabelParam}`}
              ${mockFilterLabels} | ${[]}                   | ${mockGroupBy} | ${groupedChartItem}   | ${filterLabelParams}
              ${mockFilterLabels} | ${[]}                   | ${undefined}   | ${ungroupedChartItem} | ${filterLabelParams}
              ${[]}               | ${mockCollectionLabels} | ${mockGroupBy} | ${groupedChartItem}   | ${collectionLabelParam}
              ${[]}               | ${mockCollectionLabels} | ${undefined}   | ${ungroupedChartItem} | ${collectionLabelParam}
              ${[]}               | ${[]}                   | ${mockGroupBy} | ${groupedChartItem}   | ${''}
              ${[]}               | ${[]}                   | ${undefined}   | ${ungroupedChartItem} | ${''}
            `(
              'filterLabels=$filterLabels, groupBy=$groupBy and collectionLabels=$collectionLabels',
              ({ filterLabels, collectionLabels, groupBy, chartItemData, expectedParams }) => {
                const { groupPathSuffix, projectPathSuffix } =
                  INSIGHTS_CHART_ITEM_SETTINGS[dataSourceType];
                const mockRelativeUrl = '/gitlab';

                it('should emit `chart-item-clicked` event', () => {
                  createWrapper({
                    props: {
                      type,
                      data,
                      dataSourceType,
                      filterLabels,
                      collectionLabels,
                      groupBy,
                    },
                  });

                  findChart(component).vm.$emit('chartItemClicked', chartItemData);

                  expect(wrapper.emitted('chart-item-clicked')).toHaveLength(1);
                });

                describe('at project level', () => {
                  it.each(['', '/', mockRelativeUrl])(
                    'should drill down to the correct URL when relative_url_root=%s',
                    (relativeUrlRoot) => {
                      gon.relative_url_root = relativeUrlRoot;

                      createWrapper({
                        props: {
                          type,
                          data,
                          dataSourceType,
                          filterLabels,
                          collectionLabels,
                          groupBy,
                        },
                        provide: { isProject: true, fullPath: projectPath },
                      });

                      findChart(component).vm.$emit('chartItemClicked', chartItemData);

                      expect(visitUrl).toHaveBeenCalledTimes(1);
                      expect(visitUrl).toHaveBeenCalledWith(
                        generateExpectedDrillDownUrl({
                          rootPath: relativeUrlRoot,
                          namespacePath: projectPath,
                          pathSuffix: projectPathSuffix,
                          params: expectedParams,
                        }),
                      );
                    },
                  );
                });

                describe('at group level', () => {
                  it.each(['', '/', mockRelativeUrl])(
                    'should drill down to the correct URL when relative_url_root=%s',
                    (relativeUrlRoot) => {
                      gon.relative_url_root = relativeUrlRoot;

                      createWrapper({
                        props: {
                          type,
                          data,
                          dataSourceType,
                          filterLabels,
                          collectionLabels,
                          groupBy,
                        },
                        provide: { fullPath: groupPath },
                      });

                      findChart(component).vm.$emit('chartItemClicked', chartItemData);

                      expect(visitUrl).toHaveBeenCalledTimes(1);
                      expect(visitUrl).toHaveBeenCalledWith(
                        generateExpectedDrillDownUrl({
                          rootPath: relativeUrlRoot,
                          namespacePath: `groups/${groupPath}`,
                          pathSuffix: groupPathSuffix,
                          params: expectedParams,
                        }),
                      );
                    },
                  );
                });
              },
            );
          });

          describe("chart item's collection label is `undefined`", () => {
            it('should not drill down on chart item', async () => {
              createWrapper({
                props: { type, data, dataSourceType },
              });

              findChart(component).vm.$emit('chartItemClicked', undefinedChartItem);

              await nextTick();

              expect(wrapper.emitted('chart-item-clicked')).toBeUndefined();
              expect(visitUrl).not.toHaveBeenCalled();
            });
          });
        });
      });

      describe('`merge_request` data source type', () => {
        const dataSourceType = ISSUABLE_TYPES.MERGE_REQUEST;

        it('should set correct hover interaction properties', () => {
          createWrapper({
            props: { type, data, dataSourceType },
          });

          expect(findChart(component).props('option')).toEqual(
            expect.objectContaining({
              cursor: 'pointer',
              emphasis: {
                focus: 'series',
              },
            }),
          );
        });

        describe('chart item clicked', () => {
          describe("chart item's collection label is defined", () => {
            const filterLabelParams = 'label_name[]=bug&label_name[]=regression';
            const collectionLabelParam = 'label_name[]=S%3A%3A1';

            describe.each`
              filterLabels        | collectionLabels        | groupBy        | chartItemData         | expectedParams
              ${mockFilterLabels} | ${mockCollectionLabels} | ${mockGroupBy} | ${groupedChartItem}   | ${`${filterLabelParams}&${collectionLabelParam}`}
              ${mockFilterLabels} | ${mockCollectionLabels} | ${undefined}   | ${ungroupedChartItem} | ${`${filterLabelParams}&${collectionLabelParam}`}
              ${mockFilterLabels} | ${[]}                   | ${mockGroupBy} | ${groupedChartItem}   | ${filterLabelParams}
              ${mockFilterLabels} | ${[]}                   | ${undefined}   | ${ungroupedChartItem} | ${filterLabelParams}
              ${[]}               | ${mockCollectionLabels} | ${mockGroupBy} | ${groupedChartItem}   | ${collectionLabelParam}
              ${[]}               | ${mockCollectionLabels} | ${undefined}   | ${ungroupedChartItem} | ${collectionLabelParam}
              ${[]}               | ${[]}                   | ${mockGroupBy} | ${groupedChartItem}   | ${''}
              ${[]}               | ${[]}                   | ${undefined}   | ${ungroupedChartItem} | ${''}
            `(
              'filterLabels=$filterLabels, groupBy=$groupBy and collectionLabels=$collectionLabels',
              ({ filterLabels, collectionLabels, groupBy, chartItemData, expectedParams }) => {
                const { groupPathSuffix, projectPathSuffix } =
                  INSIGHTS_CHART_ITEM_SETTINGS[dataSourceType];
                const mockRelativeUrl = '/gitlab';

                it('should emit `chart-item-clicked` event', () => {
                  createWrapper({
                    props: {
                      type,
                      data,
                      dataSourceType,
                      filterLabels,
                      collectionLabels,
                      groupBy,
                    },
                  });

                  findChart(component).vm.$emit('chartItemClicked', chartItemData);

                  expect(wrapper.emitted('chart-item-clicked')).toHaveLength(1);
                });

                describe('at project level', () => {
                  it.each(['', '/', mockRelativeUrl])(
                    'should drill down to the correct URL when relative_url_root=%s',
                    (relativeUrlRoot) => {
                      gon.relative_url_root = relativeUrlRoot;

                      createWrapper({
                        props: {
                          type,
                          data,
                          dataSourceType,
                          filterLabels,
                          collectionLabels,
                          groupBy,
                        },
                        provide: { isProject: true, fullPath: projectPath },
                      });

                      findChart(component).vm.$emit('chartItemClicked', chartItemData);

                      expect(visitUrl).toHaveBeenCalledTimes(1);
                      expect(visitUrl).toHaveBeenCalledWith(
                        generateExpectedDrillDownUrl({
                          rootPath: relativeUrlRoot,
                          namespacePath: projectPath,
                          pathSuffix: projectPathSuffix,
                          params: expectedParams,
                        }),
                      );
                    },
                  );
                });

                describe('at group level', () => {
                  it.each(['', '/', mockRelativeUrl])(
                    'should drill down to the correct URL when relative_url_root=%s',
                    (relativeUrlRoot) => {
                      gon.relative_url_root = relativeUrlRoot;

                      createWrapper({
                        props: {
                          type,
                          data,
                          dataSourceType,
                          filterLabels,
                          collectionLabels,
                          groupBy,
                        },
                        provide: { fullPath: groupPath },
                      });

                      findChart(component).vm.$emit('chartItemClicked', chartItemData);

                      expect(visitUrl).toHaveBeenCalledTimes(1);
                      expect(visitUrl).toHaveBeenCalledWith(
                        generateExpectedDrillDownUrl({
                          rootPath: relativeUrlRoot,
                          namespacePath: `groups/${groupPath}`,
                          pathSuffix: groupPathSuffix,
                          params: expectedParams,
                        }),
                      );
                    },
                  );
                });
              },
            );
          });

          describe("chart item's collection label is `undefined`", () => {
            it('should not drill down on chart item', async () => {
              createWrapper({
                props: { type, data, dataSourceType },
              });

              findChart(component).vm.$emit('chartItemClicked', undefinedChartItem);

              await nextTick();

              expect(wrapper.emitted('chart-item-clicked')).toBeUndefined();
              expect(visitUrl).not.toHaveBeenCalled();
            });
          });
        });
      });
    });
  });

  describe('does not support drilling down', () => {
    describe.each`
      type                       | component               | data
      ${CHART_TYPES.BAR}         | ${GlColumnChart}        | ${barChartData}
      ${CHART_TYPES.LINE}        | ${GlLineChart}          | ${lineChartData}
      ${CHART_TYPES.STACKED_BAR} | ${GlStackedColumnChart} | ${stackedBarChartData}
      ${CHART_TYPES.PIE}         | ${GlColumnChart}        | ${barChartData}
    `('$type chart', ({ type, component, data }) => {
      let chartComponent;

      beforeEach(() => {
        createWrapper({
          props: {
            type,
            data,
            dataSourceType: 'deployment_frequency',
          },
        });

        chartComponent = findChart(component);
      });

      it('should have cursor property set to `auto`', () => {
        expect(chartComponent.props('option')).toEqual(
          expect.objectContaining({
            cursor: 'auto',
          }),
        );
      });

      it('should not drill down when clicking on chart item', async () => {
        chartComponent.vm.$emit('chartItemClicked', groupedChartItem);

        await nextTick();

        expect(wrapper.emitted('chart-item-clicked')).toBeUndefined();
        expect(visitUrl).not.toHaveBeenCalled();
      });
    });
  });

  describe('when chart receives an error', () => {
    const error = 'my error';

    beforeEach(() => {
      createWrapper({
        props: {
          data: {},
          error,
        },
      });
    });

    it('displays info about the error', () => {
      expect(wrapper.findComponent(ChartSkeletonLoader).exists()).toBe(false);
      expect(wrapper.findComponent(InsightsChartError).exists()).toBe(true);
    });
  });
});
