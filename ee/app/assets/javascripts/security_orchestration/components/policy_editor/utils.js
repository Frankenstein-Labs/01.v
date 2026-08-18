import { intersection, isNumber, isObject, uniqBy, isEmpty } from 'lodash-es';
import { isValidCron } from 'cron-validator';
import { safeDump } from 'js-yaml';
import { sprintf, s__, __ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { projectMergeRequestPath } from '~/lib/utils/path_helpers/merge_requests';
import { groupSecurityComplianceDashboardFrameworkPath } from 'ee/lib/utils/path_helpers/group';
import createPolicyProjectAsync from 'ee/security_orchestration/graphql/mutations/create_policy_project_async.mutation.graphql';
import createPolicy from 'ee/security_orchestration/graphql/mutations/create_policy.mutation.graphql';
import getFile from 'ee/security_orchestration/graphql/queries/get_file.query.graphql';
import { gqClient } from 'ee/security_orchestration/utils';
import createMergeRequestMutation from '~/graphql_shared/mutations/create_merge_request.mutation.graphql';

import {
  ALLOWED,
  DENIED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import {
  BRANCHES_KEY,
  BRANCH_TYPE_KEY,
  DEFAULT_MR_TITLE,
  PRIMARY_POLICY_KEYS,
  RULE_MODE_SCANNERS,
  SECURITY_POLICY_ACTIONS,
  ALL_SELECTED_LABEL,
  SELECTED_ITEMS_LABEL,
  MULTIPLE_SELECTED_LABEL,
  MULTIPLE_SELECTED_LABEL_SINGLE_OPTION,
  MORE_LABEL,
} from './constants';

/**
 * Checks if an error exists and throws it if it does
 * @param {Object} payload contains the errors if they exist
 */
const checkForErrors = ({ errors, validationErrors }) => {
  if (errors?.length) {
    throw new Error(errors.join('\n'), { cause: validationErrors });
  }
};

/**
 * Creates a merge request for the changes to the policy file
 * @param {Object} payload contains the path to the parent project, the branch to merge on the project, and the branch to merge into
 * @returns {Object} contains the id of the merge request and any errors
 */
const createMergeRequest = async ({
  projectPath,
  sourceBranch,
  targetBranch,
  title = DEFAULT_MR_TITLE,
  description = '',
}) => {
  const input = {
    projectPath,
    sourceBranch,
    targetBranch,
    title,
    description,
    removeSourceBranch: true,
  };

  const {
    data: {
      mergeRequestCreate: {
        mergeRequest: { iid: id },
        errors,
      },
    },
  } = await gqClient.mutate({
    mutation: createMergeRequestMutation,
    variables: { input },
  });

  return { id, errors };
};

/**
 * Creates a new security policy on the security policy project's policy file
 * @param {Object} payload contains the path to the project and the policy yaml value
 * @returns {Object} contains the branch containing the updated policy file and any errors
 */
const updatePolicy = async ({
  action = SECURITY_POLICY_ACTIONS.APPEND,
  name,
  namespacePath,
  yamlEditorValue,
}) => {
  const {
    data: {
      scanExecutionPolicyCommit: { branch, errors, validationErrors },
    },
  } = await gqClient.mutate({
    mutation: createPolicy,
    variables: {
      mode: action,
      name,
      fullPath: namespacePath,
      policyYaml: yamlEditorValue,
    },
  });

  return { branch, errors, validationErrors };
};

/**
 * Updates the assigned security policy project's policy file with the new policy yaml or creates one file if one does not exist
 * @param {Object} payload contains the currently assigned security policy project (if one exists), the path to the project, and the policy yaml value
 * @returns {Object} contains the currently assigned security policy project and the created merge request
 */
export const modifyPolicy = async ({
  action,
  assignedPolicyProject,
  name,
  namespacePath,
  yamlEditorValue,
  extraMergeRequestInput,
}) => {
  const newPolicyCommitBranch = await updatePolicy({
    action,
    name,
    namespacePath,
    yamlEditorValue,
  });
  const { title, description } = extraMergeRequestInput ?? {};

  checkForErrors(newPolicyCommitBranch);

  const mergeRequest = await createMergeRequest({
    projectPath: assignedPolicyProject.fullPath,
    sourceBranch: newPolicyCommitBranch.branch,
    targetBranch: assignedPolicyProject.branch,
    title,
    description,
  });

  checkForErrors(mergeRequest);

  return mergeRequest;
};

export const redirectToMergeRequest = ({ mergeRequestId, assignedPolicyProjectFullPath }) => {
  visitUrl(projectMergeRequestPath(assignedPolicyProjectFullPath, mergeRequestId));
};

export const goToPolicyMR = async ({
  action,
  assignedPolicyProject,
  name,
  namespacePath,
  yamlEditorValue,
  extraMergeRequestInput,
}) => {
  const mergeRequest = await modifyPolicy({
    action,
    assignedPolicyProject,
    name,
    namespacePath,
    yamlEditorValue,
    extraMergeRequestInput,
  });

  redirectToMergeRequest({
    mergeRequestId: mergeRequest.id,
    assignedPolicyProjectFullPath: assignedPolicyProject.fullPath,
  });
};

/**
 * Creates a new security policy project via background worker
 * @param {String} fullPath
 */
export const assignSecurityPolicyProjectAsync = async (fullPath) => {
  const {
    data: {
      securityPolicyProjectCreateAsync: { errors },
    },
  } = await gqClient.mutate({
    mutation: createPolicyProjectAsync,
    variables: {
      fullPath,
    },
  });

  checkForErrors({ errors });
};

/**
 * Converts scanner strings to title case
 * @param {Array} scanners (e.g. 'container_scanning', `dast`, etcetera)
 * @returns {Array} (e.g. 'Container Scanning', `Dast`, etcetera)
 */
export const createHumanizedScanners = (scanners = []) =>
  scanners.map((scanner) => {
    const key = isObject(scanner) ? scanner.type : scanner;
    return RULE_MODE_SCANNERS[key] || key || '';
  });

/**
 * Rule can not have both keys simultaneously
 * @param rule
 */
export const ruleHasConflictingKeys = (rule) => {
  return BRANCH_TYPE_KEY in rule && BRANCHES_KEY in rule;
};

/**
 * Rule can not have both keys simultaneously
 * @param rules
 */
export const hasConflictingKeys = (rules) => {
  return (rules || []).some((rule) => BRANCH_TYPE_KEY in rule && BRANCHES_KEY in rule);
};

/**
 * Check if object has invalid keys in structure
 * @param object
 * @param allowedValues list of allowed values
 * @param useValues use values instead of keys
 * @returns {boolean} true if object is invalid
 */
export const hasInvalidKey = (object, allowedValues, useValues = false) => {
  const itemsFn = useValues ? Object.values : Object.keys;

  return !itemsFn(object).every((item) => allowedValues.includes(item));
};

/**
 * Checks for parameters unsupported by the policy "Rule Mode"
 * @param {Object} policy policy converted from YAML
 * @param {Array} primaryKeys list of primary policy keys
 * @param {Array} rulesKeys list of allowed keys for policy rule
 * @param {Array} actionsKeys list of allowed keys for policy rule
 * @returns {Boolean} whether the YAML is valid to be parsed into "Rule Mode"
 */
export const isValidPolicy = ({
  policy = {},
  primaryKeys = PRIMARY_POLICY_KEYS,
  rulesKeys = [],
  actionsKeys = [],
}) => {
  return !(
    hasInvalidKey(policy, primaryKeys) ||
    policy.rules?.some((rule) => hasInvalidKey(rule, [...rulesKeys, 'id'])) ||
    policy.rules?.some(ruleHasConflictingKeys) ||
    policy.actions?.some((action) => hasInvalidKey(action, [...actionsKeys, 'id']))
  );
};

/**
 * Replaces whitespace and non-sluggish characters with a given separator
 * @param {String} str - The string to slugify
 * @param {String=} separator - The separator used to separate words (defaults to "-")
 * @returns {String}
 */
export const slugify = (str, separator = '-') => {
  const slug = str
    .trim()
    .replace(/[^a-zA-Z0-9_.*-/]+/g, separator)
    // Remove any duplicate separators or separator prefixes/suffixes
    .split(separator)
    .filter(Boolean)
    .join(separator);

  return slug === separator ? '' : slug;
};

/**
 * Replaces whitespace and non-sluggish characters with a given separator and returns array of values
 * @param {String} branches - comma-separated branches
 * @param {String=} separator - The separator used to separate words (defaults to "-")
 * @returns {String[]}
 */
export const slugifyToArray = (branches, separator = '-') =>
  branches
    .split(',')
    .map((branch) => slugify(branch, separator))
    .filter(Boolean);

/**
 * Validate cadence cron string if it exists in rule
 * @param rules policy rules
 * @returns {Boolean}
 */
export const hasInvalidCron = (rules = []) => {
  const hasInvalidCronString = (cronString) => (cronString ? !isValidCron(cronString) : false);

  return rules.some((rule) => hasInvalidCronString(rule?.cadence));
};

export const enforceIntValue = (value) => parseInt(value || '0', 10);

const NO_ITEM_SELECTED = 0;
const ONE_ITEM_SELECTED = 1;

/**
 * Renders either itemA + n items or ItemA, itemB + n pattern
 * @param useSingleOption flag difference what pattern to choose
 * @param commonItems common items between total items and selected items
 * @param items total items from selection
 * @returns {*}
 */
export const renderMultiselectLabel = ({
  useSingleOption = false,
  commonItems = [],
  items = {},
} = {}) => {
  if (commonItems.length === 0) return '';

  const TEXT_TEMPLATE = useSingleOption
    ? MULTIPLE_SELECTED_LABEL_SINGLE_OPTION
    : MULTIPLE_SELECTED_LABEL;
  const NUMBER_TO_EXTRACT = useSingleOption ? 1 : 2;

  const moreLabel =
    commonItems.length > NUMBER_TO_EXTRACT
      ? sprintf(MORE_LABEL, { numberOfAdditionalLabels: commonItems.length - NUMBER_TO_EXTRACT })
      : undefined;

  return sprintf(TEXT_TEMPLATE, {
    firstLabel: items[commonItems[0]],
    ...(useSingleOption ? {} : { secondLabel: items[commonItems[1]] }),
    moreLabel,
  }).trim();
};

/**
 * This method returns text based on selected items
 * For single selected option it is (itemA +n selected items)
 * For multiple selected options it is (itemA, itemB +n selected items)
 * When all options selected, text would indicate that all items are selected
 * @param selected items
 * @param items items used to render list
 * @param itemTypeName
 * @param useAllSelected all selected option can be disabled
 * @param useSingleOption use format `itemA +n` (Default is `itemA, itemB +n`)
 * @returns {*}
 */
export const renderMultiSelectText = ({
  selected,
  items,
  itemTypeName,
  useAllSelected = true,
  useSingleOption = false,
}) => {
  const itemsKeys = Object.keys(items);
  const itemsKeysLength = itemsKeys.length;

  const defaultPlaceholder = sprintf(
    SELECTED_ITEMS_LABEL,
    {
      itemTypeName,
    },
    false,
  );

  /**
   * Another edge case
   * number of selected items and items are equal
   * but none of them match
   * without this check it would fall through to
   * ALL_SELECTED_LABEL
   * @type {string[]}
   */
  const commonItems = intersection(itemsKeys, selected);
  const commonItemsLength = commonItems.length;
  /**
   * Edge case for loading states when initial items are empty
   */
  if (itemsKeysLength === 0 || commonItemsLength === 0) {
    return defaultPlaceholder;
  }

  const oneItemLabel = items[commonItems[0]] || defaultPlaceholder;
  const multiSelectLabel = renderMultiselectLabel({ useSingleOption, items, commonItems });

  if (commonItemsLength === itemsKeysLength && !useAllSelected) {
    return itemsKeysLength === 1 ? oneItemLabel : multiSelectLabel;
  }

  switch (commonItemsLength) {
    case itemsKeysLength:
      return sprintf(ALL_SELECTED_LABEL, { itemTypeName }, false);
    case NO_ITEM_SELECTED:
      return defaultPlaceholder;
    case ONE_ITEM_SELECTED:
      return oneItemLabel;
    default:
      return multiSelectLabel;
  }
};

/**
 * Create project object based on provided properties
 * @param fullPath
 * @returns {{}}
 */
export const createProjectWithMinimumValues = ({ fullPath }) => ({
  ...(fullPath && { fullPath }),
});

/**
 * Parse configuration file path and create state of UI component
 * @param configuration
 * @returns {{project: {}, showLinkedFile: boolean}}
 */
export const parseCustomFileConfiguration = (configuration = {}) => {
  const projectPath = configuration?.project;
  const hasFilePath = Boolean(configuration?.file);
  const hasRef = Boolean(configuration?.ref);
  const hasProjectPath = Boolean(projectPath);
  const project = hasProjectPath ? createProjectWithMinimumValues({ fullPath: projectPath }) : null;

  return {
    showLinkedFile: hasFilePath || hasRef || hasProjectPath,
    project,
  };
};

/**
 * Convert branch exceptions from yaml editor
 * to list box format
 * @param item
 * @param index
 * @returns {{fullPath: undefined, name: string, value: string}|{fullPath: *, name, value: string}}
 */
export const mapExceptionsListBoxItem = (item, index) => {
  if (!item) return undefined;

  if (typeof item === 'string') {
    return {
      value: `${item}_${index}`,
      name: item,
      fullPath: '',
    };
  }

  const fullPath = item.fullPath || item.full_path || '';

  return {
    value: `${item.name}@${fullPath}`,
    name: item.name,
    fullPath,
  };
};

/**
 * convert branch and full_path to branch
 * full format branch-name@fullPath
 * @param items
 * @param itemKey select property of an objects that is applied before @
 * @returns {*}
 */
export const mapObjectsToString = (items = [], itemKey = 'name') => {
  return items
    .filter(Boolean)
    .map((item) => {
      const { fullPath = '', full_path = '' } = item;
      const prependValue = item[itemKey] || '';

      // eslint-disable-next-line camelcase
      const path = fullPath || full_path;

      return `${prependValue}${path ? '@' : ''}${path}`;
    })
    .filter(Boolean)
    .join(', ');
};

/**
 * Validate branch full format branch-name@fullPath
 * @param value string input
 * @returns {boolean}
 */
export const validateBranchProjectFormat = (value) => {
  const branchProjectRegexp = /\S+@\S/;
  return branchProjectRegexp.test(value);
};

/**
 * Check if branches have duplicates by value
 * @param branches
 * @returns {boolean}
 */
export const hasDuplicates = (branches = []) => {
  if (!branches) return false;

  return uniqBy(branches, 'value').length !== branches?.length;
};

/**
 * Extract branches with wrong format
 * @param items
 * @param key
 * @param mapKey
 * @returns {*[]}
 */
export const findItemsWithErrors = (items = [], key = 'value', mapKey = 'name') => {
  if (!items) return [];

  return items
    ?.filter((item) => !validateBranchProjectFormat(item[key]))
    ?.map((item) => item[mapKey]);
};

/**
 * Map selected branches to exception
 * @param branches
 * @returns {*[]}
 */
export const mapBranchesToExceptions = (branches = []) => {
  if (!branches) return [];

  return branches.map(mapExceptionsListBoxItem).filter(({ name }) => Boolean(name));
};

export const removeIdsFromPolicy = (policy) => {
  const updatedPolicy = { ...policy };

  if (updatedPolicy.actions) {
    updatedPolicy.actions = policy.actions?.map(({ id, ...action }) => ({ ...action }));
  }

  if (updatedPolicy.rules) {
    updatedPolicy.rules = policy.rules?.map(({ id, ...rule }) => ({ ...rule }));
  }

  return updatedPolicy;
};

const enabledRadioButtonTooltipText = s__(
  "SecurityOrchestration|You've reached the maximum limit of %{max} %{type} policies allowed. Policies are disabled when added.",
);

export const getPolicyLimitDetails = ({
  type,
  policyLimitReached = false,
  policyLimit = 5,
  initialValue,
}) => {
  const shouldBeDisabled = policyLimitReached && !initialValue;
  const sprintfParameters = { type, max: policyLimit };

  return {
    radioButton: {
      disabled: shouldBeDisabled,
      text: sprintf(enabledRadioButtonTooltipText, sprintfParameters),
    },
  };
};

const isEqualOrUndefined = (value1, value2) => !value1 || value1 === value2;

/**
 * Determine if one of the errors is from the given source
 * @param {Array} errorSources array of [primaryKey, index, location]
 * @param {String} primaryKey a primary key in the policy
 * @param {Number} index the index of the action/rule/condition
 * @param {String} location the sub-location inside the primary key
 * @returns {Boolean}
 */
export const isCauseOfError = ({ errorSources, primaryKey, index = 0, location }) => {
  return errorSources.some(([sourcePrimaryKey, sourceIndex, sourceLocation]) => {
    return (
      isEqualOrUndefined(primaryKey, sourcePrimaryKey) &&
      isEqualOrUndefined(index, Number(sourceIndex)) &&
      isEqualOrUndefined(location, sourceLocation)
    );
  });
};

/**
 * Parses error from the backend and returns an array of [primaryKey, index, location]
 * @param {Object} error https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error with
 * message of form `"property '/approval_policy/5/rules/0/type' is not one of: [\"scan_finding\", \"license_finding\", \"any_merge_request\"]"`
 * @returns {Array} e.g. [['rules', 0, 'type']]
 */
// Matches JSON schema path error lines, e.g. property '/policy/0/rules/0/type' is not one of: [...]
// Allows optional leading whitespace to handle minor formatting variation in error messages.
export const SCHEMA_PATH_ERROR_PATTERN = /^\s*property '\//;

// e.g. '/approval_policy/5/rules/0/type'.split('/') =>
//   ['', 'approval_policy', '5', 'rules', '0', 'type']
//    ^--- skip these 3 ----^    ^--- extract these 3 ---^
const SCHEMA_ERROR_PATH_OFFSET = 3;
const SCHEMA_ERROR_PATH_SEGMENT_COUNT = 3;

export const parseError = (error) => {
  if (!error) return [];

  try {
    const [, ...messages] = error.message.split('\n');
    return messages
      .filter((e) => SCHEMA_PATH_ERROR_PATTERN.test(e))
      .map((e) =>
        e
          .split(`'`)[1]
          .split(`/`)
          .splice(SCHEMA_ERROR_PATH_OFFSET, SCHEMA_ERROR_PATH_SEGMENT_COUNT),
      );
  } catch {
    return [];
  }
};

/**
 * Check if file exist on particular branch in particular project
 * @param fullPath full path to a project
 * @param ref branch name
 * @param filePath full file name
 * @returns {Promise<boolean>}
 */
export const doesFileExist = async ({ fullPath = {}, ref = null, filePath = '' } = {}) => {
  try {
    const { data } = await gqClient.query({
      query: getFile,
      variables: {
        fullPath,
        filePath,
        ref,
      },
    });

    return data?.project?.repository?.blobs?.nodes?.length > 0;
  } catch {
    return false;
  }
};

/**
 * Generates custom merge request title and description if compliance framework params present
 * @param params URL params
 * @param context context of generation request, including top level group path
 *
 * @returns {Object | null}
 */
export const getMergeRequestConfig = (params = {}, context = {}) => {
  const {
    compliance_framework_name: frameworkName,
    compliance_framework_id: frameworkIdString,
    path,
  } = params;
  const { namespacePath } = context;

  if (!frameworkName || !frameworkIdString || !path || !namespacePath) {
    return null;
  }
  const frameworkLink = groupSecurityComplianceDashboardFrameworkPath(
    namespacePath,
    frameworkIdString,
  );

  const title = s__(
    'SecurityOrchestration|Compliance pipeline migration to pipeline execution policy',
  );

  const migrationInfo = sprintf(
    s__(
      'SecurityOrchestration|This merge request migrates compliance pipeline `%{path}` to a pipeline execution policy scoped to framework [%{framework}](%{link}).',
    ),
    {
      path,
      framework: frameworkName,
      link: frameworkLink,
    },
  );

  const continueToOverwriteWarning = s__(
    'SecurityOrchestration|The compliance pipeline will continue to override the new pipeline execution policy until it is removed from the compliance framework configuration.',
  );

  const backLinkMessage = sprintf(
    s__(
      'SecurityOrchestration|After this merge request is merged, go to [%{framework}](%{link}) and remove the compliance pipeline so that the new pipeline execution policy can take precedence.',
    ),
    {
      framework: frameworkName,
      link: frameworkLink,
    },
  );

  return {
    title,
    description: [migrationInfo, continueToOverwriteWarning, backLinkMessage].join('\n\n'),
  };
};

export const policyBodyToYaml = (policy) => {
  return safeDump(removeIdsFromPolicy(policy), { noRefs: true });
};

/**
 * Return yaml representation of a policy.
 * @param policy
 * @param type
 * @returns {string}
 */
export const policyToYaml = (policy, type) => {
  const policyWithoutIds = removeIdsFromPolicy(policy);
  const hasLegacyTypeRootProperty = 'type' in policyWithoutIds;

  if (hasLegacyTypeRootProperty) {
    delete policyWithoutIds.type;
  }

  const payload = { [type]: [policyWithoutIds] };

  try {
    return safeDump(payload, { noRefs: true });
  } catch (error) {
    captureException(error);
    return '';
  }
};

/**
 * Parse licenses from rule
 * @param rule
 * @returns {{licenses: (*|*[]), isDenied: boolean}}
 */
export const parseAllowDenyLicenseList = (rule = {}) => {
  const { licenses = {} } = rule || {};
  const isDenied = DENIED in licenses;
  const KEY = isDenied ? DENIED : ALLOWED;

  const resultingLicenses = (licenses?.[KEY] || []).map((license) => ({
    license: { value: license.name, text: license.name },
    exceptions: license?.packages?.excluding?.purls || [],
  }));

  return {
    licenses: resultingLicenses,
    isDenied,
  };
};

/**
 * map licenses format from component to yaml
 * @param licenses
 * @returns {{name: *}[]}
 */
export const mapComponentLicenseFormatToYaml = (licenses = []) =>
  (licenses || []).map(({ license = {}, exceptions = [] }) => {
    const licenseName = { name: license.value };

    if (exceptions.length === 0) {
      return licenseName;
    }

    return {
      ...licenseName,
      packages: { excluding: { purls: exceptions } },
    };
  });

/**
 * find intersection in two collections or return original item
 * @param collectionOne
 * @param collectionTwo
 * @param mapperFn
 * @param type
 * @returns {(*)[]|*[]}
 */
export const findItemsIntersection = ({
  collectionOne = [],
  collectionTwo = [],
  mapperFn,
  type,
}) => {
  if (!mapperFn) {
    return [];
  }

  return collectionOne
    .map((approver) => {
      if (isNumber(approver)) {
        const mappedId = type ? convertToGraphQLId(type, approver) : approver;

        const item = collectionTwo.find(({ id }) => id === mappedId) || {};
        return mapperFn(item);
      }

      return mapperFn(approver);
    })
    .filter((item) => !isEmpty(item));
};

/**
 * split string by comma and white space
 * @param source
 * @returns {*|*[]}
 */
export const splitItemsByCommaOrSpace = (source) => source?.split(/[\n ,]+/).filter(Boolean) || [];

/**
 * parse string based on @ and find parsed items with failed validation
 * @param items array of strings in name@path format
 * @returns {{parsedExceptions: {file: string, fullPath: string, value: *}[], parsedWithErrorsExceptions: *[]}}
 */
export const parseExceptionsStringToItems = (items = []) => {
  const parsedExceptions = (items || []).map((item) => {
    const [file = '', fullPath = ''] = item.split('@');

    return {
      file,
      fullPath,
      value: item,
    };
  });

  const parsedWithErrorsExceptions = findItemsWithErrors(parsedExceptions, 'value', 'file');

  return {
    parsedExceptions,
    parsedWithErrorsExceptions,
  };
};

export const getHostname = () => window?.location?.host || __('your GitLab instance');
