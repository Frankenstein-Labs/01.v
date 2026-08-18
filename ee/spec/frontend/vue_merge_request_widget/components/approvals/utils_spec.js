import {
  convertRulesToStrings,
  createSecurityPolicyRuleHelpText,
} from 'ee/vue_merge_request_widget/components/approvals/utils';

const securityScanRule = { reportType: 'SCAN_FINDING' };
const licenseScanRule = { reportType: 'LICENSE_SCANNING' };
const mergeRequestRule = { reportType: 'ANY_MERGE_REQUEST' };

describe('convertRulesToStrings', () => {
  it('returns correct string for zero security scan rule', () => {
    expect(convertRulesToStrings([])).toEqual('');
  });

  it('returns correct string for a single security scan rule', () => {
    expect(convertRulesToStrings([securityScanRule])).toEqual(
      'a security scanner found vulnerabilities matching the criteria',
    );
  });

  it('returns correct string for a single license scan rule', () => {
    expect(convertRulesToStrings([licenseScanRule])).toEqual(
      'a license scanner found license violations',
    );
  });

  it('returns correct string for a single merge request rule', () => {
    expect(convertRulesToStrings([mergeRequestRule])).toEqual(
      'a merge request has been opened against a protected branch',
    );
  });

  it('returns correct string for an unknown rule', () => {
    expect(convertRulesToStrings(['new-rule'])).toEqual('a security policy has been violated');
  });

  it('returns correct string for multiple rules', () => {
    expect(convertRulesToStrings([securityScanRule, licenseScanRule, mergeRequestRule])).toEqual(
      'a security scanner found vulnerabilities matching the criteria, a license scanner found license violations and a merge request has been opened against a protected branch',
    );
  });

  it('returns correct string for multiple, duplicate rules', () => {
    expect(convertRulesToStrings([securityScanRule, securityScanRule])).toEqual(
      'a security scanner found vulnerabilities matching the criteria',
    );
  });
});

describe('createSecurityPolicyRuleHelpText', () => {
  it('returns an empty string when there are no rules', () => {
    expect(createSecurityPolicyRuleHelpText([])).toEqual('');
  });

  it('filters out rules with 0 approvals required', () => {
    expect(
      createSecurityPolicyRuleHelpText([{ ...mergeRequestRule, approvalsRequired: 0 }]),
    ).toEqual('');
  });

  it('returns the correct string for 1 approver', () => {
    expect(
      createSecurityPolicyRuleHelpText([{ ...securityScanRule, approvalsRequired: 1 }]),
    ).toEqual(
      'This policy needs 1 approval because a security scanner found vulnerabilities matching the criteria',
    );
  });

  it('returns the correct string for greater than 1 approver', () => {
    expect(
      createSecurityPolicyRuleHelpText([{ ...securityScanRule, approvalsRequired: 2 }]),
    ).toEqual(
      'This policy needs 2 approvals because a security scanner found vulnerabilities matching the criteria',
    );
  });
});
