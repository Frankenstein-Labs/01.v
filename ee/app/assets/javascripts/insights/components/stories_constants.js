/* eslint-disable @gitlab/require-i18n-strings */

export const defaultArguments = {
  loaded: true,
  type: 'bar',
  title: 'Insights chart',
  groupBy: 'month',
  data: {
    xAxisTitle: 'Months',
    yAxisTitle: 'Issues',
    labels: ['April 2024', 'May 2024', 'June 2024'],
    datasets: [
      {
        name: 'all',
        data: [
          ['April 2024', 25],
          ['May 2024', 0],
          ['June 2024', 0],
        ],
      },
    ],
    seriesNames: [],
  },
  dataSourceType: 'issue',
};

export const labelledData = {
  ...defaultArguments,
  collectionLabels: ['S::1', 'S::2', 'S::3', 'S::4'],
  data: {
    xAxisTitle: 'Months',
    yAxisTitle: 'Issues',
    labels: ['April 2024', 'May 2024', 'June 2024'],
    datasets: [
      { name: 'S::1', data: [20, 5, 0] },
      { name: 'S::2', data: [2, 3, 9] },
      { name: 'S::3', data: [1, 12, 0] },
      { name: 'S::4', data: [0, 3, 4] },
      { name: 'undefined', data: [0, 0, 0] },
    ],
    seriesNames: [],
  },
};

export const noData = {
  ...defaultArguments,
  data: {
    xAxisTitle: 'Months',
    yAxisTitle: 'Issues',
    labels: ['April 2024', 'May 2024', 'June 2024'],
    datasets: [{ name: 'all', data: [] }],
    seriesNames: [],
  },
};
