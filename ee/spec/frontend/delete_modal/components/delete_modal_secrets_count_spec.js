import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getProjectSecretsCountQuery from 'ee/delete_modal/graphql/get_project_secrets_count.query.graphql';
import getGroupSecretsCountQuery from 'ee/delete_modal/graphql/get_group_secrets_count.query.graphql';
import DeleteModalSecretsCount from 'ee/delete_modal/components/delete_modal_secrets_count.vue';

jest.mock('~/sentry/sentry_browser_wrapper');
Vue.use(VueApollo);

describe('DeleteModalSecretsCount component', () => {
  let wrapper;
  let mockApollo;
  const mockProjectSecretsCountQuery = jest.fn();
  const mockGroupSecretsCountQuery = jest.fn();

  const createComponent = async ({ props = {}, isLoading = false } = {}) => {
    mockApollo = createMockApollo([
      [getProjectSecretsCountQuery, mockProjectSecretsCountQuery],
      [getGroupSecretsCountQuery, mockGroupSecretsCountQuery],
    ]);

    wrapper = shallowMountExtended(DeleteModalSecretsCount, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath: 'root/foobar',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  const findCount = () => wrapper.findComponent(GlSprintf);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const createComponentWithQueryResult = async (resourceType, query, count) => {
    query.mockResolvedValue({ data: { secretsCount: count } });
    createComponent({ props: { resourceType } });
    await waitForPromises();
  };

  describe.each`
    resourceType | resourceQuery
    ${'project'} | ${mockProjectSecretsCountQuery}
    ${'group'}   | ${mockGroupSecretsCountQuery}
  `('when resourceType is $resourceType', ({ resourceType, resourceQuery }) => {
    beforeEach(() => {
      mockProjectSecretsCountQuery.mockClear();
      mockGroupSecretsCountQuery.mockClear();
    });

    describe('when query is loading', () => {
      it('shows skeleton loader', () => {
        createComponentWithQueryResult(resourceType, resourceQuery, 5);

        expect(findLoader().exists()).toBe(true);
        expect(findCount().exists()).toBe(false);
      });
    });

    describe('when query is fetched successfully', () => {
      it('does not show skeletal loader', async () => {
        await createComponentWithQueryResult(resourceType, resourceQuery, 5);

        expect(findLoader().exists()).toBe(false);
      });

      it('calls the correct query', async () => {
        expect(resourceQuery).toHaveBeenCalledTimes(0);

        await createComponentWithQueryResult(resourceType, resourceQuery, 5);

        expect(resourceQuery).toHaveBeenCalledTimes(1);
      });

      it('shows singular secret count', async () => {
        await createComponentWithQueryResult(resourceType, resourceQuery, 1);

        expect(wrapper.text()).toContain('1 secret');
      });

      it('shows plural secrets count', async () => {
        await createComponentWithQueryResult(resourceType, resourceQuery, 5);

        expect(wrapper.text()).toContain('5 secrets');
      });

      it('renders nothing if count is null', async () => {
        await createComponentWithQueryResult(resourceType, resourceQuery, null);

        expect(findCount().exists()).toBe(false);
      });
    });

    describe('when query fails', () => {
      beforeEach(() => {
        resourceQuery.mockRejectedValue(new Error('API Error'));
        createComponent({ props: { resourceType } });
      });

      it('does not render count or skeletal loader', async () => {
        await waitForPromises();

        expect(findLoader().exists()).toBe(false);
        expect(findCount().exists()).toBe(false);
      });

      it('emits fetch-error event', async () => {
        expect(wrapper.emitted('fetch-error')).toBeUndefined();

        await waitForPromises();

        expect(wrapper.emitted('fetch-error')).toHaveLength(1);
      });

      it('captures exception in Sentry', async () => {
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });
    });
  });
});
