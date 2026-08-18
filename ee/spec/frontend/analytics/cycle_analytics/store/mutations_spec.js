import { HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import * as types from 'ee/analytics/cycle_analytics/store/mutation_types';
import mutations from 'ee/analytics/cycle_analytics/store/mutations';
import {
  createdAfter,
  createdBefore,
  selectedProjects,
  predefinedDateRange,
} from 'jest/analytics/cycle_analytics/mock_data';
import {
  PAGINATION_SORT_DIRECTION_DESC,
  PAGINATION_SORT_FIELD_DURATION,
} from '~/analytics/cycle_analytics/constants';
import {
  issueStage,
  planStage,
  codeStage,
  stagingStage,
  reviewStage,
  customizableStagesAndEvents,
  valueStreams,
} from '../mock_data';

let state = null;
const { stages } = customizableStagesAndEvents;

describe('Value Stream Analytics mutations', () => {
  beforeEach(() => {
    state = {};
  });

  afterEach(() => {
    state = null;
  });

  it.each`
    mutation                                     | stateKey                    | value
    ${types.REQUEST_VALUE_STREAMS}               | ${'valueStreams'}           | ${[]}
    ${types.RECEIVE_VALUE_STREAMS_ERROR}         | ${'valueStreams'}           | ${[]}
    ${types.REQUEST_VALUE_STREAMS}               | ${'isLoadingValueStreams'}  | ${true}
    ${types.RECEIVE_VALUE_STREAMS_ERROR}         | ${'isLoadingValueStreams'}  | ${false}
    ${types.REQUEST_STAGE_DATA}                  | ${'isLoadingStage'}         | ${true}
    ${types.REQUEST_STAGE_DATA}                  | ${'selectedStageEvents'}    | ${[]}
    ${types.REQUEST_STAGE_DATA}                  | ${'pagination'}             | ${{}}
    ${types.RECEIVE_STAGE_DATA_ERROR}            | ${'isLoadingStage'}         | ${false}
    ${types.RECEIVE_STAGE_DATA_ERROR}            | ${'selectedStageEvents'}    | ${[]}
    ${types.RECEIVE_STAGE_DATA_ERROR}            | ${'pagination'}             | ${{}}
    ${types.REQUEST_VALUE_STREAM_DATA}           | ${'isLoading'}              | ${true}
    ${types.RECEIVE_GROUP_STAGES_ERROR}          | ${'stages'}                 | ${[]}
    ${types.REQUEST_GROUP_STAGES}                | ${'stages'}                 | ${[]}
    ${types.REQUEST_STAGE_MEDIANS}               | ${'medians'}                | ${{}}
    ${types.RECEIVE_STAGE_MEDIANS_ERROR}         | ${'medians'}                | ${{}}
    ${types.REQUEST_DELETE_VALUE_STREAM}         | ${'isDeletingValueStream'}  | ${true}
    ${types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS} | ${'isDeletingValueStream'}  | ${false}
    ${types.REQUEST_DELETE_VALUE_STREAM}         | ${'deleteValueStreamError'} | ${null}
    ${types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS} | ${'deleteValueStreamError'} | ${null}
    ${types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS} | ${'selectedValueStream'}    | ${null}
    ${types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS} | ${'stages'}                 | ${[]}
    ${types.INITIALIZE_VALUE_STREAM_SUCCESS}     | ${'isLoading'}              | ${false}
    ${types.REQUEST_STAGE_COUNTS}                | ${'stageCounts'}            | ${{}}
    ${types.RECEIVE_STAGE_COUNTS_ERROR}          | ${'stageCounts'}            | ${{}}
  `('$mutation will set $stateKey=$value', ({ mutation, stateKey, value }) => {
    mutations[mutation](state);

    expect(state[stateKey]).toEqual(value);
  });

  const pagination = { page: 10, hasNextPage: true, sort: null, direction: null };

  it.each`
    mutation                                   | payload                                                  | expectedState
    ${types.SET_SELECTED_PROJECTS}             | ${selectedProjects}                                      | ${{ selectedProjects }}
    ${types.SET_DATE_RANGE}                    | ${{ createdAfter, createdBefore }}                       | ${{ createdAfter, createdBefore }}
    ${types.SET_PREDEFINED_DATE_RANGE}         | ${predefinedDateRange}                                   | ${{ predefinedDateRange }}
    ${types.SET_SELECTED_STAGE}                | ${{ id: 'first-stage' }}                                 | ${{ selectedStage: { id: 'first-stage' } }}
    ${types.RECEIVE_DELETE_VALUE_STREAM_ERROR} | ${'Some error occurred'}                                 | ${{ deleteValueStreamError: 'Some error occurred' }}
    ${types.RECEIVE_VALUE_STREAMS_SUCCESS}     | ${valueStreams}                                          | ${{ valueStreams, isLoadingValueStreams: false }}
    ${types.SET_SELECTED_VALUE_STREAM}         | ${valueStreams[1].id}                                    | ${{ selectedValueStream: {} }}
    ${types.SET_PAGINATION}                    | ${pagination}                                            | ${{ pagination: { ...pagination, sort: PAGINATION_SORT_FIELD_DURATION, direction: PAGINATION_SORT_DIRECTION_DESC } }}
    ${types.SET_PAGINATION}                    | ${{ ...pagination, sort: 'duration', direction: 'asc' }} | ${{ pagination: { ...pagination, sort: 'duration', direction: 'asc' } }}
  `(
    '$mutation with payload $payload will update state with $expectedState',
    ({ mutation, payload, expectedState }) => {
      state = { selectedGroup: { fullPath: 'rad-stage' } };
      mutations[mutation](state, payload);

      expect(state).toMatchObject(expectedState);
    },
  );

  describe(`${types.RECEIVE_VALUE_STREAMS_SUCCESS}`, () => {
    const dummyValueStream = { id: 3, name: 'A new value stream' };
    const sorted = [dummyValueStream, valueStreams[0], valueStreams[1]];
    it('will sort the value streams alphabetically', () => {
      state = { valueStreams: [] };
      mutations[types.RECEIVE_VALUE_STREAMS_SUCCESS](state, [
        valueStreams[1],
        valueStreams[0],
        dummyValueStream,
      ]);

      expect(state.valueStreams).toEqual(sorted);
    });
  });

  describe('with value streams available', () => {
    it.each`
      mutation                           | payload            | expectedState
      ${types.SET_SELECTED_VALUE_STREAM} | ${valueStreams[1]} | ${{ selectedValueStream: valueStreams[1] }}
      ${types.SET_SELECTED_VALUE_STREAM} | ${'fake-id'}       | ${{ selectedValueStream: {} }}
    `(
      '$mutation with payload $payload will update state with $expectedState',
      ({ mutation, payload, expectedState }) => {
        state = { valueStreams };
        mutations[mutation](state, payload);
        expect(state).toMatchObject(expectedState);
      },
    );
  });

  describe(`${types.RECEIVE_VALUE_STREAM_DATA_SUCCESS}`, () => {
    it('will set isLoading=false and errorCode=null', () => {
      mutations[types.RECEIVE_VALUE_STREAM_DATA_SUCCESS](state, {
        stats: [],
        stages: [],
      });

      expect(state.errorCode).toBe(null);
      expect(state.isLoading).toBe(false);
    });
  });

  describe(`${types.RECEIVE_GROUP_STAGES_SUCCESS}`, () => {
    describe('with data', () => {
      beforeEach(() => {
        mutations[types.RECEIVE_GROUP_STAGES_SUCCESS](state, stages);
      });

      it('will convert the stats object to stages', () => {
        [issueStage, planStage, codeStage, stagingStage, reviewStage].forEach((stage) => {
          expect(state.stages).toContainEqual(stage);
        });
      });
    });
  });

  describe(`${types.RECEIVE_VALUE_STREAM_DATA_ERROR}`, () => {
    it('sets errorCode correctly', () => {
      const errorCode = HTTP_STATUS_FORBIDDEN;

      mutations[types.RECEIVE_VALUE_STREAM_DATA_ERROR](state, errorCode);

      expect(state.isLoading).toBe(false);
      expect(state.errorCode).toBe(errorCode);
    });
  });

  describe(`${types.RECEIVE_STAGE_MEDIANS_SUCCESS}`, () => {
    beforeEach(() => {
      state = {
        medians: {},
      };

      mutations[types.RECEIVE_STAGE_MEDIANS_SUCCESS](state, [
        { id: 1, value: 7580 },
        { id: 2, value: 434340 },
      ]);
    });

    it('formats each stage median for display in the path navigation', () => {
      expect(state.medians).toMatchObject({ 1: '2 hours', 2: '5 days' });
    });
  });

  describe(`${types.RECEIVE_STAGE_COUNTS_SUCCESS}`, () => {
    beforeEach(() => {
      state = {
        stageCounts: {},
      };

      mutations[types.RECEIVE_STAGE_COUNTS_SUCCESS](state, [
        { id: 1, count: 10 },
        { id: 2, count: 20 },
      ]);
    });

    it('sets each id as a key in the stageCounts object with the corresponding count', () => {
      expect(state.stageCounts).toMatchObject({ 1: 10, 2: 20 });
    });
  });

  describe(`${types.INITIALIZE_VSA}`, () => {
    const initialData = {
      group: { fullPath: 'cool-group' },
      selectedProjects,
      createdAfter: '2019-12-31',
      createdBefore: '2020-01-01',
      pagination: {
        page: 1,
        sort: PAGINATION_SORT_FIELD_DURATION,
        direction: PAGINATION_SORT_DIRECTION_DESC,
      },
    };

    it.each`
      stateKey              | expectedState
      ${'isLoading'}        | ${true}
      ${'selectedProjects'} | ${initialData.selectedProjects}
      ${'createdAfter'}     | ${initialData.createdAfter}
      ${'createdBefore'}    | ${initialData.createdBefore}
    `('$stateKey will be set to $expectedState', ({ stateKey, expectedState }) => {
      state = {};
      mutations[types.INITIALIZE_VSA](state, initialData);

      expect(state[stateKey]).toBe(expectedState);
    });

    it.each`
      stateKey       | expectedState
      ${'page'}      | ${1}
      ${'sort'}      | ${PAGINATION_SORT_FIELD_DURATION}
      ${'direction'} | ${PAGINATION_SORT_DIRECTION_DESC}
    `('$stateKey will be set to $expectedState', ({ stateKey, expectedState }) => {
      state = {};
      mutations[types.INITIALIZE_VSA](state, initialData);

      expect(state.pagination[stateKey]).toBe(expectedState);
    });
  });
});
