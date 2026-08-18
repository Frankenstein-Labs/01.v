import { GlIcon, GlTooltip, GlTruncate } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { GL_DARK } from '~/constants';

describe('WorkItemStatusBadge', () => {
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBadge = () => wrapper.find('[data-testid="work-item-status-badge"]');
  const findBadgeText = () => findBadge().text();
  const findTooltip = () => wrapper.findComponent(GlTooltip);
  const findTruncate = () => wrapper.findComponent(GlTruncate);

  const createComponent = ({
    name = 'Duplicate',
    iconName = 'status-cancelled',
    color = '',
    description = null,
  } = {}) => {
    wrapper = shallowMount(WorkItemStatusBadge, {
      propsData: {
        item: {
          name,
          iconName,
          color,
          description,
        },
      },
      stubs: {
        GlTruncate,
      },
    });
  };

  describe('with required props only', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correctly', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findIcon().exists()).toBe(true);
    });

    it('displays the correct name', () => {
      expect(findBadgeText()).toBe('Duplicate');
    });

    it('passes the correct icon name prop', () => {
      expect(findIcon().props('name')).toBe('status-cancelled');
    });

    it('does not apply color style when color prop is not provided', () => {
      expect(findIcon().attributes('style')).toBeUndefined();
    });
  });

  describe('with all props including color', () => {
    const testColor = '#ff0000';

    it('applies the color style to the icon', () => {
      createComponent({ color: testColor });
      expect(findIcon().attributes('style')).toBe('color: rgb(255, 0, 0);');
    });
  });

  describe('icon colors in dark mode', () => {
    beforeEach(() => {
      gon.user_color_mode = GL_DARK;
    });

    it.each`
      color        | darkModeColor
      ${'#737278'} | ${'color: rgb(137, 136, 141);'}
      ${'#1f75cb'} | ${'color: rgb(66, 143, 220);'}
      ${'#108548'} | ${'color: rgb(45, 161, 96);'}
      ${'#DD2B0E'} | ${'color: rgb(236, 89, 65);'}
    `(
      'converts $color to dark mode friendly $darkModeColor in dark mode',
      ({ color, darkModeColor }) => {
        createComponent({ color });

        expect(findIcon().attributes('style')).toBe(darkModeColor);
      },
    );
  });

  describe('tooltip behavior', () => {
    it('shows tooltip when description is provided', () => {
      const description = 'This describes the status.';
      createComponent({ description });

      const tooltip = findTooltip();
      expect(tooltip.exists()).toBe(true);
      expect(tooltip.text()).toContain('Duplicate');
      expect(tooltip.text()).toContain(description);
    });

    it('does not show tooltip when description is empty', () => {
      createComponent();

      expect(findTooltip().exists()).toBe(false);
    });

    it('avoids duplicate tooltips when description is present', () => {
      createComponent({ description: 'Some description' });

      expect(findTruncate().props('withTooltip')).toBe(false);
    });

    it('shows truncation tooltip when needed and no description is present', () => {
      createComponent();

      expect(findTruncate().props('withTooltip')).toBe(true);
    });
  });
});
