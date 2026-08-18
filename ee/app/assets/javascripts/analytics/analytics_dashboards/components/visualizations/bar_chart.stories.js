import { stackedPresentationOptions } from '@gitlab/ui/src/utils/constants';
import { CHART_TOOLTIP_TITLE_FORMATTERS, UNITS } from '~/analytics/shared/constants';
import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import BarChart from './bar_chart.vue';

export default {
  component: BarChart,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/bar_chart',
};

const Template = (args, { argTypes }) => ({
  components: { BarChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
  <div class="gl-h-48">
    <bar-chart :data="data" :options="options" />
  </div>`,
});

const WithDashboard = (args, { argTypes }) => ({
  components: { BarChart, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <bar-chart :data="data" :options="options" />
      </dashboard-layout>`,
});

const SuggestionsViewed = [
  [1240, 'JavaScript'],
  [980, 'Python'],
  [760, 'Java'],
  [650, 'TypeScript'],
  [420, 'C++'],
  [340, 'Go'],
  [280, 'Rust'],
  [220, 'Swift'],
  [160, 'Kotlin'],
];

const SuggestionsAccepted = [
  [875, 'JavaScript'],
  [720, 'Python'],
  [640, 'Java'],
  [580, 'TypeScript'],
  [490, 'C++'],
  [385, 'Go'],
  [320, 'Rust'],
  [275, 'Swift'],
  [195, 'Kotlin'],
];

const multiSeriesData = {
  'Suggestions viewed': SuggestionsViewed,
  'Suggestions accepted': SuggestionsAccepted,
};

const defaultArgs = {
  data: {
    'Suggestions viewed': SuggestionsViewed,
  },
  options: {
    xAxis: { type: 'value', name: 'Suggestions' },
    yAxis: { type: 'category', name: 'Language' },
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const Stacked = Template.bind({});
Stacked.args = {
  data: multiSeriesData,
  options: {
    ...defaultArgs.options,
    presentation: stackedPresentationOptions.stacked,
  },
};

export const Tiled = Template.bind({});
Tiled.args = {
  data: multiSeriesData,
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

export const WithContextualTooltipData = Template.bind({});
WithContextualTooltipData.args = {
  data: {
    ...defaultArgs.data,
    contextualData: {
      JavaScript: { acceptedCount: 875, rejectedCount: 365 },
      Python: { acceptedCount: 720, rejectedCount: 260 },
      Java: { acceptedCount: 640, rejectedCount: 120 },
      TypeScript: { acceptedCount: 580, rejectedCount: 70 },
      'C++': { acceptedCount: 490, rejectedCount: 130 },
      Go: { acceptedCount: 385, rejectedCount: 55 },
      Rust: { acceptedCount: 320, rejectedCount: 40 },
      Swift: { acceptedCount: 275, rejectedCount: 55 },
      Kotlin: { acceptedCount: 195, rejectedCount: 35 },
    },
  },
  options: {
    ...defaultArgs.options,
    chartTooltip: {
      titleFormatter: CHART_TOOLTIP_TITLE_FORMATTERS.VALUE_ONLY,
      valueUnit: UNITS.COUNT,
      contextualData: [
        {
          key: 'acceptedCount',
          label: 'Accepted',
          unit: UNITS.COUNT,
        },
        {
          key: 'rejectedCount',
          label: 'Rejected',
          unit: UNITS.COUNT,
        },
      ],
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
