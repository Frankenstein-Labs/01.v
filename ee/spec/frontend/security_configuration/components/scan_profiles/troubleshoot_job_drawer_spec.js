import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlDrawer, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { SCAN_PROFILE_CATEGORIES } from '~/security_configuration/constants';
import TroubleshootJobDrawer from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_drawer.vue';
import TroubleshootJobData from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_data.vue';
import scannerJobDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/scanner_job_details.query.graphql';
import duoChatAvailableQuery from 'ee/ai/graphql/duo_chat_available.query.graphql';
import { mockJobData, mockStatus } from './mock_data';

Vue.use(VueApollo);

const mockGitlabUrl = 'http://gitlab.test';

const duoChatAvailableResponse = (available = true) => ({
  data: {
    currentUser: {
      id: 'gid://gitlab/User/1',
      duoChatAvailable: available,
    },
  },
});

describe('TroubleshootJobDrawer', () => {
  let wrapper;
  let duoChatAvailableHandler;

  beforeEach(() => {
    gon.gitlab_url = mockGitlabUrl;
    duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(false));
  });

  const createJobDetailsResolver = (job = mockJobData) =>
    jest.fn().mockResolvedValue({
      data: { project: { job } },
    });

  const createPendingJobDetailsResolver = () => jest.fn().mockReturnValue(new Promise(() => {}));

  const createWrapper = async (props = {}, jobDetailsResolver = createJobDetailsResolver()) => {
    const apolloProvider = createMockApollo([
      [duoChatAvailableQuery, duoChatAvailableHandler],
      [scannerJobDetailsQuery, jobDetailsResolver],
    ]);

    wrapper = shallowMountExtended(TroubleshootJobDrawer, {
      apolloProvider,
      propsData: {
        openDrawer: true,
        jobData: mockJobData,
        buildId: mockStatus.buildId,
        scanType: mockStatus.scanType,
        status: mockStatus.status,
        fullPath: 'root/project',
        ...props,
      },
      stubs: {
        GlDrawer: {
          props: ['open'],
          template: '<div><slot name="title" /><slot /><slot name="footer" /></div>',
        },
      },
    });
    await waitForPromises();
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findLoadingIcon = () => wrapper.findByTestId('drawer-loader');
  const findErrorMessage = () => wrapper.findByTestId('error-message');
  const findJobData = () => wrapper.findComponent(TroubleshootJobData);
  const findTraceSummary = () => wrapper.findByTestId('job-trace-summary');
  const findFailureMessage = () => wrapper.findByTestId('failure-message');
  const findDuoButton = () => wrapper.findComponentByTestId('duo-button');
  const findViewJobButton = () => wrapper.findByTestId('view-job-button');

  describe('when jobData is provided in drawerData', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the drawer', () => {
      expect(findDrawer().exists()).toBe(true);
    });

    it('passes openDrawer prop to GlDrawer', () => {
      expect(findDrawer().props('open')).toBe(true);
    });

    it('renders TroubleshootJobData with correct props', () => {
      expect(findJobData().props()).toMatchObject({
        name: mockJobData.name,
        status: mockStatus.status,
        duration: mockJobData.duration,
        source: mockJobData.source,
        finishedAt: mockJobData.finishedAt,
        webPath: mockJobData.webPath,
        pipeline: mockJobData.pipeline,
        isDrawer: true,
      });
    });

    it('renders the correct drawer title', () => {
      const scannerName = SCAN_PROFILE_CATEGORIES[mockStatus.scanType]?.displayName || '';
      expect(wrapper.text()).toContain(`${scannerName} failure`);
    });

    it('renders Job details heading', () => {
      expect(wrapper.text()).toContain('Job details');
    });
  });

  describe('loading state', () => {
    it('renders the drawer while the job details query is in flight', async () => {
      await createWrapper({ jobData: {} }, createPendingJobDetailsResolver());
      expect(findDrawer().exists()).toBe(true);
      expect(findDrawer().props('open')).toBe(true);
    });

    it('renders a loading icon while the job details query is in flight', async () => {
      await createWrapper({ jobData: {} }, createPendingJobDetailsResolver());
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findLoadingIcon().findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('does not render the job details content while loading', async () => {
      await createWrapper({ jobData: {} }, createPendingJobDetailsResolver());
      expect(findJobData().exists()).toBe(false);
      expect(wrapper.text()).not.toContain('Job details');
    });

    it('does not render footer buttons while loading', async () => {
      await createWrapper({ jobData: {} }, createPendingJobDetailsResolver());
      expect(findViewJobButton().exists()).toBe(false);
      expect(findDuoButton().exists()).toBe(false);
    });

    it('does not render the loading icon when jobData is already provided', async () => {
      await createWrapper();
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findJobData().exists()).toBe(true);
    });
  });

  describe('error state', () => {
    it('renders the error message when the query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('network error'));
      await createWrapper({ jobData: {} }, errorResolver);

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toContain('Failed to load scan details');
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findJobData().exists()).toBe(false);
    });
  });

  describe('failure message section', () => {
    it('renders failure message when present', async () => {
      await createWrapper({
        jobData: { ...mockJobData, failureMessage: 'Job failed due to an error' },
      });
      expect(findFailureMessage().text()).toBe('Job failed due to an error');
    });

    it('does not render failure message when absent', async () => {
      await createWrapper({ jobData: { ...mockJobData } });
      expect(findFailureMessage().exists()).toBe(false);
    });
  });

  describe('trace summary section', () => {
    it('renders trace summary when htmlSummary is present and no failure message', async () => {
      await createWrapper({
        jobData: { ...mockJobData, failureMessage: null },
      });
      expect(findTraceSummary().text()).toContain('some trace');
    });

    it('does not render trace summary when htmlSummary is absent', async () => {
      await createWrapper({
        jobData: { ...mockJobData, trace: { htmlSummary: null } },
      });
      expect(findTraceSummary().exists()).toBe(false);
    });

    it('does not render trace summary when failure message is present', async () => {
      await createWrapper({
        jobData: { ...mockJobData, failureMessage: 'Job failed due to an error' },
      });
      expect(findTraceSummary().exists()).toBe(false);
    });
  });

  describe('root cause section', () => {
    it('renders root cause heading when htmlSummary is present and no failure message', async () => {
      await createWrapper({
        jobData: { ...mockJobData, failureMessage: null },
      });
      expect(wrapper.text()).toContain('Root cause');
    });

    it('does not render root cause heading when htmlSummary is absent', async () => {
      await createWrapper({
        jobData: { ...mockJobData, trace: { htmlSummary: null } },
      });
      expect(wrapper.text()).not.toContain('Root cause');
    });

    it('does not render root cause heading when failure message is present', async () => {
      await createWrapper({
        jobData: { ...mockJobData, failureMessage: 'Job failed due to an error' },
      });
      expect(wrapper.text()).not.toContain('Root cause');
    });
  });

  describe('Duo Chat quick action', () => {
    describe('when duoChatAvailable is true', () => {
      beforeEach(async () => {
        duoChatAvailableHandler = jest.fn().mockResolvedValue(duoChatAvailableResponse(true));
        await createWrapper();
      });

      it('renders DuoChatQuickAction', () => {
        expect(findDuoButton().exists()).toBe(true);
      });

      it('passes correct props to DuoChatQuickAction', () => {
        expect(findDuoButton().props()).toMatchObject({
          resourceId: convertToGraphQLId(
            'Ci::Build',
            getIdFromGraphQLId('gid://gitlab/CommitStatus/123'),
          ),
          buttonText: 'Troubleshoot failure',
          buttonOptions: { variant: 'confirm' },
          trackingInfo: { label: 'security_scan_troubleshoot_duo' },
          command: { agenticPrompt: 'Troubleshoot this broken pipeline.' },
          classicQuickAction: '/troubleshoot',
        });
      });

      it('renders DuoChatQuickAction with confirm variant', () => {
        expect(findDuoButton().props('buttonOptions')).toMatchObject({
          variant: 'confirm',
        });
      });
    });

    describe('when duoChatAvailable is false', () => {
      beforeEach(async () => {
        await createWrapper();
      });

      it('does not render DuoChatQuickAction', () => {
        expect(findDuoButton().exists()).toBe(false);
      });
    });

    describe('when the query errors', () => {
      beforeEach(async () => {
        duoChatAvailableHandler = jest.fn().mockRejectedValue(new Error('network error'));
        await createWrapper();
      });

      it('does not render DuoChatQuickAction', () => {
        expect(findDuoButton().exists()).toBe(false);
      });
    });
  });

  describe('view job button', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the view job button', () => {
      expect(findViewJobButton().exists()).toBe(true);
    });

    it('renders the button with correct href', () => {
      expect(findViewJobButton().attributes('href')).toBe(mockJobData.webPath);
    });

    it('renders the button with correct title', () => {
      const jobId = getIdFromGraphQLId(mockStatus.buildId);
      expect(findViewJobButton().text()).toContain(`View job #${jobId}`);
    });
  });

  describe('when openDrawer is false', () => {
    it('passes open=false to GlDrawer', async () => {
      await createWrapper({ openDrawer: false });
      expect(findDrawer().props('open')).toBe(false);
    });
  });

  describe('events', () => {
    it('emits close-drawer when drawer is closed', async () => {
      await createWrapper();
      await findDrawer().vm.$emit('close');
      expect(wrapper.emitted('close-drawer')).toHaveLength(1);
    });
  });
});
