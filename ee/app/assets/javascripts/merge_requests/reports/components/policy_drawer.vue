<script>
import { GlDrawer, GlSprintf, GlLink } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import ScanResultDetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import InfoRow from 'ee/security_orchestration/components/policy_drawer/info_row.vue';
import getPipelineQuery from '../queries/get_pipeline.query.graphql';

export default {
  name: 'PolicyDrawer',
  components: {
    GlDrawer,
    GlSprintf,
    GlLink,
    TimeAgoTooltip,
    InfoRow,
    ScanResultDetailsDrawer,
  },
  inject: ['projectPath'],
  props: {
    open: {
      type: Boolean,
      required: true,
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    comparisonPipelines: {
      type: Object,
      required: false,
      default: null,
    },
    targetBranch: {
      type: String,
      required: true,
    },
    sourceBranch: {
      type: String,
      required: true,
    },
    pipeline: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['close'],
  data() {
    return {
      pipelines: null,
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
  },
  watch: {
    comparisonPipelines: {
      handler(newVal) {
        if (newVal) {
          this.fetchComparisonPipelines();
        }
      },
      immediate: true,
    },
  },
  methods: {
    closeDrawer() {
      this.pipelines = null;

      this.$emit('close');
    },
    async fetchComparisonPipelines() {
      this.pipelines = await Promise.all([
        await Promise.all(
          this.comparisonPipelines.source.map((id) =>
            this.$apollo
              .query({
                query: getPipelineQuery,
                variables: {
                  projectPath: this.projectPath,
                  id,
                },
                context: {
                  batchKey: 'SecurityPolicyComparisonPipeline',
                },
              })
              .then(({ data }) => data.project?.pipeline),
          ),
        ),
        await Promise.all(
          this.comparisonPipelines.target.map((id) =>
            this.$apollo
              .query({
                query: getPipelineQuery,
                variables: {
                  projectPath: this.projectPath,
                  id,
                },
                context: {
                  batchKey: 'SecurityPolicyComparisonPipeline',
                },
              })
              .then(({ data }) => data.project?.pipeline),
          ),
        ),
      ]);
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="open"
    @close="closeDrawer"
  >
    <template #title>
      <h4 class="gl-my-0">{{ __('Security policy') }}</h4>
    </template>
    <div v-if="policy" data-testid="security-policy">
      <p v-if="pipeline" class="gl-mb-3 gl-text-sm gl-text-subtle" data-testid="security-pipeline">
        <gl-sprintf :message="__('%{timeago} in pipeline %{pipeline}')">
          <template #timeago>
            <time-ago-tooltip :time="pipeline.updatedAt" />
          </template>
          <template #pipeline>
            <gl-link :href="pipeline.path">#{{ pipeline.iid }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <h5 class="h4 gl-mb-0 gl-mt-0">{{ policy.name }}</h5>
      <scan-result-details-drawer :policy="policy" :show-policy-scope="false" :show-status="false">
        <template v-if="comparisonPipelines && pipelines" #additional-details>
          <info-row :label="__('Comparison pipelines')">
            <ul class="gl-pl-6">
              <li v-if="pipelines[0]" class="gl-mb-2" data-testid="target-branch-pipeline">
                <gl-sprintf :message="__('Target branch (%{branch}): %{pipelines}')">
                  <template #branch>
                    <code>{{ targetBranch }}</code>
                  </template>
                  <template #pipelines>
                    <gl-link
                      v-for="targetBranchPipeline in pipelines[0]"
                      :key="targetBranchPipeline.iid"
                      :href="targetBranchPipeline.path"
                    >
                      #{{ targetBranchPipeline.iid }}
                    </gl-link>
                  </template>
                </gl-sprintf>
              </li>
              <li v-if="pipelines[1]" data-testid="source-branch-pipeline">
                <gl-sprintf :message="__('Source branch (%{branch}): %{pipelines}')">
                  <template #branch>
                    <code>{{ sourceBranch }}</code>
                  </template>
                  <template #pipelines>
                    <gl-link
                      v-for="sourceBranchPipeline in pipelines[1]"
                      :key="sourceBranchPipeline.iid"
                      :href="sourceBranchPipeline.path"
                    >
                      #{{ sourceBranchPipeline.iid }}
                    </gl-link>
                  </template>
                </gl-sprintf>
              </li>
            </ul>
          </info-row>
        </template>
      </scan-result-details-drawer>
    </div>
  </gl-drawer>
</template>
