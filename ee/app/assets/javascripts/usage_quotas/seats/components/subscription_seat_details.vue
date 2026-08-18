<script>
import { GlTableLite, GlBadge, GlLink } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { membershipDetailsFields } from '../constants';
import getBillableMemberDetailsQuery from '../graphql/get_billable_member_details.query.graphql';
import SubscriptionSeatDetailsLoader from './subscription_seat_details_loader.vue';

export default {
  name: 'SubscriptionSeatDetails',
  components: {
    GlBadge,
    GlTableLite,
    GlLink,
    SubscriptionSeatDetailsLoader,
  },
  inject: ['namespaceId'],
  props: {
    seatMemberId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      billableMemberDetails: {},
    };
  },
  apollo: {
    billableMemberDetails: {
      query: getBillableMemberDetailsQuery,
      variables() {
        return {
          namespaceId: this.namespaceId,
          memberId: this.seatMemberId,
        };
      },
      update({ billableMemberDetails }) {
        return billableMemberDetails;
      },
      error: (error) => {
        createAlert({
          message: s__('Billing|An error occurred while getting a billable member details.'),
        });

        Sentry.captureException(error);
      },
    },
  },
  computed: {
    items() {
      return this.billableMemberDetails.memberships;
    },
    fields() {
      return membershipDetailsFields(this.billableMemberDetails.hasIndirectMembership);
    },
  },
  methods: {
    formatDate,
  },
};
</script>

<template>
  <div v-if="$apollo.queries.billableMemberDetails.loading">
    <subscription-seat-details-loader />
  </div>
  <gl-table-lite v-else :fields="fields" :items="items" data-testid="seat-usage-details">
    <template #cell(source_full_name)="{ item }">
      <gl-link :href="item.source_members_url" target="_blank">{{ item.source_full_name }}</gl-link>
    </template>
    <template #cell(created_at)="{ item }">
      <span>{{ formatDate(item.created_at, 'yyyy-mm-dd') }}</span>
    </template>
    <template #cell(expires_at)="{ item }">
      <span>{{ item.expires_at ? formatDate(item.expires_at, 'yyyy-mm-dd') : __('Never') }}</span>
    </template>
    <template #cell(role)="{ item }">
      <template v-if="item.access_level.custom_role">
        <div>{{ item.access_level.custom_role.name }}</div>
        <gl-badge class="gl-mt-3">{{ s__('MemberRole|Custom role') }}</gl-badge>
      </template>
      <template v-else>{{ item.access_level.string_value }}</template>
    </template>
  </gl-table-lite>
</template>
