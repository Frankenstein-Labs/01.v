import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SegmentedBar from 'ee/security_inventory/components/segmented_bar.vue';

describe('SegmentedBar', () => {
  let wrapper;

  const findAllSegments = () => wrapper.findAllByTestId('bar-segment');
  const findSegmentAt = (i) => findAllSegments().at(i);

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(SegmentedBar, { propsData });
  };

  describe('with no segments', () => {
    it('renders a single full-width neutral bar', () => {
      createComponent();

      const segmentClasses = findSegmentAt(0).classes();

      expect(findAllSegments()).toHaveLength(1);
      expect(segmentClasses).toContain('gl-bg-neutral-200');
      expect(segmentClasses).toContain('gl-w-full');
    });
  });

  describe('with segments', () => {
    it('renders proportional segments adding up to full width, applies classes', () => {
      createComponent({
        segments: [
          { count: 100, class: 'class-1' },
          { count: 60, class: 'class-2' },
          { count: 40, class: 'class-3' },
        ],
      });

      expect(findAllSegments()).toHaveLength(3);

      expect(findSegmentAt(0).attributes('style')).toBe('width: 50%;');
      expect(findSegmentAt(1).attributes('style')).toBe('width: 30%;');
      expect(findSegmentAt(2).attributes('style')).toBe('width: 20%;');

      expect(findSegmentAt(0).classes()).toContain('class-1');
      expect(findSegmentAt(1).classes()).toContain('class-2');
      expect(findSegmentAt(2).classes()).toContain('class-3');
    });
  });
});
