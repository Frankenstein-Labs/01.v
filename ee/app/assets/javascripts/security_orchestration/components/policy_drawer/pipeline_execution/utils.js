import { isObject, isString, isEmpty } from 'lodash-es';
import { __ } from '~/locale';

const LOCAL = 'local';
const REMOTE = 'remote';

const KEY_LABEL_MAP = {
  file: __('Path'),
  project: __('Project'),
  ref: __('Reference'),
  id: __('Id'),
  template: __('Template'),
  [LOCAL]: __('Local'),
  [REMOTE]: __('Remote'),
};

/**
 * Convert string or object include item to sentence
 * @param acc
 * @param item
 * @returns {{}}
 */
export const humanizeIncludeArrayItem = (acc = {}, item) => {
  if (!item) return acc;

  if (isString(item)) {
    const key = LOCAL in acc ? REMOTE : LOCAL;
    acc[key] = { label: KEY_LABEL_MAP[key], content: item };
  }

  if (isObject(item)) {
    Object.keys(item).forEach((key) => {
      const content = item[key];
      const label = KEY_LABEL_MAP[key];

      if (content) {
        acc[key] = {
          type: key,
          label,
          content,
        };
      }
    });
  }

  return acc;
};

/**
 * Create readable sentence from array of strings and objects
 * @param action
 * @returns {{}}
 */
export const humanizeExternalFileAction = (action) => {
  const source = action?.content || action || {};

  const include = source?.include?.[0] || {};

  return Array.isArray(include)
    ? include?.reduce(humanizeIncludeArrayItem, {})
    : humanizeIncludeArrayItem({}, include);
};

/**
 * Convert object to humanly readable text
 * @param actions
 * @returns {*}
 */
export const humanizeActions = (actions = []) =>
  actions.map(humanizeExternalFileAction).filter((res) => !isEmpty(res));
