import { PAGE_SIZE } from './constants';

export const nextPageParams = (pageInfo) => ({
  before: null,
  after: pageInfo.endCursor,
  first: PAGE_SIZE,
  last: null,
});

export const prevPageParams = (pageInfo) => ({
  after: null,
  before: pageInfo.startCursor,
  first: null,
  last: PAGE_SIZE,
});

// Function, not a constant — each caller gets its own object to prevent cross-instance mutation.
export const initialPaginationParams = () => ({
  before: null,
  after: null,
  first: PAGE_SIZE,
  last: null,
});

export function paginationMethodsFor(queryName) {
  return {
    handleNextPage() {
      const query = this.$apollo.queries[queryName];
      query.refetch({
        ...query.variables,
        ...nextPageParams(this.pageInfo),
      });
    },
    handlePrevPage() {
      const query = this.$apollo.queries[queryName];
      query.refetch({
        ...query.variables,
        ...prevPageParams(this.pageInfo),
      });
    },
  };
}

export const reactivePaginationMethods = Object.freeze({
  handleNextPage() {
    this.paginationVariables = nextPageParams(this.pageInfo);
  },
  handlePrevPage() {
    this.paginationVariables = prevPageParams(this.pageInfo);
  },
  resetPagination() {
    this.paginationVariables = initialPaginationParams();
  },
});
