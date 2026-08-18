import { GlTable, GlLabel } from '@gitlab/ui';
import MetricsTable from 'ee/metrics/list/metrics_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { ingestedAtTimeAgo } from 'ee/metrics/utils';
import { mockMetricsListResponse } from '../mock_data';

jest.mock('ee/metrics/utils');

describe('MetricsTable', () => {
  let wrapper;

  const mockMetrics = mockMetricsListResponse.metrics;

  const mountComponent = ({ metrics = mockMetrics } = {}) => {
    wrapper = mountExtended(MetricsTable, {
      propsData: {
        metrics,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const getRows = () => wrapper.findComponent(GlTable).findAll(`[data-testid="metric-row"]`);
  const getRow = (idx) => getRows().at(idx);

  const clickRow = (idx) => getRow(idx).trigger('click');

  it('renders metrics as table', () => {
    ingestedAtTimeAgo.mockReturnValue('3 days ago');

    mountComponent();

    const rows = getRows();
    expect(rows).toHaveLength(mockMetrics.length);
    mockMetrics.forEach((m, i) => {
      const row = getRows().at(i);
      expect(row.find(`[data-testid="metric-name"]`).text()).toBe(m.name);
      expect(row.find(`[data-testid="metric-description"]`).text()).toBe(m.description);
      expect(row.find(`[data-testid="metric-type"]`).text()).toBe(m.type);
      expect(row.find(`[data-testid="metric-last-ingested"]`).text()).toBe('3 days ago');
    });
  });

  describe('label', () => {
    it.each([
      ['Sum', '#6699cc'],
      ['Gauge', '#cd5b45'],
      ['Histogram', '#009966'],
      ['ExponentialHistogram', '#ed9121'],
      ['unknown', '#808080'],
    ])('sets the proper label when metric type is %s', (type, expectedColor) => {
      mountComponent({
        metrics: [{ name: 'a metric', description: 'a description', type, attributes: [] }],
      });
      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe(expectedColor);
      expect(label.props('title')).toBe(type);
    });
  });

  describe('attributes', () => {
    it.each([
      [['1', '2', '3', '4', '5'], '1, 2, 3, 4, 5', undefined],
      [['1', '2', '3', '4', '5', '6', '7'], '1, 2, 3, 4, 5 +2 more', '6, 7'],
      [[], '', undefined],
    ])(
      'sets the proper attributes field with tooltip',
      (attributes, expectedAttributes, expectedTooltip) => {
        mountComponent({
          metrics: [{ name: 'a metric', description: 'a description', type: 'Sum', attributes }],
        });

        expect(wrapper.find(`[data-testid="metric-attributes"]`).text()).toMatchInterpolatedText(
          expectedAttributes,
        );
        const tooltipWrapper = wrapper.find(`[data-testid="metric-attributes-tooltip"]`);
        if (!expectedTooltip) {
          expect(tooltipWrapper.exists()).toBe(false);
        } else {
          const tooltip = getBinding(tooltipWrapper.element, 'gl-tooltip');
          expect(tooltip).toBeDefined();
          expect(tooltip.value).toBe(expectedTooltip);
        }
      },
    );
  });

  it('emits metric-clicked on row-clicked', async () => {
    mountComponent();

    await clickRow(0);

    expect(wrapper.emitted('metric-clicked')[0]).toEqual([
      { metricId: mockMetrics[0].name, clickEvent: expect.any(MouseEvent) },
    ]);
  });
});
