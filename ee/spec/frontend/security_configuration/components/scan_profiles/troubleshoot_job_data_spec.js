import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TroubleshootJobData from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_data.vue';
import ScannerStatusIcon from 'ee/security_configuration/components/scan_profiles/scanner_status_icon.vue';
import { humanizeTimeInterval } from '~/lib/utils/datetime/date_format_utility';
import { SCAN_PROFILE_SOURCE_LABELS } from '~/security_configuration/constants';
import { mockJobData } from './mock_data';

describe('TroubleshootJobData', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(TroubleshootJobData, {
      propsData: {
        name: mockJobData.name,
        status: mockJobData.status,
        duration: mockJobData.duration,
        source: mockJobData.source,
        finishedAt: mockJobData.finishedAt,
        webPath: mockJobData.webPath,
        pipeline: mockJobData.pipeline,
        ...props,
      },
    });
  };

  const findPipelineLink = () => wrapper.findByTestId('pipeline-path');
  const findJobLink = () => wrapper.findByTestId('job-path');
  const findScannerStatusIcon = () => wrapper.findComponent(ScannerStatusIcon);

  describe('rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the job name', () => {
      expect(wrapper.text()).toContain('dependency-scanner-name');
    });

    it('renders the job source', () => {
      expect(wrapper.text()).toContain(SCAN_PROFILE_SOURCE_LABELS.merge_request_event);
    });

    it('does not render the source row when source is absent', () => {
      createWrapper({ source: null });
      expect(wrapper.text()).not.toContain('Source');
    });

    it('renders the formatted duration', () => {
      expect(wrapper.text()).toContain(humanizeTimeInterval(21));
    });

    it('renders ScannerStatusIcon with correct status', () => {
      expect(findScannerStatusIcon().props('status')).toBe(mockJobData.status);
    });

    it('renders the scanner status text', () => {
      wrapper = mountExtended(TroubleshootJobData, {
        propsData: {
          name: mockJobData.name,
          status: mockJobData.status,
          duration: mockJobData.duration,
          source: mockJobData.source,
          finishedAt: mockJobData.finishedAt,
          webPath: mockJobData.webPath,
          pipeline: mockJobData.pipeline,
        },
      });
      expect(wrapper.findByTestId('scanner-status').text()).toBe('Active');
    });

    it('does not render finished time when not in drawer mode', () => {
      expect(wrapper.findByText('Finished:').exists()).toBe(false);
    });

    it('does not render job link when not in drawer mode', () => {
      expect(findJobLink().exists()).toBe(false);
    });
  });

  describe('pipeline link', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the pipeline link with correct href', () => {
      expect(findPipelineLink().attributes('href')).toBe('/gitlab-org/gitlab/-/pipelines/456');
    });

    it('renders the pipeline id as link text', () => {
      expect(findPipelineLink().text()).toContain('456');
    });
  });

  describe('when isDrawer is true', () => {
    beforeEach(() => {
      createWrapper({ isDrawer: true });
    });

    it('renders the finished time', () => {
      expect(wrapper.text()).toContain('Finished');
    });

    it('renders the job link', () => {
      expect(findJobLink().exists()).toBe(true);
    });

    it('renders the job link with correct href', () => {
      expect(findJobLink().attributes('href')).toBe('/group/project/-/jobs/123');
    });

    it('renders the job id as link text', () => {
      const jobId = mockJobData.webPath.split('/').pop();
      expect(findJobLink().text()).toContain(`#${jobId}`);
    });
  });
});
