<script>
import {
  GlTable,
  GlAvatarLabeled,
  GlAvatarLink,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { range } from 'lodash-es';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { USAGE_BY_PROJECT_HEADER } from '../../constants';

export default {
  name: 'UsageByProject',
  i18n: {
    USAGE_BY_PROJECT_HEADER,
  },
  fields: [
    {
      key: 'project',
      label: __('Project'),
      tdClass: ['gl-w-full gl-wrap-anywhere'],
      thClass: ['gl-w-full'],
    },
    {
      key: 'dataUsed',
      label: s__('UsageQuota|Transfer data used'),
      tdClass: ['gl-whitespace-nowrap !gl-align-middle'],
      thClass: ['gl-whitespace-nowrap'],
    },
  ],
  components: { GlTable, GlAvatarLabeled, GlAvatarLink, GlKeysetPagination, GlSkeletonLoader },
  props: {
    projects: {
      type: Object,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['next', 'prev'],
  computed: {
    items() {
      if (this.loading) {
        return range(10).map(() => ({}));
      }

      return (this.projects.nodes || []).map(
        ({ id, avatarUrl, webUrl, name, nameWithNamespace, dataTransfer }) => {
          const egressNodes = dataTransfer?.egressNodes?.nodes || [];
          const combinedEgressNodes = egressNodes.reduce((accumulator, { totalEgress = '0' }) => {
            return accumulator + Number(totalEgress);
          }, 0);

          return {
            id: getIdFromGraphQLId(id),
            avatarUrl,
            webUrl,
            name,
            nameWithNamespace,
            dataUsed: numberToHumanSize(combinedEgressNodes),
          };
        },
      );
    },
    pageInfo() {
      return this.projects.pageInfo || {};
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <h4 class="gl-mb-5 gl-text-lg">{{ $options.i18n.USAGE_BY_PROJECT_HEADER }}</h4>
    <gl-table :fields="$options.fields" :items="items">
      <template #cell(project)="{ item: { id, avatarUrl, webUrl, name, nameWithNamespace } }">
        <div v-if="loading" class="gl-w-20">
          <gl-skeleton-loader :width="160" :height="32">
            <rect x="0" y="0" rx="2" ry="2" width="32" height="32" />
            <rect x="40" y="8" rx="2" ry="2" width="120" height="16" />
          </gl-skeleton-loader>
        </div>
        <gl-avatar-link v-else :href="webUrl">
          <gl-avatar-labeled
            :src="avatarUrl"
            :entity-id="id"
            :entity-name="name"
            :label="nameWithNamespace"
            :size="32"
            shape="rect"
          />
        </gl-avatar-link>
      </template>

      <template #cell(dataUsed)="{ item: { dataUsed } }">
        <div v-if="loading" class="gl-w-12">
          <gl-skeleton-loader :width="80" :height="16">
            <rect x="0" y="0" rx="2" ry="2" width="80" height="16" />
          </gl-skeleton-loader>
        </div>
        <span v-else data-testid="transfer-data-used">{{ dataUsed }}</span>
      </template>
    </gl-table>
    <div v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage" class="gl-mt-5 gl-text-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        @prev="$emit('prev', $event)"
        @next="$emit('next', $event)"
      />
    </div>
  </div>
</template>
