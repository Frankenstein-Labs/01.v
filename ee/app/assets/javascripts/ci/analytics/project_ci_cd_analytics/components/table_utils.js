import { formatNumber } from '~/locale';
import { formatPipelineDuration } from '~/ci/analytics/utils';

export const numericField = () => ({
  thClass: 'gl-text-right',
  tdClass: 'gl-text-right',
  thAlignRight: true,
  sortable: true,
  formatter: (n) => {
    // Render '-' for nullish values
    if (n === null || n === undefined) return '-';

    return formatNumber(n, {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });
  },
});

export const durationField = () => ({
  ...numericField(),
  formatter: formatPipelineDuration,
});
