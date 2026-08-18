import { GlButton, GlIcon } from '@gitlab/ui';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import IssueField from 'ee/external_issues_show/components/sidebar/issue_field.vue';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';

describe('IssueField', () => {
  let wrapper;

  const defaultProps = {
    icon: 'calendar',
    title: 'Field Title',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(IssueField, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: { ...defaultProps, ...props },
      stubs: {
        SidebarEditableItem,
      },
    });
  };

  const findEditableItem = () => wrapper.findComponent(SidebarEditableItem);
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findFieldCollapsed = () => wrapper.findByTestId('field-collapsed');
  const findFieldCollapsedTooltip = () => getBinding(findFieldCollapsed().element, 'gl-tooltip');
  const findFieldValue = () => wrapper.findByTestId('field-value');
  const findGlIcon = () => wrapper.findComponent(GlIcon);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders title', () => {
      expect(findEditableItem().props('title')).toBe(defaultProps.title);
    });

    it('renders GlIcon (when collapsed)', () => {
      expect(findGlIcon().props('name')).toBe(defaultProps.icon);
    });

    it('does not render "Edit" button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('without value prop', () => {
    beforeEach(() => {
      createComponent();
    });

    it('falls back to "None"', () => {
      expect(findFieldValue().text()).toBe('None');
    });

    it('renders tooltip (when collapsed) with "value" = title', () => {
      const tooltip = findFieldCollapsedTooltip();

      expect(tooltip).toBeDefined();
      expect(tooltip.value.title).toBe(defaultProps.title);
    });
  });

  describe('with value prop', () => {
    const value = 'field value';

    beforeEach(() => {
      createComponent({
        props: { value },
      });
    });

    it('renders the value', () => {
      expect(findFieldValue().text()).toBe(value);
    });

    it('renders tooltip (when collapsed) with "value" = value', () => {
      const tooltip = findFieldCollapsedTooltip();

      expect(tooltip).toBeDefined();
      expect(tooltip.value.title).toBe(value);
    });
  });
});
