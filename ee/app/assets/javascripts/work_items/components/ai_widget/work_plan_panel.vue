<script>
import { isEmpty } from 'lodash-es';
import { GlButton, GlDisclosureDropdown, GlEmptyState, GlTooltipDirective } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/status/status-new-sm.svg';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import EditorModeSwitcher from '~/vue_shared/components/markdown/editor_mode_switcher.vue';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import { EDITING_MODE_MARKDOWN_FIELD, EDITING_MODE_CONTENT_EDITOR } from '~/vue_shared/constants';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import DuoWorkItemToMrAction from 'ee/ai/shared/widgets/duo_work_item_to_mr_action.vue';
import { s__ } from '~/locale';
import { updateHistory, setUrlParams, removeParams, queryToObject } from '~/lib/utils/url_utility';
import { DETAIL_VIEW_QUERY_PARAM_NAME } from '~/work_items/constants';
import namespacePathsQuery from '~/work_items/graphql/namespace_paths.query.graphql';
import {
  buildWorkPlanChatCommand,
  WORKPLAN_GOAL_PREFIX,
  GENERATE_MR_BUTTON_OPTIONS,
} from './constants';

const PANEL_URL_VALUE = 'workplan';
const RESTRICTED_TOOLBAR_ITEMS = ['full-screen'];
const SWITCHER_VALUE_MARKDOWN = 'markdown';
const SWITCHER_VALUE_RICH_TEXT = 'richText';

export default {
  name: 'WorkPlanPanel',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    EditorModeSwitcher,
    GlButton,
    GlDisclosureDropdown,
    GlEmptyState,
    MarkdownEditor,
    MountingPortal,
    NonGfmMarkdown,
    DuoChatQuickAction,
    DuoWorkItemToMrAction,
  },
  emptyStateSvg,
  inject: ['fullPath'],
  inheritAttrs: false,
  props: {
    open: {
      type: Boolean,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    savedContent: {
      type: String,
      required: true,
    },
    draftContent: {
      type: String,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    isSaving: {
      type: Boolean,
      required: true,
    },
    workItemIid: {
      type: [String, Number],
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    workItemWebUrl: {
      type: String,
      required: true,
    },
    hasRemoteFlowsEnabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['close', 'save', 'delete', 'draft-change', 'start-edit', 'cancel-edit', 'regenerate'],
  data() {
    return {
      tmpContent: this.draftContent || this.savedContent,
      markdownPaths: {},
      editorMode: EDITING_MODE_MARKDOWN_FIELD,
      formFieldProps: {
        id: 'agent-plan',
        name: 'agent-plan',
        'aria-label': s__('AgentPlan|Workplan'),
      },
    };
  },
  computed: {
    areMarkdownPathsLoaded() {
      return !isEmpty(this.markdownPaths);
    },
    isEditingAllowed() {
      return this.canUpdate && !this.isEditing;
    },
    hasSavedContent() {
      return Boolean(this.savedContent);
    },
    showGenerateMrAction() {
      return this.hasRemoteFlowsEnabled && !this.isEditing && this.hasSavedContent;
    },
    nextEditorMode() {
      return this.editorMode === EDITING_MODE_MARKDOWN_FIELD
        ? EDITING_MODE_CONTENT_EDITOR
        : EDITING_MODE_MARKDOWN_FIELD;
    },
    editorSwitcherValue() {
      return this.editorMode === EDITING_MODE_MARKDOWN_FIELD
        ? SWITCHER_VALUE_MARKDOWN
        : SWITCHER_VALUE_RICH_TEXT;
    },
    emptyStateText() {
      return s__(
        "AgentPlan|No workplan has been added yet. You don't have permission to create or edit the workplan.",
      );
    },
    panelHeading() {
      return s__('AgentPlan|Workplan');
    },
    editMoreActions() {
      const actions = [];
      if (this.hasSavedContent) {
        actions.push({
          text: s__('AgentPlan|Regenerate workplan'),
          icon: 'tanuki-ai',
          action: () => this.$emit('regenerate'),
        });
        actions.push({
          text: s__('AgentPlan|Delete workplan'),
          icon: 'remove',
          action: () => this.deletePlan(),
          variant: 'danger',
        });
      }
      return actions;
    },
    generateWorkplanQuickAction() {
      return {
        command: buildWorkPlanChatCommand(this.workItemWebUrl),
        tracking: { label: 'create_work_plan' },
        buttonOptions: { variant: 'confirm', category: 'primary' },
      };
    },
  },
  watch: {
    open(value) {
      if (value) {
        this.addPanelParam();
      } else {
        this.removePanelParam();
      }
    },
    isEditing(value) {
      if (value) {
        this.tmpContent = this.draftContent || this.savedContent;
      }
    },
  },
  created() {
    if (this.open) {
      this.addPanelParam();
    }
  },
  mounted() {
    document.addEventListener('keydown', this.handleKeydown);
  },
  beforeDestroy() {
    document.removeEventListener('keydown', this.handleKeydown);
  },
  apollo: {
    markdownPaths: {
      query: namespacePathsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data?.namespace?.markdownPaths || {};
      },
      skip() {
        return !this.fullPath;
      },
    },
  },
  methods: {
    addPanelParam() {
      const currentValue = queryToObject(window.location.search)?.[DETAIL_VIEW_QUERY_PARAM_NAME];
      if (currentValue === PANEL_URL_VALUE) {
        return;
      }
      updateHistory({
        url: setUrlParams({ [DETAIL_VIEW_QUERY_PARAM_NAME]: PANEL_URL_VALUE }),
      });
    },
    removePanelParam() {
      const currentValue = queryToObject(window.location.search)?.[DETAIL_VIEW_QUERY_PARAM_NAME];
      if (currentValue === PANEL_URL_VALUE) {
        updateHistory({ url: removeParams([DETAIL_VIEW_QUERY_PARAM_NAME]) });
      }
    },
    handleClose() {
      const active = document.activeElement;
      const activeTag = active?.tagName;
      if (
        document.body.classList.contains('modal-open') ||
        active?.closest('.js-editor') != null ||
        activeTag === 'INPUT' ||
        activeTag === 'TEXTAREA'
      ) {
        return;
      }
      this.$emit('close');
    },
    handleKeydown({ key }) {
      if (key === 'Escape' && this.open) {
        this.handleClose();
      }
    },
    toggleEditorMode() {
      this.$refs.markdownEditor?.onEditingModeChange(this.nextEditorMode);
    },
    onEditorModeSynced(mode) {
      this.editorMode = mode;
    },
    cancelEdit() {
      this.$emit('cancel-edit');
    },
    savePlan() {
      this.$emit('save', this.tmpContent?.trim() || '');
    },
    deletePlan() {
      this.tmpContent = '';
      this.$emit('delete');
    },
    handleInput(value) {
      this.tmpContent = value;
      this.$emit('draft-change', value);
    },
  },
  RESTRICTED_TOOLBAR_ITEMS,
  EDITING_MODE_MARKDOWN_FIELD,
  EDITING_MODE_CONTENT_EDITOR,
  WORKPLAN_GOAL_PREFIX,
  generateMrButtonOptions: GENERATE_MR_BUTTON_OPTIONS,
};
</script>

<template>
  <mounting-portal v-if="open" mount-to="#contextual-panel-portal" append>
    <div data-testid="work-plan-panel" class="work-item-detail-panel gl-leading-reset">
      <div class="work-item-detail-panel-header">
        <div class="gl-flex gl-h-full gl-min-w-0 gl-grow gl-items-center gl-gap-2">
          <span
            class="gl-truncate gl-text-sm gl-font-bold gl-text-default"
            data-testid="work-plan-panel-title"
          >
            {{ panelHeading }}
          </span>
        </div>
        <duo-work-item-to-mr-action
          v-if="showGenerateMrAction"
          run-duo-developer-in-chat
          :project-path="fullPath"
          :work-item-iid="workItemIid"
          :work-item-type="workItemType"
          :work-item-web-url="workItemWebUrl"
          :additional-goal-context="$options.WORKPLAN_GOAL_PREFIX"
          :generate-mr-button-options="$options.generateMrButtonOptions"
          data-testid="panel-generate-mr-with-duo"
        />
        <template v-if="isEditingAllowed">
          <gl-button
            size="small"
            category="secondary"
            data-testid="panel-edit-button"
            @click="$emit('start-edit')"
          >
            {{ s__('AgentPlan|Edit') }}
          </gl-button>
          <gl-disclosure-dropdown
            v-if="editMoreActions.length"
            v-gl-tooltip.bottom
            size="small"
            category="tertiary"
            icon="ellipsis_v"
            no-caret
            text-sr-only
            :toggle-text="__('More actions')"
            :title="__('More actions')"
            :items="editMoreActions"
            data-testid="panel-edit-more-actions"
          />
        </template>
        <gl-button
          v-gl-tooltip.bottom
          class="gl-detail-panel-close-button"
          data-testid="panel-close-button"
          category="tertiary"
          icon="close"
          size="small"
          :aria-label="__('Close panel')"
          :title="__('Close panel')"
          @click="handleClose"
        />
      </div>
      <div
        :class="
          isEditing
            ? 'gl-flex gl-min-h-0 gl-flex-1 gl-flex-col'
            : 'work-item-detail-panel-content gl-px-5 gl-pt-4'
        "
      >
        <template v-if="!isEditing">
          <template v-if="!hasSavedContent">
            <gl-empty-state
              v-if="canUpdate"
              data-testid="work-plan-empty-state"
              :svg-path="$options.emptyStateSvg"
              :svg-height="72"
              content-class="!gl-px-0"
              :title="s__('AgentPlan|Create a workplan')"
              :description="
                s__(
                  'AgentPlan|A workplan breaks down your work item into a step-by-step implementation guide for GitLab Duo to execute. Create one manually or let Duo generate it for you.',
                )
              "
            >
              <template #actions>
                <div class="gl-flex gl-flex-wrap gl-justify-center gl-gap-3">
                  <duo-chat-quick-action
                    :resource-id="workItemId"
                    :button-text="s__('AgentPlan|Generate')"
                    :command="generateWorkplanQuickAction.command"
                    :tracking-info="generateWorkplanQuickAction.tracking"
                    :button-options="generateWorkplanQuickAction.buttonOptions"
                    data-testid="panel-generate-with-duo-button"
                  />
                  <gl-button
                    category="secondary"
                    data-testid="panel-create-manually-button"
                    @click="$emit('start-edit')"
                  >
                    {{ s__('AgentPlan|Create manually') }}
                  </gl-button>
                </div>
              </template>
            </gl-empty-state>
            <p v-else data-testid="work-plan-empty-state" class="gl-mb-0 gl-text-subtle">
              {{ emptyStateText }}
            </p>
          </template>
          <template v-else>
            <non-gfm-markdown :markdown="savedContent" data-testid="work-plan-rendered" />
          </template>
        </template>
        <template v-else>
          <div class="common-note-form gl-flex gl-min-h-0 gl-flex-1 gl-flex-col">
            <!--
              eslint-disable vue/v-on-event-hyphenation
            -->
            <markdown-editor
              v-if="areMarkdownPathsLoaded"
              ref="markdownEditor"
              :value="tmpContent"
              :render-markdown-path="markdownPaths.markdownPreviewPath"
              :uploads-path="markdownPaths.uploadsPath"
              :form-field-props="formFieldProps"
              :enable-autocomplete="false"
              autofocus
              immersive
              fill-container
              hide-mode-switcher
              enable-content-editor
              :restricted-tool-bar-items="$options.RESTRICTED_TOOLBAR_ITEMS"
              data-testid="work-plan-editor"
              @input="handleInput"
              @keydown.meta.enter="savePlan"
              @keydown.ctrl.enter="savePlan"
              @markdownField="onEditorModeSynced($options.EDITING_MODE_MARKDOWN_FIELD)"
              @contentEditor="onEditorModeSynced($options.EDITING_MODE_CONTENT_EDITOR)"
            >
              <template #header>
                <div
                  class="gl-flex gl-items-center gl-justify-between gl-gap-2 gl-py-2 gl-pl-2 gl-pr-5"
                >
                  <editor-mode-switcher
                    :value="editorSwitcherValue"
                    data-testid="work-plan-editor-mode-switcher"
                    @switch="toggleEditorMode"
                  />
                  <div class="gl-flex gl-gap-2">
                    <gl-button
                      :disabled="isSaving"
                      size="small"
                      data-testid="cancel-work-plan-button"
                      @click="cancelEdit"
                    >
                      {{ __('Cancel') }}
                    </gl-button>
                    <gl-button
                      variant="confirm"
                      size="small"
                      :loading="isSaving"
                      data-testid="save-work-plan-button"
                      @click="savePlan"
                    >
                      {{ __('Save changes') }}
                    </gl-button>
                  </div>
                </div>
              </template>
            </markdown-editor>
            <!-- eslint-enable vue/v-on-event-hyphenation -->
          </div>
        </template>
      </div>
    </div>
  </mounting-portal>
</template>
