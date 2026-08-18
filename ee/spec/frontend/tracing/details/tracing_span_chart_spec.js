import { GlButton, GlTruncate } from '@gitlab/ui';
import { nextTick } from 'vue';
import TracingSpansChart from 'ee/tracing/details/tracing_spans_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('TracingSpansChart', () => {
  const mockSpans = [
    {
      operation: 'operation-1',
      service: 'service-1',
      span_id: 'span1',
      start_ms: 100,
      duration_ms: 150,
      children: [
        {
          operation: 'operation-3',
          service: 'service-3',
          span_id: 'span3',
          start_ms: 0,
          duration_ms: 100,
          children: [],
        },
      ],
    },
    {
      operation: 'operation-2',
      service: 'service-2',
      span_id: 'span2',
      start_ms: 100,
      duration_ms: 200,
      children: [],
    },
  ];

  const mockProps = {
    spans: mockSpans,
    traceDurationMs: 300,
    serviceToColor: {
      'service-1': 'gl-bg-data-viz-blue-500',
      'service-2': 'gl-bg-data-viz-orange-500',
    },
  };

  let wrapper;

  const getSpanWrapper = (index, depth = 0) =>
    wrapper.findByTestId(`span-wrapper-${depth}-${index}`);

  const getSpan = (index, depth = 0) =>
    getSpanWrapper(index, depth).find('[data-testid="span-inner-container"]');

  const getSpanDetails = (index, depth = 0) =>
    getSpan(index, depth).find('[data-testid="span-details"]');

  const getToggleButton = (index, depth = 0) =>
    getSpanDetails(index, depth).findComponent(GlButton);

  const getSpanDurationValue = (index, depth = 0) =>
    getSpan(index, depth).find('[data-testid="span-duration-value"]');

  const getSpanDurationBar = (index, depth = 0) =>
    getSpan(index, depth).find('[data-testid="span-duration-bar"]');

  const getSpanChildren = (index, depth = 0) =>
    getSpanWrapper(index, depth).findComponent(TracingSpansChart);

  const toggleExpandButton = (index) =>
    getToggleButton(index).vm.$emit('click', { stopPropagation: jest.fn() });

  beforeEach(() => {
    wrapper = shallowMountExtended(TracingSpansChart, {
      propsData: {
        ...mockProps,
      },
    });
  });

  it('renders the correct number of spans', () => {
    expect(wrapper.findAll('[data-testid^="span-wrapper-"]')).toHaveLength(mockProps.spans.length);
  });

  it('renders tracing-details-spans-chart only if span has children', () => {
    const childrenChart = getSpanChildren(0);

    expect(childrenChart.exists()).toBe(true);
    expect(childrenChart.props('depth')).toBe(1);
    expect(childrenChart.props('traceDurationMs')).toBe(mockProps.traceDurationMs);
    expect(childrenChart.props('serviceToColor')).toBe(mockProps.serviceToColor);
    expect(childrenChart.props('spans')).toBe(mockProps.spans[0].children);

    // span with no children
    expect(getSpanChildren(1).isVisible()).toBe(false);
  });

  it('toggle the children spans when clicking the expand button', async () => {
    await toggleExpandButton(0);

    expect(getToggleButton(0).props('icon')).toBe('chevron-right');
    expect(getSpanChildren(0).isVisible()).toBe(false);

    await toggleExpandButton(0);

    expect(getToggleButton(0).props('icon')).toBe('chevron-down');
    expect(getSpanChildren(0).isVisible()).toBe(true);
  });

  it('should stop click event propagation when the toggle button is pressed', async () => {
    const stopPropagation = jest.fn();

    await getToggleButton(0).vm.$emit('click', { stopPropagation });

    expect(stopPropagation).toHaveBeenCalled();
  });

  it('emits span-selected upon selection', async () => {
    await getSpan(0).trigger('click');

    expect(wrapper.emitted('span-selected')).toStrictEqual([[{ spanId: 'span1' }]]);
  });

  it('sets the proper class on the selected span', async () => {
    expect(getSpan(0).classes()).not.toContain('gl-bg-blue-100');

    wrapper.setProps({ selectedSpanId: 'span1' });
    await nextTick();

    expect(getSpan(0).classes()).toContain('gl-bg-blue-100');
  });

  it('reset the expanded state when the spans change', async () => {
    await toggleExpandButton(0);
    expect(getSpanChildren(0).isVisible()).toBe(false);

    await wrapper.setProps({ spans: [...mockSpans] });
    expect(getSpanChildren(0).isVisible()).toBe(true);
  });

  describe('span details', () => {
    it('renders the spans details with left padding based on depth', () => {
      wrapper = shallowMountExtended(TracingSpansChart, {
        propsData: {
          ...mockProps,
          depth: 2,
        },
      });
      expect(getSpanDetails(0, 2).element.style.paddingLeft).toBe('32px');
    });

    it('renders span operation and service name', () => {
      const textContents = getSpanDetails(0).findAllComponents(GlTruncate);
      expect(textContents.at(0).props('text')).toBe('operation-1');
      expect(textContents.at(1).props('text')).toBe('service-1');
    });

    it('renders the expanded button', () => {
      expect(getToggleButton(0).props('icon')).toBe('chevron-down');
    });

    describe('error icon', () => {
      const mountWithError = (hasError) => {
        wrapper = shallowMountExtended(TracingSpansChart, {
          propsData: {
            ...mockProps,
            spans: [
              {
                operation: 'operation-2',
                service: 'service-2',
                span_id: 'span2',
                start_ms: 100,
                duration_ms: 200,
                children: [],
                hasError,
              },
            ],
          },
        });
      };

      const getErrorIcon = () => getSpanDetails(0).find('[data-testid="span-details-error-icon"]');
      it('renders the error icon if the span has errors', () => {
        mountWithError(true);
        expect(getErrorIcon().exists()).toBe(true);
      });

      it('does not render the error icon if the span has no errors', () => {
        mountWithError(false);
        expect(getErrorIcon().exists()).toBe(false);
      });
    });
  });

  describe('span duration', () => {
    it('renders the duration value', () => {
      const durationValue = getSpanDurationValue(0);
      expect(durationValue.text()).toBe('150ms');
      expect(durationValue.element.style.marginLeft).toBe('33%');
    });

    it('renders the duration bar with the proper style', () => {
      const spanDurationBar = getSpanDurationBar(0);
      const barStyle = spanDurationBar.element.style;
      expect(spanDurationBar.classes()).toContain('gl-bg-data-viz-blue-500');
      expect(barStyle.marginLeft).toBe('33%');
      expect(barStyle.width).toBe('50%');
    });

    it.each([
      [{ start_ms: 0, duration_ms: 0.4 }, '0.5%', '0%'],
      [{ start_ms: 0, duration_ms: 110 }, '100%', '0%'],
      [{ start_ms: 80, duration_ms: 40 }, '40%', '60%'],
      [{ start_ms: -10, duration_ms: 40 }, '40%', '0%'],
    ])('caps the layout width and margin', (spanAttrs, expectedWidth, expectedMargin) => {
      wrapper = shallowMountExtended(TracingSpansChart, {
        propsData: {
          serviceToColor: {
            'service-1': 'blue-500',
          },
          traceDurationMs: 100,
          spans: [
            {
              operation: 'operation-1',
              service: 'service-1',
              children: [],
              ...spanAttrs,
            },
          ],
        },
      });

      const parentElement = getSpanDurationBar(0);
      const wrapperEl =
        parentElement.wrapperElement ||
        parentElement?.find('[data-testid="span-duration-bar"]').element;

      const barStyle = wrapperEl.style;
      expect(barStyle.width).toBe(expectedWidth);
      expect(barStyle.marginLeft).toBe(expectedMargin);
    });
  });
});
