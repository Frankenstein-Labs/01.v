import {
  getDefaultStateType,
  getStatuses,
  sortStatuses,
  getSortValueEE,
  getSortedWorkItems,
} from 'ee/work_items/utils';
import { STATUS_CATEGORY_VALUE_MAP, HEALTH_STATUS_VALUE_MAP } from 'ee/work_items/constants';
import {
  HEALTH_STATUS_ASC,
  HEALTH_STATUS_DESC,
  BLOCKING_ISSUES_ASC,
  BLOCKING_ISSUES_DESC,
  STATUS_ASC,
  STATUS_DESC,
  WEIGHT_ASC,
  WEIGHT_DESC,
  CREATED_ASC,
} from '~/work_items/list/constants';
import {
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_STATUS,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_LINKED_ITEMS,
} from '~/work_items/constants';
import { getSortValue as getSortValueCE } from '~/work_items/utils';
import { namespaceWorkItemTypesQueryResponse } from 'jest/work_items/mock_data';

describe('getDefaultStateType', () => {
  const mockLifecycle = {
    defaultClosedStatus: { id: 'closed-id' },
    defaultDuplicateStatus: { id: 'duplicate-id' },
    defaultOpenStatus: { id: 'open-id' },
  };

  it('returns DEFAULT_STATE_CLOSED if status matches defaultClosedStatus', () => {
    const status = { id: 'closed-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('closed');
  });

  it('returns DEFAULT_STATE_DUPLICATE if status matches defaultDuplicateStatus', () => {
    const status = { id: 'duplicate-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('duplicate');
  });

  it('returns DEFAULT_STATE_OPEN if status matches defaultOpenStatus', () => {
    const status = { id: 'open-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBe('open');
  });

  it('returns null if status does not match any default status', () => {
    const status = { id: 'some-other-id' };
    expect(getDefaultStateType(mockLifecycle, status)).toBeNull();
  });
});

describe('sortStatuses', () => {
  it('sorts, and deduplicates statuses', () => {
    const statuses = [
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
        category: 'to_do',
        name: 'To do',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/2',
        category: 'in_progress',
        name: 'In progress',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/3',
        category: 'done',
        name: 'Done',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/4',
        category: 'canceled',
        name: "Won't do",
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/5',
        category: 'canceled',
        name: 'Duplicate',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
        category: 'to_do',
        name: 'To do',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/7',
        category: 'in_progress',
        name: 'In dev',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/8',
        category: 'in_progress',
        name: 'In review',
      },
      {
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/9',
        category: 'done',
        name: 'Complete',
      },
    ];

    expect(sortStatuses(statuses)).toEqual([
      expect.objectContaining({ name: 'To do' }),
      expect.objectContaining({ name: 'In progress' }),
      expect.objectContaining({ name: 'In dev' }),
      expect.objectContaining({ name: 'In review' }),
      expect.objectContaining({ name: 'Done' }),
      expect.objectContaining({ name: 'Complete' }),
      expect.objectContaining({ name: "Won't do" }),
      expect.objectContaining({ name: 'Duplicate' }),
    ]);
  });
});

describe('getStatuses', () => {
  it('merges, sorts, and deduplicates statuses', () => {
    expect(
      getStatuses(namespaceWorkItemTypesQueryResponse.data.namespace.workItemTypes.nodes),
    ).toEqual([
      expect.objectContaining({ name: 'To do' }),
      expect.objectContaining({ name: 'In progress' }),
      expect.objectContaining({ name: 'In dev' }),
      expect.objectContaining({ name: 'In review' }),
      expect.objectContaining({ name: 'Done' }),
      expect.objectContaining({ name: 'Complete' }),
      expect.objectContaining({ name: "Won't do" }),
      expect.objectContaining({ name: 'Duplicate' }),
    ]);
  });
});

describe('getSortValueEE', () => {
  it.each`
    sortKey                 | item                                                                                | expectedValue
    ${WEIGHT_ASC}           | ${{ widgets: [{ type: WIDGET_TYPE_WEIGHT, weight: 5 }] }}                           | ${5}
    ${WEIGHT_DESC}          | ${{ widgets: [{ type: WIDGET_TYPE_WEIGHT, weight: 5 }] }}                           | ${5}
    ${STATUS_ASC}           | ${{ widgets: [{ type: WIDGET_TYPE_STATUS, status: { category: 'in_progress' } }] }} | ${STATUS_CATEGORY_VALUE_MAP.in_progress}
    ${STATUS_DESC}          | ${{ widgets: [{ type: WIDGET_TYPE_STATUS, status: { category: 'in_progress' } }] }} | ${STATUS_CATEGORY_VALUE_MAP.in_progress}
    ${HEALTH_STATUS_ASC}    | ${{ widgets: [{ type: WIDGET_TYPE_HEALTH_STATUS, healthStatus: 'onTrack' }] }}      | ${HEALTH_STATUS_VALUE_MAP.onTrack}
    ${HEALTH_STATUS_DESC}   | ${{ widgets: [{ type: WIDGET_TYPE_HEALTH_STATUS, healthStatus: 'onTrack' }] }}      | ${HEALTH_STATUS_VALUE_MAP.onTrack}
    ${BLOCKING_ISSUES_ASC}  | ${{ widgets: [{ type: WIDGET_TYPE_LINKED_ITEMS, blockingCount: 3 }] }}              | ${3}
    ${BLOCKING_ISSUES_DESC} | ${{ widgets: [{ type: WIDGET_TYPE_LINKED_ITEMS, blockingCount: 3 }] }}              | ${3}
  `('returns expected value for $sortKey', ({ sortKey, item, expectedValue }) => {
    expect(getSortValueEE(item, sortKey)).toBe(expectedValue);
  });

  it.each`
    sortKey                | item                                                       | description
    ${WEIGHT_ASC}          | ${{ widgets: [] }}                                         | ${'weight widget is missing'}
    ${STATUS_ASC}          | ${{ widgets: [] }}                                         | ${'status widget is missing'}
    ${STATUS_ASC}          | ${{ widgets: [{ type: WIDGET_TYPE_STATUS, status: {} }] }} | ${'status category is missing'}
    ${HEALTH_STATUS_ASC}   | ${{ widgets: [] }}                                         | ${'health status widget is missing'}
    ${HEALTH_STATUS_ASC}   | ${{ widgets: [{ type: WIDGET_TYPE_HEALTH_STATUS }] }}      | ${'health status value is missing'}
    ${BLOCKING_ISSUES_ASC} | ${{ widgets: [] }}                                         | ${'linked items widget is missing'}
  `('returns null when $description', ({ sortKey, item }) => {
    expect(getSortValueEE(item, sortKey)).toBeNull();
  });

  it('falls back to CE getSortValue for unsupported sort keys', () => {
    const item = { createdAt: '2024-01-01T00:00:00Z' };

    expect(getSortValueEE(item, CREATED_ASC)).toEqual(getSortValueCE(item, CREATED_ASC));
  });
});

describe('getSortedWorkItems (EE)', () => {
  it('sorts work items by weight ascending and keeps nulls last', () => {
    const items = [
      { id: 1, widgets: [{ type: WIDGET_TYPE_WEIGHT, weight: null }] },
      { id: 2, widgets: [{ type: WIDGET_TYPE_WEIGHT, weight: 5 }] },
      { id: 3, widgets: [{ type: WIDGET_TYPE_WEIGHT, weight: 1 }] },
      { id: 4, widgets: [] },
    ];

    const sorted = getSortedWorkItems(items, WEIGHT_ASC);

    expect(sorted.map(({ id }) => id)).toEqual([3, 2, 1, 4]);
  });
});
