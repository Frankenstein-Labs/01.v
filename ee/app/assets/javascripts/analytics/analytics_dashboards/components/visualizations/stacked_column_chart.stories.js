import { stackedPresentationOptions } from '@gitlab/ui/src/utils/constants';
import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import { CHART_TOOLTIP_TITLE_FORMATTERS, UNITS } from '~/analytics/shared/constants';
import StackedColumnChart from './stacked_column_chart.vue';

export default {
  component: StackedColumnChart,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/stacked_column_chart',
};

const mockBarsData = [
  {
    name: 'Production',
    data: [4500, 5200, 4800, 6100, 5800, 6500, 7000, 6800, 7200, 7500, 7800, 8200],
  },
  {
    name: 'Staging',
    data: [7800, 8500, 9200, 8800, 9500, 10200, 9800, 10500, 11000, 10800, 11500, 12000],
  },
  {
    name: 'Development',
    data: [1200, 1350, 1280, 1420, 1380, 1550, 1480, 1600, 1650, 1700, 1680, 1750],
  },
];

const mockGroupBy = [
  'Jan 2025',
  'Feb 2025',
  'Mar 2025',
  'Apr 2025',
  'May 2025',
  'Jun 2025',
  'Jul 2025',
  'Aug 2025',
  'Sep 2025',
  'Oct 2025',
  'Nov 2025',
  'Dec 2025',
];

const defaultArgs = {
  data: {
    bars: mockBarsData,
    groupBy: mockGroupBy,
  },
  options: {
    xAxis: { type: 'category', name: 'Month' },
    yAxis: { type: 'value', name: 'Deployments' },
  },
};

const Template = (args, { argTypes }) => ({
  components: { StackedColumnChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <stacked-column-chart :data="data" :options="options" />
  </div>`,
});

const WithDashboard = (args, { argTypes }) => ({
  components: { StackedColumnChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <stacked-column-chart :data="data" :options="options" />
      </dashboard-layout>`,
});

export const Default = Template.bind({});
Default.args = defaultArgs;

export const Tiled = Template.bind({});
Tiled.args = {
  data: defaultArgs.data,
  options: {
    ...defaultArgs.options,
    presentation: stackedPresentationOptions.tiled,
  },
};

export const WithCustomTooltip = Template.bind({});
WithCustomTooltip.args = {
  data: defaultArgs.data,
  options: {
    ...defaultArgs.options,
    chartTooltip: {
      titleFormatter: CHART_TOOLTIP_TITLE_FORMATTERS.VALUE_ONLY,
      valueUnit: UNITS.COUNT,
    },
  },
};

export const InDashboardPanel = WithDashboard.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Panel #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 12,
        height: 3,
      },
    },
  ],
};
