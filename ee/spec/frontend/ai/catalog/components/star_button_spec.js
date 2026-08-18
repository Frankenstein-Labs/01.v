import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import StarButton from 'ee/ai/catalog/components/star_button.vue';
import aiCatalogItemStarMutation from 'ee/ai/catalog/graphql/mutations/ai_catalog_item_star.mutation.graphql';
import {
  mockAiCatalogItemStarSuccessMutation,
  mockAiCatalogItemStarErrorMutation,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('StarButton', () => {
  let wrapper;
  let mockApollo;
  let mockStarMutationHandler;

  const defaultItem = {
    id: 'gid://gitlab/Ai::Catalog::Item/1',
    starCount: 3,
    starred: false,
  };

  const createComponent = ({ item = defaultItem, starHandler = null, disabled = false } = {}) => {
    mockStarMutationHandler =
      starHandler || jest.fn().mockResolvedValue(mockAiCatalogItemStarSuccessMutation);

    mockApollo = createMockApollo([[aiCatalogItemStarMutation, mockStarMutationHandler]]);

    wrapper = shallowMountExtended(StarButton, {
      apolloProvider: mockApollo,
      propsData: { item, disabled },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  const findStarButton = () => wrapper.findComponent(GlButton);
  const findStarButtonWrapper = () => wrapper.findByTestId('star-button-wrapper');

  afterEach(() => {
    mockApollo = null;
  });

  describe('icon rendering', () => {
    it('renders the unstarred icon (star-o) when item.starred is false', () => {
      createComponent({ item: { ...defaultItem, starred: false } });

      expect(findStarButton().props('icon')).toBe('star-o');
    });

    it('renders the starred icon (star) when item.starred is true', () => {
      createComponent({ item: { ...defaultItem, starred: true } });

      expect(findStarButton().props('icon')).toBe('star');
    });
  });

  describe('star count', () => {
    it('passes star count to the button count prop', () => {
      createComponent({ item: { ...defaultItem, starCount: 7 } });

      expect(findStarButton().props('count')).toBe(7);
    });
  });

  describe('when user is logged in and clicks star button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls mutation with correct variables', async () => {
      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(mockStarMutationHandler).toHaveBeenCalledWith({
        input: { id: defaultItem.id, starred: true },
      });
    });

    it('updates local star count to mutation response starCount after success', async () => {
      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(findStarButton().props('count')).toBe(5);
    });

    it('toggles isStarred after success', async () => {
      createComponent({ item: { ...defaultItem, starred: false } });

      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(findStarButton().props('icon')).toBe('star');
    });

    it('sets isLoading true during mutation and false after', async () => {
      let resolvePromise;
      const pendingHandler = jest.fn(
        () =>
          new Promise((resolve) => {
            resolvePromise = resolve;
          }),
      );
      createComponent({ starHandler: pendingHandler });

      findStarButton().vm.$emit('click');
      await nextTick();

      expect(findStarButton().props('loading')).toBe(true);
      expect(findStarButton().props('disabled')).toBe(true);

      resolvePromise(mockAiCatalogItemStarSuccessMutation);
      await waitForPromises();

      expect(findStarButton().props('loading')).toBe(false);
      expect(findStarButton().props('disabled')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows error toast and calls Sentry.captureException when mutation returns errors array', async () => {
      createComponent({
        starHandler: jest.fn().mockResolvedValue(mockAiCatalogItemStarErrorMutation),
      });

      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Star toggle failed. Try again later.',
        expect.objectContaining({ variant: 'danger' }),
      );
    });

    it('shows error toast and calls Sentry.captureException on network error', async () => {
      const networkError = new Error('Network error');
      createComponent({
        starHandler: jest.fn().mockRejectedValue(networkError),
      });

      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(networkError);
      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Star toggle failed. Try again later.',
        expect.objectContaining({ variant: 'danger' }),
      );
    });
  });

  describe('when disabled prop is true (user not logged in)', () => {
    beforeEach(() => {
      createComponent({ item: defaultItem, disabled: true });
    });

    it('does not call mutation when clicking star button', async () => {
      await findStarButton().vm.$emit('click');
      await waitForPromises();

      expect(mockStarMutationHandler).not.toHaveBeenCalled();
    });

    it('renders the star button as disabled', () => {
      expect(findStarButton().props('disabled')).toBe(true);
    });

    it('shows tooltip on the wrapper indicating sign-in is required', () => {
      expect(findStarButtonWrapper().attributes('title')).toBe(
        'You must sign in to star this item',
      );
    });
  });

  describe('button component', () => {
    it('renders a GlButton with the star-button test id', () => {
      createComponent();

      expect(wrapper.findComponent(GlButton).exists()).toBe(true);
      expect(findStarButton().exists()).toBe(true);
    });
  });
});
