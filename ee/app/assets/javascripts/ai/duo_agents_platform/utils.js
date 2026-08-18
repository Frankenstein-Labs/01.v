import { s__, sprintf } from '~/locale';
import { humanize } from '~/lib/utils/text_utility';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { isGid, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  AGENT_PLATFORM_STATUS_ICON,
  AGENT_PLATFORM_STATUS_BADGE,
  FILTER_FIELD_ACTION,
  FILTER_FIELD_PIPELINE_STATUS,
  FILTER_OPERATOR_IN,
  FLOW_TRIGGER_MODE_EVENT,
  FLOW_TRIGGER_MODE_SCHEDULE,
  FLOW_TRIGGER_TYPES,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST_READY,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST_CODE_CONFLICT,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
  FLOW_TRIGGER_TYPE_SCHEDULE,
  FLOW_TRIGGER_TYPE_WORK_ITEM,
  MERGE_REQUEST_ACTIONS,
  PIPELINE_HOOK_STATUSES,
  SCHEDULE_DAY_OF_MONTH_MAX,
  SCHEDULE_DAY_OF_MONTH_MIN,
  SCHEDULE_DAY_OF_WEEK_MAX,
  SCHEDULE_DAY_OF_WEEK_MIN,
  SCHEDULE_FIELD_DAY_OF_MONTH,
  SCHEDULE_FIELD_DAY_OF_WEEK,
  SCHEDULE_FIELD_HOUR,
  SCHEDULE_FIELD_MINUTE,
  SCHEDULE_FIELD_TIMEZONE,
  SCHEDULE_FREQUENCY_FIELDS,
  SCHEDULE_HOUR_MAX,
  SCHEDULE_HOUR_MIN,
  SCHEDULE_MINUTE_VALUES,
  WORK_ITEM_ACTIONS,
} from './constants';

export const getNumericId = (id) => {
  if (!id) return null;
  return isGid(id) ? getIdFromGraphQLId(id) : id;
};

export { getToolData, getMessageData } from './icon_utils';

export const formatAgentDefinition = (agentDefinition) => {
  return humanize(agentDefinition || s__('DuoAgentsPlatform|Agent session'));
};

export const formatAgentFlowName = (agentDefinition, id) => {
  return `${formatAgentDefinition(agentDefinition)} #${id}`;
};

export const formatAgentFlowTitle = (title, agentDefinition) =>
  title?.trim() ? title : formatAgentDefinition(agentDefinition);

export const formatAgentFlowTitleWithId = (title, agentDefinition, id) =>
  title?.trim() ? title : formatAgentFlowName(agentDefinition, id);

export const formatAgentStatus = (status) => {
  return status ? humanize(status.toLowerCase()) : s__('DuoAgentsPlatform|Unknown');
};

export const getAgentStatusIcon = (status) => {
  return AGENT_PLATFORM_STATUS_ICON[status] || AGENT_PLATFORM_STATUS_ICON.CREATED;
};

export const getAgentStatusBadge = (status) => {
  return AGENT_PLATFORM_STATUS_BADGE[status] || AGENT_PLATFORM_STATUS_BADGE.FAILED;
};

export const getNamespaceDatasetProperties = (dataset, properties) =>
  properties.reduce((acc, prop) => {
    acc[prop] = dataset[prop];
    return acc;
  }, {});

export const formatDate = (isoString) => {
  if (!isoString) return '';

  try {
    return localeDateFormat.asDate.format(new Date(isoString));
  } catch {
    return '';
  }
};

/**
 * Extracts the values of a single `{ field, operator: 'in', value: [...] }` rule from a
 * trigger filter scope, keeping only values that belong to the known option set.
 *
 * The filter is shaped like `{ <scope>: { rules: [{ field, operator, value }] } }`
 * (validated by app/validators/json_schemas/filter.json).
 * Returns `[]` when the filter is missing, malformed, or has values outside `options`.
 */
export const parseFilterRuleValues = ({ filter, scope, field, options }) => {
  const rules = filter?.[scope]?.rules;
  if (!Array.isArray(rules) || rules.length !== 1) return [];

  const [rule] = rules;
  if (rule.field !== field || rule.operator !== FILTER_OPERATOR_IN || !Array.isArray(rule.value)) {
    return [];
  }

  const allowedValues = options.map((option) => option.value);
  return rule.value.filter((value) => allowedValues.includes(value));
};

/**
 * Maps selected option values to their human-readable labels, preserving option order.
 * Used to render the trigger token summary on the catalog item page.
 */
const selectedOptionLabels = (options, values) =>
  options.filter((option) => values.includes(option.value)).map((option) => option.text);

export const parsePipelineStatusFilter = (filter) =>
  parseFilterRuleValues({
    filter,
    scope: FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value,
    field: FILTER_FIELD_PIPELINE_STATUS,
    options: PIPELINE_HOOK_STATUSES,
  });

export const pipelineStatusLabels = (filter) =>
  selectedOptionLabels(PIPELINE_HOOK_STATUSES, parsePipelineStatusFilter(filter));

const FOLDABLE_MERGE_REQUEST_ACTIONS = MERGE_REQUEST_ACTIONS.filter(
  (action) => action.eventTypeValueInt != null,
);

const buildMergeRequestActionFilter = (filter, actions) => ({
  ...(filter || {}),
  [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value]: {
    rules: [{ field: FILTER_FIELD_ACTION, operator: FILTER_OPERATOR_IN, value: actions }],
  },
});

const filterWithoutMergeRequest = (filter) =>
  Object.fromEntries(
    Object.entries(filter || {}).filter(([key]) => key !== FLOW_TRIGGER_TYPE_MERGE_REQUEST.value),
  );

/**
 * Extracts the selected merge_request action values from a trigger's filter JSONB.
 *
 * The filter is shaped like
 *   `{ merge_request: { rules: [{ field: 'action', operator: 'in', value: [...] }] } }`.
 * Returns the validated action values (e.g. `['ready', 'approved']`), or `[]` if the
 * filter is missing, malformed, or contains values outside the known action set.
 */
export const parseMergeRequestActionFilter = (filter) => {
  const rules = filter?.[FLOW_TRIGGER_TYPE_MERGE_REQUEST.value]?.rules;
  if (!Array.isArray(rules) || rules.length !== 1) return [];

  const [rule] = rules;
  if (
    rule.field !== FILTER_FIELD_ACTION ||
    rule.operator !== FILTER_OPERATOR_IN ||
    !Array.isArray(rule.value)
  ) {
    return [];
  }

  const allowedValues = MERGE_REQUEST_ACTIONS.map((action) => action.value);
  return rule.value.filter((value) => allowedValues.includes(value));
};

export const parseWorkItemActionFilter = (filter) =>
  parseFilterRuleValues({
    filter,
    scope: FLOW_TRIGGER_TYPE_WORK_ITEM.value,
    field: FILTER_FIELD_ACTION,
    options: WORK_ITEM_ACTIONS,
  });

/**
 * Returns the human-readable labels for the merge_request actions selected in a filter,
 * e.g. `['Ready', 'Approved']`. Used to render the trigger token summary on the catalog item page.
 */
export const mergeRequestActionLabels = (filter) => {
  const values = parseMergeRequestActionFilter(filter);
  if (!values.length) return [];

  return MERGE_REQUEST_ACTIONS.filter((action) => values.includes(action.value)).map(
    (action) => action.text,
  );
};

export const workItemActionLabels = (filter) =>
  selectedOptionLabels(WORK_ITEM_ACTIONS, parseWorkItemActionFilter(filter));

// Every event type that can appear in a trigger's event_types, including the foldable
// merge_request actions (4/5) that are not offered as standalone listbox options.
const ALL_FLOW_TRIGGER_TYPES = [
  ...FLOW_TRIGGER_TYPES,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST_READY,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST_CODE_CONFLICT,
];

/**
 * Maps string event-type values (e.g. `'merge_request'`) to their numeric ids, dropping
 * any unknown values. Lets string-keyed callers reuse the int-keyed fold helpers below.
 */
export const eventTypeValuesToInts = (values = []) =>
  values
    .map((value) => ALL_FLOW_TRIGGER_TYPES.find((type) => type.value === value)?.valueInt)
    .filter((valueInt) => valueInt != null);

/**
 * Inverse of `eventTypeValuesToInts`: maps numeric event-type ids back to their string
 * values, dropping any unknown ids.
 */
export const eventTypeIntsToValues = (ints = []) =>
  ints
    .map((valueInt) => ALL_FLOW_TRIGGER_TYPES.find((type) => type.valueInt === valueInt)?.value)
    .filter(Boolean);

/**
 * Inverse of `normalizeMergeRequestEventTypes`: restores each foldable action to its own
 * event type (`ready` -> 4, `code_conflict` -> 5) on save, so only the non-foldable actions
 * (`approved`, `merged`) are ever stored under `merge_request` (6). Idempotent and pure.
 */
export const denormalizeMergeRequestEventTypes = ({ eventTypes, filter }) => {
  const mrId = FLOW_TRIGGER_TYPE_MERGE_REQUEST.valueInt;
  const actions = parseMergeRequestActionFilter(filter);

  const toRestore = FOLDABLE_MERGE_REQUEST_ACTIONS.filter((action) =>
    actions.includes(action.value),
  );

  if (!toRestore.length) {
    return { eventTypes, filter: filter || {} };
  }

  const restoredValues = toRestore.map((action) => action.value);
  const remainingActions = actions.filter((action) => !restoredValues.includes(action));
  const nextFilter = remainingActions.length
    ? buildMergeRequestActionFilter(filterWithoutMergeRequest(filter), remainingActions)
    : filterWithoutMergeRequest(filter);

  let nextEventTypes = [...(eventTypes || [])];
  toRestore.forEach(({ eventTypeValueInt }) => {
    if (!nextEventTypes.includes(eventTypeValueInt)) nextEventTypes.push(eventTypeValueInt);
  });
  if (!remainingActions.length) {
    nextEventTypes = nextEventTypes.filter((id) => id !== mrId);
  }

  return { eventTypes: nextEventTypes, filter: nextFilter };
};

/**
 * Folds `merge_request_ready` (4) and `merge_request_code_conflict` (5) into `merge_request`
 * (6) with the matching action filter, so the field only deals with the consolidated shape.
 * Idempotent and pure.
 */
export const normalizeMergeRequestEventTypes = ({ eventTypes, filter }) => {
  const types = Array.isArray(eventTypes) ? [...eventTypes] : eventTypes;
  if (!Array.isArray(types)) return { eventTypes, filter: filter || {} };

  const mrId = FLOW_TRIGGER_TYPE_MERGE_REQUEST.valueInt;
  const toFold = FOLDABLE_MERGE_REQUEST_ACTIONS.filter((action) =>
    types.includes(action.eventTypeValueInt),
  );

  if (!toFold.length) {
    return { eventTypes: types, filter: filter || {} };
  }

  const eventTypeValueInts = toFold.map((action) => action.eventTypeValueInt);
  const filteredTypes = types.filter((id) => !eventTypeValueInts.includes(id));
  if (!filteredTypes.includes(mrId)) {
    filteredTypes.push(mrId);
  }

  const existingActions = parseMergeRequestActionFilter(filter);
  const foldedActions = toFold
    .map((action) => action.value)
    .filter((value) => !existingActions.includes(value));

  return {
    eventTypes: filteredTypes,
    filter: buildMergeRequestActionFilter(filter, [...existingActions, ...foldedActions]),
  };
};

const randomInt = (min, max) => min + Math.floor(Math.random() * (max - min + 1));

const randomFrom = (values) => values[Math.floor(Math.random() * values.length)];

// Returns the plain schedule object described in `constants.js`, or null when absent.
export const parseScheduleConfig = (filter) => filter?.[FLOW_TRIGGER_TYPE_SCHEDULE.value] ?? null;

const isIntegerInRange = (value, min, max) =>
  Number.isInteger(value) && value >= min && value <= max;

const isScheduleFieldValid = (field, value) => {
  switch (field) {
    case SCHEDULE_FIELD_MINUTE:
      return SCHEDULE_MINUTE_VALUES.includes(value);
    case SCHEDULE_FIELD_HOUR:
      return isIntegerInRange(value, SCHEDULE_HOUR_MIN, SCHEDULE_HOUR_MAX);
    case SCHEDULE_FIELD_DAY_OF_WEEK:
      return isIntegerInRange(value, SCHEDULE_DAY_OF_WEEK_MIN, SCHEDULE_DAY_OF_WEEK_MAX);
    case SCHEDULE_FIELD_DAY_OF_MONTH:
      return isIntegerInRange(value, SCHEDULE_DAY_OF_MONTH_MIN, SCHEDULE_DAY_OF_MONTH_MAX);
    case SCHEDULE_FIELD_TIMEZONE:
      return typeof value === 'string' && value.length > 0;
    default:
      return false;
  }
};

export const isScheduleConfigValid = (filter) => {
  const schedule = parseScheduleConfig(filter);
  const fields = schedule && SCHEDULE_FREQUENCY_FIELDS[schedule.frequency];
  if (!fields) return false;

  return fields.every((field) => isScheduleFieldValid(field, schedule[field]));
};

const EVENT_SUMMARY_LABEL_BUILDERS = {
  [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value]: pipelineStatusLabels,
  [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value]: mergeRequestActionLabels,
  [FLOW_TRIGGER_TYPE_WORK_ITEM.value]: workItemActionLabels,
};

/**
 * The trigger types a namespace can actually offer, given its feature flags. Types opt out
 * either with an `isAvailable` predicate or a plain `featureFlag` name; anything declaring
 * neither is always available.
 */
export const getEnabledFlowTriggerTypes = (glFeatures = {}) =>
  FLOW_TRIGGER_TYPES.filter((type) => {
    if (type.isAvailable) return type.isAvailable(glFeatures);
    if (type.featureFlag) return Boolean(glFeatures[type.featureFlag]);
    return true;
  });

/**
 * Shapes a trigger type for a listbox. Descriptions are templated per item type, so a flow
 * and an agent read correctly from the same definition. A description may also be a function
 * of `glFeatures`, so a flag-gated type can describe itself differently once its flag is on.
 */
export const toFlowTriggerTypeOption = (
  { value, text, description },
  itemTypeLabel,
  glFeatures = {},
) => {
  const resolved = typeof description === 'function' ? description(glFeatures) : description;

  return {
    value,
    text,
    description: resolved ? sprintf(resolved, { itemType: itemTypeLabel }) : undefined,
  };
};

/**
 * Which mode a condition's event type belongs to. Only `schedule` is time based; every
 * other type is driven by something happening in the project.
 */
export const flowTriggerModeFor = (typeValue) =>
  typeValue === FLOW_TRIGGER_MODE_SCHEDULE ? FLOW_TRIGGER_MODE_SCHEDULE : FLOW_TRIGGER_MODE_EVENT;

/**
 * Summarizes a single configured event type as one line, e.g. "Merge request: Marked ready".
 * Event types with no rules, including `schedule`, are named but not described: rendering a
 * schedule as a sentence needs its own strings and belongs with the code that enables it.
 */
export const flowTriggerEventSummary = (typeValue, filter) => {
  const type = FLOW_TRIGGER_TYPES.find(({ value }) => value === typeValue);

  if (!type) {
    return s__('DuoAgentsPlatform|Unknown event');
  }

  const labels = EVENT_SUMMARY_LABEL_BUILDERS[typeValue]?.(filter) ?? [];

  if (!labels.length) {
    return type.text;
  }

  return sprintf(s__('DuoAgentsPlatform|%{event}: %{conditions}'), {
    event: type.text,
    conditions: labels.join(', '),
  });
};

// Randomize each field's default so new schedules spread across the domain instead of clustering
// on the first selectable value. The timezone defaults to the user's zone, never a random one.
export const randomizeScheduleDefaults = (frequency, { timezone = '' } = {}) => {
  const fields = SCHEDULE_FREQUENCY_FIELDS[frequency] ?? [];
  const schedule = { frequency };

  if (fields.includes(SCHEDULE_FIELD_MINUTE)) schedule.minute = randomFrom(SCHEDULE_MINUTE_VALUES);
  if (fields.includes(SCHEDULE_FIELD_HOUR)) {
    schedule.hour = randomInt(SCHEDULE_HOUR_MIN, SCHEDULE_HOUR_MAX);
  }
  if (fields.includes(SCHEDULE_FIELD_DAY_OF_WEEK)) {
    schedule.dayOfWeek = randomInt(SCHEDULE_DAY_OF_WEEK_MIN, SCHEDULE_DAY_OF_WEEK_MAX);
  }
  if (fields.includes(SCHEDULE_FIELD_DAY_OF_MONTH)) {
    schedule.dayOfMonth = randomInt(SCHEDULE_DAY_OF_MONTH_MIN, SCHEDULE_DAY_OF_MONTH_MAX);
  }
  if (fields.includes(SCHEDULE_FIELD_TIMEZONE)) schedule.timezone = timezone;

  return schedule;
};
