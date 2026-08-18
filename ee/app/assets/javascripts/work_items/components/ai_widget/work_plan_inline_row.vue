<script>
import { GlButton, GlButtonGroup, GlDisclosureDropdown, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import DuoWorkItemToMrAction from 'ee/ai/shared/widgets/duo_work_item_to_mr_action.vue';
import {
  buildWorkPlanChatCommand,
  WORKPLAN_GOAL_PREFIX,
  GENERATE_MR_BUTTON_OPTIONS,
} from './constants';
import WorkPlanStatusBar from './work_plan_status_bar.vue';

export default {
  name: 'WorkPlanInlineRow',
  components: {
    GlButton,
    GlButtonGroup,
    GlLink,
    GlSprintf,
    HelpPopover,
    GlDisclosureDropdown,
    DuoChatQuickAction,
    DuoWorkItemToMrAction,
    WorkPlanStatusBar,
  },
  props: {
    hasContent: {
      type: Boolean,
      required: false,
      default: false,
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    isPanelOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: String,
      required: false,
      default: null,
    },
    workItemType: {
      type: String,
      required: false,
      default: null,
    },
    workItemWebUrl: {
      type: String,
      required: false,
      default: '',
    },
    hasRemoteFlowsEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['open', 'open-chat-request', 'open-chat-completed'],
  computed: {
    helpPopoverOptions() {
      return {
        title: s__('AgentPlan|What is a workplan?'),
      };
    },
    workPlanChatCommand() {
      return buildWorkPlanChatCommand(this.workItemWebUrl);
    },
    statusLabel() {
      if (!this.hasContent) {
        return this.canUpdate ? s__('AgentPlan|Not yet created') : s__('AgentPlan|No workplan');
      }
      return s__('AgentPlan|Ready for review');
    },
    showWorkplanToggle() {
      return this.hasContent;
    },
    showCreateWorkPlanAction() {
      return !this.hasContent && this.canUpdate;
    },
    showGenerateMrAction() {
      return this.hasRemoteFlowsEnabled && this.hasContent && this.canUpdate;
    },
    showActionsDivider() {
      return this.showWorkplanToggle && this.showGenerateMrAction;
    },
  },
  createWorkplanDropdownItems: [
    {
      text: s__('AgentPlan|Create manually'),
      extraAttrs: {
        'data-testid': 'create-workplan-dropdown-item',
      },
    },
  ],
  duoQuickAction: {
    tracking: { label: 'create_work_plan' },
    buttonOptions: { size: 'medium' },
  },
  WORKPLAN_GOAL_PREFIX,
  generateMrButtonOptions: GENERATE_MR_BUTTON_OPTIONS,
  workplanHelpPath: helpPagePath('user/work_items/workplan'),
};
</script>

<template>
  <div
    data-testid="work-plan-inline-row"
    class="gl-relative gl-flex gl-w-fit gl-flex-wrap gl-items-stretch gl-justify-between gl-gap-x-6 gl-gap-y-4 gl-rounded-2xl"
  >
    <div class="gl-flex gl-gap-4">
      <div class="gl-flex gl-flex-row gl-items-stretch gl-gap-4">
        <work-plan-status-bar
          :variant="hasContent ? 'success' : 'neutral'"
          :aria-label="statusLabel"
        />

        <div class="gl-flex gl-flex-col gl-gap-2 gl-text-sm">
          <div class="gl-flex gl-items-end gl-gap-2">
            <span
              class="gl-text-xs gl-font-semibold gl-uppercase gl-tracking-widest gl-text-control-placeholder"
              >{{ s__('AgentPlan|Workplan') }}
            </span>
            <help-popover v-if="!hasContent" :options="helpPopoverOptions" class="gl-inline-flex">
              <gl-sprintf
                :message="
                  s__(
                    'AgentPlan|A workplan breaks a work item into clear, ordered steps that guide implementation. Create one manually, or generate it with GitLab Duo. %{linkStart}Learn more%{linkEnd}.',
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="$options.workplanHelpPath" target="_blank">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </help-popover>
          </div>
          <span class="gl-text-subtle">{{ statusLabel }}</span>
        </div>
      </div>
      <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-5">
        <gl-button
          v-if="showWorkplanToggle"
          :aria-pressed="String(isPanelOpen)"
          category="secondary"
          data-testid="open-work-plan-button"
          @click="$emit('open')"
        >
          {{ __('View') }}
        </gl-button>
        <div
          v-if="showActionsDivider"
          data-testid="duo-divider"
          class="gl-border-l gl-h-6 gl-border-subtle"
        ></div>
        <gl-button-group v-if="showCreateWorkPlanAction">
          <duo-chat-quick-action
            :resource-id="workItemId"
            :button-text="s__('AgentPlan|Generate')"
            :command="workPlanChatCommand"
            :tracking-info="$options.duoQuickAction.tracking"
            :button-options="$options.duoQuickAction.buttonOptions"
            data-testid="inline-generate-with-duo-button"
            @click="$emit('open-chat-request')"
            @chat-opened="$emit('open-chat-completed')"
          />
          <gl-disclosure-dropdown
            :items="$options.createWorkplanDropdownItems"
            :toggle-text="s__('AgentPlan|More options')"
            text-sr-only
            placement="bottom-end"
            data-testid="create-workplan-dropdown"
            @action="$emit('open')"
          />
        </gl-button-group>
        <duo-work-item-to-mr-action
          v-if="showGenerateMrAction"
          run-duo-developer-in-chat
          :project-path="projectPath"
          :work-item-iid="workItemIid"
          :work-item-type="workItemType"
          :work-item-web-url="workItemWebUrl"
          :additional-goal-context="$options.WORKPLAN_GOAL_PREFIX"
          :generate-mr-button-options="$options.generateMrButtonOptions"
          data-testid="generate-mr-with-duo"
        />
      </div>
    </div>
  </div>
</template>
