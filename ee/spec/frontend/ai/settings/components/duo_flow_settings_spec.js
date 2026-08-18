import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');

describe('DuoFlowSettings', () => {
  let wrapper;
  const defaultProvide = {
    isSaaS: false,
    isGroupSettings: false,
    glFeatures: {
      duoFoundationalFlows: true,
    },
    duoRemoteFlowsCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSettings: false,
    },
    duoFoundationalFlowsCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSettings: false,
    },
    availableFoundationalFlows: [],
    duoEnterpriseActive: false,
    initialCodeReviewFlowConsentGiven: false,
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRemoteFlowsCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(0);
  const findFoundationalFlowsCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(1);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findAllCascadingLocks = () => wrapper.findAllComponents(CascadingLockIcon);
  const findFoundationalFlowSelector = () =>
    wrapper.findComponent({ name: 'FoundationalFlowSelector' });
  const findDefaultImageRegistryInput = () =>
    wrapper.findComponent('[data-testid="duo-workflows-default-image-registry-input"]');
  const findFlowHeader = () => wrapper.find('[data-testid="flows-subsection-header"]');
  const findFlowDescription = () => wrapper.find('[data-testid="flows-subsection-description"]');

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(DuoFlowSettings, {
      propsData: {
        disabledCheckbox: false,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        selectedFoundationalFlowIds: [],
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        GlFormCheckbox,
        GlFormGroup,
        GlFormInput,
        GlLink,
        GlSprintf,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the flows section header', () => {
      expect(findFlowHeader().text()).toBe('Flows');
    });

    it('renders the flows section description', () => {
      expect(findFlowDescription().text()).toBe(
        'Combine one or more agents to solve a complex problem.',
      );
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('Flow execution');
    });

    it('renders both checkboxes', () => {
      expect(wrapper.findAllComponents(GlFormCheckbox)).toHaveLength(2);
    });

    it('renders the remote flows checkbox with correct label', () => {
      expect(findRemoteFlowsCheckbox().exists()).toBe(true);
      expect(wrapper.findAll('#duo-flow-checkbox-label').at(0).text()).toBe('Allow flow execution');
    });

    it('renders the foundational flows checkbox with correct label', () => {
      expect(findFoundationalFlowsCheckbox().exists()).toBe(true);
      expect(wrapper.findAll('#duo-flow-checkbox-label').at(1).text()).toBe(
        'Allow foundational flows',
      );
    });

    it('sets initial remote flows checkbox state based on duoRemoteFlowsAvailability prop', () => {
      expect(findRemoteFlowsCheckbox().props('checked')).toBe(false);
    });

    it('sets initial foundational flows checkbox state based on duoFoundationalFlowsAvailability prop', () => {
      expect(findFoundationalFlowsCheckbox().props('checked')).toBe(false);
    });

    it('renders help link with correct href', () => {
      expect(findHelpLink().exists()).toBe(true);
      expect(findHelpLink().attributes('href')).toBe(
        '/help/user/duo_agent_platform/flows/_index.md',
      );
      expect(findHelpLink().attributes('target')).toBe('_blank');
    });

    it('does not render cascading locks by default', () => {
      expect(findAllCascadingLocks()).toHaveLength(0);
    });

    it('disables foundational flows checkbox when remote flows is disabled', () => {
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
    });
  });

  describe('when duoRemoteFlowsAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ duoRemoteFlowsAvailability: true });
    });

    it('sets remote flows checkbox as checked', () => {
      expect(findRemoteFlowsCheckbox().props('checked')).toBe(true);
    });

    it('enables the foundational flows checkbox', () => {
      expect(findFoundationalFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });
  });

  describe('when duoFoundationalFlowsAvailability is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        duoRemoteFlowsAvailability: true,
        duoFoundationalFlowsAvailability: true,
      });
    });

    it('sets foundational flows checkbox as checked', () => {
      expect(findFoundationalFlowsCheckbox().props('checked')).toBe(true);
    });
  });

  describe('when disabledCheckbox is false', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        disabledCheckbox: false,
        duoRemoteFlowsAvailability: true,
      });
    });

    it('enables the remote flows checkbox', () => {
      expect(findRemoteFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });

    it('enables the foundational flows checkbox when remote flows is enabled', () => {
      expect(findFoundationalFlowsCheckbox().attributes('disabled')).toBe(undefined);
    });
  });

  describe('when disabledCheckbox is true', () => {
    beforeEach(() => {
      wrapper = createWrapper({ disabledCheckbox: true });
    });

    it('disables both checkboxes', () => {
      expect(findRemoteFlowsCheckbox().props('disabled')).toBe(true);
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
    });
  });

  describe('when remote flows is disabled', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
      });
    });

    it('disables the foundational flows checkbox', () => {
      expect(findFoundationalFlowsCheckbox().props('disabled')).toBe(true);
    });
  });

  describe('cascading locks for remote flows', () => {
    describe('when locked by application setting', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoRemoteFlowsCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByApplicationSettings')).toBe(true);
      });
    });

    describe('when locked by ancestor', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoRemoteFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByGroupAncestor')).toBe(true);
      });
    });
  });

  describe('cascading locks for foundational flows', () => {
    describe('when locked by application setting', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByApplicationSettings')).toBe(true);
      });
    });

    describe('when locked by ancestor', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
          },
        );
      });

      it('shows cascading lock', () => {
        expect(findAllCascadingLocks()).toHaveLength(1);
        expect(findAllCascadingLocks().at(0).props('isLockedByGroupAncestor')).toBe(true);
      });
    });

    describe('when both checkboxes are locked', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {},
          {
            duoRemoteFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        );
      });

      it('shows both cascading locks', () => {
        expect(findAllCascadingLocks()).toHaveLength(2);
      });
    });
  });

  describe('help text variations', () => {
    describe('when isGroupSettings is true', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { isGroupSettings: true });
      });

      it('renders the group-specific help text for remote flows', () => {
        expect(wrapper.text()).toContain('this group and its subgroups and projects');
      });

      it('renders the group-specific help text for foundational flows', () => {
        expect(wrapper.text()).toContain(
          'Allow GitLab Duo agents to execute foundational flows in this group and its subgroups and projects',
        );
      });
    });

    describe('when isGroupSettings is false', () => {
      beforeEach(() => {
        wrapper = createWrapper({}, { isGroupSettings: false });
      });

      it('renders the instance-specific help text for remote flows', () => {
        expect(wrapper.text()).toContain('for the instance');
      });

      it('renders the instance-specific help text for foundational flows', () => {
        expect(wrapper.text()).toContain(
          'Allow GitLab Duo agents to execute foundational flows for the instance',
        );
      });
    });
  });

  describe('checkbox interactions', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('emits change event when remote flows checkbox is toggled', async () => {
      await findRemoteFlowsCheckbox().vm.$emit('input', true);

      expect(wrapper.emitted('change')).toHaveLength(1);
      expect(wrapper.emitted('change')[0]).toEqual([true]);
    });

    it('emits change-foundational-flows event when foundational flows checkbox is toggled', async () => {
      await findFoundationalFlowsCheckbox().vm.$emit('input', true);

      expect(wrapper.emitted('change-foundational-flows')).toHaveLength(1);
      expect(wrapper.emitted('change-foundational-flows')[0]).toEqual([true]);
    });
  });

  describe('foundational flow selector', () => {
    describe('when foundational flows are disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          duoRemoteFlowsAvailability: true,
          duoFoundationalFlowsAvailability: false,
        });
      });

      it('renders the flow selector as hidden', () => {
        expect(findFoundationalFlowSelector().isVisible()).toBe(false);
      });

      it('passes disabled state to the selector', () => {
        expect(findFoundationalFlowSelector().props('disabled')).toBe(true);
      });
    });

    describe('when foundational flows are enabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          duoRemoteFlowsAvailability: true,
          duoFoundationalFlowsAvailability: true,
          selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1'],
        });
      });

      it('renders the flow selector', () => {
        expect(findFoundationalFlowSelector().exists()).toBe(true);
      });

      it('passes the selected flow ids to the selector', () => {
        expect(findFoundationalFlowSelector().props('value')).toEqual([
          'code_review/v1',
          'bug_triage/v1',
        ]);
      });

      it('passes disabled state to the selector', () => {
        expect(findFoundationalFlowSelector().props('disabled')).toBe(false);
      });

      it('emits change-selected-flow-ids when selector value changes', async () => {
        await findFoundationalFlowSelector().vm.$emit('input', [
          'documentation/v1',
          'sast_fp_detection/v1',
          'resolve_sast_vulnerability/v1',
        ]);

        expect(wrapper.emitted('change-selected-flow-ids')).toHaveLength(1);
        expect(wrapper.emitted('change-selected-flow-ids')[0]).toEqual([
          ['documentation/v1', 'sast_fp_detection/v1', 'resolve_sast_vulnerability/v1'],
        ]);
      });
    });

    describe('when foundational flows checkbox is disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          duoRemoteFlowsAvailability: true,
          duoFoundationalFlowsAvailability: true,
          disabledCheckbox: true,
        });
      });

      it('passes disabled state to the selector', () => {
        expect(findFoundationalFlowSelector().props('disabled')).toBe(true);
      });
    });

    describe('when foundational flows checkbox is unchecked', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          duoRemoteFlowsAvailability: true,
          duoFoundationalFlowsAvailability: true,
          selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1'],
        });
      });

      it('clears selected flow ids when checkbox is unchecked', async () => {
        await findFoundationalFlowsCheckbox().vm.$emit('input', false);

        expect(wrapper.emitted('change-selected-flow-ids')).toHaveLength(1);
        expect(wrapper.emitted('change-selected-flow-ids')[0]).toEqual([[]]);
      });
    });

    describe('when remote flows are disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: true,
        });
      });

      it('passes disabled state to the selector', () => {
        expect(findFoundationalFlowSelector().props('disabled')).toBe(true);
      });
    });

    describe('when locked by cascading settings', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
          },
          {
            duoFoundationalFlowsCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
            },
          },
        );
      });

      it('passes disabled state to the selector', () => {
        expect(findFoundationalFlowSelector().props('disabled')).toBe(true);
      });
    });
  });

  describe('default image registry input', () => {
    describe('when isGroupSettings is false and foundational flows are enabled', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
            duoWorkflowsDefaultImageRegistry: 'registry.example.com',
          },
          { isGroupSettings: false },
        );
      });

      it('renders the image registry input', () => {
        expect(findDefaultImageRegistryInput().exists()).toBe(true);
      });

      it('sets the input value from prop', () => {
        expect(findDefaultImageRegistryInput().props('value')).toBe('registry.example.com');
      });

      it('has the correct label', () => {
        expect(wrapper.text()).toContain('Image registry');
      });

      it('has the correct help text', () => {
        expect(wrapper.text()).toContain(
          'Container registry for the foundational flow image. Enter either a registry hostname to use the default image from that registry or a full image reference to override the image entirely (for example, "registry.example.com/group/project/image:tag"). Leave blank to use "registry.gitlab.com".',
        );
      });

      it('has the correct placeholder', () => {
        expect(findDefaultImageRegistryInput().attributes('placeholder')).toBe(
          'registry.gitlab.com',
        );
      });

      it('emits change-default-image-registry event when input value changes', async () => {
        wrapper.vm.defaultImageRegistry = 'custom.registry.io';
        await wrapper.vm.onDefaultImageRegistryChanged();

        expect(wrapper.emitted('change-default-image-registry')).toBeDefined();
        expect(wrapper.emitted('change-default-image-registry')[0]).toEqual(['custom.registry.io']);
      });
    });

    describe('when isGroupSettings is true', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
          },
          { isGroupSettings: true },
        );
      });

      it('does not render the image registry input for group settings', () => {
        expect(findDefaultImageRegistryInput().exists()).toBe(false);
      });
    });

    describe('when isSaaS is true', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
          },
          { isSaaS: true, isGroupSettings: false },
        );
      });

      it('does not render the image registry input on SaaS', () => {
        expect(findDefaultImageRegistryInput().exists()).toBe(false);
      });
    });

    describe('when foundational flows are disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: false,
          },
          { isGroupSettings: false },
        );
      });

      it('renders the image registry input as disabled', () => {
        expect(findDefaultImageRegistryInput().exists()).toBe(true);
        expect(findDefaultImageRegistryInput().attributes('disabled')).toBe('disabled');
      });
    });

    describe('when checkbox is disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
            disabledCheckbox: true,
          },
          { isGroupSettings: false },
        );
      });

      it('disables the image registry input', () => {
        expect(findDefaultImageRegistryInput().attributes('disabled')).toBe('disabled');
      });
    });

    describe('when remote flows are disabled', () => {
      beforeEach(() => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: false,
            duoFoundationalFlowsAvailability: true,
          },
          { isGroupSettings: false },
        );
      });

      it('disables the image registry input', () => {
        expect(findDefaultImageRegistryInput().attributes('disabled')).toBe('disabled');
      });
    });
  });

  describe('Code Review Flow consent modal', () => {
    const CODE_REVIEW_REFERENCE = 'code_review/v1';
    const OTHER_FLOW_REFERENCE = 'bug_triage/v1';

    const consentProvide = {
      isGroupSettings: true,
      duoEnterpriseActive: true,
      initialCodeReviewFlowConsentGiven: false,
      glFeatures: {
        duoFoundationalFlows: true,
      },
    };

    beforeEach(() => {
      wrapper = createWrapper(
        {
          duoRemoteFlowsAvailability: true,
          duoFoundationalFlowsAvailability: true,
          selectedFoundationalFlowIds: [],
        },
        consentProvide,
      );
    });

    afterEach(() => {
      confirmAction.mockReset();
    });

    describe('DuoCodeReviewConsentMessage props', () => {
      it('passes codeReviewFlowSelected as false when code review is not selected', () => {
        expect(wrapper.vm.codeReviewFlowSelected).toBe(false);
      });

      it('passes codeReviewFlowSelected as true when code review is selected', async () => {
        confirmAction.mockResolvedValue(true);
        findFoundationalFlowSelector().vm.$emit('input', [CODE_REVIEW_REFERENCE]);
        await waitForPromises();

        expect(wrapper.vm.codeReviewFlowSelected).toBe(true);
      });

      it('passes codeReviewFlowConsentGiven as false initially', () => {
        expect(wrapper.vm.codeReviewFlowConsentGiven).toBe(false);
      });

      it('passes codeReviewFlowConsentGiven as true after confirmation', async () => {
        confirmAction.mockResolvedValue(true);
        findFoundationalFlowSelector().vm.$emit('input', [CODE_REVIEW_REFERENCE]);
        await waitForPromises();

        expect(wrapper.vm.codeReviewFlowConsentGiven).toBe(true);
      });

      it('passes codeReviewFlowConsentGiven as true from the start when initialCodeReviewFlowConsentGiven is true', () => {
        wrapper = createWrapper(
          {
            duoRemoteFlowsAvailability: true,
            duoFoundationalFlowsAvailability: true,
            selectedFoundationalFlowIds: [CODE_REVIEW_REFERENCE],
          },
          { ...consentProvide, initialCodeReviewFlowConsentGiven: true },
        );

        expect(wrapper.vm.codeReviewFlowConsentGiven).toBe(true);
      });
    });

    describe('when user cancels the consent modal', () => {
      beforeEach(async () => {
        confirmAction.mockResolvedValue(false);
        findFoundationalFlowSelector().vm.$emit('input', [CODE_REVIEW_REFERENCE]);
        await waitForPromises();
      });

      it('shows the consent modal', () => {
        expect(confirmAction).toHaveBeenCalledTimes(1);
      });

      it('does not add Code Review to the selection', () => {
        expect(findFoundationalFlowSelector().props('value')).not.toContain(CODE_REVIEW_REFERENCE);
      });

      it('does not emit change-selected-flow-ids', () => {
        expect(wrapper.emitted('change-selected-flow-ids')).toBeUndefined();
      });

      it('increments the selector key to force a remount of the flow selector', () => {
        expect(wrapper.vm.selectorKey).toBe(1);
      });

      it('does not update codeReviewFlowConsentGiven', () => {
        expect(wrapper.vm.codeReviewFlowConsentGiven).toBe(false);
      });
    });

    describe('when user confirms the consent modal', () => {
      beforeEach(async () => {
        confirmAction.mockResolvedValue(true);
        findFoundationalFlowSelector().vm.$emit('input', [CODE_REVIEW_REFERENCE]);
        await waitForPromises();
      });

      it('adds Code Review to the selection', () => {
        expect(findFoundationalFlowSelector().props('value')).toContain(CODE_REVIEW_REFERENCE);
      });

      it('emits change-selected-flow-ids with Code Review included', () => {
        expect(wrapper.emitted('change-selected-flow-ids')).toBeDefined();
        expect(wrapper.emitted('change-selected-flow-ids')[0][0]).toContain(CODE_REVIEW_REFERENCE);
      });

      it('emits consent-given', () => {
        expect(wrapper.emitted('consent-given')).toBeDefined();
      });

      it('does not increment the selector key', () => {
        expect(wrapper.vm.selectorKey).toBe(0);
      });

      it('sets codeReviewFlowConsentGiven to true', () => {
        expect(wrapper.vm.codeReviewFlowConsentGiven).toBe(true);
      });
    });

    describe('when adding a non-Code-Review flow', () => {
      beforeEach(async () => {
        findFoundationalFlowSelector().vm.$emit('input', [OTHER_FLOW_REFERENCE]);
        await waitForPromises();
      });

      it('does not show the modal', () => {
        expect(confirmAction).not.toHaveBeenCalled();
      });

      it('adds the flow to the selection immediately', () => {
        expect(findFoundationalFlowSelector().props('value')).toContain(OTHER_FLOW_REFERENCE);
      });
    });
  });
});
