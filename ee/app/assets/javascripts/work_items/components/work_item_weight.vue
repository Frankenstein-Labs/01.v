<script>
import { GlButton, GlFormGroup, GlFormInput, GlTooltipDirective } from '@gitlab/ui';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import Tracking from '~/tracking';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  VIEW_CONTEXT,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { newWorkItemId } from '~/work_items/utils';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import WorkItemWeightConflictWarning from 'ee/work_items/components/work_item_weight_conflict_warning.vue';
import { sprintf } from '~/locale';

export default {
  name: 'WorkItemWeight',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    WorkItemSidebarWidget,
    WorkItemWeightConflictWarning,
  },
  mixins: [Tracking.mixin(), glFeatureFlagsMixin()],
  inject: {
    viewContext: { default: VIEW_CONTEXT.fullScreen },
  },
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    widget: {
      type: Object,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  emits: ['error', 'update-widget-draft'],
  data() {
    return {
      localWeight: this.widget.weight,
      isUpdating: false,
    };
  },
  computed: {
    weight() {
      return this.widget.weight;
    },
    rolledUpWeight() {
      return this.widget.rolledUpWeight;
    },
    hasWeight() {
      return this.weight !== null;
    },
    showRemoveWeight() {
      return this.hasWeight && !this.isUpdating;
    },
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_weight',
        property: `type_${this.workItemType}`,
        extra: { viewContext: this.viewContext },
      };
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
  },
  methods: {
    cancelEditing(stopEditing) {
      this.resetWeight();
      stopEditing();
    },
    clearWeight(stopEditing) {
      this.localWeight = '';
      stopEditing();
    },
    resetWeight() {
      this.localWeight = this.weight;
    },
    updateWeight() {
      if (!this.canUpdate) {
        return;
      }

      const newWeight = isPositiveInteger(this.localWeight) ? Number(this.localWeight) : null;

      if (this.weight === newWeight) {
        this.resetWeight();
        return;
      }

      this.isUpdating = true;

      this.track('updated_weight');

      if (this.createFlow) {
        this.$emit('update-widget-draft', { weight: newWeight });
        this.isUpdating = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              weightWidget: {
                weight: newWeight,
              },
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          this.resetWeight();
          this.$emit(
            'error',
            sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
              workItemType: this.workItemType,
            }),
          );
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <work-item-sidebar-widget
    :can-update="canUpdate"
    :is-updating="isUpdating"
    data-testid="work-item-weight"
    @stop-editing="updateWeight"
  >
    <template #title>
      {{ __('Weight') }}
    </template>
    <template #content>
      <template v-if="hasWeight">
        {{ weight }}

        <work-item-weight-conflict-warning :weight="weight" :rolled-up-weight="rolledUpWeight" />
      </template>
      <span v-else class="gl-text-subtle">
        {{ __('None') }}
      </span>
    </template>
    <template #editing-content="{ stopEditing }">
      <div class="gl-relative gl-px-2">
        <gl-form-group :label="__('Weight')" label-for="weight-widget-input" label-sr-only>
          <gl-form-input
            id="weight-widget-input"
            v-model="localWeight"
            autofocus
            min="0"
            :placeholder="__('Enter a number')"
            type="number"
            @keydown.enter="stopEditing"
            @keydown.exact.esc.stop="cancelEditing(stopEditing)"
          />
        </gl-form-group>
        <gl-button
          v-if="showRemoveWeight"
          v-gl-tooltip
          class="gl-absolute gl-right-7 gl-top-2"
          category="tertiary"
          icon="clear"
          size="small"
          :title="__('Remove weight')"
          :aria-label="__('Remove weight')"
          data-testid="remove-weight"
          @click="clearWeight(stopEditing)"
        />
      </div>
    </template>
  </work-item-sidebar-widget>
</template>
