import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';

import {
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
} from './constants';

export const getComponentNameForType = (reportType) =>
  `ReportType${capitalizeFirstCharacter(reportType)}`;

export const REPORT_COMPONENTS = {
  [getComponentNameForType(REPORT_TYPE_LIST)]: () => import('./report_type_list.vue'),
  [getComponentNameForType(REPORT_TYPE_URL)]: () => import('./report_type_url.vue'),
  [getComponentNameForType(REPORT_TYPE_DIFF)]: () => import('./report_type_diff.vue'),
  [getComponentNameForType(REPORT_TYPE_NAMED_LIST)]: () => import('./report_type_named_list.vue'),
  [getComponentNameForType(REPORT_TYPE_TEXT)]: () => import('./report_type_value.vue'),
  [getComponentNameForType(REPORT_TYPE_VALUE)]: () => import('./report_type_value.vue'),
  [getComponentNameForType(REPORT_TYPE_MODULE_LOCATION)]: () =>
    import('./report_type_module_location.vue'),
  [getComponentNameForType(REPORT_TYPE_FILE_LOCATION)]: () =>
    import('./report_type_file_location.vue'),
  [getComponentNameForType(REPORT_TYPE_TABLE)]: () => import('./report_type_table.vue'),
  [getComponentNameForType(REPORT_TYPE_CODE)]: () => import('./report_type_code.vue'),
  [getComponentNameForType(REPORT_TYPE_MARKDOWN)]: () =>
    import('~/vue_shared/components/markdown/markdown_content.vue'),
  [getComponentNameForType(REPORT_TYPE_COMMIT)]: () => import('./report_type_commit.vue'),
};
