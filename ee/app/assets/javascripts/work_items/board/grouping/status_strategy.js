import { s__ } from '~/locale';
import { sortStatuses } from 'ee/work_items/utils';
import getBoardNamespaceStatusesQuery from 'ee_else_ce/work_items/board/graphql/get_namespace_statuses.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import { findStatusWidget, getWorkItemTypeAllowedStatusMap } from '~/work_items/utils';

// Status grouping is EE-only (statuses don't exist in CE), so grouping by
// status in CE resolves to no strategy.
/** @type {import('~/work_items/board/grouping/index').GroupingStrategy} */
export const statusStrategy = {
  property: 'status',

  label: s__('WorkItems|Status'),

  valuesQuery: getBoardNamespaceStatusesQuery,

  // Sort columns by category (triage, to_do, in_progress, done, cancelled) for a
  // consistent order rather than the order the API returns them in.
  extractValues(data) {
    return sortStatuses(data?.namespace?.rootNamespace?.statuses?.nodes ?? []);
  },

  columnFilter(value) {
    return { status: { name: value.name } };
  },

  // The column value id a work item currently belongs to.
  // Used to move the card to the matching column when its status changes
  // via the detail panel. Null when the item has no status.
  itemValueId(item) {
    return findStatusWidget(item)?.status?.id ?? null;
  },

  moveInput(value) {
    return { statusWidget: { status: value.id } };
  },

  // Widgets-draft fragment read by the create modal (via setNewWorkItemCache) so a
  // work item created in this column is pre-populated with the column's status. The
  // column value already carries the status fields the draft expects ({ id, name, ... }).
  newItemDraft(value) {
    return { [WIDGET_TYPE_STATUS]: { status: value } };
  },

  patchCard(node, value) {
    const statusWidget = findStatusWidget(node);
    if (statusWidget) {
      // Leading spread preserves any status fields the column value omits.
      statusWidget.status = { ...statusWidget.status, ...value };
    }
  },

  headerDecoration(value) {
    return value.iconName
      ? { type: 'icon', name: value.iconName, color: value.color }
      : { type: 'none' };
  },

  // Gate: a work item type's Status widget definition limits which statuses it can take.
  // In CE `allowedStatuses` is absent, so the map is empty and every drop is allowed.
  gateQuery: namespaceWorkItemTypesQuery,

  extractGateData(data) {
    return getWorkItemTypeAllowedStatusMap(data?.namespace?.workItemTypes?.nodes ?? []);
  },

  isDropAllowed({ item, value, gateData }) {
    const allowedStatuses = gateData?.[item?.workItemType?.id];
    // No constraint recorded for this type (CE, or a type with no status widget) -> allow.
    if (!allowedStatuses) {
      return true;
    }
    return allowedStatuses.some((status) => status.id === value.id);
  },
};
