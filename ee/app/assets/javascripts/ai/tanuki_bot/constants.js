import { s__ } from '~/locale';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import { CHAT_MODES } from '~/super_sidebar/constants';

export const MESSAGE_TYPES = {
  USER: GENIE_CHAT_MODEL_ROLES.user,
  TANUKI: GENIE_CHAT_MODEL_ROLES.assistant,
};

export const SOURCE_TYPES = {
  HANDBOOK: {
    value: 'handbook',
    icon: 'book',
  },
  DOC: {
    value: 'doc',
    icon: 'documents',
  },
  BLOG: {
    value: 'blog',
    icon: 'list-bulleted',
  },
};

export const ERROR_MESSAGE = s__(
  'DuoChat|There was an error communicating with GitLab Duo Chat. Please try again later.',
);

export const TANUKI_BOT_TRACKING_EVENT_NAME = 'ask_gitlab_chat';
export const TANUKI_BOT_FEEDBACK_ISSUE_URL = 'https://gitlab.com/gitlab-org/gitlab/-/issues/408527';

export const WIDTH_OFFSET = 10;
export const MULTI_THREADED_CONVERSATION_TYPE = 'DUO_CHAT';

// GraphQL type for classic chat thread GIDs. The router path carries the
// numeric id; the GraphQL layer needs the full GID.
export const TYPENAME_AI_CONVERSATION_THREAD = 'Ai::Conversation::Thread';

export const DUO_AGENTIC_MODE_COOKIE = 'duo_agentic_mode_on';
export const DUO_AGENTIC_MODE_COOKIE_EXPIRATION = 365 * 10;

// Re-export CHAT_MODES for backward compatibility
export { CHAT_MODES };

/* eslint-disable @gitlab/no-hardcoded-urls -- False positive, not a URL */
export const CHAT_RESET_MESSAGE = '/reset';
export const CHAT_CLEAR_MESSAGE = '/clear';
export const CHAT_NEW_MESSAGE = '/new';
export const CHAT_INCLUDE_MESSAGE = '/include';
/* eslint-enable @gitlab/no-hardcoded-urls */
export const CHAT_BASE_COMMANDS = [CHAT_RESET_MESSAGE, CHAT_CLEAR_MESSAGE, CHAT_NEW_MESSAGE];

export const MAX_PROMPT_LENGTH = 16384;
export const PROMPT_LENGTH_WARNING = MAX_PROMPT_LENGTH - 100;
