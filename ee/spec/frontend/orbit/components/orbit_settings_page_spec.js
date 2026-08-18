import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import OrbitSettingsPage from 'ee/orbit/components/orbit_settings_page.vue';
import { fetchOrbitStatus } from 'ee/orbit/api/orbit_api';
import namespaceQuery from 'ee/orbit/graphql/queries/namespace.query.graphql';

Vue.use(VueApollo);

jest.mock('ee/orbit/api/orbit_api', () => ({
  fetchOrbitStatus: jest.fn(),
}));

describe('OrbitSettingsPage', () => {
  let wrapper;

  const namespace = {
    id: 'gid://gitlab/Group/1',
    fullPath: 'gitlab-org',
    name: 'gitlab-org',
    fullName: 'GitLab Org',
    avatarUrl: null,
    knowledgeGraphEnabled: true,
    knowledgeGraphAvailable: true,
  };

  const mockStatus = (status = 'healthy') => {
    fetchOrbitStatus.mockResolvedValue({
      data: {
        user: { available: true },
        system: { version: '1.0', status, components: [] },
      },
    });
  };

  const createComponent = async ({ status = 'healthy' } = {}) => {
    mockStatus(status);
    const namespaceHandler = jest.fn().mockResolvedValue({ data: { group: namespace } });
    const apolloProvider = createMockApollo([[namespaceQuery, namespaceHandler]]);

    wrapper = shallowMountExtended(OrbitSettingsPage, {
      apolloProvider,
      propsData: { groupFullPath: 'gitlab-org' },
    });

    await waitForPromises();
  };

  const findDisableButton = () => wrapper.findComponentByTestId('turn-off-indexing-btn');
  const findUnavailableRow = () => wrapper.findByTestId('orbit-unavailable-row');

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click_orbit_turn_off_indexing when the Turn off indexing button is clicked', async () => {
      await createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findDisableButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith('click_orbit_turn_off_indexing', {}, undefined);
    });
  });

  describe('cluster status', () => {
    it('does not show the unavailable row when migrating', async () => {
      await createComponent({ status: 'migrating' });

      expect(findUnavailableRow().exists()).toBe(false);
    });

    it('does not show the unavailable row when healthy', async () => {
      await createComponent({ status: 'healthy' });

      expect(findUnavailableRow().exists()).toBe(false);
    });

    it('shows the unavailable row when unhealthy', async () => {
      await createComponent({ status: 'unhealthy' });

      expect(findUnavailableRow().exists()).toBe(true);
    });
  });
});
