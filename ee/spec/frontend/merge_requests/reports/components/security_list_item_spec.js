import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import StatusIcon from '~/vue_merge_request_widget/components/widget/status_icon.vue';
import SecurityListApp from 'ee/merge_requests/reports/components/security_list_item.vue';

describe('Merge request reports SecurityListApp component', () => {
  let wrapper;

  const findSecurityHeading = () => wrapper.findByTestId('security-item-heading');
  const findSecuritySubheading = () => wrapper.findByTestId('security-item-subheading');
  const findSecurityFinding = () => wrapper.findByTestId('security-item-finding');
  const findSecurityFindingStatusIcon = () =>
    wrapper.findComponentByTestId('security-item-finding-status-icon');
  const findSecurityFindingButton = () =>
    wrapper.findComponentByTestId('security-item-finding-button');

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(SecurityListApp, {
      propsData: { policyName: 'Policy Name', loading: false, status: 'failed', ...propsData },
      stubs: { GlSprintf },
    });
  };

  it('renders loading text', () => {
    createComponent({ loading: true });

    expect(findSecuritySubheading().text()).toBe('Results pending…');
  });

  describe('with findings', () => {
    it.each`
      findings                                      | text
      ${[]}                                         | ${'Policy `Policy Name` passed'}
      ${[{ name: 'Finding' }]}                      | ${'Policy `Policy Name` found 1 violation'}
      ${[{ name: 'Finding' }, { name: 'Finding' }]} | ${'Policy `Policy Name` found 2 violations'}
    `('renders "$text" subheading with $findings', ({ findings, text }) => {
      createComponent({ findings });

      expect(findSecurityHeading().text()).toBe(text);
    });

    it.each`
      findings                                      | text
      ${[]}                                         | ${'No policy violations found'}
      ${[{ name: 'Finding' }]}                      | ${'1 finding must be resolved'}
      ${[{ name: 'Finding' }, { name: 'Finding' }]} | ${'2 findings must be resolved'}
    `('renders "$text" subheading with $findings', ({ findings, text }) => {
      createComponent({ findings });

      expect(findSecuritySubheading().text()).toBe(text);
    });

    it('renders security finding text', () => {
      createComponent({ findings: [{ name: 'Finding', severity: 'high' }] });

      expect(findSecurityFinding().text()).toContain('High');
      expect(findSecurityFinding().text()).toContain('Finding');
    });

    it('renders security finding icon', () => {
      createComponent({ findings: [{ name: 'Finding', severity: 'high' }] });

      expect(findSecurityFindingStatusIcon().props('iconName')).toBe('severityHigh');
    });

    it('emits open-finding when clicking finding button', () => {
      createComponent({ findings: [{ name: 'Finding', severity: 'high' }] });

      findSecurityFindingButton().vm.$emit('click');

      expect(wrapper.emitted('open-finding')[0][0]).toEqual({ name: 'Finding', severity: 'high' });
    });

    it('selects finding button when selectedFinding matches a finding', () => {
      createComponent({
        findings: [{ name: 'Finding', severity: 'high' }],
        selectedFinding: { name: 'Finding' },
      });

      expect(findSecurityFindingButton().props('selected')).toBe(true);
    });
  });

  it.each`
    status       | icon          | iconName
    ${'SUCCESS'} | ${StatusIcon} | ${'StatusIcon'}
    ${'WARNING'} | ${StatusIcon} | ${'StatusIcon'}
    ${'RUNNING'} | ${CiIcon}     | ${'CiIcon'}
  `('renders icon $iconName for status $status', ({ status, icon }) => {
    createComponent({ status });

    expect(wrapper.findComponent(icon).exists()).toBe(true);
  });
});
