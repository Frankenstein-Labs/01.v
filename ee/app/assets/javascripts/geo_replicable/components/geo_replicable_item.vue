<script>
import { GlSprintf } from '@gitlab/ui';
import {
  REPLICATION_STATUS_STATES,
  VERIFICATION_STATUS_STATES,
  REPLICATION_STATUS_LABELS,
  VERIFICATION_STATUS_LABELS,
} from 'ee/geo_shared/constants';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { __, s__, sprintf } from '~/locale';
import { ACTION_TYPES } from '../constants';

export default {
  name: 'GeoReplicableItem',
  i18n: {
    unknown: __('Unknown'),
    nA: __('Not applicable.'),
    resync: s__('Geo|Resync'),
    reverify: s__('Geo|Reverify'),
    lastVerified: s__('Geo|Verified'),
    modelRecord: s__('Geo|Model record: %{modelRecord}'),
    replicationStatus: s__('Geo|Replication: %{status}'),
    verificationStatus: s__('Geo|Verification: %{status}'),
    replicationFailure: s__('Geo|Replication failure'),
    verificationFailure: s__('Geo|Verification failure'),
  },
  components: {
    GeoListItem,
    GlSprintf,
  },
  inject: ['replicableBasePath', 'replicableClass'],
  props: {
    registryId: {
      type: [String, Number],
      required: true,
    },
    modelRecordId: {
      type: Number,
      required: true,
    },
    syncStatus: {
      type: String,
      required: false,
      default: '',
    },
    verificationState: {
      type: String,
      required: false,
      default: '',
    },
    lastSynced: {
      type: String,
      required: false,
      default: '',
    },
    lastVerified: {
      type: String,
      required: false,
      default: '',
    },
    lastSyncFailure: {
      type: String,
      required: false,
      default: '',
    },
    verificationFailure: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['action-clicked'],
  computed: {
    timeAgoArray() {
      return [
        {
          label: capitalizeFirstCharacter(this.syncStatus?.toLowerCase()),
          dateString: this.lastSynced,
          defaultText: this.$options.i18n.unknown,
        },
        {
          label: this.$options.i18n.lastVerified,
          dateString: this.lastVerified,
          defaultText: this.replicableClass.verificationEnabled
            ? this.$options.i18n.unknown
            : this.$options.i18n.nA,
        },
      ];
    },
    id() {
      return getIdFromGraphQLId(this.registryId);
    },
    modelRecord() {
      return `${this.replicableClass.modelClassName}/${this.modelRecordId}`;
    },
    detailsPath() {
      return `${this.replicableBasePath}/${getIdFromGraphQLId(this.id)}`;
    },
    name() {
      return `${this.replicableClass.graphqlRegistryClass}/${this.id}`;
    },
    statusArray() {
      const replicationStatus =
        REPLICATION_STATUS_STATES[this.syncStatus?.toUpperCase()] ||
        REPLICATION_STATUS_STATES.UNKNOWN;

      const statuses = [
        {
          tooltip: sprintf(this.$options.i18n.replicationStatus, {
            status: replicationStatus.title,
          }),
          icon: replicationStatus.icon,
          variant: replicationStatus.variant,
          label:
            REPLICATION_STATUS_LABELS[replicationStatus.value] || REPLICATION_STATUS_LABELS.UNKNOWN,
        },
      ];

      if (this.replicableClass.verificationEnabled) {
        const verificationStatus =
          VERIFICATION_STATUS_STATES[this.verificationState?.toUpperCase()] ||
          VERIFICATION_STATUS_STATES.UNKNOWN;

        statuses.push({
          tooltip: sprintf(this.$options.i18n.verificationStatus, {
            status: verificationStatus.title,
          }),
          icon: verificationStatus.icon,
          variant: verificationStatus.variant,
          label:
            VERIFICATION_STATUS_LABELS[verificationStatus.value] ||
            VERIFICATION_STATUS_LABELS.UNKNOWN,
        });
      }

      return statuses;
    },
    actionsArray() {
      const actions = [
        {
          id: 'geo-resync-item',
          value: ACTION_TYPES.RESYNC,
          text: this.$options.i18n.resync,
          icon: 'retry',
        },
      ];

      if (this.replicableClass.verificationEnabled) {
        actions.push({
          id: 'geo-reverify-item',
          value: ACTION_TYPES.REVERIFY,
          text: this.$options.i18n.reverify,
        });
      }

      return actions;
    },
    errorsArray() {
      const errors = [];

      if (this.lastSyncFailure) {
        errors.push({
          label: this.$options.i18n.replicationFailure,
          message: this.lastSyncFailure,
        });
      }

      if (this.verificationFailure) {
        errors.push({
          label: this.$options.i18n.verificationFailure,
          message: this.verificationFailure,
        });
      }

      return errors;
    },
  },
  methods: {
    handleActionClicked(action) {
      this.$emit('action-clicked', {
        registryId: this.registryId,
        name: this.name,
        action: action.value,
      });
    },
  },
};
</script>

<template>
  <geo-list-item
    :name="name"
    :details-path="detailsPath"
    :status-array="statusArray"
    :time-ago-array="timeAgoArray"
    :actions-array="actionsArray"
    :errors-array="errorsArray"
    @action-clicked="handleActionClicked"
  >
    <template #extra-details>
      <gl-sprintf :message="$options.i18n.modelRecord">
        <template #modelRecord>
          {{ modelRecord }}
        </template>
      </gl-sprintf>
    </template>
  </geo-list-item>
</template>
