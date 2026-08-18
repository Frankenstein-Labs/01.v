import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerJobFailure from 'ee/ci/runner/components/runner_job_failure.vue';
import RunnerFullName from 'ee/ci/runner/components/runner_full_name.vue';

import { runnerFailedJobsData } from '../mock_data';

const mockFailedJob = runnerFailedJobsData.data.jobs.nodes[0];

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

describe('RunnerJobFailure', () => {
  let wrapper;

  const findTimeAgo = () => wrapper.findComponent(TimeAgo);
  const findCiIcon = () => wrapper.findComponent(CiIcon);
  const findRunnerLink = () => wrapper.findByTestId('runner-link');
  const findLog = () => wrapper.find('pre');

  const createComponent = ({ job = {}, mountFn = shallowMountExtended, ...options } = {}) => {
    wrapper = mountFn(RunnerJobFailure, {
      propsData: {
        job: {
          ...mockFailedJob,
          ...job,
        },
      },
      ...options,
    });
  };

  describe('"finished at" time', () => {
    it('shows job finish time', () => {
      createComponent();

      expect(findTimeAgo().props('time')).toBe(mockFailedJob.finishedAt);
    });

    it('when data is not present, shows no job finish time', () => {
      createComponent({
        job: { finishedAt: null },
      });

      expect(findTimeAgo().exists()).toBe(false);
    });
  });

  describe('status badge', () => {
    it('shows status badge', () => {
      createComponent();

      expect(findCiIcon().props('status')).toBe(mockFailedJob.detailedStatus);
    });

    it('when data is not present, shows no status badge', () => {
      createComponent({
        job: { detailedStatus: null },
      });

      expect(findCiIcon().exists()).toBe(false);
    });
  });

  describe('runner', () => {
    it('shows runner link', () => {
      createComponent();

      expect(findRunnerLink().findComponent(RunnerFullName).props('runner')).toBe(
        mockFailedJob.runner,
      );
      expect(findRunnerLink().attributes('href')).toBe(mockFailedJob.runner.adminUrl);
    });

    it('when runner is not present, shows runner link', () => {
      createComponent({
        job: { runner: null },
      });

      expect(findRunnerLink().exists()).toBe(false);
    });
  });

  describe('job log', () => {
    it('shows job log', () => {
      createComponent();

      expect(findLog().html()).toContain(mockFailedJob.trace.htmlSummary);
    });

    it('when no job is present, shows no job log', () => {
      createComponent({
        job: { trace: null },
      });

      expect(findLog().html()).toContain('No job log');
    });

    it('when permissions are not available shows job log', () => {
      createComponent({
        job: { userPermissions: { readBuild: false } },
      });

      expect(findLog().exists()).toBe(false);
    });
  });
});
