import { s__ } from '~/locale';

// Untranslated grouping and sorting keys; CATEGORY_LABELS supplies the displayed names.
export const CATEGORY_ENFORCEMENT = 'enforcement';
export const CATEGORY_ADVANCED = 'advanced';
export const CATEGORY_GENERAL = 'general';
export const CATEGORY_DEPLOYMENT = 'deployment';
export const CATEGORY_SECURITY = 'security';
export const CATEGORY_PROCESS = 'process';
export const CATEGORY_AI = 'ai';
export const CATEGORY_CI_CD = 'ci_cd';
export const CATEGORY_CODE = 'code';
export const CATEGORY_COMPLIANCE = 'compliance';
export const CATEGORY_ACCESS = 'access';
export const CATEGORY_INTEGRATIONS = 'integrations';

export const CATEGORY_ORDER = [
  CATEGORY_ENFORCEMENT,
  CATEGORY_ADVANCED,
  CATEGORY_GENERAL,
  CATEGORY_DEPLOYMENT,
  CATEGORY_SECURITY,
  CATEGORY_PROCESS,
  CATEGORY_AI,
  CATEGORY_CI_CD,
  CATEGORY_CODE,
  CATEGORY_COMPLIANCE,
  CATEGORY_ACCESS,
  CATEGORY_INTEGRATIONS,
];

export const CATEGORY_LABELS = {
  [CATEGORY_ENFORCEMENT]: s__('PolicyStore|Enforcement'),
  [CATEGORY_ADVANCED]: s__('PolicyStore|Advanced'),
  [CATEGORY_DEPLOYMENT]: s__('PolicyStore|Deployment'),
  [CATEGORY_CI_CD]: s__('PolicyStore|CI/CD'),
};
