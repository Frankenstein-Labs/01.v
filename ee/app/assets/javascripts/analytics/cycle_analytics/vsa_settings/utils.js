import { isEqual, pick } from 'lodash-es';
import {
  isStartEvent,
  getAllowedEndEvents,
  eventToOption,
  eventsByIdentifier,
  isLabelEvent,
} from '../utils';
import {
  ERRORS,
  NAME_MAX_LENGTH,
  NAME_MIN_LENGTH,
  formFieldKeys,
  editableFormFieldKeys,
} from './constants';

/**
 * @typedef {Object} CustomStageEvents
 * @property {String} canBeStartEvent - Title of the metric measured
 * @property {String} name - Friendly name for the event
 * @property {String} identifier - snakeized name for the event
 *
 * @typedef {Object} DropdownData
 * @property {String} text - Friendly name for the event
 * @property {String} value - Value to be submitted for the dropdown
 */

/**
 * Takes an array of custom stage events to return only the
 * events where `canBeStartEvent` is true and converts them
 * to { value, text } pairs for use in dropdowns
 *
 * @param {CustomStageEvents[]} events
 * @returns {DropdownData[]} array of start events formatted for dropdowns
 */
export const startEventOptions = (eventsList) => eventsList.filter(isStartEvent).map(eventToOption);

/**
 * Takes an array of custom stage events to return only the
 * events where `canBeStartEvent` is false and converts them
 * to { value, text } pairs for use in dropdowns
 *
 * @param {CustomStageEvents[]} events
 * @returns {DropdownData[]} array end events formatted for dropdowns
 */
export const endEventOptions = (eventsList, startEventIdentifier) => {
  const endEvents = getAllowedEndEvents(eventsList, startEventIdentifier);
  return eventsByIdentifier(eventsList, endEvents).map(eventToOption);
};

/**
 * Returns a clean string for comparison, converted lower case with whitespace trimmed
 * @param {String} str the string to be cleaned
 * @returns {String}
 */
export const cleanStageName = (str = '') => str?.trim().toLowerCase();

/**
 * Validates the form fields for the custom stages form
 * Any errors will be returned in an object where the key is
 * the name of the field
 *
 * @param {Object} currentStage - the current stage to be validated
 * @param {Array} allStageNames - array of the existing value stream stage names
 * @param {Array} labelEvents - array of all label events
 * @returns {Object} key value pair of form fields with an array of errors
 */
export const validateStage = ({
  currentStage = null,
  allStageNames = [],
  labelEvents = [],
} = {}) => {
  const newErrors = {};

  if (currentStage?.name) {
    if (currentStage.name.length > NAME_MAX_LENGTH) {
      newErrors.name = [ERRORS.MAX_LENGTH];
    }

    const formattedStageName = cleanStageName(currentStage.name);

    const matches = allStageNames.filter((stageName) => {
      return cleanStageName(stageName) === formattedStageName;
    });
    if (matches.length > 1) {
      newErrors.name = [ERRORS.STAGE_NAME_EXISTS];
    }
  } else {
    newErrors.name = [ERRORS.STAGE_NAME_MIN_LENGTH];
  }

  if (currentStage?.startEventIdentifier) {
    if (!currentStage?.endEventIdentifier) {
      newErrors.endEventIdentifier = [ERRORS.END_EVENT_REQUIRED];
    }

    if (
      isLabelEvent(labelEvents, currentStage.startEventIdentifier) &&
      !currentStage?.startEventLabelId
    ) {
      newErrors.startEventLabelId = [ERRORS.EVENT_LABEL_REQUIRED];
    }
  } else {
    newErrors.startEventIdentifier = [ERRORS.START_EVENT_REQUIRED];
  }

  if (currentStage?.endEventIdentifier) {
    if (
      isLabelEvent(labelEvents, currentStage.endEventIdentifier) &&
      !currentStage?.endEventLabelId
    ) {
      newErrors.endEventLabelId = [ERRORS.EVENT_LABEL_REQUIRED];
    }
  }
  return newErrors;
};

/**
 * Validates the name of a value stream Any errors will be
 * returned as an array in a object with key`name`
 *
 * @param {Object} fields key value pair of form field values
 * @returns {Array} an array of errors
 */
export const validateValueStreamName = ({ name = '' }) => {
  const errors = [];
  if (name.length > NAME_MAX_LENGTH) {
    errors.push(ERRORS.MAX_LENGTH);
  }

  if (name && name.length < NAME_MIN_LENGTH) {
    errors.push(ERRORS.VALUE_STREAM_NAME_MIN_LENGTH);
  }

  if (!name.length) {
    errors.push(ERRORS.VALUE_STREAM_NAME_REQUIRED);
  }
  return errors;
};

/**
 * Formats the value stream stages for submission, ensures that the
 * 'custom' property is set when we are editing, we include the `id` if its
 * set and all fields are converted to snake case
 *
 * @param {Array} stages array of value stream stages
 * @param {Boolean} isEditing flag to indicate if we are editing a value stream or creating
 * @returns {Array} the array prepared to be submitted for persistence
 */
export const formatStageDataForSubmission = (stages, isEditing = false) => {
  return stages.map(({ id = null, custom = false, name, hidden, ...rest }) => {
    let editProps = { custom };
    if (isEditing) {
      // We can add a new stage to the value stream when either creating, or editing
      // If a new stage has been added then at this point, the `id` won't exist
      // The new stage is still `custom` but wont have an id until the form submits and its persisted to the DB
      editProps = id ? { id, custom: true } : { custom: true };
    }

    const editableFields = pick(rest, editableFormFieldKeys);

    // Stage event IDs are `lower_snake_case` for both the frontend and backend
    // but we require `UPPER_SNAKE_CASE` with GraphQL.
    editableFields.startEventIdentifier = editableFields.startEventIdentifier?.toUpperCase();
    editableFields.endEventIdentifier = editableFields.endEventIdentifier?.toUpperCase();

    // While we work on https://gitlab.com/gitlab-org/gitlab/-/issues/321959 we should not allow editing default
    return custom
      ? { ...editableFields, ...editProps, name }
      : { ...editProps, name, hidden, custom: false };
  });
};

/**
 * Checks an array of value stream stages to see if there are
 * any differences in the values they contain
 *
 * @param {Array} stages array of value stream stages
 * @param {Array} stages array of value stream stages
 * @returns {Boolean} returns true if there is a difference in the 2 arrays
 */
export const hasDirtyStage = (currentStages, originalStages) => {
  const cs = currentStages.map((s) => pick(s, formFieldKeys));
  const os = originalStages.map((s) => pick(s, formFieldKeys));
  return !isEqual(cs, os);
};

/**
 * Checks if the target name matches the name of any of the value
 * stream stages passed in
 *
 * @param {Array} stages array of value stream stages
 * @param {String} targetName name we are searching for
 * @returns {Object} returns the found object or null
 */
const findStageByName = (stages, targetName = '') =>
  stages.find(({ name }) => name.toLowerCase().trim() === targetName.toLowerCase().trim());

/**
 * Returns a valid custom value stream stage
 *
 * @param {Object} stage a raw value stream stage retrieved from the vuex store
 * @returns {Object} the same stage with fields adjusted for the value stream form
 */
const prepareCustomStage = ({ startEventLabel = {}, endEventLabel = {}, ...rest }) => ({
  ...rest,
  startEventLabel,
  endEventLabel,
  startEventLabelId: startEventLabel?.id || null,
  endEventLabelId: endEventLabel?.id || null,
  isDefault: false,
});

/**
 * Returns a valid default value stream stage
 *
 * @param {Object} stage a raw value stream stage retrieved from the vuex store
 * @returns {Object} the same stage with fields adjusted for the value stream form
 */
const prepareDefaultStage = (defaultStageConfig, { name, ...rest }) => {
  // default stages currently dont have any label based events
  const stage = findStageByName(defaultStageConfig, name) || null;
  if (!stage) return {};
  const { startEventIdentifier = null, endEventIdentifier = null } = stage;
  return {
    ...rest,
    name,
    startEventIdentifier,
    endEventIdentifier,
    isDefault: true,
  };
};

/**
 * Prepares the stage errors for use in the create value stream form
 *
 * The JSON error response returns a key value pair, the key corresponds to the
 * index of the stage with errors and the value is the returned error(s)
 *
 * @param {Array} stages - Array of value stream stages
 * @param {Object} errors - Key value pair of stage errors
 * @returns {Array} Returns and array of stage error objects
 */
export const prepareStageErrors = (stages, errors) => stages.map((_, index) => errors[index] || {});

/**
 * Sorts the inputs array so that any hidden stages are at the end of the list
 *
 * @param {Array} stages - an array of value stream stages
 * @returns {Array} The sorted array of value stream stages
 */
export const sortStagesByHidden = (stages) =>
  [...stages].sort(({ hidden: a = false }, { hidden: b = false }) => Number(a) - Number(b));

const generateHiddenDefaultStages = (defaultStageConfig, stageNames) => {
  // We use the stage name to check for any default stages that might be hidden
  // Currently the default stages can't be renamed
  return defaultStageConfig
    .filter(({ name }) => !stageNames.includes(name.toLowerCase()))
    .map((data) => ({ ...data, hidden: true }));
};

/**
 * Returns a valid array of value stream stages for
 * use in the value stream form
 *
 * @param {Array} defaultStageConfig an array of the default value stream stages retrieved from the backend
 * @param {Array} selectedValueStreamStages an array of raw value stream stages retrieved from the vuex store
 * @returns {Object} the same stage with fields adjusted for the value stream form
 */
export const generateInitialStageData = (defaultStageConfig, selectedValueStreamStages) => {
  const hiddenDefaultStages = generateHiddenDefaultStages(
    defaultStageConfig,
    selectedValueStreamStages.map((s) => s.name.toLowerCase()),
  );
  const combinedStages = [...selectedValueStreamStages, ...hiddenDefaultStages];
  const formattedStages = combinedStages.map(
    ({ startEventIdentifier = null, endEventIdentifier = null, custom = false, ...rest }) => {
      const stageData =
        custom && startEventIdentifier && endEventIdentifier
          ? prepareCustomStage({ ...rest, startEventIdentifier, endEventIdentifier })
          : prepareDefaultStage(defaultStageConfig, rest);

      if (stageData?.name) {
        return {
          ...stageData,
          custom,
        };
      }
      return {};
    },
  );

  return sortStagesByHidden(formattedStages);
};
