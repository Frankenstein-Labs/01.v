import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import ComplianceFrameworkSelector from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_selector.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import waitForPromises from 'helpers/wait_for_promises';
import {
  ALL_PROJECTS_IN_GROUP,
  PROJECTS_WITH_FRAMEWORK,
  WITHOUT_EXCEPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import {
  APPROVAL_POLICY,
  DEFAULT_PROVIDE,
  PIPELINE_EXECUTION_POLICY,
  SCAN_EXECUTION_POLICY,
} from '../mocks/mocks';
import { verify } from '../utils';
import {
  mockScanExecutionActionManifest,
  mockPipelineExecutionActionManifest,
  mockApprovalActionGroupManifest,
  mockApprovalActionProjectManifest,
  mockScanExecutionActionProjectManifest,
} from './mocks';
import {
  createMockApolloProvider,
  createSppLinkedItemsHandler,
  defaultHandlers,
} from './apollo_utils';

jest.mock('~/lib/logger');

describe('ComplianceFrameworks', () => {
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
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        existingPolicy: null,
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findScopeTypeSelector = () => wrapper.findComponentByTestId('project-scope-type');
  const findExceptionTypeSelector = () => wrapper.findComponentByTestId('exception-type');
  const findProjectText = () => wrapper.findByTestId('policy-scope-project-text');
  const findComplianceFrameworkSelector = () => wrapper.findComponent(ComplianceFrameworkSelector);

  const verifyRuleMode = () => {
    expect(findComplianceFrameworkSelector().exists()).toBe(true);
  };

  const selectComplianceFrameworksOption = async () => {
    await findScopeTypeSelector().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);
    await findComplianceFrameworkSelector().vm.$emit('select', [1, 2]);
  };

  describe('group level', () => {
    describe.each`
      policyType                   | manifest
      ${SCAN_EXECUTION_POLICY}     | ${mockScanExecutionActionManifest}
      ${PIPELINE_EXECUTION_POLICY} | ${mockPipelineExecutionActionManifest}
      ${APPROVAL_POLICY}           | ${mockApprovalActionGroupManifest}
    `('$policyType', ({ policyType, manifest }) => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);

        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });
      });

      it('renders policy scope default state on group level', () => {
        expect(findScopeTypeSelector().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
        expect(findExceptionTypeSelector().props('selected')).toBe(WITHOUT_EXCEPTIONS);
      });

      it('selects compliance frameworks', async () => {
        await findScopeTypeSelector().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);
        await waitForPromises();

        expect(findComplianceFrameworkSelector().exists()).toBe(true);
      });

      it('selects compliance frameworks ids on group level', async () => {
        await selectComplianceFrameworksOption();
        await verify({ manifest, verifyRuleMode, wrapper });
      });
    });
  });

  describe('project level', () => {
    describe.each`
      policyType                   | manifest
      ${SCAN_EXECUTION_POLICY}     | ${mockScanExecutionActionProjectManifest}
      ${PIPELINE_EXECUTION_POLICY} | ${mockPipelineExecutionActionManifest}
      ${APPROVAL_POLICY}           | ${mockApprovalActionProjectManifest}
    `('$policyType', ({ policyType, manifest }) => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(policyType);
      });

      it('renders project scope message for a non-SPP', async () => {
        createWrapper();
        await waitForPromises();

        expect(findProjectText().exists()).toBe(true);
      });

      it('selects compliance frameworks for a SPP', async () => {
        createWrapper({
          handlers: {
            ...defaultHandlers,
            sppLinkedItemsHandler: createSppLinkedItemsHandler({
              projects: [
                { id: '1', name: 'name1', fullPath: 'fullPath1' },
                { id: '2', name: 'name2', fullPath: 'fullPath2' },
              ],
              namespaces: [
                { id: '1', name: 'name1', fullPath: 'fullPath1' },
                { id: '2', name: 'name2', fullPath: 'fullPath2' },
              ],
            }),
          },
        });

        await waitForPromises();
        await selectComplianceFrameworksOption();

        await verify({ manifest, verifyRuleMode, wrapper });
      });
    });
  });
});
