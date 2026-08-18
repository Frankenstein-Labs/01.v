<script>
import { GlToastMixin } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { getParentGroupName } from '~/work_items/utils';
import WorkItemChangeTypeModal from '~/work_items/components/work_item_change_type_modal.vue';
import promoteToEpicMutation from '~/issues/show/queries/promote_to_epic.mutation.graphql';
import {
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_WEIGHT,
  WORK_ITEM_TYPE_NAME_EPIC,
} from '~/work_items/constants';

export default {
  name: 'WorkItemChangeTypeModalEE',
  components: {
    WorkItemChangeTypeModal,
  },
  mixins: [GlToastMixin],
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: '',
    },
    workItemType: {
      type: String,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: true,
    },
    hasChildren: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasParent: {
      type: Boolean,
      required: false,
      default: false,
    },
    widgets: {
      type: Array,
      required: false,
      default: () => [],
    },
    allowedChildTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
    namespaceFullName: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['error', 'work-item-type-changed'],
  computed: {
    epicFieldNote() {
      return sprintf(s__('WorkItem|Epic will be moved to parent group %{groupName}.'), {
        groupName: getParentGroupName(this.namespaceFullName),
      });
    },
  },
  methods: {
    async promoteToEpic() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: promoteToEpicMutation,
          variables: {
            input: {
              iid: String(this.workItemIid),
              projectPath: this.fullPath,
            },
          },
        });

        if (data?.promoteToEpic?.errors?.length > 0) {
          this.$emit('error', data.promoteToEpic.errors[0]);
          return;
        }

        this.$toast.show(s__('WorkItem|Type changed.'));

        visitUrl(data.promoteToEpic.epic.webPath);
      } catch (error) {
        this.$emit('error', error.message);
        Sentry.captureException(error);
      }
    },
    // show() is invoked by parent component to show the modal
    // eslint-disable-next-line vue/no-unused-properties
    show() {
      this.$refs.workItemsChangeTypeModal.show();
    },
    getEpicWidgetDefinitions({ workItemTypes }) {
      const epicWidgets = workItemTypes.find(
        (widget) => widget.name === WORK_ITEM_TYPE_NAME_EPIC,
      )?.widgetDefinitions;
      const updatedWidgetDefinitions = epicWidgets.filter((widget) => {
        if (widget.type === WIDGET_TYPE_WEIGHT) {
          return widget.editable === true;
        }
        return true;
      });
      // The workItemTypes query is not fetching assignees widget, so we need to add it manually in frontend
      // Need to fix this in the backend
      updatedWidgetDefinitions.push({
        type: WIDGET_TYPE_ASSIGNEES,
        __typename: 'WorkItemWidgetDefinitionAssignees',
      });

      return updatedWidgetDefinitions;
    },
  },
};
</script>
<template>
  <work-item-change-type-modal
    ref="workItemsChangeTypeModal"
    :work-item-id="workItemId"
    :work-item-iid="workItemIid"
    :work-item-type="workItemType"
    :full-path="fullPath"
    :has-children="hasChildren"
    :has-parent="hasParent"
    :widgets="widgets"
    :allowed-child-types="allowedChildTypes"
    :namespace-full-name="namespaceFullName"
    :epic-field-note="epicFieldNote"
    :get-epic-widget-definitions="getEpicWidgetDefinitions"
    @work-item-type-changed="$emit('work-item-type-changed')"
    @promote-to-epic="promoteToEpic"
    @error="$emit('error', $event)"
  />
</template>
