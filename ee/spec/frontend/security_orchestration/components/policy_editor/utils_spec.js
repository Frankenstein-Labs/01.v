import {
  assignSecurityPolicyProjectAsync,
  doesFileExist,
  getPolicyLimitDetails,
  goToPolicyMR,
  modifyPolicy,
  redirectToMergeRequest,
  createHumanizedScanners,
  findItemsWithErrors,
  isCauseOfError,
  isValidPolicy,
  hasInvalidCron,
  hasDuplicates,
  hasConflictingKeys,
  slugify,
  slugifyToArray,
  renderMultiselectLabel,
  renderMultiSelectText,
  createProjectWithMinimumValues,
  parseCustomFileConfiguration,
  mapExceptionsListBoxItem,
  mapObjectsToString,
  mapBranchesToExceptions,
  parseError,
  removeIdsFromPolicy,
  validateBranchProjectFormat,
  getMergeRequestConfig,
  policyToYaml,
  parseAllowDenyLicenseList,
  findItemsIntersection,
  mapComponentLicenseFormatToYaml,
  parseExceptionsStringToItems,
  splitItemsByCommaOrSpace,
  getHostname,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import createPolicyProjectAsync from 'ee/security_orchestration/graphql/mutations/create_policy_project_async.mutation.graphql';
import createPolicy from 'ee/security_orchestration/graphql/mutations/create_policy.mutation.graphql';
import { gqClient } from 'ee/security_orchestration/utils';
import createMergeRequestMutation from '~/graphql_shared/mutations/create_merge_request.mutation.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import {
  mockDastScanExecutionManifestWithoutType,
  mockDastScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import {
  SCAN_EXECUTION_POLICY_TYPE,
  APPROVAL_POLICY_TYPE,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import {
  ALLOWED,
  DENIED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

jest.mock('ee/security_orchestration/utils');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));
jest.mock('~/sentry/sentry_browser_wrapper');

const defaultAssignedPolicyProject = { fullPath: 'path/to/policy-project', branch: 'main' };
const projectPath = 'path/to/current-project';
const policyName = 'policy-01';
const yamlEditorValue = `\nname: ${policyName}\ndescription: some yaml`;
const createSavePolicyInput = (assignedPolicyProject = defaultAssignedPolicyProject, action) => ({
  action,
  assignedPolicyProject,
  name: policyName,
  projectPath,
  yamlEditorValue,
});

const error = 'There was an error';

const mockApolloResponses = (shouldReject) => {
  return ({ mutation }) => {
    if (mutation === createPolicyProjectAsync) {
      return Promise.resolve({
        data: {
          securityPolicyProjectCreateAsync: {
            errors: shouldReject ? [error] : [],
          },
        },
      });
    }
    if (mutation === createPolicy) {
      return Promise.resolve({
        data: {
          scanExecutionPolicyCommit: {
            branch: 'new-branch',
            errors: shouldReject ? [error] : [],
          },
        },
      });
    }
    if (mutation === createMergeRequestMutation) {
      return Promise.resolve({
        data: { mergeRequestCreate: { mergeRequest: { iid: '01' }, errors: [] } },
      });
    }
    return Promise.resolve();
  };
};

const mockApolloQueryResponse = (nodes = []) => {
  return () => {
    return Promise.resolve({
      data: {
        project: {
          repository: {
            blobs: {
              nodes,
            },
          },
        },
      },
    });
  };
};

describe('removeIdsFromPolicy', () => {
  it('removes ids from a policy with actions and rules', () => {
    expect(
      removeIdsFromPolicy({ actions: [{ key: 'value', id: 0 }], rules: [{ key: 'value', id: 0 }] }),
    ).toStrictEqual({ actions: [{ key: 'value' }], rules: [{ key: 'value' }] });
  });

  it('does not remove ids from a policy with actions and rules without ids', () => {
    const policy = { name: 'the best', actions: [{ key: 'value' }], rules: [{ key: 'value' }] };
    expect(removeIdsFromPolicy(policy)).toStrictEqual(policy);
  });

  it('does not remove ids from a policy with no actions and no rules', () => {
    const policy = { name: 'the best' };
    expect(removeIdsFromPolicy(policy)).toStrictEqual(policy);
  });
});

describe('assignSecurityPolicyProjectAsync', () => {
  it('returns undefined if successful', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses());

    const newlyCreatedPolicyProject = await assignSecurityPolicyProjectAsync(projectPath);

    expect(newlyCreatedPolicyProject).toBe(undefined);
  });

  it('throws when an error is detected', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses(true));

    await expect(async () => {
      await assignSecurityPolicyProjectAsync(projectPath);
    }).rejects.toThrow(error);
  });
});

describe('modifyPolicy', () => {
  it('returns the policy project and merge request on success when a policy project does not exist', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses());

    const mergeRequest = await modifyPolicy(createSavePolicyInput(DEFAULT_ASSIGNED_POLICY_PROJECT));

    expect(mergeRequest).toStrictEqual({ id: '01', errors: [] });
  });

  it('returns the policy project and merge request on success when a policy project does exist', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses());

    const mergeRequest = await modifyPolicy(createSavePolicyInput());

    expect(mergeRequest).toStrictEqual({ id: '01', errors: [] });
  });

  it('throws when an error is detected', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses(true));

    await expect(async () => {
      await modifyPolicy(createSavePolicyInput());
    }).rejects.toThrow(error);
  });
});

describe('redirectToMergeRequest', () => {
  it('redirects to the merge request', () => {
    redirectToMergeRequest({
      mergeRequestId: '01',
      assignedPolicyProjectFullPath: 'path/to/project',
    });
    expect(visitUrl).toHaveBeenCalledWith('/path/to/project/-/merge_requests/01');
  });
});

describe('goToPolicyMR', () => {
  it('redirects to the newly created merge request', async () => {
    gqClient.mutate.mockImplementation(mockApolloResponses());

    await goToPolicyMR(createSavePolicyInput(defaultAssignedPolicyProject));

    expect(visitUrl).toHaveBeenCalledWith('/path/to/policy-project/-/merge_requests/01');
  });
});

describe('createHumanizedScanners', () => {
  it.each`
    title                                            | input                                                 | output
    ${'returns empty array if no input is provided'} | ${undefined}                                          | ${[]}
    ${'returns empty array for an empty array'}      | ${[]}                                                 | ${[]}
    ${'returns converted array'}                     | ${['dast', 'container_scanning', 'secret_detection']} | ${['DAST', 'Container scanning', 'Secret detection']}
    ${'handles scanner objects'}                     | ${[{ type: 'sast' }, { type: 'dast' }]}               | ${['SAST', 'DAST']}
    ${'handles mixed string and object scanners'}    | ${['dast', { type: 'sast' }, 'secret_detection']}     | ${['DAST', 'SAST', 'Secret detection']}
    ${'handles unknown scanner type in object'}      | ${[{ type: 'unknown_scanner' }]}                      | ${['unknown_scanner']}
  `('$title', ({ input, output }) => {
    expect(createHumanizedScanners(input)).toStrictEqual(output);
  });
});

describe('isCauseOfError', () => {
  it.each`
    title                                                         | errorSources             | primaryKey   | index | location     | expectedOutput
    ${'return false for no errors'}                               | ${[]}                    | ${''}        | ${0}  | ${''}        | ${false}
    ${'return false for no errors that match any inputs'}         | ${[['foo', '0', 'bar']]} | ${undefined} | ${1}  | ${undefined} | ${false}
    ${'return false for no errors that match some of the inputs'} | ${[['foo', '0', 'bar']]} | ${'foo'}     | ${0}  | ${'other'}   | ${false}
    ${'return true for errors that match the inputs'}             | ${[['foo', '0', 'bar']]} | ${'foo'}     | ${0}  | ${'bar'}     | ${true}
  `('$title', ({ errorSources, primaryKey, index, location, expectedOutput }) => {
    expect(isCauseOfError({ errorSources, primaryKey, index, location })).toBe(expectedOutput);
  });
});

describe('isValidPolicy', () => {
  it.each`
    input                                                                                                                                          | output
    ${{}}                                                                                                                                          | ${true}
    ${{ policy: {}, primaryKeys: [], rulesKeys: [], actionsKeys: [] }}                                                                             | ${true}
    ${{ policy: { foo: 'bar' }, primaryKeys: ['foo'], rulesKeys: [], actionsKeys: [] }}                                                            | ${true}
    ${{ policy: { foo: 'bar' }, rulesKeys: [], actionsKeys: [] }}                                                                                  | ${false}
    ${{ policy: { foo: 'bar', rules: [{ zoo: 'dar' }] }, primaryKeys: ['foo', 'rules'], rulesKeys: ['zoo'], actionsKeys: [] }}                     | ${true}
    ${{ policy: { foo: 'bar', rules: [{ zoo: 'dar' }] }, primaryKeys: ['foo', 'rules'], rulesKeys: [], actionsKeys: [] }}                          | ${false}
    ${{ policy: { foo: 'bar', actions: [{ zoo: 'dar' }] }, primaryKeys: ['foo', 'actions'], rulesKeys: [], actionsKeys: ['zoo'] }}                 | ${true}
    ${{ policy: { foo: 'bar', actions: [{ zoo: 'dar' }] }, primaryKeys: ['foo', 'actions'], rulesKeys: [], actionsKeys: [] }}                      | ${false}
    ${{ policy: { foo: 'bar', actions: [{ zoo: 'dar' }, { goo: 'rar' }] }, primaryKeys: ['foo', 'actions'], rulesKeys: [], actionsKeys: ['zoo'] }} | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isValidPolicy(input)).toBe(output);
  });
});

describe('hasInvalidCron', () => {
  it.each`
    input                                                                               | output
    ${[{ zoo: 'dar', cadence: '0 0 * * *' }]}                                           | ${false}
    ${[{ zoo: 'dar', cadence: '* 0 0 * 5' }]}                                           | ${true}
    ${[{ zoo: 'dar', cadence: '0 0 * asd ada' }]}                                       | ${true}
    ${[{ zoo: 'dar', cadence: '0 0 * asd ada' }, { zoo: 'dar', cadence: '0 0 * * *' }]} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(hasInvalidCron(input)).toBe(output);
  });
});

const BRANCHES = [
  {
    input: 'My Input String',
    output: 'My-Input-String',
  },
  {
    input: ' a new project ',
    output: 'a-new-project',
  },
  {
    input: 'test!_bra-nch/*~',
    output: 'test-_bra-nch/*',
  },
  {
    input: 'test!!!!_pro-ject~',
    output: 'test-_pro-ject',
  },
  {
    input: 'дружба',
    output: '',
  },
  {
    input: 'Test:-)',
    output: 'Test',
  },
  {
    input: '-Test:-)-',
    output: 'Test',
  },
];

describe('slugify', () => {
  it.each`
    title                                                                                      | input                | output
    ${'should replaces whitespaces with hyphens'}                                              | ${BRANCHES[0].input} | ${BRANCHES[0].output}
    ${'should remove trailing whitespace and replace whitespaces within string with a hyphen'} | ${BRANCHES[1].input} | ${BRANCHES[1].output}
    ${'should only remove non-allowed special characters'}                                     | ${BRANCHES[2].input} | ${BRANCHES[2].output}
    ${'should squash to multiple non-allowed special characters'}                              | ${BRANCHES[3].input} | ${BRANCHES[3].output}
    ${'should return empty string if only non-allowed characters'}                             | ${BRANCHES[4].input} | ${BRANCHES[4].output}
    ${'should squash multiple separators'}                                                     | ${BRANCHES[5].input} | ${BRANCHES[5].output}
    ${'should trim any separators from the beginning and end of the slug'}                     | ${BRANCHES[6].input} | ${BRANCHES[6].output}
  `('$title', ({ input, output }) => {
    expect(slugify(input)).toBe(output);
  });
});

describe('slugifyToArray', () => {
  it('should create an array split on ","', () => {
    expect(slugifyToArray(BRANCHES.map((b) => b.input).join(','))).toEqual(
      BRANCHES.map((b) => b.output).filter(Boolean),
    );
  });
});

describe('validation', () => {
  it.each`
    useSingleOption | commonItems                             | items                                                                      | expectedText
    ${false}        | ${[]}                                   | ${{}}                                                                      | ${''}
    ${false}        | ${[]}                                   | ${{ project1: 'project 1', project2: 'project 2' }}                        | ${''}
    ${false}        | ${['project1', 'project2']}             | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1, project 2'}
    ${false}        | ${['project1', 'project2', 'project3']} | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1, project 2 +1 more'}
    ${true}         | ${['project1', 'project2', 'project3']} | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1 +2 more'}
    ${true}         | ${['project1', 'project2']}             | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1 +1 more'}
    ${true}         | ${[]}                                   | ${{}}                                                                      | ${''}
    ${true}         | ${['project1']}                         | ${{}}                                                                      | ${''}
  `('renders correct multiple label', ({ useSingleOption, commonItems, items, expectedText }) => {
    expect(renderMultiselectLabel({ useSingleOption, commonItems, items })).toBe(expectedText);
  });
});

describe('parseError', () => {
  const errorExample = {
    message:
      'Title \nproperty \'/type/policyNum/actions/0/variables/\' is not one of: ["scan_finding"]',
    output: [['actions', '0', 'variables']],
  };
  const errorsExample = {
    message:
      'Title \nproperty \'/type/policyNum/actions/0/variables/\' is not one of: ["scan_finding"] \nproperty \'/type/policyNum/rules/1/type/\' is not one of: ["schedule"]',
    output: [
      ['actions', '0', 'variables'],
      ['rules', '1', 'type'],
    ],
  };
  const mixedMessagesExample = {
    message:
      "Invalid policy\nFriendly human-readable error message\nproperty '/type/policyNum/schedules/0/time_window/value' is invalid",
    output: [['schedules', '0', 'time_window']],
  };
  it.each`
    title                                                                   | input                                        | expectedOutput
    ${'returns an empty array if no error is passed'}                       | ${undefined}                                 | ${[]}
    ${'returns an empty array if the error parsing fails'}                  | ${{}}                                        | ${[]}
    ${'returns an empty array if the error parsing fails'}                  | ${{ message: 'Title' }}                      | ${[]}
    ${'returns the parsed error for a single error'}                        | ${{ message: errorExample.message }}         | ${errorExample.output}
    ${'returns the parsed error for multiple errors'}                       | ${{ message: errorsExample.message }}        | ${errorsExample.output}
    ${'skips non-property lines and returns remaining parsed path entries'} | ${{ message: mixedMessagesExample.message }} | ${mixedMessagesExample.output}
  `('$title', ({ input, expectedOutput }) => {
    expect(parseError(input)).toEqual(expectedOutput);
  });
});

describe('renderMultiSelectText', () => {
  it.each`
    selected                                | useAllSelected | useSingleOption | items                                                                      | expectedText
    ${[]}                                   | ${true}        | ${false}        | ${{}}                                                                      | ${'Select projects'}
    ${['project1']}                         | ${true}        | ${false}        | ${{ project1: 'project 1', project2: 'project 2' }}                        | ${'project 1'}
    ${['project1', 'project2']}             | ${true}        | ${false}        | ${{ project1: 'project 1', project2: 'project 2' }}                        | ${'All projects'}
    ${['project1', 'project2']}             | ${false}       | ${false}        | ${{ project1: 'project 1', project2: 'project 2' }}                        | ${'project 1, project 2'}
    ${['project1', 'project2', 'project3']} | ${false}       | ${false}        | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1, project 2 +1 more'}
    ${['project1']}                         | ${false}       | ${false}        | ${{ project1: 'project 1' }}                                               | ${'project 1'}
    ${['project1', 'project2']}             | ${true}        | ${false}        | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1, project 2'}
    ${[]}                                   | ${true}        | ${false}        | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'Select projects'}
    ${['project4', 'project5']}             | ${true}        | ${false}        | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'Select projects'}
    ${['project4', 'project5']}             | ${true}        | ${false}        | ${{ project2: 'project 2', project3: 'project 3' }}                        | ${'Select projects'}
    ${['project1', 'project2', 'project3']} | ${false}       | ${true}         | ${{ project1: 'project 1', project2: 'project 2', project3: 'project 3' }} | ${'project 1 +2 more'}
  `(
    'should render correct selection text',
    ({ selected, useAllSelected, useSingleOption, items, expectedText }) => {
      expect(
        renderMultiSelectText({
          selected,
          items,
          itemTypeName: 'projects',
          useAllSelected,
          useSingleOption,
        }),
      ).toBe(expectedText);
    },
  );

  describe('parseCustomFileConfiguration', () => {
    it.each`
      configuration                    | expectedOutput
      ${{ project: 'path', id: 'id' }} | ${{ showLinkedFile: true, project: createProjectWithMinimumValues({ fullPath: 'path', id: 'id' }) }}
      ${{ ref: 'ref' }}                | ${{ showLinkedFile: true, project: null }}
      ${{ file: 'file' }}              | ${{ showLinkedFile: true, project: null }}
      ${{ file: null }}                | ${{ showLinkedFile: false, project: null }}
      ${{}}                            | ${{ showLinkedFile: false, project: null }}
      ${{ project: 'path' }}           | ${{ showLinkedFile: true, project: { fullPath: 'path' } }}
    `('should parse custom file path configuration', ({ configuration, expectedOutput }) => {
      expect(parseCustomFileConfiguration(configuration)).toEqual(expectedOutput);
    });
  });

  describe('mapExceptionsListBoxItem', () => {
    const index = 1;
    it.each`
      item                                        | expectedResult
      ${'test'}                                   | ${{ value: 'test_1', name: 'test', fullPath: '' }}
      ${''}                                       | ${undefined}
      ${{ name: 'test', full_path: 'full-path' }} | ${{ value: 'test@full-path', name: 'test', fullPath: 'full-path' }}
      ${{ name: 'test', fullPath: 'full-path' }}  | ${{ value: 'test@full-path', name: 'test', fullPath: 'full-path' }}
      ${{ name: 'test', fullPath: undefined }}    | ${{ value: 'test@', name: 'test', fullPath: '' }}
    `('should map exception to list box item', ({ item, expectedResult }) => {
      expect(mapExceptionsListBoxItem(item, index)).toEqual(expectedResult);
    });
  });

  describe('mapObjectsToString', () => {
    it.each`
      branches                                 | expectedResult
      ${[{ name: 'test', fullPath: 'path' }]}  | ${'test@path'}
      ${[{ name: 'test', full_path: 'path' }]} | ${'test@path'}
      ${[{ invalid_name: 'name' }]}            | ${''}
      ${[undefined]}                           | ${''}
    `('should map branches to string format', ({ branches, expectedResult }) => {
      expect(mapObjectsToString(branches)).toEqual(expectedResult);
    });
  });

  describe('validateBranchProjectFormat', () => {
    it.each`
      value          | valid
      ${'test'}      | ${false}
      ${'test@path'} | ${true}
      ${''}          | ${false}
      ${undefined}   | ${false}
      ${null}        | ${false}
      ${'@path'}     | ${false}
      ${'test@'}     | ${false}
    `('should validate branch@full_path format', ({ value, valid }) => {
      expect(validateBranchProjectFormat(value)).toBe(valid);
    });
  });
});

describe('getPolicyLimitDetails', () => {
  const defaultValues = {
    type: 'scan',
    policyLimitReached: true,
    policyLimit: 5,
    initialValue: false,
  };
  describe('radio button details', () => {
    it('returns the radio button text', () => {
      expect(getPolicyLimitDetails(defaultValues).radioButton.text).toBe(
        "You've reached the maximum limit of 5 scan policies allowed. Policies are disabled when added.",
      );
    });

    it.each`
      policyLimitReached | initialValue | expectedOutput
      ${true}            | ${true}      | ${false}
      ${false}           | ${true}      | ${false}
      ${true}            | ${false}     | ${true}
      ${false}           | ${false}     | ${false}
    `(
      'returns $expectedOutput for the radio button disabled status when policyLimitReached is $policyLimitReached and initialValue is $initialValue',
      ({ policyLimitReached, initialValue, expectedOutput }) => {
        expect(
          getPolicyLimitDetails({ ...defaultValues, policyLimitReached, initialValue }).radioButton
            .disabled,
        ).toBe(expectedOutput);
      },
    );
  });
});

describe('hasDuplicates', () => {
  it.each`
    branches                                                                    | output
    ${[]}                                                                       | ${false}
    ${undefined}                                                                | ${false}
    ${null}                                                                     | ${false}
    ${{}}                                                                       | ${true}
    ${[{ name: 'name', value: 'values' }, { name: 'name1', value: 'values1' }]} | ${false}
    ${[{ name: 'name', value: 'values' }, { name: 'name1', value: 'values' }]}  | ${true}
  `('should check if branches has duplicates', ({ branches, output }) => {
    expect(hasDuplicates(branches)).toBe(output);
  });
});

describe('hasConflictingKeys', () => {
  it.each`
    rules                                           | output
    ${null}                                         | ${false}
    ${undefined}                                    | ${false}
    ${[]}                                           | ${false}
    ${[{ branch_type: 'protected' }]}               | ${false}
    ${[{ branches: [] }]}                           | ${false}
    ${[{ branch_type: 'protected', branches: [] }]} | ${true}
  `('returns $output without throwing for rules $rules', ({ rules, output }) => {
    expect(hasConflictingKeys(rules)).toBe(output);
  });
});

describe('findItemsWithErrors', () => {
  it.each`
    branches                                                                              | output
    ${[]}                                                                                 | ${[]}
    ${undefined}                                                                          | ${[]}
    ${null}                                                                               | ${[]}
    ${[{ name: 'name', value: 'values' }, { name: 'name1', value: 'values1' }]}           | ${['name', 'name1']}
    ${[{ name: 'name', value: 'values' }, { name: 'name1', value: 'values1' }]}           | ${['name', 'name1']}
    ${[{ name: 'name', value: 'name@values' }, { name: 'name1', value: 'name@values1' }]} | ${[]}
  `('should check if branches has duplicates', ({ branches, output }) => {
    expect(findItemsWithErrors(branches)).toEqual(output);
  });
});

describe('mapBranchesToExceptions', () => {
  const mockBranches = [
    { name: 'name', value: 'values', fullPath: 'fullPath' },
    { name: 'name1', value: 'values1', fullPath: 'fullPath1' },
  ];

  it.each`
    branches        | output
    ${[]}           | ${[]}
    ${undefined}    | ${[]}
    ${null}         | ${[]}
    ${mockBranches} | ${mockBranches.map(mapExceptionsListBoxItem)}
  `('should check if branches has duplicates', ({ branches, output }) => {
    expect(mapBranchesToExceptions(branches)).toEqual(output);
  });

  describe('doesFileExist', () => {
    it.each`
      files                         | expectedResult
      ${[{ fileName: 'filePath' }]} | ${true}
      ${[]}                         | ${false}
    `('returns $expectedResult when file exist', async ({ files, expectedResult }) => {
      gqClient.query.mockImplementation(mockApolloQueryResponse(files));
      const exists = await doesFileExist({
        filePath: 'filePath',
        fullPath: 'fullPath',
        ref: 'main',
      });

      expect(exists).toBe(expectedResult);
    });

    it('returns false when fullPath is not provides', async () => {
      gqClient.query.mockImplementation(mockApolloQueryResponse());
      const exists = await doesFileExist({ fullPath: 'fullPath', ref: 'main' });

      expect(exists).toBe(false);
    });

    it('fallbacks to false when request fails', async () => {
      gqClient.query.mockRejectedValue({});
      const exists = await doesFileExist({ fullPath: 'fullPath', ref: 'main' });
      expect(exists).toBe(false);
    });
  });

  describe('getMergeRequestConfig', () => {
    const fullConfig = {
      compliance_framework_name: 'test',
      compliance_framework_id: '1',
      path: 'foo@bar',
    };

    it('returns correct title and description if all required data is supplied', () => {
      const output = getMergeRequestConfig(fullConfig, { namespacePath: 'foo' });
      expect(output).toMatchObject({
        title: 'Compliance pipeline migration to pipeline execution policy',
        description: expect.stringContaining('This merge request migrates compliance pipeline'),
      });
    });

    it.each(Object.keys(fullConfig).map((k) => [k]))('returns null if %s key is missing', (key) => {
      const params = { ...fullConfig };
      delete params[key];

      expect(getMergeRequestConfig(params, { namespacePath: 'foo ' })).toBe(null);
    });
  });

  describe.each([
    SCAN_EXECUTION_POLICY_TYPE,
    APPROVAL_POLICY_TYPE,
    VULNERABILITY_MANAGEMENT_POLICY_TYPE,
    PIPELINE_EXECUTION_POLICY_TYPE,
  ])('policyToYaml', (urlParameter) => {
    it('returns policy object as yaml', () => {
      expect(policyToYaml(mockDastScanExecutionObject, urlParameter)).toBe(
        mockDastScanExecutionManifestWithoutType(urlParameter),
      );
    });

    it('returns policy object as yaml with type wrapper', () => {
      expect(policyToYaml(mockDastScanExecutionObject, urlParameter)).toBe(`${urlParameter}:
  - name: Scheduled Dast/SAST scan
    description: This policy enforces pipeline configuration to have a job with DAST scan
    enabled: false
    rules:
      - type: pipeline
        branches:
          - main
    actions:
      - scan: dast
        site_profile: required_site_profile
        scanner_profile: required_scanner_profile
`);
    });

    it('returns empty string and captures exception when safeDump throws', () => {
      const policyWithUndumpableValue = {
        ...mockDastScanExecutionObject,
        undumpable: () => {},
      };

      const result = policyToYaml(policyWithUndumpableValue, urlParameter);

      expect(result).toBe('');
      expect(captureException).toHaveBeenCalled();
    });
  });

  describe('parseAllowDenyLicenseList', () => {
    it.each`
      rule                                                                                                  | output
      ${undefined}                                                                                          | ${{ isDenied: false, licenses: [] }}
      ${null}                                                                                               | ${{ isDenied: false, licenses: [] }}
      ${{}}                                                                                                 | ${{ isDenied: false, licenses: [] }}
      ${{ licenses: { [ALLOWED]: [{ name: 'value' }] } }}                                                   | ${{ isDenied: false, licenses: [{ license: { text: 'value', value: 'value' }, exceptions: [] }] }}
      ${{ licenses: { [DENIED]: [{ name: 'value', packages: { excluding: { purls: ['test@test'] } } }] } }} | ${{ isDenied: true, licenses: [{ license: { text: 'value', value: 'value' }, exceptions: ['test@test'] }] }}
      ${{ licenses: { [DENIED]: [{ name: 'value', packages: { excluding: ['test@test'] } }] } }}            | ${{ isDenied: true, licenses: [{ license: { text: 'value', value: 'value' }, exceptions: [] }] }}
      ${{ licenses: { invalid: [{ name: 'value' }] } }}                                                     | ${{ isDenied: false, licenses: [] }}
    `('parse licenses from rule', ({ rule, output }) => {
      expect(parseAllowDenyLicenseList(rule)).toEqual(output);
    });
  });

  describe('mapComponentLicenseFormatToYaml', () => {
    it.each`
      licenses                                                                       | output
      ${undefined}                                                                   | ${[]}
      ${null}                                                                        | ${[]}
      ${[{ license: { text: 'value', value: 'value' } }]}                            | ${[{ name: 'value' }]}
      ${[{ license: { text: 'value', value: 'value' }, exceptions: ['test@test'] }]} | ${[{ name: 'value', packages: { excluding: { purls: ['test@test'] } } }]}
    `('parse licenses to yaml format', ({ licenses, output }) => {
      expect(mapComponentLicenseFormatToYaml(licenses)).toEqual(output);
    });
  });

  describe('findItemsIntersection', () => {
    it.each`
      collectionOne             | collectionTwo                      | mapperFn          | type         | output
      ${undefined}              | ${undefined}                       | ${undefined}      | ${undefined} | ${[]}
      ${[]}                     | ${[]}                              | ${() => {}}       | ${undefined} | ${[]}
      ${[1, 2]}                 | ${[{ id: 2 }]}                     | ${(item) => item} | ${undefined} | ${[{ id: 2 }]}
      ${[1, 2]}                 | ${[{ id: 'gid://gitlab/User/2' }]} | ${(item) => item} | ${'User'}    | ${[{ id: 'gid://gitlab/User/2' }]}
      ${[1, 2]}                 | ${[{ id: 'gid://gitlab/User/3' }]} | ${(item) => item} | ${'User'}    | ${[]}
      ${[{ id: 1 }, { id: 2 }]} | ${[{ id: 2 }]}                     | ${(item) => item} | ${'User'}    | ${[{ id: 1 }, { id: 2 }]}
    `(
      'find common items in collections and map to result object',
      ({ collectionOne, collectionTwo, mapperFn, type, output }) => {
        expect(findItemsIntersection({ collectionOne, collectionTwo, mapperFn, type })).toEqual(
          output,
        );
      },
    );
  });

  describe('splitItemsByCommaOrSpace', () => {
    it.each`
      source              | output
      ${'item1, item2'}   | ${['item1', 'item2']}
      ${'item1 item2'}    | ${['item1', 'item2']}
      ${'item1;item2'}    | ${['item1;item2']}
      ${'item1-item2'}    | ${['item1-item2']}
      ${'item1 \n item2'} | ${['item1', 'item2']}
    `('split sting by space new line or comma', ({ source, output }) => {
      expect(splitItemsByCommaOrSpace(source)).toEqual(output);
    });
  });

  describe('parseExceptionsStringToItems', () => {
    it.each`
      items                          | output
      ${undefined}                   | ${{ parsedExceptions: [], parsedWithErrorsExceptions: [] }}
      ${null}                        | ${{ parsedExceptions: [], parsedWithErrorsExceptions: [] }}
      ${[]}                          | ${{ parsedExceptions: [], parsedWithErrorsExceptions: [] }}
      ${['item@test', 'item1@test']} | ${{ parsedExceptions: [{ file: 'item', fullPath: 'test', value: 'item@test' }, { file: 'item1', fullPath: 'test', value: 'item1@test' }], parsedWithErrorsExceptions: [] }}
      ${['item@test', 'item1']}      | ${{ parsedExceptions: [{ file: 'item', fullPath: 'test', value: 'item@test' }, { file: 'item1', fullPath: '', value: 'item1' }], parsedWithErrorsExceptions: ['item1'] }}
    `('parses array of strings into objects', ({ items, output }) => {
      expect(parseExceptionsStringToItems(items)).toEqual(output);
    });
  });
});

describe('getHostname', () => {
  const mockHostname = 'gitlab.example.com';
  const originalHostname = window.location.host;

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: { host: originalHostname },
    });
  });

  it('returns the host name', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: { host: mockHostname },
    });
    expect(getHostname()).toBe(mockHostname);
  });

  it('returns the fallback value', () => {
    Object.defineProperty(window, 'location', {
      writable: true,
      value: undefined,
    });
    expect(getHostname()).toBe('your GitLab instance');
  });
});
