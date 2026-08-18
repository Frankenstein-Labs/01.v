import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import GroupRunnersApp from '~/ci/runner/group_runners/group_runners_app.vue';

import RunnerDashboardLink from 'ee/ci/runner/components/runner_dashboard_link.vue';

import { mockRegistrationToken, newRunnerPath } from 'jest/ci/runner/mock_data';

Vue.use(VueApollo);

describe('GroupRunnersApp', () => {
  let wrapper;

  const findRunnerDashboardLink = () => wrapper.findComponent(RunnerDashboardLink);

  const createComponent = ({ provide, stubs, ...options } = {}) => {
    wrapper = shallowMount(GroupRunnersApp, {
      apolloProvider: createMockApollo(),
      propsData: {
        registrationToken: mockRegistrationToken,
        groupFullPath: 'test-group',
        newRunnerPath,
      },
      provide: {
        localMutations: {},
        ...provide,
      },
      stubs: {
        RunnerFilteredSearchBar: true,
        ...stubs,
      },
      ...options,
    });

    return waitForPromises();
  };

  describe('dashboard link', () => {
    it('shows link', async () => {
      await createComponent({
        provide: { runnerDashboardPath: '/dashboard-path' },
        stubs: { RunnerDashboardLink },
      });

      expect(findRunnerDashboardLink().attributes('href')).toBe('/dashboard-path');
    });
  });
});
