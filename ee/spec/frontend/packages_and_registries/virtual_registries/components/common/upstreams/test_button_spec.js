import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import TestUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/test_button.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  testMavenUpstream,
  testExistingMavenUpstreamWithOverrides,
} from 'ee/api/virtual_registries_api';
import waitForPromises from 'helpers/wait_for_promises';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import testUpstreamMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/test_container_upstream.mutation.graphql';

jest.mock('ee/api/virtual_registries_api');
jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('TestUpstreamButton', () => {
  let wrapper;

  const defaultProps = {
    url: 'https://gitlab.com',
  };

  const findTestUpstreamButton = () => wrapper.findComponent(GlButton);

  const showToastSpy = jest.fn();

  const createComponent = ({ props = {}, provide = {}, handlers = [] } = {}) => {
    wrapper = shallowMountExtended(TestUpstreamButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
      apolloProvider: createMockApollo(handlers),
      mocks: {
        $toast: {
          show: showToastSpy,
        },
      },
    });
  };

  const testSuccessResponse = { data: { success: true } };
  const testErrorResponse = { response: { status: 400, data: { message: { url: 'is blocked' } } } };
  const testFailureResponse = { data: { success: false, result: 'message' } };
  const upstreamId = 'gid://gitlab/VirtualRegistryUpstream/1';

  describe('default', () => {
    beforeEach(() => {
      testMavenUpstream.mockResolvedValue(testSuccessResponse);
      createComponent({
        provide: {
          fullPath: 'full-path',
        },
      });
    });

    it('renders GlButton', () => {
      expect(findTestUpstreamButton().props('disabled')).toBe(false);
      expect(findTestUpstreamButton().props('loading')).toBe(false);
      expect(findTestUpstreamButton().text()).toBe('Test upstream');
    });

    it('on click calls testMavenUpstream API', async () => {
      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testMavenUpstream).toHaveBeenCalledWith({
        id: 'full-path',
        url: defaultProps.url,
        username: '',
        password: '',
      });

      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    describe('when testMavenUpstream fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        testMavenUpstream.mockRejectedValue(mockError);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect.');
        expect(captureException).toHaveBeenCalledWith({
          error: mockError,
          name: 'TestUpstreamButton',
        });
      });

      it('shows toast with message from API and does not report error to Sentry', async () => {
        testMavenUpstream.mockResolvedValue(testFailureResponse);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect message');
        expect(captureException).not.toHaveBeenCalled();
      });

      it('shows toast with error message from API & does not report error to Sentry', async () => {
        testMavenUpstream.mockRejectedValue(testErrorResponse);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect url is blocked');
        expect(captureException).not.toHaveBeenCalled();
      });
    });
  });

  describe('when upstreamId is provided', () => {
    beforeEach(() => {
      testExistingMavenUpstreamWithOverrides.mockResolvedValue(testSuccessResponse);
      createComponent({
        props: { upstreamId },
      });
    });

    it('on click calls testExistingMavenUpstreamWithOverrides API with overrides', async () => {
      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: getIdFromGraphQLId(upstreamId),
        url: defaultProps.url,
        username: '',
        password: '',
      });
      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    it('passes username and password overrides when provided', async () => {
      createComponent({
        props: {
          upstreamId,
          url: defaultProps.url,
          username: 'test-user',
          password: 'test-password',
        },
      });

      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: getIdFromGraphQLId(upstreamId),
        url: defaultProps.url,
        username: 'test-user',
        password: 'test-password',
      });
    });

    it('calls API with only upstreamId when no overrides are provided (link existing upstream modal)', async () => {
      createComponent({
        props: {
          upstreamId,
          url: '',
          username: '',
          password: '',
        },
      });

      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: getIdFromGraphQLId(upstreamId),
        url: '',
        username: '',
        password: '',
      });
      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    describe('when testExistingMavenUpstreamWithOverrides fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        testExistingMavenUpstreamWithOverrides.mockRejectedValue(mockError);
        createComponent({
          props: { upstreamId },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect.');
        expect(captureException).toHaveBeenCalledWith({
          error: mockError,
          name: 'TestUpstreamButton',
        });
      });

      it('shows toast with message from API and does not report error to Sentry', async () => {
        testExistingMavenUpstreamWithOverrides.mockResolvedValue(testFailureResponse);
        createComponent({
          props: { upstreamId },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect message');
        expect(captureException).not.toHaveBeenCalled();
      });

      it('shows toast with error message from API and does not report error to Sentry', async () => {
        testExistingMavenUpstreamWithOverrides.mockRejectedValue(testErrorResponse);
        createComponent({
          props: { upstreamId },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect url is blocked');
        expect(captureException).not.toHaveBeenCalled();
      });
    });
  });

  describe('when testUpstreamMutation is provided', () => {
    const defaultMutationHandler = jest
      .fn()
      .mockResolvedValue({ data: { test: { success: true, errors: [] } } });

    const createGraphqlComponent = ({ props = {}, handler = defaultMutationHandler } = {}) => {
      createComponent({
        props,
        provide: {
          fullPath: 'gitlab-org',
          testUpstreamMutation,
        },
        handlers: [[testUpstreamMutation, handler]],
      });
    };

    it('calls the GraphQL mutation with correct variables', async () => {
      createGraphqlComponent({
        props: {
          upstreamId,
          url: 'https://registry.example.com',
          username: 'user',
          password: 'pass',
        },
      });

      findTestUpstreamButton().vm.$emit('click');
      await waitForPromises();

      expect(defaultMutationHandler).toHaveBeenCalledWith({
        input: {
          id: upstreamId,
          url: 'https://registry.example.com',
          username: 'user',
          password: 'pass',
          groupPath: 'gitlab-org',
        },
      });
    });

    it('shows success toast on successful test', async () => {
      createGraphqlComponent();

      findTestUpstreamButton().vm.$emit('click');
      await waitForPromises();

      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    it('does not call REST APIs', async () => {
      createGraphqlComponent();

      findTestUpstreamButton().vm.$emit('click');
      await waitForPromises();

      expect(testMavenUpstream).not.toHaveBeenCalled();
      expect(testExistingMavenUpstreamWithOverrides).not.toHaveBeenCalled();
    });

    describe('when the GraphQL mutation fails', () => {
      it('shows toast with error from mutation response', async () => {
        const handler = jest.fn().mockResolvedValue({
          data: { test: { success: false, errors: ['upstream is unreachable'] } },
        });
        createGraphqlComponent({ handler });

        findTestUpstreamButton().vm.$emit('click');
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect upstream is unreachable');
        expect(captureException).not.toHaveBeenCalled();
      });

      it('shows default toast and reports to Sentry on network error', async () => {
        const mockError = new Error('network error');
        const handler = jest.fn().mockRejectedValue(mockError);
        createGraphqlComponent({ handler });

        findTestUpstreamButton().vm.$emit('click');
        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect.');
        expect(captureException).toHaveBeenCalledWith({
          error: mockError,
          name: 'TestUpstreamButton',
        });
      });
    });
  });
});
