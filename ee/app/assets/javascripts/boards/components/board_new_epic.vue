<script>
import { s__ } from '~/locale';
import BoardNewItem from '~/boards/components/board_new_item.vue';
import { setError } from '~/boards/graphql/cache_updates';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import epicBoardQuery from '../graphql/epic_board.query.graphql';

import GroupSelect from './group_select.vue';

export default {
  name: 'BoardNewEpic',
  i18n: {
    errorFetchingBoard: s__('Boards|An error occurred while fetching board. Please try again.'),
  },
  components: {
    BoardNewItem,
    GroupSelect,
  },
  inject: ['fullPath'],
  props: {
    list: {
      type: Object,
      required: true,
    },
    boardId: {
      type: String,
      required: true,
    },
  },
  emits: ['add-new-epic', 'toggle-new-form'],
  data() {
    return {
      selectedGroup: {},
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    board: {
      query: epicBoardQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          boardId: this.boardId,
        };
      },
      update(data) {
        const { board } = data.namespace;
        return {
          ...board,
          labels: board.labels?.nodes,
        };
      },
      error(error) {
        setError({
          error,
          message: this.$options.i18n.errorFetchingBoard,
        });
      },
    },
  },
  computed: {
    groupPath() {
      return this.selectedGroup?.fullPath ?? this.fullPath;
    },
  },
  methods: {
    submit({ title }) {
      const labels = this.list.label ? [this.list.label] : [];

      return this.addNewEpicToList({
        epicInput: {
          title,
          labelIds: labels?.map((l) => getIdFromGraphQLId(l.id)),
          groupPath: this.groupPath,
        },
      });
    },
    addNewEpicToList({ epicInput }) {
      const { labelIds = [], ...restEpicInput } = epicInput;
      const { labels } = this.board;
      const boardLabelIds = labels.map(({ id }) => getIdFromGraphQLId(id));

      this.$emit('add-new-epic', {
        ...restEpicInput,
        addLabelIds: [...labelIds, ...boardLabelIds],
      });
    },
    cancel() {
      this.$emit('toggle-new-form');
    },
  },
};
</script>

<template>
  <board-new-item
    :list="list"
    :submit-button-title="__('Create epic')"
    @form-submit="submit"
    @form-cancel="cancel"
  >
    <group-select v-model="selectedGroup" />
  </board-new-item>
</template>
