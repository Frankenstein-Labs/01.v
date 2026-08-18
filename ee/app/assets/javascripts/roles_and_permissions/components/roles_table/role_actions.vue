<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlSprintf,
  GlToastMixin,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isCustomRole, isAdminRole, isRoleInUse } from '../../utils';
import DeleteRoleTooltipWrapper from '../delete_role_tooltip_wrapper.vue';

export default {
  name: 'RoleActions',
  i18n: {
    accessLevelText: s__('MemberRole|Access level: %{id}'),
    roleIdText: s__('MemberRole|Role ID: %{id}'),
    viewDetailsText: __('View details'),
    editRoleText: s__('MemberRole|Edit role'),
    deleteRoleText: s__('MemberRole|Delete role'),
    accessLevelCopied: s__('MemberRole|Access level copied to clipboard'),
    roleIdCopied: s__('MemberRole|Role ID copied to clipboard'),
  },
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    DeleteRoleTooltipWrapper,
    GlSprintf,
  },
  mixins: [GlToastMixin],
  props: {
    role: {
      type: Object,
      required: true,
    },
  },
  emits: ['delete'],
  computed: {
    isCustomOrAdminRole() {
      return isCustomRole(this.role) || isAdminRole(this.role);
    },
    roleId() {
      return this.isCustomOrAdminRole ? getIdFromGraphQLId(this.role.id) : this.role.accessLevel;
    },
    idText() {
      const { roleIdText, accessLevelText } = this.$options.i18n;

      return this.isCustomOrAdminRole ? roleIdText : accessLevelText;
    },
    viewDetailsItem() {
      return { text: this.$options.i18n.viewDetailsText, href: this.role.detailsPath };
    },
    editRoleItem() {
      return { text: this.$options.i18n.editRoleText, href: this.role.editPath };
    },
    dropdownId() {
      return `dropdown-${this.roleId}`;
    },
    deleteRoleItem() {
      const disabled = isRoleInUse(this.role);

      return {
        text: this.$options.i18n.deleteRoleText,
        variant: disabled ? null : 'danger',
        extraAttrs: { disabled },
      };
    },
  },
  methods: {
    showCopiedToClipboardToast() {
      const { roleIdCopied, accessLevelCopied } = this.$options.i18n;
      const toastMessage = this.isCustomOrAdminRole ? roleIdCopied : accessLevelCopied;
      this.$toast.show(toastMessage);
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown category="tertiary" icon="ellipsis_v" placement="bottom-end" no-caret>
    <template #footer>
      <!--
      This is a placeholder for the delete role tooltip/popover to render into. Do not remove it.
      The tooltip/popover needs to render within the disclosure dropdown, otherwise clicks in the
      tooltip/popover are treated as off-clicks from the dropdown, which closes the dropdown and
      in turn hides the tooltip/popover. This means links in the popover won't work because the
      popover is closed before the link click can be processed.
      -->
      <div :id="dropdownId"></div>
    </template>

    <gl-disclosure-dropdown-item
      :data-clipboard-text="roleId"
      data-testid="role-id-item"
      @action="showCopiedToClipboardToast"
    >
      <template #list-item>
        <gl-icon name="copy-to-clipboard" class="gl-mr-2" variant="subtle" />
        <gl-sprintf :message="idText">
          <template #id>{{ roleId }}</template>
        </gl-sprintf>
      </template>
    </gl-disclosure-dropdown-item>

    <gl-disclosure-dropdown-item data-testid="view-details-item" :item="viewDetailsItem" />

    <template v-if="isCustomOrAdminRole">
      <gl-disclosure-dropdown-item data-testid="edit-role-item" :item="editRoleItem" />

      <delete-role-tooltip-wrapper :role="role" :container-id="dropdownId">
        <gl-disclosure-dropdown-item
          data-testid="delete-role-item"
          :item="deleteRoleItem"
          @action="$emit('delete')"
        />
      </delete-role-tooltip-wrapper>
    </template>
  </gl-disclosure-dropdown>
</template>
