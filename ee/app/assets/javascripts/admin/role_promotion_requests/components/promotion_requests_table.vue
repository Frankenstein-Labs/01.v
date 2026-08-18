<script>
import { GlTable, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import UserAvatar from '~/vue_shared/components/users_table/user_avatar.vue';

export default {
  name: 'PromotionRequestsTable',
  components: {
    GlTable,
    GlButton,
    UserAvatar,
    UserDate,
  },
  inject: ['paths'],
  props: {
    list: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['approve', 'reject'],
  fields: [
    {
      key: 'name',
      label: __('Name'),
    },
    {
      key: 'requestedRole',
      label: s__('PromotionRequests|Highest role requested'),
    },
    {
      key: 'lastActivity',
      label: __('Last activity'),
    },
    {
      key: 'actions',
      label: __('Actions'),
    },
  ],
};
</script>

<template>
  <div>
    <gl-table
      :items="list"
      :fields="$options.fields"
      :empty-text="s__('PromotionRequests|No promotion requests found')"
      show-empty
      stacked="md"
      :busy="isLoading"
    >
      <template #cell(name)="{ item: { user } }">
        <user-avatar :user="user" :admin-user-path="paths.adminUser" />
      </template>

      <template #cell(requestedRole)="{ item: { newAccessLevel } }">
        {{ newAccessLevel.stringValue }}
      </template>

      <template #cell(lastActivity)="{ item: { user } }">
        <user-date :date="user.lastActivityOn" />
      </template>

      <template #head(actions)="{ label }">
        <span class="gl-sr-only">{{ label }}</span>
      </template>

      <template #cell(actions)="{ item: { user } }">
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-button @click="$emit('reject', user.id)">{{ __('Reject') }}</gl-button>
          <gl-button variant="confirm" @click="$emit('approve', user.id)">{{
            __('Approve')
          }}</gl-button>
        </div>
      </template>
    </gl-table>
  </div>
</template>
