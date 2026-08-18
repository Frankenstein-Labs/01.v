import { GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import RequirementStatus from 'ee/compliance_dashboard/components/standards_adherence_report/components/requirement_status.vue';

describe('RequirementStatus', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mount(RequirementStatus, {
      propsData: {
        pendingCount: 0,
        passCount: 0,
        failCount: 0,
        ...props,
      },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findIcon = () => wrapper.findComponent(GlIcon);

  describe('status indicators', () => {
    describe('when status is pending', () => {
      beforeEach(() => {
        createComponent({ pendingCount: 2, passCount: 3, failCount: 0 });
      });

      it('renders loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(true);
        expect(findIcon().exists()).toBe(false);
      });

      it('displays pending text', () => {
        expect(wrapper.text()).toContain('Pending');
      });
    });

    describe('when status is failed', () => {
      beforeEach(() => {
        createComponent({ pendingCount: 0, passCount: 3, failCount: 2 });
      });

      it('renders failed icon', () => {
        expect(findIcon().exists()).toBe(true);
        expect(findIcon().props('name')).toBe('status_failed');
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('displays failure count text', () => {
        expect(wrapper.text()).toContain('2/5 controls failed');
      });
    });

    describe('when status is passed', () => {
      beforeEach(() => {
        createComponent({ pendingCount: 0, passCount: 5, failCount: 0 });
      });

      it('renders success icon', () => {
        expect(findIcon().exists()).toBe(true);
        expect(findIcon().props('name')).toBe('status_success');
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('displays passed text', () => {
        expect(wrapper.text()).toContain('Passed');
      });
    });
  });

  describe('count calculations', () => {
    it('correctly identifies pending status when any pending items exist', () => {
      createComponent({ pendingCount: 1, passCount: 3, failCount: 0 });
      expect(findLoadingIcon().exists()).toBe(true);
      expect(wrapper.text()).toContain('Pending');
    });

    it('correctly identifies failed status when any failed items exist', () => {
      createComponent({ pendingCount: 0, passCount: 3, failCount: 1 });
      expect(findIcon().props('name')).toBe('status_failed');
      expect(wrapper.text()).toContain('1/4 controls failed');
    });

    it('prioritizes failed over pending status', () => {
      createComponent({ pendingCount: 1, passCount: 3, failCount: 2 });
      expect(findIcon().props('name')).toBe('status_failed');
      expect(findLoadingIcon().exists()).toBe(false);
      expect(wrapper.text()).toContain('2/6 controls failed');
    });
  });

  describe('pluralization', () => {
    it('uses singular form for a single control', () => {
      createComponent({ pendingCount: 0, passCount: 0, failCount: 1 });
      expect(wrapper.text()).toContain('1/1 control failed');
    });

    it('uses plural form for multiple controls', () => {
      createComponent({ pendingCount: 0, passCount: 1, failCount: 2 });
      expect(wrapper.text()).toContain('2/3 controls failed');
    });
  });
});
