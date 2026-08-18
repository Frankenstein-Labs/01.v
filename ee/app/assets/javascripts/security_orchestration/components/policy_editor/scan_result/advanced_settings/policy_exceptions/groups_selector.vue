<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';

export default {
  i18n: {
    title: s__('ScanResultPolicy|Groups'),
    groupSelectorLabel: s__('ScanResultPolicy|Select group exceptions'),
    groupSelectorDescription: s__('ScanResultPolicy|Choose which groups can bypass this policy'),
  },
  name: 'GroupsSelector',
  components: {
    GlFormGroup,
    ScopedGroupsDropdown,
  },
  inject: ['assignedPolicyProject'],
  props: {
    selectedGroups: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['set-groups'],
  data() {
    return {
      groups: this.selectedGroups,
    };
  },
  computed: {
    assignedPolicyProjectPath() {
      return this.assignedPolicyProject?.fullPath || '';
    },
    selectedIds() {
      return this.groups.map(({ id }) => convertToGraphQLId(TYPENAME_GROUP, id));
    },
  },
  methods: {
    setGroups(groups) {
      this.groups = groups;
      this.$emit(
        'set-groups',
        this.selectedIds.map((id) => ({ id: getIdFromGraphQLId(id) })),
      );
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <gl-form-group
      id="groups-list"
      class="gl-w-full"
      :optional="false"
      label-for="groups-list"
      :label="$options.i18n.groupSelectorLabel"
      :description="$options.i18n.groupSelectorDescription"
    >
      <scoped-groups-dropdown
        state
        include-descendants
        :full-path="assignedPolicyProjectPath"
        :selected="selectedIds"
        @select="setGroups"
      />
    </gl-form-group>
  </div>
</template>
