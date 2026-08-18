import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  APPROVAL_POLICY_TYPE,
  POLICY_TYPE_COMPONENT_OPTIONS,
} from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';
import AutoDismissedActionBanner from 'ee/security_orchestration/components/policy_editor/auto_dismissed_action_banner.vue';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';

describe('App component', () => {
  let wrapper;

  const findPolicySelection = () => wrapper.findComponent(PolicyTypeSelector);
  const findPolicyEditor = () => wrapper.findComponent(EditorWrapper);
  const findTitle = () => wrapper.findByTestId('page-heading').text();
  const findAdvancedEditorToggle = () => wrapper.findComponent(AdvancedEditorToggle);
  const findAutoDismissedActionBanner = () => wrapper.findComponent(AutoDismissedActionBanner);

  const factory = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(App, {
      provide: { assignedPolicyProject: {}, ...provide },
      stubs: { PageHeading },
    });
  };

  describe('rendering', () => {
    it('displays the policy selection when there is no query parameter', () => {
      factory();
      expect(findPolicySelection().exists()).toBe(true);
      expect(findPolicyEditor().exists()).toBe(false);

      expect(findAutoDismissedActionBanner().exists()).toBe(false);
      expect(findAdvancedEditorToggle().exists()).toBe(false);
    });

    it('displays the policy editor when there is a type query parameter', () => {
      jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(APPROVAL_POLICY_TYPE);
      factory({ provide: { existingPolicy: { id: 'policy-id', value: 'approval' } } });
      expect(findPolicySelection().exists()).toBe(false);
      expect(findPolicyEditor().exists()).toBe(true);
      expect(findPolicyEditor().props('selectedPolicy')).toEqual(
        POLICY_TYPE_COMPONENT_OPTIONS.legacyApproval,
      );
    });
  });

  describe('page title', () => {
    describe.each`
      value                        | titleSuffix                          | expectedPolicy
      ${'approval'}                | ${'merge request approval policy'}   | ${POLICY_TYPE_COMPONENT_OPTIONS.legacyApproval}
      ${'scanExecution'}           | ${'scan execution policy'}           | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution}
      ${'pipelineExecution'}       | ${'pipeline execution policy'}       | ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution}
      ${'vulnerabilityManagement'} | ${'vulnerability management policy'} | ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement}
      ${'dependencyFirewall'}      | ${'dependency firewall policy'}      | ${POLICY_TYPE_COMPONENT_OPTIONS.dependencyFirewall}
    `('$titleSuffix', ({ titleSuffix, value, expectedPolicy }) => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS[value].urlParameter);
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe(`New ${titleSuffix}`);
        expect(findPolicyEditor().props('selectedPolicy')).toEqual(expectedPolicy);
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value } } });
        expect(findTitle()).toBe(`Edit ${titleSuffix}`);
        expect(findPolicyEditor().props('selectedPolicy')).toEqual(expectedPolicy);
      });
    });

    describe('invalid url parameter', () => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('invalid');
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe('New policy');
        expect(findPolicyEditor().exists()).toBe(false);
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value: 'scanResult' } } });
        expect(findTitle()).toBe('Edit policy');
        expect(findPolicyEditor().exists()).toBe(false);
      });
    });

    describe.each`
      value                        | expected
      ${'approval'}                | ${false}
      ${'scanExecution'}           | ${false}
      ${'pipelineExecution'}       | ${false}
      ${'vulnerabilityManagement'} | ${true}
      ${'dependencyFirewall'}      | ${false}
    `('experimental banner', ({ value, expected }) => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS[value].urlParameter);
      });

      it('does not render banner for other policies except for vulnerability type', () => {
        factory();
        expect(findAutoDismissedActionBanner().exists()).toBe(expected);
      });
    });
  });
});
