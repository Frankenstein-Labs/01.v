import { isObject } from 'lodash-es';
import { sprintf, s__, n__, __ } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { roundOffFloat } from '~/lib/utils/common_utils';

import {
  ANY_COMMIT,
  ANY_UNSIGNED_COMMIT,
  INVALID_RULE_MESSAGE,
  NO_RULE_MESSAGE,
  BRANCH_TYPE_KEY,
  HUMANIZED_BRANCH_TYPE_TEXT_DICT,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  GREATER_THAN_OPERATOR,
  LESS_THAN_OPERATOR,
  MATCH_ON_INCLUSION_LICENSE,
} from '../../policy_editor/constants';
import { createHumanizedScanners } from '../../policy_editor/utils';
import {
  NEEDS_TRIAGE_PLURAL,
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES_FLAT,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  ENRICHMENT_DATA_UNAVAILABLE,
  ENRICHMENT_DATA_ACTIONS,
} from '../../policy_editor/scan_result/rule/scan_filters/constants';
import {
  ANY_MERGE_REQUEST,
  LICENSE_FINDING,
  LICENSE_STATES,
  groupSelectedVulnerabilityStates,
} from '../../policy_editor/scan_result/lib';
import { buildBranchExceptionsString, humanizedBranchExceptions } from '../utils';

/**
 * Create a human-readable list of strings, adding the necessary punctuation and conjunctions
 * @param {Array} items strings representing items to compose the final sentence
 * @param {String} singular string to be used for single items
 * @param {Boolean} hasTextBeforeItems
 * @param {String} plural string to be used for multiple items
 * @returns {String}
 */
const humanizeItems = ({ items, singular, plural, hasTextBeforeItems = false }) => {
  if (!items) {
    return '';
  }

  let noun = '';

  if (singular && plural) {
    noun = items.length > 1 ? plural : singular;
  }

  const finalSentence = [];

  if (hasTextBeforeItems && noun) {
    finalSentence.push(`${noun} `);
  }

  if (items.length === 1) {
    finalSentence.push(items.join(','));
  } else {
    const lastItem = items[items.length - 1];
    const rest = items.slice(0, -1);
    // Use Oxford comma for 3+ items: "A, B, or C"; for 2 items: "A or B"
    const conjunction =
      rest.length >= 2 ? s__('SecurityOrchestration|, or ') : s__('SecurityOrchestration| or ');
    finalSentence.push(rest.join(', '), conjunction, lastItem);
  }

  if (!hasTextBeforeItems && noun) {
    finalSentence.push(` ${noun}`);
  }

  return finalSentence.join('');
};

/**
 * Create a human-readable version of the branches
 * @param {Array} branches
 * @returns {String}
 */
const humanizeBranches = (branches = []) => {
  const hasNoBranch = branches.length === 0;

  if (hasNoBranch) {
    return s__('SecurityOrchestration|any protected branch');
  }

  return sprintf(s__('SecurityOrchestration|the %{branches}'), {
    branches: humanizeItems({
      items: branches,
      singular: s__('SecurityOrchestration|branch'),
      plural: s__('SecurityOrchestration|branches'),
    }),
  });
};

const humanizeBranchType = (branchType) => {
  return sprintf(s__('SecurityOrchestration|targeting %{branchTypeText}'), {
    branchTypeText: HUMANIZED_BRANCH_TYPE_TEXT_DICT[branchType],
  });
};

/**
 * Create a human-readable version of the allowed vulnerabilities
 * @param {Number} vulnerabilitiesAllowed
 * @returns {String}
 */
const humanizeVulnerabilitiesAllowed = (vulnerabilitiesAllowed) =>
  vulnerabilitiesAllowed
    ? sprintf(s__('SecurityOrchestration|more than %{allowed}'), {
        allowed: vulnerabilitiesAllowed,
      })
    : s__('SecurityOrchestration|any');

/**
 * Create a translation map for vulnerability statuses,
 * applying replacements needed for human-readable version of vulnerability states
 * @returns {Object}
 */
const vulnerabilityStatusTranslationMap = {
  ...APPROVAL_VULNERABILITY_STATES_FLAT,
  new_needs_triage: NEEDS_TRIAGE_PLURAL,
  detected: NEEDS_TRIAGE_PLURAL,
};

/**
 * Create a human-readable version of the vulnerability states
 * @param {Array} vulnerabilitiesStates
 * @returns {String}
 */
const humanizeVulnerabilityStates = (vulnerabilitiesStates) => {
  if (!vulnerabilitiesStates.length) {
    return '';
  }

  const divider = __(', or ');
  const statesByGroup = groupSelectedVulnerabilityStates(vulnerabilitiesStates);
  const stateGroups = Object.keys(statesByGroup);

  return stateGroups
    .reduce((sentence, stateGroup) => {
      return [
        ...sentence,
        sprintf(s__('SecurityOrchestration|%{state} and %{statuses}'), {
          state: APPROVAL_VULNERABILITY_STATE_GROUPS[stateGroup].toLowerCase(),
          statuses: humanizeItems({
            items: statesByGroup[stateGroup].map((status) =>
              vulnerabilityStatusTranslationMap[status].toLowerCase(),
            ),
          }),
        }),
      ];
    }, [])
    .join(divider);
};

/**
 * Create a human-readable version of vulnerability attributes.
 * Supported attributes must be included in VULNERABILITY_ATTRIBUTES mapping.
 * @param {Object} vulnerabilityAttributes - Object containing applicable vulnerability attributes
 * @returns {String}
 */
const humanizeVulnerabilityAttributes = (vulnerabilityAttributes) => {
  const sentenceMap = {
    [FIX_AVAILABLE]: new Map([
      [true, s__('SecurityOrchestration|have a fix available')],
      [false, s__('SecurityOrchestration|have no fix available')],
    ]),
    [FALSE_POSITIVE]: new Map([
      [true, s__('SecurityOrchestration|are false positives')],
      [false, s__('SecurityOrchestration|are not false positives')],
    ]),
    [KNOWN_EXPLOITED]: new Map([
      [true, s__('SecurityOrchestration|are in the KEV catalog')],
      [false, s__('SecurityOrchestration|are not in the KEV catalog')],
    ]),
  };
  const sentence = Object.entries(vulnerabilityAttributes)
    .filter(([key]) => key !== EPSS_SCORE)
    .map(([key, value]) => {
      return sentenceMap[key]?.get(value);
    })
    .filter(Boolean);

  return sentence.join(__(' and '));
};

/**
 * Create a human-readable version of the EPSS score attribute
 * @param {Object} epssScore
 * @returns {String|null}
 */
const humanizeEpssOperatorAndValue = (epssScore) => {
  const { operator, value } = epssScore;

  const operatorTextMap = {
    [GREATER_THAN_OPERATOR]: s__('SecurityOrchestration|greater than'),
    [LESS_THAN_OPERATOR]: s__('SecurityOrchestration|less than'),
  };

  return {
    humanizedOperator: operatorTextMap[operator] || operator,
    percentValue: `${roundOffFloat(value * 100)}%`,
  };
};

const humanizeEpssScore = (vulnerabilityAttributes) => {
  const epssScore = vulnerabilityAttributes?.[EPSS_SCORE];

  if (!epssScore) {
    return null;
  }

  const { percentValue } = humanizeEpssOperatorAndValue(epssScore);

  if (epssScore.operator === GREATER_THAN_OPERATOR) {
    return sprintf(
      s__('SecurityOrchestration|Vulnerabilities have EPSS score greater than %{value}.'),
      { value: percentValue },
    );
  }

  return sprintf(s__('SecurityOrchestration|Vulnerabilities have EPSS score less than %{value}.'), {
    value: percentValue,
  });
};

/**
 * Create a human-readable version of vulnerability age
 * @param {Object} vulnerabilityAge
 * @returns {String}
 */
const humanizeVulnerabilityAge = (vulnerabilityAge) => {
  const { value, operator } = vulnerabilityAge;

  const strMap = {
    day: (number) => n__('%d day', '%d days', number),
    week: (number) => n__('%d week', '%d weeks', number),
    month: (number) => n__('%d month', '%d months', number),
    year: (number) => n__('%d year', '%d years', number),
  };

  const baseStr = {
    [GREATER_THAN_OPERATOR]: sprintf(
      s__('SecurityOrchestration|Vulnerability age is greater than %{vulnerabilityAge}.'),
      { vulnerabilityAge: strMap[vulnerabilityAge.interval](value) },
    ),
    [LESS_THAN_OPERATOR]: sprintf(
      s__('SecurityOrchestration|Vulnerability age is less than %{vulnerabilityAge}.'),
      { vulnerabilityAge: strMap[vulnerabilityAge.interval](value) },
    ),
  };

  return baseStr[operator];
};

/**
 * Create a human-readable version of the scanners
 * @param {Array} scanners
 * @returns {String}
 */
const humanizeScanners = (scanners) => {
  const hasEmptyScanners = scanners.length === 0;

  if (hasEmptyScanners) {
    return s__('SecurityOrchestration|any security scanner finds');
  }

  return sprintf(s__('SecurityOrchestration|%{scanners}'), {
    scanners: humanizeItems({
      items: scanners,
      singular: s__('SecurityOrchestration|scanner finds'),
      plural: s__('SecurityOrchestration|scanners find'),
    }),
  });
};

const humanizeLicenseDetection = (licenseStates) => {
  const maxNumOfLicenseStates = Object.entries(LICENSE_STATES).length;

  if (licenseStates.length === maxNumOfLicenseStates) {
    return '';
  }

  return sprintf(s__('SecurityOrchestration| that is %{licenseState} and is'), {
    licenseState: LICENSE_STATES[licenseStates[0]].toLowerCase(),
  });
};

/**
 * Validate commits type
 * @param type commit type
 * @returns {*|string}
 */
const humanizeCommitType = (type) => {
  const stringMap = {
    [ANY_COMMIT]: s__('SecurityOrchestration| for any commits'),
    [ANY_UNSIGNED_COMMIT]: s__('SecurityOrchestration| for unsigned commits'),
  };

  return stringMap[type] || '';
};

const hasBranchType = (rule) => BRANCH_TYPE_KEY in rule;

const hasValidBranchType = (rule) => {
  if (!rule) return false;

  return (
    hasBranchType(rule) &&
    SCAN_RESULT_BRANCH_TYPE_OPTIONS()
      .map(({ value }) => value)
      .includes(rule.branch_type)
  );
};

/**
 * Build per-scanner criteria for object-format scanners
 * @param {Array} scanners - Array of scanner objects with per-scanner settings
 * @returns {Array} Array of { name, criteriaList } objects
 */
const buildScannerDetails = (scanners) => {
  return scanners.filter(isObject).map((scanner) => {
    const name = createHumanizedScanners([scanner])[0];
    const scannerCriteria = [];

    const addScannerCriteria = (predicate, compileCriteria) => {
      if (predicate) {
        // Strip trailing period so per-scanner bullets remain consistent
        const text = compileCriteria().replace(/\.$/, '');
        scannerCriteria.push(capitalizeFirstCharacter(text));
      }
    };

    addScannerCriteria(scanner.vulnerabilities_allowed != null, () => {
      const count = scanner.vulnerabilities_allowed;
      return count > 0
        ? sprintf(
            n__(
              'SecurityOrchestration|Allows more than %{count} vulnerability',
              'SecurityOrchestration|Allows more than %{count} vulnerabilities',
              count,
            ),
            { count },
          )
        : s__('SecurityOrchestration|No new vulnerabilities allowed');
    });

    addScannerCriteria(scanner.severity_levels?.length, () =>
      sprintf(s__('SecurityOrchestration|Severity is %{severity}'), {
        severity: humanizeItems({
          items: [...scanner.severity_levels],
        }),
      }),
    );

    addScannerCriteria(scanner.vulnerability_states?.length, () =>
      humanizeVulnerabilityStates(scanner.vulnerability_states),
    );

    addScannerCriteria(Object.keys(scanner.vulnerability_age || {}).length, () =>
      humanizeVulnerabilityAge(scanner.vulnerability_age),
    );

    const attrs = scanner.vulnerability_attributes || {};
    const nonEpssAttrs = Object.fromEntries(
      Object.entries(attrs).filter(
        ([key]) => key !== EPSS_SCORE && key !== ENRICHMENT_DATA_UNAVAILABLE,
      ),
    );

    addScannerCriteria(Object.keys(nonEpssAttrs).length, () =>
      humanizeVulnerabilityAttributes(nonEpssAttrs),
    );

    const epssScore = attrs[EPSS_SCORE];
    addScannerCriteria(epssScore, () => {
      const { percentValue } = humanizeEpssOperatorAndValue(epssScore);

      if (epssScore.operator === GREATER_THAN_OPERATOR) {
        return sprintf(s__('SecurityOrchestration|EPSS score is greater than %{value}'), {
          value: percentValue,
        });
      }

      return sprintf(s__('SecurityOrchestration|EPSS score is less than %{value}'), {
        value: percentValue,
      });
    });

    const enrichmentData = attrs[ENRICHMENT_DATA_UNAVAILABLE];
    addScannerCriteria(enrichmentData, () => {
      if (enrichmentData?.action === ENRICHMENT_DATA_ACTIONS.BLOCK) {
        return s__(
          'SecurityOrchestration|When KEV or EPSS data is unavailable, block merge requests based on the severity of the vulnerability.',
        );
      }

      return s__(
        'SecurityOrchestration|When KEV or EPSS data is unavailable, exclude the vulnerability from policy evaluation',
      );
    });

    return { name, criteriaList: scannerCriteria };
  });
};

/**
 * Create a human-readable version of the rule
 * @param {Object} rule {type: 'scan_finding', branch_type: 'protected', branches: ['master'], scanners: ['container_scanning'], vulnerabilities_allowed: 1, severity_levels: ['critical']}
 * @returns {Object} {summary: '', criteriaList: []}
 */
const humanizeRule = (rule) => {
  const humanizedValue = hasBranchType(rule)
    ? humanizeBranchType(rule.branch_type)
    : humanizeBranches(rule.branches);
  const targetingValue = hasBranchType(rule) ? '' : __('targeting ');

  if (hasBranchType(rule) && !hasValidBranchType(rule)) {
    return {
      summary: INVALID_RULE_MESSAGE,
    };
  }

  const branchExceptions = humanizedBranchExceptions(rule.branch_exceptions);
  const branchExceptionsString = buildBranchExceptionsString(rule.branch_exceptions);

  if (rule.type === LICENSE_FINDING) {
    const summaryText = rule[MATCH_ON_INCLUSION_LICENSE]
      ? s__(
          'SecurityOrchestration|When license scanner finds any license matching %{licenses}%{detection} in an open merge request %{targeting}%{branches}%{branchExceptionsString}',
        )
      : s__(
          'SecurityOrchestration|When license scanner finds any license except %{licenses}%{detection} in an open merge request %{targeting}%{branches}%{branchExceptionsString}',
        );

    return {
      summary: sprintf(summaryText, {
        detection: humanizeLicenseDetection(rule.license_states),
        branches: humanizedValue,
        targeting: targetingValue,
        branchExceptionsString: branchExceptions.length ? branchExceptionsString : '.',
      }),
      branchExceptions,
      licenses: rule.license_types,
      denyAllowList: rule.licenses || [],
      licenseOverrides: rule.license_overrides || [],
    };
  }

  if (rule.type === ANY_MERGE_REQUEST) {
    const summaryText = s__(
      'SecurityOrchestration|For any merge request on %{branches}%{commitType}%{branchExceptionsString}',
    );

    return {
      summary: sprintf(summaryText, {
        branches: humanizedValue,
        commitType: humanizeCommitType(rule.commits),
        branchExceptionsString: branchExceptions.length ? branchExceptionsString : '.',
      }),
      branchExceptions,
    };
  }

  const criteriaList = [];

  const addCriteria = (predicate, compileCriteria) => {
    if (predicate) {
      criteriaList.push(compileCriteria());
    }
  };

  addCriteria(rule.severity_levels?.length, () =>
    sprintf(s__('SecurityOrchestration|Severity is %{severity}.'), {
      severity: humanizeItems({
        items: rule.severity_levels,
      }),
    }),
  );

  addCriteria(rule.vulnerability_states?.length, () =>
    sprintf(s__('SecurityOrchestration|Vulnerabilities are %{vulnerabilityStates}.'), {
      vulnerabilityStates: humanizeVulnerabilityStates(rule.vulnerability_states),
    }),
  );

  addCriteria(Object.keys(rule.vulnerability_age || {}).length, () =>
    humanizeVulnerabilityAge(rule.vulnerability_age),
  );

  addCriteria(Object.keys(rule.vulnerability_attributes || {}).length, () =>
    sprintf(s__('SecurityOrchestration|Vulnerabilities %{vulnerabilityStates}.'), {
      vulnerabilityStates: humanizeVulnerabilityAttributes(rule.vulnerability_attributes),
    }),
  );

  const epssText = humanizeEpssScore(rule.vulnerability_attributes);
  addCriteria(epssText, () => epssText);

  const criteriaMessage = s__('SecurityOrchestration| and all the following apply:');
  let criteriaEnding = '';

  if (!branchExceptions.length) {
    criteriaEnding = '.';
  }

  const hasObjectScanners = rule.scanners?.some(isObject);

  const scannerDetails = hasObjectScanners ? buildScannerDetails(rule.scanners) : undefined;

  const allCriteriaList = hasObjectScanners ? [] : criteriaList;
  const hasCriteria = hasObjectScanners
    ? Boolean(scannerDetails?.length)
    : Boolean(criteriaList.length);

  const summary = hasObjectScanners
    ? sprintf(
        s__(
          'SecurityOrchestration|When the following scanners find any vulnerabilities in an open merge request %{targeting}%{branches}%{branchExceptionsString}%{criteriaApply}',
        ),
        {
          branches: humanizedValue,
          targeting: targetingValue,
          branchExceptionsString: branchExceptions.length ? branchExceptionsString : '',
          criteriaApply: branchExceptions.length ? '' : ':',
        },
      )
    : sprintf(
        s__(
          'SecurityOrchestration|When %{scanners} %{vulnerabilitiesAllowed} %{vulnerability} in an open merge request %{targeting}%{branches}%{branchExceptionsString}%{criteriaApply}',
        ),
        {
          scanners: humanizeScanners(createHumanizedScanners(rule.scanners)),
          branches: humanizedValue,
          targeting: targetingValue,
          vulnerabilitiesAllowed: humanizeVulnerabilitiesAllowed(rule.vulnerabilities_allowed),
          vulnerability: n__('vulnerability', 'vulnerabilities', rule.vulnerabilities_allowed),
          branchExceptionsString: branchExceptions.length ? branchExceptionsString : '',
          criteriaApply: hasCriteria && !branchExceptions.length ? criteriaMessage : criteriaEnding,
        },
      );

  return {
    summary,
    criteriaList: allCriteriaList,
    branchExceptions,
    criteriaMessage: hasCriteria && branchExceptions.length ? criteriaMessage : '',
    ...(scannerDetails ? { scannerDetails } : {}),
  };
};

/**
 * Create a human-readable version of the rules
 * @param rules {Array} [{type: 'scan_finding', branches: ['master'], scanners: ['container_scanning'], vulnerabilities_allowed: 1, severity_levels: ['critical']}]
 * @returns {Array} [{summary: '', criteriaList: []}]
 */
export const humanizeRules = (rules = []) => {
  const humanizedRules = rules.reduce((acc, curr) => {
    return [...acc, humanizeRule(curr)];
  }, []);
  return humanizedRules.length ? humanizedRules : [{ summary: NO_RULE_MESSAGE }];
};

/**
 * Map approver object to flat array
 * @param approvers
 * @returns {*[]}
 */
export const mapApproversToArray = (approvers) => {
  if (approvers === undefined) {
    return [];
  }

  const { allGroups = [], customRoles = [], roles = [], users = [] } = approvers || {};

  return [
    ...allGroups,
    ...customRoles,
    ...roles
      .map((role) => {
        return {
          GUEST: __('Guest'),
          REPORTER: __('Reporter'),
          DEVELOPER: __('Developer'),
          MAINTAINER: __('Maintainer'),
          OWNER: __('Owner'),
        }[role];
      })
      .filter(Boolean),
    ...users,
  ];
};
