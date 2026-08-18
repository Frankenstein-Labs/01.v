import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityPolicyPipelineCheck from 'ee/vue_merge_request_widget/components/checks/security_policy_pipeline_check.vue';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';

describe('SecurityPolicyPipelineCheck merge checks component', () => {
  let wrapper;

  const policiesPath = '/security-path';

  function createComponent({ status = 'FAILED', securityPoliciesPath = policiesPath } = {}) {
    wrapper = shallowMountExtended(SecurityPolicyPipelineCheck, {
      propsData: {
        mr: {
          securityPoliciesPath,
        },
        check: {
          identifier: 'SECURITY_POLICY_PIPELINE_CHECK',
          status,
        },
      },
      stubs: {
        MergeChecksMessage,
      },
    });
  }

  const findActionButtons = () => wrapper.findComponent(ActionButtons);
  const findHelpIcon = () => wrapper.findByTestId('security-policy-pipeline-help-icon');
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('action buttons', () => {
    it.each`
      status        | path            | hasButtons | rendersText
      ${'SUCCESS'}  | ${policiesPath} | ${true}    | ${'renders'}
      ${'SUCCESS'}  | ${''}           | ${false}   | ${'does not render'}
      ${'SUCCESS'}  | ${null}         | ${false}   | ${'does not render'}
      ${'FAILED'}   | ${policiesPath} | ${true}    | ${'renders'}
      ${'FAILED'}   | ${''}           | ${false}   | ${'does not render'}
      ${'FAILED'}   | ${null}         | ${false}   | ${'does not render'}
      ${'WARNING'}  | ${policiesPath} | ${true}    | ${'renders'}
      ${'WARNING'}  | ${''}           | ${false}   | ${'does not render'}
      ${'CHECKING'} | ${policiesPath} | ${true}    | ${'renders'}
      ${'CHECKING'} | ${''}           | ${false}   | ${'does not render'}
      ${'INACTIVE'} | ${policiesPath} | ${false}   | ${'does not render'}
      ${'INACTIVE'} | ${''}           | ${false}   | ${'does not render'}
      ${'INACTIVE'} | ${null}         | ${false}   | ${'does not render'}
    `(
      '$rendersText link to security policies when status is $status and path is "$path"',
      ({ status, path, hasButtons }) => {
        createComponent({ status, securityPoliciesPath: path });

        const actionButtons = findActionButtons();

        if (hasButtons) {
          expect(actionButtons.exists()).toBe(true);
          const buttons = actionButtons.props('tertiaryButtons');
          expect(buttons).toHaveLength(1);
          expect(buttons[0]).toMatchObject({
            href: path,
            text: 'View policies',
          });
        } else if (actionButtons.exists()) {
          expect(actionButtons.props('tertiaryButtons')).toHaveLength(0);
        } else {
          expect(actionButtons.exists()).toBe(false);
        }
      },
    );
  });

  describe('help icon and popover', () => {
    it('renders help icon and popover when securityPoliciesPath is provided', () => {
      createComponent({ securityPoliciesPath: policiesPath });

      expect(findHelpIcon().exists()).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('uses a unique ID to link the help icon and popover', () => {
      createComponent({ securityPoliciesPath: policiesPath });

      const iconId = findHelpIcon().attributes('id');
      const popoverTarget = findPopover().props('target');

      expect(iconId).toMatch(/^security-policy-pipeline-help-icon-\d+$/);
      expect(popoverTarget).toBe(iconId);
    });

    it('does not render help icon when securityPoliciesPath is not provided', () => {
      createComponent({ securityPoliciesPath: '' });

      expect(findHelpIcon().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });

    it('does not render help icon when check is inactive', () => {
      createComponent({ status: 'INACTIVE', securityPoliciesPath: policiesPath });

      expect(findHelpIcon().exists()).toBe(false);
    });
  });
});
