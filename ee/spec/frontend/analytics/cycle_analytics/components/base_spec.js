import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import Component from 'ee/analytics/cycle_analytics/components/base.vue';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import TypeOfWorkChartsLoader from 'ee/analytics/cycle_analytics/components/tasks_by_type/type_of_work_charts_loader.vue';
import ValueStreamSelect from 'ee/analytics/cycle_analytics/components/value_stream_select.vue';
import ValueStreamAggregationStatus from 'ee/analytics/cycle_analytics/components/value_stream_aggregation_status.vue';
import ValueStreamEmptyState from 'ee/analytics/cycle_analytics/components/value_stream_empty_state.vue';
import { OVERVIEW_STAGE_CONFIG } from 'ee/analytics/cycle_analytics/constants';
import {
  currentGroup,
  groupNamespace as namespace,
  projectNamespace,
  createdBefore,
  createdAfter,
  initialPaginationQuery,
} from 'jest/analytics/cycle_analytics/mock_data';
import ValueStreamMetrics from '~/analytics/shared/components/value_stream_metrics.vue';
import { OVERVIEW_STAGE_ID } from '~/analytics/cycle_analytics/constants';
import { toYmd } from '~/analytics/shared/utils';
import PathNavigation from '~/analytics/cycle_analytics/components/path_navigation.vue';
import StageTable from '~/analytics/cycle_analytics/components/stage_table.vue';
import ValueStreamFilters from '~/analytics/cycle_analytics/components/value_stream_filters.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  valueStreams,
  customizableStagesAndEvents,
  issueStage,
  aggregationData,
} from '../mock_data';

Vue.use(Vuex);

describe('EE Value Stream Analytics component', () => {
  let wrapper;

  const [selectedValueStream] = valueStreams;
  const noAccessSvgPath = 'path/to/no/access';
  const emptyStateSvgPath = 'path/to/empty/state';

  const setSelectedProjects = jest.fn();
  const setSelectedStage = jest.fn();
  const setDefaultSelectedStage = jest.fn();
  const setDateRange = jest.fn();
  const setPredefinedDateRange = jest.fn();
  const updateStageTablePagination = jest.fn();

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createWrapper = ({
    props = {},
    state = {},
    getters = {},
    actions = {},
    glLicensedFeatures = {},
  } = {}) => {
    const store = new Vuex.Store({
      actions: {
        setSelectedProjects,
        setSelectedStage,
        setDefaultSelectedStage,
        setDateRange,
        setPredefinedDateRange,
        updateStageTablePagination,
        ...actions,
      },
      getters: {
        hasNoAccessError: () => false,
        namespaceRestApiRequestPath: () => 'namespace/path',
        activeStages: () => customizableStagesAndEvents.stages,
        selectedProjectIds: () => [],
        cycleAnalyticsRequestParams: () => ({}),
        pathNavigationData: () => [],
        isOverviewStageSelected: ({ selectedStage }) => selectedStage?.id === OVERVIEW_STAGE_ID,
        selectedStageCount: () => 0,
        hasValueStreams: () => true,
        isProjectNamespace: () => false,
        ...getters,
      },
      state: {
        isLoading: false,
        isLoadingStage: false,
        isFetchingGroupStages: false,
        selectedProjects: [],
        selectedStageEvents: [],
        isLoadingValueStreams: false,
        selectedStageError: '',
        pagination: {},
        canEdit: false,
        predefinedDateRange: null,
        enableVsdLink: false,
        canReadCycleAnalytics: false,
        selectedValueStream,
        createdAfter,
        createdBefore,
        groupPath: currentGroup.fullPath,
        aggregation: aggregationData,
        namespace,
        selectedStage: OVERVIEW_STAGE_CONFIG,
        enableProjectsFilter: true,
        enableCustomizableStages: true,
        ...state,
      },
    });

    wrapper = shallowMount(Component, {
      store,
      provide: {
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: false,
          ...glLicensedFeatures,
        },
      },
      propsData: {
        emptyStateSvgPath,
        noDataSvgPath: 'path/to/no/data',
        noAccessSvgPath,
        enableTasksByTypeChart: true,
        ...props,
      },
      stubs: {
        UrlSync,
      },
    });
  };

  const findAggregationStatus = () => wrapper.findComponent(ValueStreamAggregationStatus);
  const findPathNavigation = () => wrapper.findComponent(PathNavigation);
  const findStageTable = () => wrapper.findComponent(StageTable);
  const findOverviewMetrics = () => wrapper.findComponent(ValueStreamMetrics);
  const findFilterBar = () => wrapper.findComponent(ValueStreamFilters);
  const findDurationChart = () => wrapper.findComponent(DurationChartLoader);
  const findTypeOfWorkCharts = () => wrapper.findComponent(TypeOfWorkChartsLoader);
  const findValueStreamSelect = () => wrapper.findComponent(ValueStreamSelect);
  const findUrlSync = () => wrapper.findComponent(UrlSync);

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({
        state: { isLoadingValueStreams: true },
      });
    });

    it('displays the loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });
  });

  describe('with no value streams', () => {
    beforeEach(() => {
      createWrapper({
        state: { selectedValueStream: null },
        getters: {
          hasValueStreams: () => false,
        },
      });
    });

    it('displays an empty state', () => {
      const emptyState = wrapper.findComponent(ValueStreamEmptyState);

      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('emptyStateSvgPath')).toBe(emptyStateSvgPath);
    });

    it.each`
      component                | componentFinder          | exists   | result
      ${'Filter bar'}          | ${findFilterBar}         | ${false} | ${'not render'}
      ${'Aggregation status'}  | ${findAggregationStatus} | ${false} | ${'not render'}
      ${'Value stream select'} | ${findValueStreamSelect} | ${false} | ${'not render'}
      ${'Stage table'}         | ${findStageTable}        | ${false} | ${'not render'}
      ${'Duration chart'}      | ${findDurationChart}     | ${false} | ${'not render'}
      ${'Overview metrics'}    | ${findOverviewMetrics}   | ${false} | ${'not render'}
      ${'Type of work chart'}  | ${findTypeOfWorkCharts}  | ${false} | ${'not render'}
    `(`will $result the $component`, ({ componentFinder, exists }) => {
      expect(componentFinder().exists()).toBe(exists);
    });

    it('does not track any events', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).not.toHaveBeenCalled();
    });
  });

  describe('the user does not have access to the group', () => {
    beforeEach(() => {
      createWrapper({
        getters: { hasNoAccessError: () => true },
      });
    });

    it('renders the no access information', () => {
      const emptyState = wrapper.findComponent(GlEmptyState);

      expect(emptyState.exists()).toBe(true);
      expect(emptyState.props('svgPath')).toBe(noAccessSvgPath);
    });

    it.each`
      component                | componentFinder          | exists   | result
      ${'Filter bar'}          | ${findFilterBar}         | ${true}  | ${'render'}
      ${'Aggregation status'}  | ${findAggregationStatus} | ${true}  | ${'render'}
      ${'Value stream select'} | ${findValueStreamSelect} | ${true}  | ${'render'}
      ${'Stage table'}         | ${findStageTable}        | ${false} | ${'not render'}
      ${'Duration chart'}      | ${findDurationChart}     | ${false} | ${'not render'}
      ${'Overview metrics'}    | ${findOverviewMetrics}   | ${false} | ${'not render'}
      ${'Type of work chart'}  | ${findTypeOfWorkCharts}  | ${false} | ${'not render'}
    `(`will $result the $component`, ({ componentFinder, exists }) => {
      expect(componentFinder().exists()).toBe(exists);
    });
  });

  describe('the user has access to the group', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('hides the empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(false);
    });

    it.each`
      component                | componentFinder          | exists   | result
      ${'Path navigation'}     | ${findPathNavigation}    | ${true}  | ${'render'}
      ${'Filter bar'}          | ${findFilterBar}         | ${true}  | ${'render'}
      ${'Aggregation status'}  | ${findAggregationStatus} | ${true}  | ${'render'}
      ${'Value stream select'} | ${findValueStreamSelect} | ${true}  | ${'render'}
      ${'Overview metrics'}    | ${findOverviewMetrics}   | ${true}  | ${'render'}
      ${'Type of work chart'}  | ${findTypeOfWorkCharts}  | ${true}  | ${'render'}
      ${'Duration chart'}      | ${findDurationChart}     | ${true}  | ${'render'}
      ${'Stage table'}         | ${findStageTable}        | ${false} | ${'not render'}
    `(`will $result the $component`, ({ componentFinder, exists }) => {
      expect(componentFinder().exists()).toBe(exists);
    });

    it('displays the project filter', () => {
      expect(findFilterBar().props('hasProjectFilter')).toBe(true);
    });

    it('sets the correct aggregation status', () => {
      expect(findAggregationStatus().props('data')).toEqual(aggregationData);
    });

    it('does not render a link to the value streams dashboard', () => {
      expect(findOverviewMetrics().props('dashboardsPath')).toBeNull();
    });

    it('tracks `view_value_stream_analytics` event`', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'view_value_stream_analytics',
        {
          label: selectedValueStream.name,
          value: selectedValueStream.id,
        },
        undefined,
      );
    });

    describe('without the overview stage selected', () => {
      beforeEach(() => {
        createWrapper({
          state: {
            selectedStage: issueStage,
            selectedStageEvents: [{}],
          },
        });
      });

      describe.each`
        component                | componentFinder          | exists   | visible
        ${'Filter bar'}          | ${findFilterBar}         | ${true}  | ${true}
        ${'Aggregation status'}  | ${findAggregationStatus} | ${true}  | ${true}
        ${'Value stream select'} | ${findValueStreamSelect} | ${true}  | ${true}
        ${'Stage table'}         | ${findStageTable}        | ${true}  | ${true}
        ${'Duration chart'}      | ${findDurationChart}     | ${true}  | ${true}
        ${'Overview metrics'}    | ${findOverviewMetrics}   | ${false} | ${false}
        ${'Type of work chart'}  | ${findTypeOfWorkCharts}  | ${true}  | ${false}
      `(`for $component`, ({ componentFinder, exists, visible }) => {
        it(`${exists ? 'will' : 'will not'} render`, () => {
          expect(componentFinder().exists()).toBe(exists);
        });

        it(`${visible ? 'will' : 'will not'} be visible`, () => {
          expect(componentFinder().exists()).toBe(exists);
        });
      });

      it('sets the `includeProjectName` prop on stage table', () => {
        expect(findStageTable().props('includeProjectName')).toBe(true);
      });

      describe('without issue events', () => {
        beforeEach(() => {
          createWrapper({
            state: {
              selectedStage: issueStage,
              selectedStageEvents: [],
            },
          });
        });

        describe.each`
          component                | componentFinder          | exists   | visible
          ${'Filter bar'}          | ${findFilterBar}         | ${true}  | ${true}
          ${'Aggregation status'}  | ${findAggregationStatus} | ${true}  | ${true}
          ${'Value stream select'} | ${findValueStreamSelect} | ${true}  | ${true}
          ${'Stage table'}         | ${findStageTable}        | ${false} | ${false}
          ${'Duration chart'}      | ${findDurationChart}     | ${true}  | ${true}
          ${'Overview metrics'}    | ${findOverviewMetrics}   | ${false} | ${false}
          ${'Type of work chart'}  | ${findTypeOfWorkCharts}  | ${true}  | ${false}
        `(`for $component`, ({ componentFinder, exists, visible }) => {
          it(`${exists ? 'will' : 'will not'} render`, () => {
            expect(componentFinder().exists()).toBe(exists);
          });

          it(`${visible ? 'will' : 'will not'} be visible`, () => {
            expect(componentFinder().exists()).toBe(exists);
          });
        });
      });
    });
  });

  describe('with no aggregation data', () => {
    beforeEach(() => {
      createWrapper({
        state: {
          aggregation: {
            ...aggregationData,
            lastRunAt: null,
          },
        },
      });
    });

    it('does not render the aggregation status', () => {
      expect(findAggregationStatus().exists()).toBe(false);
    });
  });

  describe('Path navigation', () => {
    it('when a stage is selected', () => {
      createWrapper({
        state: {
          pagination: initialPaginationQuery,
        },
      });

      findPathNavigation().vm.$emit('selected', issueStage);

      expect(setSelectedStage).toHaveBeenCalledWith(expect.anything(), issueStage);
      expect(updateStageTablePagination).toHaveBeenCalledWith(expect.anything(), {
        ...initialPaginationQuery,
        page: 1,
      });
    });

    it('when the overview is selected', () => {
      createWrapper({ state: { issueStage } });

      findPathNavigation().vm.$emit('selected', OVERVIEW_STAGE_CONFIG);

      expect(setDefaultSelectedStage).toHaveBeenCalled();
    });

    it('shows loading state when fetching value stream', () => {
      createWrapper({ state: { isLoading: true } });

      expect(findPathNavigation().props('loading')).toBe(true);
    });

    it('shows loading state when fetching stages', () => {
      createWrapper({ state: { isFetchingGroupStages: true } });

      expect(findPathNavigation().props('loading')).toBe(true);
    });
  });

  describe('Url parameters', () => {
    const defaultParams = {
      value_stream_id: selectedValueStream.id,
      created_after: toYmd(createdAfter),
      created_before: toYmd(createdBefore),
      stage_id: null,
      project_ids: null,
      sort: null,
      direction: null,
      page: null,
    };

    describe('with minimal parameters set', () => {
      beforeEach(() => {
        createWrapper({
          getters: {
            cycleAnalyticsRequestParams: () => defaultParams,
          },
        });
      });

      it('sets the created_after and created_before url parameters', () => {
        expect(findUrlSync().props('query')).toMatchObject(defaultParams);
      });
    });

    describe('with selectedProjectIds set', () => {
      const selectedProjectIds = [1, 2, 3];

      beforeEach(() => {
        createWrapper({
          getters: {
            selectedProjectIds: () => selectedProjectIds,
            cycleAnalyticsRequestParams: () => ({
              ...defaultParams,
              project_ids: selectedProjectIds,
            }),
          },
        });
      });

      it('sets the project_ids url parameter', () => {
        expect(findUrlSync().props('query')).toMatchObject({
          project_ids: selectedProjectIds,
        });
      });
    });

    describe('with selectedStage set', () => {
      beforeEach(() => {
        createWrapper({
          state: {
            selectedStage: issueStage,
            pagination: initialPaginationQuery,
          },
          getters: {
            cycleAnalyticsRequestParams: () => defaultParams,
          },
        });
      });

      it('sets the stage, sort, direction and page parameters', () => {
        expect(findUrlSync().props('query')).toMatchObject({
          ...initialPaginationQuery,
          stage_id: issueStage.id,
        });
      });
    });
  });

  describe('with`groupLevelAnalyticsDashboard=true`', () => {
    it('renders a link to the value streams dashboard', () => {
      createWrapper({
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: true,
        },
        state: {
          enableVsdLink: true,
        },
      });

      expect(findOverviewMetrics().props('dashboardsPath')).toBe(
        '/groups/foo/-/analytics/dashboards/value_streams_dashboard',
      );
    });
  });

  describe('with `enableTasksByTypeChart=false`', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          enableTasksByTypeChart: false,
        },
      });
    });

    it('does not display the tasks by type chart', () => {
      expect(findTypeOfWorkCharts().exists()).toBe(false);
    });
  });

  describe('with `enableCustomizableStages=false`', () => {
    beforeEach(() => {
      createWrapper({
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: true,
        },
        state: {
          enableCustomizableStages: false,
        },
      });
    });

    it('does not display the value stream selector', () => {
      expect(findValueStreamSelect().exists()).toBe(false);
    });
  });

  describe('with `enableProjectsFilter=false`', () => {
    beforeEach(() => {
      createWrapper({
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: true,
        },
        state: {
          enableProjectsFilter: false,
        },
      });
    });

    it('does not display the project filter', () => {
      expect(findFilterBar().props('hasProjectFilter')).toBe(false);
    });
  });

  describe('with a project namespace', () => {
    beforeEach(() => {
      createWrapper({
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: true,
        },
        state: {
          enableProjectsFilter: false,
          enableVsdLink: true,
          namespace: projectNamespace,
          project: 'fake-id',
        },
        getters: {
          isProjectNamespace: () => true,
        },
      });
    });

    it('renders a link to the value streams dashboard', () => {
      expect(findOverviewMetrics().props('dashboardsPath')).toBe(
        '/some/cool/path/-/analytics/dashboards/value_streams_dashboard',
      );
    });
  });

  describe('when dashboard link is disabled for the project namespace`', () => {
    beforeEach(() => {
      createWrapper({
        glLicensedFeatures: {
          groupLevelAnalyticsDashboard: true,
        },
        state: {
          enableProjectsFilter: false,
          enableVsdLink: false,
          namespace: projectNamespace,
          project: 'fake-id',
        },
        getters: {
          isProjectNamespace: () => true,
        },
      });
    });

    it('does not render a link to the value streams dashboard', () => {
      expect(findOverviewMetrics().props('dashboardsPath')).toBeNull();
    });
  });
});
