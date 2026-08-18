import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import {
  ALL_PROJECTS_IN_LINKED_GROUPS,
  EXCEPT_PROJECTS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import waitForPromises from 'helpers/wait_for_promises';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { verify } from '../utils';
import {
  APPROVAL_POLICY,
  DEFAULT_PROVIDE,
  PIPELINE_EXECUTION_POLICY,
  SCAN_EXECUTION_POLICY,
} from '../mocks/mocks';
import { createMockApolloProvider, defaultHandlers } from './apollo_utils';
import { INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS, INCLUDING_GROUPS_MOCKS } from './mocks';

jest.mock('~/lib/logger');

describe('Policy Scope for linked groups', () => {
  let wrapper;

  const createWrapper = ({
    propsData = {},
    provide = {},
    glFeatures = {},
    handlers = defaultHandlers,
  } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        ...propsData,
      },
      provide: {
        existingPolicy: null,
        ...DEFAULT_PROVIDE,
        glFeatures: {
          ...glFeatures,
        },
        assignedPolicyProject: {
          fullPath: 'full-path',
        },
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findScopeTypeSelector = () => wrapper.findComponentByTestId('project-scope-type');
  const findGroupsDropdown = () => wrapper.findComponentByTestId('groups-dropdown');
  const findProjectSelector = () => wrapper.findComponentByTestId('projects-dropdown');
  const findExceptionTypeSelector = () => wrapper.findComponentByTestId('exception-type');

  const verifyRuleMode = () => {
    expect(findGroupsDropdown().exists()).toBe(true);
  };

  const selectLinkedGroupsOption = async () => {
    await findScopeTypeSelector().vm.$emit('select', ALL_PROJECTS_IN_LINKED_GROUPS);
    await findGroupsDropdown().vm.$emit('select', [
      { id: convertToGraphQLId(TYPENAME_GROUP, 1) },
      { id: convertToGraphQLId(TYPENAME_GROUP, 2) },
    ]);
  };

  const selectLinkedGroupsWithExceptionsOption = async () => {
    await selectLinkedGroupsOption();

    await findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

    await findProjectSelector().vm.$emit('select', [
      { id: convertToGraphQLId(TYPENAME_PROJECT, 1) },
      { id: convertToGraphQLId(TYPENAME_PROJECT, 2) },
    ]);
  };

  describe('group level', () => {
    describe.each`
      policyType                   | manifest
      ${SCAN_EXECUTION_POLICY}     | ${INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.SCAN_EXECUTION}
      ${PIPELINE_EXECUTION_POLICY} | ${INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.PIPELINE_EXECUTION}
      ${APPROVAL_POLICY}           | ${INCLUDING_GROUPS_WITH_EXCEPTIONS_MOCKS.APPROVAL_POLICY}
    `('$policyType', ({ policyType, manifest }) => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);

        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });
      });

      it('select linked groups with exceptions on group level', async () => {
        await selectLinkedGroupsWithExceptionsOption();
        await waitForPromises();

        await verify({ manifest, verifyRuleMode, wrapper });
      });
    });
  });

  describe.each`
    policyType                   | manifest
    ${SCAN_EXECUTION_POLICY}     | ${INCLUDING_GROUPS_MOCKS.SCAN_EXECUTION}
    ${PIPELINE_EXECUTION_POLICY} | ${INCLUDING_GROUPS_MOCKS.PIPELINE_EXECUTION}
    ${APPROVAL_POLICY}           | ${INCLUDING_GROUPS_MOCKS.APPROVAL_POLICY}
  `('$policyType', ({ policyType, manifest }) => {
    beforeEach(() => {
      jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);

      createWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
    });

    it('select just linked groups on group level', async () => {
      await selectLinkedGroupsOption();
      await waitForPromises();

      await verify({ manifest, verifyRuleMode, wrapper });
    });
  });
});
