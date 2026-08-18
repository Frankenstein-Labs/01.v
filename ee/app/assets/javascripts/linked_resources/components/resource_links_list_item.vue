<script>
import { GlIcon, GlButton, GlTooltipDirective, GlLink } from '@gitlab/ui';
import api from '~/api';
import '~/commons/bootstrap';
import { resourceLinksListI18n } from '../constants';
import { getLinkIcon } from './utils';

export default {
  name: 'ResourceLinkItem',
  components: {
    GlIcon,
    GlButton,
    GlLink,
  },
  i18n: resourceLinksListI18n,
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    idKey: {
      type: String,
      required: false,
      default: '',
    },
    iconName: {
      type: String,
      required: false,
      default: 'external-link',
    },
    linkText: {
      type: String,
      required: false,
      default: '',
    },
    linkValue: {
      type: String,
      required: false,
      default: '',
    },
    canRemove: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['remove-request'],
  data() {
    return {
      isRemoveDisabled: false,
    };
  },
  computed: {
    iconClasses() {
      return `ic-${this.iconName}`;
    },
  },
  methods: {
    getLinkIcon,
    trackResourceLinkClick() {
      api.trackRedisHllUserEvent('incident_management_issuable_resource_link_visited');
    },
    handleRemove() {
      this.isRemoveDisabled = true;
      this.$emit('remove-request', this.idKey);
    },
  },
};
</script>

<template>
  <div
    :class="{
      'gl-pr-2': canRemove,
    }"
    class="item-body -gl-mx-2 gl-flex gl-items-center gl-px-3"
  >
    <div
      class="item-contents gl-flex gl-min-h-7 gl-grow gl-flex-wrap gl-items-center @xl/panel:!gl-flex-nowrap"
    >
      <div
        class="item-title gl-min-w-0 @sm/panel:gl-flex @xl/panel:!gl-mb-0 @xl/panel:!gl-items-center"
      >
        <gl-icon
          class="gl-mr-3"
          :name="getLinkIcon(iconName)"
          :class="iconClasses"
          variant="subtle"
        />
        <gl-link
          :href="linkValue"
          target="_blank"
          class="sortable-link gl-font-normal"
          @click="trackResourceLinkClick"
          >{{ linkText }}</gl-link
        >
      </div>
    </div>
    <gl-button
      v-if="canRemove"
      v-gl-tooltip
      icon="close"
      category="tertiary"
      size="small"
      :disabled="isRemoveDisabled"
      class="js-issue-item-remove-button gl-ml-5"
      :title="$options.i18n.linkRemoveText"
      :aria-label="$options.i18n.linkRemoveText"
      @click="handleRemove"
    />
  </div>
</template>
