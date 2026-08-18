<script>
import { GlSprintf, GlAlert, GlButton, GlTooltipDirective, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { BASE_ROLES_WITHOUT_MINIMAL_ACCESS } from '~/access_level/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { TYPENAME_MEMBER_ROLE } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DeleteRoleModal from '../delete_role_modal.vue';
import memberRoleQuery from '../../graphql/role_details/member_role.query.graphql';
import adminRoleQuery from '../../graphql/admin_role/role.query.graphql';
import DeleteRoleTooltipWrapper from '../delete_role_tooltip_wrapper.vue';
import { isRoleInUse } from '../../utils';
import RoleDetailsContent from './role_details_content.vue';

export const DETAILS_QUERYSTRING = 'from_details';

export default {
  name: 'RoleDetails',
  components: {
    GlSprintf,
    RoleDetailsContent,
    DeleteRoleTooltipWrapper,
    GlAlert,
    GlButton,
    GlLoadingIcon,
    DeleteRoleModal,
    PageHeading,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    roleId: {
      type: String,
      required: true,
    },
    listPagePath: {
      type: String,
      required: true,
    },
    isAdminRole: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      memberRole: null,
      roleToDelete: null,
    };
  },
  apollo: {
    memberRole: {
      query() {
        return this.isAdminRole ? adminRoleQuery : memberRoleQuery;
      },
      variables() {
        return { id: convertToGraphQLId(TYPENAME_MEMBER_ROLE, this.roleId) };
      },
      error() {
        this.memberRole = null;
      },
      skip() {
        return Boolean(this.standardRole);
      },
    },
  },
  computed: {
    standardRole() {
      return BASE_ROLES_WITHOUT_MINIMAL_ACCESS.find(
        ({ value }) => value === this.roleId.toUpperCase(),
      );
    },
    role() {
      return this.memberRole || this.standardRole;
    },
    headerDescription() {
      return this.memberRole
        ? s__('MemberRole|Custom role created on %{dateTime}')
        : s__('MemberRole|This role is available by default and cannot be changed.');
    },
    createdDate() {
      return localeDateFormat.asDate.format(this.role.createdAt);
    },
    isRoleInUse() {
      return isRoleInUse(this.role);
    },
    editRolePath() {
      return `${this.role.editPath}?${DETAILS_QUERYSTRING}`;
    },
  },
  methods: {
    navigateToListPage() {
      visitUrl(this.listPagePath);
    },
  },
};
</script>

<template>
  <gl-loading-icon v-if="$apollo.queries.memberRole.loading" size="md" class="gl-mt-5" />

  <gl-alert v-else-if="!role" variant="danger" class="gl-mt-5" :dismissible="false">
    {{ s__('MemberRole|Failed to fetch role.') }}
  </gl-alert>

  <div v-else data-testid="role-details">
    <page-heading :heading="role.name || role.text" inline-actions>
      <template #description>
        <gl-sprintf :message="headerDescription">
          <template #dateTime>{{ createdDate }}</template>
        </gl-sprintf>
      </template>

      <template v-if="memberRole" #actions>
        <div class="gl-flex gl-gap-3">
          <gl-button
            v-gl-tooltip="s__('MemberRole|Edit role')"
            icon="pencil"
            :href="editRolePath"
            data-testid="edit-button"
          />
          <delete-role-tooltip-wrapper :role="role">
            <gl-button
              v-gl-tooltip="s__('MemberRole|Delete role')"
              icon="remove"
              category="secondary"
              variant="danger"
              :disabled="isRoleInUse"
              :aria-label="s__('MemberRole|Delete role')"
              data-testid="delete-button"
              @click="roleToDelete = role"
            />
            <delete-role-modal
              :role="roleToDelete"
              @deleted="navigateToListPage"
              @close="roleToDelete = null"
            />
          </delete-role-tooltip-wrapper>
        </div>
      </template>
    </page-heading>

    <role-details-content :role="role" />
  </div>
</template>
