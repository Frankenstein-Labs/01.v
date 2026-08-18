import { STATUS_CATEGORIES_MAP } from 'ee/work_items/constants';
import { STATE_CLOSED } from '~/work_items/constants';
import {
  getSelectedStatus,
  getNewStatusOptionsFromTheSameState,
  getDefaultStatusMapping,
} from 'ee/groups/settings/work_items/custom_status/utils';

describe('Utils Functions', () => {
  // Mock data
  const mockCurrentLifecycleStatuses = [
    {
      id: 'current-status-1',
      name: 'Current To Do',
      category: 'to_do',
      iconName: 'status-waiting',
      color: '#737278',
    },
    {
      id: 'current-status-2',
      name: 'Current Done',
      category: 'done',
      iconName: 'status-success',
      color: '#108548',
    },
  ];

  const mockNewLifecycleStatuses = [
    {
      id: 'new-status-1',
      name: 'New To Do',
      category: 'to_do',
      iconName: 'status-waiting',
      color: '#737278',
    },
    {
      id: 'new-status-2',
      name: 'New In Progress',
      category: 'in_progress',
      iconName: 'status-running',
      color: '#1f75cb',
    },
    {
      id: 'new-status-3',
      name: 'New Done',
      category: 'done',
      iconName: 'status-success',
      color: '#108548',
    },
    {
      id: 'new-status-4',
      name: 'New Canceled',
      category: 'canceled',
      iconName: 'status-cancelled',
      color: '#DD2B0E',
    },
  ];

  describe('getSelectedStatus', () => {
    const currentStatus = {
      id: 'current-1',
      name: 'Current Status',
      category: 'to_do',
    };

    it('returns the same status if it exists in new options', () => {
      const newStatusOptions = [
        { id: 'other-1', name: 'Other', category: 'done' },
        { id: 'current-1', name: 'Current Status', category: 'to_do' },
      ];

      const result = getSelectedStatus(currentStatus, newStatusOptions);

      expect(result).toEqual(currentStatus);
    });

    it('returns status from same category when exact match is not found', () => {
      const newStatusOptions = [
        { id: 'different-1', name: 'Different To Do', category: 'to_do' },
        { id: 'done-1', name: 'Done Status', category: 'done' },
      ];

      const result = getSelectedStatus(currentStatus, newStatusOptions);

      expect(result).toEqual(newStatusOptions[0]);
      expect(result.category).toBe(currentStatus.category);
    });

    it('returns first status when no same category status exists', () => {
      const newStatusOptions = [
        { id: 'done-1', name: 'Done Status', category: 'done' },
        { id: 'progress-1', name: 'In Progress', category: 'in_progress' },
      ];

      const result = getSelectedStatus(currentStatus, newStatusOptions);

      expect(result).toEqual(newStatusOptions[0]);
    });

    it('returns undefined when new status options array is empty', () => {
      const result = getSelectedStatus(currentStatus, []);

      expect(result).toBeUndefined();
    });

    it('handles multiple statuses in same category and returns first one', () => {
      const newStatusOptions = [
        { id: 'todo-1', name: 'First To Do', category: 'to_do' },
        { id: 'todo-2', name: 'Second To Do', category: 'to_do' },
        { id: 'done-1', name: 'Done Status', category: 'done' },
      ];

      const result = getSelectedStatus(currentStatus, newStatusOptions);

      expect(result).toEqual(newStatusOptions[0]);
    });
  });

  describe('getNewStatusOptionsFromTheSameState', () => {
    it('filters statuses by same work item state for open statuses', () => {
      const currentStatus = {
        id: 'current-1',
        name: 'Current To Do',
        category: 'to_do',
      };

      const result = getNewStatusOptionsFromTheSameState(currentStatus, mockNewLifecycleStatuses);

      // to_do, in_progress, and triage all have workItemState 'open'
      const expectedStatuses = mockNewLifecycleStatuses.filter((status) =>
        ['to_do', 'in_progress', 'triage'].includes(status.category),
      );

      expect(result).toHaveLength(2); // to_do and in_progress
      expect(result).toEqual(expectedStatuses);
    });

    it('filters statuses by same work item state for closed statuses', () => {
      const doneStatus = {
        id: 'done-1',
        name: 'Done Status',
        category: 'done',
      };

      const result = getNewStatusOptionsFromTheSameState(doneStatus, mockNewLifecycleStatuses);

      // done and canceled both have workItemState 'closed'
      expect(result).toHaveLength(2);
      expect(
        result.every(
          (status) =>
            STATUS_CATEGORIES_MAP[status.category.toUpperCase()]?.workItemState === STATE_CLOSED,
        ),
      ).toBe(true);
    });

    it('handles unknown category gracefully', () => {
      const unknownStatus = {
        id: 'unknown-1',
        name: 'Unknown Status',
        category: 'unknown_category',
      };

      const result = getNewStatusOptionsFromTheSameState(unknownStatus, mockNewLifecycleStatuses);

      expect(result).toEqual([]);
    });

    it('handles case insensitive category matching', () => {
      const lowercaseStatus = {
        id: 'lowercase-1',
        name: 'Lowercase Status',
        category: 'to_do', // lowercase
      };

      const result = getNewStatusOptionsFromTheSameState(lowercaseStatus, mockNewLifecycleStatuses);

      expect(result).toHaveLength(2);
    });

    it('returns empty array when no matching states found', () => {
      const customStatus = {
        id: 'custom-1',
        name: 'Custom Status',
        category: 'custom_category',
      };

      const result = getNewStatusOptionsFromTheSameState(customStatus, mockNewLifecycleStatuses);

      expect(result).toEqual([]);
    });

    it('returns all statuses when current status category is not in STATUS_CATEGORIES_MAP', () => {
      const unmappedStatus = {
        id: 'unmapped-1',
        name: 'Unmapped Status',
        category: 'unmapped',
      };

      const result = getNewStatusOptionsFromTheSameState(unmappedStatus, mockNewLifecycleStatuses);

      // When currentStatusState is undefined, filter will return statuses where statusState is also undefined
      expect(result).toEqual([]);
    });
  });

  describe('getDefaultStatusMapping', () => {
    it('creates correct status mappings between lifecycles', () => {
      const result = getDefaultStatusMapping(
        mockCurrentLifecycleStatuses,
        mockNewLifecycleStatuses,
      );

      expect(result).toHaveLength(mockCurrentLifecycleStatuses.length);

      // Check structure of mappings
      result.forEach((mapping) => {
        expect(mapping).toHaveProperty('oldStatusId');
        expect(mapping).toHaveProperty('newStatusId');
      });

      // First status (to_do) should map to new to_do status
      expect(result[0].oldStatusId).toBe('current-status-1');
      expect(result[0].newStatusId).toBe('new-status-1');

      // Second status (done) should map to new done status
      expect(result[1].oldStatusId).toBe('current-status-2');
      expect(result[1].newStatusId).toBe('new-status-3');
    });

    it('handles empty current lifecycle statuses', () => {
      const result = getDefaultStatusMapping([], mockNewLifecycleStatuses);

      expect(result).toEqual([]);
    });

    it('creates mappings for statuses with different categories', () => {
      const mixedCurrentStatuses = [
        {
          id: 'triage-1',
          name: 'Triage Status',
          category: 'triage',
        },
        {
          id: 'canceled-1',
          name: 'Canceled Status',
          category: 'canceled',
        },
      ];

      const result = getDefaultStatusMapping(mixedCurrentStatuses, mockNewLifecycleStatuses);

      expect(result).toHaveLength(2);

      // Triage (open state) should map to an open state status
      const triageMapping = result.find((m) => m.oldStatusId === 'triage-1');
      expect(triageMapping.newStatusId).toBe('new-status-1');

      // Canceled (closed state) should map to a closed state status
      const canceledMapping = result.find((m) => m.oldStatusId === 'canceled-1');
      expect(canceledMapping.newStatusId).toBe('new-status-4'); // New Canceled
    });
  });
});
