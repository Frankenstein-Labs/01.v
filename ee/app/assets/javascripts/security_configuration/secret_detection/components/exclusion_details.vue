<script>
import { GlIcon } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { EXCLUSION_TYPE_MAP } from '../constants';
import Detail from './exclusion_detail.vue';

export default {
  name: 'ExclusionDetails',
  components: { GlIcon, Detail },
  i18n: {
    typeLabel: s__('SecurityExclusions|Type'),
    contentLabel: s__('SecurityExclusions|Value'),
    descriptionLabel: s__('SecurityExclusions|Description'),
    enforcementLabel: s__('SecurityExclusions|Enforcement'),
    statusLabel: s__('SecurityExclusions|Status'),
    createdLabel: s__('SecurityExclusions|Created'),
    updatedLabel: s__('SecurityExclusions|Updated'),
    secretPushProtection: s__('SecurityExclusions|Secret push protection'),
  },
  props: {
    exclusion: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    type() {
      return EXCLUSION_TYPE_MAP[this.exclusion.type]?.text || '';
    },
    content() {
      return this.exclusion.value;
    },
    description() {
      return this.exclusion.description || __('None');
    },
    enforcement() {
      return this.$options.i18n.secretPushProtection;
    },
    status() {
      return this.exclusion.active ? __('Enabled') : __('Disabled');
    },
    iconName() {
      return this.exclusion.active ? 'check-circle-filled' : 'dash-circle';
    },
    statusClass() {
      return this.exclusion.active ? 'gl-text-success' : 'gl-text-info';
    },
    createdAt() {
      return getTimeago().format(this.exclusion.createdAt);
    },
    updatedAt() {
      return getTimeago().format(this.exclusion.updatedAt);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <detail :label="$options.i18n.typeLabel" :value="type" />
    <detail :label="$options.i18n.contentLabel" :value="content" />
    <detail :label="$options.i18n.descriptionLabel" :value="description" />
    <detail :label="$options.i18n.enforcementLabel">
      <gl-icon name="check" variant="success" />
      {{ enforcement }}
    </detail>
    <detail :label="$options.i18n.statusLabel">
      <span :class="statusClass"> <gl-icon :name="iconName" /> {{ status }} </span>
    </detail>
    <detail :label="$options.i18n.createdLabel" :value="createdAt" />
    <detail :label="$options.i18n.updatedLabel" :value="updatedAt" />
  </div>
</template>
