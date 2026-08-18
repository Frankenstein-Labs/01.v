import { GlSprintf } from '@gitlab/ui';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MR Widget Security Reports - Summary Highlights', () => {
  let wrapper;

  const createComponent = ({ highlights, showSingleSeverity, capped } = {}) => {
    wrapper = shallowMountExtended(SummaryHighlights, {
      propsData: {
        highlights,
        showSingleSeverity,
        capped,
      },
      stubs: { GlSprintf },
    });
  };

  describe.each`
    severity      | count
    ${'critical'} | ${5022}
    ${'high'}     | ${20}
    ${'other'}    | ${1}
  `('for $severity', ({ severity, count }) => {
    it('emphasizes counts higher than 0', () => {
      createComponent({
        highlights: {
          [severity]: count,
        },
      });

      expect(wrapper.findByTestId(severity).element.tagName).toBe('STRONG');
    });

    it('does not emphasize counts equal to 0', () => {
      createComponent({
        highlights: {
          critical: 1,
          high: 1,
          other: 1,
          [severity]: 0,
        },
      });

      expect(wrapper.findByTestId(severity).element.tagName).toBe('SPAN');
    });
  });

  it("calculate 'others' when other severities are provided", () => {
    const others = { medium: 50, low: 30, unknown: 20 };

    createComponent({
      highlights: {
        critical: 10,
        high: 20,
        ...others,
      },
    });

    expect(wrapper.text()).toContain('100 others');
  });

  it.each`
    severity      | color                       | count
    ${'critical'} | ${'severity-text-critical'} | ${10}
    ${'high'}     | ${'severity-text-high'}     | ${20}
    ${'medium'}   | ${'severity-text-medium'}   | ${50}
    ${'low'}      | ${'severity-text-low'}      | ${30}
    ${'unknown'}  | ${'severity-text-unknown'}  | ${20}
  `(
    "displays a number only when 'showSingleSeverity' property is provided",
    ({ severity, color, count }) => {
      const others = { medium: 50, low: 30, unknown: 20 };

      createComponent({
        showSingleSeverity: severity,
        highlights: {
          critical: 10,
          high: 20,
          ...others,
        },
      });

      expect(wrapper.html()).toContain(color);
      expect(wrapper.text().replace(/\s+/, ' ')).toBe(`${count.toString()} vulnerabilities`);
    },
  );

  it('shows capped results when capped property is true', () => {
    const others = { medium: 50, low: 1001, unknown: 20 };

    createComponent({
      capped: true,
      highlights: {
        critical: 1001,
        high: 20,
        ...others,
      },
    });

    expect(wrapper.text()).toContain('1000+ critical');
    expect(wrapper.text()).toContain('20 high');
    expect(wrapper.text()).toContain('1000+ others');
  });

  it('shows capped results when `other` is specified and capped property is true', () => {
    createComponent({
      capped: true,
      highlights: {
        critical: 1001,
        high: 20,
        other: 1001,
      },
    });

    expect(wrapper.text()).toContain('1000+ critical');
    expect(wrapper.text()).toContain('20 high');
    expect(wrapper.text()).toContain('1000+ others');
  });

  describe('snapshots', () => {
    it('displays all three severities when all are non-zero', () => {
      createComponent({
        highlights: { critical: 10, high: 20, other: 60 },
      });

      expect(wrapper.html()).toMatchSnapshot();
    });

    it('displays all three severities with zero counts muted', () => {
      createComponent({
        highlights: { critical: 21, high: 0, other: 8 },
      });

      expect(wrapper.html()).toMatchSnapshot();
    });

    it('displays "0 vulnerabilities" when all counts are zero', () => {
      createComponent({
        highlights: { critical: 0, high: 0, other: 0 },
      });

      expect(wrapper.html()).toMatchSnapshot();
    });
  });

  describe('rendering', () => {
    it.each([
      {
        description: 'all severity parts are provided',
        highlights: { critical: 4, high: 0, other: 0 },
      },
      {
        description: 'some severity parts are missing',
        highlights: { critical: 4 },
      },
    ])('renders all severity parts with zero fallbacks when $description', ({ highlights }) => {
      createComponent({
        highlights,
      });

      expect(wrapper.findByTestId('critical').exists()).toBe(true);
      expect(wrapper.findByTestId('high').exists()).toBe(true);
      expect(wrapper.findByTestId('other').exists()).toBe(true);
      expect(wrapper.text()).toBe('4 critical, 0 high, and 0 others');
    });

    it('renders "0 vulnerabilities" when all counts are zero', () => {
      createComponent({
        highlights: { critical: 0, high: 0, other: 0 },
      });

      expect(wrapper.text()).toBe('0 vulnerabilities');
    });
  });
});
