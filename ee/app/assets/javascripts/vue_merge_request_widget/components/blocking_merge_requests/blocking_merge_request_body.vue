<script>
import { GlIcon } from '@gitlab/ui';
import { n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import RelatedIssuableItem from '~/issuable/components/related_issuable_item.vue';
import { STATUS_MERGED } from '~/issues/constants';

export default {
  name: 'BlockingMergeRequestsBody',
  components: { RelatedIssuableItem, GlIcon },
  props: {
    issue: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hiddenBlockingMRsText() {
      return n__(
        "%d merge request that you don't have access to.",
        "%d merge requests that you don't have access to.",
        this.issue.hiddenCount,
      );
    },
    isMerged() {
      return this.issue.state === STATUS_MERGED;
    },
    mergeRequestId() {
      return getIdFromGraphQLId(this.issue.id);
    },
  },
};
</script>

<template>
  <div v-if="issue.hiddenCount" class="gl-flex gl-items-center !gl-p-5">
    <gl-icon class="gl-mr-3" name="eye-slash" />
    {{ hiddenBlockingMRsText }}
  </div>
  <related-issuable-item
    v-else
    :id-key="mergeRequestId"
    :display-reference="issue.reference"
    :title="issue.title"
    :milestone="issue.milestone"
    :assignees="issue.assignees.nodes"
    :created-at="issue.createdAt"
    :closed-at="issue.closedAt"
    :merged-at="issue.mergedAt"
    :path="issue.webUrl"
    :state="issue.state"
    :is-merge-request="true"
    :pipeline-status="issue.headPipeline && issue.headPipeline.detailedStatus"
    path-id-separator="!"
    :class="{ 'mr-merged': isMerged }"
    :grey-link-when-merged="true"
    class="gl-mx-1"
  />
</template>
