import { s__ } from '~/locale';

export const LENGTH = 'length';
export const COMMON = 'common';
export const USER_INFO = 'user_info';
export const NUMBER = 'number';
export const UPPERCASE = 'uppercase';
export const LOWERCASE = 'lowercase';
export const SYMBOL = 'symbol';
export const INVALID_FORM_CLASS = 'show-password-complexity-errors';
export const INVALID_INPUT_CLASS = 'password-complexity-error-outline';
export const PASSWORD_REQUIREMENTS_ID = 'password-requirements';
export const RED_TEXT_CLASS = 'gl-text-danger';
export const GREEN_TEXT_CLASS = 'gl-text-success';

export const I18N = {
  PASSWORD_SATISFIED: s__('Password|Satisfied'),
  PASSWORD_NOT_SATISFIED: s__('Password|Not satisfied'),
  PASSWORD_TO_BE_SATISFIED: s__('Password|To be satisfied'),
};
export const PASSWORD_RULE_MAP = {
  [LENGTH]: {
    reg: /^.{8,128}$/u,
    text: s__('Password|must be between 8-128 characters'),
  },
  [COMMON]: {
    text: s__('Password|cannot use common phrases (e.g. "password")'),
  },
  [USER_INFO]: {
    text: s__('Password|cannot include your name, username, or email'),
  },
  [NUMBER]: {
    reg: /\p{N}/u,
    text: s__('Password|requires at least one number'),
  },
  [LOWERCASE]: {
    reg: /\p{Lower}/u,
    text: s__('Password|requires at least one lowercase letter'),
  },
  [UPPERCASE]: {
    reg: /\p{Upper}/u,
    text: s__('Password|requires at least one uppercase letter'),
  },
  [SYMBOL]: {
    reg: /[^\p{N}\p{Upper}\p{Lower}]/u,
    text: s__('Password|requires at least one symbol character'),
  },
};
