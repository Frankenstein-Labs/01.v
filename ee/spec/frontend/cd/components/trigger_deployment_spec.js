import { GlModal, GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import TriggerDeployment from 'ee/cd/components/trigger_deployment.vue';
import cdRolloutCreateMutation from 'ee/cd/graphql/cd_rollout_create.mutation.graphql';

Vue.use(VueApollo);

describe('TriggerDeployment', () => {
  let wrapper;
  let hide;
  let mutationHandler;

  const organizationId = 'gid://gitlab/Organizations::Organization/1';
  const versionSetId = 'gid://gitlab/Cd::VersionSet/5';
  const releaseName = 'v2.5.0';

  const createSuccess = {
    data: {
      cdRolloutCreate: {
        rollout: { id: 'gid://gitlab/Cd::Rollout/1' },
        errors: [],
      },
    },
  };

  const findTriggerButton = () => wrapper.findByTestId('trigger-deployment-button');
  const findModal = () => wrapper.findComponent(GlModal);
  const findErrorAlert = () => wrapper.findByTestId('deployment-error-alert');
  const findDescription = () => wrapper.findByTestId('modal-body-text');

  const createComponent = ({ handler = mutationHandler } = {}) => {
    hide = jest.fn();
    wrapper = shallowMountExtended(TriggerDeployment, {
      apolloProvider: createMockApollo([[cdRolloutCreateMutation, handler]]),
      propsData: { organizationId, versionSetId, releaseName },
      stubs: {
        GlModal: stubComponent(GlModal, { methods: { hide } }),
        GlSprintf,
      },
    });
  };

  const triggerDeployment = async () => {
    const preventDefault = jest.fn();
    findModal().vm.$emit('primary', { preventDefault });
    await waitForPromises();
    return preventDefault;
  };

  beforeEach(() => {
    mutationHandler = jest.fn().mockResolvedValue(createSuccess);
  });

  it('renders the trigger button and modal', () => {
    createComponent();

    expect(findTriggerButton().exists()).toBe(true);
    expect(findModal().props('title')).toBe('Trigger deployment — v2.5.0');
  });

  it('renders the correct body', () => {
    createComponent();

    expect(findDescription().text()).toBe(
      'Trigger a manual deployment of v2.5.0. It will use the latest deployment flow.',
    );
  });

  it('prevents the default modal close so it stays open until the mutation resolves', async () => {
    createComponent();

    const preventDefault = await triggerDeployment();

    expect(preventDefault).toHaveBeenCalled();
  });

  it('shows the primary action as loading and disables cancel while in flight', async () => {
    let resolveMutation;
    mutationHandler = jest.fn().mockReturnValue(
      new Promise((resolve) => {
        resolveMutation = resolve;
      }),
    );
    createComponent();

    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await nextTick();

    expect(findModal().props('actionPrimary').attributes.loading).toBe(true);
    expect(findModal().props('actionCancel').attributes.disabled).toBe(true);

    resolveMutation(createSuccess);
    await waitForPromises();
  });

  describe('when the deployment is triggered successfully', () => {
    beforeEach(async () => {
      createComponent();
      await triggerDeployment();
    });

    it('runs the mutation with the organization and version set ids', () => {
      expect(mutationHandler).toHaveBeenCalledWith({
        input: { organizationId, versionSetId },
      });
    });

    it('hides the modal', () => {
      expect(hide).toHaveBeenCalledTimes(1);
    });

    it('emits deploy-triggered with the created rollout id', () => {
      expect(wrapper.emitted('deploy-triggered')).toEqual([['gid://gitlab/Cd::Rollout/1']]);
    });

    it('shows no error', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('when the mutation returns errors', () => {
    beforeEach(async () => {
      mutationHandler = jest.fn().mockResolvedValue({
        data: {
          cdRolloutCreate: {
            rollout: null,
            errors: ['A rollout requires at least one environment.'],
          },
        },
      });
      createComponent();
      await triggerDeployment();
    });

    it('shows the returned errors', () => {
      expect(findErrorAlert().text()).toContain('A rollout requires at least one environment.');
    });

    it('does not hide the modal or emit deploy-triggered', () => {
      expect(hide).not.toHaveBeenCalled();
      expect(wrapper.emitted('deploy-triggered')).toBeUndefined();
    });

    describe('when the modal is then hidden', () => {
      beforeEach(async () => {
        findModal().vm.$emit('hidden');
        await nextTick();
      });

      it('clears the errors', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });
    });
  });

  describe('when the mutation request fails', () => {
    beforeEach(async () => {
      mutationHandler = jest.fn().mockRejectedValue(new Error('boom'));
      createComponent();
      await triggerDeployment();
    });

    it('shows a generic error', () => {
      expect(findErrorAlert().text()).toContain('Failed to trigger the deployment');
    });

    it('does not hide the modal or emit deploy-triggered', () => {
      expect(hide).not.toHaveBeenCalled();
      expect(wrapper.emitted('deploy-triggered')).toBeUndefined();
    });
  });
});
