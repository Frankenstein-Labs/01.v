import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlAvatarLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RequestedChangesComponent from 'ee/vue_merge_request_widget/components/checks/requested_changes.vue';
import requestedChangesQuery from 'ee/vue_merge_request_widget/components/checks/queries/requested_changes.query.graphql';
import updateMergeRequestMutation from 'ee/vue_merge_request_widget/components/checks/queries/update_merge_request.mutation.graphql';
import removeChangeRequestMutation from 'ee/vue_merge_request_widget/components/checks/queries/remove_change_request.mutation.graphql';

Vue.use(VueApollo);

describe('Requested changes merge checks component', () => {
  let wrapper;
  let updateMergeRequestMutationMock;
  let removeChangeRequestMutationMock;

  const findGlModal = () => wrapper.findComponent(GlModal);
  const findRemoveChangeRequestModel = () => wrapper.findAllComponents(GlModal).at(1);
  const findActionButtons = () => wrapper.findAllComponentsByTestId('extension-actions-button');

  function createComponent({ canMerge = true, status = 'FAILED' } = {}) {
    updateMergeRequestMutationMock = jest.fn().mockResolvedValue({
      data: {
        mergeRequestUpdate: {
          mergeRequest: {
            id: '1',
          },
          errors: [],
        },
      },
    });
    removeChangeRequestMutationMock = jest.fn().mockResolvedValue({
      data: {
        mergeRequestDestroyRequestedChanges: {
          mergeRequest: {
            id: '1',
          },
          errors: [],
        },
      },
    });
    const apolloProvider = createMockApollo([
      [updateMergeRequestMutation, updateMergeRequestMutationMock],
      [removeChangeRequestMutation, removeChangeRequestMutationMock],
      [
        requestedChangesQuery,
        jest.fn().mockResolvedValue({
          data: {
            project: {
              id: '1',
              mergeRequest: {
                id: '1',
                changeRequesters: {
                  nodes: [
                    {
                      id: 'gid://gitlab/User/1',
                      avatarUrl: '/',
                      name: 'Admin',
                      username: 'root',
                      webPath: '/',
                    },
                  ],
                },
                userPermissions: {
                  canMerge,
                },
              },
            },
          },
        }),
      ],
    ]);

    wrapper = mountExtended(RequestedChangesComponent, {
      apolloProvider,
      propsData: {
        mr: {
          targetProjectFullPath: 'gitlab-org/gitlab',
          iid: '1',
          targetBranch: 'master',
        },
        check: {
          identifier: 'requested_changes',
          status,
        },
      },
    });
  }

  it.each`
    canMerge | disabled
    ${true}  | ${undefined}
    ${false} | ${'true'}
  `(
    'renders button with disabled attribute as $disabled when canMerge is $canMerge',
    async ({ canMerge, disabled }) => {
      createComponent({ canMerge });

      await waitForPromises();

      expect(findActionButtons().at(0).attributes('aria-disabled')).toBe(disabled);
    },
  );

  it('renders disabled button when canMerge is false', async () => {
    createComponent({ canMerge: false });

    await waitForPromises();

    expect(findActionButtons().at(0).text()).toBe("Can't bypass");
  });

  it('renders multiple buttons when status is WARNING', async () => {
    createComponent({ status: 'WARNING' });

    await waitForPromises();

    expect(findActionButtons()).toHaveLength(2);
    expect(findActionButtons().at(0).text()).toBe('Bypassed');
    expect(findActionButtons().at(0).attributes('aria-disabled')).toBe('true');
    expect(findActionButtons().at(1).text()).toBe('Remove');
  });

  it('does not render remove button when canMerge is false', async () => {
    createComponent({ status: 'WARNING', canMerge: false });

    await waitForPromises();

    expect(findActionButtons()).toHaveLength(1);
    expect(findActionButtons().at(0).text()).toBe('Bypassed');
    expect(findActionButtons().at(0).attributes('aria-disabled')).toBe('true');
  });

  describe('when status is FAILED', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders bypass button for modal primary action', async () => {
      findActionButtons().at(0).vm.$emit('click');

      await Vue.nextTick();

      expect(findGlModal().props('actionPrimary')).toEqual({
        text: 'Bypass',
      });
    });

    it('shows confirm modal when clicking bypass button', async () => {
      findActionButtons().at(0).vm.$emit('click');

      await Vue.nextTick();

      expect(findGlModal().props('visible')).toBe(true);
    });

    it('sends GraphQL mutation when confirming in modal', () => {
      findGlModal().vm.$emit('primary');

      expect(updateMergeRequestMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          iid: '1',
          overrideRequestedChanges: true,
          projectPath: 'gitlab-org/gitlab',
        }),
      );
    });

    it('renders list of change requesters', () => {
      expect(wrapper.findAllComponents(GlAvatarLink)).toHaveLength(1);
    });
  });

  describe('when status is WARNING', () => {
    beforeEach(async () => {
      createComponent({ status: 'WARNING' });

      await waitForPromises();
    });

    it('renders remove button for modal primary action', async () => {
      findActionButtons().at(0).vm.$emit('click');

      await Vue.nextTick();

      expect(findGlModal().props('actionPrimary')).toEqual({
        text: 'Remove',
      });
    });

    it('shows confirm modal when clicking remove button', async () => {
      findActionButtons().at(1).vm.$emit('click');

      await Vue.nextTick();

      expect(findGlModal().props('visible')).toBe(true);
    });

    it('sends GraphQL mutation when confirming in modal', () => {
      findGlModal().vm.$emit('primary');

      expect(updateMergeRequestMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          iid: '1',
          overrideRequestedChanges: false,
          projectPath: 'gitlab-org/gitlab',
        }),
      );
    });
  });

  describe('removing a change request', () => {
    describe('when current user has not requested changes', () => {
      beforeEach(async () => {
        gon.current_user_id = 2;

        createComponent();

        await waitForPromises();
      });

      it('does not render remove button', () => {
        expect(findActionButtons()).toHaveLength(1);
      });
    });

    describe('when current user has requested changes', () => {
      beforeEach(async () => {
        gon.current_user_id = 1;

        createComponent();

        await waitForPromises();
      });

      it('renders remove button', () => {
        expect(findActionButtons()).toHaveLength(2);
      });

      it('shows confirm modal when clicking remove button', async () => {
        findActionButtons().at(0).vm.$emit('click');

        await Vue.nextTick();

        expect(findRemoveChangeRequestModel().props('visible')).toBe(true);
      });

      it('sends GraphQL mutation when confirming in modal', () => {
        findRemoveChangeRequestModel().vm.$emit('primary');

        expect(removeChangeRequestMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            iid: '1',
            projectPath: 'gitlab-org/gitlab',
          }),
        );
      });
    });
  });
});
