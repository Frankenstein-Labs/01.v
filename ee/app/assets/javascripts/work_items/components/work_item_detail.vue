<script>
import WorkItemDetail from '~/work_items/components/work_item_detail.vue';
import WorkItemAiWidget from 'ee/work_items/components/ai_widget/work_item_ai_widget.vue';
import WorkItemAgentSessions from 'ee/work_items/components/agent_sessions/index.vue';
import WorkItemDecisionLog from 'ee/work_items/components/decision_log/work_item_decision_log.vue';
import { AGENT_PLAN_PANEL } from '~/work_items/constants';
import { findAgentPlanWidget } from 'ee/work_items/utils';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'WorkItemDetailEE',
  AGENT_PLAN_PANEL,
  components: {
    WorkItemDetail,
    WorkItemAiWidget,
    WorkItemAgentSessions,
    WorkItemDecisionLog,
  },
  mixins: [glListenersMixin, glFeatureFlagsMixin()],
  inheritAttrs: false,
  methods: {
    isAgentPlanAvailable(workItem) {
      return Boolean(findAgentPlanWidget(workItem));
    },
    // The decision log records the choices made while a workplan is refined, so it is only
    // meaningful on the work items that have one.
    isDecisionLogAvailable(workItem) {
      return Boolean(this.glFeatures.workplanDecisionLog) && this.isAgentPlanAvailable(workItem);
    },
  },
};
</script>

<template>
  <work-item-detail v-bind="$attrs" v-on="glListeners()">
    <template #widgets-top="{ workItem, isDetailPanel, activePanel, editMode, requestPanel }">
      <!-- eslint-disable local-rules/vue-no-web-url -- Internal drawer-redirect URL; webUrl is what the work-item fragment already exposes. -->
      <work-item-ai-widget
        v-if="workItem && isAgentPlanAvailable(workItem) && !editMode"
        :work-item="workItem"
        :work-item-web-url="workItem.webUrl"
        :is-in-drawer="isDetailPanel"
        :is-panel-open="activePanel === $options.AGENT_PLAN_PANEL"
        :can-update="workItem.userPermissions?.updateWorkItem"
        class="gl-mb-5"
        @request-panel="requestPanel"
      />
      <!-- eslint-enable local-rules/vue-no-web-url -->
    </template>
    <template #widgets="{ workItem }">
      <work-item-decision-log v-if="isDecisionLogAvailable(workItem)" class="gl-mb-5" />
      <work-item-agent-sessions v-if="workItem" :work-item-id="workItem.id" />
    </template>
  </work-item-detail>
</template>
