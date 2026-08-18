import { __ } from '~/locale';
import {
  COMMENT_TEMPLATES_KEYS as COMMENT_TEMPLATES_KEYS_FOSS,
  COMMENT_TEMPLATES_TITLES as COMMENT_TEMPLATES_TITLES_FOSS,
} from '~/vue_shared/components/markdown/constants';

export {
  TRACKING_SAVED_REPLIES_USE,
  TRACKING_SAVED_REPLIES_USE_IN_MR,
  TRACKING_SAVED_REPLIES_USE_IN_OTHER,
} from '~/vue_shared/components/markdown/constants';

export const COMMENT_TEMPLATES_KEYS = [...COMMENT_TEMPLATES_KEYS_FOSS, 'project', 'group'];
export const COMMENT_TEMPLATES_TITLES = {
  ...COMMENT_TEMPLATES_TITLES_FOSS,
  project: __('Project'),
  group: __('Group'),
};
