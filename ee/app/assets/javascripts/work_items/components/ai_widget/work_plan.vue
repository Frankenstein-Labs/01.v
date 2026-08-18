<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { __, s__, sprintf } from '~/locale';
import { clearDraft, getDraft, updateDraft } from '~/lib/utils/autosave';
import { queryToObject, visitUrl } from '~/lib/utils/url_utility';
import {
  AGENT_PLAN_PANEL,
  DETAIL_VIEW_QUERY_PARAM_NAME,
  I18N_WORK_ITEM_ERROR_UPDATING,
} from '~/work_items/constants';
import { findAgentPlanWidget } from 'ee/work_items/utils';
import { WIDGET_TYPE_AGENT_PLAN } from 'ee/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  eventHub,
  QUEUE_CHAT_COMMAND,
  SHOW_NEW_CHAT,
  OPEN_AGENT_PLAN_PANEL,
  DUO_CHAT_REGISTER_EMPTY_STATE_HEADER,
  DUO_CHAT_REQUEST_EMPTY_STATE_HEADER,
} from 'ee/ai/events/panel';
import WorkPlanInlineRow from './work_plan_inline_row.vue';
import WorkPlanPanel from './work_plan_panel.vue';
import WorkplanEmptyStateHeader from './workplan_empty_state_header.vue';
import { buildWorkPlanChatCommand } from './constants';

const EMPTY_STATE_HEADER_ID = 'workplan';

export default {
  name: 'WorkPlan',
  components: {
    WorkPlanInlineRow,
    WorkPlanPanel,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    fullPath: { default: '' },
    hasRemoteFlowsEnabled: { from: 'duoRemoteFlowsAvailability', default: false },
  },
  props: {
    workItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemWebUrl: {
      type: String,
      required: false,
      default: '',
    },
    isInDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
    isPanelOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['request-panel'],
  data() {
    return {
      isEditing: false,
      isSaving: false,
      tmpContent: '',
      draftContent: '',
      pendingGenerateOpen: false,
    };
  },
  computed: {
    isWorkplanEmptyStateEnabled() {
      return Boolean(this.glFeatures?.duoChatWorkplanEmptyState);
    },
    workItemId() {
      return this.workItem.id;
    },
    workItemIid() {
      return this.workItem.iid;
    },
    workItemType() {
      return this.workItem.workItemType.name;
    },
    agentPlanWidget() {
      return findAgentPlanWidget(this.workItem);
    },
    content() {
      return this.agentPlanWidget?.content || '';
    },
    hasSavedContent() {
      return Boolean(this.content);
    },
    planStorageKey() {
      return `work-plan-draft-${this.workItemId}`;
    },
    optimisticResponse() {
      const existing = this.agentPlanWidget;
      const updatedWidget = {
        ...(existing || { type: WIDGET_TYPE_AGENT_PLAN, __typename: 'WorkItemWidgetAgentPlan' }),
        content: this.tmpContent,
      };
      const editedFeatures = this.workItem?.features
        ? {
            features: {
              ...this.workItem.features,
              agentPlan: { ...this.workItem.features.agentPlan, content: this.tmpContent },
            },
          }
        : {};
      return {
        workItemUpdate: {
          errors: [],
          workItem: {
            ...this.workItem,
            widgets: [
              ...(this.workItem.widgets || []).filter((w) => w.type !== WIDGET_TYPE_AGENT_PLAN),
              updatedWidget,
            ],
            ...editedFeatures,
          },
        },
      };
    },
  },
  watch: {
    hasSavedContent(hasContent) {
      // Duo has finished generating and the plan is now saved. Open the panel
      // now — never on the Generate click itself — so the user skips the empty
      // Workplan state and lands directly on the previewable content.
      if (hasContent && this.pendingGenerateOpen) {
        this.pendingGenerateOpen = false;
        if (!this.isInDrawer && !this.isPanelOpen) {
          this.$emit('request-panel', AGENT_PLAN_PANEL);
        }
      }
    },
  },
  created() {
    const { content: storedDraft } = this.loadFromStorage();
    if (storedDraft) {
      this.draftContent = storedDraft;
    }
    if (!this.isInDrawer) {
      window.addEventListener('popstate', this.syncPanelFromUrl);
      if (this.urlRequestsPanel() && !this.isPanelOpen) {
        this.$emit('request-panel', AGENT_PLAN_PANEL);
      }
    }
    eventHub.$on(OPEN_AGENT_PLAN_PANEL, this.onGenerateRequested);
    if (this.isWorkplanEmptyStateEnabled) {
      eventHub.$on(DUO_CHAT_REQUEST_EMPTY_STATE_HEADER, this.publishEmptyStateHeader);
      this.publishEmptyStateHeader();
    }
  },
  beforeDestroy() {
    window.removeEventListener('popstate', this.syncPanelFromUrl);
    eventHub.$off(OPEN_AGENT_PLAN_PANEL, this.onGenerateRequested);
    eventHub.$off(DUO_CHAT_REQUEST_EMPTY_STATE_HEADER, this.publishEmptyStateHeader);
    eventHub.$emit(DUO_CHAT_REGISTER_EMPTY_STATE_HEADER, {
      id: EMPTY_STATE_HEADER_ID,
      component: null,
    });
  },
  methods: {
    publishEmptyStateHeader() {
      eventHub.$emit(DUO_CHAT_REGISTER_EMPTY_STATE_HEADER, {
        id: EMPTY_STATE_HEADER_ID,
        component: WorkplanEmptyStateHeader,
        props: {
          hasExistingWorkplan: this.hasSavedContent,
          resourceId: this.workItemId,
          workItemWebUrl: this.workItemWebUrl,
        },
      });
    },
    persistField(key, value) {
      if (!key) return;
      if (value) {
        updateDraft(key, value);
      } else {
        clearDraft(key);
      }
    },
    loadFromStorage() {
      return {
        content: this.planStorageKey ? getDraft(this.planStorageKey) : null,
      };
    },
    clearStorage() {
      this.persistField(this.planStorageKey, null);
    },
    openPanel() {
      if (this.isPanelOpen) {
        this.$emit('request-panel', null);
        return;
      }
      if (this.isInDrawer && this.workItemWebUrl) {
        try {
          visitUrl(`${this.workItemWebUrl}?${DETAIL_VIEW_QUERY_PARAM_NAME}=workplan`);
          return;
        } catch (e) {
          Sentry.captureException(e);
        }
      }
      this.$emit('request-panel', AGENT_PLAN_PANEL);
    },
    closePanel() {
      this.$emit('request-panel', null);
    },
    urlRequestsPanel() {
      const showParam = queryToObject(window.location.search)?.[DETAIL_VIEW_QUERY_PARAM_NAME];
      return showParam === 'workplan';
    },
    // Keep the panel in sync with the ?show=workplan URL param on browser
    syncPanelFromUrl() {
      const shouldOpen = this.urlRequestsPanel();
      if (shouldOpen !== this.isPanelOpen) {
        this.$emit('request-panel', shouldOpen ? AGENT_PLAN_PANEL : null);
      }
    },
    onGenerateRequested() {
      if (this.isInDrawer) {
        return;
      }
      this.pendingGenerateOpen = true;
    },
    handleDraftChange(value) {
      this.draftContent = value || '';
      this.persistField(this.planStorageKey, value);
    },
    // Duo chat is taking over — drop any in-progress edit so the panel
    // re-renders against the soon-to-be-written content rather than
    // stomping the user's stale draft on top of it.
    onAgentHandoff() {
      if (this.isEditing) {
        this.handleCancelEdit();
      }
    },
    showUpdateError(error) {
      createAlert({
        message: sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
          workItemType: this.workItemType,
        }),
      });
      Sentry.captureException(error);
    },
    async mutateAgentPlanContent() {
      const { data } = await this.$apollo.mutate({
        mutation: updateWorkItemMutation,
        variables: {
          input: {
            id: this.workItemId,
            agentPlanWidget: { content: this.tmpContent },
          },
          useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
        },
        optimisticResponse: this.optimisticResponse,
      });
      if (data.workItemUpdate.errors.length) {
        throw new Error(data.workItemUpdate.errors.join('\n'));
      }
    },
    handleStartEdit() {
      this.isEditing = true;
    },
    handleCancelEdit() {
      this.isEditing = false;
      this.draftContent = '';
      this.persistField(this.planStorageKey, null);
    },
    async handleSave(content) {
      // Defence-in-depth: the panel already trims before emitting, but
      // trimming here too means any future caller (e.g. an automated
      // save from a Duo flow) can't accidentally persist whitespace-only
      // content and flip the inline-row status pill to "Ready".
      this.tmpContent = content?.trim() || '';
      this.isSaving = true;
      try {
        await this.mutateAgentPlanContent();
        this.isEditing = false;
        this.draftContent = '';
        this.persistField(this.planStorageKey, null);
        if (this.isWorkplanEmptyStateEnabled) this.publishEmptyStateHeader();
      } catch (error) {
        this.showUpdateError(error);
      } finally {
        this.isSaving = false;
        this.tmpContent = '';
      }
    },
    handleRegenerate() {
      if (this.isEditing) {
        this.handleCancelEdit();
      }
      const command = buildWorkPlanChatCommand(this.workItemWebUrl);
      eventHub.$emit(SHOW_NEW_CHAT);
      eventHub.$emit(QUEUE_CHAT_COMMAND, {
        ...command,
        question: command.agenticPrompt,
        resourceId: this.workItemId,
      });
    },
    async handleDelete() {
      const confirmed = await confirmAction(
        s__(
          'AgentPlan|Are you sure you want to delete this workplan? This action cannot be undone.',
        ),
        {
          primaryBtnText: __('Delete'),
          primaryBtnVariant: 'danger',
        },
      );
      if (!confirmed) return;

      this.tmpContent = '';
      this.isSaving = true;
      this.clearStorage();
      try {
        await this.mutateAgentPlanContent();
        if (this.isWorkplanEmptyStateEnabled) this.publishEmptyStateHeader();
      } catch (error) {
        this.showUpdateError(error);
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <work-plan-inline-row
      :can-update="canUpdate"
      :is-panel-open="isPanelOpen"
      :project-path="fullPath"
      :has-content="hasSavedContent"
      :has-remote-flows-enabled="hasRemoteFlowsEnabled"
      :work-item-id="workItemId"
      :work-item-iid="workItemIid"
      :work-item-type="workItemType"
      :work-item-web-url="workItemWebUrl"
      @open="openPanel"
      @open-chat-request="onGenerateRequested"
      @open-chat-completed="onAgentHandoff"
    />
    <work-plan-panel
      :open="isPanelOpen"
      :work-item-id="workItemId"
      :work-item-iid="workItemIid"
      :work-item-type="workItemType"
      :work-item-web-url="workItemWebUrl"
      :has-remote-flows-enabled="hasRemoteFlowsEnabled"
      :saved-content="content"
      :draft-content="draftContent"
      :can-update="canUpdate"
      :is-editing="isEditing"
      :is-saving="isSaving"
      @start-edit="handleStartEdit"
      @cancel-edit="handleCancelEdit"
      @save="handleSave"
      @delete="handleDelete"
      @regenerate="handleRegenerate"
      @draft-change="handleDraftChange"
      @close="closePanel"
    />
  </div>
</template>
