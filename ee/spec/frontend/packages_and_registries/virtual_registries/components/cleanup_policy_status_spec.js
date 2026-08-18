import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getVirtualRegistriesCleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_virtual_registries_cleanup_policy_status.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import { mockVirtualRegistriesCleanupPolicy } from '../mock_data';

Vue.use(VueApollo);

describe('CleanupPolicyStatus', () => {
  let wrapper;
  let apolloProvider;
  let cleanupPolicyQueryHandler;

  const fullPath = 'testFullPath';

  const createComponent = ({
    adminVirtualRegistryAbility = true,
    mockData = mockVirtualRegistriesCleanupPolicy(),
  } = {}) => {
    cleanupPolicyQueryHandler = jest.fn().mockResolvedValue(mockData);
    const requestHandlers = [[getVirtualRegistriesCleanupPolicyStatus, cleanupPolicyQueryHandler]];

    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMountExtended(CleanupPolicyStatus, {
      apolloProvider,
      propsData: {
        batchKey: 'testBatchKey',
      },
      provide: {
        fullPath,
        glAbilities: {
          adminVirtualRegistry: adminVirtualRegistryAbility,
        },
      },
    });
  };

  const findCleanupPolicyStatus = () => wrapper.findByTestId('cleanup-policy-status');

  describe('when cleanup policy is enabled with next run date', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows enabled message with next run date', () => {
      expect(findCleanupPolicyStatus().text()).toContain(
        'Cache cleanup enabled. Next run scheduled for Jan 15',
      );
    });

    it('calls the query with correct variables', () => {
      expect(cleanupPolicyQueryHandler).toHaveBeenCalledWith({ fullPath });
    });
  });

  describe('when cleanup policy is enabled with next run date null', () => {
    beforeEach(async () => {
      createComponent({ mockData: mockVirtualRegistriesCleanupPolicy({ nextRunAt: null }) });
      await waitForPromises();
    });

    it('shows disabled message', () => {
      expect(findCleanupPolicyStatus().text()).toBe(
        'Cache cleanup disabled. Next run is not scheduled.',
      );
    });
  });

  describe('when cleanup policy is disabled', () => {
    beforeEach(async () => {
      createComponent({ mockData: mockVirtualRegistriesCleanupPolicy({ enabled: false }) });
      await waitForPromises();
    });

    it('shows disabled message', () => {
      expect(findCleanupPolicyStatus().text()).toBe(
        'Cache cleanup disabled. Next run is not scheduled.',
      );
    });
  });

  describe('adminVirtualRegistry ability', () => {
    describe('when user has adminVirtualRegistry permission', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('renders the cleanup policy status', () => {
        expect(findCleanupPolicyStatus().exists()).toBe(true);
      });

      it('calls the query', () => {
        expect(cleanupPolicyQueryHandler).toHaveBeenCalledWith({ fullPath });
      });
    });

    describe('when user does not have adminVirtualRegistry permission', () => {
      beforeEach(async () => {
        createComponent({ adminVirtualRegistryAbility: false });
        await waitForPromises();
      });

      it('does not render the cleanup policy status', () => {
        expect(findCleanupPolicyStatus().exists()).toBe(false);
      });

      it('does not call the query', () => {
        expect(cleanupPolicyQueryHandler).not.toHaveBeenCalled();
      });
    });
  });
});
