import { shallowMount } from '@vue/test-utils';
import ActivityConnectorSvg from 'ee/ai/duo_agents_platform/components/common/activity_connector_svg.vue';

describe('ActivityConnectorSvg', () => {
  let wrapper;
  let target1;
  let target2;

  const createMockElement = (boundingRect) => {
    const element = document.createElement('div');
    jest.spyOn(element, 'getBoundingClientRect').mockReturnValue(boundingRect);
    return element;
  };

  const createWrapper = (props = {}) => {
    return shallowMount(ActivityConnectorSvg, {
      propsData: {
        targets: [target1, target2],
        ...props,
      },
    });
  };

  const findSvg = () => wrapper.find('svg');
  const findLine = () => wrapper.find('line');

  beforeEach(() => {
    target1 = createMockElement({
      left: 10,
      top: 20,
      width: 20,
      height: 20,
    });

    target2 = createMockElement({
      left: 50,
      top: 100,
      width: 30,
      height: 25,
    });
  });

  describe('when has 2 targets (start and end point)', () => {
    beforeEach(() => {
      wrapper = createWrapper({ targets: [target1, target2] });

      jest.advanceTimersByTime(1000);
    });

    it('renders SVG element in the DOM', () => {
      expect(findSvg().exists()).toBe(true);
    });

    it('renders a single line element', () => {
      expect(findLine().exists()).toBe(true);
    });

    it('applies correct line attributes', () => {
      const line = findLine();

      expect(line.attributes('x1')).toBe('20');
      expect(line.attributes('y1')).toBe('20');
      expect(line.attributes('x2')).toBe('65');
      expect(line.attributes('y2')).toBe('100');
    });
  });

  describe('when targets are not available', () => {
    beforeEach(() => {
      wrapper = createWrapper({ targets: [] });
      jest.advanceTimersByTime(1000);
    });

    it('returns default coordinates', () => {
      const line = findLine();

      expect(line.attributes('x1')).toBe('0');
      expect(line.attributes('y1')).toBe('0');
      expect(line.attributes('x2')).toBe('0');
      expect(line.attributes('y2')).toBe('0');
    });
  });
});
