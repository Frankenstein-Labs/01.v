<script>
import { GlCard, GlTableLite, GlIcon, GlBadge, GlSprintf, GlLink, GlAvatar } from '@gitlab/ui';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { SHORT_DATE_FORMAT_WITH_TIME } from '~/vue_shared/constants';
import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import UserDate from '~/vue_shared/components/user_date.vue';
import { projectPagesPath, projectJobPath } from '~/lib/utils/path_helpers/project';
import { s__, sprintf } from '~/locale';
import DeleteDeployment from 'ee/usage_quotas/pages/components/delete_deployment.vue';

export default {
  name: 'ProjectView',
  components: {
    DeleteDeployment,
    UserDate,
    NumberToHumanSize,
    GlCard,
    GlTableLite,
    GlBadge,
    GlIcon,
    GlSprintf,
    GlLink,
    GlAvatar,
  },
  inject: ['viewType'],
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  static: {
    PROJECT_VIEW_TYPE,
    SHORT_DATE_FORMAT_WITH_TIME,
  },
  i18n: {
    deleteError: s__(
      'Pages|An error occurred while deleting the deployment. Please check your connection and try again.',
    ),
    restoreError: s__(
      'Pages|Restoring the deployment failed. The deployment might be permanently deleted.',
    ),
    extraDeploymentsLabel: s__('Pages|Parallel deployments: %{count}'),
    activeState: s__('Pages|Active'),
    stoppedState: s__('Pages|Stopped'),
    pathPrefixLabel: s__('Pages|Path prefix'),
    createdLabel: s__('Pages|Created'),
    deployJobLabel: s__('Pages|Deploy job'),
    rootDirLabel: s__('Pages|Root directory'),
    filesLabel: s__('Pages|Files'),
    sizeLabel: s__('Pages|Size'),
    lastUpdatedLabel: s__('Pages|Last updated'),
    deleteScheduledAtLabel: s__('Pages|Scheduled for deletion at'),
    deleteBtnLabel: s__('Pages|Delete'),
    restoreBtnLabel: s__('Pages|Restore'),
    moreDeploymentsMessage: s__('Pages|+ %{n} more deployments'),
  },
  fields: [
    {
      key: 'state',
      label: s__('Pages|State'),
    },
    {
      key: 'environment',
      label: s__('Pages|Path prefix'),
    },
    {
      key: 'url',
      label: s__('Pages|URL'),
      thClass: 'gl-min-w-62 gl-max-w-62',
      tdClass: 'gl-min-w-62 gl-max-w-62 gl-truncate',
    },
    {
      key: 'createdAt',
      label: s__('Pages|Created at'),
    },
    {
      key: 'ciBuildId',
      label: s__('Pages|Deploy Job'),
    },
    {
      key: 'size',
      label: s__('Pages|Size'),
    },
    {
      key: 'delete',
      label: s__('Pages|Delete'),
    },
  ],
  computed: {
    isSingleProjectView() {
      return this.viewType === this.$options.static.PROJECT_VIEW_TYPE;
    },
    pagesUrl() {
      return projectPagesPath(this.project.fullPath);
    },
    deploymentsTotalCount() {
      return this.project.pagesDeployments.count;
    },
    deploymentsNotShownCount() {
      return this.deploymentsTotalCount - this.project.pagesDeployments.nodes.length;
    },
    moreDeploymentsMessage() {
      return sprintf(this.$options.i18n.moreDeploymentsMessage, {
        n: this.deploymentsNotShownCount,
      });
    },
  },
  methods: {
    getBuildUrl(ciBuildId) {
      return projectJobPath(this.project.fullPath, ciBuildId);
    },
  },
};
</script>

<template>
  <gl-card body-class="gl-p-0">
    <template v-if="!isSingleProjectView" #header>
      <div class="gl-flex gl-items-center gl-justify-between" data-testid="project-name">
        <gl-link :href="pagesUrl" class="gl-flex gl-items-center gl-no-underline">
          <gl-avatar
            :src="project.avatarUrl"
            :size="32"
            shape="rect"
            :entity-name="project.name"
            fallback-on-error
            class="!gl-mr-3"
          />
          <span class="gl-font-bold gl-text-default">{{ project.name }}</span>
        </gl-link>
        <div>
          <gl-sprintf :message="$options.i18n.extraDeploymentsLabel">
            <template #count>
              <span class="gl-font-bold">
                {{ deploymentsTotalCount }}
              </span>
            </template>
          </gl-sprintf>
        </div>
      </div>
    </template>
    <div>
      <gl-table-lite
        :items="project.pagesDeployments.nodes"
        :fields="$options.fields"
        class="deployments-table gl-mb-0"
      >
        <template #cell(state)="{ item }">
          <gl-badge
            v-if="item.active"
            variant="success"
            size="sm"
            icon="status_success"
            icon-size="sm"
          >
            {{ $options.i18n.activeState }}
          </gl-badge>
          <gl-badge v-else variant="neutral" size="sm" icon="status_canceled" icon-size="sm">
            {{ $options.i18n.stoppedState }}
          </gl-badge>
        </template>
        <template #cell(environment)="{ item }">
          <gl-icon name="environment" class="!gl-mr-2" variant="subtle" />
          <span data-testid="path-prefix">{{ item.pathPrefix }}</span>
        </template>
        <template #cell(url)="{ item }">
          <gl-link v-if="item.active" :href="item.url" target="_blank" data-testid="url">
            {{ item.url }}
          </gl-link>
          <span v-else class="gl-text-subtle" data-testid="url">
            {{ item.url }}
          </span>
        </template>
        <template #cell(createdAt)="{ item }">
          <gl-icon name="play" class="!gl-mr-2" variant="subtle" />
          <user-date
            :date="item.createdAt"
            :date-format="$options.static.SHORT_DATE_FORMAT_WITH_TIME"
          />
        </template>
        <template #cell(ciBuildId)="{ item }">
          <gl-icon name="deployments" class="!gl-mr-2" variant="subtle" />
          <gl-link :href="getBuildUrl(item.ciBuildId)" data-testid="ci-build">
            {{ item.ciBuildId }}
          </gl-link>
        </template>
        <template #cell(size)="{ item }">
          <gl-icon name="disk" class="!gl-mr-2" variant="subtle" />
          <number-to-human-size :value="item.size" />
        </template>
        <template #cell(delete)="{ item }">
          <delete-deployment :id="item.id" :active="item.active" />
        </template>
      </gl-table-lite>
      <div v-if="deploymentsNotShownCount > 0">
        <div class="gl-flex gl-justify-center gl-py-3">
          {{ moreDeploymentsMessage }}
          <gl-link :href="pagesUrl" class="gl-ml-2" data-testid="view-all-link">{{
            __('View all')
          }}</gl-link>
        </div>
      </div>
    </div>
  </gl-card>
</template>

<style scoped>
/**
 Remove the first header's top and last row's bottom border so it doesn't create
 a double border with the card body border
*/
:deep(thead:first-child th) {
  border-top: none;
}
.deployments-table:last-child :deep(tr:last-child td) {
  border-bottom: none;
}
</style>
