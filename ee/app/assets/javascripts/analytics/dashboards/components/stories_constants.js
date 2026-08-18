/* eslint-disable @gitlab/require-i18n-strings */
import { TREND_STYLE_DESC } from '../constants';

export const comparisonTableData = [
  {
    metric: {
      identifier: 'deployment_frequency',
      value: 'Deployment frequency',
    },
    thisMonth: {
      value: '13.1/d',
      change: -0.45351043643263755,
    },
    lastMonth: {
      value: '23.9/d',
      change: -0.09144893111638955,
    },
    twoMonthsAgo: {
      value: '26.3/d',
      change: 0.4436946902654867,
    },
    chart: {
      // eslint-disable-next-line @gitlab/no-hardcoded-urls -- False positive, not a URL
      tooltipLabel: '/day',
      data: [
        ['Mar 30 - Apr 30', 0],
        ['Apr 30 - May 30', 0],
        ['May 30 - Jun 30', 17.7],
        ['Jun 30 - Jul 30', 26.2],
        ['Jul 30 - Aug 30', 24.3],
        ['Aug 30 - Sep 30', 14],
      ],
    },
  },
  {
    trendStyle: TREND_STYLE_DESC,
    metric: {
      identifier: 'change_failure_rate',
      value: 'Change failure rate',
    },
    thisMonth: {
      value: '9.1%',
      change: 0.08333333333333325,
    },
    lastMonth: {
      value: '8.4%',
      change: 0.3125,
    },
    twoMonthsAgo: {
      value: '6.4%',
      change: -0.22891566265060243,
    },
    chart: {
      tooltipLabel: '%',
      data: [
        ['Mar 30 - Apr 30', 0],
        ['Apr 30 - May 30', 0],
        ['May 30 - Jun 30', 8.3],
        ['Jun 30 - Jul 30', 6.7],
        ['Jul 30 - Aug 30', 8.1],
        ['Aug 30 - Sep 30', 8.9],
      ],
    },
  },
  {
    metric: {
      identifier: 'issues',
      value: 'Issues created',
    },
    thisMonth: {
      value: 19,
      change: 1.7142857142857142,
    },
    lastMonth: {
      value: 7,
      change: 0,
    },
    twoMonthsAgo: {
      value: '-',
      change: 0,
    },
    chart: {
      data: [
        ['Mar 30 - Apr 30', null],
        ['Apr 30 - May 30', null],
        ['May 30 - Jun 30', null],
        ['Jun 30 - Jul 30', null],
        ['Jul 30 - Aug 30', 3],
        ['Aug 30 - Sep 30', 23],
      ],
    },
  },
  {
    metric: {
      identifier: 'deploys',
      value: 'Deploys',
    },
    thisMonth: {
      value: 405,
      change: -0.47058823529411764,
    },
    lastMonth: {
      value: 765,
      change: -0.09144893111638955,
    },
    twoMonthsAgo: {
      value: 842,
      change: 0.4902654867256637,
    },
    chart: {
      data: [
        ['Mar 30 - Apr 30', null],
        ['Apr 30 - May 30', null],
        ['May 30 - Jun 30', 565],
        ['Jun 30 - Jul 30', 811],
        ['Jul 30 - Aug 30', 776],
        ['Aug 30 - Sep 30', 449],
      ],
    },
  },
];
