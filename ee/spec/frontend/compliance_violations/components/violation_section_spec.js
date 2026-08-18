import { mountExtended } from 'helpers/vue_test_utils_helper';
import ViolationSection from 'ee/compliance_violations/components/violation_section.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { statusesInfo } from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';

describe('ViolationSection', () => {
  let wrapper;

  const mockControl = {
    name: 'merge_request_prevent_committers_approval',
    complianceRequirement: {
      name: 'basic code regulation',
      framework: {
        id: 'gid://gitlab/ComplianceManagement::Framework/3',
        color: '#cd5b45',
        default: false,
        name: 'SOC 2',
        description: 'SOC 2 description',
      },
    },
  };

  const mockComplianceCenterPath = 'mock/compliance-center';

  const createComponent = (props = {}) => {
    wrapper = mountExtended(ViolationSection, {
      propsData: {
        control: mockControl,
        complianceCenterPath: mockComplianceCenterPath,
        ...props,
      },
    });
  };

  const findViolationSection = () => wrapper.findComponent(CrudComponent);
  const findFrameworkBadge = () => wrapper.findComponent(FrameworkBadge);
  const findRequirement = () => wrapper.findByTestId('violation-requirement');
  const findControl = () => wrapper.findByTestId('violation-control');

  beforeEach(() => {
    createComponent();
  });

  describe('violation section', () => {
    it('renders violation section', () => {
      expect(findViolationSection().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      const titleElement = wrapper.findByTestId('crud-title');
      expect(titleElement.text()).toBe('Violation created based on associated framework');
    });

    it('renders correct framework', () => {
      const frameworkBadge = findFrameworkBadge();
      expect(frameworkBadge.exists()).toBe(true);
      expect(frameworkBadge.text()).toContain(mockControl.complianceRequirement.framework.name);
    });

    it('renders correct requirement', () => {
      const requirement = findRequirement();
      expect(requirement.exists()).toBe(true);
      expect(requirement.text()).toContain(mockControl.complianceRequirement.name);
    });
  });

  describe('control title', () => {
    it('renders control title from statusesInfo when available', () => {
      const control = findControl();
      expect(control.exists()).toBe(true);
      expect(control.text()).toContain(statusesInfo[mockControl.name].title);
    });

    it('renders control name when title is not found in statusesInfo', () => {
      const controlName = 'unknown_control';
      createComponent({
        control: {
          ...mockControl,
          name: controlName,
        },
      });

      const control = findControl();
      expect(control.text()).toContain(controlName);
    });

    it('renders empty string when control has no name', () => {
      createComponent({
        control: {
          complianceRequirement: mockControl.complianceRequirement,
        },
      });

      const control = findControl();
      expect(control.text()).toBe('Control:');
    });
  });
});
