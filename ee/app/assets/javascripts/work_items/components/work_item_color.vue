<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlPopover,
} from '@gitlab/ui';
import { validateHexColor } from '~/lib/utils/color_utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __, s__, sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  DEFAULT_EPIC_COLORS,
  EPIC_COLORS,
  I18N_WORK_ITEM_ERROR_UPDATING,
  TRACKING_CATEGORY_SHOW,
  VIEW_CONTEXT,
  WIDGET_TYPE_COLOR,
} from '~/work_items/constants';
import SidebarColorView from '~/sidebar/components/sidebar_color_view.vue';
import SidebarColorPicker from '~/sidebar/components/sidebar_color_picker.vue';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { findColorWidget, newWorkItemId } from '~/work_items/utils';
import Tracking from '~/tracking';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';

export default {
  name: 'WorkItemColor',
  helpIconLink: helpPagePath('/user/group/epics/manage_epics', { anchor: 'epic-color' }),
  EPIC_COLORS,
  components: {
    GlIcon,
    GlLink,
    GlPopover,
    SidebarColorPicker,
    SidebarColorView,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlButton,
    WorkItemSidebarWidget,
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
    workItem: {
      type: Object,
      required: true,
    },
  },
  emits: ['error', 'update-widget-draft'],
  data() {
    return {
      currentColor: '',
      isEditing: false,
      isUpdating: false,
      errorMessage: '',
    };
  },
  computed: {
    workItemId() {
      return this.workItem?.id;
    },
    workItemType() {
      return this.workItem?.workItemType?.name;
    },
    workItemColorWidget() {
      return findColorWidget(this.workItem);
    },
    color() {
      return this.workItemColorWidget?.color;
    },
    selectedColor() {
      // Check if current color hex code matches a suggested color key
      // If yes, return the named color from suggested color list
      // If no, return Custom
      if (this.suggestedColorKeys.includes(this.color?.toLowerCase())) {
        return Object.values(
          EPIC_COLORS.find((item) => Object.keys(item)[0] === this.color?.toLowerCase()),
        ).pop();
      }
      return __('Custom');
    },
    textColor() {
      return this.workItemColorWidget?.textColor;
    },
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_color',
        property: `type_${this.workItemType}`,
        extra: { viewContext: this.viewContext },
      };
    },
    suggestedColorKeys() {
      return EPIC_COLORS.map((item) => Object.keys(item).pop());
    },
    helpIconId() {
      return `help-icon-icon-${this.workItem?.iid}`;
    },
  },
  watch: {
    currentColor() {
      if (!validateHexColor(this.currentColor)) {
        this.errorMessage = s__('WorkItem|Must be a valid hex code');
      } else if (this.suggestedColorKeys.includes(this.currentColor)) {
        this.errorMessage = '';
        this.updateColor();
      } else {
        this.errorMessage = '';
      }
    },
  },
  created() {
    this.currentColor = this.color;
  },
  methods: {
    async updateColor() {
      if (
        !this.canUpdate ||
        this.color === this.currentColor ||
        !validateHexColor(this.currentColor)
      ) {
        this.isEditing = false;
        return;
      }

      this.isUpdating = true;

      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$emit('update-widget-draft', { color: this.currentColor });
        this.isUpdating = false;
        this.isEditing = false;
        return;
      }

      const editedFeatures =
        this.glFeatures?.workItemFeaturesField && this.workItem?.features
          ? {
              features: {
                ...this.workItem.features,
                color: {
                  ...(this.workItem.features.color || {}),
                  color: this.currentColor,
                  textColor: this.textColor,
                },
              },
            }
          : {};

      try {
        const {
          data: {
            workItemUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              colorWidget: { color: this.currentColor },
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
          optimisticResponse: {
            workItemUpdate: {
              errors: [],
              workItem: {
                ...this.workItem,
                widgets: [
                  ...this.workItem.widgets,
                  {
                    color: this.currentColor,
                    textColor: this.textColor,
                    type: WIDGET_TYPE_COLOR,
                    __typename: 'WorkItemWidgetColor',
                  },
                ],
                ...editedFeatures,
              },
            },
          },
        });

        if (errors.length) {
          throw new Error(errors.join('\n'));
        }
        this.track('updated_color');
      } catch {
        const msg = sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
          workItemType: this.workItemType,
        });
        this.$emit('error', msg);
      } finally {
        this.isEditing = false;
        this.isUpdating = false;
      }
    },
    resetColor() {
      this.currentColor = DEFAULT_EPIC_COLORS;
      this.updateColor();
    },
  },
};
</script>

<template>
  <work-item-sidebar-widget
    :can-update="canUpdate"
    :is-editing="isEditing"
    :is-updating="isUpdating"
    data-testid="work-item-color"
    @start-editing="isEditing = true"
    @stop-editing="isEditing = false"
  >
    <template #title>
      {{ __('Color') }}
      <gl-link
        :id="helpIconId"
        class="gl-leading-0"
        :href="$options.helpIconLink"
        :aria-label="__('Learn more')"
        data-testid="info-icon"
      >
        <gl-icon name="information-o" />
      </gl-link>
      <gl-popover :target="helpIconId">
        {{ __('An epic’s color is shown in roadmaps and epic boards.') }}
        <gl-link :href="$options.helpIconLink">
          {{ __('See examples.') }}
        </gl-link>
      </gl-popover>
    </template>
    <template #content>
      <sidebar-color-view :color="color" :color-name="selectedColor" />
    </template>
    <template #editing-content>
      <gl-disclosure-dropdown
        class="work-item-sidebar-dropdown"
        :auto-close="false"
        start-opened
        @hidden="updateColor"
      >
        <template #header>
          <div
            class="gl-flex gl-min-h-8 gl-items-center gl-border-b-1 gl-border-b-dropdown gl-px-4 gl-py-2 gl-border-b-solid"
          >
            <span
              data-testid="color-header-title"
              class="gl-grow gl-pr-2 gl-text-sm gl-font-bold gl-leading-normal"
            >
              {{ __('Select a color') }}
            </span>
            <gl-button
              data-testid="reset-color"
              category="tertiary"
              size="small"
              class="!gl-px-2 !gl-py-2 !gl-text-sm"
              @click="resetColor"
              >{{ __('Reset') }}
            </gl-button>
          </div>
        </template>
        <template #toggle>
          <sidebar-color-view :color="color" :color-name="selectedColor" />
        </template>
        <gl-disclosure-dropdown-item>
          <sidebar-color-picker
            v-model="currentColor"
            autofocus
            :suggested-colors="$options.EPIC_COLORS"
            :error-message="errorMessage"
            class="gl-mt-3 gl-px-3"
          />
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown>
    </template>
  </work-item-sidebar-widget>
</template>
