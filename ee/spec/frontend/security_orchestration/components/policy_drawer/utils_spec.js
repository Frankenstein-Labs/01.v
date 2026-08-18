import {
  getTimeWindowInfo,
  humanizedBranchExceptions,
  mapShortIdsToFullGraphQlFormat,
} from 'ee/security_orchestration/components/policy_drawer/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';

describe('humanizedBranchExceptions', () => {
  it.each`
    exceptions                                                                                       | expectedResult
    ${undefined}                                                                                     | ${[]}
    ${[undefined, null]}                                                                             | ${[]}
    ${['test', 'test1']}                                                                             | ${['test', 'test1']}
    ${['test']}                                                                                      | ${['test']}
    ${['test', undefined]}                                                                           | ${['test']}
    ${[{ name: 'test', full_path: 'gitlab/group' }]}                                                 | ${['test (in %{codeStart}gitlab/group%{codeEnd})']}
    ${[{ name: 'test', full_path: 'gitlab/group' }, { name: 'test1', full_path: 'gitlab/project' }]} | ${['test (in %{codeStart}gitlab/group%{codeEnd})', 'test1 (in %{codeStart}gitlab/project%{codeEnd})']}
  `('should humanize branch exceptions', ({ exceptions, expectedResult }) => {
    expect(humanizedBranchExceptions(exceptions)).toEqual(expectedResult);
  });
});

describe('mapShortIdsToFullGraphQlFormat', () => {
  it.each`
    ids          | type                         | expectedResult
    ${[1, 2]}    | ${undefined}                 | ${['gid://gitlab/Project/1', 'gid://gitlab/Project/2']}
    ${[1, 2]}    | ${TYPE_COMPLIANCE_FRAMEWORK} | ${['gid://gitlab/ComplianceManagement::Framework/1', 'gid://gitlab/ComplianceManagement::Framework/2']}
    ${undefined} | ${undefined}                 | ${[]}
    ${null}      | ${null}                      | ${[]}
  `('converts short format to full GraphQl format', ({ ids, type, expectedResult }) => {
    expect(mapShortIdsToFullGraphQlFormat(type, ids)).toEqual(expectedResult);
  });
});

describe('getTimeWindowInfo', () => {
  it.each([undefined, null, {}, { value: null }])(
    'returns empty string when time window is the invalid value %s',
    (input) => {
      expect(getTimeWindowInfo(input)).toBe('');
    },
  );

  it.each`
    seconds | expectedText
    ${3600} | ${'1 hour'}
    ${7200} | ${'2 hours'}
    ${5400} | ${'1 hour and 30 minutes'}
    ${9000} | ${'2 hours and 30 minutes'}
    ${1800} | ${'30 minutes'}
    ${2700} | ${'45 minutes'}
  `('formats $seconds seconds to $expectedText', ({ seconds, expectedText }) => {
    const result = getTimeWindowInfo({ value: seconds });
    expect(result).toBe(expectedText);
  });
});
