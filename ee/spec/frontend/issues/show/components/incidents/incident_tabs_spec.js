import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { merge } from 'lodash-es';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import IncidentTabs from '~/issues/show/components/incidents/incident_tabs.vue';
import INVALID_URL from '~/lib/utils/invalid_url';
import { descriptionProps } from 'jest/issues/show/mock_data/mock_data';

Vue.use(PiniaVuePlugin);

const mockAlert = {
  __typename: 'AlertManagementAlert',
  detailsUrl: INVALID_URL,
  iid: '1',
};

const defaultMocks = {
  $route: { params: { id: '' } },
  $apollo: {
    queries: {
      alert: {
        loading: true,
      },
    },
  },
};

beforeEach(() => {
  gon.features = { hideIncidentManagementFeatures: false };
});

afterEach(() => {
  window.gon.features = {};
});

describe('Incident Tabs component', () => {
  let wrapper;

  const mountComponent = ({ uploadMetricsFeatureAvailable }) => {
    wrapper = shallowMount(
      IncidentTabs,
      merge({
        pinia: createTestingPinia(),
        propsData: {
          ...descriptionProps,
        },
        stubs: {
          DescriptionComponent: true,
          MetricsTab: true,
        },
        provide: {
          fullPath: '',
          iid: '',
          projectId: '',
          issuableId: '',
          uploadMetricsFeatureAvailable,
          hasLinkedAlerts: false,
        },
        data() {
          return { alert: mockAlert };
        },
        mocks: defaultMocks,
      }),
    );
  };

  const findMetricsTab = () => wrapper.find('[data-testid="metrics-tab"]');

  describe('upload metrics feature available', () => {
    it('shows the metric tab when metrics are available', () => {
      mountComponent({ uploadMetricsFeatureAvailable: true });

      expect(findMetricsTab().exists()).toBe(true);
    });

    it('hides the tab when metrics are not available', () => {
      mountComponent({ uploadMetricsFeatureAvailable: false });

      expect(findMetricsTab().exists()).toBe(false);
    });
  });
});
