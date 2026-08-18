import { TASKS_BY_TYPE_FILTERS } from '../../constants';

export const subjectFilter = TASKS_BY_TYPE_FILTERS.SUBJECT;

export const tasksByTypeData = [
  {
    label: { title: 'in-review' },
    series: [
      ['2023-10-01', 0],
      ['2023-10-02', 0],
      ['2023-10-03', 3],
      ['2023-10-04', 1],
      ['2023-10-05', 0],
      ['2023-10-06', 0],
      ['2023-10-07', 1],
    ],
  },
  {
    label: { title: 'ready' },
    series: [
      ['2023-10-01', 2],
      ['2023-10-02', 1],
      ['2023-10-03', 0],
      ['2023-10-04', 0],
      ['2023-10-05', 5],
      ['2023-10-06', 0],
      ['2023-10-07', 0],
    ],
  },
  {
    label: { title: 'done' },
    series: [
      ['2023-10-01', 1],
      ['2023-10-02', 2],
      ['2023-10-03', 5],
      ['2023-10-04', 0],
      ['2023-10-05', 0],
      ['2023-10-06', 0],
      ['2023-10-07', 1],
    ],
  },
];

const seriesNames = ['in-review', 'ready', 'done'];
export const tasksByTypeChartData = {
  data: [
    {
      name: 'in-review',
      data: [0, 0, 3, 1, 0, 0, 1],
    },
    {
      name: 'ready',
      data: [2, 1, 0, 0, 5, 0, 0],
    },
    {
      name: 'done',
      data: [1, 2, 5, 0, 0, 0, 1],
    },
  ],
  seriesNames,
  groupBy: [
    '2023-10-01',
    '2023-10-02',
    '2023-10-03',
    '2023-10-04',
    '2023-10-05',
    '2023-10-06',
    '2023-10-07',
  ],
};
