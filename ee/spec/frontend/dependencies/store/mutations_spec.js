import { SORT_ASCENDING, SORT_DESCENDING } from 'ee/dependencies/store/constants';
import * as types from 'ee/dependencies/store/mutation_types';
import mutations from 'ee/dependencies/store/mutations';
import getInitialState from 'ee/dependencies/store/state';
import { TEST_HOST } from 'helpers/test_constants';

describe('Dependencies mutations', () => {
  let state;

  beforeEach(() => {
    state = getInitialState();
  });

  describe(types.SET_DEPENDENCIES_ENDPOINT, () => {
    it('sets the endpoint', () => {
      mutations[types.SET_DEPENDENCIES_ENDPOINT](state, TEST_HOST);

      expect(state.endpoint).toBe(TEST_HOST);
    });
  });

  describe(types.SET_EXPORT_DEPENDENCIES_ENDPOINT, () => {
    it('sets the export endpoint', () => {
      mutations[types.SET_EXPORT_DEPENDENCIES_ENDPOINT](state, TEST_HOST);

      expect(state.exportEndpoint).toBe(TEST_HOST);
    });
  });

  describe(types.SET_FETCHING_IN_PROGRESS, () => {
    it('sets if export is being fetched', () => {
      mutations[types.SET_FETCHING_IN_PROGRESS](state, true);

      expect(state.fetchingInProgress).toBe(true);
    });
  });

  describe(types.SET_PAGE_INFO, () => {
    it('correctly mutates the state', () => {
      const pageInfo = {
        type: 'cursor',
        currentCursor: 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9',
        endCursor: 'eyJpZCI6IjYyIiwiX2tkIjoibiJ9',
        hasNextPage: true,
        hasPreviousPage: true,
        startCursor: 'eyJpZCI6IjQyIiwiX2tkIjoicCJ9',
      };
      mutations[types.SET_PAGE_INFO](state, pageInfo);

      expect(state.pageInfo).toBe(pageInfo);
    });
  });

  describe(types.REQUEST_DEPENDENCIES, () => {
    beforeEach(() => {
      mutations[types.REQUEST_DEPENDENCIES](state);
    });

    it('correctly mutates the state', () => {
      expect(state.isLoading).toBe(true);
      expect(state.errorLoading).toBe(false);
    });
  });

  describe(types.RECEIVE_DEPENDENCIES_SUCCESS, () => {
    const dependencies = [];
    const pageInfo = {};

    beforeEach(() => {
      mutations[types.RECEIVE_DEPENDENCIES_SUCCESS](state, { dependencies, pageInfo });
    });

    it('correctly mutates the state', () => {
      expect(state.isLoading).toBe(false);
      expect(state.errorLoading).toBe(false);
      expect(state.dependencies).toBe(dependencies);
      expect(state.pageInfo).toBe(pageInfo);
      expect(state.initialized).toBe(true);
    });
  });

  describe(types.RECEIVE_DEPENDENCIES_ERROR, () => {
    beforeEach(() => {
      mutations[types.RECEIVE_DEPENDENCIES_ERROR](state);
    });

    it('correctly mutates the state', () => {
      expect(state.isLoading).toBe(false);
      expect(state.errorLoading).toBe(true);
      expect(state.dependencies).toEqual([]);
      expect(state.pageInfo).toEqual({});
      expect(state.initialized).toBe(true);
    });
  });

  describe(types.SET_SORT_FIELD, () => {
    it.each`
      field         | order
      ${'name'}     | ${SORT_ASCENDING}
      ${'packager'} | ${SORT_ASCENDING}
      ${'severity'} | ${SORT_DESCENDING}
      ${'license'}  | ${SORT_ASCENDING}
      ${'foo'}      | ${undefined}
    `('sets the sort field to $field and default sort order to $order', ({ field, order }) => {
      mutations[types.SET_SORT_FIELD](state, field);

      expect(state.sortField).toBe(field);
      expect(state.sortOrder).toBe(order);
    });
  });

  describe(types.TOGGLE_SORT_ORDER, () => {
    it('toggles the sort order', () => {
      const sortState = { sortOrder: SORT_ASCENDING };
      mutations[types.TOGGLE_SORT_ORDER](sortState);

      expect(sortState.sortOrder).toBe(SORT_DESCENDING);

      mutations[types.TOGGLE_SORT_ORDER](sortState);

      expect(sortState.sortOrder).toBe(SORT_ASCENDING);
    });
  });

  describe(types.TOGGLE_VULNERABILITY_ITEM_LOADING, () => {
    const item = { occurrenceId: 1 };

    it('toggles the selected item', () => {
      mutations[types.TOGGLE_VULNERABILITY_ITEM_LOADING](state, item);

      expect(state.vulnerabilityItemsLoading).toEqual([item]);

      mutations[types.TOGGLE_VULNERABILITY_ITEM_LOADING](state, item);

      expect(state.vulnerabilityItemsLoading).toEqual([]);
    });
  });

  describe(types.SET_VULNERABILITIES, () => {
    const payload = [{ occurrence_id: 1 }];

    it('sets the vulnerability data', () => {
      mutations[types.SET_VULNERABILITIES](state, payload);

      expect(state.vulnerabilityInfo).toStrictEqual({ 1: payload });
    });

    it('does not set vulnerability data if empty', () => {
      mutations[types.SET_VULNERABILITIES](state, []);

      expect(state.vulnerabilityInfo).toEqual({});
    });
  });

  describe(types.SET_FULL_PATH, () => {
    const fullPath = 'group/project';

    it('sets the full path', () => {
      mutations[types.SET_FULL_PATH](state, fullPath);

      expect(state.fullPath).toBe(fullPath);
    });
  });
});
