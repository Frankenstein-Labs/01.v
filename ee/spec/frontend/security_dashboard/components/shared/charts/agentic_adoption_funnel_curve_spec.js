import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgenticAdoptionFunnelCurve from 'ee/security_dashboard/components/shared/charts/agentic_adoption_funnel_curve.vue';

describe('AgenticAdoptionFunnelCurve', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AgenticAdoptionFunnelCurve, {
      propsData: props,
    });
  };

  const findChart = () => wrapper.findByTestId('funnel-empty-state-chart');
  const findTopSpacer = () => wrapper.findByTestId('funnel-curve-top-spacer');
  const findPaths = () => findChart().findAll('path');
  const findAreaPath = () => findPaths().at(0);
  const findLinePath = () => findPaths().at(1);

  // The viewBox is a normalized 1×1 square, with y = 1 - ratio.
  const yFor = (ratio) => 1 - ratio;

  it('renders an area path and a line path', () => {
    createComponent();

    expect(findPaths()).toHaveLength(2);
  });

  // Keep in sync with the stage-header row in agentic_adoption_funnel_chart.vue
  // (asserted in its spec) so the curve stays aligned with the chart columns.
  it('offsets the curve by the stage-header row height', () => {
    createComponent();

    expect(findTopSpacer().classes()).toContain('gl-basis-13');
  });

  it('draws a dropping curve from startRatio to endRatio', () => {
    createComponent({ startRatio: 1, endRatio: 0.4 });

    const startY = yFor(1);
    const endY = yFor(0.4);

    expect(findLinePath().attributes('d')).toBe(
      `M0,${startY} C0.5,${startY} 0.5,${endY} 1,${endY}`,
    );
    expect(findAreaPath().attributes('d')).toBe(
      `M0,${startY} C0.5,${startY} 0.5,${endY} 1,${endY} L1,1 L0,1 Z`,
    );
  });

  it('draws a straight line when endRatio is omitted (defaults to startRatio)', () => {
    createComponent({ startRatio: 0.7 });

    const y = yFor(0.7);

    expect(findLinePath().attributes('d')).toBe(`M0,${y} C0.5,${y} 0.5,${y} 1,${y}`);
  });

  it('clamps ratio values to the 0–1 range', () => {
    createComponent({ startRatio: 2, endRatio: -1 });

    const startY = yFor(1);
    const endY = yFor(0);

    expect(findLinePath().attributes('d')).toBe(
      `M0,${startY} C0.5,${startY} 0.5,${endY} 1,${endY}`,
    );
  });
});
