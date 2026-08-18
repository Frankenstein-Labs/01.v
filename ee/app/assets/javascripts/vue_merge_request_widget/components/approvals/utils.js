import { sprintf, __, n__, s__ } from '~/locale';

export const convertRulesToStrings = (rules) => {
  const reportTypes = rules.map((rule) => rule.reportType || '');
  const strings = [...new Set(reportTypes)].map((reportType) => {
    switch (reportType) {
      case 'SCAN_FINDING':
        return s__(
          'SecurityOrchestration|a security scanner found vulnerabilities matching the criteria',
        );
      case 'LICENSE_SCANNING':
        return s__('SecurityOrchestration|a license scanner found license violations');
      case 'ANY_MERGE_REQUEST':
        return s__(
          'SecurityOrchestration|a merge request has been opened against a protected branch',
        );
      default:
        return s__('SecurityOrchestration|a security policy has been violated');
    }
  });

  let rulesString = '';
  if (strings.length === 1) {
    [rulesString] = strings;
  } else if (strings.length > 1) {
    const last = strings.pop();
    rulesString = strings.join(__(', ')) + __(' and ') + last;
  }

  return rulesString;
};

export const createSecurityPolicyRuleHelpText = (scanResultPolicies) => {
  const applicableRules = scanResultPolicies.filter((policy) => policy.approvalsRequired);

  if (!applicableRules.length) return '';

  const approvals = applicableRules[0].approvalsRequired;
  const rulesString = convertRulesToStrings(applicableRules);

  return sprintf(
    n__(
      'This policy needs %{approvals} approval because %{rules}',
      'This policy needs %{approvals} approvals because %{rules}',
      approvals,
    ),
    { approvals, rules: rulesString },
  );
};
