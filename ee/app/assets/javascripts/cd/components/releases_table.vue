<script>
import { GlBadge, GlTableLite } from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import {
  TH_CLASS,
  TD_CLASS,
  ROW_SELECTED_CLASS,
  ROW_RECENT_CLASS,
  EMPTY_PLACEHOLDER,
} from '../constants';
import {
  worstRolloutHealth,
  healthVariant,
  healthLabel,
  rolloutStateVariant,
  rolloutStateLabel,
  buildRowClass,
} from '../utils';

const VERSION_FIELD = {
  key: 'name',
  label: s__('ContinuousDeployment|Version'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const DEPLOYMENTS_FIELD = {
  key: 'deployments',
  label: s__('ContinuousDeployment|Deployment ID'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const SERVICES_FIELD = {
  key: 'services',
  label: s__('ContinuousDeployment|Services'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const CREATED_FIELD = {
  key: 'createdAt',
  label: s__('ContinuousDeployment|Created'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const STATUS_FIELD = {
  key: 'status',
  label: s__('ContinuousDeployment|Status'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};
const HEALTH_FIELD = {
  key: 'health',
  label: s__('ContinuousDeployment|Health'),
  tdClass: TD_CLASS,
  thClass: TH_CLASS,
};

export default {
  name: 'ReleasesTable',
  components: {
    GlBadge,
    GlTableLite,
    TimeAgo,
  },
  props: {
    releases: {
      type: Array,
      required: true,
    },
    full: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedId: {
      type: String,
      required: false,
      default: null,
    },
    recentId: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['select'],
  computed: {
    fields() {
      if (!this.full) {
        return [VERSION_FIELD, STATUS_FIELD];
      }

      return [
        VERSION_FIELD,
        DEPLOYMENTS_FIELD,
        SERVICES_FIELD,
        CREATED_FIELD,
        STATUS_FIELD,
        HEALTH_FIELD,
      ];
    },
  },
  methods: {
    deploymentIdsList(release) {
      const deployments = release.rollouts?.nodes || [];
      if (!deployments.length) {
        return EMPTY_PLACEHOLDER;
      }
      return deployments.map((deployment) => `#${deployment.iid}`).join(', ');
    },
    servicesCount(release) {
      return release.versionSetEntries?.count ?? 0;
    },
    rolloutState(release) {
      return release.latestRollout?.nodes?.[0]?.state ?? null;
    },
    statusVariant(release) {
      return rolloutStateVariant(this.rolloutState(release));
    },
    statusLabel(release) {
      return rolloutStateLabel(this.rolloutState(release));
    },
    releaseHealth(release) {
      return worstRolloutHealth(release.latestRollout?.nodes?.[0]);
    },
    healthVariant,
    healthLabel,
    rowClass(item) {
      return buildRowClass(item?.id, [
        [this.selectedId, ROW_SELECTED_CLASS],
        [this.recentId, ROW_RECENT_CLASS],
      ]);
    },
  },
};
</script>

<template>
  <gl-table-lite
    :items="releases"
    :fields="fields"
    stacked="sm"
    borderless
    :tbody-tr-class="rowClass"
    data-testid="releases-table"
    @row-clicked="$emit('select', $event)"
  >
    <template #cell(status)="{ item }">
      <gl-badge v-if="statusLabel(item)" :variant="statusVariant(item)">
        {{ statusLabel(item) }}
      </gl-badge>
    </template>
    <template v-if="full" #cell(deployments)="{ item }">
      {{ deploymentIdsList(item) }}
    </template>
    <template v-if="full" #cell(services)="{ item }">
      {{ servicesCount(item) }}
    </template>
    <template v-if="full" #cell(createdAt)="{ item }">
      <time-ago v-if="item.createdAt" :time="item.createdAt" />
    </template>
    <template v-if="full" #cell(health)="{ item }">
      <gl-badge :variant="healthVariant(releaseHealth(item))">
        {{ healthLabel(releaseHealth(item)) }}
      </gl-badge>
    </template>
  </gl-table-lite>
</template>
