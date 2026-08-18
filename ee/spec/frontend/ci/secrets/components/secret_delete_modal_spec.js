import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormInput, GlModal, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  INDEX_ROUTE_NAME,
  DETAILS_ROUTE_NAME,
  ENTITY_GROUP,
  ENTITY_PROJECT,
} from 'ee/ci/secrets/constants';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
import { mockDeleteProjectSecretResponse, mockDeleteGroupSecretResponse } from '../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretDetailsWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockDeleteSecretMutationResponse;

  const mockRouter = {
    push: jest.fn(),
  };

  const defaultProps = {
    secretName: 'SECRET_KEY',
    showModal: true,
  };

  const createComponent = ({
    context = ENTITY_PROJECT,
    props = {},
    stubs = { GlSprintf },
    isRoot = true,
    routeName = INDEX_ROUTE_NAME,
  } = {}) => {
    const contextConfig = SECRETS_MANAGER_CONTEXT_CONFIG[context];
    mockApollo = createMockApollo([
      [contextConfig.deleteSecret.mutation, mockDeleteSecretMutationResponse],
    ]);

    wrapper = shallowMountExtended(SecretDeleteModal, {
      apolloProvider: mockApollo,
      provide: {
        contextConfig,
        fullPath: 'path/to/project',
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        RouterView: true,
        ...stubs,
      },
      mocks: {
        $router: mockRouter,
        $route: {
          name: routeName,
          meta: {
            isRoot,
          },
        },
      },
    });
  };

  const findInput = () => wrapper.findComponent(GlFormInput);
  const findModal = () => wrapper.findComponent(GlModal);
  const findModalDescription = () => wrapper.findByTestId('secret-delete-modal-description');
  const findModalConfirmText = () => wrapper.findByTestId('secret-delete-modal-confirm-text');
  const findDeleteButton = () => findModal().props('actionPrimary');

  const deleteSecret = async () => {
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();
  };

  beforeEach(() => {
    mockDeleteSecretMutationResponse = jest.fn();
  });

  describe('template', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders secret name in the modal text', () => {
      expect(findModalDescription().text()).toContain(
        'Are you sure you want to delete secret SECRET_KEY?',
      );
      expect(findModalConfirmText().text()).toBe('To confirm, enter SECRET_KEY:');
    });

    it('enables delete button when secret name is provided', async () => {
      expect(findDeleteButton().attributes.disabled).toBe(true);

      findInput().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findDeleteButton().attributes.disabled).toBe(false);
    });

    it('does not enable delete button when input does not match secret name', async () => {
      expect(findDeleteButton().attributes.disabled).toBe(true);

      findInput().vm.$emit('input', 'SECRET KEY');
      await nextTick();

      expect(findDeleteButton().attributes.disabled).toBe(true);
    });

    describe.each`
      modalEvent     | emittedEvent
      ${'canceled'}  | ${'hide'}
      ${'hidden'}    | ${'hide'}
      ${'secondary'} | ${'hide'}
    `('modal events', ({ modalEvent, emittedEvent }) => {
      it('emits the $emittedEvent event when $modalEvent event is triggered', () => {
        expect(wrapper.emitted(emittedEvent)).toBeUndefined();

        findModal().vm.$emit(modalEvent);

        expect(wrapper.emitted(emittedEvent)).toHaveLength(1);
      });

      it('resets text input', async () => {
        findInput().vm.$emit('input', 'SECRET_KEY');
        await nextTick();

        expect(findInput().props('value')).toBe('SECRET_KEY');

        findModal().vm.$emit(modalEvent);
        await nextTick();

        expect(findInput().props('value')).toBe('');
      });
    });
  });

  describe.each`
    context           | mockResponse
    ${ENTITY_PROJECT} | ${mockDeleteProjectSecretResponse}
    ${ENTITY_GROUP}   | ${mockDeleteGroupSecretResponse}
  `('deleting a secret in $context context', ({ context, mockResponse }) => {
    describe('when delete action succeeds', () => {
      beforeEach(async () => {
        mockDeleteSecretMutationResponse.mockResolvedValue(mockResponse());
        await createComponent({ context });
      });

      it('resets text input', async () => {
        findInput().vm.$emit('input', 'SECRET_KEY');
        await nextTick();

        expect(findInput().props('value')).toBe('SECRET_KEY');

        await deleteSecret();
        await nextTick();

        expect(findInput().props('value')).toBe('');
      });

      it('refetches secrets and stays on the overview page', async () => {
        await deleteSecret();

        expect(wrapper.emitted('refetch-secrets')).toHaveLength(1);
        expect(mockRouter.push).not.toHaveBeenCalledWith({ name: INDEX_ROUTE_NAME });
      });

      it('triggers toast message', async () => {
        await deleteSecret();

        expect(wrapper.emitted('show-secrets-toast')).toEqual([
          ['Secret SECRET_KEY has been deleted.'],
        ]);
      });
    });

    describe('when delete action succeeds from details page', () => {
      beforeEach(async () => {
        mockDeleteSecretMutationResponse.mockResolvedValue(mockResponse());
        await createComponent({ context, isRoot: false, routeName: DETAILS_ROUTE_NAME });
        await deleteSecret();
      });

      it('redirects to index page', () => {
        expect(wrapper.emitted('refetch-secrets')).toBeUndefined();
        expect(mockRouter.push).toHaveBeenCalledWith({ name: INDEX_ROUTE_NAME });
      });
    });

    describe('when delete action fails', () => {
      beforeEach(async () => {
        mockDeleteSecretMutationResponse.mockResolvedValue(
          mockResponse({ error: 'This is an API error.' }),
        );
        await createComponent({ context });
        await deleteSecret();
      });

      it('shows error in alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'This is an API error.',
          captureError: true,
          error: new Error('This is an API error.'),
        });
      });

      it('hides modal', () => {
        expect(wrapper.emitted('hide')).toHaveLength(1);
      });

      it('does not redirect to the index page', () => {
        expect(mockRouter.push).toHaveBeenCalledTimes(0);
      });
    });

    describe('when delete action receives an error', () => {
      const error = new Error('GraphQL error: API error');

      beforeEach(async () => {
        mockDeleteSecretMutationResponse.mockRejectedValue(error);
        await createComponent({ context });
        await deleteSecret();
      });

      it('renders an error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error: new Error('API error'),
        });
      });
    });
  });
});
