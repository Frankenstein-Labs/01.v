import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlFormCheckbox } from '@gitlab/ui';
import { TEST_HOST } from 'helpers/test_constants';
import NewDeployToken from 'ee/deploy_tokens/components/new_deploy_token.vue';
import CeNewDeployToken from '~/deploy_tokens/components/new_deploy_token.vue';

const createNewTokenPath = `${TEST_HOST}/create`;
const deployTokensHelpUrl = `${TEST_HOST}/help`;

jest.mock('~/alert');

describe('New Deploy Token', () => {
  let wrapper;

  const createComponent = (options = {}) => {
    const defaults = {
      containerRegistryEnabled: true,
      packagesRegistryEnabled: true,
      dependencyProxyEnabled: true,
      tokenType: 'project',
      topLevelGroup: false,
    };

    return shallowMount(NewDeployToken, {
      propsData: {
        deployTokensHelpUrl,
        createNewTokenPath,
        ...defaults,
        ...options,
      },
      stubs: {
        GlAlert,
        GlFormCheckbox,
      },
    });
  };
  const findCeComponent = () => wrapper.findComponent(CeNewDeployToken);

  describe('without a top level group', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });
    it('should pass the correct readVirtualRegistryText to the ce component', () => {
      expect(findCeComponent().props('readVirtualRegistryHelpText')).toBe(
        'Allows read-only access to container images through the dependency proxy.',
      );
    });
  });

  describe('with a top level group', () => {
    beforeEach(() => {
      wrapper = createComponent({ topLevelGroup: true });
    });

    it('should pass the correct readVirtualRegistryText to the ce component', () => {
      expect(findCeComponent().props('readVirtualRegistryHelpText')).toBe(
        'Allows read-only access to container images through the dependency proxy and read-only access to virtual registries.',
      );
    });
  });
});
