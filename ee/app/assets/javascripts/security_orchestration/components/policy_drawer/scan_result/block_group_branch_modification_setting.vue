<script>
import { GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import getGroupsByIds from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';

export default {
  name: 'BlockGroupBranchModificationSetting',
  i18n: {
    title: s__('SecurityOrchestration|Override the following project settings:'),
    blockGroupBranchModificationExceptions: s__('SecurityOrchestration|exceptions: %{exceptions}'),
    groupNameText: s__('SecurityOrchestration|Group ID: %{id}'),
  },
  apollo: {
    exceptionGroups: {
      query: getGroupsByIds,
      variables() {
        return {
          ids: this.ids,
        };
      },
      update(data) {
        return (
          data.groups?.nodes?.map((group) => ({ ...group, id: getIdFromGraphQLId(group.id) })) || []
        );
      },
      skip() {
        return this.ids.length === 0;
      },
    },
  },
  components: {
    GlSprintf,
  },
  props: {
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      exceptionGroups: [],
    };
  },
  computed: {
    ids() {
      return this.exceptions.map(({ id }) => convertToGraphQLId(TYPENAME_GROUP, id));
    },
    exceptionStrings() {
      return this.exceptionGroups.map(({ fullName, id }) => fullName || this.getDefaultName(id));
    },
  },
  methods: {
    getDefaultName(id) {
      return sprintf(this.$options.i18n.groupNameText, { id });
    },
  },
};
</script>

<template>
  <div class="gl-ml-5 gl-mt-2">
    <gl-sprintf :message="$options.i18n.blockGroupBranchModificationExceptions">
      <template #exceptions>
        <ul data-testid="group-branch-exceptions">
          <li v-for="exception in exceptionStrings" :key="exception" class="gl-mt-2">
            {{ exception }}
          </li>
        </ul>
      </template>
    </gl-sprintf>
  </div>
</template>
