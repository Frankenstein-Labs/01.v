import { GlButton, GlCard, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretsEmptyState from 'ee/ci/secrets/components/secrets_empty_state.vue';
import {
  ENTITY_GROUP,
  ENTITY_PROJECT,
  NEW_ROUTE_NAME,
  SECRET_MANAGER_STATUS_ACTIVE,
} from 'ee/ci/secrets/constants';

describe('SecretsEmptyState component', () => {
  let wrapper;
  let mockRouterPush;

  const createComponent = ({
    props = {},
    context = ENTITY_PROJECT,
    isProvisioning = false,
    secretManagerStatus = SECRET_MANAGER_STATUS_ACTIVE,
  } = {}) => {
    wrapper = shallowMountExtended(SecretsEmptyState, {
      propsData: props,
      provide: {
        contextConfig: { type: context },
        isProvisioning,
        secretManagerStatus,
      },
      stubs: { GlCard },
      mocks: {
        $router: { push: mockRouterPush },
      },
    });
  };

  const findNewSecretButton = () => wrapper.findComponent(GlButton);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findGroupSubheader = () => wrapper.findByTestId('group-subheader');

  beforeEach(() => {
    mockRouterPush = jest.fn();
  });

  describe('when canCreateSecret is false', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the "New secret" button', () => {
      expect(findNewSecretButton().exists()).toBe(false);
    });
  });

  describe('subheader', () => {
    it('renders the subheader in group context', () => {
      createComponent({ context: ENTITY_GROUP });

      expect(findGroupSubheader().exists()).toBe(true);
      expect(findGroupSubheader().text()).toBe(
        'By default, all subgroups and projects can use stored secrets in their pipelines.',
      );
    });

    it('does not render the subheader in project context', () => {
      createComponent({ context: ENTITY_PROJECT });

      expect(findGroupSubheader().exists()).toBe(false);
    });
  });

  describe('when canCreateSecret is true', () => {
    describe('when secrets manager is already provisioned', () => {
      beforeEach(() => {
        createComponent({
          props: { canCreateSecret: true },
          secretManagerStatus: SECRET_MANAGER_STATUS_ACTIVE,
        });
      });

      it('renders the "New secret" button', () => {
        expect(findNewSecretButton().exists()).toBe(true);
      });

      it('redirects to the new secret route when clicked', () => {
        findNewSecretButton().vm.$emit('click');

        expect(mockRouterPush).toHaveBeenCalledWith({ name: NEW_ROUTE_NAME });
      });

      it('does not emit provision-secrets-manager', () => {
        findNewSecretButton().vm.$emit('click');

        expect(wrapper.emitted('provision-secrets-manager')).toBeUndefined();
      });

      it('does not show the popover', () => {
        expect(findPopover().props('show')).toBe(false);
      });
    });

    describe('when secrets manager needs provisioning', () => {
      beforeEach(() => {
        createComponent({
          props: { canCreateSecret: true },
          secretManagerStatus: null,
        });
      });

      it('emits provision-secrets-manager when clicked', () => {
        findNewSecretButton().vm.$emit('click');

        expect(wrapper.emitted('provision-secrets-manager')).toHaveLength(1);
      });

      it('does not redirect when clicked', () => {
        findNewSecretButton().vm.$emit('click');

        expect(mockRouterPush).not.toHaveBeenCalled();
      });
    });

    describe('when provisioning is in progress', () => {
      beforeEach(() => {
        createComponent({
          props: { canCreateSecret: true },
          isProvisioning: true,
        });
      });

      it('shows the loading state on the button', () => {
        expect(findNewSecretButton().props('loading')).toBe(true);
      });

      it('shows the popover', () => {
        expect(findPopover().props('show')).toBe(true);
      });
    });
  });
});
