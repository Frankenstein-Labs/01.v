<script>
import { GlFormGroup, GlFormInput, GlPopover } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import Tracking from '~/tracking';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  VIEW_CONTEXT,
  WIDGET_TYPE_PROGRESS,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { sprintf } from '~/locale';

export default {
  name: 'WorkItemProgress',
  minValue: 0,
  maxValue: 100,
  components: {
    GlFormInput,
    GlFormGroup,
    GlPopover,
    HelpIcon,
    WorkItemSidebarWidget,
  },
  mixins: [Tracking.mixin(), glFeatureFlagMixin()],
  inject: {
    getWorkItemTypeConfiguration: 'getWorkItemTypeConfiguration',
    viewContext: { default: VIEW_CONTEXT.fullScreen },
  },
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    progress: {
      type: Number,
      required: false,
      default: undefined,
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
  emits: ['error'],
  data() {
    return {
      localProgress: this.progress,
      isUpdating: false,
    };
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_progress',
        property: `type_${this.workItemType}`,
        extra: { viewContext: this.viewContext },
      };
    },
    workItemTypeConfiguration() {
      return this.getWorkItemTypeConfiguration(this.workItemType);
    },
    showProgressPopover() {
      return this.workItemTypeConfiguration?.widgetDefinitions.find(
        ({ type }) => type === WIDGET_TYPE_PROGRESS,
      )?.showPopover;
    },
    isValidProgress() {
      if (this.localProgress === '') {
        return false;
      }

      const valueAsNumber = Number(this.localProgress);

      return this.checkValidProgress(valueAsNumber);
    },
  },
  watch: {
    progress(newValue) {
      this.localProgress = newValue;
    },
  },
  methods: {
    cancelEditing(stopEditing) {
      this.resetProgress();
      stopEditing();
    },
    checkValidProgress(progress) {
      return (
        Number.isInteger(progress) &&
        progress >= this.$options.minValue &&
        progress <= this.$options.maxValue
      );
    },
    resetProgress() {
      this.localProgress = this.progress;
    },
    updateProgress() {
      if (!this.canUpdate) return;

      if (this.localProgress === '') {
        this.resetProgress();
        return;
      }

      const valueAsNumber = Number(this.localProgress);

      if (valueAsNumber === this.progress || !this.checkValidProgress(valueAsNumber)) {
        this.resetProgress();
        return;
      }

      this.isUpdating = true;
      this.track('updated_progress');
      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              progressWidget: {
                currentValue: valueAsNumber,
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
          this.resetProgress();
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
    data-testid="work-item-progress"
    @stop-editing="updateProgress"
  >
    <template #title>
      {{ __('Progress') }}
      <template v-if="showProgressPopover">
        <button
          id="okr-progress-popover-title"
          class="gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
        >
          <help-icon />
          <span class="gl-sr-only">{{ __('How is progress calculated?') }}</span>
        </button>
        <gl-popover
          target="okr-progress-popover-title"
          placement="top"
          :title="__('How is progress calculated?')"
          :content="
            __(
              'This field is auto-calculated based on the progress score of its direct children. You can overwrite this value but it will be replaced by the auto-calculation anytime the progress score of its direct children are updated.',
            )
          "
        />
      </template>
    </template>
    <template #content> {{ localProgress }}% </template>
    <template #editing-content="{ stopEditing }">
      <gl-form-group
        :invalid-feedback="__('Enter a number from 0 to 100.')"
        :label="__('Progress')"
        label-for="progress-widget-input"
        label-sr-only
      >
        <gl-form-input
          id="progress-widget-input"
          v-model="localProgress"
          autofocus
          :min="$options.minValue"
          :max="$options.maxValue"
          :state="isValidProgress"
          type="number"
          @keydown.enter="stopEditing"
          @keydown.exact.esc.stop="cancelEditing(stopEditing)"
        />
      </gl-form-group>
    </template>
  </work-item-sidebar-widget>
</template>
