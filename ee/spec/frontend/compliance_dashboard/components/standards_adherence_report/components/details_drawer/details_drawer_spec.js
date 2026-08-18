import { shallowMount } from '@vue/test-utils';
import { GlDrawer, GlLink, GlSprintf } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import DetailsDrawer from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/details_drawer.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import StatusesList from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_list.vue';

describe('DetailsDrawer', () => {
  let wrapper;
  let status;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DetailsDrawer, {
      propsData: {
        status,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    status = {
      complianceRequirement: {
        name: 'Requirement Name',
        description: 'Requirement Description',
        complianceRequirementsControls: {
          nodes: [{ id: 'control-1' }, { id: 'control-2' }],
        },
      },
      complianceFramework: { name: 'Framework' },
      project: {
        name: 'Project Name',
        webUrl: 'https://gitlab.com/project',
        complianceControlStatus: {
          nodes: [
            { complianceRequirementsControl: { id: 'control-1' } },
            { complianceRequirementsControl: { id: 'control-2' } },
            { complianceRequirementsControl: { id: 'control-3' } },
          ],
        },
      },
      passCount: 1,
      pendingCount: 2,
      failCount: 3,
    };
  });

  describe('rendering', () => {
    it('renders gl-drawer with correct props', () => {
      createComponent();
      const drawer = wrapper.findComponent(GlDrawer);

      expect(drawer.exists()).toBe(true);
      expect(drawer.props('open')).toBe(true);
      expect(drawer.props('zIndex')).toBe(DRAWER_Z_INDEX);
    });

    it('does not render drawer content when status is null', () => {
      createComponent({ status: null });

      expect(wrapper.findComponent(GlDrawer).props('open')).toBe(false);
    });

    it('renders framework badge', () => {
      createComponent();
      const frameworkBadge = wrapper.findComponent(FrameworkBadge);

      expect(frameworkBadge.exists()).toBe(true);
      expect(frameworkBadge.props('framework')).toStrictEqual({ name: 'Framework' });
      expect(frameworkBadge.props('popoverMode')).toBe('details');
    });

    it('renders project link', () => {
      createComponent();
      const link = wrapper.findComponent(GlLink);

      expect(link.exists()).toBe(true);
      expect(link.props('href')).toBe('https://gitlab.com/project');
      expect(link.text()).toBe('Project Name');
    });

    it('renders requirement description when available', () => {
      createComponent();

      expect(wrapper.text()).toContain('Description');
      expect(wrapper.text()).toContain('Requirement Description');
    });

    it('renders status section with correct counts', () => {
      createComponent();

      expect(wrapper.text()).toContain('Status');
      expect(wrapper.text()).toContain('Failed controls: 3');
      expect(wrapper.text()).toContain('Pending controls: 2');
      expect(wrapper.text()).toContain('Passed controls: 1');
    });

    it('renders statuses list with filtered statuses', () => {
      createComponent();
      const statusesList = wrapper.findComponent(StatusesList);

      expect(statusesList.exists()).toBe(true);
      expect(statusesList.props('controlStatuses')).toHaveLength(2);
    });
  });

  describe('events', () => {
    it('emits close event when drawer is closed', () => {
      createComponent();

      wrapper.findComponent(GlDrawer).vm.$emit('close');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
