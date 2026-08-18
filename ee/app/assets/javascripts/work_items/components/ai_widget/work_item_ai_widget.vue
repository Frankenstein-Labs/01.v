<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WorkItemConfidenceScore from './work_item_confidence_score.vue';
import WorkPlan from './work_plan.vue';

export default {
  name: 'WorkItemAiWidget',
  components: {
    WorkItemConfidenceScore,
    WorkPlan,
  },
  mixins: [glFeatureFlagsMixin()],
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
      // The backend does not provide a readiness score yet. While the
      // `workplan_score` flag is off by default, we mock the value client-side
      // so the score UI can be exercised.
      // TODO: replace with the GraphQL field. https://gitlab.com/gitlab-org/gitlab/-/work_items/608260
      workItemScore: Math.random(),
    };
  },
  computed: {
    showScore() {
      return Boolean(this.glFeatures?.workplanScore);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-6 gl-py-6 md:gl-flex-row md:gl-items-center">
    <work-plan
      :work-item="workItem"
      :can-update="canUpdate"
      :work-item-web-url="workItemWebUrl"
      :is-in-drawer="isInDrawer"
      :is-panel-open="isPanelOpen"
      @request-panel="$emit('request-panel', $event)"
    />
    <work-item-confidence-score v-if="showScore" :score="workItemScore" />
  </div>
</template>
