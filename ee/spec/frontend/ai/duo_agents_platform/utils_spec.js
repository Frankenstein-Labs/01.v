// eslint-disable-next-line no-restricted-imports
import { s__, sprintf } from '~/locale';
import { humanize } from '~/lib/utils/text_utility';
import {
  denormalizeMergeRequestEventTypes,
  eventTypeIntsToValues,
  eventTypeValuesToInts,
  formatAgentDefinition,
  formatAgentFlowName,
  formatAgentFlowTitle,
  formatAgentFlowTitleWithId,
  formatAgentStatus,
  formatDate,
  getMessageData,
  getNamespaceDatasetProperties,
  flowTriggerModeFor,
  getEnabledFlowTriggerTypes,
  getNumericId,
  isScheduleConfigValid,
  mergeRequestActionLabels,
  toFlowTriggerTypeOption,
  normalizeMergeRequestEventTypes,
  parseFilterRuleValues,
  parseMergeRequestActionFilter,
  parsePipelineStatusFilter,
  parseScheduleConfig,
  parseWorkItemActionFilter,
  pipelineStatusLabels,
  randomizeScheduleDefaults,
  workItemActionLabels,
} from 'ee/ai/duo_agents_platform/utils';
import {
  FLOW_TRIGGER_MODE_EVENT,
  FLOW_TRIGGER_MODE_SCHEDULE,
  FLOW_TRIGGER_TYPES,
  MESSAGE_SUB_TYPE_DELEGATION,
  MESSAGE_SUB_TYPE_DELEGATION_RETURNS,
  SCHEDULE_FREQUENCY_EVERY_15_MINUTES,
  SCHEDULE_FREQUENCY_HOURLY,
  SCHEDULE_FREQUENCY_DAILY,
  SCHEDULE_FREQUENCY_WEEKDAYS,
  SCHEDULE_FREQUENCY_WEEKLY,
  SCHEDULE_FREQUENCY_MONTHLY,
} from 'ee/ai/duo_agents_platform/constants';

// Mock the dependencies
jest.mock('~/locale');
jest.mock('~/lib/utils/text_utility');
jest.mock('~/lib/utils/axios_utils', () => ({
  __esModule: true,
  default: {
    patch: jest.fn(),
  },
}));
jest.mock('~/lib/utils/datetime/locale_dateformat', () => ({
  localeDateFormat: {
    asDate: {
      format: jest.fn((date) => {
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
      }),
    },
  },
}));
jest.mock('~/api/api_utils', () => ({
  buildApiUrl: (url) => url.replace(':version', 'v4'),
}));

describe('duo_agents_platform utils', () => {
  describe('formatAgentDefinition', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent flow');
      humanize.mockImplementation((str) => str.replace(/_/g, ' '));
    });

    describe('when an agent definition is provided', () => {
      beforeEach(() => {
        formatAgentDefinition('software_development');
      });

      it('humanizes the provided definition', () => {
        expect(humanize).toHaveBeenCalledWith('software_development');
      });
    });

    describe('when the agent definition is undefined', () => {
      beforeEach(() => {
        formatAgentDefinition();
      });

      it('humanizes the default fallback text', () => {
        expect(humanize).toHaveBeenCalledWith('Agent flow');
      });
    });
  });

  describe('formatAgentFlowTitle', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent session');
      humanize.mockImplementation((str) => str.replace(/_/g, ' '));
    });

    it('returns the title when provided', () => {
      expect(formatAgentFlowTitle('My custom title', 'software_development')).toBe(
        'My custom title',
      );
    });

    it.each([null, undefined, ''])(
      'falls back to the formatted agent definition when title is %p',
      (title) => {
        expect(formatAgentFlowTitle(title, 'software_development')).toBe('software development');
      },
    );

    it('falls back to the default agent session label when both title and definition are absent', () => {
      expect(formatAgentFlowTitle(null, null)).toBe('Agent session');
    });
  });

  describe('formatAgentFlowTitleWithId', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent session');
      humanize.mockImplementation((str) => str.replace(/_/g, ' '));
    });

    it('returns the title when provided', () => {
      expect(formatAgentFlowTitleWithId('My custom title', 'software_development', 42)).toBe(
        'My custom title',
      );
    });

    it.each([null, undefined, ''])(
      'falls back to the formatted agent flow name when title is %p',
      (title) => {
        expect(formatAgentFlowTitleWithId(title, 'software_development', 42)).toBe(
          'software development #42',
        );
      },
    );

    it('falls back to the default agent session label when title and definition are absent', () => {
      expect(formatAgentFlowTitleWithId(null, null, 42)).toBe('Agent session #42');
    });
  });

  describe('formatAgentFlowName', () => {
    beforeEach(() => {
      s__.mockReturnValue('Agent flow');
    });

    it('formats agent flow name with definition and id', () => {
      const agentDefinition = 'software_development';
      const id = 123;

      const results = formatAgentFlowName(agentDefinition, id);

      expect(humanize).toHaveBeenCalledWith('software_development');
      expect(results).toBe('software development #123');
    });

    it('formats agent flow name with default definition when null', () => {
      const id = 456;

      const result = formatAgentFlowName(null, id);

      expect(result).toBe('Agent flow #456');
    });

    it('formats agent flow name with string id', () => {
      const agentDefinition = 'convert_to_ci';
      const id = '789';

      const result = formatAgentFlowName(agentDefinition, id);

      expect(result).toBe('convert to ci #789');
    });
  });

  describe('formatAgentStatus', () => {
    beforeEach(() => {
      s__.mockReturnValue('Unknown');
      humanize.mockImplementation((str) => str.charAt(0).toUpperCase() + str.slice(1));
    });

    describe('when status is a non-empty string', () => {
      it.each([
        ['RUNNING', 'running', 'Running'],
        ['COMPLETED', 'completed', 'Completed'],
        ['Failed', 'failed', 'Failed'],
      ])('humanizes %p as %p', (input, humanizeArg, expected) => {
        const result = formatAgentStatus(input);

        expect(humanize).toHaveBeenCalledWith(humanizeArg);
        expect(result).toBe(expected);
      });
    });

    describe('when status is falsy', () => {
      it.each([null, undefined, ''])('returns the default text for %p', (input) => {
        const result = formatAgentStatus(input);

        expect(s__).toHaveBeenCalledWith('DuoAgentsPlatform|Unknown');
        expect(result).toBe('Unknown');
      });
    });
  });

  describe('getNamespaceDatasetProperties', () => {
    it('returns object with specified properties from dataset', () => {
      const dataset = {
        prop1: 'value1',
        prop2: 'value2',
        prop3: 'value3',
        unwanted: 'unwanted',
      };
      const properties = ['prop1', 'prop3'];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({
        prop1: 'value1',
        prop3: 'value3',
      });
    });

    it('returns empty object when no properties specified', () => {
      const dataset = { prop1: 'value1' };
      const properties = [];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({});
    });

    it('handles undefined properties in dataset', () => {
      const dataset = { prop1: 'value1' };
      const properties = ['prop1', 'nonexistent'];

      const result = getNamespaceDatasetProperties(dataset, properties);

      expect(result).toEqual({
        prop1: 'value1',
        nonexistent: undefined,
      });
    });
  });

  describe('getMessageData', () => {
    beforeEach(() => {
      // Strip the namespace prefix the way the real s__ does, so test
      // assertions can use the plain English title.
      s__.mockImplementation((str) => str.split('|').pop());
    });

    it.each([
      ['user', { icon: 'user', title: 'User messaged agent', level: 1 }],
      ['request', { icon: 'question-o', title: 'Agent required human input', level: 1 }],
      ['unknown', { icon: 'work-item-maintenance', title: 'Action', level: 0 }],
    ])('returns correct data for %s message type', (messageType, expected) => {
      const message = { messageType };

      const result = getMessageData(message);

      expect(result).toEqual(expected);
    });

    it('returns default agent reasoning data for agent message type with no sub-type', () => {
      expect(getMessageData({ messageType: 'agent' })).toEqual({
        icon: 'tanuki-ai',
        title: 'Agent reasoning',
        level: 0,
      });
    });

    it('returns delegated-to-subagent data for delegation sub-type', () => {
      expect(
        getMessageData({ messageType: 'tool', messageSubType: MESSAGE_SUB_TYPE_DELEGATION }),
      ).toEqual({
        icon: 'arrow-down',
        title: 'Delegated to subagent',
        level: 1,
      });
    });

    it('returns returned-to-agent data for delegation_returns success', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: MESSAGE_SUB_TYPE_DELEGATION_RETURNS,
          status: 'success',
        }),
      ).toEqual({
        icon: 'arrow-up',
        title: 'Returned to agent',
        level: 1,
      });
    });

    it('returns failure data for delegation_returns failure', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: MESSAGE_SUB_TYPE_DELEGATION_RETURNS,
          status: 'failure',
        }),
      ).toEqual({
        icon: 'error',
        title: 'Subagent did not produce an answer',
        level: 1,
      });
    });

    it('returns returned-to-agent data for delegation_returns without known status', () => {
      expect(
        getMessageData({
          messageType: 'tool',
          messageSubType: MESSAGE_SUB_TYPE_DELEGATION_RETURNS,
          status: 'running',
        }),
      ).toEqual({
        icon: 'arrow-up',
        title: 'Returned to agent',
        level: 1,
      });
    });

    it('returns tool data for tool message type', () => {
      const message = {
        messageType: 'tool',
        toolInfo: { name: 'read_file' },
      };

      const result = getMessageData(message);

      expect(result).toEqual({
        icon: 'eye',
        title: 'Read file',
        level: 0,
      });
    });

    it.each([
      [{}, "Message requires property 'message_type' but got {}"],
      [
        { messageType: null },
        'Message requires property \'message_type\' but got {"messageType":null}',
      ],
    ])('throws error when messageType is invalid: %p', (message, expectedError) => {
      expect(() => getMessageData(message)).toThrow(expectedError);
    });
  });

  describe('getNumericId', () => {
    it.each([null, undefined, ''])('returns null for %p', (input) => {
      expect(getNumericId(input)).toBeNull();
    });

    it('extracts numeric id from a GraphQL global ID', () => {
      expect(getNumericId('gid://gitlab/User/42')).toBe(42);
    });

    it('returns the value as-is when it is not a GID', () => {
      expect(getNumericId('99')).toBe('99');
    });
  });

  describe('formatDate', () => {
    it('formats a valid ISO date string', () => {
      const result = formatDate('2024-01-01T00:00:00Z');

      expect(result).toBe('Jan 1, 2024');
    });

    it.each([null, undefined, ''])('returns empty string for %p', (input) => {
      expect(formatDate(input)).toBe('');
    });
  });

  describe('parseFilterRuleValues', () => {
    const SCOPE = 'test_scope';
    const FIELD = 'test_field';
    const OPTIONS = [
      { text: 'Foo', value: 'foo' },
      { text: 'Bar', value: 'bar' },
    ];
    const buildFilter = (rules) => ({ test_scope: { rules } });

    it.each`
      name                             | input
      ${'undefined filter'}            | ${undefined}
      ${'empty filter'}                | ${{}}
      ${'scope present, no rules key'} | ${{ test_scope: {} }}
      ${'empty rules array'}           | ${buildFilter([])}
      ${'multiple rules'}              | ${buildFilter([{ field: FIELD, operator: 'in', value: ['foo'] }, { field: FIELD, operator: 'in', value: ['bar'] }])}
      ${'non-array rules'}             | ${{ test_scope: { rules: 'not an array' } }}
      ${'unsupported operator'}        | ${buildFilter([{ field: FIELD, operator: 'eq', value: ['foo'] }])}
      ${'unsupported field'}           | ${buildFilter([{ field: 'other_field', operator: 'in', value: ['foo'] }])}
      ${'non-array value'}             | ${buildFilter([{ field: FIELD, operator: 'in', value: 'foo' }])}
    `('returns [] for $name', ({ input }) => {
      expect(
        parseFilterRuleValues({ filter: input, scope: SCOPE, field: FIELD, options: OPTIONS }),
      ).toEqual([]);
    });

    it('returns known values from a single valid rule', () => {
      const filter = buildFilter([{ field: FIELD, operator: 'in', value: ['foo', 'bar'] }]);

      expect(
        parseFilterRuleValues({ filter, scope: SCOPE, field: FIELD, options: OPTIONS }),
      ).toEqual(['foo', 'bar']);
    });

    it('drops values outside the known option set', () => {
      const filter = buildFilter([{ field: FIELD, operator: 'in', value: ['foo', 'unknown'] }]);

      expect(
        parseFilterRuleValues({ filter, scope: SCOPE, field: FIELD, options: OPTIONS }),
      ).toEqual(['foo']);
    });
  });

  describe('parsePipelineStatusFilter', () => {
    const buildFilter = (rules) => ({ pipeline_hooks: { rules } });

    it('returns the known status values for a single representable rule', () => {
      const filter = buildFilter([
        { field: 'object_attributes.status', operator: 'in', value: ['failed', 'success'] },
      ]);

      expect(parsePipelineStatusFilter(filter)).toEqual(['failed', 'success']);
    });

    it('drops unknown status values from the rule', () => {
      const filter = buildFilter([
        {
          field: 'object_attributes.status',
          operator: 'in',
          value: ['failed', 'something_unknown'],
        },
      ]);

      expect(parsePipelineStatusFilter(filter)).toEqual(['failed']);
    });
  });

  describe('pipelineStatusLabels', () => {
    it('returns one label per configured status', () => {
      const filter = {
        pipeline_hooks: {
          rules: [
            { field: 'object_attributes.status', operator: 'in', value: ['failed', 'canceled'] },
          ],
        },
      };

      expect(pipelineStatusLabels(filter)).toHaveLength(2);
    });

    it('returns [] when filter is empty', () => {
      expect(pipelineStatusLabels({})).toEqual([]);
    });

    it('returns [] when the filter shape is not supported by the field', () => {
      const filter = {
        pipeline_hooks: {
          rules: [{ field: 'object_attributes.status', operator: 'eq', value: 'failed' }],
        },
      };

      expect(pipelineStatusLabels(filter)).toEqual([]);
    });
  });

  describe('parseMergeRequestActionFilter', () => {
    const buildFilter = (rules) => ({ merge_request: { rules } });

    it.each`
      name                             | input
      ${'undefined filter'}            | ${undefined}
      ${'empty filter'}                | ${{}}
      ${'scope present, no rules key'} | ${{ merge_request: {} }}
      ${'empty rules array'}           | ${buildFilter([])}
      ${'non-array rules'}             | ${{ merge_request: { rules: 'not an array' } }}
      ${'unsupported field'}           | ${buildFilter([{ field: 'something.else', operator: 'in', value: ['ready'] }])}
      ${'unsupported operator'}        | ${buildFilter([{ field: 'action', operator: 'eq', value: 'ready' }])}
      ${'in with non-array value'}     | ${buildFilter([{ field: 'action', operator: 'in', value: 'ready' }])}
      ${'multiple rules'}              | ${buildFilter([{ field: 'action', operator: 'in', value: ['ready'] }, { field: 'action', operator: 'in', value: ['approved'] }])}
    `('returns [] for $name', ({ input }) => {
      expect(parseMergeRequestActionFilter(input)).toEqual([]);
    });

    it('returns all actions for an in array rule', () => {
      expect(
        parseMergeRequestActionFilter(
          buildFilter([{ field: 'action', operator: 'in', value: ['ready', 'approved'] }]),
        ),
      ).toEqual(['ready', 'approved']);
    });

    it('returns a single action for an in rule with a one-element array', () => {
      expect(
        parseMergeRequestActionFilter(
          buildFilter([{ field: 'action', operator: 'in', value: ['approved'] }]),
        ),
      ).toEqual(['approved']);
    });

    it('returns the merged action', () => {
      expect(
        parseMergeRequestActionFilter(
          buildFilter([{ field: 'action', operator: 'in', value: ['merged'] }]),
        ),
      ).toEqual(['merged']);
    });

    it('drops unknown action values from the rule', () => {
      expect(
        parseMergeRequestActionFilter(
          buildFilter([{ field: 'action', operator: 'in', value: ['ready', 'something_unknown'] }]),
        ),
      ).toEqual(['ready']);
    });
  });

  describe('mergeRequestActionLabels', () => {
    it('returns one label per configured action', () => {
      const filter = {
        merge_request: {
          rules: [{ field: 'action', operator: 'in', value: ['ready', 'approved'] }],
        },
      };

      expect(mergeRequestActionLabels(filter)).toHaveLength(2);
    });

    it('returns [] when filter is empty', () => {
      expect(mergeRequestActionLabels({})).toEqual([]);
    });

    it('returns [] when the filter shape is not supported by the field', () => {
      const filter = {
        merge_request: { rules: [{ field: 'unknown', operator: 'in', value: ['ready'] }] },
      };

      expect(mergeRequestActionLabels(filter)).toEqual([]);
    });
  });

  describe('parseWorkItemActionFilter', () => {
    const buildFilter = (rules) => ({ work_item: { rules } });

    it('returns the created action when present', () => {
      const filter = buildFilter([{ field: 'action', operator: 'in', value: ['created'] }]);

      expect(parseWorkItemActionFilter(filter)).toEqual(['created']);
    });

    it('returns the status_changed action when present', () => {
      const filter = buildFilter([{ field: 'action', operator: 'in', value: ['status_changed'] }]);

      expect(parseWorkItemActionFilter(filter)).toEqual(['status_changed']);
    });

    it('drops values outside the known action set', () => {
      const filter = buildFilter([
        { field: 'action', operator: 'in', value: ['created', 'bogus'] },
      ]);

      expect(parseWorkItemActionFilter(filter)).toEqual(['created']);
    });
  });

  describe('workItemActionLabels', () => {
    it('returns one label per configured action', () => {
      const filter = {
        work_item: { rules: [{ field: 'action', operator: 'in', value: ['created'] }] },
      };

      expect(workItemActionLabels(filter)).toHaveLength(1);
    });

    it('returns [] when filter is empty', () => {
      expect(workItemActionLabels({})).toEqual([]);
    });

    it('returns [] when the filter shape is not supported by the field', () => {
      const filter = {
        work_item: { rules: [{ field: 'unknown', operator: 'in', value: ['created'] }] },
      };

      expect(workItemActionLabels(filter)).toEqual([]);
    });
  });

  describe('normalizeMergeRequestEventTypes', () => {
    it('returns input untouched when event_types is missing', () => {
      const result = normalizeMergeRequestEventTypes({ eventTypes: undefined, filter: undefined });

      expect(result).toEqual({ eventTypes: undefined, filter: {} });
    });

    it('returns input untouched when no merge_request_ready event type is present', () => {
      const input = { eventTypes: [0, 1], filter: { pipeline_hooks: {} } };

      expect(normalizeMergeRequestEventTypes(input)).toEqual({
        eventTypes: [0, 1],
        filter: { pipeline_hooks: {} },
      });
    });

    it('converts a merge_request_ready event type into merge_request with a ready action filter', () => {
      const result = normalizeMergeRequestEventTypes({ eventTypes: [0, 4], filter: {} });

      expect(result).toEqual({
        eventTypes: [0, 6],
        filter: {
          merge_request: { rules: [{ field: 'action', operator: 'in', value: ['ready'] }] },
        },
      });
    });

    it('combines a merge_request_ready event type with an existing approved merge_request filter', () => {
      const result = normalizeMergeRequestEventTypes({
        eventTypes: [4, 6],
        filter: {
          merge_request: { rules: [{ field: 'action', operator: 'in', value: ['approved'] }] },
        },
      });

      expect(result.eventTypes).toEqual([6]);
      expect(result.filter.merge_request).toEqual({
        rules: [{ field: 'action', operator: 'in', value: ['approved', 'ready'] }],
      });
    });

    it('is a no-op when ready is already in the existing action filter', () => {
      const result = normalizeMergeRequestEventTypes({
        eventTypes: [4, 6],
        filter: {
          merge_request: { rules: [{ field: 'action', operator: 'in', value: ['ready'] }] },
        },
      });

      expect(result.eventTypes).toEqual([6]);
      expect(result.filter.merge_request).toEqual({
        rules: [{ field: 'action', operator: 'in', value: ['ready'] }],
      });
    });

    it('converts a merge_request_code_conflict event type into merge_request with a code_conflict action filter', () => {
      const result = normalizeMergeRequestEventTypes({ eventTypes: [0, 5], filter: {} });

      expect(result).toEqual({
        eventTypes: [0, 6],
        filter: {
          merge_request: { rules: [{ field: 'action', operator: 'in', value: ['code_conflict'] }] },
        },
      });
    });

    it('folds both ready and code_conflict event types into a single merge_request filter', () => {
      const result = normalizeMergeRequestEventTypes({ eventTypes: [4, 5], filter: {} });

      expect(result.eventTypes).toEqual([6]);
      expect(result.filter.merge_request).toEqual({
        rules: [{ field: 'action', operator: 'in', value: ['code_conflict', 'ready'] }],
      });
    });

    it('does not mutate the input event_types array', () => {
      const eventTypes = [4];
      normalizeMergeRequestEventTypes({ eventTypes, filter: {} });

      expect(eventTypes).toEqual([4]);
    });
  });

  describe('denormalizeMergeRequestEventTypes', () => {
    const readyFilter = {
      merge_request: { rules: [{ field: 'action', operator: 'in', value: ['ready'] }] },
    };
    const readyApprovedFilter = {
      merge_request: { rules: [{ field: 'action', operator: 'in', value: ['ready', 'approved'] }] },
    };
    const approvedFilter = {
      merge_request: { rules: [{ field: 'action', operator: 'in', value: ['approved'] }] },
    };
    const codeConflictFilter = {
      merge_request: { rules: [{ field: 'action', operator: 'in', value: ['code_conflict'] }] },
    };

    it('returns input untouched when there is no merge_request action filter', () => {
      const result = denormalizeMergeRequestEventTypes({ eventTypes: [0, 1], filter: {} });

      expect(result).toEqual({ eventTypes: [0, 1], filter: {} });
    });

    it('folds a ready action back to event_type 4', () => {
      const result = denormalizeMergeRequestEventTypes({ eventTypes: [6], filter: readyFilter });

      expect(result).toEqual({ eventTypes: [4], filter: {} });
    });

    it('leaves a merged action under event_type 6', () => {
      const mergedFilter = {
        merge_request: { rules: [{ field: 'action', operator: 'in', value: ['merged'] }] },
      };
      const result = denormalizeMergeRequestEventTypes({ eventTypes: [6], filter: mergedFilter });

      expect(result).toEqual({ eventTypes: [6], filter: mergedFilter });
    });

    it('folds a code_conflict action back to event_type 5', () => {
      const result = denormalizeMergeRequestEventTypes({
        eventTypes: [6],
        filter: codeConflictFilter,
      });

      expect(result).toEqual({ eventTypes: [5], filter: {} });
    });

    it('folds both ready and code_conflict back to their own event types', () => {
      const result = denormalizeMergeRequestEventTypes({
        eventTypes: [6],
        filter: {
          merge_request: {
            rules: [{ field: 'action', operator: 'in', value: ['ready', 'code_conflict'] }],
          },
        },
      });

      expect(result.eventTypes.sort()).toEqual([4, 5]);
      expect(result.filter).toEqual({});
    });

    it('keeps approved under event_type 6 while folding ready back to 4', () => {
      const result = denormalizeMergeRequestEventTypes({
        eventTypes: [6],
        filter: readyApprovedFilter,
      });

      expect(result.eventTypes.sort()).toEqual([4, 6]);
      expect(result.filter).toEqual(approvedFilter);
    });

    it('leaves an approved-only trigger on event_type 6', () => {
      const result = denormalizeMergeRequestEventTypes({ eventTypes: [6], filter: approvedFilter });

      expect(result).toEqual({ eventTypes: [6], filter: approvedFilter });
    });
  });

  describe('eventTypeValuesToInts', () => {
    it('maps known string values to their numeric ids', () => {
      expect(
        eventTypeValuesToInts(['mention', 'merge_request', 'merge_request_code_conflict']),
      ).toEqual([0, 6, 5]);
    });

    it('drops unknown values', () => {
      expect(eventTypeValuesToInts(['mention', 'not_a_type'])).toEqual([0]);
    });

    it('returns an empty array by default', () => {
      expect(eventTypeValuesToInts()).toEqual([]);
    });
  });

  describe('eventTypeIntsToValues', () => {
    it('maps numeric ids back to their string values, including foldable actions', () => {
      expect(eventTypeIntsToValues([0, 6, 4, 5])).toEqual([
        'mention',
        'merge_request',
        'merge_request_ready',
        'merge_request_code_conflict',
      ]);
    });

    it('drops unknown ids', () => {
      expect(eventTypeIntsToValues([0, 99])).toEqual(['mention']);
    });

    it('returns an empty array by default', () => {
      expect(eventTypeIntsToValues()).toEqual([]);
    });

    it('round-trips with eventTypeValuesToInts', () => {
      const values = ['mention', 'assign', 'merge_request', 'merge_request_ready'];

      expect(eventTypeIntsToValues(eventTypeValuesToInts(values))).toEqual(values);
    });
  });

  describe('parseScheduleConfig', () => {
    it('returns the schedule object stored under the schedule scope', () => {
      const schedule = { frequency: SCHEDULE_FREQUENCY_DAILY, minute: 15, hour: 9 };

      expect(parseScheduleConfig({ schedule })).toBe(schedule);
    });

    it('returns null when there is no schedule scope', () => {
      expect(parseScheduleConfig({})).toBe(null);
      expect(parseScheduleConfig(undefined)).toBe(null);
    });
  });

  describe('isScheduleConfigValid', () => {
    it('returns false when there is no schedule or the frequency is unknown', () => {
      expect(isScheduleConfigValid({})).toBe(false);
      expect(isScheduleConfigValid({ schedule: { frequency: 'NOPE' } })).toBe(false);
    });

    it('returns true for a sub-hour preset that requires no fields', () => {
      expect(
        isScheduleConfigValid({ schedule: { frequency: SCHEDULE_FREQUENCY_EVERY_15_MINUTES } }),
      ).toBe(true);
    });

    it('validates a fully configured monthly schedule', () => {
      const schedule = {
        frequency: SCHEDULE_FREQUENCY_MONTHLY,
        minute: 30,
        hour: 23,
        dayOfMonth: 28,
        timezone: 'Etc/UTC',
      };

      expect(isScheduleConfigValid({ schedule })).toBe(true);
    });

    it('validates a fully configured weekdays schedule (no day field required)', () => {
      const schedule = {
        frequency: SCHEDULE_FREQUENCY_WEEKDAYS,
        minute: 0,
        hour: 9,
        timezone: 'Etc/UTC',
      };

      expect(isScheduleConfigValid({ schedule })).toBe(true);
    });

    it('validates a fully configured weekly schedule', () => {
      const schedule = {
        frequency: SCHEDULE_FREQUENCY_WEEKLY,
        minute: 0,
        hour: 9,
        dayOfWeek: 3,
        timezone: 'Etc/UTC',
      };

      expect(isScheduleConfigValid({ schedule })).toBe(true);
    });

    it.each`
      description                  | schedule
      ${'minute off the 15s'}      | ${{ frequency: SCHEDULE_FREQUENCY_DAILY, minute: 7, hour: 9, timezone: 'Etc/UTC' }}
      ${'hour out of range'}       | ${{ frequency: SCHEDULE_FREQUENCY_DAILY, minute: 0, hour: 24, timezone: 'Etc/UTC' }}
      ${'missing timezone'}        | ${{ frequency: SCHEDULE_FREQUENCY_DAILY, minute: 0, hour: 9 }}
      ${'weekly without day'}      | ${{ frequency: SCHEDULE_FREQUENCY_WEEKLY, minute: 0, hour: 9, timezone: 'Etc/UTC' }}
      ${'day-of-week above 6'}     | ${{ frequency: SCHEDULE_FREQUENCY_WEEKLY, minute: 0, hour: 9, dayOfWeek: 7, timezone: 'Etc/UTC' }}
      ${'day-of-week non-integer'} | ${{ frequency: SCHEDULE_FREQUENCY_WEEKLY, minute: 0, hour: 9, dayOfWeek: 1.5, timezone: 'Etc/UTC' }}
      ${'day-of-month above 28'}   | ${{ frequency: SCHEDULE_FREQUENCY_MONTHLY, minute: 0, hour: 9, dayOfMonth: 29, timezone: 'Etc/UTC' }}
      ${'day-of-month below 1'}    | ${{ frequency: SCHEDULE_FREQUENCY_MONTHLY, minute: 0, hour: 9, dayOfMonth: 0, timezone: 'Etc/UTC' }}
    `('returns false for $description', ({ schedule }) => {
      expect(isScheduleConfigValid({ schedule })).toBe(false);
    });
  });

  describe('getEnabledFlowTriggerTypes', () => {
    const valuesOf = (types) => types.map(({ value }) => value);

    it('keeps types that declare neither a predicate nor a flag', () => {
      const alwaysOn = FLOW_TRIGGER_TYPES.filter(
        ({ isAvailable, featureFlag }) => !isAvailable && !featureFlag,
      );

      expect(valuesOf(getEnabledFlowTriggerTypes())).toEqual(
        expect.arrayContaining(valuesOf(alwaysOn)),
      );
    });

    it('drops types whose predicate rejects the flags', () => {
      const gated = FLOW_TRIGGER_TYPES.filter(({ isAvailable }) => isAvailable?.({}) === false);

      expect(gated.length).toBeGreaterThan(0);
      expect(valuesOf(getEnabledFlowTriggerTypes({}))).not.toEqual(
        expect.arrayContaining(valuesOf(gated)),
      );
    });

    it('keeps a flag-gated type only while its flag is on', () => {
      const gatedType = { value: 'gated', text: 'Gated', featureFlag: 'someFlag' };
      FLOW_TRIGGER_TYPES.push(gatedType);

      try {
        expect(valuesOf(getEnabledFlowTriggerTypes({ someFlag: false }))).not.toContain('gated');
        expect(valuesOf(getEnabledFlowTriggerTypes({ someFlag: true }))).toContain('gated');
      } finally {
        FLOW_TRIGGER_TYPES.pop();
      }
    });
  });

  describe('toFlowTriggerTypeOption', () => {
    // `~/locale` is mocked for this suite, so give sprintf just enough behaviour to show the
    // template and the item type reach it.
    beforeEach(() => {
      sprintf.mockImplementation((template, { itemType }) =>
        template.replace('%{itemType}', itemType),
      );
    });

    it('templates the description with the item type', () => {
      const option = toFlowTriggerTypeOption(
        { value: 'mention', text: 'Mention', description: 'Trigger %{itemType} on mention.' },
        'flow',
      );

      expect(option).toEqual({
        value: 'mention',
        text: 'Mention',
        description: 'Trigger flow on mention.',
      });
    });

    it('leaves the description undefined when the type has none', () => {
      const option = toFlowTriggerTypeOption({ value: 'assign', text: 'Assign' }, 'flow');

      expect(option.description).toBeUndefined();
    });
  });

  describe('flowTriggerModeFor', () => {
    it('reports the schedule type as a schedule', () => {
      expect(flowTriggerModeFor(FLOW_TRIGGER_MODE_SCHEDULE)).toBe(FLOW_TRIGGER_MODE_SCHEDULE);
    });

    it.each(['mention', 'pipeline_hooks', 'not_an_event', undefined])(
      'reports %p as an event',
      (typeValue) => {
        expect(flowTriggerModeFor(typeValue)).toBe(FLOW_TRIGGER_MODE_EVENT);
      },
    );
  });

  describe('randomizeScheduleDefaults', () => {
    beforeEach(() => {
      jest.spyOn(Math, 'random').mockReturnValue(0);
    });

    it('fills only the fields the daily preset needs and defaults the timezone', () => {
      expect(randomizeScheduleDefaults(SCHEDULE_FREQUENCY_DAILY, { timezone: 'Etc/UTC' })).toEqual({
        frequency: SCHEDULE_FREQUENCY_DAILY,
        minute: 0,
        hour: 0,
        timezone: 'Etc/UTC',
      });
    });

    it('adds a day-of-week for weekly and a day-of-month for monthly', () => {
      expect(randomizeScheduleDefaults(SCHEDULE_FREQUENCY_WEEKLY)).toMatchObject({ dayOfWeek: 0 });
      expect(randomizeScheduleDefaults(SCHEDULE_FREQUENCY_MONTHLY)).toMatchObject({
        dayOfMonth: 1,
      });
    });

    it('adds only a minute and timezone for the hourly preset', () => {
      expect(randomizeScheduleDefaults(SCHEDULE_FREQUENCY_HOURLY, { timezone: 'Etc/UTC' })).toEqual(
        {
          frequency: SCHEDULE_FREQUENCY_HOURLY,
          minute: 0,
          timezone: 'Etc/UTC',
        },
      );
    });

    it('stores only the frequency for sub-hour presets and defaults timezone to an empty string', () => {
      expect(randomizeScheduleDefaults(SCHEDULE_FREQUENCY_EVERY_15_MINUTES)).toEqual({
        frequency: SCHEDULE_FREQUENCY_EVERY_15_MINUTES,
      });
    });

    it('keeps randomized values within their domains across many runs', () => {
      jest.restoreAllMocks();

      Array.from({ length: 50 }).forEach(() => {
        const { minute, hour, dayOfMonth } = randomizeScheduleDefaults(SCHEDULE_FREQUENCY_MONTHLY);

        expect([0, 15, 30, 45]).toContain(minute);
        expect(hour).toBeGreaterThanOrEqual(0);
        expect(hour).toBeLessThanOrEqual(23);
        expect(dayOfMonth).toBeGreaterThanOrEqual(1);
        expect(dayOfMonth).toBeLessThanOrEqual(28);
      });
    });
  });
});
