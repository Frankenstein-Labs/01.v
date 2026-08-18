<script>
import { GlCard, GlButton, GlIcon, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { SCANNER_TYPE } from 'ee/on_demand_scans/constants';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'DastProfileSummaryCard',
  components: {
    GlCard,
    GlButton,
    GlIcon,
  },
  directives: {
    GlTooltip,
  },
  mixins: [glSlotsMixin],
  props: {
    allowSelection: {
      type: Boolean,
      required: false,
      default: false,
    },
    isEditable: {
      type: Boolean,
      required: false,
      default: true,
    },
    isProfileInUse: {
      type: Boolean,
      required: false,
      default: false,
    },
    isProfileSelected: {
      type: Boolean,
      required: false,
      default: false,
    },
    profileType: {
      type: String,
      required: false,
      default: SCANNER_TYPE,
    },
  },
  emits: ['edit', 'select-profile'],
  i18n: {
    editTitle: __('Edit %{profileType} profile'),
    selectTitle: __('Select Profile'),
    selectBtnText: __('Select'),
    selectedProfileLabel: __('In use'),
    selectedProfileTooltip: s__('DastProfiles|Profile is being used by this on-demand scan'),
  },
  computed: {
    disableSelectButton() {
      return !this.allowSelection || this.isProfileSelected;
    },
    editButtonTitle() {
      return sprintf(this.$options.i18n.editTitle, {
        profileType: this.profileType,
      });
    },
  },
};
</script>

<template>
  <gl-card :class="{ 'gl-my-3': allowSelection }">
    <template #header>
      <div class="gl-flex gl-items-center gl-justify-between">
        <div>
          <h3 class="gl-my-0 gl-inline gl-text-lg">
            <slot name="title"></slot>
          </h3>
          <span
            v-if="isProfileInUse"
            v-gl-tooltip="$options.i18n.selectedProfileTooltip"
            data-testid="in-use-label"
            class="gl-pl-2 gl-text-success"
          >
            <gl-icon name="check-circle-filled" :size="16" variant="success" />
            {{ $options.i18n.selectedProfileLabel }}
          </span>
        </div>
        <div v-if="allowSelection || isEditable" class="gl-flex gl-gap-x-3">
          <gl-button
            v-if="allowSelection"
            v-gl-tooltip
            data-testid="profile-select-btn"
            variant="confirm"
            size="small"
            category="secondary"
            :disabled="disableSelectButton"
            :title="$options.i18n.selectTitle"
            @click="$emit('select-profile')"
            >{{ $options.i18n.selectBtnText }}</gl-button
          >
          <gl-button
            v-if="isEditable"
            v-gl-tooltip.hover
            data-testid="profile-edit-btn"
            category="primary"
            size="small"
            icon="pencil"
            :title="editButtonTitle"
            :aria-label="$options.i18n.editTitle"
            @click="$emit('edit')"
          />
        </div>
      </div>
    </template>
    <template v-if="glSlots().summary" #default><slot name="summary"></slot></template>
  </gl-card>
</template>
