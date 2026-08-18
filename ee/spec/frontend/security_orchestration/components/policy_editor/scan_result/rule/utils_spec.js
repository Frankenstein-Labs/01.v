import {
  buildVulnerabilitiesPayload,
  getVulnerabilityAttribute,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/utils';

describe('buildVulnerabilitiesPayload', () => {
  it.each`
    payload         | property  | value    | output
    ${{}}           | ${'test'} | ${false} | ${{ vulnerability_attributes: { test: false } }}
    ${{}}           | ${''}     | ${false} | ${{ vulnerability_attributes: { '': false } }}
    ${{ rule: {} }} | ${''}     | ${false} | ${{ rule: {}, vulnerability_attributes: { '': false } }}
  `('updates the payload', ({ payload, property, value, output }) => {
    expect(buildVulnerabilitiesPayload(payload, property, value)).toEqual(output);
  });

  it.each`
    payload                                          | property   | output
    ${{ vulnerability_attributes: { test: false } }} | ${'test'}  | ${false}
    ${{ vulnerability_attributes: { test: false } }} | ${'test1'} | ${undefined}
  `('updates the payload', ({ payload, property, output }) => {
    expect(getVulnerabilityAttribute(payload, property)).toEqual(output);
  });
});
