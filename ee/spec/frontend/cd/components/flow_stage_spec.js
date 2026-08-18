import { GlAnimatedChevronRightDownIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FlowStage from 'ee/cd/components/flow_stage.vue';

describe('FlowStage', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FlowStage, {
      propsData: {
        title: 'preprod',
        state: 'SUCCESS',
        environmentsCount: 1,
        steps: [{ state: 'SUCCESS' }, { state: 'SUCCESS' }],
        ...props,
      },
      slots: { default: '<p data-testid="stage-content">steps</p>' },
    });
  };

  const findHeader = () => wrapper.findByTestId('stage-header');
  const findTitle = () => wrapper.findByTestId('stage-title');
  const findStatusDot = () => wrapper.findByTestId('stage-status-dot');
  const findBody = () => wrapper.findByTestId('stage-body');
  const findSummary = () => wrapper.findByTestId('stage-summary');
  const findStepDots = () => wrapper.findAllByTestId('step-dot');
  const findStepCount = () => wrapper.findByTestId('step-count');
  const findChevron = () => wrapper.findComponent(GlAnimatedChevronRightDownIcon);

  describe('header', () => {
    it('renders the title', () => {
      createComponent({ title: 'production' });

      expect(findTitle().text()).toBe('production');
    });

    it.each([
      [1, '1 env'],
      [2, '2 envs'],
    ])('pluralizes %i environments as "%s"', (environmentsCount, expected) => {
      createComponent({ environmentsCount });

      expect(wrapper.text()).toContain(expected);
    });

    it('omits the environment count when there are none', () => {
      createComponent({ environmentsCount: 0 });

      expect(wrapper.text()).not.toContain('env');
    });

    it.each([
      ['PENDING', 'gl-bg-gray-400'],
      ['RUNNING', 'gl-bg-blue-500'],
      ['SUCCESS', 'gl-bg-green-500'],
      ['FAILED', 'gl-bg-red-500'],
    ])('colors the status dot for %s', (state, expected) => {
      createComponent({ state });

      expect(findStatusDot().classes()).toContain(expected);
    });

    it('describes the state in a tooltip', () => {
      createComponent({ state: 'FAILED' });

      expect(findStatusDot().attributes('title')).toBe('Failed');
    });
  });

  describe('in progress', () => {
    beforeEach(() => {
      createComponent({ state: 'RUNNING' });
    });

    it('tints the title', () => {
      expect(findTitle().classes()).toContain('gl-text-status-info');
    });

    it('tints the container border', () => {
      expect(wrapper.classes()).toContain('gl-border-feedback-info');
    });

    it('pulses the status dot', () => {
      expect(findStatusDot().classes()).toContain('flow-stage-status-pulse');
    });
  });

  describe.each([['PENDING'], ['SUCCESS'], ['FAILED']])('when %s', (state) => {
    beforeEach(() => {
      createComponent({ state });
    });

    it('leaves the title in the default color', () => {
      expect(findTitle().classes()).toContain('gl-text-strong');
    });

    it('leaves the border neutral', () => {
      expect(wrapper.classes()).toContain('gl-border-subtle');
    });
  });

  describe('when collapsed', () => {
    beforeEach(() => {
      createComponent({
        expanded: false,
        steps: [{ state: 'SUCCESS' }, { state: 'FAILED' }, { state: 'PENDING' }],
      });
    });

    it('renders summary', () => {
      expect(findBody().exists()).toBe(false);
      expect(findSummary().exists()).toBe(true);
    });

    it('gives each dot the color and tooltip of its own step state', () => {
      expect(
        findStepDots().wrappers.map((dot) => [
          dot.classes().find((className) => className.startsWith('gl-bg-')),
          dot.attributes('title'),
        ]),
      ).toEqual([
        ['gl-bg-green-500', 'Succeeded'],
        ['gl-bg-red-500', 'Failed'],
        ['gl-bg-gray-400', 'Pending'],
      ]);
    });
  });

  describe.each([
    [1, '1 step'],
    [2, '2 steps'],
  ])('when collapsed with %i steps', (count, expected) => {
    it(`counts them as "${expected}"`, () => {
      createComponent({ expanded: false, steps: Array(count).fill({ state: 'SUCCESS' }) });

      expect(findStepCount().text()).toBe(expected);
    });
  });

  describe('when the stage itself is in a state the view does not know', () => {
    beforeEach(() => {
      createComponent({ state: 'BRAND_NEW' });
    });

    it('falls back to a neutral dot instead of rendering no colour at all', () => {
      expect(findStatusDot().classes()).toContain('gl-bg-gray-400');
    });

    it('describes it as unknown', () => {
      expect(findStatusDot().attributes('title')).toBe('Unknown');
    });
  });

  describe('when collapsed with a step state the view does not know', () => {
    beforeEach(() => {
      createComponent({ expanded: false, steps: [{ state: 'nonsense' }] });
    });

    it('describes it as unknown', () => {
      expect(findStepDots().at(0).attributes('title')).toBe('Unknown');
    });

    it('renders a dot for it', () => {
      expect(findStepDots()).toHaveLength(1);
    });
  });

  describe('when expanded', () => {
    beforeEach(() => {
      createComponent({ expanded: true });
    });

    it('renders the slot instead of the summary', () => {
      expect(wrapper.findByTestId('stage-content').exists()).toBe(true);
      expect(findSummary().exists()).toBe(false);
    });
  });

  describe('toggling', () => {
    it('emits toggle when the header is clicked, leaving the decision to the parent', async () => {
      createComponent({ expanded: false });

      await findHeader().trigger('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
      expect(findBody().exists()).toBe(false);
    });

    it.each([
      [false, 'false'],
      [true, 'true'],
    ])('reports aria-expanded=%s to assistive technology', (expanded, expected) => {
      createComponent({ expanded });

      expect(findHeader().attributes('aria-expanded')).toBe(expected);
    });

    it('turns the chevron with the expanded state', () => {
      createComponent({ expanded: true });

      expect(findChevron().props('isOn')).toBe(true);
    });
  });

  describe('connector anchor', () => {
    it('exposes the node id on the container the connectors measure', () => {
      createComponent({ nodeId: 'item-2' });

      expect(wrapper.attributes('data-flow-node')).toBe('item-2');
    });
  });
});
