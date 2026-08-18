import { isEmpty, isEqual, uniqBy, uniqueId } from 'lodash-es';
import {
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_SECRET_DETECTION,
} from '~/vue_shared/security_reports/constants';
import { createPolicyObject } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import { policyToYaml } from 'ee/security_orchestration/components/policy_editor/utils';
import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';

// Maps a scan type to the template that should be enforced by default
// for newly created policies. Defaults to 'latest' for any scan type
// not explicitly listed.
const DEFAULT_OPTIMIZED_TEMPLATE_BY_SCANNER = {
  [REPORT_TYPE_DEPENDENCY_SCANNING]: 'v2',
};

const DEFAULT_OPTIMIZED_TEMPLATE = 'latest';

const optimizedTemplateForScanner = (scanner) =>
  DEFAULT_OPTIMIZED_TEMPLATE_BY_SCANNER[scanner] ?? DEFAULT_OPTIMIZED_TEMPLATE;

export const buildScannerAction = ({
  scanner,
  siteProfile = '',
  scannerProfile = '',
  id,
  isOptimized = false,
  withDefaultVariables = false,
}) => {
  const action = { scan: scanner, id: id ?? uniqueId('action_') };

  if (withDefaultVariables) {
    action.variables = { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' };
  }

  if (scanner === REPORT_TYPE_DAST) {
    action.site_profile = siteProfile;
    action.scanner_profile = scannerProfile;
  }

  if (isOptimized) {
    action.template = optimizedTemplateForScanner(scanner);
  }

  return action;
};

const ACTION_TYPES_REQUIRING_VARIABLE = [
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_SECRET_DETECTION,
];

/**
 * Add or remove SECURE_ENABLE_LOCAL_CONFIGURATION variable based on scan type
 * ACTION_TYPES_REQUIRING_VARIABLE is a list of scan types requiring variable
 * @param policy
 * @returns Object policy with refined variables
 */
export const addDefaultVariablesToPolicy = ({ policy = {} } = {}) => {
  if (!policy) return {};

  const { actions = [] } = policy;
  return {
    ...policy,
    actions: actions.map((action) => {
      const hasDefaultVariable = 'SECURE_ENABLE_LOCAL_CONFIGURATION' in (action.variables || {});

      // Case 1: Add the variable for required scan types
      if (ACTION_TYPES_REQUIRING_VARIABLE.includes(action.scan)) {
        const variableValue = hasDefaultVariable
          ? action.variables.SECURE_ENABLE_LOCAL_CONFIGURATION
          : 'false';

        return {
          ...action,
          variables: {
            ...action.variables,
            SECURE_ENABLE_LOCAL_CONFIGURATION: variableValue,
          },
        };
      }

      // Case 2: Remove the variable if it exists
      if (hasDefaultVariable) {
        const { SECURE_ENABLE_LOCAL_CONFIGURATION, ...remainingVariables } = action.variables;

        // If no variables remain, remove the entire variables property
        if (isEmpty(remainingVariables)) {
          const { variables, ...actionWithoutVariables } = action;
          return actionWithoutVariables;
        }

        return {
          ...action,
          variables: remainingVariables,
        };
      }

      // Case 3: No changes needed
      return action;
    }),
  };
};

/**
 * Add default variable for specific scan types
 * @param manifest yaml policy file
 * @returns {string} yaml with added variable
 */
export const addDefaultVariablesToManifest = ({ manifest } = {}) => {
  const { policy } = createPolicyObject(manifest, false);
  return policyToYaml(addDefaultVariablesToPolicy({ policy }), SCAN_EXECUTION_POLICY_TYPE);
};

// Action scans must be unique (e.g. only one of each scan type)
export const hasUniqueScans = (actions) => uniqBy(actions, 'scan').length === actions.length;

//  DAST scans are too complex for the optimized path
export const hasOnlyAllowedScans = (actions) =>
  actions.every(({ scan }) => scan !== REPORT_TYPE_DAST);

// Each action must be optimized (e.g. template equals the default template for the scan
// type, no runner tags or CI variables)
export const hasSimpleScans = (actions) => {
  return actions.every((action) => {
    const { id, scan, variables, ...rest } = action;
    return isEqual(rest, { template: optimizedTemplateForScanner(scan) });
  });
};
