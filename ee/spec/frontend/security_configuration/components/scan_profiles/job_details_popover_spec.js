import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlLoadingIcon, GlPopover } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import JobDetailsPopover from 'ee/security_configuration/components/scan_profiles/job_details_popover.vue';
import TroubleshootJobData from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_data.vue';
import scannerJobDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/scanner_job_details.query.graphql';
import {
  SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
} from '~/security_configuration/constants';
import { mockJobData } from './mock_data';

Vue.use(VueApollo);

describe('JobDetailsPopover', () => {
  let wrapper;

  const mockBuildId = 'gid://gitlab/CommitStatus/123';
  const mockProjectFullPath = 'group/project';
  const mockTarget = 'scanner-details';
  const mockTitle = 'Scan failed';

  const mockFailedJobData = {
    ...mockJobData,
    webPath: '',
    status: SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  };

  const mockWarningJobData = {
    ...mockJobData,
    webPath: '',
    status: SCAN_PROFILE_SCANNER_HEALTH_WARNING,
  };

  const createJobDetailsResolver = (job = mockJobData) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          job,
        },
      },
    });

  const createComponent = ({
    jobDetailsResolver = createJobDetailsResolver(),
    buildId = mockBuildId,
    projectFullPath = mockProjectFullPath,
    status = SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
    target = mockTarget,
    title = mockTitle,
    show = false,
  } = {}) => {
    const apolloProvider = createMockApollo([[scannerJobDetailsQuery, jobDetailsResolver]]);
    wrapper = mountExtended(JobDetailsPopover, {
      apolloProvider,
      propsData: {
        buildId,
        projectFullPath,
        status,
        target,
        title,
        show,
      },
      stubs: {
        TroubleshootJobData: stubComponent(TroubleshootJobData),
        GlButton: stubComponent(GlButton, {
          template: '<button @click="$emit(\'click\')"><slot /></button>',
        }),
      },
    });
    return wrapper;
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTroubleshootJobData = () => wrapper.findComponent(TroubleshootJobData);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findPopoverContent = () => wrapper.findByTestId('popover-content');

  describe('GlPopover', () => {
    it('passes target prop to GlPopover', () => {
      createComponent();
      expect(findGlPopover().props('target')).toBe(mockTarget);
    });

    it('passes title prop to GlPopover', () => {
      createComponent();
      expect(findGlPopover().props('title')).toBe(mockTitle);
    });

    it('passes show prop to GlPopover', () => {
      createComponent({ show: true });
      expect(findGlPopover().props('show')).toBe(true);
    });

    it('emits mouseenter when hovering popover content', async () => {
      createComponent();
      await waitForPromises();
      await findPopoverContent().trigger('mouseenter');
      expect(wrapper.emitted('mouseenter')).toHaveLength(1);
    });

    it('emits mouseleave when leaving popover content', async () => {
      createComponent();
      await waitForPromises();
      await findPopoverContent().trigger('mouseleave');
      expect(wrapper.emitted('mouseleave')).toHaveLength(1);
    });
  });

  describe('loading state', () => {
    it('shows loading icon while query is loading', () => {
      const loadingResolver = jest.fn(() => new Promise(() => {}));
      createComponent({ jobDetailsResolver: loadingResolver });
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('hides loading icon after query resolves', async () => {
      createComponent();
      await waitForPromises();
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows error message when query fails', async () => {
      const errorResolver = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ jobDetailsResolver: errorResolver });
      await waitForPromises();
      expect(wrapper.text()).toContain('Failed to load scan details');
    });
  });

  describe('job data rendering', () => {
    it('renders TroubleshootJobData with correct props when job data is loaded', async () => {
      createComponent();
      await waitForPromises();
      wrapper.vm.jobData = mockJobData;
      wrapper.vm.errorMessage = null;
      await nextTick();

      expect(findTroubleshootJobData().exists()).toBe(true);
      expect(findTroubleshootJobData().props()).toMatchObject({
        name: mockJobData.name,
        status: mockJobData.status,
        duration: mockJobData.duration,
        source: mockJobData.source,
        pipeline: mockJobData.pipeline,
      });
    });
  });

  describe('action button', () => {
    describe('when status is active', () => {
      it('renders a default button (View job)', async () => {
        createComponent();
        await waitForPromises();
        wrapper.vm.jobData = mockJobData;
        wrapper.vm.errorMessage = null;
        await nextTick();

        expect(findButton().props('category')).toBe('secondary');
        expect(findButton().props('variant')).toBe('default');
        expect(findButton().text()).toContain('View job #');
      });

      it('renders button as a link to the job page', async () => {
        createComponent();
        await waitForPromises();
        wrapper.vm.jobData = mockJobData;
        wrapper.vm.errorMessage = null;
        await nextTick();
        expect(findButton().props('href')).toBe(mockJobData.webPath);
      });

      it('does not emit open-drawer when button is clicked', async () => {
        createComponent();
        await waitForPromises();
        wrapper.vm.jobData = mockJobData;
        wrapper.vm.errorMessage = null;
        await nextTick();

        await findButton().trigger('click');
        expect(wrapper.emitted('open-drawer')).toBeUndefined();
      });
    });

    describe('when status is failed or warning', () => {
      it.each([
        ['failed', mockFailedJobData],
        ['warning', mockWarningJobData],
      ])(
        'renders a primary (Troubleshoot failure) button when status is %s',
        async (_, jobData) => {
          createComponent({
            jobDetailsResolver: createJobDetailsResolver(jobData),
            status: jobData.status,
          });
          await waitForPromises();
          await nextTick();
          wrapper.vm.jobData = jobData;
          wrapper.vm.errorMessage = null;
          await nextTick();

          expect(findButton().props('category')).toBe('primary');
          expect(findButton().props('variant')).toBe('confirm');
        },
      );

      it.each([
        ['failed', mockFailedJobData],
        ['warning', mockWarningJobData],
      ])('does not render button as a link when status is %s', async (_, jobData) => {
        createComponent({
          jobDetailsResolver: createJobDetailsResolver(jobData),
          status: jobData.status,
        });
        await waitForPromises();
        wrapper.vm.errorMessage = null;
        await nextTick();

        expect(findButton().props('href')).toBeUndefined();
      });

      it.each([
        ['failed', mockFailedJobData],
        ['warning', mockWarningJobData],
      ])(
        'emits open-drawer with job data when button is clicked and status is %s',
        async (_, jobData) => {
          createComponent({
            jobDetailsResolver: createJobDetailsResolver(jobData),
            status: jobData.status,
          });
          await waitForPromises();
          wrapper.vm.jobData = jobData;
          wrapper.vm.errorMessage = null;
          await nextTick();

          await findButton().trigger('click');
          expect(wrapper.emitted('open-drawer')).toHaveLength(1);
        },
      );
    });
  });

  describe('apollo query', () => {
    it('calls query with correct variables', () => {
      const resolver = createJobDetailsResolver();
      createComponent({ jobDetailsResolver: resolver });
      expect(resolver).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        id: mockBuildId,
      });
    });
  });
});
