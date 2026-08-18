import {
  nextPageParams,
  prevPageParams,
  initialPaginationParams,
  paginationMethodsFor,
  reactivePaginationMethods,
} from 'ee/ai/catalog/pagination_utils';
import { PAGE_SIZE } from 'ee/ai/catalog/constants';

describe('AI Catalog Pagination Utils', () => {
  describe('nextPageParams', () => {
    it('returns params for the next page', () => {
      const pageInfo = { endCursor: 'cursor_abc' };

      expect(nextPageParams(pageInfo)).toEqual({
        before: null,
        after: 'cursor_abc',
        first: PAGE_SIZE,
        last: null,
      });
    });
  });

  describe('prevPageParams', () => {
    it('returns params for the previous page', () => {
      const pageInfo = { startCursor: 'cursor_xyz' };

      expect(prevPageParams(pageInfo)).toEqual({
        after: null,
        before: 'cursor_xyz',
        first: null,
        last: PAGE_SIZE,
      });
    });
  });

  describe('initialPaginationParams', () => {
    it('returns the initial pagination state', () => {
      expect(initialPaginationParams()).toEqual({
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      });
    });

    it('returns a new object on each call', () => {
      expect(initialPaginationParams()).not.toBe(initialPaginationParams());
    });
  });

  describe('paginationMethodsFor', () => {
    let context;
    let methods;

    beforeEach(() => {
      context = {
        pageInfo: { endCursor: 'end_abc', startCursor: 'start_xyz' },
        $apollo: {
          queries: {
            myQuery: {
              variables: { search: 'test' },
              refetch: jest.fn(),
            },
          },
        },
      };
      methods = paginationMethodsFor('myQuery');
    });

    it('handleNextPage refetches with next page params', () => {
      methods.handleNextPage.call(context);

      expect(context.$apollo.queries.myQuery.refetch).toHaveBeenCalledWith({
        search: 'test',
        before: null,
        after: 'end_abc',
        first: PAGE_SIZE,
        last: null,
      });
    });

    it('handlePrevPage refetches with previous page params', () => {
      methods.handlePrevPage.call(context);

      expect(context.$apollo.queries.myQuery.refetch).toHaveBeenCalledWith({
        search: 'test',
        after: null,
        before: 'start_xyz',
        first: null,
        last: PAGE_SIZE,
      });
    });
  });

  describe('reactivePaginationMethods', () => {
    let context;

    beforeEach(() => {
      context = {
        pageInfo: { endCursor: 'end_abc', startCursor: 'start_xyz' },
        paginationVariables: {},
      };
    });

    it('handleNextPage sets paginationVariables to next page params', () => {
      reactivePaginationMethods.handleNextPage.call(context);

      expect(context.paginationVariables).toEqual({
        before: null,
        after: 'end_abc',
        first: PAGE_SIZE,
        last: null,
      });
    });

    it('handlePrevPage sets paginationVariables to previous page params', () => {
      reactivePaginationMethods.handlePrevPage.call(context);

      expect(context.paginationVariables).toEqual({
        after: null,
        before: 'start_xyz',
        first: null,
        last: PAGE_SIZE,
      });
    });

    it('resetPagination sets paginationVariables to initial state', () => {
      context.paginationVariables = { after: 'something' };
      reactivePaginationMethods.resetPagination.call(context);

      expect(context.paginationVariables).toEqual({
        before: null,
        after: null,
        first: PAGE_SIZE,
        last: null,
      });
    });
  });
});
