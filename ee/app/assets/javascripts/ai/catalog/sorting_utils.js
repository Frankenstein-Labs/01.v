/**
 * Returns true when the given sort key has no meaningful direction.
 *
 * CATALOG_PRIORITY is a backend-defined ordering that the resolver applies
 * automatically. There is no ascending/descending variant, so the direction
 * toggle must be suppressed in the UI and the direction suffix must be omitted
 * from GraphQL variables and URL params.
 *
 * @param {string} sortKey - The sort key without direction suffix (e.g. 'STAR_COUNT').
 */
export const isSortDirectionless = (sortKey) => sortKey === 'CATALOG_PRIORITY';

/**
 * Shared computed properties for AI Catalog sort state.
 *
 * Components that use these computeds must have a `sort` data property
 * initialized to a sort string of the form `<KEY>_ASC`, `<KEY>_DESC`,
 * or the bare `DEFAULT_SORT` constant (e.g. `'CATALOG_PRIORITY'`).
 *
 * Usage:
 *
 *   import { sortingComputeds } from '../sorting_utils';
 *
 *   computed: {
 *     ...sortingComputeds,
 *     // component-specific computeds
 *   }
 */
export const sortingComputeds = Object.freeze({
  /**
   * The value to feed FilteredSearchBar's `initial-sort-by` prop.
   * Its validator only accepts '' or a *_ASC/*_DESC string, so a
   * directionless sort maps to '' and the dropdown falls back to
   * the first sort option (the default).
   */
  initialSortBy() {
    return isSortDirectionless(this.sort) ? '' : this.sort;
  },

  /**
   * The GraphQL enum value to pass to the API. Returns null for directionless sorts so the
   * backend resolver applies its own ordering.
   */
  sortGraphQLValue() {
    return isSortDirectionless(this.sort) ? null : this.sort;
  },
});
