import { GlModal, GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ProjectModal from 'ee/security_orchestration/components/policies/project_modal.vue';
import linkSecurityPolicyProject from 'ee/security_orchestration/graphql/mutations/link_security_policy_project.mutation.graphql';
import unlinkSecurityPolicyProject from 'ee/security_orchestration/graphql/mutations/unlink_security_policy_project.mutation.graphql';
import SppSelector from 'ee/security_orchestration/components/policies/spp_selector.vue';
import {
  mockLinkSecurityPolicyProjectResponses,
  mockUnlinkSecurityPolicyProjectResponses,
} from '../../mocks/mock_apollo';

Vue.use(VueApollo);

describe('ProjectModal Component', () => {
  let wrapper;
  const sampleProject = {
    id: 'gid://gitlab/Project/1',
    name: 'Test 1',
  };

  const findSppSelector = () => wrapper.findComponent(SppSelector);
  const findUnlinkButton = () => wrapper.findComponentByTestId('unlink-button');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findModal = () => wrapper.findComponent(GlModal);

  const selectProject = async ({ project = sampleProject, shouldSubmit = true } = {}) => {
    findSppSelector().vm.$emit('project-clicked', project);
    await waitForPromises();

    if (shouldSubmit) {
      findModal().vm.$emit('ok');
      await waitForPromises();
    }
  };

  const createWrapper = ({
    mutationQuery = linkSecurityPolicyProject,
    mutationResult = mockLinkSecurityPolicyProjectResponses.success,
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(ProjectModal, {
      apolloProvider: createMockApollo([[mutationQuery, mutationResult]]),
      stubs: {
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
      provide: {
        disableSecurityPolicyProject: false,
        documentationPath: 'test/path/index.md',
        namespacePath: 'path/to/project/or/group',
        assignedPolicyProject: null,
        ...provide,
      },
    });
  };

  const createWrapperAndSelectProject = async (data) => {
    createWrapper(data);
    await selectProject();
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('passes down correct properties/attributes to the gl-modal component', () => {
      expect(findModal().props()).toMatchObject({
        modalId: 'scan-new-policy',
        size: 'sm',
        visible: false,
        title: 'Select security policy project',
      });

      expect(findModal().attributes()).toEqual({
        'ok-disabled': 'true',
        'ok-title': 'Save',
        'cancel-variant': 'light',
      });
    });

    it('does not display the remove button when no project is selected', () => {
      expect(findUnlinkButton().exists()).toBe(false);
    });

    it('does not display a warning', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  it('emits close event when gl-modal emits change event', async () => {
    createWrapper();
    await selectProject({ shouldSubmit: false });

    findModal().vm.$emit('change');
    expect(wrapper.emitted('close')).toEqual([[]]);
    expect(findSppSelector().props('selectedProject').name).toBe('Test 1');

    // should restore the previous state when action is not submitted
    await nextTick();
    expect(findSppSelector().props('selectedProject')).toBe(null);
  });

  describe('unlinking project', () => {
    const unlinkText =
      'Unlinking a security policy project will stop enforcing all policies from the linked project on this namespace. The policy project and its policies will not be deleted. Save to confirm this action.';
    const assignedPolicyProject = { id: 'gid://gitlab/Project/0', name: 'Test 0' };

    it('displays the warning text when unlink has been clicked', async () => {
      createWrapper({ provide: { assignedPolicyProject } });

      expect(findModal().attributes('ok-disabled')).toBe('true');
      expect(wrapper.findByText(unlinkText).exists()).toBe(false);

      await findUnlinkButton().vm.$emit('click');

      expect(wrapper.findByText(unlinkText).exists()).toBe(true);
      expect(findModal().attributes('ok-disabled')).toBeUndefined();
    });

    it.each`
      mutationType | expectedVariant | expectedText                                       | expectedHasPolicyProject | expectedSelectedProject
      ${'success'} | ${'success'}    | ${'Security policy project will be unlinked soon'} | ${false}                 | ${null}
      ${'failure'} | ${'danger'}     | ${'unlink failed'}                                 | ${true}                  | ${assignedPolicyProject}
    `(
      'unlinks a project and handles $mutationType case',
      async ({
        mutationType,
        expectedVariant,
        expectedText,
        expectedHasPolicyProject,
        expectedSelectedProject,
      }) => {
        createWrapper({
          mutationQuery: unlinkSecurityPolicyProject,
          mutationResult: mockUnlinkSecurityPolicyProjectResponses[mutationType],
          provide: { assignedPolicyProject },
        });

        await findUnlinkButton().vm.$emit('click');
        await findModal().vm.$emit('ok');
        await waitForPromises();

        expect(wrapper.emitted('project-updated')).toEqual([
          [
            {
              text: expectedText,
              variant: expectedVariant,
              hasPolicyProject: expectedHasPolicyProject,
            },
          ],
        ]);

        expect(findSppSelector().props('selectedProject')).toEqual(expectedSelectedProject);
      },
    );
  });

  describe('project selection', () => {
    it('enables the "Save" button only if a new project is selected', async () => {
      createWrapper({
        provide: { assignedPolicyProject: { id: 'gid://gitlab/Project/0', name: 'Test 0' } },
      });
      await waitForPromises();

      expect(findModal().attributes('ok-disabled')).toBe('true');

      findSppSelector().vm.$emit('project-clicked', {
        id: 'gid://gitlab/Project/1',
        name: 'Test 1',
      });

      await waitForPromises();

      expect(findModal().attributes('ok-disabled')).toBeUndefined();
    });

    it.each`
      messageType  | factoryFn                                                                                                  | text                                                 | variant      | hasPolicyProject | selectedProject
      ${'success'} | ${createWrapperAndSelectProject}                                                                           | ${'Security policy project was linked successfully'} | ${'success'} | ${true}          | ${sampleProject}
      ${'failure'} | ${() => createWrapperAndSelectProject({ mutationResult: mockLinkSecurityPolicyProjectResponses.failure })} | ${'link failed'}                                     | ${'danger'}  | ${false}         | ${undefined}
    `(
      'emits an event with $messageType message',
      async ({ factoryFn, text, variant, hasPolicyProject, selectedProject }) => {
        await factoryFn();

        expect(wrapper.emitted('project-updated')).toEqual([
          [
            {
              text,
              variant,
              hasPolicyProject,
            },
          ],
        ]);

        if (selectedProject) {
          expect(findSppSelector().props('selectedProject')).toEqual(selectedProject);
        }
      },
    );

    it('displays the remove button when a project is selected', async () => {
      createWrapper({
        provide: { assignedPolicyProject: { id: 'gid://gitlab/Project/0', name: 'Test 0' } },
      });
      await nextTick();

      expect(findUnlinkButton().exists()).toBe(true);
    });
  });

  describe('disabled', () => {
    beforeEach(() => {
      createWrapper({ provide: { disableSecurityPolicyProject: true } });
    });

    it('disables the dropdown', () => {
      expect(findSppSelector().props('disabled')).toBe(true);
    });

    it('displays a warning', () => {
      expect(findAlert().text()).toBe('Only owners can update Security Policy Project');
    });
  });
});
