import { nextTick } from 'vue';
import { GlLink } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import LastScanCell from 'ee/security_configuration/components/scan_profiles/last_scan_cell.vue';
import JobDetailsPopover from 'ee/security_configuration/components/scan_profiles/job_details_popover.vue';

describe('LastScanCell', () => {
  let wrapper;

  const buildId = 'gid://gitlab/CommitStatus/123';
  const lastScanAt = '2026-03-17T14:30:00Z';
  const projectFullPath = 'group/project';
  const targetId = 'scanner-details-1';

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(LastScanCell, {
      propsData: {
        targetId,
        lastScanAt,
        buildId,
        status: 'active',
        projectFullPath,
        ...props,
      },
      stubs: {
        JobDetailsPopover: stubComponent(JobDetailsPopover),
      },
    });
  };

  const findLastScanContainer = () => wrapper.findByTestId('last-scan');
  const findLink = () => wrapper.findComponent(GlLink);
  const findPopover = () => wrapper.findComponent(JobDetailsPopover);

  describe('rendering', () => {
    it('renders the formatted date, link and popover when both lastScanAt and buildId are set', () => {
      createComponent();

      expect(findLastScanContainer().exists()).toBe(true);
      expect(findLink().exists()).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('renders only the formatted date when buildId is missing', () => {
      createComponent({ buildId: null });

      expect(findLastScanContainer().exists()).toBe(false);
      expect(findLink().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
      expect(wrapper.text()).not.toBe('—');
    });

    it('renders an em dash when lastScanAt is missing', () => {
      createComponent({ lastScanAt: null, buildId: null });
      expect(wrapper.text()).toBe('—');
    });
  });

  describe('link text', () => {
    it('renders "View job #N" by default for non-failed status', () => {
      createComponent({ status: 'active' }, mountExtended);
      expect(findLink().text()).toBe('View job #123');
    });

    it('renders "View failed job #N" when status is failed', () => {
      createComponent({ status: 'failed' }, mountExtended);
      expect(findLink().text()).toBe('View failed job #123');
    });

    it('renders "View failed job #N" when status is warning', () => {
      createComponent({ status: 'warning' }, mountExtended);
      expect(findLink().text()).toBe('View failed job #123');
    });

    it('renders "Pipeline job: #N" regardless of status when linkVariant is pipeline-job', () => {
      createComponent({ linkVariant: 'pipeline-job', status: 'failed' }, mountExtended);
      expect(findLink().text()).toBe('Pipeline job: #123');
    });
  });

  describe('popover title', () => {
    it.each([
      ['active', 'Scan successful'],
      ['warning', 'Scan warning'],
      ['failed', 'Scan failed'],
      ['stale', 'Scan outdated'],
    ])('passes "%s" title for %s status', (status, expectedTitle) => {
      createComponent({ status });
      expect(findPopover().props('title')).toBe(expectedTitle);
    });

    it('passes empty title for unknown status', () => {
      createComponent({ status: 'pending' });
      expect(findPopover().props('title')).toBe('');
    });
  });

  describe('popover props', () => {
    it('forwards buildId, projectFullPath, status and targetId to the popover', () => {
      createComponent({ status: 'failed' });

      const popover = findPopover();
      expect(popover.props('buildId')).toBe(buildId);
      expect(popover.props('projectFullPath')).toBe(projectFullPath);
      expect(popover.props('status')).toBe('failed');
      expect(popover.props('target')).toBe(targetId);
    });

    it('is hidden initially', () => {
      createComponent();
      expect(findPopover().props('show')).toBe(false);
    });
  });

  describe('hover behavior', () => {
    it('shows the popover on mouseenter over the link', async () => {
      createComponent({}, mountExtended);
      await findLink().trigger('mouseenter');
      expect(findPopover().props('show')).toBe(true);
    });

    it('hides the popover after the close timeout fires on mouseleave', async () => {
      createComponent({}, mountExtended);
      await findLink().trigger('mouseenter');

      let timeoutCallback;
      jest.spyOn(global, 'setTimeout').mockImplementation((cb) => {
        timeoutCallback = cb;
      });

      await findLink().trigger('mouseleave');
      timeoutCallback();
      await nextTick();

      expect(findPopover().props('show')).toBe(false);
      jest.restoreAllMocks();
    });

    it('hides the popover immediately on blur', async () => {
      createComponent({}, mountExtended);
      await findLink().trigger('mouseenter');
      expect(findPopover().props('show')).toBe(true);

      await findLink().trigger('blur');
      expect(findPopover().props('show')).toBe(false);
    });
  });

  describe('open-drawer', () => {
    it('re-emits open-drawer with the payload from the popover', async () => {
      createComponent();
      const payload = { name: 'job-x', status: 'failed' };

      findPopover().vm.$emit('open-drawer', payload);
      await nextTick();
      expect(wrapper.emitted('open-drawer')).toEqual([[payload]]);
    });

    it('closes the popover when emitting open-drawer', async () => {
      createComponent({}, mountExtended);
      await findLink().trigger('mouseenter');
      expect(findPopover().props('show')).toBe(true);

      findPopover().vm.$emit('open-drawer', {});
      await nextTick();
      expect(findPopover().props('show')).toBe(false);
    });
  });
});
