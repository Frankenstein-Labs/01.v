import { cloneDeep, isEmpty, isEqual, isObject, omit, uniqueId } from 'lodash-es';
import { s__, sprintf } from '~/locale';
import Api from 'ee/api';
import {
  SEVERITY_LEVEL_CRITICAL,
  SEVERITY_LEVEL_HIGH,
  SEVERITY_LEVELS_KEYS,
  REPORT_TYPES_DEFAULT,
} from 'ee/security_dashboard/constants';
import {
  REPORT_TYPE_SAST,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
} from '~/vue_shared/security_reports/constants';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import {
  ALL_PROTECTED_BRANCHES,
  ANY_COMMIT,
  BRANCH_TYPE_KEY,
  GREATER_THAN_OPERATOR,
  INVALID_PROTECTED_BRANCHES,
  VALID_SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITY_AGE_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  APPROVAL_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  NEW_NEEDS_TRIAGE,
  PREVIOUSLY_EXISTING,
  AGE_INTERVALS,
  VULNERABILITY_AGE_ALLOWED_KEYS,
  ADDITIONAL_VULNERABILITY_ATTRIBUTES,
  VULNERABILITY_ATTRIBUTES,
  ALLOWED,
  EPSS_SCORE,
  FALSE_POSITIVE,
  FIX_AVAILABLE,
  KNOWN_EXPLOITED,
  ENRICHMENT_DATA_UNAVAILABLE,
  ENRICHMENT_DATA_ACTIONS,
} from '../rule/scan_filters/constants';
import { isValidEnrichmentDataAction } from '../rule/scan_filters/utils';

const REPORT_TYPES_KEYS = Object.keys(REPORT_TYPES_DEFAULT);

export const VULNERABILITY_STATE_KEYS = [
  NEWLY_DETECTED,
  ...Object.keys(APPROVAL_VULNERABILITY_STATES[NEWLY_DETECTED]),
  ...Object.keys(APPROVAL_VULNERABILITY_STATES[PREVIOUSLY_EXISTING]),
];
export const ANY_MERGE_REQUEST = 'any_merge_request';
export const SCAN_FINDING = 'scan_finding';
export const LICENSE_FINDING = 'license_finding';
export const MATCHING = s__('ScanResultPolicy|Matching');
export const EXCEPT = s__('ScanResultPolicy|Except');

export const LICENSE_STATES = {
  newly_detected: s__('ScanResultPolicy|Newly Detected'),
  detected: s__('ScanResultPolicy|Pre-existing'),
};

export const DEFAULT_SCANNER_TYPES = [
  REPORT_TYPE_SAST,
  REPORT_TYPE_SECRET_DETECTION,
  REPORT_TYPE_DEPENDENCY_SCANNING,
];

/**
 * Default EPSS threshold: flag vulnerabilities with >10% exploitation probability.
 * This value aligns with industry recommendations for prioritizing remediation.
 * @see https://www.first.org/epss/
 */
export const DEFAULT_EPSS_VALUE = 0.1;

/**
 * Returns a fresh set of vulnerability attributes for scanners that support
 * exploit intelligence (dependency scanning, container scanning).
 * A factory function is used so each scanner gets an independent object,
 * preventing shared-state mutations between scanner types.
 */
const buildExploitVulnerabilityAttributes = () => ({
  vulnerability_attributes: {
    [FALSE_POSITIVE]: false,
    [FIX_AVAILABLE]: true,
    [KNOWN_EXPLOITED]: true,
    [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
    [ENRICHMENT_DATA_UNAVAILABLE]: { action: ENRICHMENT_DATA_ACTIONS.BLOCK },
  },
});

export const SCANNER_DEFAULT_ATTRIBUTES = {
  [REPORT_TYPE_SAST]: {
    vulnerability_attributes: {
      [FALSE_POSITIVE]: false,
    },
  },
  [REPORT_TYPE_DEPENDENCY_SCANNING]: buildExploitVulnerabilityAttributes(),
  [REPORT_TYPE_CONTAINER_SCANNING]: buildExploitVulnerabilityAttributes(),
};

/**
 * Keys that are valid on a scanner object (scanner_with_attributes schema).
 * Used when converting a legacy string scanner to the atomic object format
 * to avoid leaking rule-level fields (e.g. branch_type, branch_exceptions)
 * onto individual scanner objects. Acts as an allowlist of permitted keys.
 */
export const SCANNER_VALID_KEYS = [
  'type',
  'vulnerabilities_allowed',
  'severity_levels',
  'vulnerability_states',
  'vulnerability_attributes',
  'is_malicious',
];

/**
 * Scanner types that support malware blocking via the `is_malicious` attribute.
 */
export const MALWARE_SCANNER_TYPES = [
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
];

// Single source of truth for detecting the malware attribute on a scanner,
// shared by the drawer alert and the policy-list gap indicator so the two
// cannot diverge. Keyed on the canonical `is_malicious` YAML field.
export const isMaliciousScanner = (scanner) => isObject(scanner) && scanner.is_malicious === true;

export const isMalwareEligibleScanner = (scanner) =>
  MALWARE_SCANNER_TYPES.includes(isObject(scanner) ? scanner.type : scanner);

const someScanner = (rules = [], predicate) =>
  rules.some((rule) => (rule?.scanners || []).some(predicate));

// True when a scan-result policy has a dependency/container scanner (so it
// could block malware) regardless of whether malware blocking is enabled.
export const hasMalwareEligibleScanner = (rules = []) =>
  someScanner(rules, isMalwareEligibleScanner);

// True when a scan-result policy already enables malware blocking.
export const hasMalwareBlockingEnabled = (rules = []) => someScanner(rules, isMaliciousScanner);

/**
 * The malware attribute is gated behind the `securityPoliciesMalwareAttribute`
 * feature flag, exposed to the frontend via gon. When the flag is off, scanner
 * objects are built unchanged (no `is_malicious` key).
 */
const isMalwareAttributeEnabled = () =>
  Boolean(window.gon?.features?.securityPoliciesMalwareAttribute);

export const buildDefaultScannerObject = (type) => ({
  type,
  vulnerabilities_allowed: 0,
  severity_levels: [SEVERITY_LEVEL_CRITICAL, SEVERITY_LEVEL_HIGH],
  vulnerability_states: [NEW_NEEDS_TRIAGE],
  ...cloneDeep(SCANNER_DEFAULT_ATTRIBUTES[type] || {}),
  ...(isMalwareAttributeEnabled() && MALWARE_SCANNER_TYPES.includes(type)
    ? { is_malicious: true }
    : {}),
});

export const DEFAULT_SCANNERS = DEFAULT_SCANNER_TYPES.map(buildDefaultScannerObject);

export const RECOMMENDED_SCANNERS_KEY = 'recommended';

/*
  Construct a new rule object.
*/
export const securityScanBuildRule = () => {
  return {
    id: uniqueId('rule_'),
    type: SCAN_FINDING,
    // Deep-clone via factory to prevent shared nested references in vulnerability_attributes.
    // A shallow spread would share the epss_score object by reference across instances.
    scanners: DEFAULT_SCANNER_TYPES.map(buildDefaultScannerObject),
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
    branch_type: ALL_PROTECTED_BRANCHES.value,
  };
};

export const isDefaultScannerConfiguration = (scanner) => {
  const defaultScanner = buildDefaultScannerObject(scanner.type);
  return isEqual(omit(scanner, ['id', 'branch_type']), defaultScanner);
};

/**
 * Checks if the given scanners match the recommended selection (sast, secret_detection,
 * dependency_scanning). This intentionally matches both object and string scanner formats,
 * so manually selecting these 3 types is treated equivalently to using the "Recommended" preset.
 */
export const isRecommendedScannersSelection = (scanners = []) => {
  if (scanners.length !== DEFAULT_SCANNER_TYPES.length) return false;

  const types = scanners.map((s) => (typeof s === 'string' ? s : s.type));
  return DEFAULT_SCANNER_TYPES.every((t) => types.includes(t));
};

/**
 * Resolves the scanner selection from dropdown values.
 * Handles the "Recommended" pseudo-item and "Select all" edge case.
 *
 * @param {Array} values - selected dropdown keys (may include RECOMMENDED_SCANNERS_KEY)
 * @param {Array} currentScanners - current scanner objects/strings on the rule
 * @param {Array} existingScannerObjects - resolved scanner objects for lookup
 * @returns {Array} resolved scanner objects
 */
export const resolveScannersFromSelection = (values, currentScanners, existingScannerObjects) => {
  const hasRecommended = values.includes(RECOMMENDED_SCANNERS_KEY);
  const wasRecommended = isRecommendedScannersSelection(currentScanners);
  const realScannerValues = values.filter((v) => v !== RECOMMENDED_SCANNERS_KEY);
  const allScannersSelected = realScannerValues.length === REPORT_TYPES_KEYS.length;
  const allScannersWereSelected = currentScanners.length === REPORT_TYPES_KEYS.length;

  // User just clicked "Recommended" (it wasn't previously active)
  const userClickedRecommended = hasRecommended && !wasRecommended;
  // "Select All" was triggered — all 7 real scanners are in the selection from a non-all state
  const isSelectAllAction = allScannersSelected && !allScannersWereSelected;

  if (userClickedRecommended && !isSelectAllAction) {
    // Rebuild from type strings to get deep-cloned instances. A shallow spread would
    // share nested vulnerability_attributes by reference, corrupting DEFAULT_SCANNERS.
    return DEFAULT_SCANNER_TYPES.map(buildDefaultScannerObject);
  }

  return realScannerValues.map((value) => {
    if (isObject(value)) {
      return value;
    }

    const existing = existingScannerObjects.find(({ type }) => type === value);
    // Deep-clone existing scanner objects so the caller can safely mutate returned
    // scanners without corrupting the source array (nested epss_score would be shared).
    return existing ? cloneDeep(existing) : buildDefaultScannerObject(value);
  });
};

export const migrateEmptyScannersToAllScanners = (rule) => {
  if (!Array.isArray(rule.scanners) || rule.scanners.length > 0) return rule;

  return {
    ...rule,
    scanners: REPORT_TYPES_KEYS.map((type) => buildDefaultScannerObject(type)),
  };
};

export const licenseScanBuildRule = () => {
  return {
    id: uniqueId('rule_'),
    type: LICENSE_FINDING,
    match_on_inclusion_license: true,
    licenses: { [ALLOWED]: [] },
    license_states: [],
    branch_type: ALL_PROTECTED_BRANCHES.value,
  };
};

export const anyMergeRequestBuildRule = () => ({
  id: uniqueId('rule_'),
  type: ANY_MERGE_REQUEST,
  branch_type: ALL_PROTECTED_BRANCHES.value,
  commits: ANY_COMMIT,
});

/*
  Construct a new rule object for when the licenseScanningPolicies flag is on
*/
export const emptyBuildRule = () => ({
  type: '',
});

/**
 * Check if all rule values of certain key are included in the allowedValues list
 * @param {Array} rules - List of rules
 * @param {String} key - Rule key to check
 * @param {Array} allowedValues - List of possible values
 * @param {Boolean} areDuplicatesAllowed - check for duplicates in array
 * @returns
 */
// eslint-disable-next-line max-params
const invalidRuleValues = (rules, key, allowedValues, areDuplicatesAllowed = false) => {
  if (!rules) {
    return false;
  }

  const hasDuplicates = (items = []) => new Set(items).size !== items.length;

  if (!areDuplicatesAllowed && rules.some((rule) => hasDuplicates(rule[key] || []))) {
    return true;
  }

  return rules.some((rule) => (rule[key] || []).some((value) => !allowedValues.includes(value)));
};

export const invalidScanners = (rules) => {
  if (!rules) {
    return false;
  }

  return rules.some((rule) =>
    (rule.scanners || []).some((scanner) => {
      if (typeof scanner === 'string') {
        return !REPORT_TYPES_KEYS.includes(scanner);
      }
      if (isObject(scanner)) {
        return !REPORT_TYPES_KEYS.includes(scanner.type);
      }
      return true;
    }),
  );
};

export const invalidSeverities = (rules) =>
  invalidRuleValues(rules, 'severity_levels', SEVERITY_LEVELS_KEYS);

export const invalidVulnerabilityStates = (rules) =>
  invalidRuleValues(rules, 'vulnerability_states', VULNERABILITY_STATE_KEYS);

export const invalidVulnerabilityAttributes = (rules) => {
  if (!rules) {
    return false;
  }

  const validAttributes = [...VULNERABILITY_ATTRIBUTES, ...ADDITIONAL_VULNERABILITY_ATTRIBUTES].map(
    ({ value }) => value,
  );

  return rules
    .filter((rule) => !isEmpty(rule.vulnerability_attributes))
    .flatMap((rule) => rule.vulnerability_attributes)
    .some((attribute) => {
      if (!isObject(attribute)) {
        return true;
      }
      return Object.entries(attribute).some(([key, value]) => {
        const isTypeInvalid = !validAttributes.includes(key) && key !== ENRICHMENT_DATA_UNAVAILABLE;

        if (key === EPSS_SCORE) {
          return isTypeInvalid || !isObject(value);
        }

        if (key === ENRICHMENT_DATA_UNAVAILABLE) {
          return !isObject(value) || !isValidEnrichmentDataAction(value?.action);
        }

        return isTypeInvalid || typeof value !== 'boolean';
      });
    });
};

export const invalidVulnerabilitiesAllowed = (rules) => {
  if (!rules) {
    return false;
  }

  return rules
    .filter((rule) => rule.vulnerabilities_allowed)
    .map((rule) => rule.vulnerabilities_allowed)
    .some((value) => !isPositiveInteger(value));
};

export const invalidVulnerabilityAge = (rules) => {
  if (!rules) {
    return false;
  }

  const validOperators = VULNERABILITY_AGE_OPERATORS.map(({ value }) => value);
  const validIntervals = AGE_INTERVALS.map(({ value }) => value);
  const validVulnerabilityStates = Object.keys(APPROVAL_VULNERABILITY_STATES[PREVIOUSLY_EXISTING]);

  return rules
    .filter((rule) => rule.vulnerability_age)
    .some((rule) => {
      const {
        vulnerability_age: { value, operator, interval },
        vulnerability_states: states,
      } = rule;
      return (
        !validOperators.includes(operator) ||
        !isPositiveInteger(value) ||
        !validIntervals.includes(interval) ||
        !states?.length ||
        !states?.some((state) => validVulnerabilityStates.includes(state)) ||
        !Object.keys(rule.vulnerability_age).every((key) =>
          VULNERABILITY_AGE_ALLOWED_KEYS.includes(key),
        )
      );
    });
};

/**
 * Check if any rule has invalid branch type
 * @param rules list of rules with either branches or branch_type property
 * @returns {Boolean}
 */
export const invalidBranchType = (rules) => {
  if (!rules) return false;

  return rules.some(
    (rule) =>
      BRANCH_TYPE_KEY in rule && !VALID_SCAN_RESULT_BRANCH_TYPE_OPTIONS.includes(rule.branch_type),
  );
};

/**
 * Check if any rule has invalid values for required keys
 * @param {Array} rules
 * @param enforcementType
 * @returns {Boolean}
 */
export const hasInvalidRules = (rules) =>
  invalidScanners(rules) ||
  invalidSeverities(rules) ||
  invalidVulnerabilitiesAllowed(rules) ||
  invalidVulnerabilityStates(rules) ||
  invalidBranchType(rules) ||
  invalidVulnerabilityAge(rules) ||
  invalidVulnerabilityAttributes(rules);

/*
  Returns the config for a particular rule type
*/
export const getDefaultRule = (scanType) => {
  switch (scanType) {
    case SCAN_FINDING:
      return securityScanBuildRule();
    case LICENSE_FINDING:
      return licenseScanBuildRule();
    case ANY_MERGE_REQUEST:
      return anyMergeRequestBuildRule();
    default:
      return emptyBuildRule();
  }
};

const doesBranchExist = async ({ branch, projectId }) => {
  try {
    await Api.projectProtectedBranch(projectId, branch);
    return true;
  } catch {
    return false;
  }
};

export const getInvalidBranches = async ({ branches, projectId }) => {
  const uniqueBranches = [...new Set(branches)];
  const invalidBranches = [];

  for await (const branch of uniqueBranches) {
    if (!(await doesBranchExist({ branch, projectId }))) {
      invalidBranches.push(branch);
    }
  }

  return invalidBranches;
};

export const humanizeInvalidBranchesError = (branches) => {
  const sentence = [];
  if (branches.length > 1) {
    const lastBranch = branches.pop();
    sentence.push(branches.join(', '), s__('SecurityOrchestration| and '), lastBranch);
  } else {
    sentence.push(branches.join());
  }
  return sprintf(INVALID_PROTECTED_BRANCHES, { branches: sentence.join('') });
};
