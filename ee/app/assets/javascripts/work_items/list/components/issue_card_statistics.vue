<script>
import IssueCardStatistics from '~/work_items/list/components/issue_card_statistics.vue';
import BlockingIssuesCount from 'ee/issues/components/blocking_issues_count.vue';

export default {
  name: 'IssueCardStatisticsEE',
  components: {
    BlockingIssuesCount,
    IssueCardStatistics,
  },
  props: {
    issue: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <issue-card-statistics :issue="issue">
    <blocking-issues-count
      class="gl-hidden @sm/panel:gl-inline-block"
      :blocking-issues-count="issue.blockingCount"
      is-list-item
      data-testid="blocking-issues"
    />
  </issue-card-statistics>
</template>
