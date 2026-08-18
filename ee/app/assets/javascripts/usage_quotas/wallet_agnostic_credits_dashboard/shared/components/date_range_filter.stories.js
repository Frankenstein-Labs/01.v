import { CUSTOM, LAST_7_DAYS, LAST_30_DAYS, LAST_MONTH, THIS_MONTH } from './constants';
import DateRangeFilter from './date_range_filter.vue';

const DATE_RANGE_OPTIONS = [THIS_MONTH, LAST_MONTH, LAST_7_DAYS, LAST_30_DAYS, CUSTOM];

const meta = {
  title: 'ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/date_range_filter',
  component: DateRangeFilter,
};

export default meta;

const createTemplate = (value) => {
  return (args, { argTypes }) => ({
    components: { DateRangeFilter },
    props: Object.keys(argTypes),
    data() {
      return { dateRange: value };
    },
    template: `
      <date-range-filter
        v-model="dateRange"
        :options="options"
        :custom-date-range-limit="customDateRangeLimit"
      />
    `,
  });
};

export const Default = {
  render: createTemplate({
    value: THIS_MONTH.value,
    startDate: THIS_MONTH.startDate,
    endDate: THIS_MONTH.endDate,
  }),
  args: {
    options: DATE_RANGE_OPTIONS,
    customDateRangeLimit: 0,
  },
};

export const LastMonth = {
  render: createTemplate({
    value: LAST_MONTH.value,
    startDate: LAST_MONTH.startDate,
    endDate: LAST_MONTH.endDate,
  }),
  args: {
    options: DATE_RANGE_OPTIONS,
    customDateRangeLimit: 0,
  },
};

export const CustomWithDates = {
  render: createTemplate({
    value: CUSTOM.value,
    startDate: '2026-01-01',
    endDate: '2026-01-31',
  }),
  args: {
    options: DATE_RANGE_OPTIONS,
    customDateRangeLimit: 0,
  },
};

export const CustomEmpty = {
  render: createTemplate({
    value: CUSTOM.value,
    startDate: null,
    endDate: null,
  }),
  args: {
    options: DATE_RANGE_OPTIONS,
    customDateRangeLimit: 0,
  },
};

// NOTE: For unknown reason, the custom date range limit doesn't work on this story.
// See https://gitlab.com/gitlab-org/gitlab/-/work_items/598930
export const WithDateRangeLimit = {
  render: createTemplate({
    value: CUSTOM.value,
    startDate: '2026-03-01',
    endDate: '2026-03-15',
  }),
  args: {
    options: DATE_RANGE_OPTIONS,
    customDateRangeLimit: 30,
  },
};
