<script>
import { s__ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import DecisionLogItem from './decision_log_item.vue';
import { DECIDED_DECISION_STATUSES, buildStubbedDecisions } from './constants';

export default {
  name: 'WorkItemDecisionLog',
  components: {
    CrudComponent,
    DecisionLogItem,
  },
  data() {
    return {
      // TODO: Replace with the `decisionLog` widget once it is exposed over GraphQL.
      // https://gitlab.com/gitlab-org/gitlab/-/merge_requests/248505
      decisions: buildStubbedDecisions(),
    };
  },
  computed: {
    // References are positional (DL-001, DL-002...) and follow the order the decisions are listed
    // in, so they stay stable for as long as the list does.
    references() {
      return this.decisions.reduce((acc, decision, index) => {
        acc[decision.id] = `DL-${String(index + 1).padStart(3, '0')}`;
        return acc;
      }, {});
    },
    pendingDecisions() {
      return this.decisions.filter(
        (decision) => !DECIDED_DECISION_STATUSES.includes(decision.status),
      );
    },
    decidedDecisions() {
      return this.decisions.filter((decision) =>
        DECIDED_DECISION_STATUSES.includes(decision.status),
      );
    },
  },
  i18n: {
    title: s__('WorkItemDecisionLog|Decision log'),
    pendingHeading: s__('WorkItemDecisionLog|Pending'),
    decidedHeading: s__('WorkItemDecisionLog|Decided'),
  },
};
</script>

<template>
  <crud-component
    :title="$options.i18n.title"
    :count="decisions.length"
    icon="documents"
    is-collapsible
    persist-collapsed-state
    anchor-id="decision-log"
    data-testid="decision-log-widget"
  >
    <section v-if="pendingDecisions.length" data-testid="pending-decisions">
      <h3 class="gl-heading-5 gl-mb-3">
        {{ $options.i18n.pendingHeading }} ({{ pendingDecisions.length }})
      </h3>
      <ul class="gl-m-0 gl-p-0">
        <decision-log-item
          v-for="decision in pendingDecisions"
          :key="decision.id"
          :decision="decision"
          :reference="references[decision.id]"
        />
      </ul>
    </section>

    <section v-if="decidedDecisions.length" data-testid="decided-decisions">
      <h3 class="gl-heading-5 gl-mb-3">
        {{ $options.i18n.decidedHeading }} ({{ decidedDecisions.length }})
      </h3>
      <ul class="gl-m-0 gl-p-0">
        <decision-log-item
          v-for="decision in decidedDecisions"
          :key="decision.id"
          :decision="decision"
          :reference="references[decision.id]"
        />
      </ul>
    </section>
  </crud-component>
</template>
