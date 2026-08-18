import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAvatar, GlButton, GlLink, GlDaterangePicker } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { INSTANCE_TYPE, GROUP_TYPE } from '~/ci/runner/constants';

import RunnerUsageQuery from 'ee/ci/runner/graphql/performance/runner_usage.query.graphql';
import RunnerUsageByProjectQuery from 'ee/ci/runner/graphql/performance/runner_usage_by_project.query.graphql';
import RunnerUsageExportMutation from 'ee/ci/runner/graphql/performance/runner_usage_export.mutation.graphql';

import RunnerUsage from 'ee/ci/runner/components/runner_usage.vue';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('~/sentry/sentry_browser_wrapper');

const mockRunnerUsage = [
  {
    runner: {
      id: 'gid://gitlab/Ci::Runner/1',
      shortSha: 'sha1',
      description: 'Runner 1',
      adminUrl: '/admin/runners/1',
      __typename: 'CiRunner',
    },
    ciDuration: '111222333444555666777888999', // tests support for BigInt parsing
    __typename: 'CiRunnerUsage',
  },
  {
    runner: {
      id: 'gid://gitlab/Ci::Runner/2',
      shortSha: 'sha2',
      description: 'Runner 2',
      adminUrl: '/admin/runners/2',
      __typename: 'CiRunner',
    },
    ciDuration: 2001,
    __typename: 'CiRunnerUsage',
  },
  {
    runner: {
      id: 'gid://gitlab/Ci::Runner/3',
      shortSha: 'sha3',
      description: 'Runner 3',
      adminUrl: null,
      __typename: 'CiRunner',
    },
    ciDuration: 2002,
    __typename: 'CiRunnerUsage',
  },
  {
    runner: null,
    ciDuration: 2003,
    __typename: 'CiRunnerUsage',
  },
];

const mockRunnerUsageByProject = [
  {
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Project1',
      nameWithNamespace: 'Group1 / Project1',
      avatarUrl: '/project1.png',
      webUrl: '/group1/project1',
      __typename: 'Project',
    },
    ciDuration: 1002,
    __typename: 'CiRunnerUsageByProject',
  },
  {
    project: {
      id: 'gid://gitlab/Project/22',
      name: 'Project2',
      nameWithNamespace: 'Group1 / Project2',
      avatarUrl: '/project2.png',
      webUrl: '/group1/project2',
      __typename: 'Project',
    },
    ciDuration: 1001,
    __typename: 'CiRunnerUsageByProject',
  },
  {
    project: null,
    ciDuration: 1000,
    __typename: 'CiRunnerUsageByProject',
  },
];

describe('RunnerUsage', () => {
  let wrapper;
  let mockToast;

  let runnerUsageHandler;
  let runnerUsageByProjectHandler;
  let runnerUsageExportHandler;

  const findDaterangePicker = () => wrapper.findComponent(GlDaterangePicker);
  const findButton = () => wrapper.findComponent(GlButton);
  const findTopRunnersTable = () => wrapper.findComponentByTestId('top-runners-table');
  const findTopProjectsTable = () => wrapper.findComponentByTestId('top-projects-table');
  const findTopRunners = () => findTopRunnersTable().findAll('tr');
  const findTopProjects = () => findTopProjectsTable().findAll('tr');

  const clickButton = async () => {
    findButton().vm.$emit('click');
    await waitForPromises();
  };

  const createWrapper = ({ mountFn = shallowMountExtended, props } = {}) => {
    confirmAction.mockResolvedValue(true);

    mockToast = jest.fn();

    wrapper = mountFn(RunnerUsage, {
      propsData: {
        scope: INSTANCE_TYPE,
        ...props,
      },
      apolloProvider: createMockApollo([
        [RunnerUsageByProjectQuery, runnerUsageByProjectHandler],
        [RunnerUsageQuery, runnerUsageHandler],
        [RunnerUsageExportMutation, runnerUsageExportHandler],
      ]),
      mocks: {
        $toast: { show: mockToast },
      },
    });
  };

  beforeEach(() => {
    runnerUsageByProjectHandler = jest.fn().mockResolvedValue({
      data: { runnerUsageByProject: mockRunnerUsageByProject },
    });
    runnerUsageHandler = jest.fn().mockResolvedValue({
      data: { runnerUsage: mockRunnerUsage },
    });
    runnerUsageExportHandler = jest.fn();
  });

  it('shows daterange picker', () => {
    createWrapper();

    expect(findDaterangePicker().props()).toMatchObject({
      defaultEndDate: new Date('2020-06-30T00:00:00.000Z'),
      defaultMaxDate: new Date('2020-07-06T00:00:00.000Z'),
      defaultStartDate: new Date('2020-06-01T00:00:00.000Z'),
      maxDateRange: 365,
      tooltip: 'Date range limited to 365 days',
    });
  });

  describe('when showing data for instance runners', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });
      await waitForPromises();
    });

    it('shows table fields', () => {
      expect(findTopProjectsTable().props('fields')).toMatchObject([
        { key: 'project', label: 'Top projects consuming runners' },
        { key: 'ciDuration', label: 'Usage (min)' },
      ]);

      expect(findTopRunnersTable().props('fields')).toMatchObject([
        { key: 'runner', label: 'Most used instance runners' },
        { key: 'ciDuration', label: 'Usage (min)' },
      ]);
    });

    it('fetches data', () => {
      const expectedVariables = {
        fromDate: '2020-06-01T00:00:00.000Z',
        toDate: '2020-06-30T00:00:00.000Z',
        runnerType: INSTANCE_TYPE,
      };

      expect(runnerUsageByProjectHandler).toHaveBeenCalledTimes(1);
      expect(runnerUsageByProjectHandler).toHaveBeenCalledWith(expectedVariables);

      expect(runnerUsageHandler).toHaveBeenCalledTimes(1);
      expect(runnerUsageHandler).toHaveBeenCalledWith(expectedVariables);
    });

    it('fetches data on new date range input', async () => {
      const updatedFromDate = '2020-06-15T00:00:00.000Z';
      const updatedToDate = '2020-06-20T00:00:00.000Z';

      findDaterangePicker().vm.$emit('input', {
        startDate: new Date(updatedFromDate),
        endDate: new Date(updatedToDate),
      });

      await nextTick();

      expect(runnerUsageByProjectHandler).toHaveBeenCalledTimes(2);
      expect(runnerUsageByProjectHandler).toHaveBeenLastCalledWith({
        fromDate: updatedFromDate,
        toDate: updatedToDate,
        runnerType: INSTANCE_TYPE,
      });

      expect(runnerUsageHandler).toHaveBeenCalledTimes(2);
      expect(runnerUsageHandler).toHaveBeenLastCalledWith({
        fromDate: updatedFromDate,
        toDate: updatedToDate,
        runnerType: INSTANCE_TYPE,
      });
    });

    it('shows top projects', () => {
      expect(findTopProjects()).toHaveLength(4);

      const [, row1, row2, row3] = findTopProjects().wrappers;

      expect(row1.findComponent(GlAvatar).props('src')).toBe('/project1.png');
      expect(row1.findComponent(GlAvatar).attributes('label')).toBe('Project1');
      expect(row1.text()).toContain('Project1');
      expect(row1.text()).toContain('1,002');

      expect(row2.findComponent(GlAvatar).props('src')).toBe('/project2.png');
      expect(row2.findComponent(GlAvatar).attributes('label')).toBe('Project2');
      expect(row2.text()).toContain('Project2');
      expect(row2.text()).toContain('1,001');

      expect(row3.text()).toContain('Other projects');
      expect(row3.text()).toContain('1,000');
    });

    it('shows top runners', () => {
      expect(findTopRunners()).toHaveLength(5);

      const [, row1, row2, row3, row4] = findTopRunners().wrappers;

      expect(row1.findComponent(GlLink).attributes('href')).toBe('/admin/runners/1');
      expect(row1.findComponent(GlLink).text()).toBe('#1 (sha1) - Runner 1');
      expect(row1.text()).toContain('111,222,333,444,555,666,777,888,999');

      expect(row2.findComponent(GlLink).attributes('href')).toBe('/admin/runners/2');
      expect(row2.findComponent(GlLink).text()).toBe('#2 (sha2) - Runner 2');
      expect(row2.text()).toContain('2,001');

      expect(row3.findComponent(GlLink).exists()).toBe(false);
      expect(row3.text()).toContain('#3 (sha3) - Runner 3');
      expect(row3.text()).toContain('2,002');

      expect(row4.findComponent(GlLink).exists()).toBe(false);
      expect(row4.text()).toContain('Other runners');
      expect(row4.text()).toContain('2,003');
    });
  });

  describe('when showing data for group runners', () => {
    beforeEach(async () => {
      createWrapper({
        props: {
          scope: GROUP_TYPE,
          groupFullPath: 'my-group',
        },
      });
      await waitForPromises();
    });

    it('shows table fields', () => {
      expect(findTopProjectsTable().props('fields')).toMatchObject([
        { key: 'project', label: 'Top projects consuming group runners' },
        { key: 'ciDuration', label: 'Usage (min)' },
      ]);

      expect(findTopRunnersTable().props('fields')).toMatchObject([
        { key: 'runner', label: 'Most used group runners' },
        { key: 'ciDuration', label: 'Usage (min)' },
      ]);
    });

    it('fetches data', () => {
      const expectedVariables = {
        fromDate: '2020-06-01T00:00:00.000Z',
        toDate: '2020-06-30T00:00:00.000Z',
        runnerType: GROUP_TYPE,
        fullPath: 'my-group',
      };

      expect(runnerUsageHandler).toHaveBeenCalledTimes(1);
      expect(runnerUsageHandler).toHaveBeenCalledWith(expectedVariables);

      expect(runnerUsageByProjectHandler).toHaveBeenCalledTimes(1);
      expect(runnerUsageByProjectHandler).toHaveBeenCalledWith(expectedVariables);
    });
  });

  it('shows empty results', async () => {
    runnerUsageHandler.mockResolvedValue({
      data: {
        runnerUsage: [],
      },
    });
    runnerUsageByProjectHandler.mockResolvedValue({
      data: {
        runnerUsageByProject: [],
      },
    });

    createWrapper({ mountFn: mountExtended });
    await waitForPromises();

    const projectData = findTopProjectsTable()
      .findAll('td')
      .wrappers.map((w) => w.text());
    expect(projectData).toEqual(['Other projects', '-']);

    const runnerData = findTopRunnersTable()
      .findAll('td')
      .wrappers.map((w) => w.text());
    expect(runnerData).toEqual(['Other runners', '-']);
  });

  describe('CSV export', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders button', () => {
      expect(findButton().text()).toBe('Export as CSV');
    });

    it('calls mutation for instance on button click', async () => {
      runnerUsageExportHandler.mockReturnValue(new Promise(() => {}));

      await clickButton();

      expect(runnerUsageExportHandler).toHaveBeenCalledWith({
        input: {
          fromDate: '2020-06-01T00:00:00.000Z',
          toDate: '2020-06-30T00:00:00.000Z',
          runnerType: INSTANCE_TYPE,
        },
      });
      expect(findButton().props('loading')).toBe(true);
    });

    it('calls mutation for group on button click', async () => {
      createWrapper({
        props: {
          scope: GROUP_TYPE,
          groupFullPath: 'my-group',
        },
      });

      runnerUsageExportHandler.mockReturnValue(new Promise(() => {}));

      await clickButton();

      expect(runnerUsageExportHandler).toHaveBeenCalledWith({
        input: {
          fromDate: '2020-06-01T00:00:00.000Z',
          toDate: '2020-06-30T00:00:00.000Z',
          runnerType: GROUP_TYPE,
          fullPath: 'my-group',
        },
      });
      expect(findButton().props('loading')).toBe(true);
    });

    describe('when user does not confirm', () => {
      beforeEach(() => {
        confirmAction.mockReturnValue(false);
      });

      it('does not call mutation', async () => {
        await clickButton();

        expect(runnerUsageExportHandler).not.toHaveBeenCalled();
        expect(findButton().props('loading')).toBe(false);
      });
    });

    it('handles successful result', async () => {
      runnerUsageExportHandler.mockResolvedValue({
        data: { runnersExportUsage: { errors: [] } },
      });

      await clickButton();

      expect(findButton().props('loading')).toBe(false);
      expect(mockToast).toHaveBeenCalledWith(expect.stringContaining('CSV export has started'));
    });

    describe('when an error occurs', () => {
      it('handles network error', async () => {
        runnerUsageExportHandler.mockRejectedValue(new Error('Network error'));

        await clickButton();

        expect(findButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringContaining('Something went wrong'),
        });

        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Network error'));
      });

      it('handles graphql error', async () => {
        runnerUsageExportHandler.mockResolvedValue({
          data: { runnersExportUsage: { errors: ['Error 1', 'Error 2'] } },
        });

        await clickButton();

        expect(findButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringContaining('Something went wrong'),
        });

        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Error 1 Error 2'));
      });
    });
  });
});
