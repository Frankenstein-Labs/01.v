export const REPORT_TYPE_LIST = 'list';
export const REPORT_TYPE_URL = 'url';
export const REPORT_TYPE_DIFF = 'diff';
export const REPORT_TYPE_NAMED_LIST = 'named-list';
export const REPORT_TYPE_TEXT = 'text';
export const REPORT_TYPE_VALUE = 'value';
export const REPORT_TYPE_MODULE_LOCATION = 'module-location';
export const REPORT_TYPE_FILE_LOCATION = 'file-location';
export const REPORT_TYPE_TABLE = 'table';
export const REPORT_TYPE_CODE = 'code';
export const REPORT_TYPE_MARKDOWN = 'markdown';
export const REPORT_TYPE_COMMIT = 'commit';

export const REPORT_TYPES = [
  REPORT_TYPE_LIST,
  REPORT_TYPE_URL,
  REPORT_TYPE_DIFF,
  REPORT_TYPE_NAMED_LIST,
  REPORT_TYPE_TEXT,
  REPORT_TYPE_VALUE,
  REPORT_TYPE_MODULE_LOCATION,
  REPORT_TYPE_FILE_LOCATION,
  REPORT_TYPE_TABLE,
  REPORT_TYPE_CODE,
  REPORT_TYPE_MARKDOWN,
  REPORT_TYPE_COMMIT,
];

/*
 * Diff component
 */
const DIFF = 'diff';
const BEFORE = 'before';
const AFTER = 'after';

export const VIEW_TYPES = { DIFF, BEFORE, AFTER };

const NORMAL = 'normal';
const REMOVED = 'removed';
const ADDED = 'added';

export const LINE_TYPES = { NORMAL, REMOVED, ADDED };
