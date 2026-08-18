import { n__, s__ } from '~/locale';
import { DOCS_URL } from '~/constants';

export const SYNTAX_ERRORS_TEXT = (count) =>
  n__(
    'CodeownersValidation|Contains %d syntax error.',
    'CodeownersValidation|Contains %d syntax errors.',
    count,
  );

export const SYNTAX_VALID = s__('CodeownersValidation|Syntax is valid.');

export const DOCS_LINK_TEXT = s__('CodeownersValidation|How are errors handled?');

export const SHOW_ERRORS = s__('CodeownersValidation|Show errors');

export const HIDE_ERRORS = s__('CodeownersValidation|Hide errors');

export const COLLAPSE_ID = 'CODEOWNERS_VALIDATION_COLLAPSE';

export const LINE = s__('CodeownersValidation|Line');

export const ERROR_MESSAGE = s__(
  'CodeownersValidation|An error occurred while loading the validation errors. Please try again later.',
);

export const ERROR_HANDLING_DOCS_URL = `${DOCS_URL}/user/project/codeowners/advanced.html#error-handling`;

export const CODEOWNERS_VALIDATION_I18N = {
  syntaxValid: SYNTAX_VALID,
  syntaxErrors: SYNTAX_ERRORS_TEXT,
  show: SHOW_ERRORS,
  hide: HIDE_ERRORS,
  docsLink: DOCS_LINK_TEXT,
  line: LINE,
  errorMessage: ERROR_MESSAGE,
};

export const GROUP_WITHOUT_ELIGIBLE_APPROVERS = s__(
  'CodeownersValidation|Group has no members with permission to approve merge requests',
);

export const INACCESSIBLE_OWNER = s__(
  'CodeownersValidation|Contains owners which are not accessible within the project',
);

export const INVALID_APPROVAL_REQUIREMENT = s__(
  'CodeownersValidation|Less than 1 required approvals',
);

export const INVALID_ENTRY_OWNER_FORMAT = s__('CodeownersValidation|Entries with spaces');

export const INVALID_SECTION_FORMAT = s__('CodeownersValidation|Unparsable sections');

export const INVALID_SECTION_OWNER_FORMAT = s__('CodeownersValidation|Inaccessible owners');

export const MALFORMED_ENTRY_OWNER = s__('CodeownersValidation|Malformed owners');

export const MISSING_ENTRY_OWNER = s__('CodeownersValidation|Zero owners');

export const MISSING_SECTION_NAME = s__('CodeownersValidation|Missing section name');

export const OWNER_WITHOUT_PERMISSION = s__(
  'CodeownersValidation|Contains owners without permission to approve merge requests',
);

export const UNQUALIFIED_GROUP = s__(
  'CodeownersValidation|Group needs at least Developer access to the project for its members to approve merge requests',
);

export const CODE_TO_MESSAGE = {
  group_without_eligible_approvers: GROUP_WITHOUT_ELIGIBLE_APPROVERS,
  inaccessible_owner: INACCESSIBLE_OWNER,
  invalid_approval_requirement: INVALID_APPROVAL_REQUIREMENT,
  invalid_entry_owner_format: INVALID_ENTRY_OWNER_FORMAT,
  invalid_section_format: INVALID_SECTION_FORMAT,
  invalid_section_owner_format: INVALID_SECTION_OWNER_FORMAT,
  malformed_entry_owner: MALFORMED_ENTRY_OWNER,
  missing_entry_owner: MISSING_ENTRY_OWNER,
  missing_section_name: MISSING_SECTION_NAME,
  owner_without_permission: OWNER_WITHOUT_PERMISSION,
  unqualified_group: UNQUALIFIED_GROUP,
};
