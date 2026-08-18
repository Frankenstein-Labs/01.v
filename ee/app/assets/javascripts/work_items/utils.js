import { uniqBy } from 'lodash-es';
import {
  isStatusWidget,
  sortWorkItems,
  getSortValue as getSortValueCE,
  findHealthStatusWidget,
  findLinkedItemsWidget,
  findStatusWidget,
  findWeightWidget,
} from '~/work_items/utils';
import {
  DEFAULT_STATE_CLOSED,
  DEFAULT_STATE_DUPLICATE,
  DEFAULT_STATE_OPEN,
  STATUS_CATEGORIES,
  HEALTH_STATUS_VALUE_MAP,
  STATUS_CATEGORY_VALUE_MAP,
  WIDGET_TYPE_AGENT_PLAN,
} from 'ee/work_items/constants';
import {
  HEALTH_STATUS_ASC,
  HEALTH_STATUS_DESC,
  BLOCKING_ISSUES_ASC,
  BLOCKING_ISSUES_DESC,
  STATUS_ASC,
  STATUS_DESC,
  WEIGHT_ASC,
  WEIGHT_DESC,
} from '~/work_items/list/constants';

export const findAgentPlanWidget = (workItem) =>
  workItem?.features?.agentPlan ||
  workItem?.widgets?.find((widget) => widget.type === WIDGET_TYPE_AGENT_PLAN);

export const getDefaultStateType = (lifecycle, status) => {
  if (lifecycle.defaultClosedStatus?.id === status.id) {
    return DEFAULT_STATE_CLOSED;
  }
  if (lifecycle.defaultDuplicateStatus?.id === status.id) {
    return DEFAULT_STATE_DUPLICATE;
  }
  if (lifecycle.defaultOpenStatus?.id === status.id) {
    return DEFAULT_STATE_OPEN;
  }
  return null;
};

/**
 * Takes a list of statuses and returns a unique list of statuses sorted by category.
 *
 * @param {WorkItemStatus[]} statuses statuses
 * @returns {WorkItemStatus[]} a merged list of allowed statuses sorted by category
 */
export const sortStatuses = (statuses) => {
  const statusesMap = new Map();
  Object.values(STATUS_CATEGORIES).forEach((category) => {
    statusesMap.set(category.toLowerCase(), []);
  });

  statuses.forEach((status) => {
    statusesMap.get(status.category).push(status);
  });

  return uniqBy(Array.from(statusesMap.values()).flat(), 'id');
};

/**
 * Takes `namespace.workItemTypes.nodes` and returns a unique list of allowed statuses
 * sorted by category.
 *
 * @param {WorkItemType[]} workItemTypes `namespace.workItemTypes.nodes` from GraphQL
 * @returns {WorkItemStatus[]} a unique list of allowed statuses sorted by category
 */
export const getStatuses = (workItemTypes) => {
  const statuses = workItemTypes
    ?.map((workItemType) => workItemType?.widgetDefinitions?.find(isStatusWidget)?.allowedStatuses)
    .filter((allowedStatuses) => Boolean(allowedStatuses))
    .flat();
  return sortStatuses(statuses);
};

export const getSortValueEE = (item, sortKey) => {
  switch (sortKey) {
    case WEIGHT_ASC:
    case WEIGHT_DESC:
      return findWeightWidget(item)?.weight ?? null;
    case STATUS_ASC:
    case STATUS_DESC: {
      const category = findStatusWidget(item)?.status?.category;
      if (!category) return null;
      return STATUS_CATEGORY_VALUE_MAP[category] || null;
    }
    case HEALTH_STATUS_ASC:
    case HEALTH_STATUS_DESC: {
      const healthStatus = findHealthStatusWidget(item)?.healthStatus;
      if (!healthStatus) return null;
      return HEALTH_STATUS_VALUE_MAP[healthStatus] || null;
    }
    case BLOCKING_ISSUES_ASC:
    case BLOCKING_ISSUES_DESC:
      return findLinkedItemsWidget(item)?.blockingCount || null;
    default:
      return getSortValueCE(item, sortKey); // signal CE fallback
  }
};

export function getSortedWorkItems(workItems, sortKey) {
  return sortWorkItems(workItems, sortKey, getSortValueEE);
}
