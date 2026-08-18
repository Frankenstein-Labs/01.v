import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import canReadProjectRunnerCloudProvisioningInfo from 'ee/ci/runner/graphql/register/can_read_project_runner_cloud_provisioning_info.query.graphql';
import canReadGroupRunnerCloudProvisioningInfo from 'ee/ci/runner/graphql/register/can_read_group_runner_cloud_provisioning_info.query.graphql';

import RunnerGoogleCloudOption from 'ee_component/ci/runner/components/runner_google_cloud_options.vue';
import RunnerPlatformsRadio from '~/ci/runner/components/runner_platforms_radio.vue';

Vue.use(VueApollo);

describe('RunnerGoogleCloudOptions', () => {
  let wrapper;
  let handlers;

  const setCurrentPermission = (type, readRunnerCloudProvisioningInfo) => {
    handlers[type].mockResolvedValue({
      data: {
        [type]: {
          id: `${type}/1`,
          userPermissions: { readRunnerCloudProvisioningInfo },
        },
      },
    });
  };

  const findFormRadio = () => wrapper.findComponent(RunnerPlatformsRadio);
  const findLabel = () => wrapper.find('label');

  const createComponent = ({ props = {}, ...options } = {}) => {
    wrapper = shallowMountExtended(RunnerGoogleCloudOption, {
      apolloProvider: createMockApollo([
        [canReadProjectRunnerCloudProvisioningInfo, handlers.project],
        [canReadGroupRunnerCloudProvisioningInfo, handlers.group],
      ]),
      propsData: {
        ...props,
      },
      ...options,
    });
  };

  beforeEach(() => {
    handlers = {
      group: jest.fn(),
      project: jest.fn(),
    };
  });

  describe.each`
    entityType   | path                     | props
    ${'project'} | ${'my-group/my-project'} | ${{ projectPath: 'my-group/my-project' }}
    ${'group'}   | ${'my-group'}            | ${{ groupPath: 'my-group' }}
  `('shows options for $entityType', ({ entityType, path, props }) => {
    describe('when readRunnerCloudProvisioningInfo is allowed', () => {
      beforeEach(async () => {
        setCurrentPermission(entityType, true);

        createComponent({ props });
        await waitForPromises();
      });

      it('shows', () => {
        expect(handlers[entityType]).toHaveBeenCalledWith({ fullPath: path });
      });

      it('displays form radio', () => {
        expect(findFormRadio().exists()).toBe(true);
      });

      it('displays form radio label', () => {
        expect(findLabel().text()).toBe('Cloud');
      });

      it('emits input event', () => {
        findFormRadio().vm.$emit('input', 'google_cloud');

        expect(wrapper.emitted()).toEqual({ input: [['google_cloud']] });
      });

      it('sets radio value when checked prop is passed', async () => {
        createComponent({ props: { ...props, checked: 'google_cloud' } });
        await waitForPromises();

        expect(findFormRadio().attributes('value')).toBe('google_cloud');
      });
    });

    describe('when readRunnerCloudProvisioningInfo is not allowed', () => {
      beforeEach(async () => {
        setCurrentPermission(entityType, false);

        createComponent({ props });
        await waitForPromises();
      });

      it('does not show option', () => {
        expect(findFormRadio().exists()).toBe(false);
      });
    });
  });

  it('does not show options if project or group path is missing', async () => {
    createComponent();
    await waitForPromises();

    expect(findLabel().exists()).toBe(false);
    expect(findFormRadio().exists()).toBe(false);
  });
});
