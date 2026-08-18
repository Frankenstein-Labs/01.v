import { statusStrategy } from 'ee/work_items/board/grouping/status_strategy';
import getBoardNamespaceStatusesQuery from 'ee/work_items/board/graphql/get_namespace_statuses.query.graphql';
import {
  buildStatus,
  buildStatusWidget,
  buildNamespaceStatusesResponse,
  buildWorkItemNode,
} from 'jest/work_items/board/mock_data';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';

describe('status grouping strategy', () => {
  const value = {
    id: 'gid://gitlab/Status/2',
    name: 'In progress',
    iconName: 'status-running',
    color: '#1f75cb',
    category: 'in_progress',
  };

  it('groups by the status property', () => {
    expect(statusStrategy.property).toBe('status');
  });

  it('has a human-readable label', () => {
    expect(statusStrategy.label).toBe('Status');
  });

  it('uses the namespace statuses query for its column values', () => {
    expect(statusStrategy.valuesQuery).toBe(getBoardNamespaceStatusesQuery);
  });

  describe('extractValues', () => {
    it('returns the root namespace status nodes sorted by category', () => {
      const { data } = buildNamespaceStatusesResponse([
        buildStatus(1, 'Cancelled', 'canceled'),
        buildStatus(2, 'Done', 'done'),
        buildStatus(3, 'Triage', 'triage'),
        buildStatus(4, 'In progress', 'in_progress'),
        buildStatus(5, 'To do', 'to_do'),
      ]);

      expect(statusStrategy.extractValues(data).map((status) => status.name)).toEqual([
        'Triage',
        'To do',
        'In progress',
        'Done',
        'Cancelled',
      ]);
    });

    it('returns an empty array when statuses are absent', () => {
      expect(statusStrategy.extractValues({})).toEqual([]);
      expect(statusStrategy.extractValues(undefined)).toEqual([]);
    });
  });

  describe('columnFilter', () => {
    it('filters the column work items by status name', () => {
      expect(statusStrategy.columnFilter(value)).toEqual({ status: { name: 'In progress' } });
    });
  });

  describe('itemValueId', () => {
    it('returns the work item status id', () => {
      const item = buildWorkItemNode(1, { widgets: [buildStatusWidget(value)] });

      expect(statusStrategy.itemValueId(item)).toBe('gid://gitlab/Status/2');
    });

    it('returns null when the item has no status widget', () => {
      const item = buildWorkItemNode(1, { widgets: [] });

      expect(statusStrategy.itemValueId(item)).toBeNull();
    });
  });

  describe('moveInput', () => {
    it('builds the status widget update input from the value id', () => {
      expect(statusStrategy.moveInput(value)).toEqual({
        statusWidget: { status: 'gid://gitlab/Status/2' },
      });
    });
  });

  describe('newItemDraft', () => {
    it('builds the status widgets-draft fragment from the column value', () => {
      expect(statusStrategy.newItemDraft(value)).toEqual({
        STATUS: { status: value },
      });
    });
  });

  describe('patchCard', () => {
    it('refreshes the status widget display fields in place', () => {
      const node = {
        widgets: [
          {
            type: 'STATUS',
            status: { __typename: 'WorkItemStatusCustom', id: 'old', name: 'To do' },
          },
        ],
      };

      statusStrategy.patchCard(node, value);

      expect(node.widgets[0].status).toEqual({
        __typename: 'WorkItemStatusCustom',
        id: 'gid://gitlab/Status/2',
        name: 'In progress',
        iconName: 'status-running',
        color: '#1f75cb',
        category: 'in_progress',
      });
    });

    it('does nothing when the node has no status widget', () => {
      const node = { widgets: [] };

      expect(() => statusStrategy.patchCard(node, value)).not.toThrow();
    });
  });

  describe('headerDecoration', () => {
    it('returns an icon decoration when the value has an icon', () => {
      expect(statusStrategy.headerDecoration(value)).toEqual({
        type: 'icon',
        name: 'status-running',
        color: '#1f75cb',
      });
    });

    it('returns no decoration when the value has no icon', () => {
      expect(statusStrategy.headerDecoration({ name: 'No icon' })).toEqual({ type: 'none' });
    });
  });

  it('uses the namespace work item types query as its gate query', () => {
    expect(statusStrategy.gateQuery).toBe(namespaceWorkItemTypesQuery);
  });

  describe('extractGateData', () => {
    const buildType = (id, allowedStatuses) => ({
      id,
      widgetDefinitions: [{ type: 'STATUS', allowedStatuses }],
    });

    it('maps each work item type id to its allowed statuses', () => {
      const allowed = [{ id: 'gid://gitlab/Status/2' }];
      const data = { namespace: { workItemTypes: { nodes: [buildType('type-1', allowed)] } } };

      expect(statusStrategy.extractGateData(data)).toEqual({ 'type-1': allowed });
    });

    it('returns an empty map when types are absent (e.g. CE)', () => {
      expect(statusStrategy.extractGateData({})).toEqual({});
      expect(statusStrategy.extractGateData(undefined)).toEqual({});
    });
  });

  describe('isDropAllowed', () => {
    const gateData = { 'type-1': [{ id: 'gid://gitlab/Status/2' }] };
    const item = { workItemType: { id: 'type-1' } };

    it('allows the drop when the value id is in the type allowed statuses', () => {
      expect(statusStrategy.isDropAllowed({ item, value, gateData })).toBe(true);
    });

    it('rejects the drop when the value id is not allowed for the type', () => {
      const other = { ...value, id: 'gid://gitlab/Status/99' };

      expect(statusStrategy.isDropAllowed({ item, value: other, gateData })).toBe(false);
    });

    it('allows the drop when there is no gate data (CE / not yet loaded)', () => {
      expect(statusStrategy.isDropAllowed({ item, value, gateData: null })).toBe(true);
    });

    it('allows the drop when the type has no recorded constraint', () => {
      expect(
        statusStrategy.isDropAllowed({
          item: { workItemType: { id: 'unknown' } },
          value,
          gateData,
        }),
      ).toBe(true);
    });
  });
});
