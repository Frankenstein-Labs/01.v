import { s__ } from '~/locale';
import {
  FILTER_FIELD_ACTION,
  FLOW_TRIGGER_TYPE_MERGE_REQUEST,
  FLOW_TRIGGER_TYPE_PIPELINE_HOOKS,
  FLOW_TRIGGER_TYPE_SCHEDULE,
  FLOW_TRIGGER_TYPE_WORK_ITEM,
  MERGE_REQUEST_ACTIONS,
  WORK_ITEM_ACTIONS,
} from 'ee/ai/duo_agents_platform/constants';
import {
  isScheduleConfigValid,
  parseMergeRequestActionFilter,
  parsePipelineStatusFilter,
  parseWorkItemActionFilter,
} from 'ee/ai/duo_agents_platform/utils';
import EventActionsConfiguration from './event_actions_configuration.vue';
import PipelineEventsConfiguration from './pipeline_events_configuration.vue';
import ScheduleEventsConfiguration from './schedule_events_configuration.vue';

// Event types whose configuration is "pick one or more actions on a scope". They differ only
// in the scope they read, the actions they offer, and how they name themselves.
const actionsConfiguration = ({ scope, actions, listboxHeaderText, parse, invalidFeedback }) => ({
  component: EventActionsConfiguration,
  props: {
    scope,
    field: FILTER_FIELD_ACTION,
    actions,
    listboxHeaderText,
  },
  isValid: (filter) => parse(filter).length > 0,
  invalidFeedback,
});

// The extra fields an event type needs before it can be saved. Event types absent from this
// map (mention, assign, assign reviewer) fire unconditionally and need no configuration.
const EVENT_CONFIGURATIONS = {
  [FLOW_TRIGGER_TYPE_PIPELINE_HOOKS.value]: {
    component: PipelineEventsConfiguration,
    isValid: (filter) => parsePipelineStatusFilter(filter).length > 0,
    invalidFeedback: s__('DuoAgentsPlatform|Select at least one pipeline event.'),
  },
  [FLOW_TRIGGER_TYPE_MERGE_REQUEST.value]: actionsConfiguration({
    scope: FLOW_TRIGGER_TYPE_MERGE_REQUEST.value,
    actions: MERGE_REQUEST_ACTIONS,
    listboxHeaderText: s__('DuoAgentsPlatform|Select merge request actions'),
    parse: parseMergeRequestActionFilter,
    invalidFeedback: s__('DuoAgentsPlatform|Select at least one merge request action.'),
  }),
  [FLOW_TRIGGER_TYPE_WORK_ITEM.value]: actionsConfiguration({
    scope: FLOW_TRIGGER_TYPE_WORK_ITEM.value,
    actions: WORK_ITEM_ACTIONS,
    listboxHeaderText: s__('DuoAgentsPlatform|Select work item actions'),
    parse: parseWorkItemActionFilter,
    invalidFeedback: s__('DuoAgentsPlatform|Select at least one work item action.'),
  }),
  [FLOW_TRIGGER_TYPE_SCHEDULE.value]: {
    component: ScheduleEventsConfiguration,
    isValid: (filter) => isScheduleConfigValid(filter),
    invalidFeedback: s__('DuoAgentsPlatform|Configure the schedule.'),
  },
};

export const getEventConfiguration = (typeValue) => EVENT_CONFIGURATIONS[typeValue] ?? null;

/**
 * Event types with no configuration are always valid, so an unconfigurable type never blocks
 * the form. A type is only invalid once it is selected and its own fields are incomplete.
 */
export const isEventConfigurationValid = (typeValue, filter) =>
  getEventConfiguration(typeValue)?.isValid(filter) ?? true;

export const eventConfigurationInvalidFeedback = (typeValue, filter) =>
  isEventConfigurationValid(typeValue, filter)
    ? null
    : getEventConfiguration(typeValue).invalidFeedback;
