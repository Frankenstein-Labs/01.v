import groupComplianceRequirementsStatusesQuery from '../graphql/queries/group_compliance_requirements_statuses.query.graphql';
import projectComplianceRequirementsStatusesQuery from '../graphql/queries/project_compliance_requirements_statuses.query.graphql';
import { GROUP_BY } from '../constants';

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;

const defaultPageInfo = () => ({
  startCursor: null,
  endCursor: null,
  hasNextPage: false,
  hasPreviousPage: false,
});

const EXTRACTORS = {
  [GROUP_BY.REQUIREMENTS]: (item) => item.complianceRequirement,
  [GROUP_BY.FRAMEWORKS]: (item) => item.complianceFramework,
  [GROUP_BY.PROJECTS]: (item) => item.project,
};

function groupBy(items, key) {
  const result = [];
  const extractor = EXTRACTORS[key];
  if (!extractor) {
    throw new Error(`Invalid groupBy key: ${key}`);
  }

  const groupMap = {};

  items.forEach((item) => {
    const groupValue = extractor(item);
    const { id } = groupValue;
    if (!groupMap[id]) {
      groupMap[id] = { id, children: [], groupValue, failCount: 0 };
      result.push(groupMap[id]);
    }
    groupMap[id].children.push(item);
    groupMap[id].failCount += item.failCount;
  });

  return result;
}

function mergeGroups({ mergedGroups, groupMap, newGroups }) {
  newGroups.forEach((group) => {
    const { id } = group;
    if (!groupMap[id]) {
      // eslint-disable-next-line no-param-reassign
      groupMap[id] = { id, children: [], groupValue: group.groupValue, failCount: 0 };
      mergedGroups.push(groupMap[id]);
    }
    const existingGroup = groupMap[id];
    existingGroup.children = [...existingGroup.children, ...group.children];
    existingGroup.failCount += group.failCount;
  });

  return mergedGroups;
}

export class GroupedLoader {
  constructor(options = {}) {
    this.groupPagesCache = [];
    this.mode = options.mode || 'group';
    this.groupBy = options.groupBy || null;
    this.apollo = options.apollo;
    this.pageSize = options.pageSize || DEFAULT_PAGE_SIZE;

    this.fullPath = options.fullPath;
    this.filters = {};
    this.processedEntities = [];

    if (!this.apollo || !this.fullPath) {
      throw new Error('Missing apollo client or fullPath');
    }
  }

  async fetchPage(options = {}) {
    const result = await this.apollo.query({
      query:
        this.mode === 'group'
          ? groupComplianceRequirementsStatusesQuery
          : projectComplianceRequirementsStatusesQuery,
      variables: {
        fullPath: this.fullPath,
        filters: this.filters,
        orderBy: this.groupBy,
        [options.before ? 'last' : 'first']: this.pageSize,
        ...options,
      },
    });
    return result;
  }

  async loadUngroupedPage(options = {}) {
    const result = await this.fetchPage(options);
    const statuses = result.data.container.complianceRequirementStatuses;
    this.pageInfo = statuses.pageInfo;

    return {
      data: [
        {
          group: null,
          children: statuses.nodes,
        },
      ],
      pageInfo: {
        hasNextPage: this.pageInfo.hasNextPage,
        hasPreviousPage: this.pageInfo.hasPreviousPage,
      },
    };
  }

  async loadGroupedPage(options, direction = 'after') {
    const result = [];
    const groupMap = {};

    do {
      // This async loop is intentional
      // eslint-disable-next-line no-await-in-loop
      const newPage = await this.fetchPage({
        ...options,
        ...(direction === 'before'
          ? { last: MAX_PAGE_SIZE, before: this.pageInfo?.startCursor }
          : { first: MAX_PAGE_SIZE, after: this.pageInfo?.endCursor }),
      });
      const statuses = newPage.data.container.complianceRequirementStatuses;
      const grouped = groupBy(statuses.nodes, this.groupBy).filter(
        (n) => !this.processedEntities.includes(n.id),
      );

      const itemsToTake =
        result.length < this.pageSize
          ? grouped.splice(0, Math.min(this.pageSize - result.length, grouped.length))
          : // If we are at the end of the list, take all remaining items
            grouped.filter((item) => result.some((r) => r.id === item.id));

      if (result.length === this.pageSize && itemsToTake.length === 0) {
        break;
      }

      mergeGroups({
        mergedGroups: result,
        groupMap,
        newGroups: itemsToTake,
      });

      const unprocessedCount = grouped.length;
      if (unprocessedCount > 0) {
        // this page is not fully processed yet, remember which entities were processed to ignore them on next load
        this.processedEntities = [...this.processedEntities, ...itemsToTake.map((item) => item.id)];
        break;
      } else {
        this.processedEntities = [];
        this.pageInfo = statuses.pageInfo;
      }
    } while (this.pageInfo.hasNextPage);

    return {
      data: result,
      pageInfo: {
        hasNextPage: this.pageInfo.hasNextPage || Boolean(this.processedEntities.length),
        hasPreviousPage: this.groupPagesCache.length > 0,
      },
    };
  }

  async loadPage(options = {}) {
    if (!this.groupBy) {
      return this.loadUngroupedPage(options);
    }

    const result = await this.loadGroupedPage(options);
    this.groupPagesCache.push(result);
    return result;
  }

  resetPagination() {
    this.groupPagesCache = [];
    this.pageInfo = defaultPageInfo();
  }

  setPageSize(newPageSize) {
    this.pageSize = newPageSize;
    this.resetPagination();
  }

  loadNextPage() {
    return this.loadPage({
      after: this.pageInfo.endCursor,
    });
  }

  loadPrevPage() {
    if (this.groupBy) {
      if (this.groupPagesCache.length < 2) {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        throw new Error('No previous page available');
      }

      this.groupPagesCache.pop();
      return this.groupPagesCache.at(-1);
    }

    return this.loadPage({
      before: this.pageInfo.startCursor,
    });
  }

  setFilters(newFilters) {
    this.filters = newFilters;
    this.resetPagination();
  }

  setGroupBy(newGroupBy) {
    this.groupBy = newGroupBy;
    this.resetPagination();
  }
}
