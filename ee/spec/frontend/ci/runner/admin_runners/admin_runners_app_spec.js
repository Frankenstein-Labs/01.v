import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createLocalState } from '~/ci/runner/graphql/list/local_state';
import AdminRunnersApp from '~/ci/runner/admin_runners/admin_runners_app.vue';
import RunnerList from '~/ci/runner/components/runner_list.vue';

import RunnerUpgradeStatusIcon from 'ee/ci/runner/components/runner_upgrade_status_icon.vue';
import RunnerDashboardLink from 'ee/ci/runner/components/runner_dashboard_link.vue';

import allRunnersQuery from 'ee_else_ce/ci/runner/graphql/list/all_runners.query.graphql';
import allRunnersCountQuery from '~/ci/runner/graphql/list/all_runners_count.query.graphql';
import runnerJobCountQuery from '~/ci/runner/graphql/list/runner_job_count.query.graphql';
import {
  runnerJobCountData,
  runnersCountData,
  mockRegistrationToken,
  newRunnerPath,
  runnerSettingsPath,
} from 'jest/ci/runner/mock_data';
import { allRunnersUpgradeStatusData } from '../mock_data';

const mockRunnersHandler = jest.fn();
const mockRunnersCountHandler = jest.fn();
const mockRunnerJobCountHandler = jest.fn();

Vue.use(VueApollo);

describe('AdminRunnersApp', () => {
  let wrapper;
  let cacheConfig;
  let localMutations;

  const defaultProps = {
    registrationToken: mockRegistrationToken,
    newRunnerPath,
    runnerSettingsPath,
    canAdminRunners: true,
  };

  const findRunnerDashboardLink = () => wrapper.findComponent(RunnerDashboardLink);
  const findRunnerRows = () => wrapper.findComponent(RunnerList).findAll('tr');

  const createComponent = ({ props = {}, provide, ...options } = {}) => {
    ({ cacheConfig, localMutations } = createLocalState());

    const handlers = [
      [allRunnersQuery, mockRunnersHandler],
      [allRunnersCountQuery, mockRunnersCountHandler],
      [runnerJobCountQuery, mockRunnerJobCountHandler],
    ];

    wrapper = mountExtended(AdminRunnersApp, {
      apolloProvider: createMockApollo(handlers, {}, cacheConfig),
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        localMutations,
        ...provide,
      },
      stubs: {
        RunnerFilteredSearchBar: true,
      },
      ...options,
    });

    return waitForPromises();
  };

  beforeEach(() => {
    mockRunnersHandler.mockResolvedValue(allRunnersUpgradeStatusData);
    mockRunnersCountHandler.mockResolvedValue(runnersCountData);
    mockRunnerJobCountHandler.mockResolvedValue(runnerJobCountData);
  });

  afterEach(() => {
    mockRunnersHandler.mockReset();
    mockRunnersCountHandler.mockReset();
    mockRunnerJobCountHandler.mockReset();
  });

  describe('dashboard link', () => {
    it('shows link', async () => {
      await createComponent({
        provide: { runnerDashboardPath: '/dashboard-path' },
      });

      expect(findRunnerDashboardLink().attributes('href')).toBe('/dashboard-path');
    });
  });

  describe('upgrade icons', () => {
    beforeEach(async () => {
      await createComponent({
        provide: { glLicensedFeatures: { runnerUpgradeManagement: true } },
      });
    });

    it.each`
      version     | description                                | colorClass            | index
      ${'15.1.1'} | ${'displays no upgrade icon (up to date)'} | ${null}               | ${1}
      ${'15.1.0'} | ${'displays upgrade recommended'}          | ${'gl-text-warning'}  | ${2}
      ${'15.0.0'} | ${'displays upgrade available'}            | ${'gl-text-blue-500'} | ${3}
    `('with $version $description', ({ version, index, colorClass }) => {
      const row = findRunnerRows().wrappers.map(extendedWrapper)[index];
      const upgradeIcon = row.findComponent(RunnerUpgradeStatusIcon).find('svg');

      if (colorClass) {
        expect(upgradeIcon.classes()).toContain(colorClass);
      } else {
        expect(upgradeIcon.exists()).toBe(false);
      }

      expect(row.text()).toContain(version);
    });
  });
});
