<script>
import { s__ } from '~/locale';
import BoardNewIssueFoss from '~/boards/components/board_new_issue.vue';
import { setError } from '~/boards/graphql/cache_updates';
import { formatIssueInput } from '../boards_util';
import { IterationIDs } from '../constants';

import currentIterationQuery from '../graphql/board_current_iteration.query.graphql';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'BoardNewIssue',
  extends: BoardNewIssueFoss,
  emits: ['add-new-issue'],
  data() {
    return {
      currentIteration: {},
    };
  },
  apollo: {
    currentIteration: {
      query: currentIterationQuery,
      context: {
        isSingleRequest: true,
      },
      variables() {
        return {
          isGroup: this.isGroupBoard,
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data[this.boardType]?.iterations?.nodes?.[0];
      },
      skip() {
        const { iteration, iterationCadence } = this.board;
        return iteration?.id !== IterationIDs.CURRENT || iterationCadence?.id !== undefined;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|No cadence matches current iteration filter'),
        });
      },
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- This component inherits from `BoardNewIssueFoss` which calls `addNewIssueToList()` internally
    async addNewIssueToList({ issueInput }) {
      const { labels, assignee, milestone, weight, iteration, iterationCadence } = this.board;
      const config = {
        labels,
        assigneeId: assignee?.id || null,
        milestoneId: milestone?.id || null,
        weight,
      };

      const statusId = this.list?.status?.id;

      const modifiedIssueInput = { ...issueInput };
      if (statusId) {
        modifiedIssueInput.statusId = statusId;
      }

      if (iteration?.id !== IterationIDs.NONE) {
        config.iterationId = iteration?.id || null;
        config.iterationCadenceId = iterationCadence?.id || null;
      }

      // When board is scoped to current iteration we need to fetch and assign a cadence to the issue being created
      if (!config.iterationCadenceId && config.iterationId === IterationIDs.CURRENT) {
        config.iterationCadenceId = await this.fetchCurrentIterationCadenceId();

        // The backend requires the cadence to resolve the current iteration
        // wildcard. If it is unavailable the error has already been surfaced,
        // so abort rather than silently creating an issue without an iteration.
        if (!config.iterationCadenceId) {
          return;
        }
      }

      const input = formatIssueInput(modifiedIssueInput, config);

      if (!this.isGroupBoard) {
        input.projectPath = this.fullPath;
      }

      this.$emit('add-new-issue', input);
    },
    // The `currentIteration` query is skipped until the `board` query resolves,
    // so it can still be in flight when the issue is submitted. Refetch it on
    // demand to guarantee the current iteration's cadence is available.
    async fetchCurrentIterationCadenceId() {
      if (this.currentIteration?.iterationCadence?.id) {
        return this.currentIteration.iterationCadence.id;
      }
      const { data } = await this.$apollo.queries.currentIteration.refetch();
      return data?.[this.boardType]?.iterations?.nodes?.[0]?.iterationCadence?.id || null;
    },
  },
};
</script>
