import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import DeleteDeployment from 'ee/usage_quotas/pages/components/delete_deployment.vue';
import {
  deleteDeploymentSuccess,
  restoreDeploymentSuccess,
  deleteDeploymentError,
  restoreDeploymentError,
} from 'ee_jest/usage_quotas/pages/components/mock_data';
import deletePagesDeploymentMutation from '~/gitlab_pages/queries/delete_pages_deployment.mutation.graphql';
import restorePagesDeploymentMutation from '~/gitlab_pages/queries/restore_pages_deployment.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('DeleteDeployment', () => {
  let wrapper;
  let button;

  const deleteDeploymentHandler = jest.fn().mockResolvedValue(deleteDeploymentSuccess);
  const restoreDeploymentHandler = jest.fn().mockResolvedValue(restoreDeploymentSuccess);

  const createComponent = (
    props = {},
    handlers = {
      deleteDeploymentHandler,
      restoreDeploymentHandler,
    },
  ) => {
    createAlert.mockClear();
    return shallowMountExtended(DeleteDeployment, {
      propsData: {
        id: '123',
        active: true,
        ...props,
      },
      apolloProvider: createMockApollo([
        [deletePagesDeploymentMutation, handlers.deleteDeploymentHandler],
        [restorePagesDeploymentMutation, handlers.restoreDeploymentHandler],
      ]),
    });
  };

  describe('when state is active', () => {
    beforeEach(() => {
      wrapper = createComponent({ active: true });
      button = wrapper.getComponent(GlButton);
    });

    it('renders delete button', () => {
      expect(button.props('icon')).toBe('remove');
      expect(button.attributes('aria-label')).toBe('Delete deployment');
      expect(wrapper.findByTestId('restore-deployment').exists()).toBe(false);
    });

    it('calls the delete mutation when clicked', async () => {
      button.vm.$emit('click');
      await nextTick();

      expect(deleteDeploymentHandler).toHaveBeenCalledWith({
        deploymentId: '123',
      });
    });
  });

  describe('when state is inactive', () => {
    beforeEach(() => {
      wrapper = createComponent({ active: false });
      button = wrapper.getComponent(GlButton);
    });

    it('renders restore button', () => {
      expect(button.props('icon')).toBe('redo');
      expect(button.attributes('aria-label')).toBe('Restore deployment');
      expect(wrapper.findByTestId('delete-deployment').exists()).toBe(false);
    });

    it('calls the restore mutation when clicked', async () => {
      button.vm.$emit('click');
      await nextTick();

      expect(restoreDeploymentHandler).toHaveBeenCalledWith({
        deploymentId: '123',
      });
    });
  });

  describe('when the mutations have an error', () => {
    const handlers = {
      deleteDeploymentHandler: jest.fn().mockRejectedValue(deleteDeploymentError),
      restoreDeploymentHandler: jest.fn().mockRejectedValue(restoreDeploymentError),
    };

    it.each`
      state         | message
      ${'active'}   | ${'There was an error trying to delete the deployment'}
      ${'inactive'} | ${'There was an error trying to restore the deployment'}
    `('renders the correct toast when state is $state', async ({ state, message }) => {
      wrapper = createComponent({ active: state === 'active' }, handlers);

      button = wrapper.getComponent(GlButton);
      button.vm.$emit('click');

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message,
        captureError: true,
        error: expect.any(Error),
      });
    });
  });
});
